--!strict

--[[
	Crafting recipes. Costs are material ids from Materials.luau.

	An `item` result mints that catalog base with a fresh stat roll.
	A `consumable` result adds a stack, today only the Healing Tonic.
	A `reroll` result replaces one trait on a weapon or armor piece the
	player already owns. Add a recipe by adding a row here.
]]

local ItemBases = require("./ItemBases")
local Materials = require("./Materials")

local Recipes = {}

export type ItemResult = {
	kind: "item",
	templateId: string,
}

export type ConsumableResult = {
	kind: "consumable",
	id: string,
	count: number,
}

export type RerollResult = {
	kind: "reroll",
}

export type Recipe = {
	id: string,
	name: string,
	blurb: string,
	costs: { [string]: number },
	result: ItemResult | ConsumableResult | RerollResult,
	-- Crafting Level required. Missing means 1.
	level: number?,
	-- XP tier. Missing means 1. Higher tiers pay more crafting XP.
	tier: number?,
	-- Material id of a scroll that must be owned. The craft does not spend it.
	scroll: string?,
}

local LIST: { Recipe } = {
	{
		id = "briar_edge",
		name = "Briar Edge",
		blurb = "Craft a Thorn Dagger. Its stats roll the same way a shard drop does.",
		costs = { wood = 4, vine = 2 },
		result = { kind = "item", templateId = "thorn_dagger" },
	},
	{
		id = "grove_hood",
		name = "Grovewarden Hood",
		blurb = "Craft the helm from the Grovewarden set.",
		costs = { bark = 2, vine = 3, spore = 1 },
		result = { kind = "item", templateId = "grovewarden_hood" },
	},
	{
		id = "healing_tonic",
		name = "Healing Tonic",
		blurb = "Drink it in the dungeon to restore 40% of your max HP.",
		costs = { spore = 1, vine = 1 },
		result = { kind = "consumable", id = Materials.TONIC_ID, count = 1 },
	},
	{
		id = "wild_resin",
		name = "Wild Resin",
		blurb = "Spend Heartwood to reroll one trait on a Rare or better weapon or armor piece.",
		costs = { heartwood = 1, spore = 2 },
		result = { kind = "reroll" },
	},
	{
		id = "iron_sword",
		name = "Iron Sword",
		blurb = "A plain sword. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 4 },
		result = { kind = "item", templateId = "iron_sword" },
		level = 1,
		tier = 1,
	},
	{
		id = "iron_greatsword",
		name = "Iron Greatsword",
		blurb = "A plain greatsword. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 6 },
		result = { kind = "item", templateId = "iron_greatsword" },
		level = 1,
		tier = 1,
	},
	{
		id = "iron_bow",
		name = "Iron Bow",
		blurb = "A plain bow. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 4 },
		result = { kind = "item", templateId = "iron_bow" },
		level = 1,
		tier = 1,
	},
	{
		id = "iron_staff",
		name = "Iron Staff",
		blurb = "A plain staff. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 4 },
		result = { kind = "item", templateId = "iron_staff" },
		level = 1,
		tier = 1,
	},
	{
		id = "iron_dagger",
		name = "Iron Dagger",
		blurb = "A plain dagger. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 3 },
		result = { kind = "item", templateId = "iron_dagger" },
		level = 1,
		tier = 1,
	},
	{
		id = "iron_hammer",
		name = "Iron Hammer",
		blurb = "A plain hammer. Stats roll with your Crafting Level.",
		costs = { verdant_bark = 6 },
		result = { kind = "item", templateId = "iron_hammer" },
		level = 1,
		tier = 1,
	},
	{
		id = "thornbound_blade",
		name = "Thornbound Blade",
		blurb = "Verdant rare sword. Needs Crafting Level 10 and a Thornbound Scroll.",
		costs = { verdant_bark = 6, heartwood = 2 },
		result = { kind = "item", templateId = "thornbound_blade" },
		level = 10,
		tier = 2,
		scroll = "scroll_thornbound",
	},
}

local byId: { [string]: Recipe } = {}

for _, recipe in ipairs(LIST) do
	if byId[recipe.id] ~= nil then
		error("Duplicate recipe '" .. recipe.id .. "'", 0)
	end
	for materialId, count in pairs(recipe.costs) do
		if Materials.DEFS[materialId] == nil then
			error(recipe.id .. " spends unknown material '" .. materialId .. "'", 0)
		end
		if type(count) ~= "number" or count < 1 then
			error(recipe.id .. " has a bad cost", 0)
		end
	end
	if recipe.scroll ~= nil and Materials.DEFS[recipe.scroll] == nil then
		error(recipe.id .. " needs an unknown scroll", 0)
	end
	if recipe.level ~= nil and (recipe.level < 1 or recipe.level > 100) then
		error(recipe.id .. " has a bad crafting level", 0)
	end
	if recipe.tier ~= nil and (recipe.tier < 1 or recipe.tier > 5) then
		error(recipe.id .. " has a bad tier", 0)
	end
	if recipe.result.kind == "item" then
		if ItemBases.get(recipe.result.templateId) == nil then
			error(recipe.id .. " crafts a missing item", 0)
		end
	elseif recipe.result.kind == "consumable" then
		if recipe.result.id ~= Materials.TONIC_ID or recipe.result.count < 1 then
			error(recipe.id .. " has a bad consumable result", 0)
		end
	elseif recipe.result.kind ~= "reroll" then
		error(recipe.id .. " has an unknown result", 0)
	end
	byId[recipe.id] = recipe
end

function Recipes.get(recipeId: string): Recipe?
	return byId[recipeId]
end

function Recipes.all(): { Recipe }
	return LIST
end

for _, recipe in ipairs(LIST) do
	table.freeze(recipe.costs)
	table.freeze(recipe.result)
	table.freeze(recipe)
end
table.freeze(LIST)

return Recipes
