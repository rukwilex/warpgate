use std::future::Future;
use std::sync::Arc;
use std::time::Duration;

use futures::FutureExt;
use russh::{ChannelMsg, ChannelReadHalf};

use crate::api::channel::ChannelChunk;
use crate::api::error::{EngineError, EngineErrorKind};

const COALESCE_WINDOW: Duration = Duration::from_millis(1);
const COALESCE_BELOW: usize = 16 * 1024;

pub(crate) type Pending = Arc<std::sync::Mutex<Vec<ChannelMsg>>>;

pub(crate) trait MessageSource: Send {
    fn next_message(&mut self) -> impl Future<Output = Option<ChannelMsg>> + Send;
}

impl MessageSource for ChannelReadHalf {
    fn next_message(&mut self) -> impl Future<Output = Option<ChannelMsg>> + Send {
        self.wait()
    }
}

pub(crate) fn take_pending(pending: &Pending) -> Vec<ChannelMsg> {
    let mut stashed = std::mem::take(
        &mut *pending
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()),
    );
    stashed.reverse();
    stashed
}

pub(crate) fn requeue(pending: &Pending, mut stashed: Vec<ChannelMsg>) {
    if stashed.is_empty() {
        return;
    }
    stashed.reverse();
    let mut slot = pending
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    stashed.append(&mut slot);
    *slot = stashed;
}

fn record_exit(exit: &std::sync::Mutex<Option<u32>>, status: Option<u32>) -> Option<u32> {
    let mut slot = exit.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    if status.is_some() {
        *slot = status;
    }
    *slot
}

