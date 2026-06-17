# Example: basic schedule

The simplest integration — register a recurring schedule at server start.

1. Put the SDK at `ServerStorage/RoControl`.
2. Create `ServerStorage/RoControlConfig/ApiKey` (StringValue) with your key.
3. Put `RoControlBootstrap.server.luau` and `EventScheduleConfig.luau` together in
   `ServerScriptService` (the script requires the config as a sibling).

That's it — RoControl computes occurrences and drives the icon. No per-occurrence
traffic.
