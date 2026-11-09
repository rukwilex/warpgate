use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use flutter_rust_bridge::DartFnFuture;
use russh::client::{self, Handle, Msg};
use russh::Disconnect;
use tokio::sync::{mpsc, watch, Mutex, Notify, RwLock};

use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::forwarding::ForwardedConnection;
use crate::api::util::{on_runtime, until_cancelled, CancelToken};
use crate::engine::handler::{ClientHandler, Verifier};
use crate::engine::sniffer::VersionSniffer;
use crate::engine::stopper::Stopper;
use crate::engine::{shared, Shared};

const WINDOW_SIZE: u32 = 2 * 1024 * 1024;
const MAXIMUM_PACKET_SIZE: u32 = 32768;
const CHANNEL_BUFFER_SIZE: usize = 64;
const FORWARD_QUEUE: usize = 64;
const TUNNEL_ORIGIN: &str = "127.0.0.1";

pub struct ConnectParams {
    pub host: String,
    pub port: u16,
    pub connect_timeout_ms: u32,
    pub handshake_timeout_ms: u32,
    pub client_id: String,
}

pub struct SshClient {
    pub(crate) handle: Arc<RwLock<Handle<ClientHandler>>>,
    pub(crate) closed: watch::Receiver<bool>,
    pub(crate) forwarded: Arc<Mutex<mpsc::Receiver<ForwardedConnection>>>,
    disconnected: Arc<AtomicBool>,
    shutdown: Arc<Notify>,
    reason: Shared<EngineError>,
    remote_version: Shared<String>,
}

fn config(client_id: &str) -> Arc<client::Config> {
    Arc::new(client::Config {
        client_id: russh::SshId::Standard(client_id.to_string().into()),
        inactivity_timeout: None,
        keepalive_interval: None,
        nodelay: true,
        window_size: WINDOW_SIZE,
        maximum_packet_size: MAXIMUM_PACKET_SIZE,
        channel_buffer_size: CHANNEL_BUFFER_SIZE,
        ..Default::default()
    })
}

fn millis(value: u32) -> Duration {
    Duration::from_millis(value as u64)
}

async fn handshake<S>(
    params: &ConnectParams,
    stream: S,
    verifier: Verifier,
) -> Result<SshClient, EngineError>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
{
    let (closed_tx, closed_rx) = watch::channel(false);
    let (forward_tx, forward_rx) = mpsc::channel(FORWARD_QUEUE);
    let reason = shared();
    let rejected = Arc::new(AtomicBool::new(false));
    let prompting = Arc::new(AtomicBool::new(false));
    let remote_version = shared();
    let handler = ClientHandler {
        verifier,
        closed: closed_tx,
        forwarded: forward_tx,
        reason: reason.clone(),
        rejected: rejected.clone(),
        prompting: prompting.clone(),
    };
    let stream = VersionSniffer::new(stream, remote_version.clone());
    let connecting = client::connect_stream(config(&params.client_id), stream, handler);
    let handle = match within_budget(millis(params.handshake_timeout_ms), &prompting, connecting)
        .await
    {
        Ok(Ok(handle)) => handle,
        Ok(Err(error))
            if rejected.load(Ordering::SeqCst) || error.kind == EngineErrorKind::HostKey =>
        {
            return Err(EngineError::new(
                EngineErrorKind::HostKey,
                "the host key was not trusted",
            ));
        }
        Ok(Err(error)) => return Err(EngineError::new(EngineErrorKind::Handshake, error.message)),
        Err(_) => {
            return Err(EngineError::new(
                EngineErrorKind::Timeout,
                "the SSH handshake did not finish in time",
            ));
        }
    };
    Ok(SshClient {
        handle: Arc::new(RwLock::new(handle)),
        closed: closed_rx,
        forwarded: Arc::new(Mutex::new(forward_rx)),
        disconnected: Arc::new(AtomicBool::new(false)),
        shutdown: Arc::new(Notify::new()),
        reason,
        remote_version,
    })
}

const BUDGET_TICK: Duration = Duration::from_millis(100);

async fn within_budget<F: std::future::Future>(
    budget: Duration,
    paused: &AtomicBool,
    work: F,
) -> Result<F::Output, ()> {
    tokio::pin!(work);
    let mut deadline = tokio::time::Instant::now() + budget;
    loop {
        tokio::select! {
            output = &mut work => return Ok(output),
            _ = tokio::time::sleep(BUDGET_TICK) => {
                if paused.load(Ordering::SeqCst) {
                    deadline += BUDGET_TICK;
                } else if tokio::time::Instant::now() >= deadline {
                    return Err(());
                }
            }
        }
    }
}

