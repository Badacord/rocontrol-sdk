# Example: ragdoll-luckyblock-style adapter

Shows a game that already owns a deterministic event schedule adapting it to the
SDK with a tiny adapter, keeping the game config as the source of truth.

- `EventScheduleConfig.example.luau` — the game-owned config (with `iconAssetId`).
- `RoControlEventAdapter.luau` — maps it to a `RoControlSchedule`.

Usage:

```lua
local client = RoControl.init({ apiKey = ServerStorage.RoControlConfig.ApiKey.Value })
client:registerSchedule(adapt(EventScheduleConfig))
```

Full walkthrough: [docs/ragdoll-luckyblock-example.md](../../docs/ragdoll-luckyblock-example.md).
