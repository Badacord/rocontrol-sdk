# Quickstart

Create `ServerScriptService/RoControlBootstrap.server.luau`:

```lua
local ServerStorage = game:GetService("ServerStorage")
local RoControl = require(ServerStorage:WaitForChild("RoControl"))

local client = RoControl.init({
	apiKey = ServerStorage.RoControlConfig.ApiKey.Value,
	logLevel = "info", -- "silent" in production if you prefer
})

-- Surface failures (never crashes gameplay).
client:onFailedOperation(function(failed)
	warn(("[RoControl] %s failed: %s — %s"):format(
		failed.operation,
		failed.error.kind,
		failed.error.message
	))
end)

-- Register a recurring schedule once at startup.
client:registerSchedule({
	key = "world-events",
	timezone = "UTC",
	cycleSeconds = 1800,
	eventDurationSeconds = 300,
	rotation = { kind = "sequential" },
	events = {
		{ key = "Lava", iconAssetId = "rbxassetid://111", durationSeconds = 300 },
		{ key = "Toxic", iconAssetId = "rbxassetid://222", durationSeconds = 300 },
		{ key = "Mirror", iconAssetId = "rbxassetid://333", durationSeconds = 300 },
	},
})

-- Flush pending work on shutdown.
game:BindToClose(function()
	client:flush()
end)
```

## Verify the connection

Check the dashboard (SDK → Activity) — you should see the schedule registration
with your `placeId` and `placeVersion`. Locally, set `logLevel = "debug"` to see
request logs (secrets are always redacted).

## Next

- [Event schedules](event-schedules.md) — cadence, duration, rotation.
- [Reporting live events](reporting-live-events.md) — ad-hoc events.
