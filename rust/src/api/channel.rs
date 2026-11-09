use std::sync::Arc;

use russh::client::Msg;
use russh::{Channel, ChannelReadHalf, ChannelWriteHalf};
use tokio::sync::Mutex;

use crate::api::connection::SshClient;
use crate::api::error::EngineError;
use crate::api::util::on_runtime;
use crate::engine::reader::{expect_success, read_into, requeue, take_pending, Pending};

pub struct ChannelChunk {
    pub data: Vec<u8>,
    pub extended: Vec<u8>,
    pub exit_status: Option<u32>,
    pub closed: bool,
}

#[derive(Clone)]
pub struct SshChannel {
    read: Arc<Mutex<Option<ChannelReadHalf>>>,
    write: Arc<ChannelWriteHalf<Msg>>,
    exit: Arc<std::sync::Mutex<Option<u32>>>,
    pending: Pending,
}

impl SshClient {
    pub async fn open_session(&self) -> Result<SshChannel, EngineError> {
        let handle = self.handle.clone();
        on_runtime(async move {
            let channel = handle
                .read()
                .await
                .channel_open_session()
                .await
                .map_err(EngineError::channel)?;
            Ok(SshChannel::new(channel))
        })
        .await
    }
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
            expect_success(&mut *read.lock().await, &pending).await
        })
        .await
    }

    pub async fn exec(&self, command: String) -> Result<(), EngineError> {
        let write = self.write.clone();
        let read = self.read.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            write.exec(true, command).await?;
            expect_success(&mut *read.lock().await, &pending).await
        })
        .await
    }

    pub async fn read(&self, max_bytes: u32) -> Result<ChannelChunk, EngineError> {
        let read = self.read.clone();
        let exit = self.exit.clone();
        let pending = self.pending.clone();
        on_runtime(async move {
            let mut guard = read.lock().await;
            let mut stashed = take_pending(&pending);
            let chunk = read_into(&mut guard, &mut stashed, &exit, max_bytes as usize).await;
            requeue(&pending, stashed);
            Ok(chunk)
        })
        .await
    }

    pub async fn write(&self, data: Vec<u8>) -> Result<(), EngineError> {
        let write = self.write.clone();
        on_runtime(async move {
            write.data(&data[..]).await.map_err(EngineError::channel)?;
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
        *self
            .exit
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }
}
