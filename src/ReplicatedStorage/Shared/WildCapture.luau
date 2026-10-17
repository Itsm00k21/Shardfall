--!strict

--[[
	Wild shiny capture and tiny boss pets.

	A shiny enemy is a rare roll. Defeating it with a Capture Charm
	equipped gives a chance to tame it. The charm is gold and loot, never
	Robux, and it does not make the pet stronger than the shiny bonus.

	Boss pets are a separate very low drop. Gnarlling is cosmetic flex
	plus a unique ability id, not a paid stat stick.

	DungeonService calls WildCaptureService. This module only holds the
	rates, the species map, and the pure rolls.
]]

local WildCapture = {}

export type Form = {
	species: string,
	displayName: string,
	ability: string,
	role: string,
	rarity: string,
	personality: string,
}

export type BossPet = {
	dropRate: number,
	species: string,
	displayName: string,
	ability: string,
	role: string,
	rarity: string,
	personality: string,
}

-- About one enemy in fifty. Tune here, not in a branch.
WildCapture.SHINY_SPAWN_RATE = 0.02
-- With the charm equipped. Without it the chance is zero.
WildCapture.CAPTURE_CHANCE = 0.25
-- Seconds after the shiny dies. The service stores an os.clock() deadline.
WildCapture.TAME_WINDOW = 30
WildCapture.CHARM_ITEM_ID = "capture_charm"
-- Gold price for a vendor. Not a Robux product.
WildCapture.CHARM_GOLD = 250
WildCapture.SHINY_STAT_BONUS = 0.05
WildCapture.SHINY_STAT_NOTE = "+5% stats"

WildCapture.ENEMIES = {
	vine_crawler = {
		species = "vine_sprout",
		displayName = "Vine Sprout",
		ability = "vine_lash",
		role = "Striker",
		rarity = "Uncommon",
		personality = "Playful",
	},
	spore_bat = {
		species = "spore_mote",
		displayName = "Spore Mote",
		ability = "spore_dust",
		role = "Hexer",
		rarity = "Uncommon",
		personality = "Curious",
	},
	moss_crawler = {
		species = "moss_kit",
		displayName = "Moss Kit",
		ability = "moss_shell",
		role = "Guardian",
		rarity = "Uncommon",
		personality = "Loyal",
	},
	root_brute = {
		species = "root_pup",
		displayName = "Root Pup",
		ability = "root_slam",
		role = "Guardian",
		rarity = "Rare",
		personality = "Brave",
	},
	thorn_sprite = {
		species = "thorn_wisp",
		displayName = "Thorn Wisp",
		ability = "thorn_hex",
		role = "Hexer",
		rarity = "Rare",
		personality = "Playful",
	},
} :: { [string]: Form }

WildCapture.BOSS_PETS = {
	grandmother_gnarl = {
		dropRate = 0.01,
		species = "gnarlling",
		displayName = "Gnarlling",
		ability = "tiny_gnarl",
		role = "Guardian",
		rarity = "Legendary",
		personality = "Loyal",
	},
} :: { [string]: BossPet }

for _, form in pairs(WildCapture.ENEMIES) do
	table.freeze(form)
end
table.freeze(WildCapture.ENEMIES)
for _, row in pairs(WildCapture.BOSS_PETS) do
	table.freeze(row)
end
table.freeze(WildCapture.BOSS_PETS)

local function companion(form: Form, journalLine: string): any
	return {
		species = form.species,
		name = form.displayName,
		speciesName = form.displayName,
		role = form.role,
		rarity = form.rarity,
		personality = form.personality,
		level = 1,
		xp = 0,
		bond = 1,
		affinity = 1,
		favorite = false,
		colors = { primary = "verdant", secondary = "sap", glow = "none" },
		journal = { journalLine },
		ability = form.ability,
	}
end

function WildCapture.rollShiny(roll: number): boolean
	if type(roll) ~= "number" or roll ~= roll or roll < 0 then
		return false
	end
	return roll < WildCapture.SHINY_SPAWN_RATE
end

function WildCapture.charmEquipped(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	-- In-memory flag for a server that already checked the charm.
	-- Schema does not save this key. The durable check is the item below.
	if data.captureCharm == true then
		return true
	end
	if type(data.inventory) ~= "table" or type(data.equipped) ~= "table" then
		return false
	end
	local accessories = data.equipped.accessories
	if type(accessories) ~= "table" then
		return false
	end
	local uid = accessories.charm
	if type(uid) ~= "string" then
		return false
	end
	local item = data.inventory[uid]
	if type(item) ~= "table" then
		return false
	end
	local templateId = item.templateId
	if type(templateId) ~= "string" then
		templateId = item.id
	end
	return templateId == WildCapture.CHARM_ITEM_ID
end

function WildCapture.tryCapture(charmEquipped: boolean, roll: number): (boolean, string)
	if charmEquipped ~= true then
		return false, "Equip a Capture Charm."
	end
	if type(roll) ~= "number" or roll ~= roll or roll < 0 or roll >= WildCapture.CAPTURE_CHANCE then
		return false, "The shiny slipped away."
	end
	return true, "Tamed."
end

function WildCapture.shinyCompanion(enemyId: string): (any?, string)
	if type(enemyId) ~= "string" then
		return nil, "That creature cannot be tamed."
	end
	local form = WildCapture.ENEMIES[enemyId]
	if form == nil then
		return nil, "That creature cannot be tamed."
	end
	local pet = companion(form, "Captured shiny")
	pet.enemyId = enemyId
	pet.source = "wild"
	pet.shiny = true
	pet.golden = true
	pet.statBonus = WildCapture.SHINY_STAT_BONUS
	pet.statNote = WildCapture.SHINY_STAT_NOTE
	pet.colors = { primary = "gold", secondary = "verdant", glow = "shiny" }
	pet.bossPet = false
	return pet, "Tamed."
end

function WildCapture.rollBossPet(bossId: string, roll: number): (any?, string)
	if type(bossId) ~= "string" or type(roll) ~= "number" or roll ~= roll or roll < 0 then
		return nil, "That boss has no pet."
	end
	local row = WildCapture.BOSS_PETS[bossId]
	if row == nil then
		return nil, "That boss has no pet."
	end
	if roll >= row.dropRate then
		return nil, "No tiny boss this time."
	end
	local form: Form = {
		species = row.species,
		displayName = row.displayName,
		ability = row.ability,
		role = row.role,
		rarity = row.rarity,
		personality = row.personality,
	}
	local pet = companion(form, "Boss pet: " .. row.displayName)
	pet.bossId = bossId
	pet.source = "boss"
	pet.shiny = false
	pet.golden = false
	pet.bossPet = true
	pet.statBonus = 0
	pet.statNote = ""
	return pet, row.displayName
end

return WildCapture
