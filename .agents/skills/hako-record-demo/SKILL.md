---
name: hako-record-demo
description: "Record a native Hako macOS feature demonstration or encode supplied app video/screenshots into a GIF, with identifiable build provenance and truthful runtime evidence."
license: MIT; see ../LICENSE
metadata:
  source-skill: record-browser-gif
---

# Record the native app's real behavior

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Identify the scenario, exact executable, source revision and any dirty diff, architecture, signing mode and launch method. Use the Hako build reference when a fresh app is required. A desktop copy may not match the current source artifact.

Use the authorized native-app control/recording tools available in the session. Follow their permission and capture rules; do not install a browser driver or use a browser mock as a substitute for this SwiftUI app. When UI access is unavailable, state that limitation and work with user-supplied captures or preserve a storyboard instead of claiming a live recording.

Choose a short sequence with observable starting state, user action and result. For proxy work, show the running server status and an actual connection/routing result where those are the claim. A configured port or a screenshot of Global mode alone proves neither. Keep real-node demos separate from local-fixture demos and label the latter accurately.

Keep recordings under an ignored run directory such as `.build/demos/<run>/`. Use one consistent window/crop and one coherent run. Do not splice failed runs into a successful story or include credentials, subscriptions, unrelated windows or notifications. If a user's running app must be replaced, account for that service interruption before recording.

## Optional GIF encoding

The [encoder](scripts/encode_gif.py) accepts a video or ordered screenshots and requires `ffmpeg` and `ffprobe`. Check their availability when encoding is requested. Missing media dependencies do not invalidate source/build checks, and a missing encoder dependency is not permission to simulate a recording.

```sh
python3 .agents/skills/hako-record-demo/scripts/encode_gif.py   .build/demos/run/frames .build/demos/run/demo.gif   --durations 1.5,1.5,3 --fps 10 --max-width 1200 --colors 128
```

Use observed durations and actual frame counts. For video, select one continuous interval with `--start`/`--end`; disclose any `--speed` change. Preserve raw captures. Inspect the encoded GIF, including intermediate frames and final hold, not only its source images. The JSON summary verifies dimensions, duration and size, not that the demonstrated feature works.

Encoder maintenance tests, when media tools are installed:

```sh
python3 -m unittest discover -s .agents/skills/hako-record-demo/scripts -p 'test_*.py' -v
```

Return the artifact path, demonstrated build and conditions, and known limits. Recording produces local evidence; uploading it or editing a PR requires that separate action to be part of the task. Do not put binary demos in a product branch by default.
