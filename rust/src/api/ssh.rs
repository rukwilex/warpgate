use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{anyhow, bail};
use flutter_rust_bridge::DartFnFuture;
use futures::FutureExt;
use russh::client::{self, Handle, KeyboardInteractiveAuthResponse, Msg, Session};
use russh::keys::agent::client::AgentClient;
use russh::keys::{HashAlg, PrivateKeyWithHashAlg, PublicKeyOrCertificate};
use russh::{Channel, ChannelMsg, ChannelReadHalf, ChannelWriteHalf, Disconnect};
use tokio::sync::{mpsc, watch, Mutex};

use crate::api::util::{on_runtime, until_cancelled, CancelToken};

type Verifier = Arc<dyn Fn(String, String) -> DartFnFuture<bool> + Send + Sync>;

pub struct ConnectParams {
    pub host: String,
    pub port: u16,
    pub connect_timeout_ms: u32,
    pub handshake_timeout_ms: u32,
    pub client_id: String,
}

pub struct ChannelChunk {
    pub data: Vec<u8>,
    pub extended: Vec<u8>,
    pub exit_status: Option<u32>,
    pub closed: bool,
}

pub struct ForwardedConnection {
    pub channel: SshChannel,
    pub connected_host: String,
    pub connected_port: u32,
    pub origin_host: String,
    pub origin_port: u32,
}

struct ClientHandler {
    verifier: Verifier,
    closed: watch::Sender<bool>,
    forwarded: mpsc::Sender<ForwardedConnection>,
}

impl Drop for ClientHandler {
    fn drop(&mut self) {
        let _ = self.closed.send(true);
    }
}

impl client::Handler for ClientHandler {
    type Error = anyhow::Error;

    async fn check_server_key(
        &mut self,
        key: &PublicKeyOrCertificate,
    ) -> Result<bool, Self::Error> {
        let public = match key {
            PublicKeyOrCertificate::PublicKey { key, .. } => key.clone(),
            PublicKeyOrCertificate::Certificate(cert) => cert.public_key().clone().into(),
        };
        let kind = public.algorithm().as_str().to_string();
        let fingerprint = public.fingerprint(HashAlg::Sha256).to_string();
        Ok((self.verifier)(kind, fingerprint).await)
    }

    async fn server_channel_open_forwarded_tcpip(
        &mut self,
        channel: Channel<Msg>,
        connected_address: &str,
        connected_port: u32,
        originator_address: &str,
        originator_port: u32,
        reply: russh::client::ChannelOpenHandle,
        _session: &mut Session,
    ) -> Result<(), Self::Error> {
        let connection = ForwardedConnection {
            channel: SshChannel::new(channel),
            connected_host: connected_address.to_string(),
            connected_port,
            origin_host: originator_address.to_string(),
            origin_port: originator_port,
        };
        if self.forwarded.try_send(connection).is_ok() {
            reply.accept().await;
        } else {
            reply
                .reject(russh::ChannelOpenFailure::ResourceShortage)
                .await;
        }
        Ok(())
    }
}

pub struct SshClient {
    handle: Arc<Mutex<Handle<ClientHandler>>>,
    closed: watch::Receiver<bool>,
    forwarded: Arc<Mutex<mpsc::Receiver<ForwardedConnection>>>,
    disconnected: Arc<AtomicBool>,
}

fn config(client_id: &str) -> Arc<client::Config> {
    Arc::new(client::Config {
        client_id: russh::SshId::Standard(client_id.to_string().into()),
        inactivity_timeout: None,
        keepalive_interval: None,
        nodelay: true,
        window_size: 2 * 1024 * 1024,
        maximum_packet_size: 32768,
        channel_buffer_size: 64,
        ..Default::default()
    })
}

async fn handshake<S>(
    params: &ConnectParams,
    stream: S,
    verifier: Verifier,
) -> anyhow::Result<SshClient>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
{
    let (closed_tx, closed_rx) = watch::channel(false);
    let (forward_tx, forward_rx) = mpsc::channel(64);
    let handler = ClientHandler {
        verifier,
        closed: closed_tx,
        forwarded: forward_tx,
    };
    let timeout = Duration::from_millis(params.handshake_timeout_ms as u64);
    let handle = match tokio::time::timeout(
        timeout,
        client::connect_stream(config(&params.client_id), stream, handler),
    )
    .await
    {
        Ok(Ok(handle)) => handle,
        Ok(Err(error)) => {
            let text = format!("{error:#}");
            if text.contains("UnknownKey")
                || text.contains("check_server_key")
                || text.contains("server key")
            {
                bail!("hostkey: the host key was not trusted");
            }
            bail!("handshake: {text}");
        }
        Err(_) => bail!("timeout: the SSH handshake did not finish in time"),
    };
    Ok(SshClient {
        handle: Arc::new(Mutex::new(handle)),
        closed: closed_rx,
        forwarded: Arc::new(Mutex::new(forward_rx)),
        disconnected: Arc::new(AtomicBool::new(false)),
    })
}

