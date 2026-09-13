# Clash for Apple Platforms

English · [简体中文](README.zh-CN.md)

A native, rule-based proxy client for iPhone, iPad, Mac and Apple TV, powered by the Hako kernel.

## Official website and download

- [Official website](https://clash.md/)
- [Download Clash on the App Store](https://apps.apple.com/app/id6794257189)

Use the App Store link to install the official app. The instructions below are for building from source.

## About this repository

This repository contains the Apple applications, their extensions, shared libraries and resources needed to build them. The [Hako kernel](https://github.com/TokenPLS/Hako) and [Adapter components](https://github.com/TokenPLS/Hako-Adapter) are maintained in separate repositories; their source revisions are pinned in [`Dependencies.lock.json`](Dependencies.lock.json).

| Directory | Contents |
| --- | --- |
| `apple/HakoClient` | Platform applications, extensions and XcodeGen project specification |
| `apple/HakoClientKit` | Shared configuration and profile models |
| `apple/HakoClientUI` | Shared interface components |
| `apple/HakoMacClient` | macOS components |

The source distribution is pre-release. The App Store app version and a checkout of this repository are separate artifacts; pin a source revision when reproducing a build.

## Build from source

### Requirements

- macOS with Xcode 26.6 and the iOS, macOS and tvOS SDKs.
- XcodeGen and Git available on your command path.
- Go with automatic toolchain selection enabled, or the Go 1.26.6 toolchain selected by the pinned kernel's binding module.
- Python 3 with PyYAML.

### Prepare the project

```sh
git clone https://github.com/TokenPLS/Hako-Client.git
cd Hako-Client
python3 -m venv .build/python-env
source .build/python-env/bin/activate
python3 -m pip install PyYAML
python3 scripts/bootstrap.py
python3 scripts/configure.py
```

The first bootstrap fetches the pinned public Kernel and Adapter sources, installs the pinned gomobile tools and builds the five-slice SDK. It requires network access and can take several minutes. The configure step generates the Xcode project.

Open `apple/HakoClient/HakoClient.xcodeproj` and choose a scheme:

| Platform | Scheme |
| --- | --- |
| iPhone / iPad | `HakoClient` |
| Apple TV | `HakoTV` |
| Mac | `HakoMac` |

For an unsigned iOS Simulator build:

```sh
xcodebuild -project apple/HakoClient/HakoClient.xcodeproj \
  -scheme HakoClient -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

### macOS independent proxy without a system VPN

Select a configuration and open **Utilities → Independent Proxy**. Set the port and optional username/password, then turn on **Enable Independent Proxy**. Enable it manually the first time; subsequent launches of Clash restore the listener automatically. The Home **Start(VPN)** button and a system VPN are not required. This feature does not change the system proxy or routes.

HTTP and SOCKS5 share one port, defaulting to `7890` (range `1024–65535`). Leave both username and password empty for anonymous access, or fill in both for authentication. Connect locally at `127.0.0.1:port`, or use the displayed LAN address from another device. Configure the proxy in the browser or other client application.

The outbound mode follows **Global**, **Rule**, or **Direct** selected in **General**, and node selections apply immediately. Turn the independent proxy off and on after switching profiles or changing subscriptions/rules. Global mode requires a valid proxy node.

Closing the window keeps the proxy running. Turning off **Enable Independent Proxy** stops listening and disables automatic startup. Quitting Clash stops the current service while retaining the enabled setting. VPN connection changes do not stop the independent proxy. If the VPN configuration also opens a listener, use different ports for the two services.

**Status** shows the actual runtime state. An occupied port, invalid configuration, or unavailable saved credentials produces an error; correct the problem and select **Retry**. macOS may request Local Network access or incoming connection permission. The original VPN sharing settings are available under **VPN LAN Sharing** on this page.

Enable **Show Speed in Menu Bar** in the menu bar menu to display the standalone server's live upload and download rates. These rates cover traffic passing through the proxy server.

To test a built helper against a local HTTP origin:

```sh
python3 scripts/test_proxy_server.py \
  .build/macos-arm64/DerivedData/Build/Products/Release/Clash.app/Contents/Helpers/HakoProxyServer
```

The test covers HTTP/SOCKS5, authentication, port conflicts, shutdown/restart, routing rules, file providers, transfer rates and idle reset. Add `--lan-host YOUR_MAC_LAN_IP` to verify the LAN listener address.

### Sign your own build

Set your own bundle identifier family and Apple Developer Team ID:

```sh
python3 scripts/configure.py --bundle-base org.yourname.clash --team YOURTEAMID
```

Configure signing and capabilities for the app and its extensions in Xcode, including Network Extensions, App Groups and any iCloud capabilities you use. Certificates and provisioning profiles are not included. An unsigned build checks compilation; installing on a device requires your own signing setup.

## Feedback

Report app problems in [Issues](https://github.com/TokenPLS/Hako-Client/issues). Include the platform and OS version, app version or source revision, reproduction steps, and expected versus actual behavior. Share only the configuration and logs needed to reproduce the problem, with credentials and subscription links removed.

Kernel issues can be reported in [Hako](https://github.com/TokenPLS/Hako/issues); packet bridge and provider lifecycle issues belong in [Hako-Adapter](https://github.com/TokenPLS/Hako-Adapter/issues).

## License

[GPL-3.0](LICENSE). Third-party resource licenses remain with their resources.
