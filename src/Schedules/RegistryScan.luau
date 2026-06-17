--!strict
-- Convenience: build a (raw) schedule descriptor by scanning a Folder of event
-- instances/modules. Reads `IconAssetId` and `Priority` attributes per child.
-- The result is validated/normalized when passed to `registerSchedule`.

local Types = require(script.Parent.Parent.Types)

type RegistryScanConfig = Types.RegistryScanConfig
type RoControlSchedule = Types.RoControlSchedule

local RegistryScan = {}

function RegistryScan.build(config: RegistryScanConfig): RoControlSchedule
	assert(typeof(config.folder) == "Instance", "RegistryScanConfig.folder must be an Instance")
	local duration = config.defaultDurationSeconds or 300
	local readAttributes = config.readAttributes ~= false

	local events = {}
	for _, child in ipairs(config.folder:GetChildren()) do
		local iconAssetId = if readAttributes then child:GetAttribute("IconAssetId") else nil
		local priority = if readAttributes then child:GetAttribute("Priority") else nil
		table.insert(events, {
			key = child.Name,
			iconAssetId = if iconAssetId ~= nil then iconAssetId else nil,
			durationSeconds = duration,
			priority = if typeof(priority) == "number" then priority else config.defaultPriority,
		})
	end

	return {
		key = config.folder.Name,
		timezone = "UTC",
		cycleSeconds = math.max(duration, #events * duration),
		eventDurationSeconds = duration,
		rotation = { kind = "sequential" },
		events = events,
	}
end

return RegistryScan