pub async fn connect(
    params: ConnectParams,
    cancel: &CancelToken,
    verifier: impl Fn(String, String) -> DartFnFuture<bool> + Send + Sync + 'static,
) -> anyhow::Result<SshClient> {
    let verifier: Verifier = Arc::new(verifier);
    let (notify, flag) = cancel.parts();
    on_runtime(async move {
        let address = format!("{}:{}", params.host, params.port);
        let timeout = Duration::from_millis(params.connect_timeout_ms as u64);
        let dial = async {
            match tokio::time::timeout(timeout, tokio::net::TcpStream::connect(address)).await {
                Ok(Ok(socket)) => Ok(socket),
                Ok(Err(error)) => Err(anyhow!("socket: {error}")),
                Err(_) => Err(anyhow!("timeout: the host did not answer in time")),
            }
        };
        tokio::select! {
            _ = until_cancelled(notify.clone(), flag.clone()) => bail!("cancelled: the connection was cancelled"),
            result = async {
                let socket = dial.await?;
                let _ = socket.set_nodelay(true);
                handshake(&params, socket, verifier).await
            } => result,
        }
    })
    .await
}

impl SshClient {
    pub async fn connect_via(
        &self,
        params: ConnectParams,
        verifier: impl Fn(String, String) -> DartFnFuture<bool> + Send + Sync + 'static,
    ) -> anyhow::Result<SshClient> {
        let verifier: Verifier = Arc::new(verifier);
        let handle = self.handle.clone();
        on_runtime(async move {
            let channel = {
                let handle = handle.lock().await;
                handle
                    .channel_open_direct_tcpip(
                        params.host.clone(),
                        params.port as u32,
                        "127.0.0.1",
                        0,
                    )
                    .await
                    .map_err(|error| {
                        anyhow!("channel: the jump host refused the tunnel: {error}")
                    })?
            };
            handshake(&params, channel.into_stream(), verifier).await
        })
        .await
    }

