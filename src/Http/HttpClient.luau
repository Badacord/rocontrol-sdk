--!strict
-- Performs a single logical RoControl request: builds headers + metadata, sends
-- through the injected adapter, classifies the response, and retries idempotent
-- operations with backoff + jitter while respecting the circuit breaker.
--
-- This layer is intentionally synchronous (it may yield via clock:sleep). The
-- Client schedules it off the gameplay path through the queue/runtime.

local Types = require(script.Parent.Parent.Types)
local Routes = require(script.Parent.Routes)
local Retry = require(script.Parent.Retry)
local ResponseClassifier = require(script.Parent.ResponseClassifier)
local Metrics = require(script.Parent.Parent.Metrics.Metrics)
local ErrorFactory = require(script.Parent.Parent.Errors)
local Uuid = require(script.Parent.Parent.Internal.Uuid)

type RoControlError = Types.RoControlError

local HttpClient = {}
HttpClient.__index = HttpClient

export type SendOptions = {
	idempotencyKey: string?,
	requestId: string?,
}

export type SendResult = {
	ok: boolean,
	statusCode: number?,
	requestId: string,
	error: RoControlError?,
	body: any?,
}

-- `deps` carries every collaborator so the client is fully testable.
export type Deps = {
	adapter: any, -- HttpServiceAdapter.HttpAdapter
	clock: any, -- Clock.Clock
	logger: any, -- Logger.StructuredLogger
	metrics: Metrics.Metrics,
	circuit: any, -- CircuitBreaker.CircuitBreaker
	metadata: { name: string, version: string, protocolVersion: string },
	env: any, -- Env.Environment
	config: {
		baseUrl: string,
		apiKey: string,
		maxRetries: number,
		retryBaseDelaySeconds: number,
		retryMaxDelaySeconds: number,
	},
}

function HttpClient.new(deps: Deps)
	local self = setmetatable({ _deps = deps }, HttpClient)
	return self
end

local function buildHeaders(deps: Deps, requestId: string, options: SendOptions): { [string]: string }
	local headers: { [string]: string } = {
		["Authorization"] = "Bearer " .. deps.config.apiKey,
		["Content-Type"] = "application/json",
		["RoControl-SDK-Version"] = deps.metadata.version,
		["RoControl-Protocol-Version"] = deps.metadata.protocolVersion,
		["RoControl-Place-Id"] = tostring(deps.env.placeId),
		["RoControl-Place-Version"] = tostring(deps.env.placeVersion),
		["RoControl-Job-Id"] = deps.env.jobId,
		["RoControl-Is-Studio"] = tostring(deps.env.isStudio),
		["RoControl-Request-Id"] = requestId,
	}
	if options.idempotencyKey ~= nil then
		headers["Idempotency-Key"] = options.idempotencyKey
	end
	return headers
end

-- Sends to a named route. `payload` is JSON-encoded for write methods.
function HttpClient.send(self: any, routeName: string, payload: any?, options: SendOptions?): SendResult
	local deps: Deps = self._deps
	local opts: SendOptions = options or {}
	local requestId = opts.requestId or Uuid.requestId()

	local route = Routes[routeName]
	if route == nil then
		-- Hard guardrail: never send to an unregistered route.
		return {
			ok = false,
			requestId = requestId,
			error = ErrorFactory.config("Unknown route: " .. tostring(routeName)),
		}
	end

	local log = deps.logger:child({ route = routeName, requestId = requestId, operation = routeName })
	local url = deps.config.baseUrl .. route.path
	local headers = buildHeaders(deps, requestId, opts)
	local body: string? = nil
	if route.method ~= "GET" and payload ~= nil then
		body = deps.adapter:encode(payload)
	end

	local backoff: Retry.BackoffConfig = {
		baseDelaySeconds = deps.config.retryBaseDelaySeconds,
		maxDelaySeconds = deps.config.retryMaxDelaySeconds,
	}

	local lastError: RoControlError? = nil
	-- attempt 0 is the first try; up to maxRetries additional attempts.
	for attempt = 0, deps.config.maxRetries do
		local now = deps.clock:now()
		if not deps.circuit:canRequest(now) then
			log:warn("circuit open, skipping request", { attempt = attempt })
			return {
				ok = false,
				requestId = requestId,
				error = ErrorFactory.new("CircuitOpen", "Circuit breaker is open", { requestId = requestId }),
			}
		end

		local startedAt = deps.clock:monotonic()
		local response = deps.adapter:request({
			method = route.method,
			url = url,
			headers = headers,
			body = body,
		})
		local elapsedMs = (deps.clock:monotonic() - startedAt) * 1000

		local classification = ResponseClassifier.classify(response)
		if classification.ok then
			deps.circuit:recordSuccess()
			log:debug("request ok", { attempt = attempt, statusCode = response.statusCode, durationMs = elapsedMs })
			return {
				ok = true,
				statusCode = response.statusCode,
				requestId = requestId,
				body = deps.adapter:decode(response.body),
			}
		end

		local err = classification.error :: RoControlError
		lastError = err
		log:warn("request failed", {
			attempt = attempt,
			statusCode = err.statusCode,
			errorKind = err.kind,
			durationMs = elapsedMs,
		})

		local canRetry = err.retryable and route.idempotent and attempt < deps.config.maxRetries
		if not canRetry then
			-- Only count transport/server-class failures against the breaker.
			if err.retryable then
				deps.circuit:recordFailure(deps.clock:now())
			end
			return { ok = false, statusCode = err.statusCode, requestId = requestId, error = err }
		end

		deps.circuit:recordFailure(deps.clock:now())
		deps.metrics:count(Metrics.Names.httpRetry, 1, { route = routeName, kind = err.kind })
		local wait = Retry.nextWait(attempt, backoff, ResponseClassifier.retryAfterSeconds(response))
		deps.clock:sleep(wait)
	end

	return {
		ok = false,
		requestId = requestId,
		error = lastError or ErrorFactory.new("Unknown", "Request failed", { requestId = requestId }),
	}
end

return HttpClient
