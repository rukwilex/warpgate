#![allow(
    non_camel_case_types,
    unused,
    non_snake_case,
    clippy::needless_return,
    clippy::redundant_closure_call,
    clippy::redundant_closure,
    clippy::useless_conversion,
    clippy::unit_arg,
    clippy::unused_unit,
    clippy::double_parens,
    clippy::let_and_return,
    clippy::too_many_arguments,
    clippy::match_single_binding,
    clippy::clone_on_copy,
    clippy::let_unit_value,
    clippy::deref_addrof,
    clippy::explicit_auto_deref,
    clippy::borrow_deref_ref,
    clippy::uninlined_format_args,
    clippy::needless_borrow
)]

use crate::api::sftp::*;
use crate::api::ssh::*;
use crate::api::util::*;
use flutter_rust_bridge::for_generated::byteorder::{NativeEndian, ReadBytesExt, WriteBytesExt};
use flutter_rust_bridge::for_generated::{transform_result_dco, Lifetimeable, Lockable};
use flutter_rust_bridge::{Handler, IntoIntoDart};

flutter_rust_bridge::frb_generated_boilerplate!(
    default_stream_sink_codec = SseCodec,
    default_rust_opaque = RustOpaqueMoi,
    default_rust_auto_opaque = RustAutoOpaqueMoi,
);
pub(crate) const FLUTTER_RUST_BRIDGE_CODEGEN_VERSION: &str = "2.12.0";
pub(crate) const FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH: i32 = 1760737308;

flutter_rust_bridge::frb_generated_default_handler!();

