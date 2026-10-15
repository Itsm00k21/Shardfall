--!strict

--[[
	Checks a recipe and applies it to a profile table.

	The server calls this inside DataService.mutate. Returning an error
	string spends nothing, because the caller restores the profile. The
	client never decides the result: it only sends a recipe id and, for
	Wild Resin, the item id to reroll.
]]

local CraftingLevel = require("./CraftingLevel")
local InventoryView = require("./InventoryView")
local ItemBases = require("./ItemBases")
local Materials = require("./Materials")
local Rarities = require("./Rarities")
local Recipes = require("./Recipes")
local RollMath = require("./RollMath")
local Schema = require("./Schema")
local Stats = require("./Stats")
local Traits = require("./Traits")

local Crafting = {}

export type Need = {
	id: string,
	name: string,
	owned: number,
	need: number,
}

local function missing(recipe: Recipes.Recipe, materials: { [string]: number }): { Need }
	local gaps = {}
	for _, materialId in ipairs(Materials.ORDER) do
		local need = recipe.costs[materialId]
		if need ~= nil and need > 0 then
			local owned = materials[materialId] or 0
			if owned < need then
				table.insert(gaps, {
					id = materialId,
					name = Materials.displayName(materialId),
					owned = owned,
					need = need,
				})
			end
		end
	end
	return gaps
end

local function spend(materials: { [string]: number }, costs: { [string]: number })
	for materialId, count in pairs(costs) do
		materials[materialId] = (materials[materialId] or 0) - count
	end
end

local function craftingLevelOf(profile: any): number
	local level = profile.craftingLevel
	if type(level) ~= "number" or level ~= level or level < 1 then
		return 1
	end
	return math.floor(level)
end

local function recipeLevel(recipe: Recipes.Recipe): number
	if type(recipe.level) ~= "number" or recipe.level < 1 then
		return 1
	end
	return recipe.level
end

local function recipeTier(recipe: Recipes.Recipe): number
	if type(recipe.tier) ~= "number" or recipe.tier < 1 then
		return 1
	end
	return recipe.tier
end

-- Nil means the recipe is unlocked. A short material pile is a separate check.
function Crafting.lockReason(profile: any, recipeId: string): string?
	local recipe = Recipes.get(recipeId)
	if recipe == nil or type(profile) ~= "table" then
		return "Unknown recipe."
	end
	local lines = {}
	if craftingLevelOf(profile) < recipeLevel(recipe) then
		table.insert(lines, string.format("Crafting Level %d.", recipeLevel(recipe)))
	end
	if type(recipe.scroll) == "string" then
		local owned = 0
		if type(profile.materials) == "table" then
			owned = profile.materials[recipe.scroll] or 0
		end
		if owned < 1 then
			table.insert(lines, "Needs a " .. Materials.displayName(recipe.scroll) .. ".")
		end
	end
	if #lines == 0 then
		return nil
	end
	return table.concat(lines, " ")
end

local YIELD: { [string]: { [string]: number } } = {
	Common = { common = 2 },
	Uncommon = { common = 3 },
	Rare = { common = 1, rare = 1 },
	Epic = { common = 2, rare = 2 },
	Legendary = { rare = 2, boss = 1 },
	Mythic = { rare = 2, boss = 2 },
	Secret = { rare = 2, boss = 3 },
}

function Crafting.salvageYield(item: any): { [string]: number }
	local counts = {}
	if type(item) ~= "table" then
		return counts
	end
	local base = if type(item.templateId) == "string" then ItemBases.get(item.templateId) else nil
	local ascension = if base ~= nil then base.ascension else 0
	local realm = Materials.realmForAscension(ascension)
	local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
	local grades = YIELD[rarity] or YIELD.Common
	for grade, count in pairs(grades) do
		local materialId = Materials.primary(realm, grade :: Materials.Grade)
		if materialId ~= nil and count > 0 then
			counts[materialId] = (counts[materialId] or 0) + count
		end
	end
	return counts
end

local function shiftRng(rng: RollMath.Rng, bias: number): RollMath.Rng
	if bias <= 0 then
		return rng
	end
	return {
		nextNumber = function()
			local value = rng:nextNumber() + bias
			if value > 1 then
				return 1
			end
			if value < 0 then
				return 0
			end
			return value
		end,
		nextInteger = function(_self, min: number, max: number)
			return rng:nextInteger(min, max)
		end,
	}
end

