use std::fmt;

use russh::keys::ssh_key;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EngineErrorKind {
    HostKey,
    Auth,
    AuthAbort,
    KeyDecrypt,
    KeyDecode,
    Timeout,
    Socket,
    Handshake,
    Channel,
    ChannelRequest,
    Cancelled,
    Disconnect,
    SftpStatus,
    Sftp,
    Internal,
}

#[derive(Debug, Clone)]
pub struct EngineError {
    pub kind: EngineErrorKind,
    pub message: String,
    pub code: Option<u32>,
}

impl EngineError {
    pub(crate) fn new(kind: EngineErrorKind, message: impl Into<String>) -> EngineError {
        EngineError {
            kind,
            message: message.into(),
            code: None,
        }
    }

    pub(crate) fn coded(
        kind: EngineErrorKind,
        code: u32,
        message: impl Into<String>,
    ) -> EngineError {
        EngineError {
            kind,
            message: message.into(),
            code: Some(code),
        }
    }

    pub(crate) fn channel(error: impl fmt::Display) -> EngineError {
        EngineError::new(EngineErrorKind::Channel, error.to_string())
    }
}

impl fmt::Display for EngineError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:?}: {}", self.kind, self.message)
    }
}

impl std::error::Error for EngineError {}

impl From<russh::keys::Error> for EngineError {
    fn from(error: russh::keys::Error) -> EngineError {
        EngineError::new(classify_key(&error), error.to_string())
    }
}

impl From<russh::Error> for EngineError {
    fn from(error: russh::Error) -> EngineError {
        let kind = match &error {
            russh::Error::UnknownKey => EngineErrorKind::HostKey,
            russh::Error::IO(_) | russh::Error::HUP | russh::Error::SendError => {
                EngineErrorKind::Socket
            }
            russh::Error::Disconnect => EngineErrorKind::Disconnect,
            russh::Error::ConnectionTimeout
            | russh::Error::KeepaliveTimeout
            | russh::Error::InactivityTimeout
            | russh::Error::Elapsed(_) => EngineErrorKind::Timeout,
            russh::Error::ChannelOpenFailure(_) => EngineErrorKind::Channel,
            russh::Error::Keys(inner) => {
                return EngineError::new(classify_key(inner), error.to_string())
            }
            _ => EngineErrorKind::Handshake,
        };
        EngineError::new(kind, error.to_string())
    }
}

fn classify_key(error: &russh::keys::Error) -> EngineErrorKind {
    match error {
        russh::keys::Error::KeyIsEncrypted
        | russh::keys::Error::Unpad(_)
        | russh::keys::Error::Pad(_)
        | russh::keys::Error::SshKey(ssh_key::Error::Crypto | ssh_key::Error::Encrypted) => {
            EngineErrorKind::KeyDecrypt
        }
        _ => EngineErrorKind::KeyDecode,
    }
}

impl From<russh::AgentAuthError> for EngineError {
    fn from(error: russh::AgentAuthError) -> EngineError {
        EngineError::new(EngineErrorKind::Auth, error.to_string())
    }
}

impl From<std::io::Error> for EngineError {
    fn from(error: std::io::Error) -> EngineError {
        EngineError::new(EngineErrorKind::Socket, error.to_string())
    }
}

impl From<tokio::task::JoinError> for EngineError {
    fn from(error: tokio::task::JoinError) -> EngineError {
        EngineError::new(EngineErrorKind::Internal, error.to_string())
    }
}

impl From<russh_sftp::client::error::Error> for EngineError {
    fn from(error: russh_sftp::client::error::Error) -> EngineError {
        use russh_sftp::protocol::StatusCode;
        match error {
            russh_sftp::client::error::Error::Status(status) => {
                let code = match status.status_code {
                    StatusCode::Ok => 0,
                    StatusCode::Eof => 1,
                    StatusCode::NoSuchFile => 2,
                    StatusCode::PermissionDenied => 3,
                    StatusCode::Failure => 4,
                    StatusCode::BadMessage => 5,
                    StatusCode::NoConnection => 6,
                    StatusCode::ConnectionLost => 7,
                    StatusCode::OpUnsupported => 8,
                };
                EngineError::coded(EngineErrorKind::SftpStatus, code, status.error_message)
            }
            other => EngineError::new(EngineErrorKind::Sftp, other.to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_host_key_is_a_host_key_error() {
        assert_eq!(
            EngineError::from(russh::Error::UnknownKey).kind,
            EngineErrorKind::HostKey
        );
    }

    #[test]
    fn an_encrypted_key_without_passphrase_needs_decryption() {
        let error = EngineError::from(russh::keys::Error::KeyIsEncrypted);
        assert_eq!(error.kind, EngineErrorKind::KeyDecrypt);
    }

    #[test]
    fn a_corrupt_key_is_a_decode_error() {
        let error = EngineError::from(russh::keys::Error::KeyIsCorrupt);
        assert_eq!(error.kind, EngineErrorKind::KeyDecode);
    }

    #[test]
    fn io_errors_are_socket_errors() {
        let error = EngineError::from(std::io::Error::other("reset"));
        assert_eq!(error.kind, EngineErrorKind::Socket);
        assert_eq!(error.message, "reset");
    }

    #[test]
    fn coded_errors_keep_their_code() {
        let error = EngineError::coded(EngineErrorKind::SftpStatus, 3, "denied");
        assert_eq!(error.code, Some(3));
    }
}
