--!strict
local CircuitBreaker = require("../../src/Http/CircuitBreaker")

return function(t: any)
	t:describe("CircuitBreaker", function()
		t:it("stays closed below the failure threshold", function()
			local cb = CircuitBreaker.new({ failureThreshold = 3, cooldownSeconds = 60 })
			cb:recordFailure(0)
			cb:recordFailure(1)
			t:eq(cb:state(2), "closed")
			t:truthy(cb:canRequest(2))
		end)

		t:it("opens at the failure threshold", function()
			local cb = CircuitBreaker.new({ failureThreshold = 3, cooldownSeconds = 60 })
			cb:recordFailure(0)
			cb:recordFailure(0)
			cb:recordFailure(0)
			t:eq(cb:state(0), "open")
			t:falsy(cb:canRequest(0))
		end)

		t:it("moves to half_open after cooldown", function()
			local cb = CircuitBreaker.new({ failureThreshold = 1, cooldownSeconds = 60 })
			cb:recordFailure(100)
			t:eq(cb:state(120), "open")
			t:eq(cb:state(160), "half_open")
			t:truthy(cb:canRequest(160))
		end)

		t:it("closes again on success and fires onClose", function()
			local closed = false
			local cb = CircuitBreaker.new({ failureThreshold = 1, cooldownSeconds = 60 })
			cb:onClose(function()
				closed = true
			end)
			cb:recordFailure(0)
			cb:recordSuccess()
			t:eq(cb:state(0), "closed")
			t:truthy(closed)
		end)

		t:it("fires onOpen exactly when it opens", function()
			local opens = 0
			local cb = CircuitBreaker.new({ failureThreshold = 2, cooldownSeconds = 60 })
			cb:onOpen(function()
				opens += 1
			end)
			cb:recordFailure(0)
			cb:recordFailure(0)
			cb:recordFailure(0)
			t:eq(opens, 1)
		end)
	end)
end
