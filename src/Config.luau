--!strict
-- Configuration defaults + validation. Invalid user input yields a typed Config
-- error (never a raw crash). The resolved config is a fully-populated, validated
-- table the rest of the SDK can trust.

local Types = require(script.Parent.Types)
local ErrorFactory = require(script.Parent.Errors)

type InitConfig = Types.InitConfig
type RoControlError = Types.RoControlError
type LogLevel = Types.LogLevel

local Config = {}

export type ResolvedConfig = {
	apiKey: string,
	baseUrl: string,
	logLevel: LogLevel,
	httpTimeoutSeconds: number,
	maxRetries: number,
	retryBaseDelaySeconds: number,
	retryMaxDelaySeconds: number,
	circuitBreakerFailureThreshold: number,
	circuitBreakerCooldownSeconds: number,
	enableMemoryStoreLease: boolean,
	studioMode: boolean,
}

type Setting = {
	value: any,
	validator: (any) -> boolean,
	message: string,
}

local function isLogLevel(value: any): boolean
	return value == "silent"
		or value == "error"
		or value == "warn"
		or value == "info"
		or value == "debug"
end

local function isNumberInRange(min: number, max: number): (any) -> boolean
	return function(value: any): boolean
		return type(value) == "number" and value == value and value >= min and value <= max
	end
end

-- Defaults applied when the field is omitted, each with a validator + message.
local DEFAULT_SETTINGS: { [string]: Setting } = {
	baseUrl = {
		value = "https://api.rocontrol.app",
		validator = function(v)
			return type(v) == "string" and v ~= "" and string.match(v, "^https?://") ~= nil
		end,
		message = "baseUrl must be an http(s) URL",
	},
	logLevel = {
		value = "info",
		validator = isLogLevel,
		message = "logLevel must be one of silent|error|warn|info|debug",
	},
	httpTimeoutSeconds = {
		value = 10,
		validator = isNumberInRange(1, 60),
		message = "httpTimeoutSeconds must be between 1 and 60",
	},
	maxRetries = {
		value = 3,
		validator = isNumberInRange(0, 10),
		message = "maxRetries must be between 0 and 10",
	},
	retryBaseDelaySeconds = {
		value = 0.5,
		validator = isNumberInRange(0, 30),
		message = "retryBaseDelaySeconds must be between 0 and 30",
	},
	retryMaxDelaySeconds = {
		value = 10,
		validator = isNumberInRange(0, 120),
		message = "retryMaxDelaySeconds must be between 0 and 120",
	},
	circuitBreakerFailureThreshold = {
		value = 5,
		validator = isNumberInRange(1, 100),
		message = "circuitBreakerFailureThreshold must be between 1 and 100",
	},
	circuitBreakerCooldownSeconds = {
		value = 60,
		validator = isNumberInRange(1, 3600),
		message = "circuitBreakerCooldownSeconds must be between 1 and 3600",
	},
	enableMemoryStoreLease = {
		value = true,
		validator = function(v)
			return type(v) == "boolean"
		end,
		message = "enableMemoryStoreLease must be a boolean",
	},
	studioMode = {
		value = false,
		validator = function(v)
			return type(v) == "boolean"
		end,
		message = "studioMode must be a boolean",
	},
}

-- Resolves user config against defaults + validators.
-- Returns (resolvedConfig, nil) on success or (nil, RoControlError) on failure.
function Config.resolve(input: InitConfig?): (ResolvedConfig?, RoControlError?)
	if type(input) ~= "table" then
		return nil, ErrorFactory.config("init() requires a config table with an apiKey")
	end

	local raw = input :: any

	if type(raw.apiKey) ~= "string" or raw.apiKey == "" then
		return nil, ErrorFactory.config("apiKey is required and must be a non-empty string")
	end

	local resolved: any = { apiKey = raw.apiKey }

	for field, setting in pairs(DEFAULT_SETTINGS) do
		local provided = raw[field]
		if provided == nil then
			resolved[field] = setting.value
		elseif setting.validator(provided) then
			resolved[field] = provided
		else
			return nil, ErrorFactory.config(setting.message)
		end
	end

	if resolved.retryMaxDelaySeconds < resolved.retryBaseDelaySeconds then
		return nil, ErrorFactory.config("retryMaxDelaySeconds must be >= retryBaseDelaySeconds")
	end

	return (resolved :: ResolvedConfig), nil
end

return Config