pub async fn connect(
    params: ConnectParams,
    cancel: &CancelToken,
    verifier: impl Fn(String, String) -> DartFnFuture<bool> + Send + Sync + 'static,
) -> Result<SshClient, EngineError> {
    let verifier: Verifier = Arc::new(verifier);
    let (notify, flag) = cancel.parts();
    on_runtime(async move {
        let address = format!("{}:{}", params.host, params.port);
        let dial = async {
            match tokio::time::timeout(
                millis(params.connect_timeout_ms),
                tokio::net::TcpStream::connect(address),
            )
            .await
            {
                Ok(Ok(socket)) => Ok(socket),
                Ok(Err(error)) => Err(EngineError::from(error)),
                Err(_) => Err(EngineError::new(
                    EngineErrorKind::Timeout,
                    "the host did not answer in time",
                )),
            }
        };
        tokio::select! {
            _ = until_cancelled(notify, flag) => {
                Err(EngineError::new(EngineErrorKind::Cancelled, "the connection was cancelled"))
            }
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
    ) -> Result<SshClient, EngineError> {
        let verifier: Verifier = Arc::new(verifier);
        let handle = self.handle.clone();
        on_runtime(async move {
            let open = async {
                let handle = handle.read().await;
                handle
                    .channel_open_direct_tcpip(
                        params.host.clone(),
                        params.port as u32,
                        TUNNEL_ORIGIN,
                        0,
                    )
                    .await
            };
            let channel = match tokio::time::timeout(millis(params.connect_timeout_ms), open).await
            {
                Ok(Ok(channel)) => channel,
                Ok(Err(error)) => {
                    return Err(EngineError::channel(format!(
                        "the jump host refused the tunnel: {error}"
                    )));
                }
                Err(_) => {
                    return Err(EngineError::new(
                        EngineErrorKind::Timeout,
                        "the jump host did not open the tunnel in time",
                    ));
                }
            };
            handshake(&params, channel.into_stream(), verifier).await
        })
        .await
    }

    pub async fn ping(&self, timeout_ms: u32) -> Result<(), EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let ping = async { handle.read().await.send_ping().await };
            match tokio::time::timeout(millis(timeout_ms), ping).await {
                Ok(Ok(())) => Ok(()),
                Ok(Err(error)) => Err(EngineError::new(EngineErrorKind::Socket, error.to_string())),
                Err(_) => Err(EngineError::new(
                    EngineErrorKind::Timeout,
                    "the server did not answer the keep-alive",
                )),
            }
        })
        .await
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn remote_version(&self) -> Option<String> {
        self.remote_version
            .lock()
            .ok()
            .and_then(|slot| slot.clone())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_closed(&self) -> bool {
        *self.closed.borrow() || self.disconnected.load(Ordering::SeqCst)
    }

    pub async fn wait_closed(&self) -> Result<(), EngineError> {
        let mut closed = self.closed.clone();
        let reason = self.reason.clone();
        let disconnected = self.disconnected.clone();
        on_runtime(async move {
            let _ = closed.wait_for(|value| *value).await;
            if disconnected.load(Ordering::SeqCst) {
                return Ok(());
            }
            match reason.lock().ok().and_then(|mut slot| slot.take()) {
                Some(cause) => Err(cause),
                None => Ok(()),
            }
        })
        .await
    }

    pub async fn disconnect(&self) -> Result<(), EngineError> {
        self.disconnected.store(true, Ordering::SeqCst);
        self.shutdown.notify_waiters();
        let handle = self.handle.clone();
        on_runtime(async move {
            let _ = handle
                .read()
                .await
                .disconnect(Disconnect::ByApplication, "", "en")
                .await;
            Ok(())
        })
        .await
    }

    pub(crate) async fn open_subsystem_stream(
        &self,
        name: &str,
    ) -> Result<russh::ChannelStream<Msg>, EngineError> {
        let handle = self.handle.read().await;
        let channel = handle
            .channel_open_session()
            .await
            .map_err(EngineError::channel)?;
        channel.request_subsystem(true, name).await?;
        Ok(channel.into_stream())
    }

    pub(crate) fn stopper(&self) -> Stopper {
        Stopper {
            notify: self.shutdown.clone(),
            flag: self.disconnected.clone(),
        }
    }

    pub(crate) fn clone_ref(&self) -> SshClient {
        SshClient {
            handle: self.handle.clone(),
            closed: self.closed.clone(),
            forwarded: self.forwarded.clone(),
            disconnected: self.disconnected.clone(),
            shutdown: self.shutdown.clone(),
            reason: self.reason.clone(),
            remote_version: self.remote_version.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test(start_paused = true)]
    async fn time_spent_prompting_does_not_count_against_the_budget() {
        let paused = Arc::new(AtomicBool::new(true));
        let flag = paused.clone();
        tokio::spawn(async move {
            tokio::time::sleep(Duration::from_secs(60)).await;
            flag.store(false, Ordering::SeqCst);
        });
        let work = tokio::time::sleep(Duration::from_secs(62));
        assert!(within_budget(Duration::from_secs(5), &paused, work)
            .await
            .is_ok());
    }

    #[tokio::test(start_paused = true)]
    async fn a_stalled_handshake_still_times_out() {
        let paused = AtomicBool::new(false);
        let work = std::future::pending::<()>();
        assert!(within_budget(Duration::from_secs(5), &paused, work)
            .await
            .is_err());
    }
}
