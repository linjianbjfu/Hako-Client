---
name: hako-trim-cot-leakage
description: "Audit or remove authoring-session residue, dead draft citations and review narration from Hako-Client comments or docs while retaining technical facts."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-trim-cot-leakage
---

# Remove authoring-session residue

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Use [the prose standard](../hako-prose-standard/SKILL.md) to preserve complete factual statements. Ask whether a reader with this repository, but without the authoring conversation, can resolve each reference and understand the rule.

Look for uncommitted design-section citations, anonymous audit codes, "this PR", review-round arguments, unowned future plans and comments that walk through obvious control flow. Search terms are candidate finders, not deletion rules. Read each hit and its owning code.

Replace a dead citation with a real maintained reference or a self-contained technical fact. Retain the failure that an ordering rule prevents, the owner of cancellation/cleanup, numeric limits and measurement provenance. Remove narration only after those facts survive.

Keep issue references, resolvable standards, suppression explanations, runtime old/new state distinctions, and history inside decision records or incident reports. "The old process exits before the new listener starts" describes runtime ordering; it is not development-history leakage.

Keep the audit within the requested files. Do not rewrite generated projects, vendored Adapter code, the downloaded kernel, or recorded fixtures as a prose cleanup. Update the owning source and affected translations when a real wording change warrants it. Report unresolved citations or behavior questions instead of quietly changing the promised behavior.
