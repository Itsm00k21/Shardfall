--!strict

--[[
	Both guards. The graybox builds only when both are on.

	1. LaunchGate.waveArena == true. A missing key is nil, and nil is not
	   true, so the flag stays off until Ghost adds it. This does not read
	   LaunchGate.SHOW and it does not call LaunchGate.on.
	2. WaveArenaConfig.enabled == true. Shipped as false.
]]

local LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")

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
	local waveArena = (gate :: any).waveArena
	return waveArena == true
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
