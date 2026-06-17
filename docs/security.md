# Security

## Server-only

The SDK holds a privileged API key. It must live in `ServerStorage` or
`ServerScriptService`. The SDK:

- Returns an inert module (metadata only) if required from the client.
- Errors on `init()` from the client.
- Warns at runtime if it detects placement under a replicated container.

**Never** place the SDK, `RoControlConfig`, or `ApiKey` in `ReplicatedStorage`,
`ReplicatedFirst`, `StarterPlayer`, `StarterGui`, `StarterPack`, or `Workspace`.

## API keys

- Per-universe and capability-scoped (`schedule:write`, `event:report`).
- The backend derives your universe from the key — a client cannot spoof a
  `universeId` in the payload.
- Store the key in `ServerStorage/RoControlConfig/ApiKey`, not in source control.

### Rotation

1. Create a new key in the dashboard.
2. Update `ServerStorage/RoControlConfig/ApiKey` and publish.
3. Revoke the old key.

## Logging

Secrets are redacted centrally (`src/Logging/Redaction.luau`). The SDK never logs
the API key, `Authorization` header, cookies, or CSRF tokens. If you supply a
custom `Logger`, redaction still runs before your sink receives records.

## Reporting issues

See [SECURITY.md](../SECURITY.md). Report privately to security@rocontrol.app.
