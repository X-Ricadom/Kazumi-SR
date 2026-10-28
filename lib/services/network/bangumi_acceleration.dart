import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/utils/bangumi_mirror_credentials.dart';

enum BangumiAcceleration {
  direct,
  ech,
  mirror;

  static bool isProtectedMirrorRequest(Uri uri, String method) {
    if (!ApiEndpoints.bangumiPublicApiHosts.contains(uri.host)) return false;
    if (method == 'POST' && uri.path == '/v0/search/subjects') return true;
    if (method != 'GET' || !uri.path.endsWith('/comments')) return false;
    return uri.path.startsWith('/p1/subjects/') ||
        uri.path.startsWith('/p1/episodes/') ||
        uri.path.startsWith('/p1/characters/');
  }

  // Local builds lack the private mirror signing keys. Use the official API
  // with ECH for protected requests, without changing the user's mirror mode.
  static BangumiAcceleration forRequest(Uri uri, String method) {
    final mode = current;
    if (mode == mirror &&
        !hasBangumiMirrorCredentials &&
        isProtectedMirrorRequest(uri, method)) {
      return ech;
    }
    return mode;
  }

  static BangumiAcceleration get current => switch (GStorage.getSetting(
    SettingsKeys.bangumiAcceleration,
  )) {
    'direct' => direct,
    'ech' => ech,
    'mirror' => mirror,
    _ => GStorage.getSetting(SettingsKeys.enableBangumiProxy) ? mirror : direct,
  };

  String get label => switch (this) {
    direct => '直连',
    ech => 'ECH',
    mirror => '镜像',
  };
}