fn wire__crate__api__util__CancelToken_cancel_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "CancelToken_cancel",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    crate::api::util::CancelToken::cancel(&*api_that_guard);
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__util__CancelToken_is_cancelled_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "CancelToken_is_cancelled",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(crate::api::util::CancelToken::is_cancelled(
                    &*api_that_guard,
                ))?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__util__CancelToken_new_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "CancelToken_new",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let output_ok = Result::<_, ()>::Ok(crate::api::util::CancelToken::new())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_channel_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_get_channel",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(api_that_guard.channel.clone())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_connected_host_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_get_connected_host",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(api_that_guard.connected_host.clone())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_connected_port_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_get_connected_port",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(api_that_guard.connected_port.clone())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_origin_host_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_get_origin_host",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(api_that_guard.origin_host.clone())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_origin_port_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_get_origin_port",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(api_that_guard.origin_port.clone())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_channel_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_set_channel",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            let api_channel = <SshChannel>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, true,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref_mut()),
                        _ => unreachable!(),
                    }
                }
                let mut api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    {
                        api_that_guard.channel = api_channel;
                    };
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_connected_host_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_set_connected_host",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            let api_connected_host = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, true,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref_mut()),
                        _ => unreachable!(),
                    }
                }
                let mut api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    {
                        api_that_guard.connected_host = api_connected_host;
                    };
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_connected_port_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_set_connected_port",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            let api_connected_port = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, true,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref_mut()),
                        _ => unreachable!(),
                    }
                }
                let mut api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    {
                        api_that_guard.connected_port = api_connected_port;
                    };
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_origin_host_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_set_origin_host",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            let api_origin_host = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, true,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref_mut()),
                        _ => unreachable!(),
                    }
                }
                let mut api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    {
                        api_that_guard.origin_host = api_origin_host;
                    };
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_origin_port_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "ForwardedConnection_auto_accessor_set_origin_port",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
            >>::sse_decode(&mut deserializer);
            let api_origin_port = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, true,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref_mut()),
                        _ => unreachable!(),
                    }
                }
                let mut api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok({
                    {
                        api_that_guard.origin_port = api_origin_port;
                    };
                })?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__sftp__SftpFile_close_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpFile_close",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpFile::close(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpFile_read_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpFile_read",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>,
            >>::sse_decode(&mut deserializer);
            let api_offset = <u64>::sse_decode(&mut deserializer);
            let api_len = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpFile::read(&*api_that_guard, api_offset, api_len)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpFile_size_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpFile_size",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpFile::size(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpFile_write_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpFile_write",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>,
            >>::sse_decode(&mut deserializer);
            let api_offset = <u64>::sse_decode(&mut deserializer);
            let api_data = <Vec<u8>>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpFile::write(
                            &*api_that_guard,
                            api_offset,
                            api_data,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_close_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_close",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::close(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_list_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_list",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::list(&*api_that_guard, api_path).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_mkdir_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_mkdir",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::mkdir(&*api_that_guard, api_path)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_open_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_open",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            let api_flags = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpSession::open(
                            &*api_that_guard,
                            api_path,
                            api_flags,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_realpath_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_realpath",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::realpath(&*api_that_guard, api_path)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_remove_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_remove",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::remove(&*api_that_guard, api_path)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_rename_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_rename",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_from = <String>::sse_decode(&mut deserializer);
            let api_to = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpSession::rename(
                            &*api_that_guard,
                            api_from,
                            api_to,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_rmdir_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_rmdir",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::sftp::SftpSession::rmdir(&*api_that_guard, api_path)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_set_permissions_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_set_permissions",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            let api_mode = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpSession::set_permissions(
                            &*api_that_guard,
                            api_path,
                            api_mode,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__sftp__SftpSession_stat_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SftpSession_stat",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
            >>::sse_decode(&mut deserializer);
            let api_path = <String>::sse_decode(&mut deserializer);
            let api_follow_links = <bool>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::sftp::SftpSession::stat(
                            &*api_that_guard,
                            api_path,
                            api_follow_links,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_close_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_close",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshChannel::close(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_eof_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_eof",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshChannel::eof(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_exec_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_exec",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_command = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshChannel::exec(&*api_that_guard, api_command)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_exit_status_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_exit_status",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(crate::api::ssh::SshChannel::exit_status(
                    &*api_that_guard,
                ))?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__SshChannel_read_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_read",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_max_bytes = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshChannel::read(&*api_that_guard, api_max_bytes)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_request_pty_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_request_pty",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_term = <String>::sse_decode(&mut deserializer);
            let api_columns = <u32>::sse_decode(&mut deserializer);
            let api_rows = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshChannel::request_pty(
                            &*api_that_guard,
                            api_term,
                            api_columns,
                            api_rows,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_request_shell_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_request_shell",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshChannel::request_shell(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_set_env_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_set_env",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_name = <String>::sse_decode(&mut deserializer);
            let api_value = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshChannel::set_env(
                            &*api_that_guard,
                            api_name,
                            api_value,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_window_change_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_window_change",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_columns = <u32>::sse_decode(&mut deserializer);
            let api_rows = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshChannel::window_change(
                            &*api_that_guard,
                            api_columns,
                            api_rows,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshChannel_write_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshChannel_write",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
            >>::sse_decode(&mut deserializer);
            let api_data = <Vec<u8>>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshChannel::write(&*api_that_guard, api_data).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_accept_forwarded_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_accept_forwarded",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::accept_forwarded(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_auth_agent_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_auth_agent",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_user = <String>::sse_decode(&mut deserializer);
            let api_socket = <Option<String>>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::auth_agent(
                            &*api_that_guard,
                            api_user,
                            api_socket,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_auth_key_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_auth_key",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_user = <String>::sse_decode(&mut deserializer);
            let api_pem = <String>::sse_decode(&mut deserializer);
            let api_passphrase = <Option<String>>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::auth_key(
                            &*api_that_guard,
                            api_user,
                            api_pem,
                            api_passphrase,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_auth_keyboard_interactive_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec,_,_,_>(flutter_rust_bridge::for_generated::TaskInfo{ debug_name: "SshClient_auth_keyboard_interactive", port: Some(port_), mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal }, move || {
            let message = unsafe { flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(ptr_, rust_vec_len_, data_len_) };
            let mut deserializer = flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>>::sse_decode(&mut deserializer);
let api_user = <String>::sse_decode(&mut deserializer);
let api_responder = decode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(<flutter_rust_bridge::DartOpaque>::sse_decode(&mut deserializer));deserializer.end(); move |context| async move {
                    transform_result_sse::<_, crate::api::error::EngineError>((move || async move {
                        let mut api_that_guard = None;
let decode_indices_ = flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(&api_that, 0, false)]);
        for i in decode_indices_ {
            match i {
                0 => api_that_guard = Some(api_that.lockable_decode_async_ref().await),
                _ => unreachable!(),
            }
        }
        let api_that_guard = api_that_guard.unwrap();
 let output_ok = crate::api::ssh::SshClient::auth_keyboard_interactive(&*api_that_guard, api_user, api_responder).await?;   Ok(output_ok)
                    })().await)
                } })
}
fn wire__crate__api__ssh__SshClient_auth_none_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_auth_none",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_user = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::auth_none(&*api_that_guard, api_user)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_auth_password_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_auth_password",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_user = <String>::sse_decode(&mut deserializer);
            let api_password = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::auth_password(
                            &*api_that_guard,
                            api_user,
                            api_password,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_cancel_forward_remote_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_cancel_forward_remote",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_host = <String>::sse_decode(&mut deserializer);
            let api_port = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::cancel_forward_remote(
                            &*api_that_guard,
                            api_host,
                            api_port,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_connect_via_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_connect_via",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_params = <crate::api::ssh::ConnectParams>::sse_decode(&mut deserializer);
            let api_verifier = decode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
                <flutter_rust_bridge::DartOpaque>::sse_decode(&mut deserializer),
            );
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::connect_via(
                            &*api_that_guard,
                            api_params,
                            api_verifier,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_disconnect_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_disconnect",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::disconnect(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_forward_remote_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_forward_remote",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_host = <String>::sse_decode(&mut deserializer);
            let api_port = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::forward_remote(
                            &*api_that_guard,
                            api_host,
                            api_port,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_is_closed_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_is_closed",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok =
                    Result::<_, ()>::Ok(crate::api::ssh::SshClient::is_closed(&*api_that_guard))?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__SshClient_open_direct_tcpip_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_open_direct_tcpip",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_host = <String>::sse_decode(&mut deserializer);
            let api_port = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::open_direct_tcpip(
                            &*api_that_guard,
                            api_host,
                            api_port,
                        )
                        .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_open_session_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_open_session",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::open_session(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_ping_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_ping",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            let api_timeout_ms = <u32>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::ping(&*api_that_guard, api_timeout_ms)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_remote_version_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_remote_version",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let mut api_that_guard = None;
                let decode_indices_ =
                    flutter_rust_bridge::for_generated::lockable_compute_decode_order(vec![
                        flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                            &api_that, 0, false,
                        ),
                    ]);
                for i in decode_indices_ {
                    match i {
                        0 => api_that_guard = Some(api_that.lockable_decode_sync_ref()),
                        _ => unreachable!(),
                    }
                }
                let api_that_guard = api_that_guard.unwrap();
                let output_ok = Result::<_, ()>::Ok(crate::api::ssh::SshClient::remote_version(
                    &*api_that_guard,
                ))?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__ssh__SshClient_sftp_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_sftp",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok = crate::api::ssh::SshClient::sftp(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__SshClient_wait_closed_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "SshClient_wait_closed",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_that = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
            >>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_that_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_that, 0, false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_that_guard =
                                        Some(api_that.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_that_guard = api_that_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::SshClient::wait_closed(&*api_that_guard).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__ssh__connect_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "connect",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_params = <crate::api::ssh::ConnectParams>::sse_decode(&mut deserializer);
            let api_cancel = <RustOpaqueMoi<
                flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>,
            >>::sse_decode(&mut deserializer);
            let api_verifier = decode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
                <flutter_rust_bridge::DartOpaque>::sse_decode(&mut deserializer),
            );
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let mut api_cancel_guard = None;
                        let decode_indices_ =
                            flutter_rust_bridge::for_generated::lockable_compute_decode_order(
                                vec![flutter_rust_bridge::for_generated::LockableOrderInfo::new(
                                    &api_cancel,
                                    0,
                                    false,
                                )],
                            );
                        for i in decode_indices_ {
                            match i {
                                0 => {
                                    api_cancel_guard =
                                        Some(api_cancel.lockable_decode_async_ref().await)
                                }
                                _ => unreachable!(),
                            }
                        }
                        let api_cancel_guard = api_cancel_guard.unwrap();
                        let output_ok =
                            crate::api::ssh::connect(api_params, &*api_cancel_guard, api_verifier)
                                .await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}
fn wire__crate__api__util__engine_version_impl(
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_sync::<flutter_rust_bridge::for_generated::SseCodec, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "engine_version",
            port: None,
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Sync,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            deserializer.end();
            transform_result_sse::<_, ()>((move || {
                let output_ok = Result::<_, ()>::Ok(crate::api::util::engine_version())?;
                Ok(output_ok)
            })())
        },
    )
}
fn wire__crate__api__util__init_app_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_normal::<flutter_rust_bridge::for_generated::SseCodec, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "init_app",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            deserializer.end();
            move |context| {
                transform_result_sse::<_, ()>((move || {
                    let output_ok = Result::<_, ()>::Ok({
                        crate::api::util::init_app();
                    })?;
                    Ok(output_ok)
                })())
            }
        },
    )
}
fn wire__crate__api__util__sha256_file_impl(
    port_: flutter_rust_bridge::for_generated::MessagePort,
    ptr_: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len_: i32,
    data_len_: i32,
) {
    FLUTTER_RUST_BRIDGE_HANDLER.wrap_async::<flutter_rust_bridge::for_generated::SseCodec, _, _, _>(
        flutter_rust_bridge::for_generated::TaskInfo {
            debug_name: "sha256_file",
            port: Some(port_),
            mode: flutter_rust_bridge::for_generated::FfiCallMode::Normal,
        },
        move || {
            let message = unsafe {
                flutter_rust_bridge::for_generated::Dart2RustMessageSse::from_wire(
                    ptr_,
                    rust_vec_len_,
                    data_len_,
                )
            };
            let mut deserializer =
                flutter_rust_bridge::for_generated::SseDeserializer::new(message);
            let api_path = <String>::sse_decode(&mut deserializer);
            deserializer.end();
            move |context| async move {
                transform_result_sse::<_, crate::api::error::EngineError>(
                    (move || async move {
                        let output_ok = crate::api::util::sha256_file(api_path).await?;
                        Ok(output_ok)
                    })()
                    .await,
                )
            }
        },
    )
}

fn decode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    dart_opaque: flutter_rust_bridge::DartOpaque,
) -> impl Fn(String, String) -> flutter_rust_bridge::DartFnFuture<bool> {
    use flutter_rust_bridge::IntoDart;

    async fn body(
        dart_opaque: flutter_rust_bridge::DartOpaque,
        arg0: String,
        arg1: String,
    ) -> bool {
        let args = vec![
            arg0.into_into_dart().into_dart(),
            arg1.into_into_dart().into_dart(),
        ];
        let message = FLUTTER_RUST_BRIDGE_HANDLER
            .dart_fn_invoke(dart_opaque, args)
            .await;

        let mut deserializer = flutter_rust_bridge::for_generated::SseDeserializer::new(message);
        let action = deserializer.cursor.read_u8().unwrap();
        let ans = match action {
            0 => std::result::Result::Ok(<bool>::sse_decode(&mut deserializer)),
            1 => std::result::Result::Err(
                <flutter_rust_bridge::for_generated::anyhow::Error>::sse_decode(&mut deserializer),
            ),
            _ => unreachable!(),
        };
        deserializer.end();
        let ans = ans.expect("Dart throws exception but Rust side assume it is not failable");
        ans
    }

    move |arg0: String, arg1: String| {
        flutter_rust_bridge::for_generated::convert_into_dart_fn_future(body(
            dart_opaque.clone(),
            arg0,
            arg1,
        ))
    }
}
fn decode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    dart_opaque: flutter_rust_bridge::DartOpaque,
) -> impl Fn(
    String,
    String,
    Vec<String>,
    Vec<bool>,
) -> flutter_rust_bridge::DartFnFuture<Option<Vec<String>>> {
    use flutter_rust_bridge::IntoDart;

    async fn body(
        dart_opaque: flutter_rust_bridge::DartOpaque,
        arg0: String,
        arg1: String,
        arg2: Vec<String>,
        arg3: Vec<bool>,
    ) -> Option<Vec<String>> {
        let args = vec![
            arg0.into_into_dart().into_dart(),
            arg1.into_into_dart().into_dart(),
            arg2.into_into_dart().into_dart(),
            arg3.into_into_dart().into_dart(),
        ];
        let message = FLUTTER_RUST_BRIDGE_HANDLER
            .dart_fn_invoke(dart_opaque, args)
            .await;

        let mut deserializer = flutter_rust_bridge::for_generated::SseDeserializer::new(message);
        let action = deserializer.cursor.read_u8().unwrap();
        let ans = match action {
            0 => std::result::Result::Ok(<Option<Vec<String>>>::sse_decode(&mut deserializer)),
            1 => std::result::Result::Err(
                <flutter_rust_bridge::for_generated::anyhow::Error>::sse_decode(&mut deserializer),
            ),
            _ => unreachable!(),
        };
        deserializer.end();
        let ans = ans.expect("Dart throws exception but Rust side assume it is not failable");
        ans
    }

    move |arg0: String, arg1: String, arg2: Vec<String>, arg3: Vec<bool>| {
        flutter_rust_bridge::for_generated::convert_into_dart_fn_future(body(
            dart_opaque.clone(),
            arg0,
            arg1,
            arg2,
            arg3,
        ))
    }
}
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>
);
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>
);
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>
);
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>
);
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>
);
flutter_rust_bridge::frb_generated_moi_arc_impl_value!(
    flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>
);

