# Kazumi SR 搜索修复记录（2026-10-28）

## 原因与改动

SR 自编译包没有官方发布流程注入的 `KAZUMI_APPID`、`KAZUMI_KEY`。
原程序仍向镜像的受保护搜索接口发送签名，应用日志反复记录 HTTP 401，
而搜索页把请求失败显示为“没有找到番剧”。

- 根据请求决定连接方式：镜像模式下，构建缺少完整密钥时，搜索与同样
  需要签名的评论接口使用官方 API 的 ECH 连接；公开镜像接口保持镜像。
- 显式选择直连或 ECH 时保持该设置，有完整密钥的构建保持镜像签名。
- 搜索 API 向控制器传播错误。界面区分鉴权失败、超时、其他请求失败与
  成功但零匹配；失败时可重试。加载下一页失败保留当前结果与分页位置。
- 保留搜索并发保护，旧查询失败不会覆盖新查询结果。超分逻辑未修改。

## 当前验证

- 修复前运行 `flutter test --no-pub test/search_network_regression_test.dart
  --plain-name "unsigned mirror build finds known anime through official search"`：
  模拟镜像 HTTP 401，实际控制器搜索结果为 `[]`，预期 `[1]`，测试失败。
- 修复后全套 Flutter 测试：224 通过，0 失败；1 个需显式开启的联网测试
  默认跳过，随后单独开启并通过。
- 真实联网使用生产 ECH 适配器：“进击的巨人”20 项；
  “葬送のフリーレン”5 项；`limit=1, offset=1` 分页取得 1 项。
- 静态分析：0 错误、0 警告、17 条既有 info。Windows Release 构建通过。
- 从更新后的便携目录启动并操作实际 GUI：“无职转生”返回 9 项；
  打开 2021 年第一季详情正常；片源搜索 6 个来源共返回 3 个条目
  （AGE 1、akianime 2）。mutefun 返回非 JSON 内容并解析失败，
  其余未匹配来源没有结果。这属于各片源自身状态。
- 便携目录的 `data/app.so` 与本次 Release 构建文件 SHA-256 一致。

联网测试命令：

```powershell
. .\.cache\flutter-env.ps1
flutter --no-version-check test --no-pub test/search_network_regression_test.dart --dart-define=KAZUMI_LIVE_SEARCH=true --plain-name 'live official searches use the production ECH transport' --reporter expanded
```

原始测试、构建及分析日志在本项目 `.cache/search-diagnostics/`。
本轮没有验证完整剧集播放、音画同步、切源换集，也没有重新执行旧版的
原生 GPU 超分验收；2026-10-20 的超分记录属于历史证据。

## 交付与回退

便携目录：`Kazumi_SR_Windows_x64/`。
旧版完整备份：同级 `Kazumi_SR_Windows_x64_before_search_fix_20261028`。
用户设置、收藏、插件和播放历史仍位于原有的独立 SR 数据目录。
本次没有变更系统代理、TUN 或原版 Kazumi。
