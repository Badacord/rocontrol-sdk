--!strict
-- Thin, never-throws wrapper over the optional consumer MetricsSink. Metric names
-- are centralized here so they stay consistent across the codebase and docs.

local Types = require(script.Parent.Parent.Types)

type MetricsSink = Types.MetricsSink

local Metrics = {}
Metrics.__index = Metrics

-- Canonical metric names (see docs/troubleshooting.md and AGENTS.md).
Metrics.Names = table.freeze({
	init = "rocontrol.sdk.init",
	scheduleRegisterAttempt = "rocontrol.sdk.schedule.register.attempt",
	scheduleRegisterSuccess = "rocontrol.sdk.schedule.register.success",
	scheduleRegisterFailure = "rocontrol.sdk.schedule.register.failure",
	eventReportAttempt = "rocontrol.sdk.event.report.attempt",
	eventReportSuccess = "rocontrol.sdk.event.report.success",
	eventReportFailure = "rocontrol.sdk.event.report.failure",
	httpRetry = "rocontrol.sdk.http.retry",
	leaseWin = "rocontrol.sdk.lease.win",
	leaseLoss = "rocontrol.sdk.lease.loss",
	leaseError = "rocontrol.sdk.lease.error",
	circuitOpen = "rocontrol.sdk.circuit.open",
	circuitClose = "rocontrol.sdk.circuit.close",
	queueEnqueued = "rocontrol.sdk.queue.enqueued",
	queueDropped = "rocontrol.sdk.queue.dropped",
	moderationPending = "rocontrol.sdk.moderation.pending",
	moderationApproved = "rocontrol.sdk.moderation.approved",
	moderationRejected = "rocontrol.sdk.moderation.rejected",
	moderationFailed = "rocontrol.sdk.moderation.failed",
})

export type Metrics = {
	count: (self: Metrics, name: string, value: number?, tags: { [string]: string }?) -> (),
	timing: (self: Metrics, name: string, milliseconds: number, tags: { [string]: string }?) -> (),
}

function Metrics.new(sink: MetricsSink?): Metrics
	local self = setmetatable({ _sink = sink }, Metrics)
	return (self :: any) :: Metrics
end

function Metrics.count(self: any, name: string, value: number?, tags: { [string]: string }?)
	if self._sink == nil then
		return
	end
	pcall(function()
		self._sink:count(name, value or 1, tags)
	end)
end

function Metrics.timing(self: any, name: string, milliseconds: number, tags: { [string]: string }?)
	if self._sink == nil then
		return
	end
	pcall(function()
		self._sink:timing(name, milliseconds, tags)
	end)
end

return Metrics
