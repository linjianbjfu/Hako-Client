---
name: hako-prose-standard
description: "Write or review Hako-Client technical prose, comments, diagnostics and UI wording while preserving behavior, ownership, timing and recovery information."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-prose-standard
---

# Preserve facts, remove unnecessary narration

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Identify the passage's reader and every factual proposition before editing. Preserve the actor, action, condition, timing, required/optional distinction, side effect, ownership, failure and consequence. Shorter text is useful only when those facts remain clear.

Document non-obvious caller obligations beside Swift APIs: actor/thread assumptions, callback ownership, cancellation, error/readiness meaning and persistent effects. Explain why an invariant is needed when code alone does not show it. Avoid comments that merely narrate branches or recount the development conversation.

Use concrete terms such as pipe message, selected node, signed entitlement, profile revision, or running process instead of vague architectural labels when those are the actual subject. Keep searchable names and measured provenance.

## Match the surface

- User text explains an action or recovery using product terms. Do not expose internal implementation details unless they help the user decide.
- Developer docs explain the current design and link code. Decision records and incident reports may legitimately contain history and alternatives.
- Tests explain only non-obvious fixtures, observations or platform constraints.
- Diagnostics distinguish invalid configuration, missing capabilities, transport failure and unavailable upstreams without including secrets.
- Skills state task scope and useful decisions, not a mandatory ceremony for unrelated work.

Visible strings are product behavior: use the existing localization path and preserve format placeholders, accessibility meaning, units and user-provided names. Do not rewrite fixture expectations or API keys as prose. Exclude generated SDK/Adapter material unless the task explicitly concerns that upstream source.

Use [documentation guidance](../hako-doc/SKILL.md) for placement and [session-residue cleanup](../hako-trim-cot-leakage/SKILL.md) for a targeted audit. Report meaningful edits and deliberate keeps; avoid a universal deletion quota or a required new comment for every symbol.
