--!strict
-- Simple three-state circuit breaker. After `failureThreshold` consecutive
-- retryable failures the circuit opens for `cooldownSeconds`; the next attempt
-- after cooldown is a half-open probe that closes the circuit on success.

export type CircuitState = "closed" | "open" | "half_open"

export type CircuitBreaker = {
	state: (self: CircuitBreaker, now: number) -> CircuitState,
	canRequest: (self: CircuitBreaker, now: number) -> boolean,
	recordSuccess: (self: CircuitBreaker) -> (),
	recordFailure: (self: CircuitBreaker, now: number) -> (),
	onOpen: (self: CircuitBreaker, callback: () -> ()) -> (),
	onClose: (self: CircuitBreaker, callback: () -> ()) -> (),
}

local CircuitBreaker = {}
CircuitBreaker.__index = CircuitBreaker

export type Config = {
	failureThreshold: number,
	cooldownSeconds: number,
}

function CircuitBreaker.new(config: Config): CircuitBreaker
	local self = setmetatable({
		_threshold = math.max(1, config.failureThreshold),
		_cooldown = math.max(1, config.cooldownSeconds),
		_failures = 0,
		_openedAt = nil :: number?,
		_onOpen = nil :: (() -> ())?,
		_onClose = nil :: (() -> ())?,
	}, CircuitBreaker)
	return (self :: any) :: CircuitBreaker
end

function CircuitBreaker.state(self: any, now: number): CircuitState
	if self._openedAt == nil then
		return "closed"
	end
	if now - self._openedAt >= self._cooldown then
		return "half_open"
	end
	return "open"
end

function CircuitBreaker.canRequest(self: any, now: number): boolean
	return self:state(now) ~= "open"
end

function CircuitBreaker.recordSuccess(self: any)
	local wasOpen = self._openedAt ~= nil
	self._failures = 0
	self._openedAt = nil
	if wasOpen and self._onClose then
		self._onClose()
	end
end

function CircuitBreaker.recordFailure(self: any, now: number)
	self._failures += 1
	if self._failures >= self._threshold and self._openedAt == nil then
		self._openedAt = now
		if self._onOpen then
			self._onOpen()
		end
	elseif self._openedAt ~= nil then
		-- A failed half-open probe re-opens the window from now.
		self._openedAt = now
	end
end

function CircuitBreaker.onOpen(self: any, callback: () -> ())
	self._onOpen = callback
end

function CircuitBreaker.onClose(self: any, callback: () -> ())
	self._onClose = callback
end

return CircuitBreaker
