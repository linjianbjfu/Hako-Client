---
name: hako-ci-test-reliability
description: "Design or diagnose Hako-Client Swift/Python tests involving concurrency, timing, subprocesses, ports, filesystem state, capabilities or flaky CI behavior."
license: MIT; see ../LICENSE
metadata:
  source-skill: dsh-ci-test-reliability
---

# Make the failure reproducible

Read the relevant sections of [the Hako project reference](../../references/hako-project.md) and the affected sources.

Read the actual test runner and, if present, CI configuration. A test may overlap other Swift tests, subprocesses, separate runners or user applications. The current checkout does not establish a CI platform matrix by itself.

For every resource, identify allocation, owner, readiness, cleanup registration and completed teardown. Use private temporary roots and unique Keychain service names. Prefer binding port zero when the fixture owns the listener. When the product requires a nonzero port passed to a child, recognize the reservation gap and validate the child's bind result; do not kill an unrelated listener to make a test pass.

## Synchronization and teardown

Use a startup response, socket protocol handshake, observable state or an explicit barrier to establish readiness. A sleep may pace a transfer or bound an observation window; it does not prove setup finished. Put the outer test deadline beyond the timeout being tested and include teardown in the budget.

Swift actor isolation does not isolate process-global Go setup, environment variables, UserDefaults, Keychain or host ports. Use separate helper processes for independent core instances. If a test changes global state, capture absence versus presence and restore it in a narrowly scoped cleanup path.

On every outcome, close pipe writers, cancel polling, await child/server exit and verify the owned port is released where relevant. Test late completions against a stopped or replaced service generation. Keep Xcode builds sharing DerivedData serial; this does not justify serializing all behavioral tests.

## Evidence and diagnosis

Distinguish a refused TCP connection, a successful SOCKS handshake, an HTTP response, a chosen proxy route and a changed public egress IP. Use local origins and distinguishable proxy fixtures to prove routing. Test counters under real transfers and verify idle reset; zeros alone do not validate traffic reporting.

For a flaky failure, record the exact command, revision, workload, architecture, launch context and first failure. Use barriers for a race and independent processes when cross-process isolation is the issue. Repeated stress supplements a causal regression; retries, longer sleeps, broad serialization or weaker assertions are not a diagnosis.

Treat missing signing capabilities, GUI permission, SDK slices and external connectivity as separate limitations. A CLI startup under terminal privacy attribution is not Finder evidence. Report skips explicitly, then choose final evidence with [pre-push checks](../hako-pre-push-checks/SKILL.md).
