--!strict
-- Maps a raw HTTP response to either success or a typed RoControlError. This is
-- the only place status codes are interpreted, so retry policy stays consistent.

local Types = require(script.Parent.Parent.Types)
local HttpServiceAdapter = require(script.Parent.Parent.Internal.HttpServiceAdapter)
local ErrorFactory = require(script.Parent.Parent.Errors)

type RoControlError = Types.RoControlError
type HttpResponse = HttpServiceAdapter.HttpResponse

local ResponseClassifier = {}

export type Classification = {
	ok: boolean,
	error: RoControlError?,
}

-- Extracts a server-provided request id if present, for log correlation.
local function extractRequestId(response: HttpResponse): string?
	local headers = response.headers
	if type(headers) == "table" then
		local id = headers["RoControl-Request-Id"] or headers["rocontrol-request-id"]
		if type(id) == "string" then
			return id
		end
	end
	return nil
end

function ResponseClassifier.classify(response: HttpResponse): Classification
	local status = response.statusCode
	local requestId = extractRequestId(response)

	if status >= 200 and status < 300 then
		return { ok = true }
	end

	if status == 0 then
		return {
			ok = false,
			error = ErrorFactory.new("Transport", response.statusMessage or "Transport failure", {
				statusCode = 0,
				requestId = requestId,
				retryable = true,
			}),
		}
	end

	if status == 401 or status == 403 then
		return {
			ok = false,
			error = ErrorFactory.new("Auth", "Authentication failed (" .. status .. ")", {
				statusCode = status,
				requestId = requestId,
				retryable = false,
			}),
		}
	end

	if status == 408 then
		return {
			ok = false,
			error = ErrorFactory.new("Timeout", "Request timeout (408)", {
				statusCode = status,
				requestId = requestId,
				retryable = true,
			}),
		}
	end

	if status == 409 then
		-- Idempotency conflict: same key, different payload. Caller-visible, not retryable.
		return {
			ok = false,
			error = ErrorFactory.new("Validation", "Idempotency conflict (409)", {
				statusCode = status,
				requestId = requestId,
				retryable = false,
			}),
		}
	end

	if status == 429 then
		return {
			ok = false,
			error = ErrorFactory.new("RateLimit", "Rate limited (429)", {
				statusCode = status,
				requestId = requestId,
				retryable = true,
			}),
		}
	end

	if status >= 400 and status < 500 then
		return {
			ok = false,
			error = ErrorFactory.new("Validation", "Client error (" .. status .. ")", {
				statusCode = status,
				requestId = requestId,
				retryable = false,
			}),
		}
	end

	-- 5xx
	return {
		ok = false,
		error = ErrorFactory.new("Server", "Server error (" .. status .. ")", {
			statusCode = status,
			requestId = requestId,
			retryable = true,
		}),
	}
end

-- Parses a Retry-After header (seconds form) into a number, if present.
function ResponseClassifier.retryAfterSeconds(response: HttpResponse): number?
	local headers = response.headers
	if type(headers) ~= "table" then
		return nil
	end
	local value = headers["Retry-After"] or headers["retry-after"]
	if value == nil then
		return nil
	end
	local seconds = tonumber(value)
	if seconds ~= nil and seconds >= 0 then
		return seconds
	end
	return nil
end

return ResponseClassifier
