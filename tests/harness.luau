--!strict
-- Tiny zero-dependency test harness. Runs under the `luau` CLI and `lune` so the
-- pure-logic suites execute in CI without a Roblox DataModel. Roblox-coupled
-- modules (Client, HttpClient, Signal) are covered by the TestEZ suite that runs
-- inside Studio / run-in-roblox (see CONTRIBUTING.md).

export type Harness = {
	passed: number,
	failed: number,
	failures: { string },
	describe: (self: Harness, name: string, fn: () -> ()) -> (),
	it: (self: Harness, name: string, fn: () -> ()) -> (),
	eq: (self: Harness, got: any, want: any, msg: string?) -> (),
	truthy: (self: Harness, value: any, msg: string?) -> (),
	falsy: (self: Harness, value: any, msg: string?) -> (),
	near: (self: Harness, got: number, want: number, tol: number?, msg: string?) -> (),
}

local Harness = {}
Harness.__index = Harness

function Harness.new(): Harness
	local self = setmetatable({
		passed = 0,
		failed = 0,
		failures = {},
		_suite = "",
	}, Harness)
	return (self :: any) :: Harness
end

function Harness.describe(self: any, name: string, fn: () -> ())
	self._suite = name
	fn()
end

function Harness.it(self: any, name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		self.passed += 1
	else
		self.failed += 1
		table.insert(self.failures, string.format("%s > %s: %s", self._suite, name, tostring(err)))
	end
end

function Harness.eq(_self: any, got: any, want: any, msg: string?)
	if got ~= want then
		error(
			string.format(
				"%s (got %s, want %s)",
				msg or "expected equal",
				tostring(got),
				tostring(want)
			),
			2
		)
	end
end

function Harness.truthy(_self: any, value: any, msg: string?)
	if not value then
		error(msg or "expected truthy value", 2)
	end
end

function Harness.falsy(_self: any, value: any, msg: string?)
	if value then
		error(msg or "expected falsy value", 2)
	end
end

function Harness.near(_self: any, got: number, want: number, tol: number?, msg: string?)
	if math.abs(got - want) > (tol or 1e-6) then
		error(string.format("%s (got %f, want ~%f)", msg or "expected near", got, want), 2)
	end
end

return Harness
