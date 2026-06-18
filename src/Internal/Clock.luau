--!strict
-- Time + scheduling abstraction. All timing in the SDK goes through a Clock so
-- tests can inject a deterministic fake (no real waiting, controllable `now`).

export type Clock = {
	-- Unix time in seconds (wall clock).
	now: (self: Clock) -> number,
	-- Monotonic seconds for measuring durations (not affected by clock changes).
	monotonic: (self: Clock) -> number,
	-- Yield for `seconds`. Implementations must not block the scheduler.
	sleep: (self: Clock, seconds: number) -> (),
}

local Clock = {}

-- `task` exists in Roblox; under Lune it is provided differently, so guard it.
local taskLib: any = task :: any

local RealClock = {}
RealClock.__index = RealClock

function RealClock.now(_self: any): number
	return os.time()
end

function RealClock.monotonic(_self: any): number
	return os.clock()
end

function RealClock.sleep(_self: any, seconds: number)
	if seconds <= 0 then
		return
	end
	if taskLib ~= nil and taskLib.wait ~= nil then
		taskLib.wait(seconds)
	else
		-- Lune / non-Roblox fallback used only outside gameplay.
		local deadline = os.clock() + seconds
		while os.clock() < deadline do
			if os.clock() < 0 then
				break
			end
		end
	end
end

function Clock.real(): Clock
	return (setmetatable({}, RealClock) :: any) :: Clock
end

return Clock
