import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/pages/search/search_controller.dart';
import 'package:kazumi/repositories/collect_repository.dart';
import 'package:kazumi/repositories/search_history_repository.dart';
import 'package:kazumi/request/clients/bangumi_client.dart';
import 'package:kazumi/request/apis/bangumi_api.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late _SearchAdapter adapter;
  late SearchPageController controller;

  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_search_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });

  setUp(() async {
    await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'mirror');
    DioFactory.reset();
    adapter = _SearchAdapter();
    DioFactory.bangumiDio.httpClientAdapter.close();
    DioFactory.bangumiDio.httpClientAdapter = adapter;
    controller = SearchPageController(
      CollectRepository(),
      SearchHistoryRepository(),
    );
  });

  tearDownAll(() async {
    DioFactory.reset();
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    expect(
      directory.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    expect(
      directory.uri.pathSegments.where((part) => part.isNotEmpty).last,
      startsWith('kazumi_search_test_'),
    );
    await directory.delete(recursive: true);
  });

  test(
    'unsigned mirror build finds known anime through official search',
    () async {
      adapter.respond = (request) async => request.uri.host == 'api.kazumi.fyi'
          ? _json({'error': 'Unauthorized'}, status: 401)
          : _page([_anime(1)]);
      await controller.searchBangumi('进击的巨人', type: 'new');
      expect(controller.bangumiList.map((item) => item.id), [1]);
      expect(adapter.requests.single.uri.host, 'api.bgm.tv');
      expect(adapter.requests.single.uri.queryParameters, {
        'limit': '20',
        'offset': '0',
      });
      expect(adapter.requests.single.extra['bangumiEch'], isTrue);
      expect(adapter.requests.single.headers, isNot(contains('X-Signature')));
      expect(GStorage.getSetting(SettingsKeys.bangumiAcceleration), 'mirror');
    },
  );

  test('public mirror requests retain mirror routing', () async {
    await BangumiClient.instance.get('https://next.bgm.tv/p1/subjects/1');
    expect(adapter.requests.single.uri.host, 'api.kazumi.fyi');
    expect(adapter.requests.single.extra['bangumiEch'], isNot(true));
  });

  test('explicit direct search retains direct transport', () async {
    await GStorage.putSetting(SettingsKeys.bangumiAcceleration, 'direct');
    await controller.searchBangumi('巨人', type: 'new');
    expect(adapter.requests.single.uri.host, 'api.bgm.tv');
    expect(adapter.requests.single.extra['bangumiEch'], isNot(true));
  });

  test(
    'request failure is distinguishable from no matches and can retry',
    () async {
      adapter.respond = (_) async => _json({}, status: 401);
      await controller.searchBangumi('巨人', type: 'new');
      expect((controller as dynamic).searchError, contains('401'));
      expect(controller.isLoading, isFalse);
      adapter.respond = (_) async => _page([_anime(1)]);
      await controller.searchBangumi('巨人', type: 'new');
      expect((controller as dynamic).searchError, isEmpty);
      expect(controller.bangumiList, hasLength(1));
      adapter.respond = (_) async => _page([]);
      await controller.searchBangumi('不存在的作品', type: 'new');
      expect((controller as dynamic).searchError, isEmpty);
      expect(controller.bangumiList, isEmpty);
      expect(controller.hasMoreSearchResults, isFalse);
    },
  );

  test('timeout stops loading and has a specific error', () async {
    adapter.respond = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.connectionTimeout,
    );
    await controller.searchBangumi('巨人', type: 'new');
    expect((controller as dynamic).searchError, contains('超时'));
    expect(controller.isLoading, isFalse);
  });

  test(
    'failed next page preserves items and retries the same offset',
    () async {
      adapter.respond = (_) async =>
          _page(List.generate(20, (i) => _anime(i + 1)));
      await controller.searchBangumi('巨人', type: 'new');
      adapter.respond = (_) async => _json({}, status: 503);
      await controller.searchBangumi('巨人');
      expect(controller.bangumiList, hasLength(20));
      expect((controller as dynamic).searchError, isNotEmpty);
      adapter.respond = (_) async => _page([_anime(21)]);
      await controller.searchBangumi('巨人');
      expect(adapter.requests.last.uri.queryParameters['offset'], '20');
      expect(controller.bangumiList, hasLength(21));
      expect((controller as dynamic).searchError, isEmpty);
    },
  );

  test('stale failed search cannot overwrite a newer success', () async {
    final pending = Completer<ResponseBody>();
    final started = Completer<void>();
    adapter.respond = (_) {
      started.complete();
      return pending.future;
    };
    final oldSearch = controller.searchBangumi('旧查询', type: 'new');
    await started.future;
    adapter.respond = (_) async => _page([_anime(2)]);
    await controller.searchBangumi('新查询', type: 'new');
    pending.complete(_json({}, status: 401));
    await oldSearch;
    expect(controller.bangumiList.map((item) => item.id), [2]);
    expect((controller as dynamic).searchError, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test(
    'live official searches use the production ECH transport',
    () async {
      DioFactory.reset();
      for (final keyword in ['进击的巨人', '葬送のフリーレン']) {
        await controller.searchBangumi(keyword, type: 'new');
        // Live diagnostics are printed only in the explicitly enabled test.
        // ignore: avoid_print
        print(
          'LIVE search=$keyword items=${controller.bangumiList.length} '
          'error=${(controller as dynamic).searchError}',
        );
        expect((controller as dynamic).searchError, isEmpty);
        expect(controller.bangumiList, isNotEmpty);
      }
      final page = await BangumiApi.bangumiSearch('巨人', limit: 1, offset: 1);
      // ignore: avoid_print
      print('LIVE pagination raw=${page.rawCount} parsed=${page.items.length}');
      expect(page.items, isNotEmpty);
    },
    skip: !const bool.fromEnvironment('KAZUMI_LIVE_SEARCH'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Map<String, dynamic> _anime(int id) => {
  'id': id,
  'name': '進撃の巨人',
  'name_cn': '进击的巨人',
  'date': '2013-04-06',
  'images': <String, String>{},
  'rating': {'rank': 1, 'score': 8.0, 'total': 1, 'count': List.filled(10, 0)},
};
ResponseBody _page(List<dynamic> items) => _json({'data': items});
ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _SearchAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async =>
      _page([_anime(1)]);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
