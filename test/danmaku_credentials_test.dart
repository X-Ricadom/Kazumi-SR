import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/pages/settings/danmaku/danmaku_credentials_dialog.dart';
import 'package:kazumi/request/core/danmaku_exception.dart';
import 'package:kazumi/services/storage/danmaku_credential_service.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:logger/logger.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Directory directory;
  late PathProviderPlatform originalPaths;
  late _Adapter adapter;
  late _Store store;
  late DanmakuCredentialService originalService;
  setUpAll(() async {
    Logger.level = Level.off;
    directory = await Directory.systemTemp.createTemp('kazumi_danmaku_test_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    Hive.init(directory.path);
    await GStorage.init();
  });
  setUp(() {
    originalService = DanmakuCredentialService.instance;
    store = _Store();
    DanmakuCredentialService.instance = DanmakuCredentialService(store: store);
    DioFactory.reset();
    adapter = _Adapter();
    DioFactory.apiDio.httpClientAdapter.close();
    DioFactory.apiDio.httpClientAdapter = adapter;
  });
  tearDownAll(() async {
    DioFactory.reset();
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    await directory.delete(recursive: true);
  });
  tearDown(() => DanmakuCredentialService.instance = originalService);

  test(
    'missing credentials gives an actionable error before network access',
    () async {
      await expectLater(
        DanmakuApi.searchAnimes('进击的巨人'),
        throwsA(predicate((error) => error.toString().contains('未配置弹弹play凭证'))),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'custom overrides bundled credentials and clear restores fallback',
    () async {
      final service = DanmakuCredentialService(
        store: store,
        bundled: const DanmakuCredentials('bundled-id', 'bundled-secret'),
      );
      expect((await service.resolve()).appId, 'bundled-id');
      await service.save(
        const DanmakuCredentials(' personal-id ', ' personal-secret '),
      );
      expect((await service.resolve()).appId, 'personal-id');
      expect((await service.resolve()).secret, 'personal-secret');
      await service.clear();
      expect((await service.resolve()).appId, 'bundled-id');
    },
  );

  test('incomplete credentials do not overwrite saved credentials', () async {
    final service = DanmakuCredentialService.instance;
    await service.save(const DanmakuCredentials('personal', 'secret'));
    await expectLater(
      service.save(const DanmakuCredentials('changed', '')),
      throwsA(isA<DanmakuException>()),
    );
    expect((await service.resolve()).appId, 'personal');
    expect(
      const DanmakuCredentials('personal', 'secret').toString(),
      isNot(contains('secret')),
    );
  });

  test(
    'search, full episodes and comments share current credentials and sign paths',
    () async {
      await DanmakuCredentialService.instance.save(
        const DanmakuCredentials('personal', 'secret'),
      );
      adapter.respond = (request) async {
        if (request.uri.path.contains('/search/')) {
          return _json({
            'success': true,
            'animes': [
              {'animeId': 123, 'animeTitle': '测试番剧', 'typeDescription': 'TV'},
            ],
            'hasMore': false,
          });
        }
        if (request.uri.path.contains('/bangumi/')) {
          return _json({
            'success': true,
            'errorCode': 0,
            'errorMessage': '',
            'bangumi': {
              'animeId': 123,
              'episodes': [
                {'episodeId': 1230001, 'episodeTitle': '第一话'},
              ],
            },
          });
        }
        return _json({'success': true, 'comments': []});
      };
      final search = await DanmakuApi.searchAnimes('测试番剧');
      final episodes = await DanmakuApi.getDanDanEpisodesByDanDanBangumiID(
        search.animes.single.animeId,
      );
      expect(
        await DanmakuApi.getDanDanmakuByEpisodeID(
          episodes.episodes.single.episodeId,
        ),
        isEmpty,
      );
      expect(adapter.requests, hasLength(3));
      for (final request in adapter.requests) {
        final stamp = request.headers['X-Timestamp'];
        expect(request.headers['X-AppId'], 'personal');
        expect(
          request.headers['X-Signature'],
          base64Encode(
            sha256
                .convert(utf8.encode('personal$stamp${request.uri.path}secret'))
                .bytes,
          ),
        );
        expect(request.uri.query, isNot(contains('secret')));
        expect(request.headers, isNot(contains('X-AppSecret')));
      }
      await DanmakuCredentialService.instance.save(
        const DanmakuCredentials('new-id', 'new-secret'),
      );
      await DanmakuApi.searchAnimes('测试番剧');
      expect(adapter.requests.last.headers['X-AppId'], 'new-id');
    },
  );

  for (final entry in {
    'Missing Authentication Headers': '未配置',
    'Invalid AppId': '凭证无效',
    'Invalid AppSecret': '凭证无效',
    'Invalid Timestamp': '同步系统时间',
    'Invalid Signature': '签名验证失败',
    'untrusted server message secret': '拒绝访问',
  }.entries) {
    test('403 maps ${entry.key} to an actionable safe error', () async {
      await DanmakuCredentialService.instance.save(
        const DanmakuCredentials('personal', 'secret'),
      );
      adapter.respond = (_) async => ResponseBody.fromString(
        '',
        403,
        headers: {
          'x-error-message': [entry.key],
        },
      );
      await expectLater(
        DanmakuApi.searchAnimes('测试'),
        throwsA(
          predicate(
            (error) =>
                error is DanmakuException &&
                error.message.contains(entry.value) &&
                !error.message.contains('secret'),
          ),
        ),
      );
    });
  }

  test(
    'business failure and non JSON are not reported as no matches',
    () async {
      await DanmakuCredentialService.instance.save(
        const DanmakuCredentials('personal', 'secret'),
      );
      adapter.respond = (_) async =>
          _json({'success': false, 'errorCode': 1, 'errorMessage': 'secret'});
      await expectLater(
        DanmakuApi.searchAnimes('测试'),
        throwsA(isA<DanmakuException>()),
      );
      adapter.respond = (_) async =>
          ResponseBody.fromString('<html>error</html>', 200);
      await expectLater(
        DanmakuApi.searchAnimes('测试'),
        throwsA(isA<DanmakuException>()),
      );
      adapter.respond = (_) async =>
          _json({'success': true, 'animes': [], 'hasMore': false});
      expect((await DanmakuApi.searchAnimes('无匹配')).animes, isEmpty);
    },
  );

  test('timeout has a specific message', () async {
    await DanmakuCredentialService.instance.save(
      const DanmakuCredentials('personal', 'secret'),
    );
    adapter.respond = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.receiveTimeout,
    );
    try {
      await DanmakuApi.searchAnimes('测试');
      fail('expected timeout');
    } catch (e) {
      expect(DanmakuException.messageFor(e), contains('超时'));
    }
  });

  test('draft validation does not save or switch active credentials', () async {
    await DanmakuCredentialService.instance.save(
      const DanmakuCredentials('saved', 'saved-secret'),
    );
    adapter.respond = (_) async => _json({'success': true, 'animes': []});
    await DanmakuApi.validateCredentials(
      const DanmakuCredentials('draft', 'draft-secret'),
    );
    expect(adapter.requests.single.headers['X-AppId'], 'draft');
    expect((await DanmakuCredentialService.instance.resolve()).appId, 'saved');
  });

  testWidgets('dialog masks secret, validates draft, saves and clears', (
    tester,
  ) async {
    final service = DanmakuCredentialService.instance;
    DanmakuCredentials? validated;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DanmakuCredentialsDialog(
            service: service,
            validate: (value) async {
              validated = value;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'personal');
    await tester.enterText(fields.at(1), 'secret');
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    await tester.tap(find.text('验证连接'));
    await tester.pumpAndSettle();
    expect(validated?.appId, 'personal');
    expect(store.value, isNull);
    expect(find.text('连接验证通过，点击保存后生效'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.value?.secret, 'secret');
    expect(find.text('当前使用：自定义凭证'), findsOneWidget);
    await tester.tap(find.text('清除自定义'));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.text('当前未配置凭证'), findsOneWidget);
  });

  test(
    'Windows vault supports isolated write, reopen, overwrite and delete',
    () async {
      final target = 'KazumiSR/test/${DateTime.now().microsecondsSinceEpoch}';
      final vault = WindowsDanmakuCredentialStore(target: target);
      try {
        expect(await vault.read(), isNull);
        await vault.write(const DanmakuCredentials('test-id', 'test-secret'));
        final reopened = WindowsDanmakuCredentialStore(target: target);
        expect((await reopened.read())?.secret, 'test-secret');
        await reopened.write(
          const DanmakuCredentials('updated-id', 'updated-secret'),
        );
        expect((await vault.read())?.appId, 'updated-id');
        await vault.delete();
        expect(await reopened.read(), isNull);
        await vault.delete();
      } finally {
        await vault.delete();
      }
    },
    skip:
        !Platform.isWindows || !const bool.fromEnvironment('KAZUMI_TEST_VAULT'),
  );
}

ResponseBody _json(Object data) => ResponseBody.fromString(
  jsonEncode(data),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Store implements DanmakuCredentialStore {
  DanmakuCredentials? value;
  @override
  Future<DanmakuCredentials?> read() async => value;
  @override
  Future<void> write(DanmakuCredentials credentials) async {
    value = credentials;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async =>
      ResponseBody.fromString(
        '',
        403,
        headers: {
          'x-error-message': ['Missing Authentication Headers'],
        },
      );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}
