--!strict
-- The user-facing client. Validates input, then dispatches HTTP off the gameplay
-- thread via the runtime scheduler so a slow or down RoControl can never stall the
-- game. Network outcomes surface through metrics, logs, and the failed-operation
-- signal.
--
-- Schedule registration uses canonical-JSON content hashing (src/Schedules).
-- reportEvent is single-flighted across servers via a MemoryStore lease
-- (src/Leases), with a per-server debounce fallback when MemoryStore is
-- unavailable; the backend idempotency layer is the correctness backstop.

local Types = require(script.Parent.Types)
local Runtime = require(script.Parent.Runtime)
local Schedules = require(script.Parent.Schedules)
local Leases = require(script.Parent.Leases)
local OccurrenceId = require(script.Parent.Events.OccurrenceId)
local Metrics = require(script.Parent.Metrics.Metrics)
local ErrorFactory = require(script.Parent.Errors)
local Uuid = require(script.Parent.Internal.Uuid)

local MemoryStoreLease = Leases.MemoryStoreLease

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
local emitModerationMetric: (Metrics.Metrics, any) -> ()

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
		local err =
			ErrorFactory.new("Transport", "SDK pending queue is full", { retryable = false })
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
			emitModerationMetric(runtime.metrics, result.body)
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

emitModerationMetric = function(metrics: Metrics.Metrics, body: any)
	if type(body) ~= "table" or type(body.moderation) ~= "table" then
		return
	end
	local status = body.moderation.status
	if status == "pending" then
		metrics:count(Metrics.Names.moderationPending)
	elseif status == "approved" then
		metrics:count(Metrics.Names.moderationApproved)
	elseif status == "rejected" then
		metrics:count(Metrics.Names.moderationRejected)
	elseif status == "failed" then
		metrics:count(Metrics.Names.moderationFailed)
	end
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
		return {
			ok = false,
			status = "failed",
			error = ErrorFactory.validation("event.key is required"),
		}
	end

	local runtime = self._runtime
	local startedAt = input.startedAt or runtime.clock:now()
	local occurrenceId = input.occurrenceId or OccurrenceId.build(input.key, startedAt)

	-- Cross-server single-flight: only one server actually reports an occurrence.
	-- Lease for efficiency; backend idempotency for correctness.
	local ttl = MemoryStoreLease.computeTtl(input.durationSeconds)
	local now = runtime.clock:now()
	if runtime.config.enableMemoryStoreLease then
		local outcome = MemoryStoreLease.tryClaim({
			hashMap = runtime.getLeaseHashMap(),
			now = now,
			jobId = runtime.env.jobId,
			occurrenceId = occurrenceId,
			ttlSeconds = ttl,
			sdkVersion = runtime.metadata.version,
		})
		if outcome == "won" then
			runtime.metrics:count(Metrics.Names.leaseWin)
		elseif outcome == "lost" then
			runtime.metrics:count(Metrics.Names.leaseLoss)
			return { ok = true, status = "duplicate" }
		else
			-- MemoryStore unavailable: degrade to per-server debounce.
			runtime.metrics:count(Metrics.Names.leaseError)
			runtime.logger:warn(
				"lease unavailable; using local debounce",
				{ event = "lease_unavailable" }
			)
			if not runtime.localDebounce:shouldSend(occurrenceId, now, ttl) then
				return { ok = true, status = "duplicate" }
			end
		end
	elseif not runtime.localDebounce:shouldSend(occurrenceId, now, ttl) then
		return { ok = true, status = "duplicate" }
	end

	local env = runtime.env
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
function Client.buildScheduleFromRegistry(_self: any, config: RegistryScanConfig): RoControlSchedule
	return Schedules.buildFromRegistry(config)
end

function Client.onFailedOperation(self: any, callback: (FailedOperation) -> ()): RBXScriptConnection
	return self._runtime.failedSignal:connect(callback)
end

function Client.retryFailedOperation(self: any, failed: any): OperationResult
	if self._destroyed then
		return {
			ok = false,
			status = "disabled",
			error = ErrorFactory.config("client has been destroyed"),
		}
	end
	if type(failed) ~= "table" or failed._route == nil or failed._payload == nil then
		return {
			ok = false,
			status = "failed",
			error = ErrorFactory.validation(
				"retryFailedOperation requires a FailedOperation from onFailedOperation"
			),
		}
	end

	local operation = failed.operation
	local metricSuffix = if operation == "registerSchedule"
		then {
			Metrics.Names.scheduleRegisterSuccess,
			Metrics.Names.scheduleRegisterFailure,
			Metrics.Names.scheduleRegisterAttempt,
		}
		else {
			Metrics.Names.eventReportSuccess,
			Metrics.Names.eventReportFailure,
			Metrics.Names.eventReportAttempt,
		}

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

-- Synchronous (yielding) read of the universe's upcoming Roblox virtual events.
-- Unlike registerSchedule/reportEvent (fire-and-forget through the queue), the
-- caller needs the data back, so this blocks on the HTTP round-trip. Call it
-- from a non-critical thread (e.g. a `task.spawn` after some gameplay), never on
-- a hot path. Network failures return `{ ok = false, error = ... }` rather than
-- raising, so a down backend can never crash gameplay code.
function Client.getUpcomingEvents(self: any): Types.UpcomingEventsResult
	local runtime = self._runtime
	if self._destroyed then
		return {
			ok = false,
			error = ErrorFactory.config("client has been destroyed"),
		}
	end

	runtime.metrics:count(Metrics.Names.upcomingFetchAttempt)
	local requestId = Uuid.requestId()
	local ok, result = pcall(function()
		return runtime.http:send("upcomingEvents", nil, { requestId = requestId })
	end)

	if not ok then
		self._lastFailureAt = runtime.clock:now()
		runtime.metrics:count(Metrics.Names.upcomingFetchFailure)
		return {
			ok = false,
			error = ErrorFactory.new("Unknown", "Read crashed: " .. tostring(result)),
		}
	end

	if not result.ok then
		self._lastFailureAt = runtime.clock:now()
		runtime.metrics:count(Metrics.Names.upcomingFetchFailure)
		return { ok = false, error = result.error }
	end

	self._lastSuccessAt = runtime.clock:now()
	runtime.metrics:count(Metrics.Names.upcomingFetchSuccess)

	local body = result.body
	if type(body) ~= "table" then
		return {
			ok = false,
			error = ErrorFactory.new("Server", "Malformed upcoming-events response"),
		}
	end

	return {
		ok = true,
		events = (body.events :: any) or {},
		active = body.active,
		-- Backend names the field `next`; expose it as `nextEvent` (Luau keyword).
		nextEvent = body.next,
		serverTime = body.serverTime,
		sourceError = body.sourceError,
	}
end

-- Convenience: the soonest event that hasn't started yet (the one to advertise),
-- falling back to a currently-active event, or nil if none / on failure.
function Client.getNextEvent(self: any): Types.RoControlUpcomingEvent?
	local result = self:getUpcomingEvents()
	if not result.ok then
		return nil
	end
	return result.nextEvent or result.active
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