    pub async fn auth_none(&self, user: String) -> anyhow::Result<bool> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let mut handle = handle.lock().await;
            Ok(handle.authenticate_none(user).await?.success())
        })
        .await
    }

    pub async fn auth_password(&self, user: String, password: String) -> anyhow::Result<bool> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let mut handle = handle.lock().await;
            Ok(handle
                .authenticate_password(user, password)
                .await?
                .success())
        })
        .await
    }

    pub async fn auth_key(
        &self,
        user: String,
        pem: String,
        passphrase: Option<String>,
    ) -> anyhow::Result<bool> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let key =
                russh::keys::decode_secret_key(&pem, passphrase.as_deref()).map_err(|error| {
                    let text = error.to_string();
                    if text.to_lowercase().contains("decrypt")
                        || text.to_lowercase().contains("passphrase")
                        || text.to_lowercase().contains("crypto")
                    {
                        anyhow!("key_decrypt: {text}")
                    } else {
                        anyhow!("key_decode: {text}")
                    }
                })?;
            let mut handle = handle.lock().await;
            let hash = handle
                .best_supported_rsa_hash()
                .await
                .ok()
                .flatten()
                .flatten();
            let key = PrivateKeyWithHashAlg::new(Arc::new(key), hash);
            Ok(handle.authenticate_publickey(user, key).await?.success())
        })
        .await
    }

    pub async fn auth_agent(&self, user: String, socket: Option<String>) -> anyhow::Result<bool> {
        let handle = self.handle.clone();
        on_runtime(async move {
            #[cfg(unix)]
            let mut agent = match socket {
                Some(path) => AgentClient::connect_uds(path).await?.dynamic(),
                None => AgentClient::connect_env().await?.dynamic(),
            };
            #[cfg(windows)]
            let mut agent = match socket {
                Some(path) => AgentClient::connect_named_pipe(path).await?.dynamic(),
                None => AgentClient::connect_named_pipe(r"\\.\pipe\openssh-ssh-agent")
                    .await?
                    .dynamic(),
            };
            let identities = agent.request_identities().await?;
            let mut handle = handle.lock().await;
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
        })
        .await
    }

    pub async fn auth_keyboard_interactive(
        &self,
        user: String,
        responder: impl Fn(String, String, Vec<String>, Vec<bool>) -> DartFnFuture<Option<Vec<String>>>
            + Send
            + Sync
            + 'static,
    ) -> anyhow::Result<bool> {
        let handle = self.handle.clone();
        let responder = Arc::new(responder);
        on_runtime(async move {
            let mut handle = handle.lock().await;
            let mut reply = handle
                .authenticate_keyboard_interactive_start(user, None)
                .await?;
            for _ in 0..16 {
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
                            bail!("auth_abort: sign-in was cancelled");
                        };
                        reply = handle
                            .authenticate_keyboard_interactive_respond(answers)
                            .await?;
                    }
                }
            }
            Ok(false)
        })
        .await
    }

    pub async fn open_session(&self) -> anyhow::Result<SshChannel> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.lock().await;
            let channel = handle
                .channel_open_session()
                .await
                .map_err(|error| anyhow!("channel: {error}"))?;
            Ok(SshChannel::new(channel))
        })
        .await
    }

    pub async fn open_direct_tcpip(&self, host: String, port: u32) -> anyhow::Result<SshChannel> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.lock().await;
            let channel = handle
                .channel_open_direct_tcpip(host, port, "127.0.0.1", 0)
                .await
                .map_err(|error| anyhow!("channel: {error}"))?;
            Ok(SshChannel::new(channel))
        })
        .await
    }

    pub async fn forward_remote(&self, host: String, port: u32) -> anyhow::Result<u32> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.lock().await;
            let assigned = handle.tcpip_forward(host, port).await?;
            Ok(if port == 0 { assigned } else { port })
        })
        .await
    }

    pub async fn cancel_forward_remote(&self, host: String, port: u32) -> anyhow::Result<()> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.lock().await;
            handle.cancel_tcpip_forward(host, port).await?;
            Ok(())
        })
        .await
    }

    pub async fn accept_forwarded(&self) -> anyhow::Result<Option<ForwardedConnection>> {
        let forwarded = self.forwarded.clone();
        let mut closed = self.closed.clone();
        on_runtime(async move {
            let mut receiver = forwarded.lock().await;
            tokio::select! {
                next = receiver.recv() => Ok(next),
                _ = closed.wait_for(|value| *value) => Ok(None),
            }
        })
        .await
    }

    pub async fn ping(&self, timeout_ms: u32) -> anyhow::Result<()> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let ping = async {
                let handle = handle.lock().await;
                handle.send_ping().await
            };
            match tokio::time::timeout(Duration::from_millis(timeout_ms as u64), ping).await {
                Ok(Ok(())) => Ok(()),
                Ok(Err(error)) => Err(anyhow!("socket: {error}")),
                Err(_) => Err(anyhow!("timeout: the server did not answer the keep-alive")),
            }
        })
        .await
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_closed(&self) -> bool {
        *self.closed.borrow() || self.disconnected.load(Ordering::SeqCst)
    }

    pub async fn wait_closed(&self) -> anyhow::Result<()> {
        let mut closed = self.closed.clone();
        on_runtime(async move {
            let _ = closed.wait_for(|value| *value).await;
            Ok(())
        })
        .await
    }

    pub async fn disconnect(&self) -> anyhow::Result<()> {
        self.disconnected.store(true, Ordering::SeqCst);
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.lock().await;
            let _ = handle.disconnect(Disconnect::ByApplication, "", "en").await;
            Ok(())
        })
        .await
    }
}

type Pending = Arc<std::sync::Mutex<Vec<ChannelMsg>>>;

#[derive(Clone)]
pub struct SshChannel {
    read: Arc<Mutex<Option<ChannelReadHalf>>>,
    write: Arc<ChannelWriteHalf<Msg>>,
    exit: Arc<std::sync::Mutex<Option<u32>>>,
    pending: Pending,
}

impl SshChannel {
    pub(crate) fn new(channel: Channel<Msg>) -> SshChannel {
        let (read, write) = channel.split();
        SshChannel {
            read: Arc::new(Mutex::new(Some(read))),
            write: Arc::new(write),
            exit: Arc::new(std::sync::Mutex::new(None)),
            pending: Arc::new(std::sync::Mutex::new(Vec::new())),
        }
    }

