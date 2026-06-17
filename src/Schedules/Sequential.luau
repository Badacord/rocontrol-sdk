--!strict
-- Sequential rotation: event index cycles 1..n by cycle index. Trivially
-- deterministic and identical across the game and the backend.

local Sequential = {}

-- 1-based index into `count` events for a given (zero-based) cycle index.
function Sequential.pickIndex(cycleIndex: number, count: number): number
	if count <= 0 then
		return 1
	end
	return (cycleIndex % count) + 1
end

return Sequential
