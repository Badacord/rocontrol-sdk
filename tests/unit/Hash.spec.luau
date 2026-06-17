--!strict
-- Golden vectors for the portable 32-bit math. These MUST match the TypeScript
-- backend. The fnv1a32 values below are the canonical FNV-1a reference values.
local Hash = require("../../src/Schedules/Hash")

return function(t: any)
	t:describe("Hash.fnv1a32", function()
		t:it("matches canonical FNV-1a reference vectors", function()
			t:eq(Hash.fnv1a32(""), 2166136261) -- offset basis
			t:eq(Hash.fnv1a32("a"), 3826002220) -- 0xe40c292c
			t:eq(Hash.fnv1a32("abc"), 440920331) -- 0x1a47e90b
		end)

		t:it("renders 8-char lowercase hex", function()
			t:eq(Hash.ofString(""), "811c9dc5")
			t:eq(Hash.ofString("a"), "e40c292c")
			t:eq(Hash.ofString("abc"), "1a47e90b")
		end)

		t:it("is deterministic", function()
			t:eq(Hash.fnv1a32("world-events:0"), Hash.fnv1a32("world-events:0"))
		end)
	end)

	t:describe("Hash.mulberry32", function()
		t:it("produces the golden sequence for a fixed seed", function()
			local rng = Hash.mulberry32(Hash.fnv1a32("seed"))
			t:near(rng(), 0.9498909888789058, 1e-9)
			t:near(rng(), 0.0760880485177040, 1e-9)
			t:near(rng(), 0.0262593005318195, 1e-9)
		end)

		t:it("yields values in [0, 1)", function()
			local rng = Hash.mulberry32(12345)
			for _ = 1, 50 do
				local v = rng()
				t:truthy(v >= 0 and v < 1, "value out of range: " .. tostring(v))
			end
		end)

		t:it("is reproducible from the same seed", function()
			local a = Hash.mulberry32(999)
			local b = Hash.mulberry32(999)
			t:eq(a(), b())
			t:eq(a(), b())
		end)
	end)
end
