use std::sync::Arc;

use russh_sftp::client::RawSftpSession;
use russh_sftp::protocol::{FileAttributes, OpenFlags, StatusCode};

use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::ssh::SshClient;
use crate::api::util::on_runtime;

pub struct SftpEntry {
    pub filename: String,
    pub longname: String,
    pub attrs: SftpAttrs,
}

pub struct SftpAttrs {
    pub size: Option<u64>,
    pub uid: Option<u32>,
    pub gid: Option<u32>,
    pub permissions: Option<u32>,
    pub atime: Option<u32>,
    pub mtime: Option<u32>,
}

impl From<&FileAttributes> for SftpAttrs {
    fn from(value: &FileAttributes) -> Self {
        SftpAttrs {
            size: value.size,
            uid: value.uid,
            gid: value.gid,
            permissions: value.permissions,
            atime: value.atime,
            mtime: value.mtime,
        }
    }
}

pub struct SftpSession {
    raw: Arc<RawSftpSession>,
}

pub struct SftpFile {
    raw: Arc<RawSftpSession>,
    handle: String,
    closed: Arc<std::sync::atomic::AtomicBool>,
}

impl SshClient {
    pub async fn sftp(&self) -> Result<SftpSession, EngineError> {
        let client = self.clone_ref();
        on_runtime(async move {
            let stream = client.open_subsystem_stream("sftp").await?;
            let config = russh_sftp::client::Config {
                request_timeout_secs: 30,
                ..Default::default()
            };
            let mut raw = RawSftpSession::new_with_config(stream, config);
            raw.init().await?;
            if let Ok(limits) = raw.limits().await {
                raw.set_limits(limits.into());
            }
            Ok(SftpSession { raw: Arc::new(raw) })
        })
        .await
    }
}

impl SftpSession {
    pub async fn list(&self, path: String) -> Result<Vec<SftpEntry>, EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let handle = raw.opendir(path).await?.handle;
            let mut out = Vec::new();
            loop {
                match raw.readdir(handle.clone()).await {
                    Ok(name) => {
                        for file in name.files {
                            out.push(SftpEntry {
                                attrs: SftpAttrs::from(&file.attrs),
                                filename: file.filename,
                                longname: file.longname,
                            });
                        }
                    }
                    Err(russh_sftp::client::error::Error::Status(status))
                        if status.status_code == StatusCode::Eof =>
                    {
                        break
                    }
                    Err(error) => {
                        let _ = raw.close(handle.clone()).await;
                        return Err(error.into());
                    }
                }
            }
            let _ = raw.close(handle).await;
            Ok(out)
        })
        .await
    }

    pub async fn stat(&self, path: String, follow_links: bool) -> Result<SftpAttrs, EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let attrs = if follow_links {
                raw.stat(path).await?.attrs
            } else {
                raw.lstat(path).await?.attrs
            };
            Ok(SftpAttrs::from(&attrs))
        })
        .await
    }

    pub async fn realpath(&self, path: String) -> Result<String, EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let name = raw.realpath(path).await?;
            name.files
                .into_iter()
                .next()
                .map(|f| f.filename)
                .ok_or_else(|| EngineError::new(EngineErrorKind::Sftp, "empty realpath reply"))
        })
        .await
    }

    pub async fn mkdir(&self, path: String) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            raw.mkdir(path, FileAttributes::empty()).await?;
            Ok(())
        })
        .await
    }

    pub async fn rmdir(&self, path: String) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            raw.rmdir(path).await?;
            Ok(())
        })
        .await
    }

    pub async fn remove(&self, path: String) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            raw.remove(path).await?;
            Ok(())
        })
        .await
    }

    pub async fn rename(&self, from: String, to: String) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            raw.rename(from, to).await?;
            Ok(())
        })
        .await
    }

    pub async fn set_permissions(&self, path: String, mode: u32) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let mut attrs = FileAttributes::empty();
            attrs.permissions = Some(mode);
            raw.setstat(path, attrs).await?;
            Ok(())
        })
        .await
    }

    pub async fn open(&self, path: String, flags: u32) -> Result<SftpFile, EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let handle = raw
                .open(
                    path,
                    OpenFlags::from_bits_truncate(flags),
                    FileAttributes::empty(),
                )
                .await?
                .handle;
            Ok(SftpFile {
                raw,
                handle,
                closed: Arc::new(std::sync::atomic::AtomicBool::new(false)),
            })
        })
        .await
    }

    pub async fn close(&self) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        on_runtime(async move {
            let _ = raw.close_session();
            Ok(())
        })
        .await
    }
}

impl SftpFile {
    pub async fn read(&self, offset: u64, len: u32) -> Result<Option<Vec<u8>>, EngineError> {
        let raw = self.raw.clone();
        let handle = self.handle.clone();
        on_runtime(async move {
            match raw.read(handle, offset, len).await {
                Ok(data) => Ok(Some(data.data)),
                Err(russh_sftp::client::error::Error::Status(status))
                    if status.status_code == StatusCode::Eof =>
                {
                    Ok(None)
                }
                Err(error) => Err(error.into()),
            }
        })
        .await
    }

    pub async fn write(&self, offset: u64, data: Vec<u8>) -> Result<(), EngineError> {
        let raw = self.raw.clone();
        let handle = self.handle.clone();
        on_runtime(async move {
            raw.write(handle, offset, data).await?;
            Ok(())
        })
        .await
    }

    pub async fn size(&self) -> Result<Option<u64>, EngineError> {
        let raw = self.raw.clone();
        let handle = self.handle.clone();
        on_runtime(async move { Ok(raw.fstat(handle).await?.attrs.size) }).await
    }

    pub async fn close(&self) -> Result<(), EngineError> {
        if self.closed.swap(true, std::sync::atomic::Ordering::SeqCst) {
            return Ok(());
        }
        let raw = self.raw.clone();
        let handle = self.handle.clone();
        on_runtime(async move {
            let _ = raw.close(handle).await;
            Ok(())
        })
        .await
    }
}

impl Drop for SftpFile {
    fn drop(&mut self) {
        if self.closed.swap(true, std::sync::atomic::Ordering::SeqCst) {
            return;
        }
        let raw = self.raw.clone();
        let handle = self.handle.clone();
        crate::api::util::RUNTIME.spawn(async move {
            let _ = raw.close(handle).await;
        });
    }
}
