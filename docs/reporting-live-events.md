# Reporting Live Events (imperative)

Use `reportEvent` for events that aren't a fixed schedule — admin-triggered,
player-triggered, or random.

```lua
client:reportEvent({
	key = "BlackHole",
	iconAssetId = "rbxassetid://789",
	durationSeconds = 120,
	-- startedAt defaults to now; occurrenceId defaults to key:startedAt
})
```

## The multi-server problem

Roblox runs many servers per universe, and the game icon is one global resource.
If every server reported every occurrence, RoControl would get hammered.

The SDK solves this in two layers:

1. **Cross-server single-flight** via MemoryStore (Phase 4): all servers compute
   the same `occurrenceId = key:startedAt` and race for an atomic claim. Only the
   winner sends. *(Until Phase 4 ships, every server sends and layer 2 dedupes.)*
2. **Backend idempotency** keyed by `universeId:event:occurrenceId`: duplicate
   reports are safe no-ops. This is the correctness guarantee; the lease is the
   efficiency optimization.

If MemoryStore is unavailable, the SDK degrades to a per-server debounce and relies
on backend idempotency — it never crashes.

## Idempotency and occurrence ids

Pass `occurrenceId` yourself if you have a natural unique id; otherwise the SDK
derives `normalizedKey:startedAt`. The same occurrence reported twice (same id)
results in one icon change.

## Handling failures

```lua
client:onFailedOperation(function(failed)
	if failed.error.retryable then
		client:retryFailedOperation(failed)
	end
end)
```

`reportEvent` returns immediately with `status = "queued"`; the network result
arrives via metrics, logs, and `onFailedOperation`.
