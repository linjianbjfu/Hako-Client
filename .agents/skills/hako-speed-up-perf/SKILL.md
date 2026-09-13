---
name: hako-speed-up-perf
description: "Investigate or optimize Hako-Client startup, SwiftUI responsiveness, core/helper overhead, memory, or proxy throughput using reproducible measurements."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-speed-up-perf
---

# Measure before optimizing

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Define the user action and its observable completion: usable window, proxy listener ready, first routed response, menu-bar sample, profile activation, or completed shutdown. Record architecture, build configuration, signing/launch method, fixture dimensions and whether the cache is cold or warm.

Separate local overhead from DNS, subscription, proxy-node and Internet latency. Use local synthetic origins/providers for repeatable routing and throughput work. Do not import private subscriptions or credentials into benchmarks.

## Follow measured cost

Useful targets include repeated YAML/JSON decoding, profile/resource copies, broad Combine invalidation, main-actor blocking I/O, per-sample allocations, helper startup, and retained view state. Confirm the production path and measured cost before adding caches or replacing data structures.

Use available Instruments, sampling tools, existing timing counters or focused benchmarks. Record baseline and candidate raw samples under comparable load. Do not run a CPU-heavy build alongside latency measurements. Keep end-to-end timing separate from component timing, and peak memory separate from retained memory. A low average does not excuse a startup or scrolling stall.

Vary realistic dimensions: profile bytes, nodes, groups, rule/provider count, visible rows and concurrent connections. Use fresh processes for cold helper or launch measurements; explicitly retain only the cache intended for a warm case.

## Preserve behavior

Change one causal factor at a time. Preserve routing decisions, ordered DNS rules, authentication, resource containment, cancellation, startup readiness and UI update semantics. Deferring work moves cost; measure first activation and retention too. Use a baseline or a controlled reintroduction to show that a performance assertion can detect the targeted regression.

A command-line launch does not measure Finder prompts or window usability. A loopback transfer does not measure LAN or remote-node performance. State these limits. Reject a change when gains disappear end-to-end, behavior changes unintentionally, or added state costs more than the measured benefit.

Report workload, before/after values, sample count, timing boundaries, memory behavior and functional evidence. Use [test reliability](../hako-ci-test-reliability/SKILL.md) and [pre-push checks](../hako-pre-push-checks/SKILL.md) as needed. Do not introduce a mandatory benchmark or CI threshold without a maintained runner and measured variance.