impl SseDecode for flutter_rust_bridge::for_generated::anyhow::Error {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <String>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::anyhow::anyhow!("{}", inner);
    }
}

impl SseDecode for CancelToken {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for ForwardedConnection {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for SftpFile {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for SftpSession {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for SshChannel {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for SshClient {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <RustOpaqueMoi<
            flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>,
        >>::sse_decode(deserializer);
        return flutter_rust_bridge::for_generated::rust_auto_opaque_decode_owned(inner);
    }
}

impl SseDecode for flutter_rust_bridge::DartOpaque {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return unsafe { flutter_rust_bridge::for_generated::sse_decode_dart_opaque(inner) };
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>
{
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <usize>::sse_decode(deserializer);
        return decode_rust_opaque_moi(inner);
    }
}

impl SseDecode for String {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <Vec<u8>>::sse_decode(deserializer);
        return String::from_utf8(inner).unwrap();
    }
}

impl SseDecode for bool {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u8().unwrap() != 0
    }
}

impl SseDecode for crate::api::ssh::ChannelChunk {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut var_data = <Vec<u8>>::sse_decode(deserializer);
        let mut var_extended = <Vec<u8>>::sse_decode(deserializer);
        let mut var_exitStatus = <Option<u32>>::sse_decode(deserializer);
        let mut var_closed = <bool>::sse_decode(deserializer);
        return crate::api::ssh::ChannelChunk {
            data: var_data,
            extended: var_extended,
            exit_status: var_exitStatus,
            closed: var_closed,
        };
    }
}

impl SseDecode for crate::api::ssh::ConnectParams {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut var_host = <String>::sse_decode(deserializer);
        let mut var_port = <u16>::sse_decode(deserializer);
        let mut var_connectTimeoutMs = <u32>::sse_decode(deserializer);
        let mut var_handshakeTimeoutMs = <u32>::sse_decode(deserializer);
        let mut var_clientId = <String>::sse_decode(deserializer);
        return crate::api::ssh::ConnectParams {
            host: var_host,
            port: var_port,
            connect_timeout_ms: var_connectTimeoutMs,
            handshake_timeout_ms: var_handshakeTimeoutMs,
            client_id: var_clientId,
        };
    }
}

