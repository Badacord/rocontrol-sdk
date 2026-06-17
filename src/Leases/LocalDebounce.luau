--!strict
-- Per-server fallback used when MemoryStore is unavailable: ensures a single
-- server won't send the same occurrence twice within its TTL. Combined with
-- backend idempotency, duplicates across servers are still safe.
-- Dependency-free (unit-tested under luau/lune).

export type LocalDebounce = {
	shouldSend: (self: LocalDebounce, occurrenceId: string, now: number, ttlSeconds: number) -> boolean,
}

local LocalDebounce = {}
LocalDebounce.__index = LocalDebounce

local CLEANUP_EVERY = 64

function LocalDebounce.new(): LocalDebounce
	local self = setmetatable({
		_seen = {} :: { [string]: number },
		_since = 0,
	}, LocalDebounce)
	return (self :: any) :: LocalDebounce
end

-- Returns true at most once per occurrence per TTL window on this server.
function LocalDebounce.shouldSend(self: any, occurrenceId: string, now: number, ttlSeconds: number): boolean
	local expiry = self._seen[occurrenceId]
	if expiry ~= nil and expiry > now then
		return false
	end
	self._seen[occurrenceId] = now + ttlSeconds

	-- Opportunistic cleanup so the table can't grow unbounded.
	self._since += 1
	if self._since >= CLEANUP_EVERY then
		self._since = 0
		for id, exp in pairs(self._seen) do
			if exp <= now then
				self._seen[id] = nil
			end
		end
	end

	return true
end

return LocalDebounce
