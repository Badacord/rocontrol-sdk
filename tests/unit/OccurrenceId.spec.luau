--!strict
local OccurrenceId = require("../../src/Events/OccurrenceId")

return function(t: any)
	t:describe("OccurrenceId", function()
		t:it("normalizes keys (lowercase, collapse whitespace)", function()
			t:eq(OccurrenceId.normalizeKey("Black Hole"), "black-hole")
			t:eq(OccurrenceId.normalizeKey("  Lava   Storm "), "-lava-storm-")
		end)

		t:it("builds a deterministic id", function()
			t:eq(OccurrenceId.build("BlackHole", 1700), "blackhole:1700")
			t:eq(OccurrenceId.build("Black Hole", 1700), "black-hole:1700")
		end)

		t:it("is stable for the same inputs", function()
			t:eq(OccurrenceId.build("X", 5), OccurrenceId.build("X", 5))
		end)
	end)
end
