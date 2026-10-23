--!strict

--[[
	Ground loot. A kill leaves a chip where the body fell. Walking inside
	the pickup radius takes it. The wave purse is tokens from the economy
	sheet, added when that wave is swept, and it never touches a profile.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")

local Loot = {}

export type Payload = {
	dropId: string,
	fragments: number,
	tokens: number,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Loot.payload(kind: string, config: any?): Payload
	local cfg = cfgOf(config)
	local drops = cfg.loot.drops
	local row = drops[kind]
	if typeof(row) ~= "table" then
		row = drops.chaser
	end
	return {
		dropId = row.id,
		fragments = row.fragments or 0,
		tokens = row.tokens or 0,
	}
end

function Loot.purse(waveIndex: number, config: any?): number
	local cfg = cfgOf(config)
	local list = cfg.loot.waveTokens
	local amount = list[waveIndex]
	if typeof(amount) ~= "number" or amount ~= amount then
		return 0
	end
	return amount
end

function Loot.near(px: number, pz: number, drop: any, radius: number): boolean
	local dx = px - drop.x
	local dz = pz - drop.z
	return dx * dx + dz * dz <= radius * radius
end

function Loot.take(earned: any, drop: any)
	earned.tokens += drop.tokens or 0
	earned.fragments += drop.fragments or 0
	table.insert(earned.drops, {
		id = drop.dropId,
		tokens = drop.tokens or 0,
		fragments = drop.fragments or 0,
		wave = drop.wave,
	})
end

return Loot
