--!strict

--[[
	The stamp printed at startup and drawn on the HUD.

	STAMP is the real git short sha that Rojo is serving. It comes from
	BuildStamp, a gitignored module that scripts/stamp.sh writes (the git
	hooks from scripts/install-hooks.sh rerun it after every commit, merge,
	and checkout). A trailing "+" means src had uncommitted edits.

	"unstamped" means BuildStamp is missing: run `sh scripts/stamp.sh` in
	the repo Rojo serves. If Output shows a sha that is not `git log -1`
	there, Studio is not synced to this repo (Rojo plugin not connected).

	This module requires nothing else, so the entry scripts can print it
	before any other require.
]]

local Build = {}

Build.UNSTAMPED = "unstamped"

local function readStamp(): (string, string?)
	-- Roblox: a sibling ModuleScript. Lune (tests) has no `script`.
	local holder = if typeof(script) == "Instance" then script.Parent else nil
	local node = if holder ~= nil then holder:FindFirstChild("BuildStamp") else nil
	if node == nil or not node:IsA("ModuleScript") then
		return Build.UNSTAMPED, nil
	end
	local ok, data = pcall(require, node :: any)
	if not ok or type(data) ~= "table" or type(data.sha) ~= "string" then
		return Build.UNSTAMPED, nil
	end
	local sha = data.sha
	if not string.match(sha, "^%x+%+?$") then
		return Build.UNSTAMPED, nil
	end
	return sha, if type(data.at) == "string" then data.at else nil
end

local stamp, stampedAt = readStamp()
Build.STAMP = stamp
Build.AT = stampedAt

function Build.line(side: string): string
	return string.format("[Shardfall] build %s %s", Build.STAMP, side)
end

-- True for a real sha (optionally dirty), false for "unstamped".
function Build.valid(value: any): boolean
	return type(value) == "string" and string.match(value, "^%x+%+?$") ~= nil
end

return Build
