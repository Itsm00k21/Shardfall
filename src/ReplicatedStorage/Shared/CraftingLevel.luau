--!strict

--[[
	Crafting Level 1–100.

	XP to the next level is 20 * level * (level + 5). It rises every level
	and stops at 100. A Forge Boost doubles XP while its timestamp is still
	ahead. Milestones sit on every 10th level. The profile stores the earned
	levels and a copy of this table.
]]

local CraftingLevel = {}

CraftingLevel.MAX = 100

export type Milestone = {
	level: number,
	tier: number,
	rollBias: number,
	rarityUp: number,
	masterwork: number,
	note: string,
}

export type Bonuses = {
	tier: number,
	rollBias: number,
	rarityUp: number,
	masterwork: number,
}

-- Tier 1 is the six basic weapons. Tier 2 opens at level 10 (Thornbound).
CraftingLevel.MILESTONES = {
	{
		level = 10,
		tier = 2,
		rollBias = 0.02,
		rarityUp = 0,
		masterwork = 0,
		note = "Tier 2 recipes and +2% roll quality",
	},
	{
		level = 20,
		tier = 2,
		rollBias = 0.04,
		rarityUp = 0,
		masterwork = 0,
		note = "Stronger roll quality",
	},
	{
		level = 30,
		tier = 2,
		rollBias = 0.06,
		rarityUp = 0.02,
		masterwork = 0,
		note = "2% chance a craft gains one rarity",
	},
	{
		level = 40,
		tier = 3,
		rollBias = 0.08,
		rarityUp = 0.02,
		masterwork = 0,
		note = "Tier 3 recipes",
	},
	{
		level = 50,
		tier = 3,
		rollBias = 0.1,
		rarityUp = 0.02,
		masterwork = 0.05,
		note = "5% Masterwork extra stat",
	},
	{
		level = 60,
		tier = 4,
		rollBias = 0.12,
		rarityUp = 0.02,
		masterwork = 0.05,
		note = "Tier 4 recipes",
	},
	{
		level = 70,
		tier = 4,
		rollBias = 0.14,
		rarityUp = 0.04,
		masterwork = 0.05,
		note = "4% rarity-up",
	},
	{
		level = 80,
		tier = 4,
		rollBias = 0.16,
		rarityUp = 0.04,
		masterwork = 0.1,
		note = "10% Masterwork",
	},
	{
		level = 90,
		tier = 5,
		rollBias = 0.18,
		rarityUp = 0.04,
		masterwork = 0.1,
		note = "Tier 5 recipes",
	},
	{
		level = 100,
		tier = 5,
		rollBias = 0.2,
		rarityUp = 0.04,
		masterwork = 0.15,
		note = "Grandmaster Smith",
	},
} :: { Milestone }

CraftingLevel.CRAFT_XP = { 24, 48, 80, 120, 180 }

CraftingLevel.SALVAGE_XP = {
	Common = 8,
	Uncommon = 12,
	Rare = 20,
	Epic = 36,
	Legendary = 56,
	Mythic = 80,
	Secret = 80,
}

function CraftingLevel.xpToNext(level: number): number
	local whole = math.floor(level)
	if whole ~= whole or whole < 1 then
		whole = 1
	end
	if whole >= CraftingLevel.MAX then
		return 0
	end
	return 20 * whole * (whole + 5)
end

function CraftingLevel.bonusesAt(level: number): Bonuses
	local whole = math.floor(level)
	if whole ~= whole or whole < 1 then
		whole = 1
	end
	local bonuses: Bonuses = {
		tier = 1,
		rollBias = 0,
		rarityUp = 0,
		masterwork = 0,
	}
	for _, row in ipairs(CraftingLevel.MILESTONES) do
		if whole >= row.level then
			bonuses = {
				tier = row.tier,
				rollBias = row.rollBias,
				rarityUp = row.rarityUp,
				masterwork = row.masterwork,
			}
		end
	end
	return bonuses
end

function CraftingLevel.craftXp(tier: number): number
	local index = math.floor(tier)
	if index < 1 then
		index = 1
	end
	local amount = CraftingLevel.CRAFT_XP[index]
	if amount == nil then
		return CraftingLevel.CRAFT_XP[#CraftingLevel.CRAFT_XP]
	end
	return amount
end

function CraftingLevel.salvageXp(rarity: string): number
	local amount = CraftingLevel.SALVAGE_XP[rarity]
	if amount == nil then
		return CraftingLevel.SALVAGE_XP.Common
	end
	return amount
end

function CraftingLevel.multiplier(boostUntil: any, now: number): number
	local untilTime = boostUntil
	if type(untilTime) ~= "number" or untilTime ~= untilTime or untilTime <= 0 then
		return 1
	end
	if type(now) ~= "number" or now ~= now then
		return 1
	end
	if now < untilTime then
		return 2
	end
	return 1
end

local function earnedLevels(level: number): { number }
	local earned = {}
	for _, row in ipairs(CraftingLevel.MILESTONES) do
		if level >= row.level then
			table.insert(earned, row.level)
		end
	end
	return earned
end

-- Plain rows for the profile. Reconcile refreshes this from the module.
function CraftingLevel.copyTable(): { Milestone }
	local rows = {}
	for _, row in ipairs(CraftingLevel.MILESTONES) do
		table.insert(rows, {
			level = row.level,
			tier = row.tier,
			rollBias = row.rollBias,
			rarityUp = row.rarityUp,
			masterwork = row.masterwork,
			note = row.note,
		})
	end
	return rows
end

-- Adds crafting XP. Returns the XP that landed and how many levels were gained.
function CraftingLevel.grant(profile: any, baseAmount: number, now: number): (number, number)
	if type(profile) ~= "table" then
		return 0, 0
	end
	local level = profile.craftingLevel
	if type(level) ~= "number" or level < 1 then
		level = 1
	end
	level = math.floor(level)
	if level > CraftingLevel.MAX then
		level = CraftingLevel.MAX
	end
	local xp = profile.craftingXp
	if type(xp) ~= "number" or xp ~= xp or xp < 0 then
		xp = 0
	end
	xp = math.floor(xp)
	if level >= CraftingLevel.MAX then
		profile.craftingLevel = CraftingLevel.MAX
		profile.craftingXp = 0
		profile.craftingMilestones = earnedLevels(CraftingLevel.MAX)
		return 0, 0
	end
	local amount = math.floor(baseAmount)
	if amount < 0 or amount ~= amount then
		amount = 0
	end
	amount = math.floor(amount * CraftingLevel.multiplier(profile.forgeBoostUntil, now))
	xp += amount
	local gained = 0
	while level < CraftingLevel.MAX and xp >= CraftingLevel.xpToNext(level) and gained < 100 do
		xp -= CraftingLevel.xpToNext(level)
		level += 1
		gained += 1
	end
	if level >= CraftingLevel.MAX then
		level = CraftingLevel.MAX
		xp = 0
	end
	profile.craftingLevel = level
	profile.craftingXp = xp
	profile.craftingMilestones = earnedLevels(level)
	return amount, gained
end

for _, row in ipairs(CraftingLevel.MILESTONES) do
	table.freeze(row)
end
table.freeze(CraftingLevel.MILESTONES)
table.freeze(CraftingLevel.CRAFT_XP)
table.freeze(CraftingLevel.SALVAGE_XP)

return CraftingLevel
