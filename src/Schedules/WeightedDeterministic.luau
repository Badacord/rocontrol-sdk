--!strict
-- Portable weighted-random rotation: `mulberry32-fnv1a32`.
--
-- Seed = fnv1a32(scheduleHash .. ":" .. cycleIndex), advanced by the mulberry32
-- PRNG. This is reproducible bit-for-bit in TypeScript (Math.imul-based), unlike
-- Roblox `Random.new`. Same (hash, cycleIndex, weights) -> same chosen index on
-- every machine and on the backend.

local Hash = require(script.Parent.Hash)

local WeightedDeterministic = {}

-- Returns a 1-based index into `weights`, chosen by the seeded roll.
function WeightedDeterministic.pickIndex(scheduleHash: string, cycleIndex: number, weights: { number }): number
	local total = 0
	for _, weight in ipairs(weights) do
		total += weight
	end
	if total <= 0 then
		return 1
	end

	local seed = Hash.fnv1a32(scheduleHash .. ":" .. tostring(cycleIndex))
	local rng = Hash.mulberry32(seed)
	local roll = rng() * total

	local cumulative = 0
	for index, weight in ipairs(weights) do
		cumulative += weight
		if roll < cumulative then
			return index
		end
	end
	return #weights
end

return WeightedDeterministic
