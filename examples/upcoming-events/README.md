# Example: upcoming events

Read the universe's upcoming Roblox virtual events and prompt players to join the
next one. Roblox doesn't expose the virtual-events feed in-experience, so the SDK
relays it from the backend (the same feed that drives icon automation).

- `client:getUpcomingEvents()` — yields, returns
  `{ ok, events, active, nextEvent, serverTime, sourceError }`. Never raises; a
  backend outage returns `{ ok = false, error = ... }`.
- `client:getNextEvent()` — convenience: the soonest not-yet-started event (or a
  currently-active one), or `nil`.

Each event carries `startsInSeconds` (computed against the backend clock, so you
don't trust client time) and `active` (true while it's running).

Call these from a spawned thread, never on a hot path. Any valid SDK API key
works — no extra scope is required.

See [event-schedules](../../docs/event-schedules.md).
