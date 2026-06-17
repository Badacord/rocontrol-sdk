--!strict
-- Removes secrets from structured log fields before they ever reach a sink.
-- This is defense-in-depth: the SDK also simply never puts the API key into a
-- field table, but redaction guarantees it even if a future change slips up.

local Redaction = {}

-- Field names that must never be logged in clear text (compared case-insensitively).
local SENSITIVE_KEYS: { [string]: boolean } = {
	apikey = true,
	api_key = true,
	authorization = true,
	auth = true,
	token = true,
	cookie = true,
	["set-cookie"] = true,
	["x-csrf-token"] = true,
	csrf = true,
	secret = true,
	password = true,
	bearer = true,
}

local REDACTED = "[REDACTED]"
local MAX_DEPTH = 4

local function isSensitive(key: string): boolean
	return SENSITIVE_KEYS[string.lower(key)] == true
end

local function redactValue(value: any, depth: number): any
	if depth > MAX_DEPTH then
		return "[max-depth]"
	end

	if type(value) ~= "table" then
		return value
	end

	local out = {}
	for k, v in pairs(value) do
		if type(k) == "string" and isSensitive(k) then
			out[k] = REDACTED
		else
			out[k] = redactValue(v, depth + 1)
		end
	end
	return out
end

-- Returns a copy of `fields` with all sensitive keys (at any nesting depth) masked.
function Redaction.redact(fields: { [string]: any }?): { [string]: any }?
	if fields == nil then
		return nil
	end
	return redactValue(fields, 1)
end

function Redaction.isSensitiveKey(key: string): boolean
	return isSensitive(key)
end

return Redaction
