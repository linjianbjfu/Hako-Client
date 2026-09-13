---
name: hako-find-simplifications
description: "Find or implement evidence-backed simplifications in Hako-Client code and documentation when the user requests a simplification survey or refactor."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-find-simplifications
---

# Find useful simplifications

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Treat a survey as investigation unless the request includes implementation. Map each candidate to current callers, required behavior and a concrete maintenance cost. Do not manufacture a candidate count, TODO list or decision-note corpus.

Survey the requested areas: shared packages, platform adapters, profile transformation, UI projections, helper IPC and lifecycle. Search exact symbols, wire strings, selectors, resource names and XcodeGen membership. A source file with no textual call site may still be an app entry point, an Objective-C callback, a SwiftUI resource or a generated target member.

Strong candidates remove unused public operations, repeated parsing, redundant state, duplicated presentation logic, or unnecessary adapters. For each, record production callers separately from tests and docs, explain the resulting behavior, and identify a regression test. When replacing custom code with Foundation, Swift concurrency or a dependency, account for deployment targets, binary size, dependencies and remaining glue.

Do not collapse the app, Network Extension and helper merely because their code looks similar. Inspect core setup/cache policy, process ownership and signing responsibilities. Preserve configuration ordering, migration requirements, cancellation arbitration and independent readback unless evidence proves they are redundant.

For prose, use [the prose standard](../hako-prose-standard/SKILL.md). Keep the facts that explain a non-obvious invariant; remove duplicated narration rather than hiding complexity behind an extra abstraction.

Deliver a ranked set of specific proposals with affected paths, net deletion/complexity, behavior changes, counterarguments and validation. Implement only the authorized candidates. Record durable rationale where it already belongs, or propose a small decision record when useful; do not require a new note for every edit. Use [pre-push checks](../hako-pre-push-checks/SKILL.md) for implemented changes.
