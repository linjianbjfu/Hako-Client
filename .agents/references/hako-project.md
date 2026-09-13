# Hako project reference

Read the sections relevant to the task. These are navigation and command references, not a requirement to run a full platform matrix.

## Source ownership

| Area | Owner |
| --- | --- |
| App targets, dependencies, signing capabilities, resource membership | [project.yml](../../apple/HakoClient/project.yml) |
| macOS app, menu bar, VPN controller | [Mac sources](../../apple/HakoClient/Sources/Mac) |
| Shared app logic, profile staging and settings | [App sources](../../apple/HakoClient/Sources) |
| Network Extension lifecycle | [Extension](../../apple/HakoClient/Extension) |
| Independent HTTP/SOCKS5 service executable | [ProxyServer](../../apple/HakoClient/ProxyServer) |
| Shared data types, CloudKit adapters and pipe protocol | [HakoClientKit](../../apple/HakoClientKit) |
| Shared SwiftUI components | [HakoClientUI](../../apple/HakoClientUI) |
| macOS UI components | [HakoMacClient](../../apple/HakoMacClient) |
| Dependency revision pins | [Dependencies.lock.json](../../Dependencies.lock.json) |
| Dependency setup and project generation | [bootstrap.py](../../scripts/bootstrap.py), [configure.py](../../scripts/configure.py) |
| Unit and process protocol tests | [HakoClientKitTests](../../apple/HakoClientKit/Tests/HakoClientKitTests) |
| Proxy protocol and routing integration tests | [test_proxy_server.py](../../scripts/test_proxy_server.py) |

The root READMEs own environment prerequisites. `bootstrap.py` fetches pinned kernel/Adapter sources and builds the complete Apple SDK. It is not an arm64-only command. If a verified matching SDK already exists, reuse it. For a requested macOS-only bootstrap, inspect the pinned kernel's build driver for its explicit `macos/arm64` target, keep the XCFramework basename `Hako.xcframework`, and verify its platform, architecture and build provenance. Do not mistake a one-slice artifact for the bootstrap script's five-slice receipt.

The current repo has no committed CI workflow or universal lint/coverage gate. Inspect the actual tree before relying on any that is added later. Do not import DeepSeek Harness's pnpm, Vitest, Cordis, translation-hash or 100%-coverage requirements.

## Build environment

Check `xcode-select -p`, `xcodebuild -version`, `swift --version` and available SDKs when an environment problem is plausible. If the selected developer directory is CommandLineTools but full Xcode is installed, set `DEVELOPER_DIR` for the command; do not change the system-wide selection as a routine build step. The examples use `/Applications/Xcode.app/Contents/Developer`; substitute the actual installation when different.

Generate the project after changing its specification or target source membership:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  .build/python-env/bin/python scripts/configure.py
```

This assumes the README's Python environment and PyYAML are installed. Preserve the configured bundle identifiers and team. Changing signing identity is a separate task from generating or compiling a project.

## macOS arm64 build

From the repository root:

```sh
mkdir -p .build/macos-arm64
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project apple/HakoClient/HakoClient.xcodeproj \
  -scheme HakoMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/macos-arm64/DerivedData \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build \
  > .build/macos-arm64/build.log 2>&1
```

Check the process exit code and build log. This compiles the app and embedded targets, including the helper. `file` can verify the executable architecture. A successful build is not signing or runtime evidence.

Use `clean build` when stale removed targets or resources could remain in an app bundle. Do not clean for every edit, delete dependency caches as a default remedy, or stop a running desktop copy without considering the user's current work. Changes to the source build do not update an existing copy on the Desktop or in Applications.

The helper-only scheme is `HakoProxyServer`. Build it with the same options when only helper artifacts are needed for tests, then wait for completion before starting another Xcode build using this DerivedData directory.

## Selecting tests

For shared model, configuration, or protocol behavior:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift test --package-path apple/HakoClientKit \
  --scratch-path .build/clientkit-tests
```

Use `--filter` for a focused test when appropriate. The real helper handshake case is conditional on `HAKO_TEST_HELPER`; a run without that variable does not verify IPC. After building the helper:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  HAKO_TEST_HELPER="$PWD/.build/macos-arm64/DerivedData/Build/Products/Release/HakoProxyServer" \
  swift test --package-path apple/HakoClientKit \
  --scratch-path .build/clientkit-tests
