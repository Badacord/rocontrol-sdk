--!strict
local Queue = require("../../src/Internal/Queue")

return function(t: any)
	t:describe("Queue", function()
		t:it("is FIFO for equal priorities", function()
			local q = Queue.new(10)
			q:push("a")
			q:push("b")
			q:push("c")
			t:eq(q:pop(), "a")
			t:eq(q:pop(), "b")
			t:eq(q:pop(), "c")
			t:truthy(q:isEmpty())
		end)

		t:it("reports size and empties via clear", function()
			local q = Queue.new(10)
			q:push("a")
			q:push("b")
			t:eq(q:size(), 2)
			q:clear()
			t:eq(q:size(), 0)
		end)

		t:it("drops the lowest-priority item when full", function()
			local q = Queue.new(2)
			-- lower number = more important
			t:truthy(q:push("low", 1000))
			t:truthy(q:push("high", 1))
			-- queue full; a mid-priority item evicts the worst (low)
			t:truthy(q:push("mid", 100))
			-- "low" should be gone; remaining are high + mid
			local first = q:pop()
			local second = q:pop()
			local present = { [first] = true, [second] = true }
			t:truthy(present["high"])
			t:truthy(present["mid"])
			t:falsy(present["low"])
		end)

		t:it("rejects a newcomer less important than everything queued", function()
			local q = Queue.new(1)
			t:truthy(q:push("important", 1))
			t:falsy(q:push("trivial", 9999))
			t:eq(q:pop(), "important")
		end)
	end)
end
