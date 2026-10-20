# 架构与边界

Material 3 界面 → TaskStore（ChangeNotifier）→ TaskRepository → shared_preferences。Task 模型与 JSON 校验独立于 Widget，存储可注入内存实现。

所有变更按串行队列计算并落盘；保存成功后才更新内存和通知 UI。保存失败保留原状态，后续操作仍可继续。JSON 根结构带 schemaVersion=1，导入前完整校验、拒绝重复 ID 和非法日期。任务截止日期按本地自然日处理，已完成任务不算逾期。所有统计来自当前真实任务。

本机档案只是显示名，没有远程账号。数据明文存在本机偏好存储，不提供加密、云备份和设备同步。Web 首次加载需要网络或本地资源服务器；“离线”指已加载应用后的本地业务操作，不保证浏览器永远缓存安装资源。

验证 SDK 为 Flutter 3.41.9 / Dart 3.11.5。iOS 目录来自 Flutter 标准工程模板，已移除自动填入的开发者 Team；未构建、签名或在 iPhone 运行。
