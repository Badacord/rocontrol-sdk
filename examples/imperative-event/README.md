# Example: imperative event

For events that aren't a fixed schedule (admin/player/random triggered). Call
`client:reportEvent(...)` when the event begins. Duplicate reports across servers
are safe no-ops.

See [reporting-live-events](../../docs/reporting-live-events.md).
