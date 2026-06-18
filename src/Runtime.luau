--!strict
-- Dependency container. Wires the resolved config to concrete (or injected)
-- collaborators and exposes them to the Client. Tests pass `overrides` to swap in
-- fakes (adapter, clock, env, signal, scheduler) with zero engine access.

local Metadata = require(script.Parent.Metadata)
local Config = require(script.Parent.Config)

local Logger = require(script.Parent.Logging.Logger)
local Metrics = require(script.Parent.Metrics.Metrics)
local Clock = require(script.Parent.Internal.Clock)
local Env = require(script.Parent.Internal.Env)
local Signal = require(script.Parent.Internal.Signal)
local Queue = require(script.Parent.Internal.Queue)

local HttpServiceAdapter = require(script.Parent.Internal.HttpServiceAdapter)
local MemoryStoreAdapter = require(script.Parent.Internal.MemoryStoreAdapter)
local HttpClient = require(script.Parent.Http.HttpClient)
local CircuitBreaker = require(script.Parent.Http.CircuitBreaker)
local Leases = require(script.Parent.Leases)

local Runtime = {}

export type Overrides = {
	adapter: any?,
	clock: any?,
	env: any?,
	signal: any?,
	circuit: any?,
	scheduler: ((() -> ()) -> ())?,
	logger: any?, -- consumer Logger sink
	metrics: any?, -- consumer MetricsSink
	memoryStore: any?, -- MemoryStoreAdapter fake
	leaseHashMap: any?, -- inject a fake lease hash map directly (tests)
}

-- Default async scheduler: prefer task.spawn, then task.defer, else run inline
-- (used under non-Roblox harnesses; tests usually inject a synchronous scheduler).
local function defaultScheduler(): (() -> ()) -> ()
	local taskLib: any = task :: any
	if taskLib ~= nil and taskLib.spawn ~= nil then
		return function(fn)
			taskLib.spawn(fn)
		end
	end
	return function(fn)
		fn()
	end
end

function Runtime.create(config: Config.ResolvedConfig, overrides: Overrides?)
	local o = overrides or {}

	local clock = o.clock or Clock.real()
	local env = o.env or Env.detect()
	local metrics = Metrics.new(o.metrics)

	local logger = Logger.new({
		level = config.logLevel,
		sink = o.logger,
		baseFields = {
			sdkVersion = Metadata.version,
			protocolVersion = Metadata.protocolVersion,
			placeId = env.placeId,
			placeVersion = env.placeVersion,
			jobId = env.jobId,
			isStudio = env.isStudio,
		},
	})

	local circuit = o.circuit
		or CircuitBreaker.new({
			failureThreshold = config.circuitBreakerFailureThreshold,
			cooldownSeconds = config.circuitBreakerCooldownSeconds,
		})
	circuit:onOpen(function()
		metrics:count(Metrics.Names.circuitOpen)
		logger:warn("circuit opened")
	end)
	circuit:onClose(function()
		metrics:count(Metrics.Names.circuitClose)
		logger:info("circuit closed")
	end)

	local adapter = o.adapter or HttpServiceAdapter.new()

	local httpClient = HttpClient.new({
		adapter = adapter,
		clock = clock,
		logger = logger,
		metrics = metrics,
		circuit = circuit,
		metadata = Metadata,
		env = env,
		config = {
			baseUrl = config.baseUrl,
			apiKey = config.apiKey,
			maxRetries = config.maxRetries,
			retryBaseDelaySeconds = config.retryBaseDelaySeconds,
			retryMaxDelaySeconds = config.retryMaxDelaySeconds,
		},
	})

	-- Lease infrastructure for imperative reporting (Phase 4). The hash map is
	-- fetched lazily and cached; a fake can be injected for tests.
	local memoryStore = o.memoryStore or MemoryStoreAdapter.new()
	local leaseMapName = "rocontrol:v1:" .. tostring(env.universeId) .. ":leases"
	local cachedLeaseHashMap = o.leaseHashMap
	local leaseHashMapResolved = o.leaseHashMap ~= nil
	local function getLeaseHashMap()
		if not leaseHashMapResolved then
			leaseHashMapResolved = true
			if memoryStore.available then
				cachedLeaseHashMap = memoryStore:getHashMap(leaseMapName)
			end
		end
		return cachedLeaseHashMap
	end

	return {
		config = config,
		metadata = Metadata,
		clock = clock,
		env = env,
		logger = logger,
		metrics = metrics,
		circuit = circuit,
		adapter = adapter,
		http = httpClient,
		failedSignal = o.signal or Signal.new(),
		scheduler = o.scheduler or defaultScheduler(),
		Queue = Queue,
		memoryStore = memoryStore,
		getLeaseHashMap = getLeaseHashMap,
		localDebounce = Leases.LocalDebounce.new(),
	}
end

return Runtime
