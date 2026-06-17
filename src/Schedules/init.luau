--!strict
-- Schedule layer: validation/normalization, canonical hashing, deterministic
-- rotation, occurrence computation, and registry/adapter helpers.
--
-- The occurrence math (`stateAt`) mirrors what the RoControl backend computes, so
-- games can preview/verify the schedule client-side. The hash and rotation are
-- portable to the TypeScript backend.

local Validators = require(script.Validators)
local CanonicalJson = require(script.CanonicalJson)
local Hash = require(script.Hash)
local Sequential = require(script.Sequential)
local WeightedDeterministic = require(script.WeightedDeterministic)
local RegistryScan = require(script.RegistryScan)
local Adapters = require(script.Adapters)

local Types = require(script.Parent.Types)

type RoControlError = Types.RoControlError

local Schedules = {}

Schedules.validateAndNormalize = Validators.validateAndNormalize
Schedules.normalizeAssetId = Validators.normalizeAssetId
Schedules.canonicalize = CanonicalJson.encode
Schedules.buildFromRegistry = RegistryScan.build
Schedules.mapEvents = Adapters.mapEvents

export type OccurrenceEvent = {
	eventKey: string,
	iconAssetId: string?,
	startAt: number,
	expiry: number,
	cycleIndex: number,
}

export type ScheduleState = {
	scheduleHash: string,
	cycleIndex: number,
	current: OccurrenceEvent?,
	nextEvent: OccurrenceEvent,
}

-- Validates + normalizes + hashes. Returns (hash, normalized, nil) or (nil, nil, error).
function Schedules.hashOf(descriptor: any): (string?, any?, RoControlError?)
	local normalized, err = Validators.validateAndNormalize(descriptor)
	if err ~= nil or normalized == nil then
		return nil, nil, err
	end
	local canonical = CanonicalJson.encode(normalized)
	return Hash.ofString(canonical), normalized, nil
end

-- Picks the event for a cycle from a *normalized* descriptor.
function Schedules.eventForCycle(normalized: any, scheduleHash: string, cycleIndex: number): any
	local events = normalized.events
	local index
	if normalized.rotation.kind == "weighted" then
		local weights = table.create(#events)
		for i, event in ipairs(events) do
			weights[i] = event.weight
		end
		index = WeightedDeterministic.pickIndex(scheduleHash, cycleIndex, weights)
	else
		index = Sequential.pickIndex(cycleIndex, #events)
	end
	return events[index]
end

local function toOccurrence(event: any, startAt: number, duration: number, cycleIndex: number): OccurrenceEvent
	return {
		eventKey = event.key,
		iconAssetId = event.iconAssetId,
		startAt = startAt,
		expiry = startAt + duration,
		cycleIndex = cycleIndex,
	}
end

-- Resolves the schedule state at a unix timestamp: the currently-active event (if
-- any) and the next event. Mirrors the backend resolver.
function Schedules.stateAt(descriptor: any, nowUnix: number): (ScheduleState?, RoControlError?)
	local hash, normalized, err = Schedules.hashOf(descriptor)
	if err ~= nil or normalized == nil or hash == nil then
		return nil, err
	end

	local cycle = normalized.cycleSeconds
	local duration = normalized.eventDurationSeconds
	local anchor = normalized.startsAtUnix

	local cycleIndex = math.floor((nowUnix - anchor) / cycle)
	local cycleStart = anchor + cycleIndex * cycle
	local intoCycle = nowUnix - cycleStart

	local current: OccurrenceEvent? = nil
	if intoCycle >= 0 and intoCycle < duration then
		current = toOccurrence(Schedules.eventForCycle(normalized, hash, cycleIndex), cycleStart, duration, cycleIndex)
	end

	local nextIndex = cycleIndex + 1
	local nextStart = anchor + nextIndex * cycle
	local nextEvent = toOccurrence(Schedules.eventForCycle(normalized, hash, nextIndex), nextStart, duration, nextIndex)

	return {
		scheduleHash = hash,
		cycleIndex = cycleIndex,
		current = current,
		nextEvent = nextEvent,
	},
		nil
end

return Schedules
