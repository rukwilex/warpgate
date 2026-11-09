pub(crate) mod handler;
pub(crate) mod reader;
pub(crate) mod sniffer;
pub(crate) mod stopper;

pub(crate) type Shared<T> = std::sync::Arc<std::sync::Mutex<Option<T>>>;

pub(crate) fn shared<T>() -> Shared<T> {
    std::sync::Arc::new(std::sync::Mutex::new(None))
}
