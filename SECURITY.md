# Security Policy

## Reporting a vulnerability

Please report security issues privately to **security@rocontrol.app**. Do not open
a public issue for vulnerabilities. We aim to acknowledge within 3 business days.

Include: affected version, a description, reproduction steps, and impact.

## What counts as sensitive

- RoControl API keys (per-universe, capability-scoped).
- The `Authorization` header / bearer tokens.
- Roblox cookies and CSRF tokens.

The SDK never logs these (see `src/Logging/Redaction.luau`) and never sends them to
any host other than the configured `baseUrl`.

## API key exposure

If an API key is exposed:

1. Rotate it in the RoControl dashboard (create new → update
   `ServerStorage/RoControlConfig/ApiKey` → publish → revoke old).
2. Keys are per-universe and capability-scoped, limiting blast radius.

**Never** place the SDK or its API key in a client-replicated container
(`ReplicatedStorage`, `StarterPlayer`, `StarterGui`, `Workspace`). The SDK warns at
runtime if it detects such placement, and refuses `init()` on the client.

## Supported versions

The latest minor release receives security fixes. Pre-1.0, only the latest
published version is supported.
