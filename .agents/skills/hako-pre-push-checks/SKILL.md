---
name: hako-pre-push-checks
description: "Select and run relevant Hako-Client checks before a handoff, push, readiness claim, or after a base change, without defaulting to an exhaustive platform rebuild."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-pre-push-checks
---

# Select evidence for a Hako change

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Establish the checkout, requested change, and exact base/head. Do not guess `main` or `master`. For a PR, read its live metadata and fetch the relevant refs when needed. For uncommitted work, distinguish pre-existing changes from this task.

The read-only [change-scope utility](scripts/change_scope.py) reports committed and worktree layers independently:

```sh
python3 .agents/skills/hako-pre-push-checks/scripts/change_scope.py
python3 .agents/skills/hako-pre-push-checks/scripts/change_scope.py --base VERIFIED_BASE --head HEAD
```

Replace `VERIFIED_BASE` with the ref verified for this review. Without a base the report covers worktree layers only; it is not an outgoing-commit audit. The utility does not fetch, build, stage, commit, or push.

For utility maintenance, run `python3 -m unittest discover -s .agents/skills/hako-pre-push-checks/scripts -p 'test_*.py' -v`. The reported areas are navigation hints; inspect the changed behavior before selecting checks.

## Choose the smallest useful checks

- Shared model or protocol logic: owning Swift tests; set `HAKO_TEST_HELPER` after building the helper if the IPC case matters.
- Proxy/helper lifecycle, authentication, traffic or routing: helper integration tests, plus tests for the specific regression. Check real forwarding or distinguishable upstreams, not just socket connectivity.
- App/UI or build configuration: build affected targets and verify the produced bundle. Inspect the actual UI when presentation or input behavior matters, using authorized native-app tools.
- Localization or plist edits: syntax checks and semantic review of the affected locale values and placeholders.
- Markdown/skills: frontmatter, references, commands and any changed script behavior. Do not compile the app merely because workflow text changed.
- SDK/Adapter pins or shared cross-platform APIs: inspect affected consumers and available SDK slices. Run justified platform checks and state missing prerequisites.

Commands and artifact locations are in the project reference. Inspect tests behind a command before treating their result as coverage. A skipped helper or platform case is not a pass for that behavior. Avoid repeating passing checks unless new edits, changed bases, failures or unresolved concerns invalidate the evidence.

There is no assumed CI or hook baseline. Inspect current automation, if present. Keep parallel read-only checks separate from mutations; serialize Xcode builds sharing DerivedData and performance measurements competing for CPU.

## Handoff and publication

Report exact commands, exit results and meaningful limits. Diagnose build/database, SDK, signing and runtime failures separately. Do not mask failures with retries, disabled assertions or permission changes.

If the task authorizes pushing, inspect any hook-produced changes, verify the intended commit, push, and compare the remote head. A history rewrite needs the verified remote OID and an exact `--force-with-lease` condition; a moved remote head requires reassessment. This workflow selects evidence and does not grant publication authority.
