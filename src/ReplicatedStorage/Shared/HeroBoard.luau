--!strict

--[[
	Hero-tab numbers. Power is a score from the equipped loadout.
	Each bar is that stat divided by a fixed cap, clamped to 0..1.
]]

local CombatMath = require("./CombatMath")

local HeroBoard = {}

HeroBoard.CAPS = {
	damage = 200,
	health = 500,
	defense = 100,
}

export type Bar = {
	id: string,
	label: string,
	fill: number,
}

local function fill(value: number, cap: number): number
	if value ~= value or value < 0 or cap <= 0 then
		return 0
	end
	return math.clamp(value / cap, 0, 1)
end

function HeroBoard.power(profile: any): number
	local offense, vitality = CombatMath.loadout(profile)
	local score = offense.damage * 2 + vitality.maxHealth * 0.15 + vitality.defense * 3
	if score ~= score or score < 0 then
		return 0
	end
	return math.floor(score + 0.5)
end

function HeroBoard.bars(profile: any): { Bar }
	local offense, vitality = CombatMath.loadout(profile)
	return {
		{
			id = "damage",
			label = string.format("Damage  %d", math.floor(offense.damage + 0.5)),
			fill = fill(offense.damage, HeroBoard.CAPS.damage),
		},
		{
			id = "health",
			label = string.format("HP  %d", vitality.maxHealth),
			fill = fill(vitality.maxHealth, HeroBoard.CAPS.health),
		},
		{
			id = "defense",
			label = string.format("Defense  %d", vitality.defense),
			fill = fill(vitality.defense, HeroBoard.CAPS.defense),
		},
	}
end

return HeroBoard
