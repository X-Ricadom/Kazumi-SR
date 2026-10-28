import 'package:kazumi/modules/danmaku/danmaku_ch_convert.dart';
import 'package:kazumi/modules/danmaku/danmaku_episode_response.dart';
import 'package:kazumi/modules/danmaku/danmaku_module.dart';
import 'package:kazumi/modules/danmaku/danmaku_search_response.dart';
import 'package:kazumi/request/clients/danmaku_client.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/danmaku_credential_service.dart';
import 'package:kazumi/request/core/danmaku_exception.dart';

class DanmakuApi {
  static final DanmakuClient _client = DanmakuClient.instance;

  static T _parse<T>(dynamic json, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(json as Map<String, dynamic>);
    } catch (_) {
      throw DanmakuException.invalidResponse;
    }
  }

  /// Validate the draft without saving it or changing active credentials.
  static Future<void> validateCredentials(
    DanmakuCredentials credentials,
  ) async {
    final json = await _client.get(
      ApiEndpoints.dandanAPIDomain + ApiEndpoints.dandanAPISearchEpisodes,
      queryParameters: {'anime': '进击的巨人', 'v2': 'true'},
      credentials: credentials,
    );
    _parse(json, DanmakuSearchResponse.fromJson);
  }

  static Future<int> getDanDanBangumiIDByBgmBangumiID(int bgmBangumiID) async {
    final path = ApiEndpoints.formatUrl(
      ApiEndpoints.dandanAPIInfoByBgmBangumiId,
      [bgmBangumiID],
    );
    final endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    return _parse(jsonData, DanmakuEpisodeResponse.fromJson).bangumiId;
  }

  static Future<DanmakuEpisodeResponse> getDanDanEpisodesByDanDanBangumiID(
    int bangumiID,
  ) async {
    final path = ApiEndpoints.dandanAPIInfo + bangumiID.toString();
    final endPoint = ApiEndpoints.dandanAPIDomain + path;
    final jsonData = await _client.get(endPoint);
    return _parse(jsonData, DanmakuEpisodeResponse.fromJson);
  }

  // v2 episode search avoids the anime search's 25-result cap.
  // Fetch full episode lists separately; search results can truncate them.
  static Future<DanmakuSearchResponse> searchAnimes(String title) async {
    final endPoint =
        ApiEndpoints.dandanAPIDomain + ApiEndpoints.dandanAPISearchEpisodes;
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {'anime': title, 'v2': 'true'},
    );
    return _parse(jsonData, DanmakuSearchResponse.fromJson);
  }

  static Future<List<DanmakuEntry>> getDanDanmaku(
    int bangumiID,
    int episode,
  ) async {
    if (bangumiID == 0) {
      return [];
    }
    // Automatic matching relies on an undocumented episode ID convention.
    return _getComments('$bangumiID${episode.toString().padLeft(4, '0')}');
  }

  static Future<List<DanmakuEntry>> getDanDanmakuByEpisodeID(int episodeID) =>
      _getComments(episodeID.toString());

  static Future<List<DanmakuEntry>> _getComments(String episodeID) async {
    final endPoint =
        '${ApiEndpoints.dandanAPIDomain}${ApiEndpoints.dandanAPIComment}$episodeID';
    final conversion = DanmakuChConvert.fromValue(
      GStorage.getSetting(SettingsKeys.danmakuChConvert),
    );
    KazumiLogger().i('Danmaku: final request URL $endPoint');
    final jsonData = await _client.get(
      endPoint,
      queryParameters: {
        'withRelated': 'true',
        'chConvert': conversion.value.toString(),
      },
    );
    return _parse(jsonData, (json) {
      final comments = json['comments'] as List<dynamic>;
      return [for (final comment in comments) DanmakuEntry.fromJson(comment)];
    });
  }
}
