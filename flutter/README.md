# Rocket.Chat Flutter 客户端

使用 Flutter 编写的 Rocket.Chat 跨平台客户端，支持 Windows、Android、iOS、macOS、Linux 和 Web。业务操作使用官方 REST API，实时消息通过 DDP WebSocket 接收。

界面全局使用项目内置的 MiSans VF 可变字体（`assets/fonts/MiSansVF.ttf`）。

## 功能

- 自定义服务器登录，可选择使用系统安全凭据存储记住密码
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

登录页默认服务器为 `http://192.168.31.188:3000`，可在登录前修改；若此前启用了“保存密码”，安全存储中的服务器地址会优先回填。Android 和 Apple 平台仅为该局域网 IP 配置了明文 HTTP 例外，其他服务器仍应使用 HTTPS。

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

仓库不包含测试账号、密码或认证令牌。认证令牌只存在于当前应用进程的内存中。启用“保存密码”后，服务器、用户名和密码会写入平台安全存储；取消勾选会立即清除。Web 端安全存储仅应在 HTTPS 或 localhost 环境使用。

Linux 运行时需要 `libsecret-1-0`，构建时需要 `libsecret-1-dev`；Windows 构建环境需要安装 Visual Studio C++ ATL 组件。
