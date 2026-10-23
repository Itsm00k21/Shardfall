--!strict

--[[
	Stage A duplicate upgrades. Data only, plus the read-time scale.

	This is not a second level. The Bag UPGRADE button already writes
	item.upgrade, Schema already saves it (0 through Economy.UPGRADE_MAX),
	and Economy.upgradeCost is the gold curve. A duplicate grants +1 on
	that same field and stops at that same cap.

	The earlier per-rarity caps (Common 5, Uncommon 6, Rare 7, Epic 8,
	Legendary 10) do not fit. The button still sells +6 through +10 on a
	Common piece. One cap for every rarity keeps the two paths together.

	PER_LEVEL is +8% of the piece's current stat for each upgrade above
	+0. +0 is ×1, so an item nobody has upgraded keeps its numbers.
	The scale is applied when totals are computed. It is not written
	back onto the saved stat. Stars already multiply the saved value.

	ESSENCE is how much overflow a duplicate records once the piece is
	at the cap. Stage B spends it. This module does not.
]]

local Economy = require("../Economy")

local GearLevels = {}

GearLevels.PER_LEVEL = 0.08

-- Starting overflow. Same ladder the duplicate fragments used.
-- Stage B is the real Essence wallet. This number is only a record.
GearLevels.ESSENCE = table.freeze({
	Common = 1,
	Uncommon = 3,
	Rare = 10,
	Epic = 40,
	Legendary = 200,
	Mythic = 200,
	Secret = 200,
})

function GearLevels.capFor(_rarity: any): number
	local cap = Economy.UPGRADE_MAX
	if type(cap) ~= "number" or cap ~= cap or cap < 0 or cap >= math.huge then
		return 10
	end
	return math.floor(cap)
end

-- +0 when the field is missing, junk, or below 0. A stored upgrade
-- above the forge cap clamps down. Stats on the item are not read.
function GearLevels.storedUpgrade(value: any): number
	local cap = GearLevels.capFor(nil)
	local upgrade = 0
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then
		upgrade = math.floor(value)
	end
	if upgrade < 0 then
		upgrade = 0
	end
	if upgrade > cap then
		upgrade = cap
	end
	return upgrade
end

function GearLevels.multiplier(upgrade: any, _rarity: any): number
	local stored = GearLevels.storedUpgrade(upgrade)
	local rate = GearLevels.PER_LEVEL
	if type(rate) ~= "number" or rate ~= rate or rate < 0 then
		return 1
	end
	if rate > 1 then
		rate = 1
	end
	return 1 + stored * rate
end

function GearLevels.essenceFor(rarity: any): number
	if type(rarity) ~= "string" then
		return 0
	end
	local amount = GearLevels.ESSENCE[rarity]
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount >= math.huge then
		return 0
	end
	return math.floor(amount)
end

function GearLevels.levelText(name: any, oldLevel: number, newLevel: number): string?
	if type(name) ~= "string" or name == "" or newLevel <= oldLevel then
		return nil
	end
	return string.format("%s +%d -> +%d", name, oldLevel, newLevel)
end

return table.freeze(GearLevels)
