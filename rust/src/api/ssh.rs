use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use flutter_rust_bridge::DartFnFuture;
use futures::FutureExt;
use russh::client::{
    self, DisconnectReason, Handle, KeyboardInteractiveAuthResponse, Msg, Session,
};
use russh::keys::agent::client::AgentClient;
use russh::keys::{HashAlg, PrivateKeyWithHashAlg, PublicKeyOrCertificate};
use russh::{Channel, ChannelMsg, ChannelReadHalf, ChannelWriteHalf, Disconnect};
use tokio::sync::{mpsc, watch, Mutex, Notify, RwLock};

use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::util::{on_runtime, until_cancelled, CancelToken};

type Verifier = Arc<dyn Fn(String, String) -> DartFnFuture<bool> + Send + Sync>;
type Reason = Arc<std::sync::Mutex<Option<EngineError>>>;
type Shared<T> = Arc<std::sync::Mutex<Option<T>>>;

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
    reason: Reason,
    rejected: Arc<AtomicBool>,
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

struct Stopper {
    notify: Arc<Notify>,
    flag: Arc<AtomicBool>,
}

impl Stopper {
    async fn guard<T>(
        self,
        body: impl std::future::Future<Output = Result<T, EngineError>>,
    ) -> Result<T, EngineError> {
        tokio::select! {
            _ = until_cancelled(self.notify, self.flag) => Err(EngineError::new(EngineErrorKind::Cancelled, "the connection was closed")),
            result = body => result,
        }
    }
}

