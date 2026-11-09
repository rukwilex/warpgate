use crate::api::channel::SshChannel;
use crate::api::connection::SshClient;
use crate::api::error::EngineError;
use crate::api::util::on_runtime;

const TUNNEL_ORIGIN: &str = "127.0.0.1";

pub struct ForwardedConnection {
    pub channel: SshChannel,
    pub connected_host: String,
    pub connected_port: u32,
    pub origin_host: String,
    pub origin_port: u32,
}

impl SshClient {
    pub async fn open_direct_tcpip(
        &self,
        host: String,
        port: u32,
    ) -> Result<SshChannel, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let handle = handle.read().await;
            let channel = handle
                .channel_open_direct_tcpip(host, port, TUNNEL_ORIGIN, 0)
                .await
                .map_err(EngineError::channel)?;
            Ok(SshChannel::new(channel))
        })
        .await
    }

    pub async fn forward_remote(&self, host: String, port: u32) -> Result<u32, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let assigned = handle.read().await.tcpip_forward(host, port).await?;
            Ok(if port == 0 { assigned } else { port })
        })
        .await
    }

    pub async fn cancel_forward_remote(&self, host: String, port: u32) -> Result<(), EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            handle.read().await.cancel_tcpip_forward(host, port).await?;
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
}
