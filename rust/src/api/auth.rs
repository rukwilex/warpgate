use std::sync::Arc;

use flutter_rust_bridge::DartFnFuture;
use russh::client::KeyboardInteractiveAuthResponse;
use russh::keys::agent::client::AgentClient;
use russh::keys::PrivateKeyWithHashAlg;

use crate::api::connection::SshClient;
use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::util::on_runtime;

const KEYBOARD_INTERACTIVE_ROUNDS: usize = 16;
#[cfg(windows)]
const WINDOWS_AGENT_PIPE: &str = r"\\.\pipe\openssh-ssh-agent";

impl SshClient {
    pub async fn auth_none(&self, user: String) -> Result<bool, EngineError> {
        let handle = self.handle.clone();
        let stop = self.stopper();
        on_runtime(stop.guard(async move {
            let mut handle = handle.write().await;
            Ok(handle.authenticate_none(user).await?.success())
        }))
        .await
    }

    pub async fn auth_password(&self, user: String, password: String) -> Result<bool, EngineError> {
        let handle = self.handle.clone();
        let stop = self.stopper();
        on_runtime(stop.guard(async move {
            let mut handle = handle.write().await;
            Ok(handle
                .authenticate_password(user, password)
                .await?
                .success())
        }))
        .await
    }

    pub async fn auth_key(
        &self,
        user: String,
        pem: String,
        passphrase: Option<String>,
    ) -> Result<bool, EngineError> {
        let handle = self.handle.clone();
        let stop = self.stopper();
        on_runtime(stop.guard(async move {
            let key = russh::keys::decode_secret_key(&pem, passphrase.as_deref())?;
            let mut handle = handle.write().await;
            let hash = handle
                .best_supported_rsa_hash()
                .await
                .ok()
                .flatten()
                .flatten();
            let key = PrivateKeyWithHashAlg::new(Arc::new(key), hash);
            Ok(handle.authenticate_publickey(user, key).await?.success())
        }))
        .await
    }

    pub async fn auth_agent(
        &self,
        user: String,
        socket: Option<String>,
    ) -> Result<bool, EngineError> {
        let handle = self.handle.clone();
        let stop = self.stopper();
        on_runtime(stop.guard(async move {
            #[cfg(unix)]
            let mut agent = match socket {
                Some(path) => AgentClient::connect_uds(path).await?.dynamic(),
                None => AgentClient::connect_env().await?.dynamic(),
            };
            #[cfg(windows)]
            let mut agent = match socket {
                Some(path) => AgentClient::connect_named_pipe(path).await?.dynamic(),
                None => AgentClient::connect_named_pipe(WINDOWS_AGENT_PIPE)
                    .await?
                    .dynamic(),
            };
            let identities = agent.request_identities().await?;
            let mut handle = handle.write().await;
            let hash = handle
                .best_supported_rsa_hash()
                .await
                .ok()
                .flatten()
                .flatten();
            for identity in identities {
                let key = identity.public_key().into_owned();
                let result = handle
                    .authenticate_publickey_with(user.clone(), key, hash, &mut agent)
                    .await;
                if let Ok(result) = result {
                    if result.success() {
                        return Ok(true);
                    }
                }
            }
            Ok(false)
        }))
        .await
    }

    pub async fn auth_keyboard_interactive(
        &self,
        user: String,
        responder: impl Fn(String, String, Vec<String>, Vec<bool>) -> DartFnFuture<Option<Vec<String>>>
            + Send
            + Sync
            + 'static,
    ) -> Result<bool, EngineError> {
        let handle = self.handle.clone();
        let responder = Arc::new(responder);
        let stop = self.stopper();
        on_runtime(stop.guard(async move {
            let mut handle = handle.write().await;
            let mut reply = handle
                .authenticate_keyboard_interactive_start(user, None)
                .await?;
            for _ in 0..KEYBOARD_INTERACTIVE_ROUNDS {
                match reply {
                    KeyboardInteractiveAuthResponse::Success => return Ok(true),
                    KeyboardInteractiveAuthResponse::Failure { .. } => return Ok(false),
                    KeyboardInteractiveAuthResponse::InfoRequest {
                        name,
                        instructions,
                        prompts,
                    } => {
                        let texts = prompts.iter().map(|p| p.prompt.clone()).collect();
                        let echoes = prompts.iter().map(|p| p.echo).collect();
                        let Some(answers) = responder(name, instructions, texts, echoes).await
                        else {
                            return Err(EngineError::new(
                                EngineErrorKind::AuthAbort,
                                "sign-in was cancelled",
                            ));
                        };
                        reply = handle
                            .authenticate_keyboard_interactive_respond(answers)
                            .await?;
                    }
                }
            }
            Ok(false)
        }))
        .await
    }
}
