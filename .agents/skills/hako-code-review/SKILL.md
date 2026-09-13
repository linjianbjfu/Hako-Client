---
name: hako-code-review
description: "Review Hako-Client diffs or pull requests for correctness, Swift concurrency, app/helper/VPN lifecycle, routing, signing assumptions, and evidence gaps."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-code-review
---

# Review Hako changes

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Establish the requested diff, its verified base/head, and existing worktree changes. Read enough surrounding code to trace the changed behavior; file names and a PR description do not prove the implementation. Use the [scope/check workflow](../hako-pre-push-checks/SKILL.md) when selecting evidence.

## Trace observable behavior

- Follow a setting from SwiftUI and persisted profile state into the running core and its readback. A selected mode, GLOBAL label, or saved node choice does not prove which outbound handles traffic.
- Trace both ends of changed pipe messages and public package APIs. Check decoding, startup acknowledgement, cancellation, EOF, child exit and the possibility of a late result from an older service generation.
- Review Combine publications and actor isolation at the point where state reaches the UI. Check that menu-bar updates survive a hidden app window and return to the right state after stopping.
- For standalone proxy changes, verify TUN and unrelated listeners remain disabled, credentials follow the requested authentication mode, and provider files remain inside the owned working directory. For VPN changes, inspect the Network Extension separately.
- Verify XcodeGen target/resource membership and the embedded executable actually built. Do not infer signing permissions from an entitlements source file or treat a terminal launch as a Finder launch.
- Check storage ownership: App Groups, local versus synchronized Keychain, CloudKit initialization and configuration staging have different requirements. Do not broaden permissions merely to suppress a failed test.

Review changed docs and visible strings against behavior, including English, Simplified Chinese and Traditional Chinese resources when affected. Use [prose guidance](../hako-prose-standard/SKILL.md) for substantive wording issues and [test reliability](../hako-ci-test-reliability/SKILL.md) for resource-owning tests.

## Findings

Prioritize demonstrated behavior defects over stylistic preferences. For each finding give the file/line, trigger, consequence, and evidence or reproduction. Distinguish verified failures from unresolved hypotheses and testing limits. An empty finding list is valid. A review does not itself authorize code edits, a posted review, or a merge; follow the user's requested action.
