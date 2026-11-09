import 'api/channel.dart';
import 'api/connection.dart';
import 'api/error.dart';
import 'api/forwarding.dart';
import 'api/sftp.dart';
import 'api/util.dart';

import 'dart:async';
import 'dart:convert';

import 'frb_generated.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart';

abstract class WarpgateEngineApiImplPlatform
    extends BaseApiImpl<WarpgateEngineWire> {
  WarpgateEngineApiImplPlatform({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_CancelTokenPtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_ForwardedConnectionPtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_SftpFilePtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_SftpSessionPtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_SshChannelPtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_SshClientPtr => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw);

  @protected
  CancelToken
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  );

  @protected
  ForwardedConnection
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  SftpFile
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  );

  @protected
  SftpSession
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  );

  @protected
  SshChannel
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  );

  @protected
  SshClient
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  );

  @protected
  ForwardedConnection
  dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  CancelToken
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  );

  @protected
  ForwardedConnection
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  SftpFile
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  );

  @protected
  SftpSession
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  );

  @protected
  SshChannel
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  );

  @protected
  SshClient
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  );

  @protected
  FutureOr<bool> Function(String, String)
  dco_decode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    dynamic raw,
  );

  @protected
  FutureOr<List<String>?> Function(String, String, List<String>, List<bool>)
  dco_decode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    dynamic raw,
  );

  @protected
  Object dco_decode_DartOpaque(dynamic raw);

  @protected
  CancelToken
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  );

  @protected
  ForwardedConnection
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  SftpFile
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  );

  @protected
  SftpSession
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  );

  @protected
  SshChannel
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  );

  @protected
  SshClient
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  );

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  bool dco_decode_bool(dynamic raw);

  @protected
  ForwardedConnection
  dco_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  ConnectParams dco_decode_box_autoadd_connect_params(dynamic raw);

  @protected
  int dco_decode_box_autoadd_u_32(dynamic raw);

  @protected
  BigInt dco_decode_box_autoadd_u_64(dynamic raw);

  @protected
  ChannelChunk dco_decode_channel_chunk(dynamic raw);

  @protected
  ConnectParams dco_decode_connect_params(dynamic raw);

  @protected
  EngineError dco_decode_engine_error(dynamic raw);

  @protected
  EngineErrorKind dco_decode_engine_error_kind(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  PlatformInt64 dco_decode_isize(dynamic raw);

  @protected
  List<String> dco_decode_list_String(dynamic raw);

  @protected
  List<bool> dco_decode_list_bool(dynamic raw);

  @protected
  List<int> dco_decode_list_prim_u_8_loose(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  List<SftpEntry> dco_decode_list_sftp_entry(dynamic raw);

  @protected
  String? dco_decode_opt_String(dynamic raw);

  @protected
  ForwardedConnection?
  dco_decode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  );

  @protected
  int? dco_decode_opt_box_autoadd_u_32(dynamic raw);

  @protected
  BigInt? dco_decode_opt_box_autoadd_u_64(dynamic raw);

  @protected
  List<String>? dco_decode_opt_list_String(dynamic raw);

  @protected
  Uint8List? dco_decode_opt_list_prim_u_8_strict(dynamic raw);

  @protected
  SftpAttrs dco_decode_sftp_attrs(dynamic raw);

  @protected
  SftpEntry dco_decode_sftp_entry(dynamic raw);

  @protected
  int dco_decode_u_16(dynamic raw);

  @protected
  int dco_decode_u_32(dynamic raw);

  @protected
  BigInt dco_decode_u_64(dynamic raw);

  @protected
  int dco_decode_u_8(dynamic raw);

  @protected
  void dco_decode_unit(dynamic raw);

  @protected
  BigInt dco_decode_usize(dynamic raw);

  @protected
  AnyhowException sse_decode_AnyhowException(SseDeserializer deserializer);

  @protected
  CancelToken
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  );

  @protected
  ForwardedConnection
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  SftpFile
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  );

  @protected
  SftpSession
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  );

  @protected
  SshChannel
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  );

  @protected
  SshClient
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  );

  @protected
  ForwardedConnection
  sse_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  CancelToken
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  );

  @protected
  ForwardedConnection
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  SftpFile
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  );

  @protected
  SftpSession
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  );

  @protected
  SshChannel
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  );

  @protected
  SshClient
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  );

  @protected
  Object sse_decode_DartOpaque(SseDeserializer deserializer);

  @protected
  CancelToken
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  );

  @protected
  ForwardedConnection
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  SftpFile
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  );

  @protected
  SftpSession
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  );

  @protected
  SshChannel
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  );

  @protected
  SshClient
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  );

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  ForwardedConnection
  sse_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  ConnectParams sse_decode_box_autoadd_connect_params(
    SseDeserializer deserializer,
  );

  @protected
  int sse_decode_box_autoadd_u_32(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_box_autoadd_u_64(SseDeserializer deserializer);

  @protected
  ChannelChunk sse_decode_channel_chunk(SseDeserializer deserializer);

  @protected
  ConnectParams sse_decode_connect_params(SseDeserializer deserializer);

  @protected
  EngineError sse_decode_engine_error(SseDeserializer deserializer);

  @protected
  EngineErrorKind sse_decode_engine_error_kind(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  PlatformInt64 sse_decode_isize(SseDeserializer deserializer);

  @protected
  List<String> sse_decode_list_String(SseDeserializer deserializer);

  @protected
  List<bool> sse_decode_list_bool(SseDeserializer deserializer);

  @protected
  List<int> sse_decode_list_prim_u_8_loose(SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  List<SftpEntry> sse_decode_list_sftp_entry(SseDeserializer deserializer);

  @protected
  String? sse_decode_opt_String(SseDeserializer deserializer);

  @protected
  ForwardedConnection?
  sse_decode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  );

  @protected
  int? sse_decode_opt_box_autoadd_u_32(SseDeserializer deserializer);

  @protected
  BigInt? sse_decode_opt_box_autoadd_u_64(SseDeserializer deserializer);

  @protected
  List<String>? sse_decode_opt_list_String(SseDeserializer deserializer);

  @protected
  Uint8List? sse_decode_opt_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  SftpAttrs sse_decode_sftp_attrs(SseDeserializer deserializer);

  @protected
  SftpEntry sse_decode_sftp_entry(SseDeserializer deserializer);

  @protected
  int sse_decode_u_16(SseDeserializer deserializer);

  @protected
  int sse_decode_u_32(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_u_64(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer);

  @protected
  void sse_encode_AnyhowException(
    AnyhowException self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    FutureOr<bool> Function(String, String) self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    FutureOr<List<String>?> Function(String, String, List<String>, List<bool>)
    self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_DartOpaque(Object self, SseSerializer serializer);

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  );

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_String(String self, SseSerializer serializer);

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer);

  @protected
  void
  sse_encode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_box_autoadd_connect_params(
    ConnectParams self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_box_autoadd_u_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_u_64(BigInt self, SseSerializer serializer);

  @protected
  void sse_encode_channel_chunk(ChannelChunk self, SseSerializer serializer);

  @protected
  void sse_encode_connect_params(ConnectParams self, SseSerializer serializer);

  @protected
  void sse_encode_engine_error(EngineError self, SseSerializer serializer);

  @protected
  void sse_encode_engine_error_kind(
    EngineErrorKind self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_isize(PlatformInt64 self, SseSerializer serializer);

  @protected
  void sse_encode_list_String(List<String> self, SseSerializer serializer);

  @protected
  void sse_encode_list_bool(List<bool> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_loose(List<int> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_strict(
    Uint8List self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_list_sftp_entry(
    List<SftpEntry> self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_opt_String(String? self, SseSerializer serializer);

  @protected
  void
  sse_encode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection? self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_opt_box_autoadd_u_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_u_64(BigInt? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_list_String(List<String>? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_list_prim_u_8_strict(
    Uint8List? self,
    SseSerializer serializer,
  );

  @protected
  void sse_encode_sftp_attrs(SftpAttrs self, SseSerializer serializer);

  @protected
  void sse_encode_sftp_entry(SftpEntry self, SseSerializer serializer);

  @protected
  void sse_encode_u_16(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_u_64(BigInt self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer);
}

class WarpgateEngineWire implements BaseWire {
  WarpgateEngineWire.fromExternalLibrary(ExternalLibrary lib);

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
        ptr,
      );

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        ptr,
      );

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
        ptr,
      );

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
        ptr,
      );

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
        ptr,
      );

  void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    int ptr,
  ) => wasmModule
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr,
      );

  void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    int ptr,
  ) => wasmModule
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
        ptr,
      );
}

@JS('wasm_bindgen')
external WarpgateEngineWasmModule get wasmModule;

@JS()
@anonymous
extension type WarpgateEngineWasmModule._(JSObject _) implements JSObject {
  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    int ptr,
  );

  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    int ptr,
  );

  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    int ptr,
  );

  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    int ptr,
  );

  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    int ptr,
  );

  external void
  rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    int ptr,
  );

  external void
  rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    int ptr,
  );
}
