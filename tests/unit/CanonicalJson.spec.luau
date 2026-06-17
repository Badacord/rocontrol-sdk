--!strict
local CanonicalJson = require("../../src/Schedules/CanonicalJson")

return function(t: any)
	t:describe("CanonicalJson.encode", function()
		t:it("sorts object keys", function()
			t:eq(CanonicalJson.encode({ b = 1, a = 2, arr = { 3, 2, 1 } }), '{"a":2,"arr":[3,2,1],"b":1}')
		end)

		t:it("preserves array order", function()
			t:eq(CanonicalJson.encode({ 3, 1, 2 }), "[3,1,2]")
		end)

		t:it("encodes nested objects deterministically", function()
			t:eq(
				CanonicalJson.encode({ key = "world-events", events = { { key = "Lava", weight = 3 } } }),
				'{"events":[{"key":"Lava","weight":3}],"key":"world-events"}'
			)
		end)

		t:it("encodes booleans and integers", function()
			t:eq(CanonicalJson.encode({ ok = true, n = 42 }), '{"n":42,"ok":true}')
		end)

		t:it("escapes special characters in strings", function()
			t:eq(CanonicalJson.encode('a"b\\c'), '"a\\"b\\\\c"')
		end)

		t:it("rejects non-integer numbers", function()
			local ok = pcall(function()
				CanonicalJson.encode({ n = 1.5 })
			end)
			t:falsy(ok, "expected error on float")
		end)
	end)
end
