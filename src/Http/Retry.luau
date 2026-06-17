--!strict
-- Exponential backoff with full jitter. Pure functions so the math is unit-tested
-- without any timing. `randomFn` is injectable for deterministic tests.

local Retry = {}

export type BackoffConfig = {
	baseDelaySeconds: number,
	maxDelaySeconds: number,
}

-- Full jitter: delay = random(0, min(max, base * 2^attempt)).
-- `attempt` is zero-based (0 = first retry).
function Retry.computeDelay(
	attempt: number,
	config: BackoffConfig,
	randomFn: (() -> number)?
): number
	local rand = randomFn or math.random
	local exponential = config.baseDelaySeconds * (2 ^ attempt)
	local capped = math.min(config.maxDelaySeconds, exponential)
	return rand() * capped
end

-- Decides the effective wait before the next attempt, honoring a server-provided
-- Retry-After (which always wins, capped to maxDelay).
function Retry.nextWait(
	attempt: number,
	config: BackoffConfig,
	retryAfterSeconds: number?,
	randomFn: (() -> number)?
): number
	if retryAfterSeconds ~= nil then
		return math.min(retryAfterSeconds, config.maxDelaySeconds)
	end
	return Retry.computeDelay(attempt, config, randomFn)
end

return Retry
