--!strict
-- Shared lease types.

export type LeaseOutcome = "won" | "lost" | "unavailable"

-- The minimal hash-map surface the lease needs (satisfied by
-- Internal/MemoryStoreAdapter's HashMapAdapter, or a fake in tests).
export type LeaseHashMap = {
	updateAsync: (
		self: LeaseHashMap,
		key: string,
		ttlSeconds: number,
		transform: (any) -> any
	) -> any,
}

export type LeaseRecord = {
	ownerJobId: string,
	occurrenceId: string,
	claimedAt: number,
	expiresAt: number,
	sdkVersion: string,
}

return {}
