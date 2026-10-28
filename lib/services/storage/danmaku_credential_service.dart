import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:kazumi/request/core/danmaku_exception.dart';
import 'package:kazumi/utils/dandan_credentials.dart';
import 'package:win32/win32.dart';

class DanmakuCredentials {
  const DanmakuCredentials(this.appId, this.secret);

  final String appId;
  final String secret;
  bool get isComplete => appId.isNotEmpty && secret.isNotEmpty;

  DanmakuCredentials normalized() {
    final result = DanmakuCredentials(appId.trim(), secret.trim());
    if (!result.isComplete ||
        RegExp(r'\s|[\x00-\x1f\x7f]').hasMatch(result.appId + result.secret) ||
        result.appId.length > 256 ||
        result.secret.length > 1024) {
      throw const DanmakuException('请完整填写 App ID 和 App Secret，且不要包含空白字符');
    }
    return result;
  }

  @override
  String toString() => 'DanmakuCredentials(<redacted>)';
}

abstract class DanmakuCredentialStore {
  Future<DanmakuCredentials?> read();
  Future<void> write(DanmakuCredentials credentials);
  Future<void> delete();
}

/// A single generic credential makes updates of the ID/secret pair atomic.
/// Nothing is written to Hive, exported settings or the portable directory.
class WindowsDanmakuCredentialStore implements DanmakuCredentialStore {
  WindowsDanmakuCredentialStore({this.target = 'KazumiSR/dandanplay/v1'});
  final String target;

  @override
  Future<DanmakuCredentials?> read() async {
    if (!Platform.isWindows) return null;
    final name = target.toNativeUtf16();
    final output = calloc<Pointer<CREDENTIAL>>();
    try {
      // Resolve the lazy FFI binding before CredRead sets thread-local last error.
      GetLastError();
      if (CredRead(name, CRED_TYPE_GENERIC, 0, output) == 0) {
        if (GetLastError() == ERROR_NOT_FOUND) return null;
        throw DanmakuException.storageFailure;
      }
      final credential = output.value.ref;
      if (credential.CredentialBlobSize > 2560 ||
          credential.CredentialBlob == nullptr) {
        throw DanmakuException.storageFailure;
      }
      final data =
          jsonDecode(
                utf8.decode(
                  credential.CredentialBlob.asTypedList(
                    credential.CredentialBlobSize,
                  ),
                ),
              )
              as Map<String, dynamic>;
      return DanmakuCredentials(
        data['appId'] as String,
        data['secret'] as String,
      ).normalized();
    } catch (_) {
      throw DanmakuException.storageFailure;
    } finally {
      if (output.value != nullptr) CredFree(output.value);
      calloc.free(output);
      calloc.free(name);
    }
  }

  @override
  Future<void> write(DanmakuCredentials credentials) async {
    if (!Platform.isWindows) {
      throw const DanmakuException('此平台暂不支持保存自定义凭证，请使用编译注入的凭证');
    }
    final value = credentials.normalized();
    final bytes = utf8.encode(
      jsonEncode({'appId': value.appId, 'secret': value.secret}),
    );
    if (bytes.length > 2560) {
      throw const DanmakuException('凭证内容过长，请检查 App ID 和 App Secret');
    }
    final name = target.toNativeUtf16();
    final user = value.appId.toNativeUtf16();
    final blob = calloc<Uint8>(bytes.length);
    final credential = calloc<CREDENTIAL>();
    try {
      blob.asTypedList(bytes.length).setAll(0, bytes);
      credential.ref
        ..Type = CRED_TYPE_GENERIC
        ..TargetName = name
        ..UserName = user
        ..CredentialBlobSize = bytes.length
        ..CredentialBlob = blob
        ..Persist = CRED_PERSIST_LOCAL_MACHINE;
      if (CredWrite(credential, 0) == 0) throw DanmakuException.storageFailure;
    } finally {
      blob.asTypedList(bytes.length).fillRange(0, bytes.length, 0);
      calloc.free(credential);
      calloc.free(blob);
      calloc.free(user);
      calloc.free(name);
    }
  }

  @override
  Future<void> delete() async {
    if (!Platform.isWindows) return;
    final name = target.toNativeUtf16();
    try {
      GetLastError();
      if (CredDelete(name, CRED_TYPE_GENERIC, 0) == 0 &&
          GetLastError() != ERROR_NOT_FOUND) {
        throw DanmakuException.storageFailure;
      }
    } finally {
      calloc.free(name);
    }
  }
}

class DanmakuCredentialService {
  DanmakuCredentialService({
    required this.store,
    this.bundled = const DanmakuCredentials(
      String.fromEnvironment('DANDANAPI_APPID'),
      String.fromEnvironment('DANDANAPI_KEY'),
    ),
  });

  static DanmakuCredentialService instance = DanmakuCredentialService(
    store: WindowsDanmakuCredentialStore(),
    bundled: DanmakuCredentials(
      dandanCredentials['id']!,
      dandanCredentials['value']!,
    ),
  );

  final DanmakuCredentialStore store;
  final DanmakuCredentials bundled;

  Future<DanmakuCredentials> resolve() async {
    final custom = await store.read();
    if (custom != null) return custom.normalized();
    if (bundled.isComplete) return bundled.normalized();
    throw DanmakuException.missingCredentials;
  }

  Future<DanmakuCredentials?> readCustom() => store.read();
  Future<void> save(DanmakuCredentials credentials) async {
    await store.write(credentials.normalized());
  }

  Future<void> clear() => store.delete();
}
