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

-- Hero sheet redesign (A1): eight stat tiles, an identity header and a skill
-- grid. Values come from the same loadout the old stat sheet read; only the
-- layout changed.
export type Tile = { id: string, label: string, value: string, art: string }

function HeroBoard.tiles(profile: any): { Tile }
	local offense, vitality, goldFind = CombatMath.loadout(profile)
	local level = if type(profile) == "table" and type(profile.level) == "number"
		then profile.level
		else 1
	return {
		{
			id = "damage",
			label = "Damage",
			value = tostring(math.floor(offense.damage + 0.5)),
			art = "SkillAttack",
		},
		{ id = "health", label = "HP", value = tostring(vitality.maxHealth), art = "SkillHeal" },
		{
			id = "defense",
			label = "Defense",
			value = tostring(vitality.defense),
			art = "SkillWard",
		},
		{
			id = "attackSpeed",
			label = "Attack speed",
			value = string.format("%.2f", offense.attackSpeed),
			art = "SkillDodge",
		},
		{
			id = "crit",
			label = "Crit",
			value = string.format("%.0f%%", offense.critChance * 100),
			art = "SkillSpell",
		},
		{
			id = "critDamage",
			label = "Crit damage",
			value = string.format("%.2f", offense.critDamage),
			art = "SkillHeavy",
		},
		{
			id = "goldFind",
			label = "Gold find",
			value = string.format("%.0f%%", goldFind * 100),
			art = "Gold",
		},
		{ id = "level", label = "Level", value = tostring(math.floor(level)), art = "Shards" },
	}
end

export type Sheet = {
	wide: boolean,
	headerH: number,
	crest: number,
	avatarW: number,
	statCols: number,
	tileW: number,
	tileH: number,
	skillCols: number,
	skillW: number,
	skillH: number,
}

HeroBoard.GAP = 8

-- Layout for a hero page `width` px wide. Wide (desktop) shows 4 stat
-- columns and the whole skill kit in one row; narrow (phone) shows 2 and 3.
function HeroBoard.sheet(width: number): Sheet
	local w = if type(width) == "number" and width == width then math.max(200, width) else 264
	local wide = w >= 480
	local gap = HeroBoard.GAP
	local statCols = if wide then 4 else 2
	local skillCols = if wide then 5 else 3
	return {
		wide = wide,
		headerH = if wide then 140 else 132,
		crest = if wide then 72 else 48,
		avatarW = if wide then 150 else 72,
		statCols = statCols,
		tileW = math.floor((w - gap * (statCols - 1)) / statCols),
		tileH = 64,
		skillCols = skillCols,
		skillW = math.floor((w - gap * (skillCols - 1)) / skillCols),
		skillH = if wide then 112 else 96,
	}
end

return HeroBoard
