--!strict

--[[
	Both guards. Nothing builds unless both are on.

	1. LaunchGate.waveArena == true. The live switch is SHOW.waveArena
	   (Phase 0.1, default false). A direct field of the same name is the
	   graybox alias. A missing key is nil, and nil is off.
	2. WaveArenaConfig.enabled == true. Shipped as false.
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

local LaunchGate = SharedRequire.module("LaunchGate")
local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")

local Gate = {}

function Gate.waveArenaOn(launchGate: any): boolean
	local gate = launchGate
	if gate == nil then
		gate = LaunchGate
	end
	if typeof(gate) ~= "table" then
		return false
	end
	-- LaunchGate.waveArena == true. A missing key is nil, which is off.
	-- SHOW.waveArena is the same switch on the live module.
	if (gate :: any).waveArena == true then
		return true
	end
	local show = (gate :: any).SHOW
	if typeof(show) == "table" and show.waveArena == true then
		return true
	end
	return false
end

function Gate.configOn(config: any): boolean
	local cfg = if config == nil then WaveArenaConfig else config
	if typeof(cfg) ~= "table" then
		return false
	end
	return cfg.enabled == true
end

function Gate.open(launchGate: any, config: any): boolean
	return Gate.waveArenaOn(launchGate) and Gate.configOn(config)
end

return Gate
