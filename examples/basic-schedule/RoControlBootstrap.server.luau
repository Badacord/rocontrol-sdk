--!strict
-- Place this in ServerScriptService. Minimal declarative-schedule integration.
-- The API key lives in ServerStorage/RoControlConfig/ApiKey (a StringValue).

local ServerStorage = game:GetService("ServerStorage")

local RoControl = require(ServerStorage:WaitForChild("RoControl"))
local EventScheduleConfig = require(script.Parent:WaitForChild("EventScheduleConfig"))

local client = RoControl.init({
	apiKey = ServerStorage.RoControlConfig.ApiKey.Value,
	logLevel = "info",
})

client:onFailedOperation(function(failed)
	warn(("[RoControl] %s failed (%s): %s"):format(failed.operation, failed.error.kind, failed.error.message))
end)

client:registerSchedule(EventScheduleConfig)

game:BindToClose(function()
	client:flush()
end)
