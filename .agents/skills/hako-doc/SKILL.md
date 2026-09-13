---
name: hako-doc
description: "Create, update, review or organize Hako-Client Markdown documentation, build guidance and feature guides against the implemented Apple-client behavior."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-doc
---

# Write documentation for its reader

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Choose the page's job: user operation, contributor setup, package/API reference, architecture explanation or decision record. Place information at its owner; use the root README pair for common setup and feature entry points rather than creating a parallel manual by default.

For a user operation, state the starting state, action, observable result and likely recovery. Use the labels the app actually shows. Distinguish a configured `allow-lan` value from a running proxy server, and a proxy protocol endpoint from a VPN or system proxy setting.

For developer guidance, explain the relevant components and link exact sources for details. Verify commands against their scripts/manifests and run safe relevant examples when practical. Mark signing, GUI, network or cross-platform examples unverified when prerequisites are missing; do not execute consequential actions merely to validate prose.

## Preserve current ownership

Edit `project.yml`, source comments or scripts before generated derivatives. Preserve the existing `README.md` / `README.zh-CN.md` pairing and update affected meaning on both sides. Use [prose guidance](../hako-prose-standard/SKILL.md); routine bilingual edits do not require loading the explicit-only extended translation skill.

There is no Hako documentation website, generated metadata taxonomy, translation-hash sidecar or line-alignment gate to maintain. Do not add them as incidental documentation work. A substantial new page may use a short navigation section; small pages do not need a fixed Summary/Contents/Dev Note template.

Review local links after moves, prerequisites before commands, and exact artifact paths after builds. Separate present behavior from proposals and historical rationale. For documentation-only work, inspect syntax/links and use `git diff --check`; add executable or UI checks only for changed claims that need them.
