import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kazumi/request/apis/danmaku_api.dart';
import 'package:kazumi/request/core/danmaku_exception.dart';
import 'package:kazumi/services/storage/danmaku_credential_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showDanmakuCredentialsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const DanmakuCredentialsDialog(),
  );
}

class DanmakuCredentialsDialog extends StatefulWidget {
  const DanmakuCredentialsDialog({super.key, this.service, this.validate});

  final DanmakuCredentialService? service;
  final Future<void> Function(DanmakuCredentials)? validate;

  @override
  State<DanmakuCredentialsDialog> createState() =>
      _DanmakuCredentialsDialogState();
}

class _DanmakuCredentialsDialogState extends State<DanmakuCredentialsDialog> {
  final _appId = TextEditingController();
  final _secret = TextEditingController();
  late final _service = widget.service ?? DanmakuCredentialService.instance;
  bool _busy = true;
  bool _visible = false;
  bool _custom = false;
  bool _error = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final credentials = await _service.readCustom();
      if (!mounted) return;
      _appId.text = credentials?.appId ?? '';
      _secret.text = credentials?.secret ?? '';
      _custom = credentials != null;
    } catch (_) {
      if (!mounted) return;
      _message = DanmakuException.storageFailure.message;
      _error = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _appId.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) {
        setState(() {
          _message = message;
          _error = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = DanmakuException.messageFor(error);
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DanmakuCredentials _draft() =>
      DanmakuCredentials(_appId.text, _secret.text).normalized();

  void _edited(String _) => setState(() => _message = null);

  @override
  Widget build(BuildContext context) {
    final canSave = Platform.isWindows || widget.service != null;
    final source = _custom
        ? '当前使用：自定义凭证'
        : _service.bundled.isComplete
        ? '当前使用：程序内置凭证'
        : '当前未配置凭证';
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('弹弹play凭证'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(source),
                const SizedBox(height: 8),
                Text(
                  canSave
                      ? '自定义凭证仅保存在此 Windows 用户的凭据管理器中，不随设置导出。保存后立即用于后续请求。'
                      : '此平台使用程序内置凭证，暂不支持保存自定义凭证。',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _appId,
                  enabled: !_busy && canSave,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: _edited,
                  decoration: const InputDecoration(labelText: 'App ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secret,
                  enabled: !_busy && canSave,
                  obscureText: !_visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: _edited,
                  decoration: InputDecoration(
                    labelText: 'App Secret',
                    suffixIcon: IconButton(
                      tooltip: _visible ? '隐藏密钥' : '显示密钥',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (!await launchUrl(
                              Uri.parse('https://dev.dandanplay.com/'),
                              mode: LaunchMode.externalApplication,
                            )) {
                              throw const DanmakuException(
                                '无法打开开发者中心，请访问 dev.dandanplay.com',
                              );
                            }
                            return '请在开发者中心申请应用凭证';
                          }),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('申请应用凭证'),
                  ),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _error
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy || !canSave
                ? null
                : () => _run(() async {
                    await _service.clear();
                    if (mounted) {
                      _appId.clear();
                      _secret.clear();
                      _custom = false;
                    }
                    return _service.bundled.isComplete
                        ? '已清除自定义凭证，恢复使用内置凭证'
                        : '已清除自定义凭证';
                  }),
            child: const Text('清除自定义'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final credentials =
                        _appId.text.isEmpty && _secret.text.isEmpty
                        ? await _service.resolve()
                        : _draft();
                    await (widget.validate ?? DanmakuApi.validateCredentials)(
                      credentials,
                    );
                    return '连接验证通过${_appId.text.isEmpty ? '' : '，点击保存后生效'}';
                  }),
            child: const Text('验证连接'),
          ),
          FilledButton(
            onPressed: _busy || !canSave
                ? null
                : () => _run(() async {
                    await _service.save(_draft());
                    if (mounted) _custom = true;
                    return '已保存，后续请求立即生效';
                  }),
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
