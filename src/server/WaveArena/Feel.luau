--!strict

--[[
	Small-enemy juice. A hit flashes the body. A death leaves a puff.
	The boss uses the death hold instead of a puff.
]]

local WaveArenaConfig = require("../../ReplicatedStorage/Shared/Config/WaveArenaConfig")

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
