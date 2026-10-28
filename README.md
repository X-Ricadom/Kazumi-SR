# Kazumi SR

基于 [Predidit/Kazumi](https://github.com/Predidit/Kazumi) 的个人非商业修改版，主要面向 Windows，提供可调倍率 Anime4K 超分辨率、独立的 SR 程序标识及可配置的弹弹play接入。

- 项目地址与介绍页：<https://github.com/X-Ricadom/Kazumi-SR>
- 上游基线：Kazumi 2.3.9，提交 `184f8db535f9b4098ada763fcefea8e602126dc7`。本项目不代表 Kazumi 官方。
- 本公开仓库使用独立源码快照初始化，不包含先前本地或远端 Git 历史；上游来源和许可证继续保留。
- 代码沿用上游 GPL-3.0 许可证及第三方声明；图标、字体的权利说明见本文下方的上游说明。

## 本修改版的功能

- **可调超分倍率**：自动、1.5×、2×、3×、4×，与效率/质量档位独立。固定倍率保留原有 x2 CNN 重建链，1.5×/3× 在重建后缩小到目标尺寸。
- **Windows 程序独立**：使用 `kazumi_sr.exe`、独立窗口/互斥锁及应用数据标识；Windows 下禁用上游程序更新覆盖。
- **搜索修复**：未注入镜像凭证时使用官方 Bangumi API 的 ECH 搜索路径，区分请求失败和无匹配结果。
- **弹幕凭证设置**：设置 → 弹幕设置 → 弹弹play凭证，支持验证、保存、清除。自定义凭证保存在 Windows 凭据管理器中，不写入普通设置或仓库；没有自定义凭证时使用构建注入的凭证。

弹弹play API 需要自行申请的有效应用凭证。本仓库不提供上游维护者的凭证，也没有实现 OAuth 回调。其他平台保留上游功能路径，尚未验收本修改版。

## 构建与验证

提交或发布前运行 `python tools/check_publication_privacy.py`。提交身份应使用 GitHub 提供的 noreply 邮箱；可通过 `git config core.hooksPath .githooks` 启用本地检查，CI 也会检查新增提交身份和待发布内容。

使用 Flutter 3.47.7 和 Windows Visual Studio C++ 构建工具。Git 依赖在 `pubspec.yaml` 中固定提交。

```powershell
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build windows --release
```

Windows 若遇到 ech_http 0.2.2 的 MSVC C2026 证书字符串长度错误，需要向独立的依赖副本应用 [MSVC 补丁](docs/ech-http-msvc.patch)，再通过本机 `pubspec_overrides.yaml` 指向该副本；本机覆盖文件和依赖缓存不提交。具体说明见 [超分构建记录](docs/super-resolution-scale.md)。

截至 2026-10-28，全套 Flutter 测试 238 项通过；Windows 凭据管理器真实读写专项另行启用并通过；Windows Release 构建和凭证设置界面已检查。尚未取得有效弹弹play凭证，成功在线检索、分集选择和播放器弹幕显示仍待验收。没有完成整集播放及最终超分画质验收。

- [超分倍率与构建说明](docs/super-resolution-scale.md)
- [Bangumi 搜索修复记录](docs/search-fix-2026-10-28.md)
- [弹幕凭证配置与验证记录](docs/danmaku-credentials-2026-10-28.md)

以下保留上游项目说明，其中上游官网、发布、签名服务及维护者相关信息属于原 Kazumi 项目。本仓库保留的上游 CI 工作流需要另行配置自己的凭证与签名服务，不能直接获得官方发布权限。

---

<div align=center>

<h1>Kazumi</h1>

<img src="assets/images/logo/logo_rounded.png" width=200></img>

<a href="https://t.me/kazumi_app"><img src="https://img.shields.io/badge/Telegram-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white"></img></a>

<img src="https://img.shields.io/badge/Flutter-03A9F4?style=for-the-badge&logo=flutter&logoColor=white"></img>
<img src="https://img.shields.io/badge/Dart-00B4AB?style=for-the-badge&logo=Dart&logoColor=white"></img>

<a href="https://trendshift.io/repositories/11432"><img src="https://trendshift.io/api/badge/trendshift/repositories/11432/yearly?language=Dart"></img></a>
<a href="https://hellogithub.com/repository/Predidit/Kazumi" target="_blank"><img src="https://abroad.hellogithub.com/v1/widgets/recommend.svg?rid=68d824ea55ee4b07aba6fe1dd61ac939&claim_uid=J9Qu6aDd8LT1nU0"/></img></a>

<p>使用 Flutter 开发的基于自定义规则的番剧采集与在线观看程序。使用最多五行基于 <code>Xpath</code> 语法的选择器构建自己的规则。支持规则导入与规则分享。支持基于 <code>Anime4K</code> 的实时超分辨率。绝赞开发中 (～￣▽￣)～</p>
</div>

## 支持平台

- Android 10 及以上
- Windows 10 及以上
- MacOS 10.15 及以上
- Linux (实验性)
- iOS 13 及以上 (需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ios))
- HarmonyOS 5.0 及以上 (位于 [分支仓库](https://github.com/ErBWs/Kazumi/releases/latest)，需要 [侧载](https://kazumi.app/docs/misc/how-to-install-in-ohos))
- Web 浏览器 (位于 [分支仓库](https://github.com/0Chencc/KazumiWeb/releases/latest)，需要在 Windows / Linux / MacOS 电脑或通过 Docker 运行服务端，同一局域网内的设备通过浏览器访问)

## 屏幕截图

<table>
  <tr>
    <td><img alt="homepage" src="static/screenshot/img_1.png"></td>
    <td><img alt="timetable" src="static/screenshot/img_2.png"></td>
    <td><img alt="details" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="selection-page" src="static/screenshot/img_4.png"></td>
    <td><img alt="rules-mange" src="static/screenshot/img_5.png"></td>
    <td><img alt="rules-edit" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

- [X]  规则编辑器
- [X]  番剧目录
- [X]  番剧搜索
- [X]  番剧时间表
- [X]  番剧字幕
- [X]  分集播放
- [X]  视频播放器
- [X]  多视频源支持
- [X]  规则分享
- [X]  硬件加速
- [X]  高刷适配
- [X]  追番列表
- [X]  番剧弹幕
- [X]  在线更新
- [X]  历史记录
- [X]  倍速播放
- [X]  配色方案
- [X]  跨设备同步
- [X]  无线投屏 (DLNA)
- [X]  外部播放器播放
- [X]  超分辨率
- [X]  一起看
- [X]  番剧下载
- [ ]  番剧更新提醒
- [ ]  还有更多 (/・ω・＼)

## 下载

通过本页面 [Releases](https://github.com/Predidit/Kazumi/releases/latest) 选项卡下载：

<a href="https://github.com/Predidit/Kazumi/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

### Android

<a href="https://f-droid.org/packages/com.predidit.kazumi">
  <img src="https://fdroid.gitlab.io/artwork/badge/get-it-on-zh-hans.svg"
  alt="Get it on F-Droid" width="200">
</a>

### GNU/Linux

<a href="https://flathub.org/apps/io.github.Predidit.Kazumi">
  <img src="https://flathub.org/api/badge?svg&locale=zh-Hans" alt="Get it on Flathub" width="175"/>
</a>

#### Arch Linux

可以从 [AUR](http://aur.archlinux.org) 安装。

##### AUR

```bash
[yay/paru] -S kazumi # 从源码构建
[yay/paru] -S kazumi-bin # 二进制包
```

## 贡献

欢迎向我们的 [规则仓库](https://github.com/Predidit/KazumiRules) 提交您的自定义规则。您可以自由选择是否在规则中留下您的ID。详细的规则编写教程可以参考 [规则开发文档](https://kazumi.app/docs/rules/develop-rules)

## Q&A

<details>
<summary>使用者 Q&A</summary>

#### Q: 为什么少数番剧中有广告？

A: 本项目未插入任何广告。广告来自视频源, 请不要相信广告中的任何内容, 并尽量选择没有广告的视频源观看。

#### Q: 为什么我启用超分辨率功能后播放卡顿？

A: 超分辨率功能对 GPU 性能要求较高, 如果没有在高性能独立显卡上运行 Kazumi, 尽量选择效率档而非质量档。对低分辨率视频源而非高分辨率视频源使用超分也可以降低性能消耗。

#### Q: 为什么播放视频时内存占用较高？

A: 本程序在视频播放时, 会尽可能多地缓存视频到内存, 以提供较好的观看体验。如果您的内存较为紧张, 可以在播放设置选项卡启用低内存模式, 这将限制缓存。

#### Q: 为什么少数番剧无法通过外部播放器观看？

A: 部分视频源的番剧使用了反盗链措施, 这可以被 Kazumi 解决, 但无法被外部播放器解决。

#### Q: 为什么下载的 Linux 版本缺少图标和托盘功能？

A: 使用 .deb 版本进行安装, tar.gz 版本仅为方便二次打包, 这一格式先天缺乏图标和托盘功能支持。

</details>

<details>
<summary>规则编写者 Q&A</summary>

#### Q: 为什么我的自定义规则无法实现检索？

A: 目前我们对 `Xpath` 语法的支持并不完整, 我们目前只支持以 `//` 开头的选择器。建议参照我们给出的示例规则构建自定义规则。

#### Q: 为什么我的自定义规则可以实现检索, 但不能实现观看？

A: 尝试关闭自定义规则的使用内置播放器选项, 这将尝试使用 `webview` 进行播放, 提高兼容性。但在内置播放器可用时, 建议启用内置播放器, 以获得更加流畅并带有弹幕的观看体验。

</details>

<details>
<summary>开发者 Q&A</summary>

#### Q: 我在尝试自行编译该项目, 但编译没有成功。

A: 本项目编译需要良好的网络环境, 除了由 Google 托管的 Flutter 相关依赖外, 本项目同样依赖托管在 MavenCentral/Github/SourceForge 上的资源。如果您位于中国大陆, 可能需要设置恰当的镜像地址。

</details>

## 开发

欢迎您提交 PR！在开始之前, 请阅读 [贡献指引](static/doc/CONTRIBUTING.md) 以了解我们对 PR 和 AI 参与辅助开发的规定。

## 美术资源

本项目图标来自 [Yuquanaaa](https://www.pixiv.net/users/66219277) 发表在 [Pixiv](https://www.pixiv.net/artworks/116666979) 上的作品。

此图标由其原作者 [Yuquanaaa](https://www.pixiv.net/users/66219277) 拥有版权。我们已获得原作者的授权和许可, 可以在本项目中使用这一图标。这一图标不是自由使用的, 未经原作者明确授权, 任何人不得擅自使用、复制、修改或分发这一图标。

本项目内嵌字体为 [Mi Sans](https://hyperos.mi.com/font/zh/details/sc/) 字体, 由 [Xiaomi](https://www.mi.com/index.html) 开发和拥有版权。

## 免责声明

本项目基于 GNU 通用公共许可证第 3 版（GPL-3.0）授权。我们不对其适用性、可靠性或准确性作出任何明示或暗示的保证。在法律允许的最大范围内, 作者和贡献者不承担任何因使用本软件而产生的直接、间接、偶然、特殊或后果性的损害赔偿责任。

使用本项目需遵守所在地法律法规, 不得进行任何侵犯第三方知识产权的行为。因使用本项目而产生的数据和缓存应在24小时内清除, 超出 24 小时的使用需获得相关权利人的授权。

## 隐私政策

我们不收集任何用户数据, 不使用任何遥测组件。

## 代码签名策略

提交者: [贡献者](https://github.com/Predidit/Kazumi/graphs/contributors)
审阅者: [所有者](https://github.com/Predidit)

## 赞助


| ![signpath](https://signpath.org/assets/favicon-50x50.png)                                                                                                                      | Free code signing on Windows provided by[SignPath.io](https://about.signpath.io/), certficate by [SignPath Foundation](https://signpath.org/) |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| <img src="https://kilo.ai/favicon/favicon.svg" width="50">                                                                                                                      | **Automatic PR review provided by [Kilo Code](https://kilo.ai/), sponsored by the [Kilo OSS Program](https://kilo.ai/oss)**                   |
| <a href="https://m.do.co/c/0062035db3e4"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_icon_blue.svg" width="50" height="50"></a> | **Cloud infrastructure is supported by [DigitalOcean](https://m.do.co/c/0062035db3e4)**                                                       |

## 致谢

特别感谢 [XpathSelector](https://github.com/simonkimi/xpath_selector) 这个优秀的项目是本项目的基石。

特别感谢 [弹弹play](https://www.dandanplay.com/) 本项目使用了 弹弹play开放平台 以提供弹幕交互。

特别感谢 [Bangumi](https://bangumi.tv/) 本项目使用了 Bangumi 开放 API 以提供番剧元数据。

特别感谢 [Anime4K](https://github.com/bloc97/Anime4K) 本项目使用 Anime4K 进行实时超分。

特别感谢 [SyncPlay](https://github.com/Syncplay/syncplay) 本项目使用 SyncPlay 协议并通过 SyncPlay 公共服务器实现一起看功能。

特别感谢 [所有贡献者](https://github.com/Predidit/Kazumi/graphs/contributors) 本项目因为你们变得更好。

特别感谢 [trace.moe](https://trace.moe) 本项目使用了 trace.moe 提供的图片识别番剧功能。

感谢 [media-kit](https://github.com/media-kit/media-kit) 本项目跨平台媒体播放能力来自 media-kit。

感谢 [avbuild](https://github.com/wang-bin/avbuild) 本项目使用了来自 avbuild 的树外补丁实现非标准视频流播放。

感谢 [hive](https://github.com/isar/hive) 本项目持久化储存能力来自 hive。
