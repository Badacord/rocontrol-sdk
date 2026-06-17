--!strict
-- A ready-to-register RoControlSchedule descriptor.
return {
	key = "world-events",
	timezone = "UTC",
	cycleSeconds = 1800, -- one event every 30 minutes
	eventDurationSeconds = 300, -- each shows for 5 minutes
	rotation = { kind = "sequential" },
	events = {
		{ key = "Lava", iconAssetId = "rbxassetid://111", durationSeconds = 300 },
		{ key = "Toxic", iconAssetId = "rbxassetid://222", durationSeconds = 300 },
		{ key = "Mirror", iconAssetId = "rbxassetid://333", durationSeconds = 300 },
	},
}