pub(crate) async fn read_into<R: MessageSource>(
    slot: &mut Option<R>,
    stashed: &mut Vec<ChannelMsg>,
    exit: &std::sync::Mutex<Option<u32>>,
    limit: usize,
) -> ChannelChunk {
    let mut chunk = ChannelChunk {
        data: Vec::new(),
        extended: Vec::new(),
        exit_status: None,
        closed: false,
    };
    let Some(reader) = slot.as_mut() else {
        chunk.closed = true;
        chunk.exit_status = record_exit(exit, None);
        return chunk;
    };
    let mut first = true;
    let mut deadline = tokio::time::Instant::now() + COALESCE_WINDOW;
    loop {
        let next = if let Some(message) = stashed.pop() {
            first = false;
            Some(message)
        } else if first {
            first = false;
            let message = reader.next_message().await;
            deadline = tokio::time::Instant::now() + COALESCE_WINDOW;
            message
        } else {
            match reader.next_message().now_or_never() {
                Some(message) => message,
                None => {
                    let small = chunk.data.len() + chunk.extended.len() < COALESCE_BELOW;
                    let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
                    if !small || remaining.is_zero() {
                        break;
                    }
                    match tokio::time::timeout(remaining, reader.next_message()).await {
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
                chunk.exit_status = record_exit(exit, Some(exit_status));
            }
            Some(ChannelMsg::Close) | None => {
                chunk.closed = true;
                *slot = None;
                break;
            }
            Some(_) => {}
        }
        if chunk.data.len() + chunk.extended.len() >= limit {
            break;
        }
    }
    if chunk.exit_status.is_none() {
        chunk.exit_status = record_exit(exit, None);
    }
    chunk
}

pub(crate) async fn expect_success<R: MessageSource>(
    slot: &mut Option<R>,
    pending: &Pending,
) -> Result<(), EngineError> {
    let Some(reader) = slot.as_mut() else {
        return Err(EngineError::new(
            EngineErrorKind::Channel,
            "the channel is closed",
        ));
    };
    loop {
        match reader.next_message().await {
            Some(ChannelMsg::Success) => return Ok(()),
            Some(ChannelMsg::Failure) => {
                return Err(EngineError::new(
                    EngineErrorKind::ChannelRequest,
                    "the server refused the request",
                ));
            }
            Some(ChannelMsg::Close) | None => {
                return Err(EngineError::new(
                    EngineErrorKind::Channel,
                    "the channel closed",
                ));
            }
            Some(
                message @ (ChannelMsg::Data { .. }
                | ChannelMsg::ExtendedData { .. }
                | ChannelMsg::ExitStatus { .. }
                | ChannelMsg::Eof),
            ) => {
                pending
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner())
                    .push(message);
            }
            Some(_) => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;

    struct Script(VecDeque<ChannelMsg>);

    impl MessageSource for Script {
        fn next_message(&mut self) -> impl Future<Output = Option<ChannelMsg>> + Send {
            let next = self.0.pop_front();
            async move {
                match next {
                    Some(message) => Some(message),
                    None => std::future::pending().await,
                }
            }
        }
    }

    fn data(bytes: &[u8]) -> ChannelMsg {
        ChannelMsg::Data {
            data: bytes.to_vec().into(),
        }
    }

    fn pending_of(messages: Vec<ChannelMsg>) -> Pending {
        Arc::new(std::sync::Mutex::new(messages))
    }

    fn exit() -> std::sync::Mutex<Option<u32>> {
        std::sync::Mutex::new(None)
    }

    #[tokio::test]
    async fn a_size_limited_read_keeps_the_unread_deferred_messages() {
        let pending = pending_of(vec![data(b"aaaa"), data(b"bbbb"), data(b"cccc")]);
        let mut slot = Some(Script(VecDeque::new()));
        let mut stashed = take_pending(&pending);
        let chunk = read_into(&mut slot, &mut stashed, &exit(), 6).await;
        requeue(&pending, stashed);
        assert_eq!(chunk.data, b"aaaabbbb");
        let mut stashed = take_pending(&pending);
        let rest = read_into(&mut slot, &mut stashed, &exit(), 64).await;
        assert_eq!(rest.data, b"cccc");
        assert!(stashed.is_empty());
    }

    #[tokio::test]
    async fn requeued_messages_stay_ahead_of_newer_ones() {
        let pending = pending_of(vec![data(b"new")]);
        requeue(&pending, vec![data(b"second"), data(b"first")]);
        let order: Vec<Vec<u8>> = pending
            .lock()
            .unwrap()
            .iter()
            .map(|message| match message {
                ChannelMsg::Data { data } => data.to_vec(),
                _ => Vec::new(),
            })
            .collect();
        assert_eq!(
            order,
            vec![b"first".to_vec(), b"second".to_vec(), b"new".to_vec()]
        );
    }

    #[tokio::test]
    async fn deferred_messages_come_before_live_ones() {
        let mut slot = Some(Script(VecDeque::from(vec![data(b"live")])));
        let mut stashed = vec![data(b"early")];
        let chunk = read_into(&mut slot, &mut stashed, &exit(), 64).await;
        assert_eq!(chunk.data, b"earlylive");
    }

    #[tokio::test]
    async fn close_ends_the_channel_and_keeps_the_exit_status() {
        let status = exit();
        let mut slot = Some(Script(VecDeque::from(vec![
            data(b"bye"),
            ChannelMsg::ExitStatus { exit_status: 3 },
            ChannelMsg::Close,
        ])));
        let chunk = read_into(&mut slot, &mut Vec::new(), &status, 64).await;
        assert!(chunk.closed);
        assert_eq!(chunk.exit_status, Some(3));
        assert!(slot.is_none());
        let after = read_into(&mut slot, &mut Vec::new(), &status, 64).await;
        assert!(after.closed);
        assert_eq!(after.exit_status, Some(3));
    }

    #[tokio::test]
    async fn output_before_the_request_reply_is_deferred() {
        let pending = pending_of(Vec::new());
        let mut slot = Some(Script(VecDeque::from(vec![
            data(b"motd"),
            ChannelMsg::Success,
        ])));
        expect_success(&mut slot, &pending).await.unwrap();
        assert_eq!(pending.lock().unwrap().len(), 1);
    }

    #[tokio::test]
    async fn a_refused_request_is_a_channel_request_error() {
        let mut slot = Some(Script(VecDeque::from(vec![ChannelMsg::Failure])));
        let error = expect_success(&mut slot, &pending_of(Vec::new()))
            .await
            .unwrap_err();
        assert_eq!(error.kind, EngineErrorKind::ChannelRequest);
    }
}
