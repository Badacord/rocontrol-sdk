-- Verifies src/Metadata.luau and wally.toml agree, and (if a tag is passed)
-- that the git tag matches. Run with lune:  lune run scripts/check-version.luau [vX.Y.Z]

local fs = require("@lune/fs")
local process = require("@lune/process")

local function parse(path: string, pattern: string): string
	local content = fs.readFile(path)
	local value = string.match(content, pattern)
	assert(value, "could not parse version from " .. path)
	return value :: string
end

local metadataVersion = parse("src/Metadata.luau", 'version%s*=%s*"([^"]+)"')
local wallyVersion = parse("wally.toml", 'version%s*=%s*"([^"]+)"')

assert(
	metadataVersion == wallyVersion,
	string.format("wally.toml (%s) != Metadata.luau (%s)", wallyVersion, metadataVersion)
)

local tag = process.args[1]
if tag and tag ~= "" then
	local tagVersion = string.gsub(tag, "^v", "")
	assert(
		tagVersion == metadataVersion,
		string.format("git tag %s does not match Metadata.version %s", tag, metadataVersion)
	)
	print("version ok (tag matches): " .. metadataVersion)
else
	print("version ok: " .. metadataVersion)
end
