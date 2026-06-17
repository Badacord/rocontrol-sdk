--!strict
local Redaction = require("../../src/Logging/Redaction")

return function(t: any)
	t:describe("Redaction", function()
		t:it("masks top-level sensitive keys", function()
			local out = Redaction.redact({ apiKey = "secret", route = "registerSchedule" })
			t:eq(out.apiKey, "[REDACTED]")
			t:eq(out.route, "registerSchedule")
		end)

		t:it("masks sensitive keys case-insensitively", function()
			local out = Redaction.redact({ Authorization = "Bearer x", TOKEN = "y" })
			t:eq(out.Authorization, "[REDACTED]")
			t:eq(out.TOKEN, "[REDACTED]")
		end)

		t:it("masks nested sensitive keys", function()
			local out = Redaction.redact({ headers = { authorization = "Bearer x", ["content-type"] = "json" } })
			t:eq(out.headers.authorization, "[REDACTED]")
			t:eq(out.headers["content-type"], "json")
		end)

		t:it("does not mutate the original table", function()
			local original = { apiKey = "secret" }
			Redaction.redact(original)
			t:eq(original.apiKey, "secret")
		end)

		t:it("returns nil for nil input", function()
			t:eq(Redaction.redact(nil), nil)
		end)
	end)
end
