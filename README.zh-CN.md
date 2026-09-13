# Clash for Apple Platforms

[English](README.md) · 简体中文

基于 Hako 内核的原生规则代理客户端，适用于 iPhone、iPad、Mac 和 Apple TV。

## 官网与下载

- [官方网站](https://clash.md/)
- [在 App Store 下载 Clash](https://apps.apple.com/app/id6794257189)

安装官方应用请使用 App Store 链接。以下说明面向需要从源码构建的开发者。

## 关于本仓库

本仓库包含 Apple 各平台应用、扩展、共享库及构建所需资源。[Hako 内核](https://github.com/TokenPLS/Hako)和 [Adapter 组件](https://github.com/TokenPLS/Hako-Adapter)位于独立仓库，依赖源码提交固定在 [`Dependencies.lock.json`](Dependencies.lock.json) 中。

| 目录 | 内容 |
| --- | --- |
| `apple/HakoClient` | 各平台应用、扩展与 XcodeGen 工程配置 |
| `apple/HakoClientKit` | 共享配置与档案模型 |
| `apple/HakoClientUI` | 共享界面组件 |
| `apple/HakoMacClient` | macOS 组件 |

当前源码分发处于预发布阶段。App Store 应用版本与本仓库检出的源码分别管理；复现构建时请固定源码提交。

## 从源码构建

### 环境要求

- macOS、Xcode 26.6，以及 iOS、macOS、tvOS SDK。
- 可在命令行使用的 XcodeGen 和 Git。
- 启用自动工具链选择的 Go，或安装固定内核绑定模块所选择的 Go 1.26.6 工具链。
- Python 3 和 PyYAML。

### 准备工程

```sh
git clone https://github.com/TokenPLS/Hako-Client.git
cd Hako-Client
python3 -m venv .build/python-env
source .build/python-env/bin/activate
python3 -m pip install PyYAML
python3 scripts/bootstrap.py
python3 scripts/configure.py
```

首次准备依赖时会获取固定提交的公开内核与 Adapter 源码，安装固定版本的 gomobile 工具，并构建五切片 SDK。此过程需要网络，可能耗时数分钟。配置脚本随后生成 Xcode 工程。

打开 `apple/HakoClient/HakoClient.xcodeproj`，选择相应构建方案：

| 平台 | 构建方案 |
| --- | --- |
| iPhone / iPad | `HakoClient` |
| Apple TV | `HakoTV` |
| Mac | `HakoMac` |

不签名编译 iOS 模拟器版本：

```sh
xcodebuild -project apple/HakoClient/HakoClient.xcodeproj \
  -scheme HakoClient -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### macOS 独立代理（无需系统 VPN）

选择要使用的配置，进入 **工具 → 独立代理**，设置端口和可选的用户名、密码，然后打开“启用独立代理”。首次使用时需要手动启用；此后每次打开 Clash 都会自动恢复监听，无需点击首页“启动(VPN)”或安装系统 VPN。此功能不会修改系统代理或路由。

HTTP 和 SOCKS5 使用同一个端口，默认 `7890`，范围为 `1024–65535`。用户名和密码同时留空即可免认证；如需认证，请同时填写两项。本机连接 `127.0.0.1:端口`，其他设备连接页面显示的局域网地址。浏览器等应用需要自行设置此代理。

出站模式实时跟随 **常规** 中选中的全局、规则或直连，节点选择也会同步。切换配置或修改订阅、规则后，需要关闭再开启独立代理。全局模式仍需有效的代理节点。

关闭窗口后代理继续运行；关闭“启用独立代理”会停止监听并取消下次自动启动；退出 Clash 会停止本次服务，但保留启用设置。独立代理不随 VPN 连接或断开而停止。如果 VPN 配置也需要监听同一端口，请为两者设置不同端口。

页面中的“状态”显示实际运行结果。端口被占用、配置无效或保存的认证信息无法读取时，会显示错误；修正后点击“重试”。macOS 可能询问是否允许局域网访问或传入连接。原来随 VPN 运行的共享设置位于页面中的 **VPN 局域网共享**。

在菜单栏菜单中勾选“在菜单栏显示速度”，即可查看独立代理服务的实时上传和下载速率，统计范围为经过该服务的流量。

开发者可验证构建出的服务：

```sh
python3 scripts/test_proxy_server.py \
  .build/macos-arm64/DerivedData/Build/Products/Release/Clash.app/Contents/Helpers/HakoProxyServer
```

测试使用本机 HTTP 站点，覆盖 HTTP/SOCKS5、认证、端口冲突、停止和重启、配置规则、节点文件，以及上传下载速率和空闲归零。添加 `--lan-host 本机局域网IP` 可验证局域网监听地址。

### macOS 本地数据与迁移

没有配置 App Group 权限的 macOS 构建使用 `~/.clashhako/` 保存文件，其中包括 `working/` 和 `logs/`。偏好设置使用普通本地域 `org.example.hako.local`（自定义 Bundle ID 时为 `<Bundle ID>.local`）。具备对应 App Group 权限的签名版本继续使用共享容器，以便 VPN 和 Widget 共享数据。iOS 和 tvOS 的存储方式保持不变。

默认 Bundle ID 对应的路径如下：

| 内容 | 路径 |
| --- | --- |
| 旧数据（迁移后保留） | `~/Library/Group Containers/group.org.example.hako/` |
| 新配置与资源 | `~/.clashhako/working/` |
| 新日志 | `~/.clashhako/logs/` |
| 本地偏好设置 | `~/Library/Preferences/org.example.hako.local.plist` |

偏好设置通过 macOS `defaults` 接口导入，不需要手动编辑 plist。用户名和密码仍由钥匙串管理。

迁移已有本地版本时，**先退出 Clash 并停止其 VPN／代理服务，在打开新版之前**，从工程根目录运行：

```sh
python3 scripts/migrate_macos_data.py
```

命令会复制旧 App Group 目录、导入偏好设置，并更新 JSON／YAML／plist 文件中指向旧目录的绝对路径。原目录和钥匙串内容会保留，临时文件与系统容器元数据不会复制。目标目录或本地偏好设置已存在时，命令会停止，避免覆盖。偏好设置的恢复副本保存在 `~/.clashhako/migration/`，其中可能包含私密设置，请勿分享。如果已经打开新版并生成了 `~/.clashhako/`，请先保留该目录和本地设置，再处理迁移。

看到 `Migration complete` 后，打开 `.build/macos-arm64/DerivedData/Build/Products/Release/Clash.app`。确认原配置、节点选择、出站模式和独立代理设置已恢复；如果原来启用了独立代理，应恢复监听。退出应用再双击打开一次，检查是否仍出现“访问其他 App 数据”提示。验证完成前，请保留旧目录。

本地构建不会自动读取或迁移旧的受保护容器，从而避开已确认的“访问其他 App 数据”提示触发点；双击启动是否不再弹窗，仍需实际验证。局域网访问等其他系统权限提示不会因此关闭。以后使用具备 App Group 权限的签名版本时，会重新选择共享容器，不会自动同步本地目录中的新数据。

### 签名自己的构建

设置自己的 Bundle ID 前缀与 Apple Developer Team ID：

```sh
python3 scripts/configure.py --bundle-base org.yourname.clash --team YOURTEAMID
```

在 Xcode 中为应用和扩展配置签名与所需能力，包括 Network Extensions、App Groups，以及实际使用的 iCloud 能力。仓库不包含证书或描述文件。无签名构建只验证编译；真机安装需要自己的签名配置。

## 问题反馈

应用问题请提交到 [Issues](https://github.com/TokenPLS/Hako-Client/issues)，注明平台与系统版本、应用版本或源码提交、复现步骤，以及预期和实际行为。只分享复现所需的配置与日志，并移除凭据和订阅链接。

内核问题可提交到 [Hako](https://github.com/TokenPLS/Hako/issues)，数据包桥接与扩展生命周期问题请提交到 [Hako-Adapter](https://github.com/TokenPLS/Hako-Adapter/issues)。

## 许可证

[GPL-3.0](LICENSE)。第三方资源的许可证随资源保留。