impl SseDecode for crate::api::error::EngineError {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut var_kind = <crate::api::error::EngineErrorKind>::sse_decode(deserializer);
        let mut var_message = <String>::sse_decode(deserializer);
        let mut var_code = <Option<u32>>::sse_decode(deserializer);
        return crate::api::error::EngineError {
            kind: var_kind,
            message: var_message,
            code: var_code,
        };
    }
}

impl SseDecode for crate::api::error::EngineErrorKind {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut inner = <i32>::sse_decode(deserializer);
        return match inner {
            0 => crate::api::error::EngineErrorKind::HostKey,
            1 => crate::api::error::EngineErrorKind::Auth,
            2 => crate::api::error::EngineErrorKind::AuthAbort,
            3 => crate::api::error::EngineErrorKind::KeyDecrypt,
            4 => crate::api::error::EngineErrorKind::KeyDecode,
            5 => crate::api::error::EngineErrorKind::Timeout,
            6 => crate::api::error::EngineErrorKind::Socket,
            7 => crate::api::error::EngineErrorKind::Handshake,
            8 => crate::api::error::EngineErrorKind::Channel,
            9 => crate::api::error::EngineErrorKind::ChannelRequest,
            10 => crate::api::error::EngineErrorKind::Cancelled,
            11 => crate::api::error::EngineErrorKind::Disconnect,
            12 => crate::api::error::EngineErrorKind::SftpStatus,
            13 => crate::api::error::EngineErrorKind::Sftp,
            14 => crate::api::error::EngineErrorKind::Internal,
            _ => unreachable!("Invalid variant for EngineErrorKind: {}", inner),
        };
    }
}

impl SseDecode for i32 {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_i32::<NativeEndian>().unwrap()
    }
}

impl SseDecode for isize {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_i64::<NativeEndian>().unwrap() as _
    }
}

impl SseDecode for Vec<String> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut len_ = <i32>::sse_decode(deserializer);
        let mut ans_ = Vec::with_capacity(len_ as usize);
        for idx_ in 0..len_ {
            ans_.push(<String>::sse_decode(deserializer));
        }
        return ans_;
    }
}

impl SseDecode for Vec<bool> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut len_ = <i32>::sse_decode(deserializer);
        let mut ans_ = Vec::with_capacity(len_ as usize);
        for idx_ in 0..len_ {
            ans_.push(<bool>::sse_decode(deserializer));
        }
        return ans_;
    }
}

impl SseDecode for Vec<u8> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut len_ = <i32>::sse_decode(deserializer);
        let mut ans_ = Vec::with_capacity(len_ as usize);
        for idx_ in 0..len_ {
            ans_.push(<u8>::sse_decode(deserializer));
        }
        return ans_;
    }
}

