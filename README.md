# RoControl Roblox SDK

The official, server-only Roblox SDK for [RoControl](https://rocontrol.app). It lets
any Roblox experience report events and schedules to RoControl so features like
**Icon Automation** can drive the game icon safely and globally.

- **Server-only and safe by default** — your API key never touches the client.
- **Fully typed** Luau with a small, predictable public API.
- **Production-grade** — typed errors, structured logging with secret redaction,
  exponential backoff with jitter, a circuit breaker, a bounded queue, and a
  cross-server single-flight lease so many game servers don't stampede RoControl.
- **Two integration modes** — declarative schedules (zero per-occurrence traffic)
  and imperative `reportEvent` for ad-hoc/random events.

> **v1 is server-only.** The SDK holds a privileged API key. Never place it in
> `ReplicatedStorage`, `StarterPlayer`, `StarterGui`, `Workspace`, or any
> client-replicated container.

## Requirements

- HTTP requests enabled for your experience (Game Settings → Security).
- A RoControl API key (RoControl dashboard → your game → SDK → API Keys).
- MemoryStore is optional but recommended for `reportEvent` (cross-server dedupe).

## Installation

### Option A — Wally (recommended)

```toml
# wally.toml
[server-dependencies]
RoControl = "gh-constant/rocontrol-roblox-sdk@0.1.0"
```

```sh
wally install
```

Then map `ServerPackages` into `ServerScriptService`/`ServerStorage` in your Rojo
project so the SDK stays server-side.

### Option B — Model file (`.rbxm`)

1. Download `RoControl.rbxm` from the [latest release](https://github.com/Badacord/rocontrol-sdk/releases).
2. In Studio, right-click **ServerStorage → Insert from File** and pick the model.
3. Confirm it landed at `ServerStorage/RoControl`.

### Option C — Source / Rojo

```sh
git clone https://github.com/Badacord/rocontrol-sdk
cd rocontrol-sdk
rokit install
wally install
rojo build default.project.json --output RoControl.rbxm
```

## Where things go

| What | Location |
| --- | --- |
| SDK module | `ServerStorage/RoControl` |
| API key | `ServerStorage/RoControlConfig/ApiKey` (a `StringValue`) |
| Bootstrap script | `ServerScriptService/RoControlBootstrap.server.luau` |
| Client code | **nothing in v1** |

## Quickstart

```lua
local ServerStorage = game:GetService("ServerStorage")
local RoControl = require(ServerStorage:WaitForChild("RoControl"))

local client = RoControl.init({
	apiKey = ServerStorage.RoControlConfig.ApiKey.Value,
	-- baseUrl defaults to https://api.rocontrol.app
	logLevel = "info",
})

-- Declarative: register a recurring schedule once at server start.
client:registerSchedule({
	key = "world-events",
	timezone = "UTC",
	cycleSeconds = 1800, -- one event every 30 minutes
	eventDurationSeconds = 300, -- each shows for 5 minutes
	rotation = { kind = "sequential" },
	events = {
		{ key = "Lava", iconAssetId = "rbxassetid://123", durationSeconds = 300 },
		{ key = "Toxic", iconAssetId = "rbxassetid://456", durationSeconds = 300 },
	},
})

-- Imperative: report an ad-hoc event (admin/player/random triggered).
client:reportEvent({
	key = "BlackHole",
	iconAssetId = "rbxassetid://789",
	durationSeconds = 120,
})

-- Surface failures without crashing gameplay.
client:onFailedOperation(function(failed)
	warn("RoControl op failed:", failed.operation, failed.error.kind, failed.error.message)
end)
```

## Key rotation

Create a new key in the dashboard, update `ServerStorage/RoControlConfig/ApiKey`,
publish, then revoke the old key. Keys are per-universe and capability-scoped.

## Documentation

Full docs: **[docs/index.md](docs/index.md)** — installation, schedules,
reporting live events, security, and troubleshooting.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md) (for AI coding
agents). Security reports: [SECURITY.md](SECURITY.md).

## License

[Apache-2.0](LICENSE).
