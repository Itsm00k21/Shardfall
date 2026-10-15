--!strict

--[[
	Gear stat ranges, rarity scaling, and roll quality.

	A base lists each stat as min/max at scale 1 (Common, no class weight).
	The roll multiplies both ends by the rarity scale and by a class weight,
	then picks a value inside that range. Quality is how close those rolls
	sat to the top of the range: 0% is all minimums, 100% is all maximums.
	It is not a comparison against a higher rarity.

	CLASS_WEIGHTS is the hook for a future class system. Every weight is 1,
	so class does not change a roll yet. A class will edit this table.
	Weapon type tags live on the item (`sword`, `bow`, `staff`, `dagger`,
	`hammer`). Rolls already multiply by the weight for that type. Pets pass
	the weight key `pet`, which is also all 1s. That key is not stored as a
	weapon type on the item.
]]

local Rarities = require("./Rarities")

local Stats = {}

export type Range = {
	id: string,
	min: number,
	max: number,
}

export type RolledStat = {
	id: string,
	name: string,
	value: number,
	min: number,
	max: number,
	unit: string,
	roll: number,
	baseValue: number?,
}

export type StatDefinition = {
	name: string,
	unit: "flat" | "percent" | "multiplier",
	decimals: number,
}

Stats.DEFS = {
	damage = { name = "Damage", unit = "flat", decimals = 0 },
	attack_speed = { name = "Attack Speed", unit = "multiplier", decimals = 2 },
	crit_chance = { name = "Crit Chance", unit = "percent", decimals = 1 },
	crit_damage = { name = "Crit Damage", unit = "multiplier", decimals = 2 },
	health = { name = "HP", unit = "flat", decimals = 0 },
	defense = { name = "Defense", unit = "flat", decimals = 0 },
	pet_damage = { name = "Pet Damage", unit = "flat", decimals = 0 },
	pet_health = { name = "Pet HP", unit = "flat", decimals = 0 },
} :: { [string]: StatDefinition }

-- PLACEHOLDER. Both ends of the authored range are multiplied by this.
Stats.RARITY_SCALE = {
	Common = 1,
	Uncommon = 1.15,
	Rare = 1.35,
	Epic = 1.6,
	Legendary = 1.95,
	Mythic = 2.4,
	Secret = 3,
}

Stats.WEAPON_TYPES = { "sword", "bow", "staff", "dagger", "hammer" }

-- Future class system. Not tuned. 1 means "no class is applied".
-- Each weapon type has its own row so a class can raise sword damage
-- without changing bows. Rolls already multiply by these numbers.
local function neutralWeights(): { [string]: number }
	return {
		damage = 1,
		attack_speed = 1,
		crit_chance = 1,
		crit_damage = 1,
		health = 1,
		defense = 1,
		pet_damage = 1,
		pet_health = 1,
	}
end

Stats.CLASS_WEIGHTS = {
	sword = neutralWeights(),
	bow = neutralWeights(),
	staff = neutralWeights(),
	dagger = neutralWeights(),
	hammer = neutralWeights(),
	pet = neutralWeights(),
} :: { [string]: { [string]: number } }

function Stats.classWeight(weaponType: any, statId: string): number
	if type(weaponType) ~= "string" then
		return 1
	end
	local row = Stats.CLASS_WEIGHTS[weaponType]
	if type(row) ~= "table" then
		return 1
	end
	local weight = row[statId]
	if type(weight) ~= "number" or weight ~= weight or weight <= 0 then
		return 1
	end
	return weight
end

function Stats.scaledBounds(
	minValue: number,
	maxValue: number,
	rarity: string,
	weight: number
): (number, number)
	local scale = Stats.RARITY_SCALE[rarity]
	if scale == nil then
		error("Unknown rarity '" .. tostring(rarity) .. "'", 2)
	end
	if minValue > maxValue then
		error("Stat min is above max", 2)
	end
	local applied = weight
	if type(applied) ~= "number" or applied ~= applied or applied <= 0 then
		applied = 1
	end
	return minValue * scale * applied, maxValue * scale * applied
end

function Stats.rollPercent(value: number, minValue: number, maxValue: number): number
	local span = maxValue - minValue
	if span <= 0 then
		return 1
	end
	local percent = (value - minValue) / span
	if percent < 0 then
		return 0
	end
	if percent > 1 then
		return 1
	end
	return percent
end

function Stats.qualityOf(rolls: { number }): number
	if #rolls == 0 then
		return 1
	end
	local total = 0
	for _, roll in ipairs(rolls) do
		total += roll
	end
	return total / #rolls
end

function Stats.formatQuality(quality: number): string
	local percent = quality * 100
	if percent ~= percent then
		percent = 0
	end
	local rounded = math.floor(percent + 0.5)
	if rounded < 0 then
		rounded = 0
	elseif rounded > 100 then
		rounded = 100
	end
	return string.format("%d%%", rounded)
end

function Stats.formatValue(stat: RolledStat): string
	local definition = Stats.DEFS[stat.id]
	local decimals = if definition ~= nil then definition.decimals else 0
	local unit = if definition ~= nil then definition.unit else "flat"
	if unit == "percent" then
		return string.format("%." .. tostring(decimals) .. "f%%", stat.value * 100)
	end
	if unit == "multiplier" then
		return string.format("%." .. tostring(decimals) .. "f", stat.value)
	end
	if decimals <= 0 then
		return tostring(math.floor(stat.value + 0.5))
	end
	return string.format("%." .. tostring(decimals) .. "f", stat.value)
end

local function clamp01(alpha: number): number
	if alpha ~= alpha or alpha < 0 then
		return 0
	end
	if alpha > 1 then
		return 1
	end
	return alpha
end

function Stats.roll(
	ranges: { Range },
	rarity: string,
	weaponType: any,
	rng: any
): ({ RolledStat }, number)
	if Stats.RARITY_SCALE[rarity] == nil then
		error("Unknown rarity '" .. tostring(rarity) .. "'", 2)
	end
	if Rarities.INDEX[rarity] == nil then
		error("Unknown rarity '" .. tostring(rarity) .. "'", 2)
	end
	local rolled = {}
	local percents = {}
	for _, range in ipairs(ranges) do
		local definition = Stats.DEFS[range.id]
		if definition == nil then
			error("Unknown stat '" .. tostring(range.id) .. "'", 2)
		end
		local weight = Stats.classWeight(weaponType, range.id)
		local minValue, maxValue = Stats.scaledBounds(range.min, range.max, rarity, weight)
		local alpha = clamp01(rng:nextNumber())
		local value = minValue + (maxValue - minValue) * alpha
		table.insert(rolled, {
			id = range.id,
			name = definition.name,
			value = value,
			min = minValue,
			max = maxValue,
			unit = definition.unit,
			roll = Stats.rollPercent(value, minValue, maxValue),
			baseValue = value,
		})
		table.insert(percents, Stats.rollPercent(value, minValue, maxValue))
	end
	return rolled, Stats.qualityOf(percents)
end

for _, row in pairs(Stats.CLASS_WEIGHTS) do
	table.freeze(row)
end
table.freeze(Stats.CLASS_WEIGHTS)
table.freeze(Stats.RARITY_SCALE)
table.freeze(Stats.WEAPON_TYPES)
for _, definition in pairs(Stats.DEFS) do
	table.freeze(definition)
end
table.freeze(Stats.DEFS)

return Stats