impl SseDecode for Vec<crate::api::sftp::SftpEntry> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut len_ = <i32>::sse_decode(deserializer);
        let mut ans_ = Vec::with_capacity(len_ as usize);
        for idx_ in 0..len_ {
            ans_.push(<crate::api::sftp::SftpEntry>::sse_decode(deserializer));
        }
        return ans_;
    }
}

impl SseDecode for Option<String> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<String>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for Option<ForwardedConnection> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<ForwardedConnection>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for Option<u32> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<u32>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for Option<u64> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<u64>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for Option<Vec<String>> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<Vec<String>>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for Option<Vec<u8>> {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        if (<bool>::sse_decode(deserializer)) {
            return Some(<Vec<u8>>::sse_decode(deserializer));
        } else {
            return None;
        }
    }
}

impl SseDecode for crate::api::sftp::SftpAttrs {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut var_size = <Option<u64>>::sse_decode(deserializer);
        let mut var_uid = <Option<u32>>::sse_decode(deserializer);
        let mut var_gid = <Option<u32>>::sse_decode(deserializer);
        let mut var_permissions = <Option<u32>>::sse_decode(deserializer);
        let mut var_atime = <Option<u32>>::sse_decode(deserializer);
        let mut var_mtime = <Option<u32>>::sse_decode(deserializer);
        return crate::api::sftp::SftpAttrs {
            size: var_size,
            uid: var_uid,
            gid: var_gid,
            permissions: var_permissions,
            atime: var_atime,
            mtime: var_mtime,
        };
    }
}

impl SseDecode for crate::api::sftp::SftpEntry {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        let mut var_filename = <String>::sse_decode(deserializer);
        let mut var_longname = <String>::sse_decode(deserializer);
        let mut var_attrs = <crate::api::sftp::SftpAttrs>::sse_decode(deserializer);
        return crate::api::sftp::SftpEntry {
            filename: var_filename,
            longname: var_longname,
            attrs: var_attrs,
        };
    }
}

impl SseDecode for u16 {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u16::<NativeEndian>().unwrap()
    }
}

impl SseDecode for u32 {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u32::<NativeEndian>().unwrap()
    }
}

impl SseDecode for u64 {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u64::<NativeEndian>().unwrap()
    }
}

impl SseDecode for u8 {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u8().unwrap()
    }
}

impl SseDecode for () {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {}
}

impl SseDecode for usize {
    fn sse_decode(deserializer: &mut flutter_rust_bridge::for_generated::SseDeserializer) -> Self {
        deserializer.cursor.read_u64::<NativeEndian>().unwrap() as _
    }
}

fn pde_ffi_dispatcher_primary_impl(
    func_id: i32,
    port: flutter_rust_bridge::for_generated::MessagePort,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) {
    match func_id {
        14 => wire__crate__api__sftp__SftpFile_close_impl(port, ptr, rust_vec_len, data_len),
        15 => wire__crate__api__sftp__SftpFile_read_impl(port, ptr, rust_vec_len, data_len),
        16 => wire__crate__api__sftp__SftpFile_size_impl(port, ptr, rust_vec_len, data_len),
        17 => wire__crate__api__sftp__SftpFile_write_impl(port, ptr, rust_vec_len, data_len),
        18 => wire__crate__api__sftp__SftpSession_close_impl(port, ptr, rust_vec_len, data_len),
        19 => wire__crate__api__sftp__SftpSession_list_impl(port, ptr, rust_vec_len, data_len),
        20 => wire__crate__api__sftp__SftpSession_mkdir_impl(port, ptr, rust_vec_len, data_len),
        21 => wire__crate__api__sftp__SftpSession_open_impl(port, ptr, rust_vec_len, data_len),
        22 => wire__crate__api__sftp__SftpSession_realpath_impl(port, ptr, rust_vec_len, data_len),
        23 => wire__crate__api__sftp__SftpSession_remove_impl(port, ptr, rust_vec_len, data_len),
        24 => wire__crate__api__sftp__SftpSession_rename_impl(port, ptr, rust_vec_len, data_len),
        25 => wire__crate__api__sftp__SftpSession_rmdir_impl(port, ptr, rust_vec_len, data_len),
        26 => wire__crate__api__sftp__SftpSession_set_permissions_impl(
            port,
            ptr,
            rust_vec_len,
            data_len,
        ),
        27 => wire__crate__api__sftp__SftpSession_stat_impl(port, ptr, rust_vec_len, data_len),
        28 => wire__crate__api__ssh__SshChannel_close_impl(port, ptr, rust_vec_len, data_len),
        29 => wire__crate__api__ssh__SshChannel_eof_impl(port, ptr, rust_vec_len, data_len),
        30 => wire__crate__api__ssh__SshChannel_exec_impl(port, ptr, rust_vec_len, data_len),
        32 => wire__crate__api__ssh__SshChannel_read_impl(port, ptr, rust_vec_len, data_len),
        33 => wire__crate__api__ssh__SshChannel_request_pty_impl(port, ptr, rust_vec_len, data_len),
        34 => {
            wire__crate__api__ssh__SshChannel_request_shell_impl(port, ptr, rust_vec_len, data_len)
        }
        35 => wire__crate__api__ssh__SshChannel_set_env_impl(port, ptr, rust_vec_len, data_len),
        36 => {
            wire__crate__api__ssh__SshChannel_window_change_impl(port, ptr, rust_vec_len, data_len)
        }
        37 => wire__crate__api__ssh__SshChannel_write_impl(port, ptr, rust_vec_len, data_len),
        38 => wire__crate__api__ssh__SshClient_accept_forwarded_impl(
            port,
            ptr,
            rust_vec_len,
            data_len,
        ),
        39 => wire__crate__api__ssh__SshClient_auth_agent_impl(port, ptr, rust_vec_len, data_len),
        40 => wire__crate__api__ssh__SshClient_auth_key_impl(port, ptr, rust_vec_len, data_len),
        41 => wire__crate__api__ssh__SshClient_auth_keyboard_interactive_impl(
            port,
            ptr,
            rust_vec_len,
            data_len,
        ),
        42 => wire__crate__api__ssh__SshClient_auth_none_impl(port, ptr, rust_vec_len, data_len),
        43 => {
            wire__crate__api__ssh__SshClient_auth_password_impl(port, ptr, rust_vec_len, data_len)
        }
        44 => wire__crate__api__ssh__SshClient_cancel_forward_remote_impl(
            port,
            ptr,
            rust_vec_len,
            data_len,
        ),
        45 => wire__crate__api__ssh__SshClient_connect_via_impl(port, ptr, rust_vec_len, data_len),
        46 => wire__crate__api__ssh__SshClient_disconnect_impl(port, ptr, rust_vec_len, data_len),
        47 => {
            wire__crate__api__ssh__SshClient_forward_remote_impl(port, ptr, rust_vec_len, data_len)
        }
        49 => wire__crate__api__ssh__SshClient_open_direct_tcpip_impl(
            port,
            ptr,
            rust_vec_len,
            data_len,
        ),
        50 => wire__crate__api__ssh__SshClient_open_session_impl(port, ptr, rust_vec_len, data_len),
        51 => wire__crate__api__ssh__SshClient_ping_impl(port, ptr, rust_vec_len, data_len),
        53 => wire__crate__api__ssh__SshClient_sftp_impl(port, ptr, rust_vec_len, data_len),
        54 => wire__crate__api__ssh__SshClient_wait_closed_impl(port, ptr, rust_vec_len, data_len),
        55 => wire__crate__api__ssh__connect_impl(port, ptr, rust_vec_len, data_len),
        57 => wire__crate__api__util__init_app_impl(port, ptr, rust_vec_len, data_len),
        58 => wire__crate__api__util__sha256_file_impl(port, ptr, rust_vec_len, data_len),
        _ => unreachable!(),
    }
}

