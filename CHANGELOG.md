# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The SDK package version and the wire `protocolVersion` are tracked separately.

## [Unreleased]

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
