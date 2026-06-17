--!strict
local Retry = require("../../src/Http/Retry")

return function(t: any)
	t:describe("Retry.computeDelay", function()
		local config = { baseDelaySeconds = 0.5, maxDelaySeconds = 10 }

		t:it("returns a value within [0, capped] for each attempt", function()
			-- Deterministic randomFn = 1 yields the full cap.
			t:near(Retry.computeDelay(0, config, function()
				return 1
			end), 0.5)
			t:near(Retry.computeDelay(1, config, function()
				return 1
			end), 1.0)
			t:near(Retry.computeDelay(2, config, function()
				return 1
			end), 2.0)
		end)

		t:it("caps exponential growth at maxDelaySeconds", function()
			-- 0.5 * 2^10 = 512, capped to 10.
			t:near(Retry.computeDelay(10, config, function()
				return 1
			end), 10)
		end)

		t:it("scales by the jitter random value", function()
			t:near(Retry.computeDelay(2, config, function()
				return 0
			end), 0)
			t:near(Retry.computeDelay(2, config, function()
				return 0.5
			end), 1.0)
		end)
	end)

	t:describe("Retry.nextWait", function()
		local config = { baseDelaySeconds = 0.5, maxDelaySeconds = 10 }

		t:it("honors Retry-After when present", function()
			t:eq(Retry.nextWait(0, config, 3), 3)
		end)

		t:it("caps Retry-After to maxDelaySeconds", function()
			t:eq(Retry.nextWait(0, config, 999), 10)
		end)

		t:it("falls back to backoff when no Retry-After", function()
			t:near(Retry.nextWait(1, config, nil, function()
				return 1
			end), 1.0)
		end)
	end)
end
