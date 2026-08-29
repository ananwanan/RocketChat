# Rocket.Chat C# 桌面客户端

一个使用 C#、.NET 10 和 WPF 编写的原生 Windows Rocket.Chat 客户端。通过官方 REST API 完成业务操作，并通过 DDP WebSocket 接收实时消息；不依赖浏览器壳或第三方 UI 包。

## 功能

- 自定义 Rocket.Chat 服务器登录，密码只保留在登录请求期间
- 公开频道、私有频道、私信和客服会话列表
- 历史消息、实时新消息、未读数与标记已读
- 发送、线程回复、编辑、删除消息和添加 👍
- 搜索当前会话、筛选会话
- 上传文件
- 按用户名创建私信，创建公开或私有频道
- WebSocket 不可用时仍可使用 REST 功能

## 环境

- Windows 10/11
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- 一个可用的 Rocket.Chat 账号

## 运行

使用 Visual Studio 2026/2022（需支持 .NET 10）打开根目录下的 `RocketChat.sln`，将 `RocketChat.Client` 设为启动项目后运行；也可以使用命令行：

```powershell
dotnet run --project .\RocketChat.Client\RocketChat.Client.csproj
```

启动后输入服务器地址、用户名和密码。默认服务器为 `https://open.rocket.chat/`。

## 构建与测试

```powershell
dotnet build .\RocketChat.sln -c Release
dotnet test .\RocketChat.sln -c Release
```

发布独立的 Windows x64 版本：

```powershell
.\scripts\pack.ps1 -SelfContained -Version 1.0.0
```

也可以直接双击或从命令提示符运行 `pack.cmd`。脚本默认生成框架依赖的 Windows x64 单文件包，并在 `artifacts` 目录中输出 ZIP、SHA-256 校验文件和解压目录。

常用参数：

```powershell
# 默认的框架依赖 x64 单文件包
.\scripts\pack.ps1

# 无需目标电脑预装 .NET 的自包含包
.\scripts\pack.ps1 -SelfContained -Version 1.0.0

# Windows ARM64 包
.\scripts\pack.ps1 -Runtime win-arm64 -SelfContained

# 保留多个发布文件，不合并为单文件
.\scripts\pack.ps1 -NoSingleFile
```

## 安全说明

- 仓库不包含服务器账号、密码、认证令牌或测试凭据。
- 客户端不会把密码或认证令牌写入配置文件。
- 建议只连接启用 HTTPS 的服务器。
- `.gitignore` 排除了本地环境文件、证书、构建产物和开发配置。

## API 兼容性

客户端遵循 Rocket.Chat 官方 [REST API](https://developer.rocket.chat/apidocs/rocketchat-api) 和 [Realtime API](https://developer.rocket.chat/apidocs/realtimeapi)。服务器权限、功能开关及版本会影响部分操作（例如创建频道、上传文件或删除消息）。

## 许可证

MIT
