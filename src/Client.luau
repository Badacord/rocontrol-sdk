--!strict
-- The user-facing client. Validates input, then dispatches HTTP off the gameplay
-- thread via the runtime scheduler so a slow or down RoControl can never stall the
-- game. Network outcomes surface through metrics, logs, and the failed-operation
-- signal.
--
-- Phase markers:
--   * Canonical schedule hashing  -> Phase 2 (src/Schedules). Phase 1 uses a
--     simple stable placeholder so coalescing/idempotency already work.
--   * MemoryStore single-flight   -> Phase 4 (src/Leases). Until then every
--     server reports and the backend idempotency layer dedupes.

local Types = require(script.Parent.Types)
local Runtime = require(script.Parent.Runtime)
local Schedules = require(script.Parent.Schedules)
local Metrics = require(script.Parent.Metrics.Metrics)
local ErrorFactory = require(script.Parent.Errors)
local Uuid = require(script.Parent.Internal.Uuid)

type RoControlClient = Types.RoControlClient
type RoControlSchedule = Types.RoControlSchedule
type ReportEventInput = Types.ReportEventInput
type RegistryScanConfig = Types.RegistryScanConfig
type OperationResult = Types.OperationResult
type FailedOperation = Types.FailedOperation
type RoControlError = Types.RoControlError

local Client = {}
Client.__index = Client

local MAX_PENDING = 64
local FLUSH_STEP_SECONDS = 0.05
local FLUSH_TIMEOUT_SECONDS = 8

local function normalizeKey(key: string): string
	return (string.gsub(string.lower(key), "%s+", "-"))
end

function Client.new(resolvedConfig: any, overrides: Runtime.Overrides?): RoControlClient
	local runtime = Runtime.create(resolvedConfig, overrides)
	local self = setmetatable({
		_runtime = runtime,
		_destroyed = false,
		_pending = 0,
		_lastSuccessAt = nil :: number?,
		_lastFailureAt = nil :: number?,
		_sentScheduleHashes = {} :: { [string]: boolean },
	}, Client)

	runtime.logger:info("RoControl SDK initialized", {
		event = "init",
		baseUrl = resolvedConfig.baseUrl,
	})
	runtime.metrics:count(Metrics.Names.init)

	return (self :: any) :: RoControlClient
end

-- Internal async dispatch. Returns an OperationResult describing the *enqueue*
-- decision; the network result arrives via metrics/logs/failed signal.
function Client._dispatch(
	self: any,
	operation: "registerSchedule" | "reportEvent",
	routeName: string,
	payload: any,
	idempotencyKey: string,
	successMetric: string,
	failureMetric: string,
	attemptMetric: string
): OperationResult
	local runtime = self._runtime

	if self._destroyed then
		return {
			ok = false,
			status = "disabled",
			error = ErrorFactory.config("client has been destroyed"),
		}
	end

	if self._pending >= MAX_PENDING then
		runtime.metrics:count(Metrics.Names.queueDropped, 1, { operation = operation })
		local err = ErrorFactory.new("Transport", "SDK pending queue is full", { retryable = false })
		runtime.failedSignal:fire({
			operation = operation,
			status = "dropped",
			error = err,
		})
		return { ok = false, status = "skipped", error = err }
	end

	local requestId = Uuid.requestId()
	self._pending += 1
	runtime.metrics:count(attemptMetric)
	runtime.metrics:count(Metrics.Names.queueEnqueued, 1, { operation = operation })

	runtime.scheduler(function()
		local ok, result = pcall(function()
			return runtime.http:send(routeName, payload, {
				idempotencyKey = idempotencyKey,
				requestId = requestId,
			})
		end)

		self._pending = math.max(0, self._pending - 1)

		if not ok then
			self._lastFailureAt = runtime.clock:now()
			runtime.metrics:count(failureMetric)
			local err = ErrorFactory.new("Unknown", "Dispatch crashed: " .. tostring(result))
			runtime.failedSignal:fire({
				operation = operation,
				status = "failed",
				requestId = requestId,
				error = err,
				_route = routeName,
				_payload = payload,
				_idempotencyKey = idempotencyKey,
			} :: any)
			return
		end

		if result.ok then
			self._lastSuccessAt = runtime.clock:now()
			runtime.metrics:count(successMetric)
		else
			self._lastFailureAt = runtime.clock:now()
			runtime.metrics:count(failureMetric)
			local err = result.error :: RoControlError
			runtime.failedSignal:fire({
				operation = operation,
				status = if err.kind == "CircuitOpen" then "circuit_open" else "failed",
				requestId = requestId,
				error = err,
				_route = routeName,
				_payload = payload,
				_idempotencyKey = idempotencyKey,
			} :: any)
		end
	end)

	return { ok = true, status = "queued", requestId = requestId }
end

