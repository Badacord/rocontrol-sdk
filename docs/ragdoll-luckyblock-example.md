# Worked Example: adapting a deterministic schedule

This shows how a game with its own time-based event schedule (modeled on the
`ragdoll-luckyblock` pattern) integrates with RoControl. The game stays the source
of truth; you write a tiny adapter to the SDK's contract.

## 1. Add an icon asset id to each event

Your in-game event config already lists events. Add one field per event:

```lua
-- EventScheduleConfig.luau (game-owned)
EventScheduleConfig.CycleSeconds = 30 * 60
EventScheduleConfig.EventDurationSeconds = 5 * 60
EventScheduleConfig.Events = {
	{ name = "Lava",    weight = 3, iconAssetId = 111 },
	{ name = "Toxic",   weight = 3, iconAssetId = 222 },
	{ name = "Mirror",  weight = 3, iconAssetId = 333 },
	{ name = "Angelic", weight = 1, iconAssetId = 444 },
}
```

## 2. Write the adapter

```lua
-- RoControlEventAdapter.luau
local function adapt(config)
	local events = {}
	for _, event in ipairs(config.Events) do
		table.insert(events, {
			key = event.name,
			iconAssetId = "rbxassetid://" .. tostring(event.iconAssetId),
			durationSeconds = config.EventDurationSeconds,
			weight = event.weight,
		})
	end
	return {
		key = "world-events",
		timezone = "UTC",
		cycleSeconds = config.CycleSeconds,
		eventDurationSeconds = config.EventDurationSeconds,
		-- Your game uses a weighted pick. To make the icon match in-game, switch
		-- the game's selection to the SDK's portable algorithm (see note below).
		rotation = { kind = "weighted", algorithm = "mulberry32-fnv1a32" },
		events = events,
	}
end

return adapt
```

## 3. Register at server start

```lua
local client = RoControl.init({ apiKey = ServerStorage.RoControlConfig.ApiKey.Value })
client:registerSchedule(adapt(EventScheduleConfig))
```

## 4. Report admin/manual events imperatively

For your `StartEventGlobalCommand`-style manual triggers:

```lua
client:reportEvent({ key = eventName, iconAssetId = "rbxassetid://" .. assetId, durationSeconds = 300 })
```

## Note on weighted rotation

Roblox `Random.new(cycleIndex)` is **not** reproducible by the RoControl backend.
If you want the displayed icon to exactly match the event your game ran, change the
game's per-cycle selection to the same `mulberry32-fnv1a32` algorithm the SDK and
backend share. If you only need "rotate these icons on this cadence," prefer
`{ kind = "sequential" }` — simplest and exactly reproducible everywhere.
