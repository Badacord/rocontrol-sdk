--!strict
-- Validates and normalizes a RoControlSchedule into a deterministic canonical
-- shape (defaults filled, asset ids/keys normalized, integers enforced). The
-- canonical descriptor is what gets hashed and sent, so normalization must be
-- stable and total.

local Types = require(script.Parent.Parent.Types)
local ErrorFactory = require(script.Parent.Parent.Errors)

type RoControlSchedule = Types.RoControlSchedule
type RoControlError = Types.RoControlError

local Validators = {}

local DEFAULT_PRIORITY = 100
local DEFAULT_WEIGHT = 1
local WEIGHTED_ALGORITHM = "mulberry32-fnv1a32"

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and math.floor(value) == value
end

-- Accepts 123, "123", "rbxassetid://123". Returns canonical "rbxassetid://123".
function Validators.normalizeAssetId(value: any): (string?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) == "number" then
		if not isInteger(value) or value <= 0 then
			return nil, "iconAssetId number must be a positive integer"
		end
		return string.format("rbxassetid://%d", value), nil
	end
	if type(value) == "string" then
		local digits = string.match(value, "^%s*rbxassetid://(%d+)%s*$") or string.match(value, "^%s*(%d+)%s*$")
		if digits == nil then
			return nil, "iconAssetId string must be digits or rbxassetid://<digits>"
		end
		return "rbxassetid://" .. digits, nil
	end
	return nil, "iconAssetId must be a number or string"
end

local function normalizeEvent(raw: any, fallbackDuration: number): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "each event must be a table"
	end
	if type(raw.key) ~= "string" or string.gsub(raw.key, "%s", "") == "" then
		return nil, "event.key must be a non-empty string"
	end

	local assetId, assetErr = Validators.normalizeAssetId(raw.iconAssetId)
	if assetErr ~= nil then
		return nil, string.format("event '%s': %s", raw.key, assetErr)
	end

	local duration = raw.durationSeconds
	if duration == nil then
		duration = fallbackDuration
	elseif not isInteger(duration) or duration <= 0 then
		return nil, string.format("event '%s': durationSeconds must be a positive integer", raw.key)
	end

	local priority = raw.priority
	if priority == nil then
		priority = DEFAULT_PRIORITY
	elseif not isInteger(priority) then
		return nil, string.format("event '%s': priority must be an integer", raw.key)
	end

	local weight = raw.weight
	if weight == nil then
		weight = DEFAULT_WEIGHT
	elseif not isInteger(weight) or weight <= 0 then
		return nil, string.format("event '%s': weight must be a positive integer", raw.key)
	end

	local normalized: any = {
		key = (string.gsub(raw.key, "^%s*(.-)%s*$", "%1")),
		durationSeconds = duration,
		priority = priority,
		weight = weight,
	}
	if assetId ~= nil then
		normalized.iconAssetId = assetId
	end
	return normalized, nil
end

-- Returns (normalizedDescriptor, nil) or (nil, RoControlError).
function Validators.validateAndNormalize(descriptor: any): (any?, RoControlError?)
	if type(descriptor) ~= "table" then
		return nil, ErrorFactory.validation("schedule must be a table")
	end
	if type(descriptor.key) ~= "string" or descriptor.key == "" then
		return nil, ErrorFactory.validation("schedule.key must be a non-empty string")
	end
	if descriptor.timezone ~= nil and descriptor.timezone ~= "UTC" then
		return nil, ErrorFactory.validation("schedule.timezone must be \"UTC\"")
	end
	if not isInteger(descriptor.cycleSeconds) or descriptor.cycleSeconds <= 0 then
		return nil, ErrorFactory.validation("schedule.cycleSeconds must be a positive integer")
	end
	if not isInteger(descriptor.eventDurationSeconds) or descriptor.eventDurationSeconds <= 0 then
		return nil, ErrorFactory.validation("schedule.eventDurationSeconds must be a positive integer")
	end
	if descriptor.eventDurationSeconds > descriptor.cycleSeconds then
		return nil, ErrorFactory.validation("schedule.eventDurationSeconds must be <= cycleSeconds")
	end

	local startsAtUnix = descriptor.startsAtUnix
	if startsAtUnix == nil then
		startsAtUnix = 0
	elseif not isInteger(startsAtUnix) or startsAtUnix < 0 then
		return nil, ErrorFactory.validation("schedule.startsAtUnix must be a non-negative integer")
	end

	local rotation = descriptor.rotation
	local normalizedRotation: any
	if type(rotation) ~= "table" or rotation.kind == "sequential" then
		normalizedRotation = { kind = "sequential" }
	elseif rotation.kind == "weighted" then
		if rotation.algorithm ~= WEIGHTED_ALGORITHM then
			return nil, ErrorFactory.validation("weighted rotation requires algorithm \"" .. WEIGHTED_ALGORITHM .. "\"")
		end
		normalizedRotation = { kind = "weighted", algorithm = WEIGHTED_ALGORITHM }
	else
		return nil, ErrorFactory.validation("schedule.rotation.kind must be \"sequential\" or \"weighted\"")
	end

	if type(descriptor.events) ~= "table" or #descriptor.events == 0 then
		return nil, ErrorFactory.validation("schedule.events must be a non-empty array")
	end

	local events = {}
	for index, rawEvent in ipairs(descriptor.events) do
		local normalized, err = normalizeEvent(rawEvent, descriptor.eventDurationSeconds)
		if err ~= nil then
			return nil, ErrorFactory.validation(string.format("schedule.events[%d]: %s", index, err))
		end
		table.insert(events, normalized)
	end

	return {
		key = (string.gsub(descriptor.key, "^%s*(.-)%s*$", "%1")),
		timezone = "UTC",
		cycleSeconds = descriptor.cycleSeconds,
		eventDurationSeconds = descriptor.eventDurationSeconds,
		startsAtUnix = startsAtUnix,
		rotation = normalizedRotation,
		events = events,
	},
		nil
end

return Validators
