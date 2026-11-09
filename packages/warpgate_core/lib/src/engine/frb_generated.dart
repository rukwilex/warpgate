import 'api/error.dart';
import 'api/sftp.dart';
import 'api/ssh.dart';
import 'api/util.dart';

import 'dart:async';
import 'dart:convert';

import 'frb_generated.dart';
import 'frb_generated.io.dart'
    if (dart.library.js_interop) 'frb_generated.web.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class WarpgateEngine
    extends
        BaseEntrypoint<
          WarpgateEngineApi,
          WarpgateEngineApiImpl,
          WarpgateEngineWire
        > {
  @internal
  static final instance = WarpgateEngine._();

  WarpgateEngine._();

  static Future<void> init({
    WarpgateEngineApi? api,
    BaseHandler? handler,
    ExternalLibrary? externalLibrary,
    bool forceSameCodegenVersion = true,
  }) async {
    await instance.initImpl(
      api: api,
      handler: handler,
      externalLibrary: externalLibrary,
      forceSameCodegenVersion: forceSameCodegenVersion,
    );
  }

  static void initMock({required WarpgateEngineApi api}) {
    instance.initMockImpl(api: api);
  }

  static void dispose() => instance.disposeImpl();

  @override
  ApiImplConstructor<WarpgateEngineApiImpl, WarpgateEngineWire>
  get apiImplConstructor => WarpgateEngineApiImpl.new;

  @override
  WireConstructor<WarpgateEngineWire> get wireConstructor =>
      WarpgateEngineWire.fromExternalLibrary;

  @override
  Future<void> executeRustInitializers() async {
    await api.crateApiUtilInitApp();
  }

  @override
  ExternalLibraryLoaderConfig get defaultExternalLibraryLoaderConfig =>
      kDefaultExternalLibraryLoaderConfig;

  @override
  String get codegenVersion => '2.12.0';

  @override
  int get rustContentHash => 1760737308;

  static const kDefaultExternalLibraryLoaderConfig =
      ExternalLibraryLoaderConfig(
        stem: 'warpgate_engine',
        ioDirectory: '../../rust/target/release/',
        webPrefix: 'pkg/',
        wasmBindgenName: 'wasm_bindgen',
      );
}

abstract class WarpgateEngineApi extends BaseApi {
  void crateApiUtilCancelTokenCancel({required CancelToken that});

  bool crateApiUtilCancelTokenIsCancelled({required CancelToken that});

  CancelToken crateApiUtilCancelTokenNew();

  SshChannel crateApiSshForwardedConnectionAutoAccessorGetChannel({
    required ForwardedConnection that,
  });

  String crateApiSshForwardedConnectionAutoAccessorGetConnectedHost({
    required ForwardedConnection that,
  });

  int crateApiSshForwardedConnectionAutoAccessorGetConnectedPort({
    required ForwardedConnection that,
  });

  String crateApiSshForwardedConnectionAutoAccessorGetOriginHost({
    required ForwardedConnection that,
  });

  int crateApiSshForwardedConnectionAutoAccessorGetOriginPort({
    required ForwardedConnection that,
  });

  void crateApiSshForwardedConnectionAutoAccessorSetChannel({
    required ForwardedConnection that,
    required SshChannel channel,
  });

  void crateApiSshForwardedConnectionAutoAccessorSetConnectedHost({
    required ForwardedConnection that,
    required String connectedHost,
  });

  void crateApiSshForwardedConnectionAutoAccessorSetConnectedPort({
    required ForwardedConnection that,
    required int connectedPort,
  });

  void crateApiSshForwardedConnectionAutoAccessorSetOriginHost({
    required ForwardedConnection that,
    required String originHost,
  });

  void crateApiSshForwardedConnectionAutoAccessorSetOriginPort({
    required ForwardedConnection that,
    required int originPort,
  });

  Future<void> crateApiSftpSftpFileClose({required SftpFile that});

  Future<Uint8List?> crateApiSftpSftpFileRead({
    required SftpFile that,
    required BigInt offset,
    required int len,
  });

  Future<BigInt?> crateApiSftpSftpFileSize({required SftpFile that});

  Future<void> crateApiSftpSftpFileWrite({
    required SftpFile that,
    required BigInt offset,
    required List<int> data,
  });

  Future<void> crateApiSftpSftpSessionClose({required SftpSession that});

  Future<List<SftpEntry>> crateApiSftpSftpSessionList({
    required SftpSession that,
    required String path,
  });

  Future<void> crateApiSftpSftpSessionMkdir({
    required SftpSession that,
    required String path,
  });

  Future<SftpFile> crateApiSftpSftpSessionOpen({
    required SftpSession that,
    required String path,
    required int flags,
  });

  Future<String> crateApiSftpSftpSessionRealpath({
    required SftpSession that,
    required String path,
  });

  Future<void> crateApiSftpSftpSessionRemove({
    required SftpSession that,
    required String path,
  });

  Future<void> crateApiSftpSftpSessionRename({
    required SftpSession that,
    required String from,
    required String to,
  });

  Future<void> crateApiSftpSftpSessionRmdir({
    required SftpSession that,
    required String path,
  });

  Future<void> crateApiSftpSftpSessionSetPermissions({
    required SftpSession that,
    required String path,
    required int mode,
  });

  Future<SftpAttrs> crateApiSftpSftpSessionStat({
    required SftpSession that,
    required String path,
    required bool followLinks,
  });

  Future<void> crateApiSshSshChannelClose({required SshChannel that});

  Future<void> crateApiSshSshChannelEof({required SshChannel that});

  Future<void> crateApiSshSshChannelExec({
    required SshChannel that,
    required String command,
  });

  int? crateApiSshSshChannelExitStatus({required SshChannel that});

  Future<ChannelChunk> crateApiSshSshChannelRead({
    required SshChannel that,
    required int maxBytes,
  });

  Future<void> crateApiSshSshChannelRequestPty({
    required SshChannel that,
    required String term,
    required int columns,
    required int rows,
  });

  Future<void> crateApiSshSshChannelRequestShell({required SshChannel that});

  Future<void> crateApiSshSshChannelSetEnv({
    required SshChannel that,
    required String name,
    required String value,
  });

  Future<void> crateApiSshSshChannelWindowChange({
    required SshChannel that,
    required int columns,
    required int rows,
  });

  Future<void> crateApiSshSshChannelWrite({
    required SshChannel that,
    required List<int> data,
  });

  Future<ForwardedConnection?> crateApiSshSshClientAcceptForwarded({
    required SshClient that,
  });

  Future<bool> crateApiSshSshClientAuthAgent({
    required SshClient that,
    required String user,
    String? socket,
  });

  Future<bool> crateApiSshSshClientAuthKey({
    required SshClient that,
    required String user,
    required String pem,
    String? passphrase,
  });

  Future<bool> crateApiSshSshClientAuthKeyboardInteractive({
    required SshClient that,
    required String user,
    required FutureOr<List<String>?> Function(
      String,
      String,
      List<String>,
      List<bool>,
    )
    responder,
  });

  Future<bool> crateApiSshSshClientAuthNone({
    required SshClient that,
    required String user,
  });

  Future<bool> crateApiSshSshClientAuthPassword({
    required SshClient that,
    required String user,
    required String password,
  });

  Future<void> crateApiSshSshClientCancelForwardRemote({
    required SshClient that,
    required String host,
    required int port,
  });

  Future<SshClient> crateApiSshSshClientConnectVia({
    required SshClient that,
    required ConnectParams params,
    required FutureOr<bool> Function(String, String) verifier,
  });

  Future<void> crateApiSshSshClientDisconnect({required SshClient that});

  Future<int> crateApiSshSshClientForwardRemote({
    required SshClient that,
    required String host,
    required int port,
  });

  bool crateApiSshSshClientIsClosed({required SshClient that});

  Future<SshChannel> crateApiSshSshClientOpenDirectTcpip({
    required SshClient that,
    required String host,
    required int port,
  });

  Future<SshChannel> crateApiSshSshClientOpenSession({required SshClient that});

  Future<void> crateApiSshSshClientPing({
    required SshClient that,
    required int timeoutMs,
  });

  String? crateApiSshSshClientRemoteVersion({required SshClient that});

  Future<SftpSession> crateApiSshSshClientSftp({required SshClient that});

  Future<void> crateApiSshSshClientWaitClosed({required SshClient that});

  Future<SshClient> crateApiSshConnect({
    required ConnectParams params,
    required CancelToken cancel,
    required FutureOr<bool> Function(String, String) verifier,
  });