function Crafting.needs(profile: any, recipeId: string): { Need }
	local recipe = Recipes.get(recipeId)
	if recipe == nil or type(profile) ~= "table" or type(profile.materials) ~= "table" then
		return {}
	end
	local rows = {}
	for _, materialId in ipairs(Materials.ORDER) do
		local need = recipe.costs[materialId]
		if need ~= nil and need > 0 then
			table.insert(rows, {
				id = materialId,
				name = Materials.displayName(materialId),
				owned = profile.materials[materialId] or 0,
				need = need,
			})
		end
	end
	return rows
end

-- Nil reason means the craft can be paid for. The reason is safe to show.
function Crafting.validate(
	profile: Schema.ProfileData,
	recipeId: string,
	targetUid: string?
): (Recipes.Recipe?, string?)
	local recipe = Recipes.get(recipeId)
	if recipe == nil then
		return nil, "Unknown recipe."
	end
	local locked = Crafting.lockReason(profile, recipeId)
	if locked ~= nil then
		return nil, locked
	end
	local gaps = missing(recipe, profile.materials)
	if #gaps > 0 then
		local names = {}
		for _, gap in ipairs(gaps) do
			table.insert(names, string.format("%s (%d/%d)", gap.name, gap.owned, gap.need))
		end
		return nil, "Need " .. table.concat(names, ", ") .. "."
	end
	if recipe.result.kind == "item" then
		if Schema.countItems(profile) >= Schema.inventoryCap(profile) then
			return nil, "Inventory is full."
		end
	elseif recipe.result.kind == "consumable" then
		local owned = profile.consumables[Materials.TONIC_ID] or 0
		if owned >= Materials.TONIC_CAP then
			return nil, "You cannot carry more Healing Tonics."
		end
	elseif recipe.result.kind == "reroll" then
		if type(targetUid) ~= "string" or targetUid == "" then
			return nil, "Pick a weapon or armor piece to reroll."
		end
		local item = Schema.findItem(profile, targetUid)
		if item == nil then
			return nil, "You do not have that item."
		end
		if item.kind ~= "Weapon" and item.kind ~= "Armor" then
			return nil, "Only weapons and armor have traits."
		end
		local slots = Rarities.TRAIT_SLOTS[item.rarity]
		if slots == nil or slots <= 0 then
			return nil, "That item cannot hold a trait."
		end
	end
	return recipe, nil
end

