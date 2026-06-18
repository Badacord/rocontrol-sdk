--!strict
-- Static SDK identity. The package version is bumped by the release pipeline and
-- verified against the git tag in CI (see scripts/check-version.luau). The
-- protocol version is independent and only changes when the wire contract changes.

return table.freeze({
	name = "rocontrol-roblox-sdk",
	version = "0.2.0",
	protocolVersion = "sdk-v1",
})
