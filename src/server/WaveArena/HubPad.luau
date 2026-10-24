--!strict

--[[
	Shard Gate pad in the hub. The plan is nil unless both guards are on,
	so the pad is not created, prompted, or shown while the arena is off.
]]

-- Shared modules. Studio walks script to the server folder. Lune uses ./SharedRoot.
local SharedRequire
if game ~= nil and game.GetService ~= nil then
	local server = script:FindFirstAncestor("server")
	if server == nil then
		error("SharedRequire is not under server")
	end
	SharedRequire = require(server:WaitForChild("SharedRoot"))
else
	SharedRequire = require("./SharedRoot")
end

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