  String crateApiUtilEngineVersion();

  Future<void> crateApiUtilInitApp();

  Future<String> crateApiUtilSha256File({required String path});

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_CancelToken;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_CancelToken;

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_CancelTokenPtr;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_ForwardedConnection;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_ForwardedConnection;

  CrossPlatformFinalizerArg
  get rust_arc_decrement_strong_count_ForwardedConnectionPtr;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SftpFile;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SftpFile;

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_SftpFilePtr;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SftpSession;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SftpSession;

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_SftpSessionPtr;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SshChannel;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SshChannel;

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_SshChannelPtr;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SshClient;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SshClient;

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_SshClientPtr;
}

class WarpgateEngineApiImpl extends WarpgateEngineApiImplPlatform
    implements WarpgateEngineApi {
  WarpgateEngineApiImpl({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  @override
  void crateApiUtilCancelTokenCancel({required CancelToken that}) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 1)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiUtilCancelTokenCancelConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilCancelTokenCancelConstMeta =>
      const TaskConstMeta(debugName: "CancelToken_cancel", argNames: ["that"]);

  @override
  bool crateApiUtilCancelTokenIsCancelled({required CancelToken that}) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 2)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiUtilCancelTokenIsCancelledConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilCancelTokenIsCancelledConstMeta =>
      const TaskConstMeta(
        debugName: "CancelToken_is_cancelled",
        argNames: ["that"],
      );

  @override
  CancelToken crateApiUtilCancelTokenNew() {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 3)!;
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiUtilCancelTokenNewConstMeta,
        argValues: [],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilCancelTokenNewConstMeta =>
      const TaskConstMeta(debugName: "CancelToken_new", argNames: []);

  @override
  SshChannel crateApiSshForwardedConnectionAutoAccessorGetChannel({
    required ForwardedConnection that,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 4)!;
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorGetChannelConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorGetChannelConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_get_channel",
        argNames: ["that"],
      );

  @override
  String crateApiSshForwardedConnectionAutoAccessorGetConnectedHost({
    required ForwardedConnection that,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 5)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_String,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorGetConnectedHostConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorGetConnectedHostConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_get_connected_host",
        argNames: ["that"],
      );

  @override
  int crateApiSshForwardedConnectionAutoAccessorGetConnectedPort({
    required ForwardedConnection that,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 6)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_u_32,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorGetConnectedPortConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorGetConnectedPortConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_get_connected_port",
        argNames: ["that"],
      );

  @override
  String crateApiSshForwardedConnectionAutoAccessorGetOriginHost({
    required ForwardedConnection that,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 7)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_String,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorGetOriginHostConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorGetOriginHostConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_get_origin_host",
        argNames: ["that"],
      );

  @override
  int crateApiSshForwardedConnectionAutoAccessorGetOriginPort({
    required ForwardedConnection that,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 8)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_u_32,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorGetOriginPortConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorGetOriginPortConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_get_origin_port",
        argNames: ["that"],
      );

  @override
  void crateApiSshForwardedConnectionAutoAccessorSetChannel({
    required ForwardedConnection that,
    required SshChannel channel,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            channel,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 9)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorSetChannelConstMeta,
        argValues: [that, channel],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorSetChannelConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_set_channel",
        argNames: ["that", "channel"],
      );

  @override
  void crateApiSshForwardedConnectionAutoAccessorSetConnectedHost({
    required ForwardedConnection that,
    required String connectedHost,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          sse_encode_String(connectedHost, serializer);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 10)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorSetConnectedHostConstMeta,
        argValues: [that, connectedHost],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorSetConnectedHostConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_set_connected_host",
        argNames: ["that", "connectedHost"],
      );

  @override
  void crateApiSshForwardedConnectionAutoAccessorSetConnectedPort({
    required ForwardedConnection that,
    required int connectedPort,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          sse_encode_u_32(connectedPort, serializer);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 11)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorSetConnectedPortConstMeta,
        argValues: [that, connectedPort],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorSetConnectedPortConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_set_connected_port",
        argNames: ["that", "connectedPort"],
      );

  @override
  void crateApiSshForwardedConnectionAutoAccessorSetOriginHost({
    required ForwardedConnection that,
    required String originHost,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          sse_encode_String(originHost, serializer);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 12)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorSetOriginHostConstMeta,
        argValues: [that, originHost],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorSetOriginHostConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_set_origin_host",
        argNames: ["that", "originHost"],
      );

  @override
  void crateApiSshForwardedConnectionAutoAccessorSetOriginPort({
    required ForwardedConnection that,
    required int originPort,
  }) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            that,
            serializer,
          );
          sse_encode_u_32(originPort, serializer);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 13)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta:
            kCrateApiSshForwardedConnectionAutoAccessorSetOriginPortConstMeta,
        argValues: [that, originPort],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta
  get kCrateApiSshForwardedConnectionAutoAccessorSetOriginPortConstMeta =>
      const TaskConstMeta(
        debugName: "ForwardedConnection_auto_accessor_set_origin_port",
        argNames: ["that", "originPort"],
      );

  @override
  Future<void> crateApiSftpSftpFileClose({required SftpFile that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 14,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpFileCloseConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpFileCloseConstMeta =>
      const TaskConstMeta(debugName: "SftpFile_close", argNames: ["that"]);

  @override
  Future<Uint8List?> crateApiSftpSftpFileRead({
    required SftpFile that,
    required BigInt offset,
    required int len,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
            that,
            serializer,
          );
          sse_encode_u_64(offset, serializer);
          sse_encode_u_32(len, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 15,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_opt_list_prim_u_8_strict,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpFileReadConstMeta,
        argValues: [that, offset, len],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpFileReadConstMeta => const TaskConstMeta(
    debugName: "SftpFile_read",
    argNames: ["that", "offset", "len"],
  );

  @override
  Future<BigInt?> crateApiSftpSftpFileSize({required SftpFile that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 16,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_opt_box_autoadd_u_64,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpFileSizeConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpFileSizeConstMeta =>
      const TaskConstMeta(debugName: "SftpFile_size", argNames: ["that"]);

  @override
  Future<void> crateApiSftpSftpFileWrite({
    required SftpFile that,
    required BigInt offset,
    required List<int> data,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
            that,
            serializer,
          );
          sse_encode_u_64(offset, serializer);
          sse_encode_list_prim_u_8_loose(data, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 17,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpFileWriteConstMeta,
        argValues: [that, offset, data],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpFileWriteConstMeta => const TaskConstMeta(
    debugName: "SftpFile_write",
    argNames: ["that", "offset", "data"],
  );

  @override
  Future<void> crateApiSftpSftpSessionClose({required SftpSession that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 18,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionCloseConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionCloseConstMeta =>
      const TaskConstMeta(debugName: "SftpSession_close", argNames: ["that"]);

  @override
  Future<List<SftpEntry>> crateApiSftpSftpSessionList({
    required SftpSession that,
    required String path,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 19,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_list_sftp_entry,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionListConstMeta,
        argValues: [that, path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionListConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_list",
        argNames: ["that", "path"],
      );

  @override
  Future<void> crateApiSftpSftpSessionMkdir({
    required SftpSession that,
    required String path,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 20,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionMkdirConstMeta,
        argValues: [that, path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionMkdirConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_mkdir",
        argNames: ["that", "path"],
      );

  @override
  Future<SftpFile> crateApiSftpSftpSessionOpen({
    required SftpSession that,
    required String path,
    required int flags,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          sse_encode_u_32(flags, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 21,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionOpenConstMeta,
        argValues: [that, path, flags],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionOpenConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_open",
        argNames: ["that", "path", "flags"],
      );

  @override
  Future<String> crateApiSftpSftpSessionRealpath({
    required SftpSession that,
    required String path,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 22,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_String,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionRealpathConstMeta,
        argValues: [that, path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionRealpathConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_realpath",
        argNames: ["that", "path"],
      );

  @override
  Future<void> crateApiSftpSftpSessionRemove({
    required SftpSession that,
    required String path,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 23,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionRemoveConstMeta,
        argValues: [that, path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionRemoveConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_remove",
        argNames: ["that", "path"],
      );

  @override
  Future<void> crateApiSftpSftpSessionRename({
    required SftpSession that,
    required String from,
    required String to,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(from, serializer);
          sse_encode_String(to, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 24,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionRenameConstMeta,
        argValues: [that, from, to],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionRenameConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_rename",
        argNames: ["that", "from", "to"],
      );

  @override
  Future<void> crateApiSftpSftpSessionRmdir({
    required SftpSession that,
    required String path,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 25,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionRmdirConstMeta,
        argValues: [that, path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionRmdirConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_rmdir",
        argNames: ["that", "path"],
      );

  @override
  Future<void> crateApiSftpSftpSessionSetPermissions({
    required SftpSession that,
    required String path,
    required int mode,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          sse_encode_u_32(mode, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 26,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionSetPermissionsConstMeta,
        argValues: [that, path, mode],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionSetPermissionsConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_set_permissions",
        argNames: ["that", "path", "mode"],
      );

  @override
  Future<SftpAttrs> crateApiSftpSftpSessionStat({
    required SftpSession that,
    required String path,
    required bool followLinks,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
            that,
            serializer,
          );
          sse_encode_String(path, serializer);
          sse_encode_bool(followLinks, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 27,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_sftp_attrs,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSftpSftpSessionStatConstMeta,
        argValues: [that, path, followLinks],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSftpSftpSessionStatConstMeta =>
      const TaskConstMeta(
        debugName: "SftpSession_stat",
        argNames: ["that", "path", "followLinks"],
      );

  @override
  Future<void> crateApiSshSshChannelClose({required SshChannel that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 28,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelCloseConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelCloseConstMeta =>
      const TaskConstMeta(debugName: "SshChannel_close", argNames: ["that"]);

  @override
  Future<void> crateApiSshSshChannelEof({required SshChannel that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 29,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelEofConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelEofConstMeta =>
      const TaskConstMeta(debugName: "SshChannel_eof", argNames: ["that"]);

  @override
  Future<void> crateApiSshSshChannelExec({
    required SshChannel that,
    required String command,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_String(command, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 30,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelExecConstMeta,
        argValues: [that, command],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelExecConstMeta => const TaskConstMeta(
    debugName: "SshChannel_exec",
    argNames: ["that", "command"],
  );

  @override
  int? crateApiSshSshChannelExitStatus({required SshChannel that}) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 31)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_opt_box_autoadd_u_32,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiSshSshChannelExitStatusConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelExitStatusConstMeta =>
      const TaskConstMeta(
        debugName: "SshChannel_exit_status",
        argNames: ["that"],
      );

  @override
  Future<ChannelChunk> crateApiSshSshChannelRead({
    required SshChannel that,
    required int maxBytes,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_u_32(maxBytes, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 32,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_channel_chunk,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelReadConstMeta,
        argValues: [that, maxBytes],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelReadConstMeta => const TaskConstMeta(
    debugName: "SshChannel_read",
    argNames: ["that", "maxBytes"],
  );

  @override
  Future<void> crateApiSshSshChannelRequestPty({
    required SshChannel that,
    required String term,
    required int columns,
    required int rows,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_String(term, serializer);
          sse_encode_u_32(columns, serializer);
          sse_encode_u_32(rows, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 33,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelRequestPtyConstMeta,
        argValues: [that, term, columns, rows],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelRequestPtyConstMeta =>
      const TaskConstMeta(
        debugName: "SshChannel_request_pty",
        argNames: ["that", "term", "columns", "rows"],
      );

  @override
  Future<void> crateApiSshSshChannelRequestShell({required SshChannel that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 34,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelRequestShellConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelRequestShellConstMeta =>
      const TaskConstMeta(
        debugName: "SshChannel_request_shell",
        argNames: ["that"],
      );

  @override
  Future<void> crateApiSshSshChannelSetEnv({
    required SshChannel that,
    required String name,
    required String value,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_String(name, serializer);
          sse_encode_String(value, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 35,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelSetEnvConstMeta,
        argValues: [that, name, value],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelSetEnvConstMeta =>
      const TaskConstMeta(
        debugName: "SshChannel_set_env",
        argNames: ["that", "name", "value"],
      );

  @override
  Future<void> crateApiSshSshChannelWindowChange({
    required SshChannel that,
    required int columns,
    required int rows,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_u_32(columns, serializer);
          sse_encode_u_32(rows, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 36,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelWindowChangeConstMeta,
        argValues: [that, columns, rows],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelWindowChangeConstMeta =>
      const TaskConstMeta(
        debugName: "SshChannel_window_change",
        argNames: ["that", "columns", "rows"],
      );

  @override
  Future<void> crateApiSshSshChannelWrite({
    required SshChannel that,
    required List<int> data,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
            that,
            serializer,
          );
          sse_encode_list_prim_u_8_loose(data, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 37,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshChannelWriteConstMeta,
        argValues: [that, data],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshChannelWriteConstMeta => const TaskConstMeta(
    debugName: "SshChannel_write",
    argNames: ["that", "data"],
  );

  @override
  Future<ForwardedConnection?> crateApiSshSshClientAcceptForwarded({
    required SshClient that,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 38,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAcceptForwardedConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAcceptForwardedConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_accept_forwarded",
        argNames: ["that"],
      );

  @override
  Future<bool> crateApiSshSshClientAuthAgent({
    required SshClient that,
    required String user,
    String? socket,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(user, serializer);
          sse_encode_opt_String(socket, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 39,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAuthAgentConstMeta,
        argValues: [that, user, socket],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAuthAgentConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_auth_agent",
        argNames: ["that", "user", "socket"],
      );

  @override
  Future<bool> crateApiSshSshClientAuthKey({
    required SshClient that,
    required String user,
    required String pem,
    String? passphrase,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(user, serializer);
          sse_encode_String(pem, serializer);
          sse_encode_opt_String(passphrase, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 40,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAuthKeyConstMeta,
        argValues: [that, user, pem, passphrase],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAuthKeyConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_auth_key",
        argNames: ["that", "user", "pem", "passphrase"],
      );

  @override
  Future<bool> crateApiSshSshClientAuthKeyboardInteractive({
    required SshClient that,
    required String user,
    required FutureOr<List<String>?> Function(
      String,
      String,
      List<String>,
      List<bool>,
    )
    responder,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(user, serializer);
          sse_encode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
            responder,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 41,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAuthKeyboardInteractiveConstMeta,
        argValues: [that, user, responder],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAuthKeyboardInteractiveConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_auth_keyboard_interactive",
        argNames: ["that", "user", "responder"],
      );

  @override
  Future<bool> crateApiSshSshClientAuthNone({
    required SshClient that,
    required String user,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(user, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 42,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAuthNoneConstMeta,
        argValues: [that, user],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAuthNoneConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_auth_none",
        argNames: ["that", "user"],
      );

  @override
  Future<bool> crateApiSshSshClientAuthPassword({
    required SshClient that,
    required String user,
    required String password,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(user, serializer);
          sse_encode_String(password, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 43,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientAuthPasswordConstMeta,
        argValues: [that, user, password],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientAuthPasswordConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_auth_password",
        argNames: ["that", "user", "password"],
      );

  @override
  Future<void> crateApiSshSshClientCancelForwardRemote({
    required SshClient that,
    required String host,
    required int port,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(host, serializer);
          sse_encode_u_32(port, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 44,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientCancelForwardRemoteConstMeta,
        argValues: [that, host, port],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientCancelForwardRemoteConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_cancel_forward_remote",
        argNames: ["that", "host", "port"],
      );

  @override
  Future<SshClient> crateApiSshSshClientConnectVia({
    required SshClient that,
    required ConnectParams params,
    required FutureOr<bool> Function(String, String) verifier,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_box_autoadd_connect_params(params, serializer);
          sse_encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
            verifier,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 45,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientConnectViaConstMeta,
        argValues: [that, params, verifier],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientConnectViaConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_connect_via",
        argNames: ["that", "params", "verifier"],
      );

  @override
  Future<void> crateApiSshSshClientDisconnect({required SshClient that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 46,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientDisconnectConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientDisconnectConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_disconnect",
        argNames: ["that"],
      );

  @override
  Future<int> crateApiSshSshClientForwardRemote({
    required SshClient that,
    required String host,
    required int port,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(host, serializer);
          sse_encode_u_32(port, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 47,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_u_32,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientForwardRemoteConstMeta,
        argValues: [that, host, port],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientForwardRemoteConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_forward_remote",
        argNames: ["that", "host", "port"],
      );

  @override
  bool crateApiSshSshClientIsClosed({required SshClient that}) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 48)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_bool,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiSshSshClientIsClosedConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientIsClosedConstMeta =>
      const TaskConstMeta(debugName: "SshClient_is_closed", argNames: ["that"]);

  @override
  Future<SshChannel> crateApiSshSshClientOpenDirectTcpip({
    required SshClient that,
    required String host,
    required int port,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_String(host, serializer);
          sse_encode_u_32(port, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 49,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientOpenDirectTcpipConstMeta,
        argValues: [that, host, port],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientOpenDirectTcpipConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_open_direct_tcpip",
        argNames: ["that", "host", "port"],
      );

  @override
  Future<SshChannel> crateApiSshSshClientOpenSession({
    required SshClient that,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 50,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientOpenSessionConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientOpenSessionConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_open_session",
        argNames: ["that"],
      );

  @override
  Future<void> crateApiSshSshClientPing({
    required SshClient that,
    required int timeoutMs,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          sse_encode_u_32(timeoutMs, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 51,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientPingConstMeta,
        argValues: [that, timeoutMs],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientPingConstMeta => const TaskConstMeta(
    debugName: "SshClient_ping",
    argNames: ["that", "timeoutMs"],
  );

  @override
  String? crateApiSshSshClientRemoteVersion({required SshClient that}) {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 52)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_opt_String,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiSshSshClientRemoteVersionConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientRemoteVersionConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_remote_version",
        argNames: ["that"],
      );

  @override
  Future<SftpSession> crateApiSshSshClientSftp({required SshClient that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 53,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientSftpConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientSftpConstMeta =>
      const TaskConstMeta(debugName: "SshClient_sftp", argNames: ["that"]);

  @override
  Future<void> crateApiSshSshClientWaitClosed({required SshClient that}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
            that,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 54,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshSshClientWaitClosedConstMeta,
        argValues: [that],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshSshClientWaitClosedConstMeta =>
      const TaskConstMeta(
        debugName: "SshClient_wait_closed",
        argNames: ["that"],
      );

  @override
  Future<SshClient> crateApiSshConnect({
    required ConnectParams params,
    required CancelToken cancel,
    required FutureOr<bool> Function(String, String) verifier,
  }) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_box_autoadd_connect_params(params, serializer);
          sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
            cancel,
            serializer,
          );
          sse_encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
            verifier,
            serializer,
          );
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 55,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData:
              sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiSshConnectConstMeta,
        argValues: [params, cancel, verifier],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiSshConnectConstMeta => const TaskConstMeta(
    debugName: "connect",
    argNames: ["params", "cancel", "verifier"],
  );

  @override
  String crateApiUtilEngineVersion() {
    return handler.executeSync(
      SyncTask(
        callFfi: () {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          return pdeCallFfi(generalizedFrbRustBinding, serializer, funcId: 56)!;
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_String,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiUtilEngineVersionConstMeta,
        argValues: [],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilEngineVersionConstMeta =>
      const TaskConstMeta(debugName: "engine_version", argNames: []);

  @override
  Future<void> crateApiUtilInitApp() {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 57,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_unit,
          decodeErrorData: null,
        ),
        constMeta: kCrateApiUtilInitAppConstMeta,
        argValues: [],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilInitAppConstMeta =>
      const TaskConstMeta(debugName: "init_app", argNames: []);

  @override
  Future<String> crateApiUtilSha256File({required String path}) {
    return handler.executeNormal(
      NormalTask(
        callFfi: (port_) {
          final serializer = SseSerializer(generalizedFrbRustBinding);
          sse_encode_String(path, serializer);
          pdeCallFfi(
            generalizedFrbRustBinding,
            serializer,
            funcId: 58,
            port: port_,
          );
        },
        codec: SseCodec(
          decodeSuccessData: sse_decode_String,
          decodeErrorData: sse_decode_engine_error,
        ),
        constMeta: kCrateApiUtilSha256FileConstMeta,
        argValues: [path],
        apiImpl: this,
      ),
    );
  }

  TaskConstMeta get kCrateApiUtilSha256FileConstMeta =>
      const TaskConstMeta(debugName: "sha256_file", argNames: ["path"]);

  Future<void> Function(int, dynamic, dynamic)
  encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    FutureOr<bool> Function(String, String) raw,
  ) {
    return (callId, rawArg0, rawArg1) async {
      final arg0 = dco_decode_String(rawArg0);
      final arg1 = dco_decode_String(rawArg1);

      Box<bool>? rawOutput;
      Box<AnyhowException>? rawError;
      try {
        rawOutput = Box(await raw(arg0, arg1));
      } catch (e, s) {
        rawError = Box(AnyhowException("$e\n\n$s"));
      }

      final serializer = SseSerializer(generalizedFrbRustBinding);
      assert((rawOutput != null) ^ (rawError != null));
      if (rawOutput != null) {
        serializer.buffer.putUint8(0);
        sse_encode_bool(rawOutput.value, serializer);
      } else {
        serializer.buffer.putUint8(1);
        sse_encode_AnyhowException(rawError!.value, serializer);
      }
      final output = serializer.intoRaw();

      generalizedFrbRustBinding.dartFnDeliverOutput(
        callId: callId,
        ptr: output.ptr,
        rustVecLen: output.rustVecLen,
        dataLen: output.dataLen,
      );
    };
  }

  Future<void> Function(int, dynamic, dynamic, dynamic, dynamic)
  encode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    FutureOr<List<String>?> Function(String, String, List<String>, List<bool>)
    raw,
  ) {
    return (callId, rawArg0, rawArg1, rawArg2, rawArg3) async {
      final arg0 = dco_decode_String(rawArg0);
      final arg1 = dco_decode_String(rawArg1);
      final arg2 = dco_decode_list_String(rawArg2);
      final arg3 = dco_decode_list_bool(rawArg3);

      Box<List<String>?>? rawOutput;
      Box<AnyhowException>? rawError;
      try {
        rawOutput = Box(await raw(arg0, arg1, arg2, arg3));
      } catch (e, s) {
        rawError = Box(AnyhowException("$e\n\n$s"));
      }

      final serializer = SseSerializer(generalizedFrbRustBinding);
      assert((rawOutput != null) ^ (rawError != null));
      if (rawOutput != null) {
        serializer.buffer.putUint8(0);
        sse_encode_opt_list_String(rawOutput.value, serializer);
      } else {
        serializer.buffer.putUint8(1);
        sse_encode_AnyhowException(rawError!.value, serializer);
      }
      final output = serializer.intoRaw();

      generalizedFrbRustBinding.dartFnDeliverOutput(
        callId: callId,
        ptr: output.ptr,
        rustVecLen: output.rustVecLen,
        dataLen: output.dataLen,
      );
    };
  }

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_CancelToken => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_CancelToken => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_ForwardedConnection => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_ForwardedConnection => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SftpFile => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SftpFile => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SftpSession => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SftpSession => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SshChannel => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SshChannel => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel;

  RustArcIncrementStrongCountFnType
  get rust_arc_increment_strong_count_SshClient => wire
      .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient;

  RustArcDecrementStrongCountFnType
  get rust_arc_decrement_strong_count_SshClient => wire
      .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw) {
    return AnyhowException(raw as String);
  }

  @protected
  CancelToken
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  ) {
    return CancelTokenImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  ForwardedConnection
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return ForwardedConnectionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpFile
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  ) {
    return SftpFileImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpSession
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  ) {
    return SftpSessionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshChannel
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  ) {
    return SshChannelImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshClient
  dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  ) {
    return SshClientImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  ForwardedConnection
  dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return ForwardedConnectionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  CancelToken
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  ) {
    return CancelTokenImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  ForwardedConnection
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return ForwardedConnectionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpFile
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  ) {
    return SftpFileImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpSession
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  ) {
    return SftpSessionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshChannel
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  ) {
    return SshChannelImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshClient
  dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  ) {
    return SshClientImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  FutureOr<bool> Function(String, String)
  dco_decode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    dynamic raw,
  ) {
    throw UnimplementedError('');
  }

  @protected
  FutureOr<List<String>?> Function(String, String, List<String>, List<bool>)
  dco_decode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    dynamic raw,
  ) {
    throw UnimplementedError('');
  }

  @protected
  Object dco_decode_DartOpaque(dynamic raw) {
    return decodeDartOpaque(raw, generalizedFrbRustBinding);
  }

  @protected
  CancelToken
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    dynamic raw,
  ) {
    return CancelTokenImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  ForwardedConnection
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return ForwardedConnectionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpFile
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    dynamic raw,
  ) {
    return SftpFileImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SftpSession
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    dynamic raw,
  ) {
    return SftpSessionImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshChannel
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    dynamic raw,
  ) {
    return SshChannelImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  SshClient
  dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    dynamic raw,
  ) {
    return SshClientImpl.frbInternalDcoDecode(raw as List<dynamic>);
  }

  @protected
  String dco_decode_String(dynamic raw) {
    return raw as String;
  }

  @protected
  bool dco_decode_bool(dynamic raw) {
    return raw as bool;
  }

  @protected
  ForwardedConnection
  dco_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
      raw,
    );
  }

  @protected
  ConnectParams dco_decode_box_autoadd_connect_params(dynamic raw) {
    return dco_decode_connect_params(raw);
  }

  @protected
  int dco_decode_box_autoadd_u_32(dynamic raw) {
    return raw as int;
  }

  @protected
  BigInt dco_decode_box_autoadd_u_64(dynamic raw) {
    return dco_decode_u_64(raw);
  }

  @protected
  ChannelChunk dco_decode_channel_chunk(dynamic raw) {
    final arr = raw as List<dynamic>;
    if (arr.length != 4)
      throw Exception('unexpected arr length: expect 4 but see ${arr.length}');
    return ChannelChunk(
      data: dco_decode_list_prim_u_8_strict(arr[0]),
      extended: dco_decode_list_prim_u_8_strict(arr[1]),
      exitStatus: dco_decode_opt_box_autoadd_u_32(arr[2]),
      closed: dco_decode_bool(arr[3]),
    );
  }

  @protected
  ConnectParams dco_decode_connect_params(dynamic raw) {
    final arr = raw as List<dynamic>;
    if (arr.length != 5)
      throw Exception('unexpected arr length: expect 5 but see ${arr.length}');
    return ConnectParams(
      host: dco_decode_String(arr[0]),
      port: dco_decode_u_16(arr[1]),
      connectTimeoutMs: dco_decode_u_32(arr[2]),
      handshakeTimeoutMs: dco_decode_u_32(arr[3]),
      clientId: dco_decode_String(arr[4]),
    );
  }

  @protected
  EngineError dco_decode_engine_error(dynamic raw) {
    final arr = raw as List<dynamic>;
    if (arr.length != 3)
      throw Exception('unexpected arr length: expect 3 but see ${arr.length}');
    return EngineError(
      kind: dco_decode_engine_error_kind(arr[0]),
      message: dco_decode_String(arr[1]),
      code: dco_decode_opt_box_autoadd_u_32(arr[2]),
    );
  }

  @protected
  EngineErrorKind dco_decode_engine_error_kind(dynamic raw) {
    return EngineErrorKind.values[raw as int];
  }

  @protected
  int dco_decode_i_32(dynamic raw) {
    return raw as int;
  }

  @protected
  PlatformInt64 dco_decode_isize(dynamic raw) {
    return dcoDecodeI64(raw);
  }

  @protected
  List<String> dco_decode_list_String(dynamic raw) {
    return (raw as List<dynamic>).map(dco_decode_String).toList();
  }

  @protected
  List<bool> dco_decode_list_bool(dynamic raw) {
    return (raw as List<dynamic>).map(dco_decode_bool).toList();
  }

  @protected
  List<int> dco_decode_list_prim_u_8_loose(dynamic raw) {
    return raw as List<int>;
  }

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw) {
    return raw as Uint8List;
  }

  @protected
  List<SftpEntry> dco_decode_list_sftp_entry(dynamic raw) {
    return (raw as List<dynamic>).map(dco_decode_sftp_entry).toList();
  }

  @protected
  String? dco_decode_opt_String(dynamic raw) {
    return raw == null ? null : dco_decode_String(raw);
  }

  @protected
  ForwardedConnection?
  dco_decode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    dynamic raw,
  ) {
    return raw == null
        ? null
        : dco_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
            raw,
          );
  }

  @protected
  int? dco_decode_opt_box_autoadd_u_32(dynamic raw) {
    return raw == null ? null : dco_decode_box_autoadd_u_32(raw);
  }

  @protected
  BigInt? dco_decode_opt_box_autoadd_u_64(dynamic raw) {
    return raw == null ? null : dco_decode_box_autoadd_u_64(raw);
  }

  @protected
  List<String>? dco_decode_opt_list_String(dynamic raw) {
    return raw == null ? null : dco_decode_list_String(raw);
  }

  @protected
  Uint8List? dco_decode_opt_list_prim_u_8_strict(dynamic raw) {
    return raw == null ? null : dco_decode_list_prim_u_8_strict(raw);
  }

  @protected
  SftpAttrs dco_decode_sftp_attrs(dynamic raw) {
    final arr = raw as List<dynamic>;
    if (arr.length != 6)
      throw Exception('unexpected arr length: expect 6 but see ${arr.length}');
    return SftpAttrs(
      size: dco_decode_opt_box_autoadd_u_64(arr[0]),
      uid: dco_decode_opt_box_autoadd_u_32(arr[1]),
      gid: dco_decode_opt_box_autoadd_u_32(arr[2]),
      permissions: dco_decode_opt_box_autoadd_u_32(arr[3]),
      atime: dco_decode_opt_box_autoadd_u_32(arr[4]),
      mtime: dco_decode_opt_box_autoadd_u_32(arr[5]),
    );
  }

  @protected
  SftpEntry dco_decode_sftp_entry(dynamic raw) {
    final arr = raw as List<dynamic>;
    if (arr.length != 3)
      throw Exception('unexpected arr length: expect 3 but see ${arr.length}');
    return SftpEntry(
      filename: dco_decode_String(arr[0]),
      longname: dco_decode_String(arr[1]),
      attrs: dco_decode_sftp_attrs(arr[2]),
    );
  }

  @protected
  int dco_decode_u_16(dynamic raw) {
    return raw as int;
  }

  @protected
  int dco_decode_u_32(dynamic raw) {
    return raw as int;
  }

  @protected
  BigInt dco_decode_u_64(dynamic raw) {
    return dcoDecodeU64(raw);
  }

  @protected
  int dco_decode_u_8(dynamic raw) {
    return raw as int;
  }

  @protected
  void dco_decode_unit(dynamic raw) {
    return;
  }

  @protected
  BigInt dco_decode_usize(dynamic raw) {
    return dcoDecodeU64(raw);
  }

  @protected
  AnyhowException sse_decode_AnyhowException(SseDeserializer deserializer) {
    var inner = sse_decode_String(deserializer);
    return AnyhowException(inner);
  }

  @protected
  CancelToken
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  ) {
    return CancelTokenImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  ForwardedConnection
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    return ForwardedConnectionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpFile
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  ) {
    return SftpFileImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpSession
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  ) {
    return SftpSessionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshChannel
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  ) {
    return SshChannelImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshClient
  sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  ) {
    return SshClientImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  ForwardedConnection
  sse_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    return ForwardedConnectionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  CancelToken
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  ) {
    return CancelTokenImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  ForwardedConnection
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    return ForwardedConnectionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpFile
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  ) {
    return SftpFileImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpSession
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  ) {
    return SftpSessionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshChannel
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  ) {
    return SshChannelImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshClient
  sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  ) {
    return SshClientImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  Object sse_decode_DartOpaque(SseDeserializer deserializer) {
    var inner = sse_decode_isize(deserializer);
    return decodeDartOpaque(inner, generalizedFrbRustBinding);
  }

  @protected
  CancelToken
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    SseDeserializer deserializer,
  ) {
    return CancelTokenImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  ForwardedConnection
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    return ForwardedConnectionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpFile
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SseDeserializer deserializer,
  ) {
    return SftpFileImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SftpSession
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SseDeserializer deserializer,
  ) {
    return SftpSessionImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshChannel
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SseDeserializer deserializer,
  ) {
    return SshChannelImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  SshClient
  sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SseDeserializer deserializer,
  ) {
    return SshClientImpl.frbInternalSseDecode(
      sse_decode_usize(deserializer),
      sse_decode_i_32(deserializer),
    );
  }

  @protected
  String sse_decode_String(SseDeserializer deserializer) {
    var inner = sse_decode_list_prim_u_8_strict(deserializer);
    return utf8.decoder.convert(inner);
  }

  @protected
  bool sse_decode_bool(SseDeserializer deserializer) {
    return deserializer.buffer.getUint8() != 0;
  }

  @protected
  ForwardedConnection
  sse_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    return (sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
      deserializer,
    ));
  }

  @protected
  ConnectParams sse_decode_box_autoadd_connect_params(
    SseDeserializer deserializer,
  ) {
    return (sse_decode_connect_params(deserializer));
  }

  @protected
  int sse_decode_box_autoadd_u_32(SseDeserializer deserializer) {
    return (sse_decode_u_32(deserializer));
  }

  @protected
  BigInt sse_decode_box_autoadd_u_64(SseDeserializer deserializer) {
    return (sse_decode_u_64(deserializer));
  }

  @protected
  ChannelChunk sse_decode_channel_chunk(SseDeserializer deserializer) {
    var var_data = sse_decode_list_prim_u_8_strict(deserializer);
    var var_extended = sse_decode_list_prim_u_8_strict(deserializer);
    var var_exitStatus = sse_decode_opt_box_autoadd_u_32(deserializer);
    var var_closed = sse_decode_bool(deserializer);
    return ChannelChunk(
      data: var_data,
      extended: var_extended,
      exitStatus: var_exitStatus,
      closed: var_closed,
    );
  }

  @protected
  ConnectParams sse_decode_connect_params(SseDeserializer deserializer) {
    var var_host = sse_decode_String(deserializer);
    var var_port = sse_decode_u_16(deserializer);
    var var_connectTimeoutMs = sse_decode_u_32(deserializer);
    var var_handshakeTimeoutMs = sse_decode_u_32(deserializer);
    var var_clientId = sse_decode_String(deserializer);
    return ConnectParams(
      host: var_host,
      port: var_port,
      connectTimeoutMs: var_connectTimeoutMs,
      handshakeTimeoutMs: var_handshakeTimeoutMs,
      clientId: var_clientId,
    );
  }

  @protected
  EngineError sse_decode_engine_error(SseDeserializer deserializer) {
    var var_kind = sse_decode_engine_error_kind(deserializer);
    var var_message = sse_decode_String(deserializer);
    var var_code = sse_decode_opt_box_autoadd_u_32(deserializer);
    return EngineError(kind: var_kind, message: var_message, code: var_code);
  }

  @protected
  EngineErrorKind sse_decode_engine_error_kind(SseDeserializer deserializer) {
    var inner = sse_decode_i_32(deserializer);
    return EngineErrorKind.values[inner];
  }

  @protected
  int sse_decode_i_32(SseDeserializer deserializer) {
    return deserializer.buffer.getInt32();
  }

  @protected
  PlatformInt64 sse_decode_isize(SseDeserializer deserializer) {
    return deserializer.buffer.getPlatformInt64();
  }

  @protected
  List<String> sse_decode_list_String(SseDeserializer deserializer) {
    var len_ = sse_decode_i_32(deserializer);
    var ans_ = <String>[];
    for (var idx_ = 0; idx_ < len_; ++idx_) {
      ans_.add(sse_decode_String(deserializer));
    }
    return ans_;
  }

  @protected
  List<bool> sse_decode_list_bool(SseDeserializer deserializer) {
    var len_ = sse_decode_i_32(deserializer);
    var ans_ = <bool>[];
    for (var idx_ = 0; idx_ < len_; ++idx_) {
      ans_.add(sse_decode_bool(deserializer));
    }
    return ans_;
  }

  @protected
  List<int> sse_decode_list_prim_u_8_loose(SseDeserializer deserializer) {
    var len_ = sse_decode_i_32(deserializer);
    return deserializer.buffer.getUint8List(len_);
  }

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer) {
    var len_ = sse_decode_i_32(deserializer);
    return deserializer.buffer.getUint8List(len_);
  }

  @protected
  List<SftpEntry> sse_decode_list_sftp_entry(SseDeserializer deserializer) {
    var len_ = sse_decode_i_32(deserializer);
    var ans_ = <SftpEntry>[];
    for (var idx_ = 0; idx_ < len_; ++idx_) {
      ans_.add(sse_decode_sftp_entry(deserializer));
    }
    return ans_;
  }

  @protected
  String? sse_decode_opt_String(SseDeserializer deserializer) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_String(deserializer));
    } else {
      return null;
    }
  }

  @protected
  ForwardedConnection?
  sse_decode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    SseDeserializer deserializer,
  ) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        deserializer,
      ));
    } else {
      return null;
    }
  }

  @protected
  int? sse_decode_opt_box_autoadd_u_32(SseDeserializer deserializer) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_box_autoadd_u_32(deserializer));
    } else {
      return null;
    }
  }

  @protected
  BigInt? sse_decode_opt_box_autoadd_u_64(SseDeserializer deserializer) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_box_autoadd_u_64(deserializer));
    } else {
      return null;
    }
  }

  @protected
  List<String>? sse_decode_opt_list_String(SseDeserializer deserializer) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_list_String(deserializer));
    } else {
      return null;
    }
  }

  @protected
  Uint8List? sse_decode_opt_list_prim_u_8_strict(SseDeserializer deserializer) {
    if (sse_decode_bool(deserializer)) {
      return (sse_decode_list_prim_u_8_strict(deserializer));
    } else {
      return null;
    }
  }

  @protected
  SftpAttrs sse_decode_sftp_attrs(SseDeserializer deserializer) {
    var var_size = sse_decode_opt_box_autoadd_u_64(deserializer);
    var var_uid = sse_decode_opt_box_autoadd_u_32(deserializer);
    var var_gid = sse_decode_opt_box_autoadd_u_32(deserializer);
    var var_permissions = sse_decode_opt_box_autoadd_u_32(deserializer);
    var var_atime = sse_decode_opt_box_autoadd_u_32(deserializer);
    var var_mtime = sse_decode_opt_box_autoadd_u_32(deserializer);
    return SftpAttrs(
      size: var_size,
      uid: var_uid,
      gid: var_gid,
      permissions: var_permissions,
      atime: var_atime,
      mtime: var_mtime,
    );
  }

  @protected
  SftpEntry sse_decode_sftp_entry(SseDeserializer deserializer) {
    var var_filename = sse_decode_String(deserializer);
    var var_longname = sse_decode_String(deserializer);
    var var_attrs = sse_decode_sftp_attrs(deserializer);
    return SftpEntry(
      filename: var_filename,
      longname: var_longname,
      attrs: var_attrs,
    );
  }

  @protected
  int sse_decode_u_16(SseDeserializer deserializer) {
    return deserializer.buffer.getUint16();
  }

  @protected
  int sse_decode_u_32(SseDeserializer deserializer) {
    return deserializer.buffer.getUint32();
  }

  @protected
  BigInt sse_decode_u_64(SseDeserializer deserializer) {
    return deserializer.buffer.getBigUint64();
  }

  @protected
  int sse_decode_u_8(SseDeserializer deserializer) {
    return deserializer.buffer.getUint8();
  }

  @protected
  void sse_decode_unit(SseDeserializer deserializer) {}

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer) {
    return deserializer.buffer.getBigUint64();
  }

  @protected
  void sse_encode_AnyhowException(
    AnyhowException self,
    SseSerializer serializer,
  ) {
    sse_encode_String(self.message, serializer);
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as CancelTokenImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as ForwardedConnectionImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpFileImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpSessionImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshChannelImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshClientImpl).frbInternalSseEncode(move: true),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as ForwardedConnectionImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as CancelTokenImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as ForwardedConnectionImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpFileImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpSessionImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshChannelImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void
  sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshClientImpl).frbInternalSseEncode(move: false),
      serializer,
    );
  }

  @protected
  void sse_encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(
    FutureOr<bool> Function(String, String) self,
    SseSerializer serializer,
  ) {
    sse_encode_DartOpaque(
      encode_DartFn_Inputs_String_String_Output_bool_AnyhowException(self),
      serializer,
    );
  }

  @protected
  void
  sse_encode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
    FutureOr<List<String>?> Function(String, String, List<String>, List<bool>)
    self,
    SseSerializer serializer,
  ) {
    sse_encode_DartOpaque(
      encode_DartFn_Inputs_String_String_list_String_list_bool_Output_opt_list_String_AnyhowException(
        self,
      ),
      serializer,
    );
  }

  @protected
  void sse_encode_DartOpaque(Object self, SseSerializer serializer) {
    sse_encode_isize(
      PlatformPointerUtil.ptrToPlatformInt64(
        encodeDartOpaque(
          self,
          portManager.dartHandlerPort,
          generalizedFrbRustBinding,
        ),
      ),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCancelToken(
    CancelToken self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as CancelTokenImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as ForwardedConnectionImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpFile(
    SftpFile self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpFileImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSftpSession(
    SftpSession self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SftpSessionImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshChannel(
    SshChannel self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshChannelImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void
  sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerSshClient(
    SshClient self,
    SseSerializer serializer,
  ) {
    sse_encode_usize(
      (self as SshClientImpl).frbInternalSseEncode(move: null),
      serializer,
    );
  }

  @protected
  void sse_encode_String(String self, SseSerializer serializer) {
    sse_encode_list_prim_u_8_strict(utf8.encoder.convert(self), serializer);
  }

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer) {
    serializer.buffer.putUint8(self ? 1 : 0);
  }

  @protected
  void
  sse_encode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection self,
    SseSerializer serializer,
  ) {
    sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
      self,
      serializer,
    );
  }

  @protected
  void sse_encode_box_autoadd_connect_params(
    ConnectParams self,
    SseSerializer serializer,
  ) {
    sse_encode_connect_params(self, serializer);
  }

  @protected
  void sse_encode_box_autoadd_u_32(int self, SseSerializer serializer) {
    sse_encode_u_32(self, serializer);
  }

  @protected
  void sse_encode_box_autoadd_u_64(BigInt self, SseSerializer serializer) {
    sse_encode_u_64(self, serializer);
  }

  @protected
  void sse_encode_channel_chunk(ChannelChunk self, SseSerializer serializer) {
    sse_encode_list_prim_u_8_strict(self.data, serializer);
    sse_encode_list_prim_u_8_strict(self.extended, serializer);
    sse_encode_opt_box_autoadd_u_32(self.exitStatus, serializer);
    sse_encode_bool(self.closed, serializer);
  }

  @protected
  void sse_encode_connect_params(ConnectParams self, SseSerializer serializer) {
    sse_encode_String(self.host, serializer);
    sse_encode_u_16(self.port, serializer);
    sse_encode_u_32(self.connectTimeoutMs, serializer);
    sse_encode_u_32(self.handshakeTimeoutMs, serializer);
    sse_encode_String(self.clientId, serializer);
  }

  @protected
  void sse_encode_engine_error(EngineError self, SseSerializer serializer) {
    sse_encode_engine_error_kind(self.kind, serializer);
    sse_encode_String(self.message, serializer);
    sse_encode_opt_box_autoadd_u_32(self.code, serializer);
  }

  @protected
  void sse_encode_engine_error_kind(
    EngineErrorKind self,
    SseSerializer serializer,
  ) {
    sse_encode_i_32(self.index, serializer);
  }

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer) {
    serializer.buffer.putInt32(self);
  }

  @protected
  void sse_encode_isize(PlatformInt64 self, SseSerializer serializer) {
    serializer.buffer.putPlatformInt64(self);
  }

  @protected
  void sse_encode_list_String(List<String> self, SseSerializer serializer) {
    sse_encode_i_32(self.length, serializer);
    for (final item in self) {
      sse_encode_String(item, serializer);
    }
  }

  @protected
  void sse_encode_list_bool(List<bool> self, SseSerializer serializer) {
    sse_encode_i_32(self.length, serializer);
    for (final item in self) {
      sse_encode_bool(item, serializer);
    }
  }

  @protected
  void sse_encode_list_prim_u_8_loose(
    List<int> self,
    SseSerializer serializer,
  ) {
    sse_encode_i_32(self.length, serializer);
    serializer.buffer.putUint8List(
      self is Uint8List ? self : Uint8List.fromList(self),
    );
  }

  @protected
  void sse_encode_list_prim_u_8_strict(
    Uint8List self,
    SseSerializer serializer,
  ) {
    sse_encode_i_32(self.length, serializer);
    serializer.buffer.putUint8List(self);
  }

  @protected
  void sse_encode_list_sftp_entry(
    List<SftpEntry> self,
    SseSerializer serializer,
  ) {
    sse_encode_i_32(self.length, serializer);
    for (final item in self) {
      sse_encode_sftp_entry(item, serializer);
    }
  }

  @protected
  void sse_encode_opt_String(String? self, SseSerializer serializer) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_String(self, serializer);
    }
  }

  @protected
  void
  sse_encode_opt_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
    ForwardedConnection? self,
    SseSerializer serializer,
  ) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_box_autoadd_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerForwardedConnection(
        self,
        serializer,
      );
    }
  }

  @protected
  void sse_encode_opt_box_autoadd_u_32(int? self, SseSerializer serializer) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_box_autoadd_u_32(self, serializer);
    }
  }

  @protected
  void sse_encode_opt_box_autoadd_u_64(BigInt? self, SseSerializer serializer) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_box_autoadd_u_64(self, serializer);
    }
  }

  @protected
  void sse_encode_opt_list_String(
    List<String>? self,
    SseSerializer serializer,
  ) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_list_String(self, serializer);
    }
  }

  @protected
  void sse_encode_opt_list_prim_u_8_strict(
    Uint8List? self,
    SseSerializer serializer,
  ) {
    sse_encode_bool(self != null, serializer);
    if (self != null) {
      sse_encode_list_prim_u_8_strict(self, serializer);
    }
  }

  @protected
  void sse_encode_sftp_attrs(SftpAttrs self, SseSerializer serializer) {
    sse_encode_opt_box_autoadd_u_64(self.size, serializer);
    sse_encode_opt_box_autoadd_u_32(self.uid, serializer);
    sse_encode_opt_box_autoadd_u_32(self.gid, serializer);
    sse_encode_opt_box_autoadd_u_32(self.permissions, serializer);
    sse_encode_opt_box_autoadd_u_32(self.atime, serializer);
    sse_encode_opt_box_autoadd_u_32(self.mtime, serializer);
  }

  @protected
  void sse_encode_sftp_entry(SftpEntry self, SseSerializer serializer) {
    sse_encode_String(self.filename, serializer);
    sse_encode_String(self.longname, serializer);
    sse_encode_sftp_attrs(self.attrs, serializer);
  }

  @protected
  void sse_encode_u_16(int self, SseSerializer serializer) {
    serializer.buffer.putUint16(self);
  }

  @protected
  void sse_encode_u_32(int self, SseSerializer serializer) {
    serializer.buffer.putUint32(self);
  }

  @protected
  void sse_encode_u_64(BigInt self, SseSerializer serializer) {
    serializer.buffer.putBigUint64(self);
  }

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer) {
    serializer.buffer.putUint8(self);
  }

  @protected
  void sse_encode_unit(void self, SseSerializer serializer) {}

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer) {
    serializer.buffer.putBigUint64(self);
  }
}

@sealed
class CancelTokenImpl extends RustOpaque implements CancelToken {
  CancelTokenImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  CancelTokenImpl.frbInternalSseDecode(BigInt ptr, int externalSizeOnNative)
    : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_increment_strong_count_CancelToken,
    rustArcDecrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_CancelToken,
    rustArcDecrementStrongCountPtr: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_CancelTokenPtr,
  );

  void cancel() =>
      WarpgateEngine.instance.api.crateApiUtilCancelTokenCancel(that: this);

  bool isCancelled() => WarpgateEngine.instance.api
      .crateApiUtilCancelTokenIsCancelled(that: this);
}

@sealed
class ForwardedConnectionImpl extends RustOpaque
    implements ForwardedConnection {
  ForwardedConnectionImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  ForwardedConnectionImpl.frbInternalSseDecode(
    BigInt ptr,
    int externalSizeOnNative,
  ) : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount: WarpgateEngine
        .instance
        .api
        .rust_arc_increment_strong_count_ForwardedConnection,
    rustArcDecrementStrongCount: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_ForwardedConnection,
    rustArcDecrementStrongCountPtr: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_ForwardedConnectionPtr,
  );

  SshChannel get channel => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorGetChannel(that: this);

  String get connectedHost => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorGetConnectedHost(that: this);

  int get connectedPort => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorGetConnectedPort(that: this);

  String get originHost => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorGetOriginHost(that: this);

  int get originPort => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorGetOriginPort(that: this);

  set channel(SshChannel channel) => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorSetChannel(
        that: this,
        channel: channel,
      );

  set connectedHost(String connectedHost) => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorSetConnectedHost(
        that: this,
        connectedHost: connectedHost,
      );

  set connectedPort(int connectedPort) => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorSetConnectedPort(
        that: this,
        connectedPort: connectedPort,
      );

  set originHost(String originHost) => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorSetOriginHost(
        that: this,
        originHost: originHost,
      );

  set originPort(int originPort) => WarpgateEngine.instance.api
      .crateApiSshForwardedConnectionAutoAccessorSetOriginPort(
        that: this,
        originPort: originPort,
      );
}

@sealed
class SftpFileImpl extends RustOpaque implements SftpFile {
  SftpFileImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  SftpFileImpl.frbInternalSseDecode(BigInt ptr, int externalSizeOnNative)
    : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_increment_strong_count_SftpFile,
    rustArcDecrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_SftpFile,
    rustArcDecrementStrongCountPtr:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_SftpFilePtr,
  );

  Future<void> close() =>
      WarpgateEngine.instance.api.crateApiSftpSftpFileClose(that: this);

  Future<Uint8List?> read({required BigInt offset, required int len}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpFileRead(
        that: this,
        offset: offset,
        len: len,
      );

  Future<BigInt?> size() =>
      WarpgateEngine.instance.api.crateApiSftpSftpFileSize(that: this);

  Future<void> write({required BigInt offset, required List<int> data}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpFileWrite(
        that: this,
        offset: offset,
        data: data,
      );
}

@sealed
class SftpSessionImpl extends RustOpaque implements SftpSession {
  SftpSessionImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  SftpSessionImpl.frbInternalSseDecode(BigInt ptr, int externalSizeOnNative)
    : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_increment_strong_count_SftpSession,
    rustArcDecrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_SftpSession,
    rustArcDecrementStrongCountPtr: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_SftpSessionPtr,
  );

  Future<void> close() =>
      WarpgateEngine.instance.api.crateApiSftpSftpSessionClose(that: this);

  Future<List<SftpEntry>> list({required String path}) => WarpgateEngine
      .instance
      .api
      .crateApiSftpSftpSessionList(that: this, path: path);

  Future<void> mkdir({required String path}) => WarpgateEngine.instance.api
      .crateApiSftpSftpSessionMkdir(that: this, path: path);

  Future<SftpFile> open({required String path, required int flags}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpSessionOpen(
        that: this,
        path: path,
        flags: flags,
      );

  Future<String> realpath({required String path}) => WarpgateEngine.instance.api
      .crateApiSftpSftpSessionRealpath(that: this, path: path);

  Future<void> remove({required String path}) => WarpgateEngine.instance.api
      .crateApiSftpSftpSessionRemove(that: this, path: path);

  Future<void> rename({required String from, required String to}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpSessionRename(
        that: this,
        from: from,
        to: to,
      );

  Future<void> rmdir({required String path}) => WarpgateEngine.instance.api
      .crateApiSftpSftpSessionRmdir(that: this, path: path);

  Future<void> setPermissions({required String path, required int mode}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpSessionSetPermissions(
        that: this,
        path: path,
        mode: mode,
      );

  Future<SftpAttrs> stat({required String path, required bool followLinks}) =>
      WarpgateEngine.instance.api.crateApiSftpSftpSessionStat(
        that: this,
        path: path,
        followLinks: followLinks,
      );
}

@sealed
class SshChannelImpl extends RustOpaque implements SshChannel {
  SshChannelImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  SshChannelImpl.frbInternalSseDecode(BigInt ptr, int externalSizeOnNative)
    : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_increment_strong_count_SshChannel,
    rustArcDecrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_SshChannel,
    rustArcDecrementStrongCountPtr: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_SshChannelPtr,
  );

  Future<void> close() =>
      WarpgateEngine.instance.api.crateApiSshSshChannelClose(that: this);

  Future<void> eof() =>
      WarpgateEngine.instance.api.crateApiSshSshChannelEof(that: this);

  Future<void> exec({required String command}) => WarpgateEngine.instance.api
      .crateApiSshSshChannelExec(that: this, command: command);

  int? exitStatus() =>
      WarpgateEngine.instance.api.crateApiSshSshChannelExitStatus(that: this);

  Future<ChannelChunk> read({required int maxBytes}) => WarpgateEngine
      .instance
      .api
      .crateApiSshSshChannelRead(that: this, maxBytes: maxBytes);

  Future<void> requestPty({
    required String term,
    required int columns,
    required int rows,
  }) => WarpgateEngine.instance.api.crateApiSshSshChannelRequestPty(
    that: this,
    term: term,
    columns: columns,
    rows: rows,
  );

  Future<void> requestShell() =>
      WarpgateEngine.instance.api.crateApiSshSshChannelRequestShell(that: this);

  Future<void> setEnv({required String name, required String value}) =>
      WarpgateEngine.instance.api.crateApiSshSshChannelSetEnv(
        that: this,
        name: name,
        value: value,
      );

  Future<void> windowChange({required int columns, required int rows}) =>
      WarpgateEngine.instance.api.crateApiSshSshChannelWindowChange(
        that: this,
        columns: columns,
        rows: rows,
      );

  Future<void> write({required List<int> data}) => WarpgateEngine.instance.api
      .crateApiSshSshChannelWrite(that: this, data: data);
}

@sealed
class SshClientImpl extends RustOpaque implements SshClient {
  SshClientImpl.frbInternalDcoDecode(List<dynamic> wire)
    : super.frbInternalDcoDecode(wire, _kStaticData);

  SshClientImpl.frbInternalSseDecode(BigInt ptr, int externalSizeOnNative)
    : super.frbInternalSseDecode(ptr, externalSizeOnNative, _kStaticData);

  static final _kStaticData = RustArcStaticData(
    rustArcIncrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_increment_strong_count_SshClient,
    rustArcDecrementStrongCount:
        WarpgateEngine.instance.api.rust_arc_decrement_strong_count_SshClient,
    rustArcDecrementStrongCountPtr: WarpgateEngine
        .instance
        .api
        .rust_arc_decrement_strong_count_SshClientPtr,
  );

  Future<ForwardedConnection?> acceptForwarded() => WarpgateEngine.instance.api
      .crateApiSshSshClientAcceptForwarded(that: this);

  Future<bool> authAgent({required String user, String? socket}) =>
      WarpgateEngine.instance.api.crateApiSshSshClientAuthAgent(
        that: this,
        user: user,
        socket: socket,
      );

  Future<bool> authKey({
    required String user,
    required String pem,
    String? passphrase,
  }) => WarpgateEngine.instance.api.crateApiSshSshClientAuthKey(
    that: this,
    user: user,
    pem: pem,
    passphrase: passphrase,
  );

  Future<bool> authKeyboardInteractive({
    required String user,
    required FutureOr<List<String>?> Function(
      String,
      String,
      List<String>,
      List<bool>,
    )
    responder,
  }) => WarpgateEngine.instance.api.crateApiSshSshClientAuthKeyboardInteractive(
    that: this,
    user: user,
    responder: responder,
  );

  Future<bool> authNone({required String user}) => WarpgateEngine.instance.api
      .crateApiSshSshClientAuthNone(that: this, user: user);

  Future<bool> authPassword({required String user, required String password}) =>
      WarpgateEngine.instance.api.crateApiSshSshClientAuthPassword(
        that: this,
        user: user,
        password: password,
      );

  Future<void> cancelForwardRemote({required String host, required int port}) =>
      WarpgateEngine.instance.api.crateApiSshSshClientCancelForwardRemote(
        that: this,
        host: host,
        port: port,
      );

  Future<SshClient> connectVia({
    required ConnectParams params,
    required FutureOr<bool> Function(String, String) verifier,
  }) => WarpgateEngine.instance.api.crateApiSshSshClientConnectVia(
    that: this,
    params: params,
    verifier: verifier,
  );

  Future<void> disconnect() =>
      WarpgateEngine.instance.api.crateApiSshSshClientDisconnect(that: this);

  Future<int> forwardRemote({required String host, required int port}) =>
      WarpgateEngine.instance.api.crateApiSshSshClientForwardRemote(
        that: this,
        host: host,
        port: port,
      );

  bool isClosed() =>
      WarpgateEngine.instance.api.crateApiSshSshClientIsClosed(that: this);

  Future<SshChannel> openDirectTcpip({
    required String host,
    required int port,
  }) => WarpgateEngine.instance.api.crateApiSshSshClientOpenDirectTcpip(
    that: this,
    host: host,
    port: port,
  );

  Future<SshChannel> openSession() =>
      WarpgateEngine.instance.api.crateApiSshSshClientOpenSession(that: this);

  Future<void> ping({required int timeoutMs}) => WarpgateEngine.instance.api
      .crateApiSshSshClientPing(that: this, timeoutMs: timeoutMs);

  String? remoteVersion() =>
      WarpgateEngine.instance.api.crateApiSshSshClientRemoteVersion(that: this);

  Future<SftpSession> sftp() =>
      WarpgateEngine.instance.api.crateApiSshSshClientSftp(that: this);

  Future<void> waitClosed() =>
      WarpgateEngine.instance.api.crateApiSshSshClientWaitClosed(that: this);
}
