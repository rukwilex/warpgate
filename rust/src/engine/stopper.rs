use std::future::Future;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;

use tokio::sync::Notify;

use crate::api::error::{EngineError, EngineErrorKind};
use crate::api::util::until_cancelled;

pub(crate) struct Stopper {
    pub(crate) notify: Arc<Notify>,
    pub(crate) flag: Arc<AtomicBool>,
}

impl Stopper {
    pub(crate) async fn guard<T>(
        self,
        body: impl Future<Output = Result<T, EngineError>>,
    ) -> Result<T, EngineError> {
        tokio::select! {
            _ = until_cancelled(self.notify, self.flag) => {
                Err(EngineError::new(EngineErrorKind::Cancelled, "the connection was closed"))
            }
            result = body => result,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::Ordering;
    use std::time::Duration;

    #[tokio::test]
    async fn a_stop_aborts_a_body_that_never_finishes() {
        let notify = Arc::new(Notify::new());
        let flag = Arc::new(AtomicBool::new(false));
        let stopper = Stopper {
            notify: notify.clone(),
            flag: flag.clone(),
        };
        let guarded =
            tokio::spawn(stopper.guard(std::future::pending::<Result<(), EngineError>>()));
        tokio::time::sleep(Duration::from_millis(10)).await;
        flag.store(true, Ordering::SeqCst);
        notify.notify_waiters();
        let error = guarded.await.unwrap().unwrap_err();
        assert_eq!(error.kind, EngineErrorKind::Cancelled);
    }

    #[tokio::test]
    async fn a_finished_body_keeps_its_result() {
        let stopper = Stopper {
            notify: Arc::new(Notify::new()),
            flag: Arc::new(AtomicBool::new(false)),
        };
        assert_eq!(stopper.guard(async { Ok(7) }).await.unwrap(), 7);
    }

    #[tokio::test]
    async fn an_already_stopped_client_does_not_run_the_body() {
        let stopper = Stopper {
            notify: Arc::new(Notify::new()),
            flag: Arc::new(AtomicBool::new(true)),
        };
        let error = stopper
            .guard(std::future::pending::<Result<(), EngineError>>())
            .await
            .unwrap_err();
        assert_eq!(error.kind, EngineErrorKind::Cancelled);
    }
}
