--!strict

--[[
	Checks a recipe and applies it to a profile table.

	The server calls this inside DataService.mutate. Returning an error
	string spends nothing, because the caller restores the profile. The
	client never decides the result: it only sends a recipe id and, for
	Wild Resin, the item id to reroll.
]]

local Materials = require("./Materials")
local Rarities = require("./Rarities")
local Recipes = require("./Recipes")
local RollMath = require("./RollMath")
local Schema = require("./Schema")
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
	local gaps = missing(recipe, profile.materials)
	if #gaps > 0 then
		local names = {}
		for _, gap in ipairs(gaps) do
			table.insert(names, string.format("%s (%d/%d)", gap.name, gap.owned, gap.need))
		end
		return nil, "Need " .. table.concat(names, ", ") .. "."
	end
	if recipe.result.kind == "item" then
		if Schema.countItems(profile) >= Schema.INVENTORY_CAP then
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

	if recipe.result.kind == "item" then
		local minted = RollMath.mint(recipe.result.templateId, {
			uid = uid,
			now = now,
			poolId = "craft",
		}, rng)
		Schema.insertItem(profile, minted)
		spend(profile.materials, recipe.costs)
		summary.item = minted
		return summary, nil
	end

	if recipe.result.kind == "consumable" then
		local id = recipe.result.id
		profile.consumables[id] =
			math.min(Materials.TONIC_CAP, (profile.consumables[id] or 0) + recipe.result.count)
		spend(profile.materials, recipe.costs)
		summary.consumable = id
		summary.count = profile.consumables[id]
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
	summary.item = item
	summary.rerolled = true
	return summary, nil
end

return Crafting
