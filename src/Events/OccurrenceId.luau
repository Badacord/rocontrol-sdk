--!strict
-- Deterministic occurrence ids. Every server computes the same id for the same
-- logical occurrence, which is what makes the cross-server lease and the backend
-- idempotency key agree. Dependency-free (unit-tested under luau/lune).

local OccurrenceId = {}

-- Lowercased, whitespace-collapsed event key (stable across servers).
function OccurrenceId.normalizeKey(key: string): string
	return (string.gsub(string.lower(key), "%s+", "-"))
end

-- `<normalizedKey>:<startedAtUnixSeconds>`.
function OccurrenceId.build(key: string, startedAt: number): string
	return OccurrenceId.normalizeKey(key) .. ":" .. tostring(startedAt)
end

return OccurrenceId
