--!strict
-- Runtime environment facts (place id, version, job id, server vs client, studio).
-- Wrapped so the Client never reads engine singletons directly and tests can fake
-- the whole environment.

export type Environment = {
	isServer: boolean,
	isClient: boolean,
	isStudio: boolean,
	placeId: number,
	placeVersion: number,
	jobId: string,
}

local Env = {}

-- Reads the real Roblox environment. Guarded so it degrades gracefully if a
-- service is unavailable (e.g. inside a constrained test harness).
function Env.detect(): Environment
	local okRun, RunService = pcall(function()
		return game:GetService("RunService")
	end)

	local isServer = true
	local isClient = false
	local isStudio = false
	if okRun and RunService then
		isServer = RunService:IsServer()
		isClient = RunService:IsClient()
		isStudio = RunService:IsStudio()
	end

	local placeId = 0
	local placeVersion = 0
	local jobId = ""
	pcall(function()
		placeId = game.PlaceId
		placeVersion = game.PlaceVersion
		jobId = game.JobId
	end)

	return {
		isServer = isServer,
		isClient = isClient,
		isStudio = isStudio,
		placeId = placeId,
		placeVersion = placeVersion,
		jobId = jobId,
	}
end

return Env
