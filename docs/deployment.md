# 部署与平台说明

## Flutter Web / GitHub Pages

本轮仓库路径为 focusflow-flutter；从项目根目录执行：

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --base-href /focusflow-flutter/
```

将 build/web 的内容发布到 gh-pages 分支根目录（不是把整个 build/web 文件夹套进去），保留完整资源目录，并放置 .nojekyll。GitHub Settings → Pages → Deploy from a branch → gh-pages → /(root) → Save。访问 GitHub 实际返回的 URL。仓库改名时必须重建 base-href。

本地检查子路径时，将该目录映射为 HTTP 服务器的 /focusflow-flutter/；若直接从 build/web 根目录启动服务器，则使用 base-href=/ 重新构建后访问根路径。不要双击 file:// 页面。

默认 Flutter Web 首次加载会获取引擎与字体资源；请核对网络可达性，不能把数据本地存储解释为保证首次离线启动。截图来自真实 Flutter Web，不是原生 Android 真机证据。

## Android

```bash
flutter build apk --debug
```

产物默认 build/app/outputs/flutter-apk/app-debug.apk。调试签名仅供本机安装验证，不使用用户私人 release keystore。没有设备/模拟器时不得写“Android 已运行”。构建依赖 Android SDK、JDK 与 Gradle 网络缓存；实际结果以 testing.md 为准。

## iOS

工程模板已提供，未签名构建、未真机验证。由开发者在 Xcode 选择自己的 Team；不要上传私人签名证书或 provisioning profile。
