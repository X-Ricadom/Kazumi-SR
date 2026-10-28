import 'package:dio/dio.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/network_error_mapper.dart';
import 'package:kazumi/request/core/danmaku_exception.dart';
import 'package:kazumi/services/storage/danmaku_credential_service.dart';
import 'package:kazumi/utils/http_headers.dart';
import 'package:kazumi/utils/crypto.dart';

class DanmakuClient {
  DanmakuClient._();

  static final DanmakuClient instance = DanmakuClient._();

  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic> headers = const {},
    CancelToken? cancelToken,
    DanmakuCredentials? credentials,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' || uri.host != 'api.dandanplay.net') {
      throw const DanmakuException('弹弹play请求地址无效');
    }
    final auth =
        credentials?.normalized() ??
        await DanmakuCredentialService.instance.resolve();
    final requestHeaders = <String, dynamic>{
      'user-agent': getRandomUA(),
      'referer': '',
      'X-Auth': 1,
      ...headers,
      'X-AppId': auth.appId,
      'X-Timestamp': timestamp,
      'X-Signature': generateDandanSignature(
        uri.path,
        timestamp,
        appId: auth.appId,
        secret: auth.secret,
      ),
    };

    try {
      final response = await DioFactory.apiDio.get(
        url,
        queryParameters: queryParameters,
        options: Options(headers: requestHeaders),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) throw DanmakuException.invalidResponse;
      if (data['success'] == false) {
        // Do not echo arbitrary server text, which could contain request data.
        throw const DanmakuException('弹弹play未能完成请求，请检查检索内容后重试');
      }
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw DanmakuException.fromAuthError(
          e.response?.headers.value('x-error-message'),
          e.response?.statusCode,
        );
      }
      if (e.response?.statusCode == 429) {
        throw const DanmakuException('弹弹play请求过于频繁，请稍后重试');
      }
      throw await NetworkErrorMapper.mapException(e);
    }
  }
}
