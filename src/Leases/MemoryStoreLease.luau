--!strict
-- Cross-server single-flight. All servers compute the same occurrence id and race
-- for an atomic claim on a MemoryStore hash map; exactly one wins and reports.
-- The backend idempotency layer is the correctness backstop; this just keeps ~one
-- call per occurrence.
--
-- Dependency-free (the hash map is injected), so the claim logic is unit-tested
-- under luau/lune with a fake map.

export type LeaseOutcome = "won" | "lost" | "unavailable"

export type LeaseHashMap = {
	updateAsync: (
		self: LeaseHashMap,
		key: string,
		ttlSeconds: number,
		transform: (any) -> any
	) -> any,
}

export type ClaimParams = {
	hashMap: LeaseHashMap?,
	now: number,
	jobId: string,
	occurrenceId: string,
	ttlSeconds: number,
	sdkVersion: string,
}

local MemoryStoreLease = {}

local MIN_TTL = 60
local MAX_TTL = 86400
local SAFETY_BUFFER = 120

-- TTL = duration + buffer, clamped to [60, 86400] (spec §19).
function MemoryStoreLease.computeTtl(durationSeconds: number?): number
	local base = (durationSeconds or MIN_TTL) + SAFETY_BUFFER
	return math.max(MIN_TTL, math.min(base, MAX_TTL))
end

-- Attempts to claim the lease for `occurrenceId`. Returns:
--   "won"         -> this server should report
--   "lost"        -> another server owns it; skip
--   "unavailable" -> MemoryStore missing/errored; caller should fall back to
--                    LocalDebounce (and the backend will still dedupe)
function MemoryStoreLease.tryClaim(params: ClaimParams): LeaseOutcome
	local hashMap = params.hashMap
	if hashMap == nil then
		return "unavailable"
	end

	local key = "evt:" .. params.occurrenceId
	local ok, stored = pcall(function()
		return hashMap:updateAsync(key, params.ttlSeconds, function(old: any)
			if old == nil or type(old) ~= "table" or (old.expiresAt or 0) <= params.now then
				return {
					ownerJobId = params.jobId,
					occurrenceId = params.occurrenceId,
					claimedAt = params.now,
					expiresAt = params.now + params.ttlSeconds,
					sdkVersion = params.sdkVersion,
				}
			end
			return old
		end)
	end)

	if not ok or type(stored) ~= "table" then
		return "unavailable"
	end

	return if stored.ownerJobId == params.jobId then "won" else "lost"
end

return MemoryStoreLease
