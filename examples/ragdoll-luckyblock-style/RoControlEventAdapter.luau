--!strict
-- Maps a game-owned EventScheduleConfig to the SDK's RoControlSchedule contract.
-- Keep your game config as the single source of truth; this adapter is the glue.

local function adapt(config: any)
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
		-- Use sequential unless you have switched the in-game picker to the SDK's
		-- portable mulberry32-fnv1a32 algorithm (see the docs example).
		rotation = { kind = "sequential" },
		events = events,
	}
end

return adapt
