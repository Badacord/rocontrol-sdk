--!strict
-- Single source of truth for every public type. `init.luau` re-exports these so
-- consumers can write `RoControl.RoControlClient` etc. with full intellisense.
--
-- This module intentionally exports only types and an empty runtime table.

export type LogLevel = "silent" | "error" | "warn" | "info" | "debug"

export type LogFields = { [string]: any }

export type Logger = {
	log: (self: Logger, level: LogLevel, message: string, fields: LogFields?) -> (),
}

export type MetricsSink = {
	count: (self: MetricsSink, name: string, value: number?, tags: { [string]: string }?) -> (),
	timing: (
		self: MetricsSink,
		name: string,
		milliseconds: number,
		tags: { [string]: string }?
	) -> (),
}

export type InitConfig = {
	apiKey: string,
	baseUrl: string?,
	logger: Logger?,
	logLevel: LogLevel?,
	metrics: MetricsSink?,
	httpTimeoutSeconds: number?,
	maxRetries: number?,
	retryBaseDelaySeconds: number?,
	retryMaxDelaySeconds: number?,
	circuitBreakerFailureThreshold: number?,
	circuitBreakerCooldownSeconds: number?,
	enableMemoryStoreLease: boolean?,
	studioMode: boolean?,
}

export type RoControlEvent = {
	key: string,
	label: string?,
	iconAssetId: string?,
	durationSeconds: number,
	priority: number?,
	metadata: { [string]: any }?,
}

export type ScheduleRotation =
	{ kind: "sequential" }
	| { kind: "weighted", algorithm: "mulberry32-fnv1a32" }

export type RoControlSchedule = {
	key: string,
	timezone: "UTC",
	cycleSeconds: number,
	eventDurationSeconds: number,
	startsAtUnix: number?,
	rotation: ScheduleRotation,
	events: { RoControlEvent },
	metadata: { [string]: any }?,
}

export type ReportEventInput = {
	key: string,
	label: string?,
	iconAssetId: string?,
	startedAt: number?,
	durationSeconds: number?,
	priority: number?,
	occurrenceId: string?,
	metadata: { [string]: any }?,
}

export type OperationStatus =
	"sent"
	| "queued"
	| "skipped"
	| "duplicate"
	| "disabled"
	| "failed"
	| "circuit_open"

export type ErrorKind =
	"Auth"
	| "RateLimit"
	| "Validation"
	| "Transport"
	| "Server"
	| "Timeout"
	| "Config"
	| "MemoryStore"
	| "CircuitOpen"
	| "Unknown"

export type RoControlError = {
	kind: ErrorKind,
	message: string,
	retryable: boolean,
	statusCode: number?,
	requestId: string?,
	cause: any?,
}

export type OperationResult = {
	ok: boolean,
	status: OperationStatus,
	requestId: string?,
	error: RoControlError?,
}

export type HealthStatus = {
	initialized: boolean,
	circuitOpen: boolean,
	lastSuccessAt: number?,
	lastFailureAt: number?,
	pendingRequests: number,
	sdkVersion: string,
}

export type FailedOperation = {
	operation: "registerSchedule" | "reportEvent",
	status: "failed" | "dropped" | "circuit_open",
	requestId: string?,
	error: RoControlError,
	nextRetryAt: number?,
	payloadHash: string?,
	occurrenceIdHash: string?,
}

export type RegistryScanConfig = {
	folder: Instance,
	defaultDurationSeconds: number?,
	defaultPriority: number?,
	readAttributes: boolean?,
}

export type RoControlClient = {
	registerSchedule: (self: RoControlClient, descriptor: RoControlSchedule) -> OperationResult,
	reportEvent: (self: RoControlClient, input: ReportEventInput) -> OperationResult,
	buildScheduleFromRegistry: (
		self: RoControlClient,
		config: RegistryScanConfig
	) -> RoControlSchedule,
	onFailedOperation: (
		self: RoControlClient,
		callback: (failed: FailedOperation) -> ()
	) -> RBXScriptConnection,
	retryFailedOperation: (self: RoControlClient, failed: FailedOperation) -> OperationResult,
	getHealth: (self: RoControlClient) -> HealthStatus,
	flush: (self: RoControlClient) -> (),
	destroy: (self: RoControlClient) -> (),
}

return {}
