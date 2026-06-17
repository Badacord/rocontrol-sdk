--!strict
-- Typed error constructors. Every error that leaves the SDK is a `RoControlError`
-- with a stable `kind` and an explicit `retryable` flag, so callers (and the
-- retry layer) never have to string-match messages.

local Types = require(script.Parent.Parent.Types)

type ErrorKind = Types.ErrorKind
type RoControlError = Types.RoControlError

local ErrorFactory = {}

-- Whether a given kind is safe to retry by default. The HTTP layer may still
-- refuse to retry non-idempotent operations regardless of this flag.
local RETRYABLE_BY_KIND: { [ErrorKind]: boolean } = {
	Auth = false,
	RateLimit = true,
	Validation = false,
	Transport = true,
	Server = true,
	Timeout = true,
	Config = false,
	MemoryStore = false,
	CircuitOpen = false,
	Unknown = false,
}

export type NewErrorOptions = {
	statusCode: number?,
	requestId: string?,
	cause: any?,
	retryable: boolean?,
}

function ErrorFactory.new(kind: ErrorKind, message: string, options: NewErrorOptions?): RoControlError
	local opts = options or {}
	local retryable = opts.retryable
	if retryable == nil then
		retryable = RETRYABLE_BY_KIND[kind] or false
	end

	return {
		kind = kind,
		message = message,
		retryable = retryable,
		statusCode = opts.statusCode,
		requestId = opts.requestId,
		cause = opts.cause,
	}
end

function ErrorFactory.config(message: string): RoControlError
	return ErrorFactory.new("Config", message)
end

function ErrorFactory.validation(message: string): RoControlError
	return ErrorFactory.new("Validation", message)
end

function ErrorFactory.auth(message: string, statusCode: number?): RoControlError
	return ErrorFactory.new("Auth", message, { statusCode = statusCode })
end

function ErrorFactory.isRetryable(kind: ErrorKind): boolean
	return RETRYABLE_BY_KIND[kind] or false
end

return ErrorFactory