```

For proxy, authentication, routing, listener, traffic, or lifecycle changes, exercise the shipped helper:

```sh
python3 scripts/test_proxy_server.py \
  .build/macos-arm64/DerivedData/Build/Products/Release/Clash.app/Contents/Helpers/HakoProxyServer
```

The script uses local HTTP origins and proxy fixtures. Add `--lan-host` with the current Mac's verified LAN address when that path matters; loopback success alone does not prove LAN access. The product's port range excludes zero, so a fixture that discovers a free port and then passes it to a child still has a reservation gap. Investigate port conflicts instead of describing that pattern as atomic allocation.

Tests cover authenticated and anonymous HTTP/SOCKS5, port conflicts, shutdown, provider files, selected GLOBAL routing, mode/node changes, and traffic samples. Inspect the actual scenarios when selecting evidence; their names alone do not establish coverage for a new failure.

For changes shared with iOS or tvOS, identify affected targets in `project.yml` and available SDKs. The arm64-only macOS framework cannot validate other platforms. Report a missing SDK slice or signing capability as a validation limit rather than claiming all Apple platforms pass.

## Local storage and migration checks

The storage check compiles the actual shared storage resolver without App Group entitlements and uses an isolated temporary home. It verifies that local storage never calls the protected group resolver, including after a directory creation failure:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swiftc apple/HakoClient/Shared/HakoAppIdentifiers.swift \
  apple/HakoClient/Shared/HakoAppGroupContainer.swift \
  scripts/test_macos_storage.swift -o .build/test-macos-storage
.build/test-macos-storage
```

Migration tests use temporary files and a unique, cleaned-up preferences domain. They cover path rewriting, preserved originals, refused overwrites, symlinks, failed preference imports and a real macOS `defaults` round trip:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s scripts -p 'test_migrate_macos_data.py' -v
```

These checks do not migrate user data or prove that Finder launches are prompt-free. The README pair owns the user migration command and verification steps.

## Runtime facts worth preserving

- The containing app uses the core for configuration work; a standalone proxy runs in a separate process. Check the pinned SDK before changing setup/cache policy or merging those lifecycles.
- A standalone server must not create TUN, install a VPN profile, or change system proxy/routes. Review its configuration patch, platform callback and startup path together.
- Profile mode, saved group selections, a core cache and live routing are different state. GLOBAL mode alone can still route through DIRECT. Verify the selected outbound or use distinct proxy fixtures; an open port and a success label are insufficient.
- The helper's pipe protocol carries configuration and credentials. Keep secrets out of argv, diagnostic output, screenshots, fixtures and committed artifacts. Test EOF, cancellation, late results and shutdown, not only the happy-path handshake.
- Test fixtures own their children and temporary roots. Do not use broad `pkill`, the user's running port 7890, or real shared containers for ordinary tests.
- Keep server resources inside its owned working directory. Preserve ordered DNS policy semantics when rewriting configurations; do not round-trip the entire document through an unordered dictionary.
- SwiftUI/Combine publications can happen before a property stores its new value. Prefer emitted values when rendering changes; gate asynchronous results by their current operation/service generation.
- macOS builds without the configured App Group entitlement use `~/.clashhako/` and the ordinary `<bundle-id>.local` preferences domain. They must not probe the protected group or import it during startup. `scripts/migrate_macos_data.py` copies data explicitly while the app is stopped; use temporary fixtures for migration tests.
- CloudKit, App Groups, synchronized Keychain, Network Extension and local-network access have different capability requirements. Read signed entitlements and the actual system error before attributing a failure to one of them.
- A terminal-launched executable can inherit a different privacy attribution from a Finder-launched app. State the launch method and do not treat a terminal smoke as proof of a prompt-free Finder launch.

## Documentation and localization

[README.md](../../README.md) and [README.zh-CN.md](../../README.zh-CN.md) are the current English/Simplified Chinese pair. There is no translation sidecar or physical-line alignment requirement.

Product strings live under [AppLocalization](../../apple/HakoClient/Sources/AppArchitecture/AppLocalization) in `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj`. Other resources may have their own localization owners; trace the target's resource membership before editing. Use existing `HakoCopy`/SwiftUI localization patterns. Preserve wire keys, identifiers, placeholders, format specifiers, and user-provided node names.

Use `plutil -lint` on changed `.strings` or plist files, and `git diff --check` on the diff. Review translated meaning and UI fit separately from syntax. Workflow-only or prose-only changes do not require rebuilding the app unless they change an executable example or affected runtime behavior.
