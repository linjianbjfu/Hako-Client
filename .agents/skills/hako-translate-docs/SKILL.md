---
name: hako-translate-docs
description: "Explicitly invoked extended workflow for translating or reconciling Hako-Client English and Chinese documentation and localized product wording."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-translate-docs
---

# Extended Hako translation workflow

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Use this skill when explicitly invoked as `$hako-translate-docs`. Its explicit-only policy is retained from the source skill; ordinary paired documentation maintenance can proceed under the documentation workflow.

Identify the authored source and requested target language. For an existing pair, compare changed semantic units and make the smallest counterpart edit. For a new translation, read the whole source and translate section by section, then compare every clause and read the result on its own.

## Hako conventions

The root pair is `README.md` and `README.zh-CN.md`. Product strings have English, Simplified Chinese and Traditional Chinese owners under AppLocalization. Do not invent `.zh.md` counterparts, pairing-hash files or a new translation manifest. Preserve existing language-switch links.

Keep commands, bundle identifiers, protocol and JSON keys, paths, placeholder order, `%@`/`%d` format specifiers and user node names unchanged unless the source change explicitly alters them. Code examples must perform the same operation in both languages. Retain negation, optionality, timing, error recovery and verification limits.

Use existing nearby translations for terms such as configuration, node, proxy group, rule mode, global mode, direct connection, proxy server and VPN. Do not translate a product label differently from the UI. Record unresolved terminology briefly rather than silently inventing a new concept.

Compare structure and meaning, not physical line counts. Check local link targets and changed `.strings` syntax with `plutil -lint`; read the resulting UI text for truncation or ambiguity when it affects a visible flow. Use [the prose standard](../hako-prose-standard/SKILL.md) without adding facts absent from the source.

Return the changed pairs/locales, unresolved terms and checks. Translation does not require delegation or authorize publication.
