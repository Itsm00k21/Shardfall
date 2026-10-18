-- lune ops/studio-smoke/instrument.luau <srcRoot> <buildDir> <runId> [smokeDir]
-- Copies src/ into buildDir with button/key handlers routed through the
-- smoke shim, adds the smoke scripts, and writes smoke.project.json.
-- The repo itself is never modified.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local repo, out, runId = process.args[1], process.args[2], process.args[3] or "manual"
assert(repo and out, "usage: instrument.luau <repo> <buildDir> <runId>")
local here = process.args[4] or (repo .. "/ops/studio-smoke")

local SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "InputBegan", "InputEnded", "PromptTriggered", "Triggered" }
local stats = { files = 0, hooked = 0, missed = {}, cas = 0 }

local function transform(path, text)
	for _, sig in ipairs(SIGNALS) do
		for _, method in ipairs({ "Connect", "Once" }) do
			local pattern = "()([%a_][%w_%.]*)%." .. sig .. ":" .. method .. "%("
			local source = text
			text = source:gsub(pattern, function(pos, expr)
				local before = pos > 1 and source:sub(pos - 1, pos - 1) or ""
				if before:match("[%w_%.%]%):]") then
					table.insert(stats.missed, path .. " " .. expr .. "." .. sig)
					return nil
				end
				stats.hooked += 1
				return string.format('shared.__smk(%s, "%s"):%s(', expr, sig, method)
			end)
		end
	end
	local n
	text, n = text:gsub("ContextActionService:BindAction", "shared.__smkCas:BindAction")
	stats.cas += n
	return text
end

local function copyTree(src, dst)
	fs.writeDir(dst)
	for _, name in ipairs(fs.readDir(src)) do
		local s, d = src .. "/" .. name, dst .. "/" .. name
		if fs.isDir(s) then
			copyTree(s, d)
		elseif name:match("%.luau$") or name:match("%.lua$") then
			stats.files += 1
			local rel = s:sub(#repo + 2)
			local body = fs.readFile(s)
			if rel:find("StarterPlayerScripts/ShardfallClient", 1, true) then
				body = transform(rel, body)
			end
			fs.writeFile(d, body)
		else
			fs.writeFile(d, fs.readFile(s))
		end
	end
end

if fs.isDir(out) then
	fs.removeDir(out)
end
fs.writeDir(out)
copyTree(repo .. "/src", out .. "/src")

local clientDir = out .. "/src/StarterPlayer/StarterPlayerScripts/ShardfallClient"
fs.writeFile(clientDir .. "/SmokeShim.luau", fs.readFile(here .. "/SmokeShim.luau"))
local init = fs.readFile(clientDir .. "/init.client.luau")
local patched, hit = init:gsub('(print%("%[Shardfall%] build [^\n]*\n)', '%1require(script:WaitForChild("SmokeShim"))\n', 1)
assert(hit == 1, "could not find the build print in init.client.luau")
fs.writeFile(clientDir .. "/init.client.luau", patched)
-- Inside ShardfallServer/ShardfallClient so the foreign-script scan leaves them alone.
fs.writeFile(out .. "/src/ServerScriptService/ShardfallServer/StudioSmokeServer.server.luau", fs.readFile(here .. "/SmokeServer.server.luau"))
fs.writeFile(clientDir .. "/StudioSmokeClient.client.luau", fs.readFile(here .. "/SmokeClient.client.luau"))

local project = serde.decode("json", fs.readFile(repo .. "/default.project.json"))
project.name = "ShardfallSmoke"
project.tree.ServerStorage = project.tree.ServerStorage or { ["$className"] = "ServerStorage" }
project.tree.ServerStorage.StudioSmokeMarker = {
	["$className"] = "Configuration",
	["$attributes"] = { RunId = runId },
}
fs.writeFile(out .. "/smoke.project.json", serde.encode("json", project, true))

print(string.format("instrumented files=%d hooks=%d casBinds=%d missed=%d", stats.files, stats.hooked, stats.cas, #stats.missed))
for _, m in ipairs(stats.missed) do
	print("  not hooked: " .. m)
end