pub struct SshClient {
    handle: Arc<RwLock<Handle<ClientHandler>>>,
    closed: watch::Receiver<bool>,
    forwarded: Arc<Mutex<mpsc::Receiver<ForwardedConnection>>>,
    disconnected: Arc<AtomicBool>,
    shutdown: Arc<Notify>,
    reason: Reason,
    remote_version: Shared<String>,
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
) -> Result<SshClient, EngineError>
where
    S: tokio::io::AsyncRead + tokio::io::AsyncWrite + Unpin + Send + 'static,
{
    let (closed_tx, closed_rx) = watch::channel(false);
    let (forward_tx, forward_rx) = mpsc::channel(64);
    let reason: Reason = Arc::new(std::sync::Mutex::new(None));
    let rejected = Arc::new(AtomicBool::new(false));
    let remote_version: Shared<String> = Arc::new(std::sync::Mutex::new(None));
    let handler = ClientHandler {
        verifier,
        closed: closed_tx,
        forwarded: forward_tx,
        reason: reason.clone(),
        rejected: rejected.clone(),
    };
    let stream = VersionSniffer::new(stream, remote_version.clone());
    let timeout = Duration::from_millis(params.handshake_timeout_ms as u64);
    let handle = match tokio::time::timeout(
        timeout,
        client::connect_stream(config(&params.client_id), stream, handler),
    )
    .await
    {
        Ok(Ok(handle)) => handle,
        Ok(Err(error)) => {
            if rejected.load(Ordering::SeqCst) || error.kind == EngineErrorKind::HostKey {
                return Err(EngineError::new(
                    EngineErrorKind::HostKey,
                    "the host key was not trusted",
                ));
            }
            return Err(EngineError::new(EngineErrorKind::Handshake, error.message));
        }
        Err(_) => {
            return Err(EngineError::new(
                EngineErrorKind::Timeout,
                "the SSH handshake did not finish in time",
            ))
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

pub async fn connect(
    params: ConnectParams,
    cancel: &CancelToken,
    verifier: impl Fn(String, String) -> DartFnFuture<bool> + Send + Sync + 'static,
) -> Result<SshClient, EngineError> {
    let verifier: Verifier = Arc::new(verifier);
    let (notify, flag) = cancel.parts();
    on_runtime(async move {
        let address = format!("{}:{}", params.host, params.port);
        let timeout = Duration::from_millis(params.connect_timeout_ms as u64);
        let dial = async {
            match tokio::time::timeout(timeout, tokio::net::TcpStream::connect(address)).await {
                Ok(Ok(socket)) => Ok(socket),
                Ok(Err(error)) => Err(EngineError::new(EngineErrorKind::Socket, format!("{error}"))),
                Err(_) => Err(EngineError::new(EngineErrorKind::Timeout, "the host did not answer in time")),
            }
        };
        tokio::select! {
            _ = until_cancelled(notify.clone(), flag.clone()) => Err(EngineError::new(EngineErrorKind::Cancelled, "the connection was cancelled")),
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
            let timeout = Duration::from_millis(params.connect_timeout_ms as u64);
            let open = async {
                let handle = handle.read().await;
                handle
                    .channel_open_direct_tcpip(
                        params.host.clone(),
                        params.port as u32,
                        "127.0.0.1",
                        0,
                    )
                    .await
            };
            let channel = match tokio::time::timeout(timeout, open).await {
                Ok(Ok(channel)) => channel,
                Ok(Err(error)) => {
                    return Err(EngineError::channel(format!(
                        "the jump host refused the tunnel: {error}"
                    )))
                }
                Err(_) => {
                    return Err(EngineError::new(
                        EngineErrorKind::Timeout,
                        "the jump host did not open the tunnel in time",
                    ))
                }
            };
            handshake(&params, channel.into_stream(), verifier).await
        })
        .await
    }

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
                None => AgentClient::connect_named_pipe(r"\\.\pipe\openssh-ssh-agent")
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

    pub async fn open_session(&self) -> Result<SshChannel, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.read().await;
            let channel = handle
                .channel_open_session()
                .await
                .map_err(|error| EngineError::new(EngineErrorKind::Channel, format!("{error}")))?;
            Ok(SshChannel::new(channel))
        })
        .await
    }

    pub async fn open_direct_tcpip(
        &self,
        host: String,
        port: u32,
    ) -> Result<SshChannel, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.read().await;
            let channel = handle
                .channel_open_direct_tcpip(host, port, "127.0.0.1", 0)
                .await
                .map_err(|error| EngineError::new(EngineErrorKind::Channel, format!("{error}")))?;
            Ok(SshChannel::new(channel))
        })
        .await
    }

    pub async fn forward_remote(&self, host: String, port: u32) -> Result<u32, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.read().await;
            let assigned = handle.tcpip_forward(host, port).await?;
            Ok(if port == 0 { assigned } else { port })
        })
        .await
    }

    pub async fn cancel_forward_remote(&self, host: String, port: u32) -> Result<(), EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.read().await;
            handle.cancel_tcpip_forward(host, port).await?;
            Ok(())
        })
        .await
    }

    pub async fn accept_forwarded(&self) -> Result<Option<ForwardedConnection>, EngineError> {
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

    pub async fn ping(&self, timeout_ms: u32) -> Result<(), EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let ping = async {
                let handle = handle.read().await;
                handle.send_ping().await
            };
            match tokio::time::timeout(Duration::from_millis(timeout_ms as u64), ping).await {
                Ok(Ok(())) => Ok(()),
                Ok(Err(error)) => Err(EngineError::new(
                    EngineErrorKind::Socket,
                    format!("{error}"),
                )),
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
            let handle = handle.read().await;
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

    pub async fn request_pty(
        &self,
        term: String,
        columns: u32,
        rows: u32,
    ) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            write
                .request_pty(true, &term, columns, rows, 0, 0, &[])
                .await?;
            Ok(())
        })
        .await
    }

    pub async fn set_env(&self, name: String, value: String) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            write.set_env(false, name, value).await?;
            Ok(())
        })
        .await
    }

    pub async fn request_shell(&self) -> Result<(), EngineError> {
        let write = self.write.clone();
        let read = self.read.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            write.request_shell(true).await?;
            expect_success(&read, &pending).await
        })
        .await
    }

    pub async fn exec(&self, command: String) -> Result<(), EngineError> {
        let write = self.write.clone();
        let read = self.read.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            write.exec(true, command).await?;
            expect_success(&read, &pending).await
        })
        .await
    }

    pub async fn read(&self, max_bytes: u32) -> Result<ChannelChunk, EngineError> {
        let read = self.read.clone();
        let exit = self.exit.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            let mut guard = read.lock().await;
            let mut stashed: Vec<ChannelMsg> = std::mem::take(&mut *pending.lock().unwrap());
            stashed.reverse();
            let result = read_into(&mut guard, &mut stashed, &exit, max_bytes as usize).await;
            if !stashed.is_empty() {
                stashed.reverse();
                let mut slot = pending.lock().unwrap();
                stashed.append(&mut slot);
                *slot = stashed;
            }
            result
        })
        .await
    }

    pub async fn write(&self, data: Vec<u8>) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            write
                .data(&data[..])
                .await
                .map_err(|error| EngineError::new(EngineErrorKind::Channel, format!("{error}")))?;
            Ok(())
        })
        .await
    }
    pub async fn window_change(&self, columns: u32, rows: u32) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            write.window_change(columns, rows, 0, 0).await?;
            Ok(())
        })
        .await
    }

    pub async fn eof(&self) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            let _ = write.eof().await;
            Ok(())
        })
        .await
    }

    pub async fn close(&self) -> Result<(), EngineError> {
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

type ReadGuard<'a> = tokio::sync::MutexGuard<'a, Option<ChannelReadHalf>>;

async fn read_into(
    guard: &mut ReadGuard<'_>,
    stashed: &mut Vec<ChannelMsg>,
    exit: &std::sync::Mutex<Option<u32>>,
    limit: usize,
) -> Result<ChannelChunk, EngineError> {
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
                    let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
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
            Some(ChannelMsg::ExtendedData { data, .. }) => chunk.extended.extend_from_slice(&data),
            Some(ChannelMsg::ExitStatus { exit_status }) => {
                *exit.lock().unwrap() = Some(exit_status);
                chunk.exit_status = Some(exit_status);
            }
            Some(ChannelMsg::Close) | None => {
                chunk.closed = true;
                **guard = None;
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
}

async fn expect_success(
    read: &Arc<Mutex<Option<ChannelReadHalf>>>,
    pending: &Pending,
) -> Result<(), EngineError> {
    let mut guard = read.lock().await;
    let Some(reader) = guard.as_mut() else {
        return Err(EngineError::new(
            EngineErrorKind::Channel,
            "the channel is closed",
        ));
    };
    loop {
        match reader.wait().await {
            Some(ChannelMsg::Success) => return Ok(()),
            Some(ChannelMsg::Failure) => {
                return Err(EngineError::new(
                    EngineErrorKind::ChannelRequest,
                    "the server refused the request",
                ))
            }
            Some(ChannelMsg::Close) | None => {
                return Err(EngineError::new(
                    EngineErrorKind::Channel,
                    "the channel closed",
                ))
            }
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
    ) -> Result<russh::ChannelStream<Msg>, EngineError> {
        let handle = self.handle.read().await;
        let channel = handle
            .channel_open_session()
            .await
            .map_err(|error| EngineError::new(EngineErrorKind::Channel, format!("{error}")))?;
        channel.request_subsystem(true, name).await?;
        Ok(channel.into_stream())
    }

    fn stopper(&self) -> Stopper {
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

struct VersionSniffer<S> {
    inner: S,
    line: Vec<u8>,
    found: Shared<String>,
    done: bool,
}

impl<S> VersionSniffer<S> {
    const LIMIT: usize = 255;

    fn new(inner: S, found: Shared<String>) -> VersionSniffer<S> {
        VersionSniffer {
            inner,
            line: Vec::new(),
            found,
            done: false,
        }
    }

    fn observe(&mut self, bytes: &[u8]) {
        for &byte in bytes {
            if self.done {
                return;
            }
            if byte != b'\n' {
                self.line.push(byte);
                self.done = self.line.len() > Self::LIMIT;
                continue;
            }
            let text = String::from_utf8_lossy(&self.line).trim_end().to_string();
            self.line.clear();
            if text.starts_with("SSH-") {
                self.done = true;
                if let Ok(mut slot) = self.found.lock() {
                    *slot = Some(text);
                }
            }
        }
    }
}

impl<S: tokio::io::AsyncRead + Unpin> tokio::io::AsyncRead for VersionSniffer<S> {
    fn poll_read(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
        buf: &mut tokio::io::ReadBuf<'_>,
    ) -> std::task::Poll<std::io::Result<()>> {
        let before = buf.filled().len();
        let poll = std::pin::Pin::new(&mut self.inner).poll_read(cx, buf);
        if !self.done && matches!(poll, std::task::Poll::Ready(Ok(()))) {
            let fresh = buf.filled()[before..].to_vec();
            self.observe(&fresh);
        }
        poll
    }
}

impl<S: tokio::io::AsyncWrite + Unpin> tokio::io::AsyncWrite for VersionSniffer<S> {
    fn poll_write(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
        buf: &[u8],
    ) -> std::task::Poll<std::io::Result<usize>> {
        std::pin::Pin::new(&mut self.inner).poll_write(cx, buf)
    }

    fn poll_flush(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<std::io::Result<()>> {
        std::pin::Pin::new(&mut self.inner).poll_flush(cx)
    }

    fn poll_shutdown(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<std::io::Result<()>> {
        std::pin::Pin::new(&mut self.inner).poll_shutdown(cx)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sniff(chunks: &[&[u8]]) -> Option<String> {
        let found: Shared<String> = Arc::new(std::sync::Mutex::new(None));
        let mut sniffer = VersionSniffer::new((), found.clone());
        for chunk in chunks {
            sniffer.observe(chunk);
        }
        let value = found.lock().unwrap().clone();
        value
    }

    #[test]
    fn the_version_line_is_captured_across_reads() {
        assert_eq!(
            sniff(&[b"SSH-2.0-Open", b"SSH_9.6\r\nbinary"]),
            Some("SSH-2.0-OpenSSH_9.6".to_string())
        );
    }

    #[test]
    fn banner_lines_before_the_version_are_skipped() {
        assert_eq!(
            sniff(&[b"welcome\r\nSSH-2.0-x\r\n"]),
            Some("SSH-2.0-x".to_string())
        );
    }

    #[test]
    fn an_endless_line_stops_the_sniffer() {
        assert_eq!(sniff(&[&[b'a'; 400], b"\nSSH-2.0-late\n"]), None);
    }
}
