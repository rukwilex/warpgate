use std::future::Future;
use std::sync::Arc;

use once_cell::sync::Lazy;
use sha2::{Digest, Sha256};
use tokio::io::AsyncReadExt;
use tokio::runtime::Runtime;
use tokio::sync::Notify;

use crate::api::error::EngineError;

pub(crate) static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .thread_name("warpgate-engine")
        .enable_all()
        .build()
        .expect("tokio runtime")
});

pub(crate) async fn on_runtime<F, T>(future: F) -> Result<T, EngineError>
where
    F: Future<Output = Result<T, EngineError>> + Send + 'static,
    T: Send + 'static,
{
    RUNTIME.spawn(future).await?
}

pub struct CancelToken {
    pub(crate) notify: Arc<Notify>,
    pub(crate) cancelled: Arc<std::sync::atomic::AtomicBool>,
}

impl CancelToken {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> CancelToken {
        CancelToken {
            notify: Arc::new(Notify::new()),
            cancelled: Arc::new(std::sync::atomic::AtomicBool::new(false)),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.cancelled
            .store(true, std::sync::atomic::Ordering::SeqCst);
        self.notify.notify_waiters();
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(std::sync::atomic::Ordering::SeqCst)
    }

    pub(crate) fn parts(&self) -> (Arc<Notify>, Arc<std::sync::atomic::AtomicBool>) {
        (self.notify.clone(), self.cancelled.clone())
    }
}

pub(crate) async fn until_cancelled(notify: Arc<Notify>, flag: Arc<std::sync::atomic::AtomicBool>) {
    loop {
        let waiter = notify.notified();
        if flag.load(std::sync::atomic::Ordering::SeqCst) {
            return;
        }
        waiter.await;
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn engine_version() -> String {
    format!("warpgate_engine {} (russh 0.65)", env!("CARGO_PKG_VERSION"))
}

pub async fn sha256_file(path: String) -> Result<String, EngineError> {
    on_runtime(async move {
        let mut file = tokio::fs::File::open(&path).await?;
        let mut hasher = Sha256::new();
        let mut buffer = vec![0u8; 1 << 20];
        loop {
            let read = file.read(&mut buffer).await?;
            if read == 0 {
                break;
            }
            hasher.update(&buffer[..read]);
        }
        Ok(hasher
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect())
    })
    .await
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