    pub async fn request_pty(&self, term: String, columns: u32, rows: u32) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            write
                .request_pty(true, &term, columns, rows, 0, 0, &[])
                .await?;
            Ok(())
        })
        .await
    }

    pub async fn set_env(&self, name: String, value: String) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            write.set_env(false, name, value).await?;
            Ok(())
        })
        .await
    }

    pub async fn request_shell(&self) -> anyhow::Result<()> {
        let write = self.write.clone();
        let read = self.read.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            write.request_shell(true).await?;
            expect_success(&read, &pending).await
        })
        .await
    }

    pub async fn exec(&self, command: String) -> anyhow::Result<()> {
        let write = self.write.clone();
        let read = self.read.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            write.exec(true, command).await?;
            expect_success(&read, &pending).await
        })
        .await
    }

    pub async fn read(&self, max_bytes: u32) -> anyhow::Result<ChannelChunk> {
        let read = self.read.clone();
        let exit = self.exit.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            let mut guard = read.lock().await;
            let mut stashed: Vec<ChannelMsg> = std::mem::take(&mut *pending.lock().unwrap());
            stashed.reverse();
            let mut chunk = ChannelChunk {
                data: Vec::new(),
                extended: Vec::new(),
                exit_status: None,
                closed: false,
            };
            let Some(reader) = guard.as_mut() else {
                chunk.closed = true;
                chunk.exit_status = *exit.lock().unwrap();
                return Ok(chunk);
            };
            let limit = max_bytes as usize;
            let mut first = true;
            let mut deadline = tokio::time::Instant::now() + Duration::from_millis(1);
            loop {
                let next = if let Some(message) = stashed.pop() {
                    first = false;
                    Some(message)
                } else if first {
                    first = false;
                    let message = reader.wait().await;
                    deadline = tokio::time::Instant::now() + Duration::from_millis(1);
                    message
                } else {
                    match reader.wait().now_or_never() {
                        Some(message) => message,
                        None => {
                            let small = chunk.data.len() + chunk.extended.len() < 16 * 1024;
                            let remaining =
                                deadline.saturating_duration_since(tokio::time::Instant::now());
                            if !small || remaining.is_zero() {
                                break;
                            }
                            match tokio::time::timeout(remaining, reader.wait()).await {
                                Ok(message) => message,
                                Err(_) => break,
                            }
                        }
                    }
                };
                match next {
                    Some(ChannelMsg::Data { data }) => chunk.data.extend_from_slice(&data),
                    Some(ChannelMsg::ExtendedData { data, .. }) => {
                        chunk.extended.extend_from_slice(&data)
                    }
                    Some(ChannelMsg::ExitStatus { exit_status }) => {
                        *exit.lock().unwrap() = Some(exit_status);
                        chunk.exit_status = Some(exit_status);
                    }
                    Some(ChannelMsg::Close) | None => {
                        chunk.closed = true;
                        *guard = None;
                        break;
                    }
                    Some(_) => {}
                }
                if chunk.data.len() + chunk.extended.len() >= limit {
                    break;
                }
            }
            if chunk.exit_status.is_none() {
                chunk.exit_status = *exit.lock().unwrap();
            }
            Ok(chunk)
        })
        .await
    }

    pub async fn write(&self, data: Vec<u8>) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            write
                .data(&data[..])
                .await
                .map_err(|error| anyhow!("channel: {error}"))?;
            Ok(())
        })
        .await
    }

    pub async fn window_change(&self, columns: u32, rows: u32) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            write.window_change(columns, rows, 0, 0).await?;
            Ok(())
        })
        .await
    }

    pub async fn eof(&self) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            let _ = write.eof().await;
            Ok(())
        })
        .await
    }

    pub async fn close(&self) -> anyhow::Result<()> {
        let write = self.write.clone();
        on_runtime(async move {
            let _ = write.close().await;
            Ok(())
        })
        .await
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn exit_status(&self) -> Option<u32> {
        *self.exit.lock().unwrap()
    }
}

async fn expect_success(
    read: &Arc<Mutex<Option<ChannelReadHalf>>>,
    pending: &Pending,
) -> anyhow::Result<()> {
    let mut guard = read.lock().await;
    let Some(reader) = guard.as_mut() else {
        bail!("channel: the channel is closed")
    };
    loop {
        match reader.wait().await {
            Some(ChannelMsg::Success) => return Ok(()),
            Some(ChannelMsg::Failure) => bail!("channel_request: the server refused the request"),
            Some(ChannelMsg::Close) | None => bail!("channel: the channel closed"),
            Some(
                message @ (ChannelMsg::Data { .. }
                | ChannelMsg::ExtendedData { .. }
                | ChannelMsg::ExitStatus { .. }
                | ChannelMsg::Eof),
            ) => {
                pending.lock().unwrap().push(message);
            }
            Some(_) => {}
        }
    }
}

impl SshClient {
    pub(crate) async fn open_subsystem_stream(
        &self,
        name: &str,
    ) -> anyhow::Result<russh::ChannelStream<Msg>> {
        let handle = self.handle.lock().await;
        let channel = handle
            .channel_open_session()
            .await
            .map_err(|error| anyhow!("channel: {error}"))?;
        channel.request_subsystem(true, name).await?;
        Ok(channel.into_stream())
    }

    pub(crate) fn clone_ref(&self) -> SshClient {
        SshClient {
            handle: self.handle.clone(),
            closed: self.closed.clone(),
            forwarded: self.forwarded.clone(),
            disconnected: self.disconnected.clone(),
        }
    }
}
