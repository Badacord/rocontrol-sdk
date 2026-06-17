--!strict
-- Pure-logic test runner. Executes under the `luau` CLI or `lune`:
--   luau tests/run.luau     (run from the repo root)
--   lune run tests/run.luau
--
-- These suites cover the engine-independent core. Roblox-coupled modules are
-- tested with TestEZ inside Studio / run-in-roblox (see CONTRIBUTING.md).

local Harness = require("./harness")

local specs = {
	require("./unit/Retry.spec"),
	require("./unit/CircuitBreaker.spec"),
	require("./unit/Queue.spec"),
	require("./unit/Redaction.spec"),
}

local t = Harness.new()
for _, spec in ipairs(specs) do
	spec(t)
end

print(string.format("\nRoControl SDK tests: %d passed, %d failed", t.passed, t.failed))
for _, failure in ipairs(t.failures) do
	print("  FAIL: " .. failure)
end

if t.failed > 0 then
	error(string.format("%d test(s) failed", t.failed))
end
