--!strict
local Sequential = require("../../src/Schedules/Sequential")

return function(t: any)
	t:describe("Sequential.pickIndex", function()
		t:it("round-robins over the event count", function()
			t:eq(Sequential.pickIndex(0, 3), 1)
			t:eq(Sequential.pickIndex(1, 3), 2)
			t:eq(Sequential.pickIndex(2, 3), 3)
			t:eq(Sequential.pickIndex(3, 3), 1)
			t:eq(Sequential.pickIndex(4, 3), 2)
		end)

		t:it("handles a single event", function()
			t:eq(Sequential.pickIndex(0, 1), 1)
			t:eq(Sequential.pickIndex(7, 1), 1)
		end)

		t:it("stays in range for negative cycle indices", function()
			local idx = Sequential.pickIndex(-1, 3)
			t:truthy(idx >= 1 and idx <= 3, "index out of range: " .. tostring(idx))
		end)
	end)
end
