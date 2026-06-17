--!strict
local LocalDebounce = require("../../src/Leases/LocalDebounce")

return function(t: any)
	t:describe("LocalDebounce", function()
		t:it("sends once per occurrence within the TTL", function()
			local d = LocalDebounce.new()
			t:truthy(d:shouldSend("boss:1", 0, 100))
			t:falsy(d:shouldSend("boss:1", 50, 100))
		end)

		t:it("sends again after the TTL expires", function()
			local d = LocalDebounce.new()
			t:truthy(d:shouldSend("boss:1", 0, 100))
			t:truthy(d:shouldSend("boss:1", 101, 100))
		end)

		t:it("tracks occurrences independently", function()
			local d = LocalDebounce.new()
			t:truthy(d:shouldSend("boss:1", 0, 100))
			t:truthy(d:shouldSend("boss:2", 0, 100))
		end)
	end)
end
