--!strict
-- Deterministic JSON serialization for hashing. Object keys are sorted; only
-- integers, strings, booleans, arrays, and string-keyed objects are allowed so
-- the output is byte-identical in Luau and TypeScript.
--
-- Normalize a descriptor (Validators) BEFORE encoding so there are no floats,
-- empty objects, or stray fields.

local CanonicalJson = {}

local function encodeString(value: string): string
	local escaped = value
	escaped = string.gsub(escaped, "\\", "\\\\")
	escaped = string.gsub(escaped, '"', '\\"')
	escaped = string.gsub(escaped, "\n", "\\n")
	escaped = string.gsub(escaped, "\r", "\\r")
	escaped = string.gsub(escaped, "\t", "\\t")
	return '"' .. escaped .. '"'
end

local function isArray(t: { [any]: any }): boolean
	local count = 0
	for key in pairs(t) do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end
	return count == #t
end

local function encodeValue(value: any): string
	local valueType = type(value)
	if value == nil then
		return "null"
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "number" then
		assert(
			value == value and value ~= math.huge and value ~= -math.huge,
			"canonical json: non-finite number"
		)
		assert(
			math.floor(value) == value,
			"canonical json: numbers must be integers (normalize first)"
		)
		return string.format("%d", value)
	elseif valueType == "string" then
		return encodeString(value)
	elseif valueType == "table" then
		if isArray(value) then
			local parts = table.create(#value)
			for index = 1, #value do
				parts[index] = encodeValue(value[index])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do
			assert(type(key) == "string", "canonical json: object keys must be strings")
			table.insert(keys, key)
		end
		table.sort(keys)
		local parts = {}
		for _, key in ipairs(keys) do
			table.insert(parts, encodeString(key) .. ":" .. encodeValue(value[key]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("canonical json: unsupported type " .. valueType)
end

function CanonicalJson.encode(value: any): string
	return encodeValue(value)
end

return CanonicalJson
