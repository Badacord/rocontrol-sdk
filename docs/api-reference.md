# API Reference

All types are exported from the root module (`RoControl.<Type>`).

## `RoControl.init(config: InitConfig): RoControlClient`

Creates a client. Raises a clear `Config` error on invalid input. Server-only:
calling from the client errors.

### `InitConfig`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `apiKey` | `string` | — | **Required.** Per-universe key from the dashboard. |
| `baseUrl` | `string?` | `https://api.rocontrol.app` | Must be http(s). |
| `logger` | `Logger?` | built-in | Custom structured sink. |
| `logLevel` | `LogLevel?` | `"info"` | `silent\|error\|warn\|info\|debug`. |
| `metrics` | `MetricsSink?` | none | Optional metrics hook. |
| `httpTimeoutSeconds` | `number?` | `10` | 1–60. |
| `maxRetries` | `number?` | `3` | 0–10. |
| `retryBaseDelaySeconds` | `number?` | `0.5` | 0–30. |
| `retryMaxDelaySeconds` | `number?` | `10` | 0–120, `>= base`. |
| `circuitBreakerFailureThreshold` | `number?` | `5` | 1–100. |
| `circuitBreakerCooldownSeconds` | `number?` | `60` | 1–3600. |
| `enableMemoryStoreLease` | `boolean?` | `true` | Cross-server single-flight (Phase 4). |
| `studioMode` | `boolean?` | `false` | Friendlier logs in Studio. |

## `RoControlClient`

| Method | Returns | Description |
| --- | --- | --- |
| `registerSchedule(descriptor)` | `OperationResult` | Declarative schedule registration. Coalesces identical schedules. |
| `reportEvent(input)` | `OperationResult` | Imperative event report. |
| `buildScheduleFromRegistry(config)` | `RoControlSchedule` | Build a descriptor by scanning a folder. |
| `onFailedOperation(cb)` | `RBXScriptConnection` | Fires on dispatch/network failure. |
| `retryFailedOperation(failed)` | `OperationResult` | Re-dispatch a failed operation. |
| `getHealth()` | `HealthStatus` | Circuit state, pending count, timestamps. |
| `flush()` | `()` | Bounded wait until pending work drains. |
| `destroy()` | `()` | Stop accepting work; flush; release resources. |

`OperationResult.status` is one of
`sent | queued | skipped | duplicate | disabled | failed | circuit_open`.

## Errors — `RoControlError`

```lua
{ kind: ErrorKind, message: string, retryable: boolean, statusCode: number?, requestId: string?, cause: any? }
```

`ErrorKind` =
`Auth | RateLimit | Validation | Transport | Server | Timeout | Config | MemoryStore | CircuitOpen | Unknown`.

Retry policy: `Auth`/`Validation`/`Config` never retry; `RateLimit` (honors
`Retry-After`), `Server`, `Timeout`, `Transport` retry idempotent operations.

## Metrics

Emitted through `MetricsSink` if provided. Names are namespaced `rocontrol.sdk.*`
(init, schedule.register.\*, event.report.\*, http.retry, lease.\*, circuit.\*,
queue.\*). See `src/Metrics/Metrics.luau`.
