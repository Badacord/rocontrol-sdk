--!strict
-- Place in ServerScriptService. Reports an ad-hoc event (e.g. an admin-triggered
-- boss). The SDK dedupes across servers; the backend idempotency layer guarantees
-- a single icon change per occurrence.

local ServerStorage = game:GetService("ServerStorage")
local RoControl = require(ServerStorage:WaitForChild("RoControl"))

local client = RoControl.init({
	apiKey = ServerStorage.RoControlConfig.ApiKey.Value,
})

client:onFailedOperation(function(failed)
	if failed.error.retryable then
		client:retryFailedOperation(failed)
	else
		warn("[RoControl] giving up:", failed.error.kind, failed.error.message)
	end
end)

-- Call this when your event actually begins.
local function onBlackHoleStarted()
	client:reportEvent({
		key = "BlackHole",
		label = "Black Hole",
		iconAssetId = "rbxassetid://789",
		durationSeconds = 120,
	})
end

-- Demo trigger:
onBlackHoleStarted()
