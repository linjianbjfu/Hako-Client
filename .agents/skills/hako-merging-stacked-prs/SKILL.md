---
name: hako-merging-stacked-prs
description: "Prepare or land dependent Hako-Client PRs when the user requests stack work, using verified live bases, head commits, dependency order and repository merge requirements."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-merging-stacked-prs
---

# Work from the actual PR dependency chain

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

A request to inspect a stack is read-only. Land, push, retarget or rewrite branches only within the user's authorized task. Use an isolated worktree for branch operations when the main checkout has unrelated edits.

Read current PR metadata: state, draft status, base/head refs and OIDs, reviews and checks. Identify the target trunk and bottom-to-top dependency order; do not assume `master`, same-repository heads, a particular merge method, or native GitHub stack support.

If the repository uses a stack tool, inspect its installed help and current server support before invoking it. Follow that established mechanism rather than simultaneously hand-editing its state. Otherwise use the repository's supported Git/PR workflow. A missing optional extension is not a reason to invent APIs or impose another project's process.

## Prepare and validate

Refresh only where the current base or merge rules require it. Reassess each layer's delta against its actual parent after a merge, rebase or retarget. Use [pre-push checks](../hako-pre-push-checks/SKILL.md) for affected layers. Do not treat a passing top PR as proof that its dependencies can land.

A history rewrite must preserve others' work: record the fetched remote OID, use an exact lease when publishing, and reassess if the remote moved. Inspect rewritten heads and review anchors again. Do not disable checks or bypass required review to make a stack appear ready.

## Land only the requested range

For an authorized merge, reconfirm live heads and the requested bottom-to-top range immediately before the operation. Use the supported merge method and required checks. Stop the dependent sequence if an earlier layer fails, is retargeted unexpectedly or changes the validated diff. A queued merge is pending until the hosting service reports it merged.

Verify the final states and remaining PR bases. Branch deletion is separate cleanup: check that no open PR depends on a branch and that deletion is authorized. Report exact landed/pending/blocked layers and validation, without conflating preparation with publication.
