--!strict

--[[
	Shard Gate pad in the hub. The plan is nil unless both guards are on,
	so the pad is not created, prompted, or shown while the arena is off.
]]

local function sharedRoot()
	if game ~= nil and game.GetService ~= nil then
		local folder = script.Parent
		if folder ~= nil and folder.Name == "server" then
			return require(folder:WaitForChild("SharedRequire"))
		end
		if folder ~= nil and folder.Parent ~= nil then
			return require(folder.Parent:WaitForChild("SharedRequire"))
		end
		error("SharedRequire is not beside this module")
	end
	local source = debug.info(1, "s")
	local marker = "src/server/"
	local at = string.find(source, marker, 1, true)
	if at == nil then
		error("SharedRequire could not see src/server in " .. source)
	end
	local rest = string.sub(source, at + #marker)
	local _, slashes = string.gsub(rest, "/", "")
	if slashes == 0 then
		return require("./SharedRequire")
	end
	local prefix = ""
	local parent = string.char(46, 46)
	for _ = 1, slashes do
		prefix ..= parent .. "/"
	end
	return require(prefix .. "SharedRequire")
end

local SharedRequire = sharedRoot()

local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")
local Gate = require("./Gate")

local HubPad = {}

function HubPad.plan(launchGate: any, config: any?): any
	if not Gate.open(launchGate, config) then
		return nil
	end
	local cfg = if config == nil then WaveArenaConfig else config
	local pad = cfg.hubPad
	local origin = cfg.arena.origin
	return {
		name = "ShardGate",
		shape = "Block",
		size = pad.size,
		position = { pad.position.x, pad.position.y, pad.position.z },
		color = pad.color,
		canCollide = false,
		prompt = pad.prompt,
		actionText = pad.actionText,
		-- Feet sit just above the arena floor. The fight itself is arena-local.
		destination = { origin.x, origin.y + 3, origin.z },
	}
end

return HubPad
