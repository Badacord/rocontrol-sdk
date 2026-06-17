# RoControl Roblox SDK

The RoControl SDK connects your Roblox experience to RoControl. In v1 it powers
**Icon Automation** — showing event overlays on your game icon — but it's built as
the foundation for future RoControl integrations.

## Two ways to integrate

| Mode | Use when | Traffic |
| --- | --- | --- |
| **Declarative schedule** | Your events follow a fixed cadence (e.g. one every 30 min) | One registration per server boot |
| **Imperative `reportEvent`** | Events are admin/player/random triggered | ~one report per occurrence (cross-server lease) |

Most studios only need declarative schedules. Use `reportEvent` for the
unpredictable ones.

## Why it's safe

- **Server-only.** The API key never reaches the client.
- **Never blocks gameplay.** All network work happens off the gameplay thread; a
  down or slow RoControl can't stall your game.
- **Idempotent.** Duplicate reports (from multiple servers) are safe no-ops.

## Next steps

- [Installation](installation.md)
- [Quickstart](quickstart.md)
- [Event schedules](event-schedules.md)
- [Reporting live events](reporting-live-events.md)
- [API reference](api-reference.md)
- [Security](security.md)
- [Troubleshooting](troubleshooting.md)