fn pde_ffi_dispatcher_sync_impl(
    func_id: i32,
    ptr: flutter_rust_bridge::for_generated::PlatformGeneralizedUint8ListPtr,
    rust_vec_len: i32,
    data_len: i32,
) -> flutter_rust_bridge::for_generated::WireSyncRust2DartSse {
    match func_id {
        1 => wire__crate__api__util__CancelToken_cancel_impl(ptr, rust_vec_len, data_len),
        2 => wire__crate__api__util__CancelToken_is_cancelled_impl(ptr, rust_vec_len, data_len),
        3 => wire__crate__api__util__CancelToken_new_impl(ptr, rust_vec_len, data_len),
        4 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_channel_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        5 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_connected_host_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        6 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_connected_port_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        7 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_origin_host_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        8 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_get_origin_port_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        9 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_channel_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        10 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_connected_host_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        11 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_connected_port_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        12 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_origin_host_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        13 => wire__crate__api__ssh__ForwardedConnection_auto_accessor_set_origin_port_impl(
            ptr,
            rust_vec_len,
            data_len,
        ),
        31 => wire__crate__api__ssh__SshChannel_exit_status_impl(ptr, rust_vec_len, data_len),
        48 => wire__crate__api__ssh__SshClient_is_closed_impl(ptr, rust_vec_len, data_len),
        52 => wire__crate__api__ssh__SshClient_remote_version_impl(ptr, rust_vec_len, data_len),
        56 => wire__crate__api__util__engine_version_impl(ptr, rust_vec_len, data_len),
        _ => unreachable!(),
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<CancelToken> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for FrbWrapper<CancelToken> {}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<CancelToken>> for CancelToken {
    fn into_into_dart(self) -> FrbWrapper<CancelToken> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<ForwardedConnection> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive
    for FrbWrapper<ForwardedConnection>
{
}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<ForwardedConnection>> for ForwardedConnection {
    fn into_into_dart(self) -> FrbWrapper<ForwardedConnection> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<SftpFile> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for FrbWrapper<SftpFile> {}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<SftpFile>> for SftpFile {
    fn into_into_dart(self) -> FrbWrapper<SftpFile> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<SftpSession> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for FrbWrapper<SftpSession> {}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<SftpSession>> for SftpSession {
    fn into_into_dart(self) -> FrbWrapper<SftpSession> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<SshChannel> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for FrbWrapper<SshChannel> {}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<SshChannel>> for SshChannel {
    fn into_into_dart(self) -> FrbWrapper<SshChannel> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for FrbWrapper<SshClient> {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self.0)
            .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for FrbWrapper<SshClient> {}

impl flutter_rust_bridge::IntoIntoDart<FrbWrapper<SshClient>> for SshClient {
    fn into_into_dart(self) -> FrbWrapper<SshClient> {
        self.into()
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::ssh::ChannelChunk {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        [
            self.data.into_into_dart().into_dart(),
            self.extended.into_into_dart().into_dart(),
            self.exit_status.into_into_dart().into_dart(),
            self.closed.into_into_dart().into_dart(),
        ]
        .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for crate::api::ssh::ChannelChunk {}
impl flutter_rust_bridge::IntoIntoDart<crate::api::ssh::ChannelChunk>
    for crate::api::ssh::ChannelChunk
{
    fn into_into_dart(self) -> crate::api::ssh::ChannelChunk {
        self
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::ssh::ConnectParams {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        [
            self.host.into_into_dart().into_dart(),
            self.port.into_into_dart().into_dart(),
            self.connect_timeout_ms.into_into_dart().into_dart(),
            self.handshake_timeout_ms.into_into_dart().into_dart(),
            self.client_id.into_into_dart().into_dart(),
        ]
        .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive
    for crate::api::ssh::ConnectParams
{
}
impl flutter_rust_bridge::IntoIntoDart<crate::api::ssh::ConnectParams>
    for crate::api::ssh::ConnectParams
{
    fn into_into_dart(self) -> crate::api::ssh::ConnectParams {
        self
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::error::EngineError {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        [
            self.kind.into_into_dart().into_dart(),
            self.message.into_into_dart().into_dart(),
            self.code.into_into_dart().into_dart(),
        ]
        .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive
    for crate::api::error::EngineError
{
}
impl flutter_rust_bridge::IntoIntoDart<crate::api::error::EngineError>
    for crate::api::error::EngineError
{
    fn into_into_dart(self) -> crate::api::error::EngineError {
        self
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::error::EngineErrorKind {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        match self {
            Self::HostKey => 0.into_dart(),
            Self::Auth => 1.into_dart(),
            Self::AuthAbort => 2.into_dart(),
            Self::KeyDecrypt => 3.into_dart(),
            Self::KeyDecode => 4.into_dart(),
            Self::Timeout => 5.into_dart(),
            Self::Socket => 6.into_dart(),
            Self::Handshake => 7.into_dart(),
            Self::Channel => 8.into_dart(),
            Self::ChannelRequest => 9.into_dart(),
            Self::Cancelled => 10.into_dart(),
            Self::Disconnect => 11.into_dart(),
            Self::SftpStatus => 12.into_dart(),
            Self::Sftp => 13.into_dart(),
            Self::Internal => 14.into_dart(),
            _ => unreachable!(),
        }
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive
    for crate::api::error::EngineErrorKind
{
}
impl flutter_rust_bridge::IntoIntoDart<crate::api::error::EngineErrorKind>
    for crate::api::error::EngineErrorKind
{
    fn into_into_dart(self) -> crate::api::error::EngineErrorKind {
        self
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::sftp::SftpAttrs {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        [
            self.size.into_into_dart().into_dart(),
            self.uid.into_into_dart().into_dart(),
            self.gid.into_into_dart().into_dart(),
            self.permissions.into_into_dart().into_dart(),
            self.atime.into_into_dart().into_dart(),
            self.mtime.into_into_dart().into_dart(),
        ]
        .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for crate::api::sftp::SftpAttrs {}
impl flutter_rust_bridge::IntoIntoDart<crate::api::sftp::SftpAttrs>
    for crate::api::sftp::SftpAttrs
{
    fn into_into_dart(self) -> crate::api::sftp::SftpAttrs {
        self
    }
}

impl flutter_rust_bridge::IntoDart for crate::api::sftp::SftpEntry {
    fn into_dart(self) -> flutter_rust_bridge::for_generated::DartAbi {
        [
            self.filename.into_into_dart().into_dart(),
            self.longname.into_into_dart().into_dart(),
            self.attrs.into_into_dart().into_dart(),
        ]
        .into_dart()
    }
}
impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for crate::api::sftp::SftpEntry {}
impl flutter_rust_bridge::IntoIntoDart<crate::api::sftp::SftpEntry>
    for crate::api::sftp::SftpEntry
{
    fn into_into_dart(self) -> crate::api::sftp::SftpEntry {
        self
    }
}

impl SseEncode for flutter_rust_bridge::for_generated::anyhow::Error {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <String>::sse_encode(format!("{:?}", self), serializer);
    }
}

impl SseEncode for CancelToken {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for ForwardedConnection {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for SftpFile {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for SftpSession {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for SshChannel {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for SshClient {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>>::sse_encode(flutter_rust_bridge::for_generated::rust_auto_opaque_encode::<_, MoiArc<_>>(self), serializer);
    }
}

impl SseEncode for flutter_rust_bridge::DartOpaque {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <usize>::sse_encode(self.encode(), serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode
    for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>
{
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        let (ptr, size) = self.sse_encode_raw();
        <usize>::sse_encode(ptr, serializer);
        <i32>::sse_encode(size, serializer);
    }
}

impl SseEncode for String {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <Vec<u8>>::sse_encode(self.into_bytes(), serializer);
    }
}

impl SseEncode for bool {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_u8(self as _).unwrap();
    }
}

impl SseEncode for crate::api::ssh::ChannelChunk {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <Vec<u8>>::sse_encode(self.data, serializer);
        <Vec<u8>>::sse_encode(self.extended, serializer);
        <Option<u32>>::sse_encode(self.exit_status, serializer);
        <bool>::sse_encode(self.closed, serializer);
    }
}

impl SseEncode for crate::api::ssh::ConnectParams {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <String>::sse_encode(self.host, serializer);
        <u16>::sse_encode(self.port, serializer);
        <u32>::sse_encode(self.connect_timeout_ms, serializer);
        <u32>::sse_encode(self.handshake_timeout_ms, serializer);
        <String>::sse_encode(self.client_id, serializer);
    }
}

impl SseEncode for crate::api::error::EngineError {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <crate::api::error::EngineErrorKind>::sse_encode(self.kind, serializer);
        <String>::sse_encode(self.message, serializer);
        <Option<u32>>::sse_encode(self.code, serializer);
    }
}

impl SseEncode for crate::api::error::EngineErrorKind {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <i32>::sse_encode(
            match self {
                crate::api::error::EngineErrorKind::HostKey => 0,
                crate::api::error::EngineErrorKind::Auth => 1,
                crate::api::error::EngineErrorKind::AuthAbort => 2,
                crate::api::error::EngineErrorKind::KeyDecrypt => 3,
                crate::api::error::EngineErrorKind::KeyDecode => 4,
                crate::api::error::EngineErrorKind::Timeout => 5,
                crate::api::error::EngineErrorKind::Socket => 6,
                crate::api::error::EngineErrorKind::Handshake => 7,
                crate::api::error::EngineErrorKind::Channel => 8,
                crate::api::error::EngineErrorKind::ChannelRequest => 9,
                crate::api::error::EngineErrorKind::Cancelled => 10,
                crate::api::error::EngineErrorKind::Disconnect => 11,
                crate::api::error::EngineErrorKind::SftpStatus => 12,
                crate::api::error::EngineErrorKind::Sftp => 13,
                crate::api::error::EngineErrorKind::Internal => 14,
                _ => {
                    unimplemented!("");
                }
            },
            serializer,
        );
    }
}

impl SseEncode for i32 {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_i32::<NativeEndian>(self).unwrap();
    }
}

impl SseEncode for isize {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer
            .cursor
            .write_i64::<NativeEndian>(self as _)
            .unwrap();
    }
}

impl SseEncode for Vec<String> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <i32>::sse_encode(self.len() as _, serializer);
        for item in self {
            <String>::sse_encode(item, serializer);
        }
    }
}

impl SseEncode for Vec<bool> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <i32>::sse_encode(self.len() as _, serializer);
        for item in self {
            <bool>::sse_encode(item, serializer);
        }
    }
}

impl SseEncode for Vec<u8> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <i32>::sse_encode(self.len() as _, serializer);
        for item in self {
            <u8>::sse_encode(item, serializer);
        }
    }
}

impl SseEncode for Vec<crate::api::sftp::SftpEntry> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <i32>::sse_encode(self.len() as _, serializer);
        for item in self {
            <crate::api::sftp::SftpEntry>::sse_encode(item, serializer);
        }
    }
}

impl SseEncode for Option<String> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <String>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for Option<ForwardedConnection> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <ForwardedConnection>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for Option<u32> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <u32>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for Option<u64> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <u64>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for Option<Vec<String>> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <Vec<String>>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for Option<Vec<u8>> {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <bool>::sse_encode(self.is_some(), serializer);
        if let Some(value) = self {
            <Vec<u8>>::sse_encode(value, serializer);
        }
    }
}

impl SseEncode for crate::api::sftp::SftpAttrs {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <Option<u64>>::sse_encode(self.size, serializer);
        <Option<u32>>::sse_encode(self.uid, serializer);
        <Option<u32>>::sse_encode(self.gid, serializer);
        <Option<u32>>::sse_encode(self.permissions, serializer);
        <Option<u32>>::sse_encode(self.atime, serializer);
        <Option<u32>>::sse_encode(self.mtime, serializer);
    }
}

impl SseEncode for crate::api::sftp::SftpEntry {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        <String>::sse_encode(self.filename, serializer);
        <String>::sse_encode(self.longname, serializer);
        <crate::api::sftp::SftpAttrs>::sse_encode(self.attrs, serializer);
    }
}

impl SseEncode for u16 {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_u16::<NativeEndian>(self).unwrap();
    }
}

impl SseEncode for u32 {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_u32::<NativeEndian>(self).unwrap();
    }
}

impl SseEncode for u64 {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_u64::<NativeEndian>(self).unwrap();
    }
}

impl SseEncode for u8 {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer.cursor.write_u8(self).unwrap();
    }
}

impl SseEncode for () {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {}
}

impl SseEncode for usize {
    fn sse_encode(self, serializer: &mut flutter_rust_bridge::for_generated::SseSerializer) {
        serializer
            .cursor
            .write_u64::<NativeEndian>(self as _)
            .unwrap();
    }
}

#[cfg(not(target_family = "wasm"))]
mod io {

    use super::*;
    use crate::api::sftp::*;
    use crate::api::ssh::*;
    use crate::api::util::*;
    use flutter_rust_bridge::for_generated::byteorder::{
        NativeEndian, ReadBytesExt, WriteBytesExt,
    };
    use flutter_rust_bridge::for_generated::{transform_result_dco, Lifetimeable, Lockable};
    use flutter_rust_bridge::{Handler, IntoIntoDart};

    flutter_rust_bridge::frb_generated_boilerplate_io!();

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>::decrement_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>::decrement_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>::decrement_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>::decrement_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>::decrement_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>::increment_strong_count(ptr as _);
    }

    #[unsafe(no_mangle)]
    pub extern "C" fn frbgen_warpgate_core_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>::decrement_strong_count(ptr as _);
    }
}
#[cfg(not(target_family = "wasm"))]
pub use io::*;

#[cfg(target_family = "wasm")]
mod web {

    use super::*;
    use crate::api::sftp::*;
    use crate::api::ssh::*;
    use crate::api::util::*;
    use flutter_rust_bridge::for_generated::byteorder::{
        NativeEndian, ReadBytesExt, WriteBytesExt,
    };
    use flutter_rust_bridge::for_generated::wasm_bindgen;
    use flutter_rust_bridge::for_generated::wasm_bindgen::prelude::*;
    use flutter_rust_bridge::for_generated::{transform_result_dco, Lifetimeable, Lockable};
    use flutter_rust_bridge::{Handler, IntoIntoDart};

    flutter_rust_bridge::frb_generated_boilerplate_web!();

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<CancelToken>>::decrement_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<ForwardedConnection>>::decrement_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpFile>>::decrement_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SftpSession>>::decrement_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshChannel>>::decrement_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>::increment_strong_count(ptr as _);
    }

    #[wasm_bindgen]
    pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr: *const std::ffi::c_void,
    ) {
        MoiArc::<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<SshClient>>::decrement_strong_count(ptr as _);
    }
}
#[cfg(target_family = "wasm")]
pub use web::*;
