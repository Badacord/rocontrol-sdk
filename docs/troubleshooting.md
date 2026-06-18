# Troubleshooting

## HTTP requests are not enabled

Symptom: `Transport` errors, `statusCode = 0`. Fix: Game Settings → Security →
*Allow HTTP Requests*.

## 401 / 403 (Auth)

The API key is missing, wrong, or revoked. These are **not retried**. Recreate the
key in the dashboard and update `ServerStorage/RoControlConfig/ApiKey`.

## 429 (Rate limited)

The SDK retries automatically, honoring `Retry-After`, with backoff + jitter. If
persistent, you're likely sending too many `reportEvent` calls — prefer a
declarative schedule, or confirm the MemoryStore lease is enabled
(`enableMemoryStoreLease = true`) so only one server reports per occurrence.

## 409 (Idempotency conflict)

Same idempotency key, different payload. Usually means two servers built different
payloads for the same occurrence. Ensure `occurrenceId` is deterministic.

## Circuit breaker open

After repeated retryable failures the SDK opens the circuit for a cooldown and
returns `circuit_open`. It recovers automatically. Check `getHealth()`.

## MemoryStore unavailable

The SDK logs `lease_unavailable`, falls back to a per-server debounce, and relies
on backend idempotency. No action needed; reports are still de-duplicated.

## Moderation

Icon changes pass Roblox moderation. RoControl only re-submits when the winning
overlay actually changes, and surfaces moderation status in the dashboard. If an
icon is rejected, fix the asset; RoControl will not loop on a known-bad composite.
The SDK also emits `rocontrol.sdk.moderation.pending`,
`rocontrol.sdk.moderation.approved`, `rocontrol.sdk.moderation.rejected`, and
`rocontrol.sdk.moderation.failed` when the backend returns moderation state.

## Nothing appears in the dashboard

- Confirm the bootstrap runs on the **server**.
- Set `logLevel = "debug"` and check for request logs (secrets are redacted).
- Verify `baseUrl` and that the key's universe matches the place.
