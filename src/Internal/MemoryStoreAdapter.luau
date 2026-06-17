--!strict
-- Wraps MemoryStoreService hash maps for the cross-server single-flight lease.
-- Phase 1 ships the adapter boundary and interface; the claim logic that uses it
-- lands with the lease implementation in Phase 4 (src/Leases).

export type HashMapAdapter = {
	-- Atomic compare-and-set against a key. `transform(old)` returns the new value
	-- (or nil to leave unchanged). Returns the stored value after the update.
	updateAsync: (self: HashMapAdapter, key: string, ttlSeconds: number, transform: (any) -> any) -> any,
	getAsync: (self: HashMapAdapter, key: string) -> any,
}

export type MemoryStoreAdapter = {
	available: boolean,
	getHashMap: (self: MemoryStoreAdapter, name: string) -> HashMapAdapter?,
}

local MemoryStoreAdapter = {}
MemoryStoreAdapter.__index = MemoryStoreAdapter

local HashMapImpl = {}
HashMapImpl.__index = HashMapImpl

function HashMapImpl.new(raw: any)
	return setmetatable({ _raw = raw }, HashMapImpl)
end

function HashMapImpl.updateAsync(self: any, key: string, ttlSeconds: number, transform: (any) -> any): any
	return self._raw:UpdateAsync(key, transform, ttlSeconds)
end

function HashMapImpl.getAsync(self: any, key: string): any
	return self._raw:GetAsync(key)
end

function MemoryStoreAdapter.new(): MemoryStoreAdapter
	local ok, service = pcall(function()
		return game:GetService("MemoryStoreService")
	end)

	local self = setmetatable({
		available = ok and service ~= nil,
		_service = if ok then service else nil,
	}, MemoryStoreAdapter)
	return (self :: any) :: MemoryStoreAdapter
end

function MemoryStoreAdapter.getHashMap(self: any, name: string): HashMapAdapter?
	if not self.available then
		return nil
	end
	local ok, map = pcall(function()
		return self._service:GetHashMap(name)
	end)
	if not ok or map == nil then
		return nil
	end
	return (HashMapImpl.new(map) :: any) :: HashMapAdapter
end

return MemoryStoreAdapter
