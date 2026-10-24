--!strict

--[[
	Small-enemy juice. A hit flashes the body. A death leaves a puff.
	The boss uses the death hold instead of a puff.
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

local Feel = {}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Feel.hitFlash(enemy: any, config: any?): any
	local cfg = cfgOf(config)
	return {
		kind = "hitFlash",
		id = enemy.uid,
		seconds = cfg.feel.hitFlash,
		x = enemy.x,
		z = enemy.z,
		color = cfg.feel.flashColor,
	}
end

function Feel.deathPuff(enemy: any, config: any?): any
	local cfg = cfgOf(config)
	return {
		kind = "deathPuff",
		id = enemy.uid,
		seconds = cfg.feel.deathPuff,
		x = enemy.x,
		z = enemy.z,
		color = cfg.feel.puffColor,
	}
end

return Feel
