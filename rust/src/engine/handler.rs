use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use flutter_rust_bridge::DartFnFuture;
use russh::client::{self, DisconnectReason, Msg, Session};
use russh::keys::{HashAlg, PublicKeyOrCertificate};
use russh::Channel;
use tokio::sync::{mpsc, watch};

use crate::api::channel::SshChannel;
use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::forwarding::ForwardedConnection;
use crate::engine::Shared;

pub(crate) type Verifier = Arc<dyn Fn(String, String) -> DartFnFuture<bool> + Send + Sync>;

pub(crate) struct ClientHandler {
    pub(crate) verifier: Verifier,
    pub(crate) closed: watch::Sender<bool>,
    pub(crate) forwarded: mpsc::Sender<ForwardedConnection>,
    pub(crate) reason: Shared<EngineError>,
    pub(crate) rejected: Arc<AtomicBool>,
}

impl Drop for ClientHandler {
    fn drop(&mut self) {
        let _ = self.closed.send(true);
    }
}

impl client::Handler for ClientHandler {
    type Error = EngineError;

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
        let trusted = (self.verifier)(kind, fingerprint).await;
        if !trusted {
            self.rejected.store(true, Ordering::SeqCst);
        }
        Ok(trusted)
    }

    async fn disconnected(
        &mut self,
        reason: DisconnectReason<Self::Error>,
    ) -> Result<(), Self::Error> {
        let (cause, result) = match reason {
            DisconnectReason::ReceivedDisconnect(info) => (
                EngineError::coded(
                    EngineErrorKind::Disconnect,
                    info.reason_code as u32,
                    info.message,
                ),
                Ok(()),
            ),
            DisconnectReason::Error(error) => (error.clone(), Err(error)),
        };
        if let Ok(mut slot) = self.reason.lock() {
            slot.get_or_insert(cause);
        }
        result
    }

    async fn server_channel_open_forwarded_tcpip(
        &mut self,
        channel: Channel<Msg>,
        connected_address: &str,
        connected_port: u32,
        originator_address: &str,
        originator_port: u32,
        reply: client::ChannelOpenHandle,
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
