# Hako-Client

This repository contains native Apple clients built with Swift, SwiftUI, Swift Package Manager, and XcodeGen. Read [README.md](README.md) or [README.zh-CN.md](README.zh-CN.md) for the supported build entry points.

## Working in this repository

- Read the affected sources before choosing a workflow. [Project references](.agents/references/hako-project.md) map the app, shared packages, proxy helper, generated files, and validation commands.
- `apple/HakoClient/project.yml` owns the Xcode project. Generated projects, plists, entitlements, `.build/`, `Vendor/`, and `Hako.xcframework` are not durable edit locations; dependency revisions belong in `Dependencies.lock.json`.
- For a local macOS build, use the current machine's architecture unless the user requests a different target. The established arm64 output is `.build/macos-arm64/DerivedData/Build/Products/Release/Clash.app`. Do not run concurrent Xcode builds against the same DerivedData directory.
- Distinguish compilation, command-line startup, Finder startup, signing, and working proxy/VPN traffic. Report only the behavior actually verified. Preserve existing worktree changes and running user services while preparing tests.

## Task-specific skills

Load the relevant skill when its task applies; this is not a requirement to run every workflow on every change.

| Task | Skill |
| --- | --- |
| Review a diff or PR | [hako-code-review](.agents/skills/hako-code-review/SKILL.md) |
| Select checks before handoff or push | [hako-pre-push-checks](.agents/skills/hako-pre-push-checks/SKILL.md) |
| Find evidence-backed simplifications | [hako-find-simplifications](.agents/skills/hako-find-simplifications/SKILL.md) |
| Diagnose performance | [hako-speed-up-perf](.agents/skills/hako-speed-up-perf/SKILL.md) |
| Write or restructure documentation | [hako-doc](.agents/skills/hako-doc/SKILL.md) |
| Review technical prose and comments | [hako-prose-standard](.agents/skills/hako-prose-standard/SKILL.md) |
| Extended bilingual translation, when explicitly invoked | [hako-translate-docs](.agents/skills/hako-translate-docs/SKILL.md) |
| Remove authoring-session residue from prose | [hako-trim-cot-leakage](.agents/skills/hako-trim-cot-leakage/SKILL.md) |
| Diagnose unreliable tests | [hako-ci-test-reliability](.agents/skills/hako-ci-test-reliability/SKILL.md) |
| Audit or archive decision notes | [hako-archive-agent-notes](.agents/skills/hako-archive-agent-notes/SKILL.md) |
| Prepare or land dependent PRs | [hako-merging-stacked-prs](.agents/skills/hako-merging-stacked-prs/SKILL.md) |
| Record a native application demo | [hako-record-demo](.agents/skills/hako-record-demo/SKILL.md) |

The skills were adapted from DeepSeek Harness; [source and adaptation notes](.agents/references/skill-origins.md) identify the changes. A skill does not authorize a push, merge, upload, permission change, or running-service interruption that the task has not authorized.
