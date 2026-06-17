--!strict
-- Structured, level-filtered logger. Every record is a flat field table so it can
-- be routed to any backend. A custom `Logger` sink may be supplied in InitConfig;
-- otherwise records are printed with a stable `[RoControl]` prefix.
--
-- Secrets are redacted here, centrally, so no call site has to remember.

local Types = require(script.Parent.Parent.Types)
local Redaction = require(script.Parent.Redaction)

type LogLevel = Types.LogLevel
type Logger = Types.Logger
type LogFields = Types.LogFields

local LEVEL_ORDER: { [LogLevel]: number } = {
	silent = 0,
	error = 1,
	warn = 2,
	info = 3,
	debug = 4,
}

-- `warn` exists in Roblox; under Lune/CI it does not, so fall back to print.
local warnFn: (...any) -> () = (warn :: any) or print

export type StructuredLogger = {
	log: (self: StructuredLogger, level: LogLevel, message: string, fields: LogFields?) -> (),
	child: (self: StructuredLogger, baseFields: LogFields) -> StructuredLogger,
	error: (self: StructuredLogger, message: string, fields: LogFields?) -> (),
	warn: (self: StructuredLogger, message: string, fields: LogFields?) -> (),
	info: (self: StructuredLogger, message: string, fields: LogFields?) -> (),
	debug: (self: StructuredLogger, message: string, fields: LogFields?) -> (),
}

local LoggerImpl = {}
LoggerImpl.__index = LoggerImpl

local function mergeFields(base: LogFields?, extra: LogFields?): LogFields?
	if base == nil then
		return extra
	end
	if extra == nil then
		return base
	end
	local out: LogFields = {}
	for k, v in pairs(base) do
		out[k] = v
	end
	for k, v in pairs(extra) do
		out[k] = v
	end
	return out
end

-- Default sink: prints a single readable line. Production deployments usually
-- pass their own `Logger` to forward JSON to an analytics pipeline.
local function defaultSink(level: LogLevel, message: string, fields: LogFields?)
	local prefix = string.format("[RoControl][%s] %s", string.upper(level), message)
	if fields ~= nil and next(fields) ~= nil then
		if level == "error" or level == "warn" then
			warnFn(prefix, fields)
		else
			print(prefix, fields)
		end
	else
		if level == "error" or level == "warn" then
			warnFn(prefix)
		else
			print(prefix)
		end
	end
end

export type LoggerOptions = {
	level: LogLevel,
	sink: Logger?,
	baseFields: LogFields?,
}

function LoggerImpl.new(options: LoggerOptions): StructuredLogger
	local self = setmetatable({
		_level = options.level,
		_threshold = LEVEL_ORDER[options.level] or LEVEL_ORDER.info,
		_sink = options.sink,
		_baseFields = options.baseFields,
	}, LoggerImpl)
	return (self :: any) :: StructuredLogger
end

function LoggerImpl.log(self: any, level: LogLevel, message: string, fields: LogFields?)
	local levelOrder = LEVEL_ORDER[level] or LEVEL_ORDER.info
	if levelOrder == 0 or levelOrder > self._threshold then
		return
	end

	local merged = mergeFields(self._baseFields, fields)
	local safe = Redaction.redact(merged)

	if self._sink ~= nil then
		self._sink:log(level, message, safe)
	else
		defaultSink(level, message, safe)
	end
end

-- Returns a logger that automatically includes `baseFields` (e.g. requestId) on
-- every record, without mutating the parent.
function LoggerImpl.child(self: any, baseFields: LogFields): StructuredLogger
	return LoggerImpl.new({
		level = self._level,
		sink = self._sink,
		baseFields = mergeFields(self._baseFields, baseFields),
	})
end

function LoggerImpl.error(self: any, message: string, fields: LogFields?)
	self:log("error", message, fields)
end

function LoggerImpl.warn(self: any, message: string, fields: LogFields?)
	self:log("warn", message, fields)
end

function LoggerImpl.info(self: any, message: string, fields: LogFields?)
	self:log("info", message, fields)
end

function LoggerImpl.debug(self: any, message: string, fields: LogFields?)
	self:log("debug", message, fields)
end

return LoggerImpl