function Client.registerSchedule(self: any, descriptor: RoControlSchedule): OperationResult
	-- Validate + normalize + canonical-hash. The normalized descriptor (defaults
	-- filled, asset ids/keys normalized) is what we hash and send, so the hash is
	-- stable and reproducible by the backend.
	local hash, normalized, err = Schedules.hashOf(descriptor)
	if err ~= nil or hash == nil then
		return { ok = false, status = "failed", error = err }
	end

	if self._sentScheduleHashes[hash] then
		-- Identical schedule already registered this server session; coalesce.
		return { ok = true, status = "duplicate" }
	end
	self._sentScheduleHashes[hash] = true

	local env = self._runtime.env
	local payload = {
		sdkVersion = self._runtime.metadata.version,
		protocolVersion = self._runtime.metadata.protocolVersion,
		placeId = env.placeId,
		placeVersion = env.placeVersion,
		jobId = env.jobId,
		isStudio = env.isStudio,
		scheduleHash = hash,
		descriptor = normalized,
	}
	-- Universe is derived server-side from the API key; we only contribute the hash.
	local idempotencyKey = "schedule:" .. hash .. ":" .. tostring(env.placeVersion)

	return self:_dispatch(
		"registerSchedule",
		"registerSchedule",
		payload,
		idempotencyKey,
		Metrics.Names.scheduleRegisterSuccess,
		Metrics.Names.scheduleRegisterFailure,
		Metrics.Names.scheduleRegisterAttempt
	)
end

function Client.reportEvent(self: any, input: ReportEventInput): OperationResult
	if type(input) ~= "table" or type(input.key) ~= "string" or input.key == "" then
		return { ok = false, status = "failed", error = ErrorFactory.validation("event.key is required") }
	end

	local startedAt = input.startedAt or self._runtime.clock:now()
	local occurrenceId = input.occurrenceId or (normalizeKey(input.key) .. ":" .. tostring(startedAt))

	local env = self._runtime.env
	local payload = {
		sdkVersion = self._runtime.metadata.version,
		protocolVersion = self._runtime.metadata.protocolVersion,
		placeId = env.placeId,
		placeVersion = env.placeVersion,
		jobId = env.jobId,
		isStudio = env.isStudio,
		occurrenceId = occurrenceId,
		event = {
			key = input.key,
			label = input.label,
			iconAssetId = input.iconAssetId,
			startedAt = startedAt,
			durationSeconds = input.durationSeconds,
			priority = input.priority,
			metadata = input.metadata,
		},
	}
	local idempotencyKey = "event:" .. occurrenceId

	-- Phase 4 will gate this behind a MemoryStore lease so only one server sends.
	return self:_dispatch(
		"reportEvent",
		"reportEvent",
		payload,
		idempotencyKey,
		Metrics.Names.eventReportSuccess,
		Metrics.Names.eventReportFailure,
		Metrics.Names.eventReportAttempt
	)
end

-- Convenience scan: builds a schedule descriptor from a folder of event
-- instances/modules (reads `IconAssetId`/`Priority` attributes). The result is
-- validated/normalized when passed to `registerSchedule`.
function Client.buildScheduleFromRegistry(self: any, config: RegistryScanConfig): RoControlSchedule
	return Schedules.buildFromRegistry(config)
end

function Client.onFailedOperation(self: any, callback: (FailedOperation) -> ()): RBXScriptConnection
	return self._runtime.failedSignal:connect(callback)
end

function Client.retryFailedOperation(self: any, failed: any): OperationResult
	if self._destroyed then
		return { ok = false, status = "disabled", error = ErrorFactory.config("client has been destroyed") }
	end
	if type(failed) ~= "table" or failed._route == nil or failed._payload == nil then
		return {
			ok = false,
			status = "failed",
			error = ErrorFactory.validation("retryFailedOperation requires a FailedOperation from onFailedOperation"),
		}
	end

	local operation = failed.operation
	local metricSuffix = if operation == "registerSchedule"
		then {
			Metrics.Names.scheduleRegisterSuccess,
			Metrics.Names.scheduleRegisterFailure,
			Metrics.Names.scheduleRegisterAttempt,
		}
		else { Metrics.Names.eventReportSuccess, Metrics.Names.eventReportFailure, Metrics.Names.eventReportAttempt }

	return self:_dispatch(
		operation,
		failed._route,
		failed._payload,
		failed._idempotencyKey,
		metricSuffix[1],
		metricSuffix[2],
		metricSuffix[3]
	)
end

function Client.getHealth(self: any)
	local now = self._runtime.clock:now()
	return {
		initialized = not self._destroyed,
		circuitOpen = not self._runtime.circuit:canRequest(now),
		lastSuccessAt = self._lastSuccessAt,
		lastFailureAt = self._lastFailureAt,
		pendingRequests = self._pending,
		sdkVersion = self._runtime.metadata.version,
	}
end

-- Bounded wait until the in-flight queue drains. Safe to call from shutdown.
function Client.flush(self: any)
	local clock = self._runtime.clock
	local deadline = clock:monotonic() + FLUSH_TIMEOUT_SECONDS
	while self._pending > 0 and clock:monotonic() < deadline do
		clock:sleep(FLUSH_STEP_SECONDS)
	end
end

function Client.destroy(self: any)
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:flush()
	self._runtime.failedSignal:destroy()
	self._runtime.logger:info("RoControl SDK destroyed", { event = "destroy" })
end

return Client
