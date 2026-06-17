--!strict
-- A game-owned, deterministic schedule config (modeled on the ragdoll-luckyblock
-- pattern). Note the added `iconAssetId` field per event.
return {
	CycleSeconds = 30 * 60,
	EventDurationSeconds = 5 * 60,
	Events = {
		{ name = "Lava", weight = 3, iconAssetId = 111 },
		{ name = "Toxic", weight = 3, iconAssetId = 222 },
		{ name = "Mirror", weight = 3, iconAssetId = 333 },
		{ name = "Angelic", weight = 1, iconAssetId = 444 },
	},
}
