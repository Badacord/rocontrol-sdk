--!strict
-- Lightweight request-id generator. These ids are for correlating client logs
-- with server logs; they are not security tokens, so a fast RNG is fine.

local Uuid = {}

local CHARS = "0123456789abcdef"

-- Lazily created so merely requiring this module never touches engine globals.
local rng: Random? = nil

-- Returns a short, URL-safe correlation id, e.g. "req_a1b2c3d4e5f6".
function Uuid.requestId(): string
	if rng == nil then
		rng = Random.new()
	end
	local activeRng = rng :: Random
	local buffer = table.create(12)
	for i = 1, 12 do
		local index = activeRng:NextInteger(1, #CHARS)
		buffer[i] = string.sub(CHARS, index, index)
	end
	return "req_" .. table.concat(buffer)
end

return Uuid
