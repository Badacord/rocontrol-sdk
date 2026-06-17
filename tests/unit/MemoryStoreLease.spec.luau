--!strict
local MemoryStoreLease = require("../../src/Leases/MemoryStoreLease")

-- Fake MemoryStore hash map shared across "servers".
local function fakeMap()
	local store: { [string]: any } = {}
	return {
		updateAsync = function(_self: any, key: string, _ttl: number, transform: (any) -> any)
			local newValue = transform(store[key])
			store[key] = newValue
			return newValue
		end,
	}
end

local function erroringMap()
	return {
		updateAsync = function()
			error("memorystore down")
		end,
	}
end

return function(t: any)
	t:describe("MemoryStoreLease.computeTtl", function()
		t:it("adds a buffer and clamps", function()
			t:eq(MemoryStoreLease.computeTtl(300), 420)
			t:eq(MemoryStoreLease.computeTtl(1000000000), 86400)
		end)
	end)

	t:describe("MemoryStoreLease.tryClaim", function()
		t:it("returns unavailable with no hash map", function()
			t:eq(
				MemoryStoreLease.tryClaim({
					hashMap = nil,
					now = 0,
					jobId = "A",
					occurrenceId = "boss:1",
					ttlSeconds = 180,
					sdkVersion = "0.1.0",
				}),
				"unavailable"
			)
		end)

		t:it("grants exactly one winner across servers", function()
			local map = fakeMap()
			local function claim(jobId: string)
				return MemoryStoreLease.tryClaim({
					hashMap = map,
					now = 0,
					jobId = jobId,
					occurrenceId = "boss:1",
					ttlSeconds = 180,
					sdkVersion = "0.1.0",
				})
			end
			t:eq(claim("serverA"), "won")
			t:eq(claim("serverB"), "lost")
			t:eq(claim("serverC"), "lost")
		end)

		t:it("lets a new server reclaim after expiry", function()
			local map = fakeMap()
			t:eq(
				MemoryStoreLease.tryClaim({ hashMap = map, now = 0, jobId = "A", occurrenceId = "e:1", ttlSeconds = 180, sdkVersion = "v" }),
				"won"
			)
			t:eq(
				MemoryStoreLease.tryClaim({ hashMap = map, now = 200, jobId = "B", occurrenceId = "e:1", ttlSeconds = 180, sdkVersion = "v" }),
				"won"
			)
		end)

		t:it("treats MemoryStore errors as unavailable", function()
			t:eq(
				MemoryStoreLease.tryClaim({ hashMap = erroringMap(), now = 0, jobId = "A", occurrenceId = "e:1", ttlSeconds = 180, sdkVersion = "v" }),
				"unavailable"
			)
		end)
	end)
end
