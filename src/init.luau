--!strict
-- RoControl Roblox SDK — public entry point.
--
-- Server-only in v1. The SDK holds a privileged API key, so it must live in
-- ServerStorage or ServerScriptService and must never be required from the client.
--
-- Usage:
--   local RoControl = require(ServerStorage.RoControl)
--   local client = RoControl.init({ apiKey = ServerStorage.RoControlConfig.ApiKey.Value })
--   client:registerSchedule(descriptor)

local Types = require(script.Types)
local Metadata = require(script.Metadata)
local Config = require(script.Config)
local Client = require(script.Client)
local Env = require(script.Internal.Env)

-- Re-export every public type so consumers get `RoControl.<Type>` intellisense.
export type LogLevel = Types.LogLevel
export type Logger = Types.Logger
export type MetricsSink = Types.MetricsSink
export type InitConfig = Types.InitConfig
export type RoControlClient = Types.RoControlClient
export type RoControlSchedule = Types.RoControlSchedule
export type RoControlEvent = Types.RoControlEvent
export type ScheduleRotation = Types.ScheduleRotation
export type ReportEventInput = Types.ReportEventInput
export type RoControlUpcomingEvent = Types.RoControlUpcomingEvent
export type UpcomingEventsResult = Types.UpcomingEventsResult
export type RegistryScanConfig = Types.RegistryScanConfig
export type OperationResult = Types.OperationResult
export type OperationStatus = Types.OperationStatus
export type RoControlError = Types.RoControlError
export type ErrorKind = Types.ErrorKind
export type FailedOperation = Types.FailedOperation
export type HealthStatus = Types.HealthStatus

local warnFn: (...any) -> () = (warn :: any) or print

local SERVER_ONLY_MESSAGE =
	"RoControl SDK API keys are server-only. Move RoControl to ServerStorage or ServerScriptService."

-- One-time placement sanity check: secrets must never sit in a replicated container.
local function checkPlacement()
	local ok, fullName = pcall(function()
		return script:GetFullName()
	end)
	if not ok then
		return
	end
	local replicatedContainers = {
		"ReplicatedStorage",
		"ReplicatedFirst",
		"StarterPlayer",
		"StarterGui",
		"StarterPack",
		"Workspace",
	}
	for _, container in ipairs(replicatedContainers) do
		if
			string.find(fullName, "^" .. container) ~= nil
			or string.find(fullName, "%." .. container .. "%.") ~= nil
		then
			warnFn(
				"[RoControl] SDK appears to be under "
					.. container
					.. ". Place it (and your API key) in ServerStorage/ServerScriptService so secrets never replicate to clients."
			)
			return
		end
	end
end

local env = Env.detect()

-- If required from the client, expose only inert metadata. Calling init() errors
-- loudly so a misplaced require is caught immediately in development.
if env.isClient and not env.isServer then
	return table.freeze({
		name = Metadata.name,
		version = Metadata.version,
		protocolVersion = Metadata.protocolVersion,
		init = function(): never
			error(SERVER_ONLY_MESSAGE, 2)
		end,
	})
end

checkPlacement()

local RoControl = {
	name = Metadata.name,
	version = Metadata.version,
	protocolVersion = Metadata.protocolVersion,
}

-- Creates a configured client. Raises a clear Config error on invalid input.
function RoControl.init(config: Types.InitConfig): Types.RoControlClient
	if env.isClient and not env.isServer then
		error(SERVER_ONLY_MESSAGE, 2)
	end

	local resolved, err = Config.resolve(config)
	if err ~= nil or resolved == nil then
		local message = if err ~= nil then err.message else "invalid configuration"
		error("[RoControl] " .. message, 2)
	end

	return Client.new(resolved)
end

-- Test seam: build a client with injected fakes (adapter/clock/env/etc.).
-- Not part of the supported public API; used by the SDK's own test suite.
function RoControl._initWithOverrides(
	config: Types.InitConfig,
	overrides: any
): Types.RoControlClient
	local resolved, err = Config.resolve(config)
	if err ~= nil or resolved == nil then
		local message = if err ~= nil then err.message else "invalid configuration"
		error("[RoControl] " .. message, 2)
	end
	return Client.new(resolved, overrides)
end

return RoControl
