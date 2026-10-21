# 实测结果

验证日期：2026-10-20 至 2026-10-21（Asia/Shanghai）。

| 检查 | 结果 | 说明 |
|---|---|---|
| Flutter analyze | 通过 | 3.41.9，No issues found |
| Flutter test | 6 项通过 | ID 唯一性、CRUD/重启、失败回滚、导入校验、并发/逾期、真实表单 |
| Web release build | 通过 | base-href=/focusflow-flutter/，实际发布构建 |
| Android debug APK | 构建通过 | 标准调试签名，约 160 MiB；未连接设备/模拟器，未运行 |
| Chrome 实际运行 | 通过 | 新建任务→保存→刷新→再次检索→完成→统计 4/8=50% |
| 浏览器无匹配结果 | 通过 | 输入不存在关键词后列表 0 项，真实空状态 |
| JSON 非法导入/并发保存 | 自动测试通过 | 无效备份不覆盖，写入失败内存回滚 |
| 窄屏/触屏设备 | 未单独浏览器验证 | 响应式布局已实现；不能冒充手机真机截图 |
| iOS | 未验证 | 没有进行签名、构建或设备运行 |

实际浏览器测试发现并修复 Dart Web 的 `1 << 32` 编译为 0 导致 ID 生成失败；已改为跨平台安全的 `0x100000000`。修复后重跑分析、全部测试、Web/Android 构建，并在 Chrome 真正创建/保存/刷新验证。源码提交 af891ea 对应修复后的运行代码。

测试没有掩盖这个缺陷：最初仅原生 Dart 单元测试通过仍不代表 Web 通过，最后状态以上述浏览器实测为准。Screenshot 01–07 均来自实际 Flutter Web；详见 evidence.json。

Web 构建有 Flutter 字体裁剪/可选 Cupertino 字体提示，构建成功；本项目没有使用 Cupertino 图标。当前截图为桌面浏览器，不是 Android 或 iPhone 证据。

GitHub 首轮代码 CI：[成功运行记录](https://github.com/yang1256149685/focusflow-flutter/actions/runs/39534136871)。Pages 部署成功，公开演示已实际浏览器操作验证，部署源提交见 release-verification.json。后续仅追加文档/评估材料，不将文档提交 SHA 冒充已部署源。
