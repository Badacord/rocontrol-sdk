--!strict
-- Central registry of every endpoint the SDK may call. The HTTP client refuses
-- any route not listed here, so a typo can never become a request to an
-- unexpected URL, and retry/capability policy lives next to each route.

export type Route = {
	method: "GET" | "POST",
	path: string,
	idempotent: boolean,
	requiredCapability: string?,
}

local Routes: { [string]: Route } = {
	registerSchedule = {
		method = "POST",
		path = "/api/sdk/v1/schedules",
		idempotent = true,
		requiredCapability = "schedule:write",
	},
	reportEvent = {
		method = "POST",
		path = "/api/sdk/v1/events",
		idempotent = true,
		requiredCapability = "event:report",
	},
	health = {
		method = "GET",
		path = "/api/sdk/v1/health",
		idempotent = true,
		requiredCapability = nil,
	},
}

return table.freeze(Routes)
