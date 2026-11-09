use crate::engine::Shared;

pub(crate) struct VersionSniffer<S> {
    inner: S,
    line: Vec<u8>,
    found: Shared<String>,
    done: bool,
}

impl<S> VersionSniffer<S> {
    const LIMIT: usize = 255;

    pub(crate) fn new(inner: S, found: Shared<String>) -> VersionSniffer<S> {
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
    use crate::engine::shared;

    fn sniff(chunks: &[&[u8]]) -> Option<String> {
        let found: Shared<String> = shared();
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
