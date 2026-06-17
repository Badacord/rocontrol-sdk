# AGENTS.md

Guidance for AI coding agents working in this repository. Humans: see
[README.md](README.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## What this is

The RoControl Roblox SDK: a server-only Luau package that reports events and
schedules to the RoControl backend. It is published as a Wally package and as
`.rbxm`/`.rbxmx` release artifacts. The same wire contract is consumed by the
private RoControl NestJS backend.

## Setup and commands

```sh
rokit install          # install pinned toolchain (rojo, wally, stylua, selene, lune)
wally install          # install dependencies into Packages/
```

```sh
luau tests/run.luau                       # run the pure-logic suite (no Roblox needed)
stylua --check src tests examples         # formatting
selene src tests examples                 # lint
rojo build default.project.json --output build/RoControl.rbxm
rojo build default.project.json --output build/RoControl.rbxmx
```

If `luau` is unavailable, `lune run tests/run.luau` runs the same suite.

## Architecture

- `src/init.luau` — public entry, server-only guard, type re-exports.
- `src/Types.luau` — single source of truth for public types.
- `src/Config.luau` — defaults + validators → `ResolvedConfig`.
- `src/Client.luau` — public client; validates input, dispatches HTTP off the
  gameplay thread, never blocks gameplay.
- `src/Runtime.luau` — dependency container; tests inject fakes via `overrides`.
- `src/Http/*` — `Routes` registry, `ResponseClassifier`, `Retry`, `CircuitBreaker`,
  `HttpClient`.
- `src/Logging/*` — structured `Logger` + `Redaction` (secret masking).
- `src/Internal/*` — the only engine-touching code (HttpService, MemoryStore, Env,
  Clock, Signal, Queue, Uuid). Everything else is pure Luau and unit-testable.

## Conventions

- Tabs for indentation; `stylua.toml` and `selene.toml` are authoritative.
- All engine APIs go through an adapter in `src/Internal`. Do not call
  `game:GetService`, `task.*`, `os.*`, or `Instance.new` outside `src/Internal`.
- Every error that leaves the SDK is a typed `RoControlError` (see `src/Errors`).
- Timing goes through `Clock` so tests stay deterministic.

## How to add a new endpoint

1. Add it to `src/Http/Routes.luau` with `method`, `path`, `idempotent`,
   `requiredCapability`.
2. Add a client method in `src/Client.luau` that builds the payload and calls
   `self:_dispatch(...)`.
3. Add metric names to `src/Metrics/Metrics.luau`.
4. Document it in `docs/api-reference.md` and keep the backend contract in sync.

## How to add a new schedule rotation

Add a variant to `ScheduleRotation` in `src/Types.luau` and the deterministic
implementation under `src/Schedules` (Phase 2). Weighted rotations MUST use the
portable `mulberry32-fnv1a32` algorithm — never Roblox `Random.new`, which the
TypeScript backend cannot reproduce. Add golden fixtures under `tests/fixtures`.

## How to write tests

- Pure logic → add a `tests/unit/*.spec.luau` returning `function(t) ... end` and
  register it in `tests/run.luau`. Runs in CI via `luau`/`lune`.
- Roblox-coupled logic → TestEZ specs run in Studio / run-in-roblox.

## Public API compatibility

Types in `src/Types.luau` and methods on `RoControlClient` are public. Breaking
them is a major version bump. `protocolVersion` in `src/Metadata.luau` changes
only when the wire contract changes.

## Security — do / don't

- DO keep the SDK server-only. DO redact secrets in logs (`src/Logging/Redaction`).
- DON'T log `apiKey`, `Authorization`, cookies, or CSRF tokens.
- DON'T add client-side code or examples that put an API key in a replicated
  container. v1 has no client surface.
- DON'T trust a `universeId` from the client; the backend derives it from the key.

## Release process

Bump `version` in `src/Metadata.luau` and `wally.toml`, update `CHANGELOG.md`, tag
`vX.Y.Z`. CI verifies the tag matches `Metadata.version`, builds artifacts,
publishes to Wally, and deploys docs. See `.github/workflows/release.yml`.
