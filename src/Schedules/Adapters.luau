--!strict
-- Small helpers for writing an adapter from a game's own event config to the
-- SDK's RoControlEvent contract. The explicit adapter pattern (see docs) is the
-- robust path; these just remove boilerplate.

local Types = require(script.Parent.Parent.Types)

type RoControlEvent = Types.RoControlEvent

local Adapters = {}

-- Maps an arbitrary list to RoControlEvent[] via `transform`.
function Adapters.mapEvents<T>(
	items: { T },
	transform: (item: T, index: number) -> RoControlEvent
): { RoControlEvent }
	local events = table.create(#items)
	for index, item in ipairs(items) do
		events[index] = transform(item, index)
	end
	return events
end

return Adapters
