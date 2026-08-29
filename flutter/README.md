# Rocket.Chat Flutter 客户端

使用 Flutter 编写的 Rocket.Chat 跨平台客户端，支持 Windows、Android、iOS、macOS、Linux 和 Web。业务操作使用官方 REST API，实时消息通过 DDP WebSocket 接收。

## 功能

- 自定义服务器登录，账号和密码不会保存到磁盘
- 公开频道、私有频道、私信与客服会话
- 历史消息、实时消息、未读计数与标记已读
- 发送、线程回复、编辑、删除消息及添加 👍
- 搜索消息和筛选会话
- 创建私信、公开频道与私有频道
- 桌面双栏与移动端抽屉式响应布局

## 运行

需要 Flutter 3.47 或兼容版本：

```powershell
cd flutter
flutter pub get
flutter run -d windows
```

## 检查、测试与构建

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
flutter build web --release
```

构建 iOS 和 macOS 版本需要 macOS 与对应的 Xcode 环境。服务器权限和功能开关可能影响创建频道、编辑或删除消息等操作。

## 安全

仓库不包含测试账号、密码或认证令牌。认证令牌只存在于当前应用进程的内存中，退出登录或关闭应用后即丢弃。
