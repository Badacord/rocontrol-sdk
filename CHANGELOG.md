# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The SDK package version and the wire `protocolVersion` are tracked separately.

## [0.2.1] - 2026-06-18

### Changed

- Wally `realm` is now **`shared`** (was `server`). Install RoControl as a normal
  `[dependencies]` entry so it lands in `Packages` / `ReplicatedStorage.Packages`
  like any other Wally package, instead of a separate `ServerPackages` location
  that Rojo projects don't map by default. The SDK is still effectively
  server-only: `init()` errors on the client and the module is inert there, so
  the API key (kept in `ServerStorage`) never reaches clients.
- Removed the noisy "SDK is under ReplicatedStorage" placement warning — that is
  now the recommended location. The client-side `init()` guard remains the real
  protection.

## [0.2.0] - 2026-06-18

### Added — upcoming-events read API

- `client:getUpcomingEvents()` and `client:getNextEvent()`: synchronous
  (yielding) reads of the universe's upcoming Roblox virtual events, relayed by
  the backend (`GET /api/sdk/v1/events/upcoming`). Roblox doesn't expose this
  feed in-experience; the SDK surfaces it so games can prompt players to join.
  Any valid SDK key works (no extra scope). Backward compatible.
- New types `RoControlUpcomingEvent` / `UpcomingEventsResult`, `upcomingEvents`
  route, and `event.upcoming.*` metrics.

## [0.1.0] - 2026-06-18

First public release. Phases 1–5 of the SDK plus distribution.

### Added — Phase 6 (distribution)

- Published as the Wally package `gh-constant/rocontrol-roblox-sdk` and as
  `RoControl.rbxm` / `RoControl.rbxmx` GitHub release artifacts.
- Release workflow tolerates a missing `WALLY_TOKEN` (still cuts the GitHub
  release + artifacts; skips the Wally publish step).

### Added — Phase 5 (asset and moderation surfacing)

- Added SDK moderation metric names and response handling for backend-returned
  moderation state (`pending`, `approved`, `rejected`, `failed`).
- Expanded the SDK/backend API contract fixture with v1 idempotency keys and
  moderation response examples.

### Added — Phase 4 (imperative reporting)

- Cross-server single-flight `MemoryStoreLease` (atomic claim on a MemoryStore
  hash map; exactly one server reports an occurrence) with a per-server
  `LocalDebounce` fallback when MemoryStore is unavailable.
- Deterministic `OccurrenceId` (`<normalizedKey>:<startedAt>`) so every server and
  the backend agree on the idempotency key.
- `Client.reportEvent` now resolves single-flight before dispatching: winner
  sends, losers return `duplicate`; emits lease win/loss/error metrics.
- `Env` now exposes `universeId` (game.GameId) for the lease namespace.
- 11 new pure-logic tests (46 total, all green).

### Added — Phase 2 (declarative schedules)

- Canonical JSON serializer (sorted keys, integer-only, cross-language stable).
- Portable 32-bit hashing: FNV-1a (matches canonical reference vectors) rendered
  as 8 hex chars; content hash = schedule version.
- Deterministic rotation: `sequential` and portable `weighted`
  (`mulberry32-fnv1a32`, reproducible by the TypeScript backend — not Roblox
  `Random.new`).
- Schedule validation + normalization (defaults, asset-id/key normalization,
  integer enforcement) and occurrence computation (`stateAt`) mirroring the
  backend resolver.
- Registry-scan and adapter helpers.
- `registerSchedule` now validates, normalizes, and canonical-hashes; coalesces
  identical schedules; sends the normalized descriptor.
- Golden fixtures for canonicalization and weighted selection; 15 new pure-logic
  tests (35 total, all green).

### Added — Phase 1 (foundation & transport)

- Public entry point `RoControl.init(config)` with server-only guard and full type
  re-exports.
- Typed configuration with defaults + validation (`src/Config.luau`).
- Typed error taxonomy and factory (`src/Errors`).
- Structured logger with level filtering and secret redaction (`src/Logging`).
- Optional metrics sink with canonical metric names (`src/Metrics`).
- HTTP stack: central route registry, response classifier, exponential backoff
  with jitter, circuit breaker, idempotency + correlation headers (`src/Http`).
- Bounded work queue with priority-aware overflow (`src/Internal/Queue.luau`).
- Client lifecycle: async dispatch, `flush`, `destroy`, `onFailedOperation`,
  `retryFailedOperation`, `getHealth`.
- Engine adapters (HttpService, MemoryStore, Env, Clock, Signal) isolated in
  `src/Internal`.
- `registerSchedule` and `reportEvent` over the Phase 1 transport (canonical
  schedule hashing lands in Phase 2; MemoryStore single-flight in Phase 4).
- Pure-logic test suite runnable via `luau`/`lune`; CI, docs, and examples.

Protocol version: `sdk-v1`.
