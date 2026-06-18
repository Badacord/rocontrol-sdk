--!strict
-- Place in ServerScriptService. Reads the universe's upcoming Roblox virtual
-- events from the backend (Roblox doesn't expose this feed in-experience) and,
-- after a short warm-up, invites each player to join the next one.
--
-- getUpcomingEvents() yields on the HTTP round-trip, so we call it from a spawned
-- thread — never on a hot path. It never raises: on a backend outage it returns
-- `{ ok = false }` and we simply skip the prompt.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RoControl = require(ServerStorage:WaitForChild("RoControl"))

local PROMPT_AFTER_SECONDS = 60

local client = RoControl.init({
	apiKey = ServerStorage.RoControlConfig.ApiKey.Value,
})

-- Replace with your own UI / ByteNet packet that shows the join prompt.
local function showJoinPrompt(player: Player, event: RoControl.RoControlUpcomingEvent)
	print(
		string.format(
			"[RoControl] inviting %s to '%s' (starts in %ds)",
			player.Name,
			event.title,
			event.startsInSeconds or 0
		)
	)
end

local function promptPlayer(player: Player)
	task.wait(PROMPT_AFTER_SECONDS)
	if player.Parent == nil then
		return -- left during warm-up
	end

	local event = client:getNextEvent()
	if event == nil then
		return -- no upcoming event, or backend unavailable
	end
	showJoinPrompt(player, event)
end

-- safePlayerAdded: handle current players and future joins alike.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(promptPlayer, player)
end
Players.PlayerAdded:Connect(function(player)
	task.spawn(promptPlayer, player)
end)
