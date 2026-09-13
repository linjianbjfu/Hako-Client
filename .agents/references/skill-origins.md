# Skill adaptation

These repository skills are adapted from `deepseek-harness/.agents/skills` at source revision `c291e7961a515f6d7af9304e7fd1d257929aef26`. They are local to Hako-Client; no global skill installation or dependency on that sibling checkout is required. The upstream MIT notice is retained in [skills/LICENSE](../skills/LICENSE).

The eleven `dsh-*` workflows map to their corresponding `hako-*` directories. `record-browser-gif` maps to `hako-record-demo`, which targets the native macOS application. Test-fixture skills and Cordis preset skills were not imported.

The adaptation replaces npm/Cordis/Node instructions with Swift package, XcodeGen, macOS app/helper, and localization ownership. It adds a read-only Git change-scope utility and keeps build/test examples in [one project reference](hako-project.md). It does not introduce a CI gate, mandatory decision-note corpus, bilingual hash records, a website pipeline, or a required GitHub stack extension.

`hako-translate-docs` retains the source workflow's explicit-only invocation through `agents/openai.yaml`. Other skills use normal task-based selection. No workflow requires subagents; delegation remains subject to the active session's instructions.

The optional GIF encoder and its media tests are carried from the upstream recorder, with application-neutral wording and temporary-file names. Encoding and media tests require `ffmpeg` and `ffprobe`; the skill checks those prerequisites when recording is requested. Recording, GIF encoding, uploading, and editing a PR are separate actions.
