import 'package:kazumi/request/core/network_exception.dart';

/// Only safe, locally generated messages cross the API/UI/log boundary.
class DanmakuException implements Exception {
  const DanmakuException(this.message, {this.needsCredentials = false});

  static const missingCredentials = DanmakuException(
    '未配置弹弹play凭证，请在弹幕设置中填写 App ID 和 App Secret',
    needsCredentials: true,
  );
  static const storageFailure = DanmakuException('无法访问 Windows 凭据管理器，请重试');
  static const invalidResponse = DanmakuException('弹弹play响应格式异常，请稍后重试');

  final String message;
  final bool needsCredentials;

  static DanmakuException fromAuthError(String? reason, int? status) {
    return switch (reason) {
      'Missing Authentication Headers' => missingCredentials,
      'Invalid AppId' || 'Invalid AppSecret' => const DanmakuException(
        '弹弹play凭证无效，请检查 App ID 和 App Secret',
        needsCredentials: true,
      ),
      'Invalid Timestamp' => const DanmakuException('弹弹play鉴权时间戳无效，请同步系统时间后重试'),
      'Invalid Signature' => const DanmakuException(
        '弹弹play签名验证失败，请检查 App ID 和 App Secret',
        needsCredentials: true,
      ),
      _ => DanmakuException(
        '弹弹play拒绝访问（${status ?? 403}），请检查凭证或网络后重试',
        needsCredentials: true,
      ),
    };
  }

  static String messageFor(Object error) {
    if (error is DanmakuException) return error.message;
    if (error is NetworkException) {
      return switch (error.type) {
        NetworkExceptionType.connectionTimeout ||
        NetworkExceptionType.receiveTimeout ||
        NetworkExceptionType.sendTimeout => '弹弹play请求超时，请重试',
        NetworkExceptionType.connectionError => '无法连接弹弹play，请检查网络或代理设置',
        NetworkExceptionType.badCertificate => '弹弹play连接证书异常，请检查网络设置',
        NetworkExceptionType.cancel => '弹弹play请求已取消',
        NetworkExceptionType.parseError => invalidResponse.message,
        _ => '弹弹play请求失败，请稍后重试',
      };
    }
    return '弹弹play请求失败，请稍后重试';
  }

  @override
  String toString() => message;
}