local function rerollOne(item: Schema.Item, rng: RollMath.Rng): string?
	local slots = Rarities.TRAIT_SLOTS[item.rarity]
	if slots == nil or slots <= 0 then
		return "That item cannot hold a trait."
	end
	if type(item.traits) ~= "table" then
		item.traits = {}
	end
	if #item.traits == 0 then
		item.traits = { Traits.pick(rng, {}) }
		return nil
	end
	local index = rng:nextInteger(1, #item.traits)
	local banned: { [string]: boolean } = {}
	for slot, trait in ipairs(item.traits) do
		if slot ~= index and type(trait.id) == "string" then
			banned[trait.id] = true
		end
	end
	item.traits[index] = Traits.pick(rng, banned)
	return nil
end

-- On success, the profile is already updated and the second return is nil.
-- `uid` is the id for a newly crafted item. Rerolls keep the old id.
function Crafting.commit(
	profile: Schema.ProfileData,
	recipeId: string,
	targetUid: string?,
	rng: RollMath.Rng,
	uid: string,
	now: number
): (any?, string?)
	local recipe, reason = Crafting.validate(profile, recipeId, targetUid)
	if recipe == nil then
		return nil, reason
	end

	local summary = {
		recipeId = recipe.id,
		name = recipe.name,
	}

	local bonuses = CraftingLevel.bonusesAt(craftingLevelOf(profile))
	local tier = recipeTier(recipe)

	if recipe.result.kind == "item" then
		local minted = RollMath.mint(recipe.result.templateId, {
			uid = uid,
			now = now,
			poolId = "craft",
		}, shiftRng(rng, bonuses.rollBias))
		if bonuses.rarityUp > 0 and rng:nextNumber() < bonuses.rarityUp then
			local raised = Rarities.next(minted.rarity)
			local base = ItemBases.get(minted.templateId)
			if raised ~= nil and base ~= nil and type(base.stats) == "table" then
				minted.rarity = raised
				local stats, quality =
					Stats.roll(base.stats, raised, base.weaponType, shiftRng(rng, bonuses.rollBias))
				minted.stats = stats
				minted.quality = quality
				local slots = Rarities.TRAIT_SLOTS[raised] or 0
				while #minted.traits < slots do
					local banned: { [string]: boolean } = {}
					for _, trait in ipairs(minted.traits) do
						if type(trait.id) == "string" then
							banned[trait.id] = true
						end
					end
					table.insert(minted.traits, Traits.pick(rng, banned))
				end
			end
		end
		if
			bonuses.masterwork > 0
			and rng:nextNumber() < bonuses.masterwork
			and type(minted.stats) == "table"
		then
			local extra = Stats.roll(
				{ { id = "health", min = 8, max = 16 } },
				minted.rarity,
				minted.weaponType,
				shiftRng(rng, bonuses.rollBias)
			)
			table.insert(minted.stats, extra[1])
		end
		Schema.insertItem(profile, minted)
		spend(profile.materials, recipe.costs)
		local gained = CraftingLevel.grant(profile, CraftingLevel.craftXp(tier), now)
		summary.item = minted
		summary.xp = gained
		summary.craftingLevel = profile.craftingLevel
		return summary, nil
	end

	if recipe.result.kind == "consumable" then
		local id = recipe.result.id
		profile.consumables[id] =
			math.min(Materials.TONIC_CAP, (profile.consumables[id] or 0) + recipe.result.count)
		spend(profile.materials, recipe.costs)
		local gained = CraftingLevel.grant(profile, CraftingLevel.craftXp(tier), now)
		summary.consumable = id
		summary.count = profile.consumables[id]
		summary.xp = gained
		summary.craftingLevel = profile.craftingLevel
		return summary, nil
	end

	local item = Schema.findItem(profile, targetUid :: string)
	if item == nil then
		return nil, "You do not have that item."
	end
	local rerollError = rerollOne(item, rng)
	if rerollError ~= nil then
		return nil, rerollError
	end
	spend(profile.materials, recipe.costs)
	local gained = CraftingLevel.grant(profile, CraftingLevel.craftXp(tier), now)
	summary.item = item
	summary.rerolled = true
	summary.xp = gained
	summary.craftingLevel = profile.craftingLevel
	return summary, nil
end

function Crafting.salvage(
	profile: Schema.ProfileData,
	targetUid: string?,
	now: number
): (any?, string?)
	if type(targetUid) ~= "string" or targetUid == "" then
		return nil, "Pick a weapon or armor piece to salvage."
	end
	local item, bag = Schema.findItem(profile, targetUid)
	if item == nil or bag == nil then
		return nil, "You do not have that item."
	end
	local blocked = InventoryView.salvageBlock(profile, item)
	if blocked ~= nil then
		return nil, blocked
	end
	local yield = Crafting.salvageYield(item)
	for materialId, count in pairs(yield) do
		Materials.add(profile.materials, materialId, count)
	end
	bag[targetUid] = nil
	local gained = CraftingLevel.grant(profile, CraftingLevel.salvageXp(item.rarity), now)
	return {
		uid = targetUid,
		name = item.name,
		materials = yield,
		xp = gained,
		craftingLevel = profile.craftingLevel,
	},
		nil
end

-- Salvages every unequipped, unlocked weapon or armor piece of one rarity.
-- Locked and equipped copies stay in the bag.
function Crafting.salvageRarity(
	profile: Schema.ProfileData,
	rarity: string,
	now: number
): (any?, string?)
	if Rarities.INDEX[rarity] == nil then
		return nil, "Unknown rarity."
	end
	local uids = {}
	for uid, item in pairs(profile.inventory) do
		local gear = item.kind == "Weapon" or item.kind == "Armor"
		if gear and item.rarity == rarity and InventoryView.salvageBlock(profile, item) == nil then
			table.insert(uids, uid)
		end
	end
	if #uids == 0 then
		return nil, "Nothing of that rarity can be salvaged."
	end
	table.sort(uids)
	local count = 0
	local xp = 0
	for _, uid in ipairs(uids) do
		local summary, reason = Crafting.salvage(profile, uid, now)
		if reason ~= nil or summary == nil then
			return nil, reason or "Could not salvage that."
		end
		count += 1
		xp += summary.xp
	end
	return {
		count = count,
		xp = xp,
		rarity = rarity,
		craftingLevel = profile.craftingLevel,
	},
		nil
end

return Crafting
