# Event Schedules (declarative)

Use a schedule when your events follow a fixed cadence. You register the
definition once at server start; RoControl computes occurrences and drives the
icon. No per-occurrence traffic.

```lua
client:registerSchedule({
	key = "world-events",
	timezone = "UTC",
	cycleSeconds = 1800,        -- one event every 30 minutes
	eventDurationSeconds = 300, -- each event shows for 5 minutes
	startsAtUnix = nil,         -- optional anchor; defaults to epoch-aligned cycles
	rotation = { kind = "sequential" },
	events = {
		{ key = "Lava", iconAssetId = "rbxassetid://111", durationSeconds = 300, priority = 50 },
		{ key = "Toxic", iconAssetId = "rbxassetid://222", durationSeconds = 300, priority = 50 },
	},
})
```

## Rotation

- **`{ kind = "sequential" }`** (default, recommended) — events cycle in order.
  Trivially deterministic across the game and the backend.
- **`{ kind = "weighted", algorithm = "mulberry32-fnv1a32" }`** (advanced) —
  weighted-random per cycle using a portable PRNG the backend reproduces exactly.
  Use only if you need weighted selection; **never** rely on Roblox `Random.new`
  for the icon to match in-game, because the backend cannot reproduce it.

## Priority

`priority` is **static** and optional — lower wins. Most studios leave it unset
(all equal). It only matters when multiple sources are active at once; RoControl
shows a single winning overlay, tie-breaking by most-recently-started.

## Versioning

The SDK hashes the descriptor; that hash is the schedule version. Re-registering
an identical schedule is a no-op (coalesced). Editing the schedule and shipping a
new place version makes RoControl adopt the new definition; older servers running
the old build cannot overwrite a newer one.

## Building from a registry

If your events live in a `Folder` of modules/instances:

```lua
local descriptor = client:buildScheduleFromRegistry({
	folder = ServerStorage.EventTemplates,
	defaultDurationSeconds = 300,
	readAttributes = true, -- reads an `IconAssetId` attribute per child
})
client:registerSchedule(descriptor)
```
