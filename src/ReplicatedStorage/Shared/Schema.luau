--!strict

--[[
	The player profile shape, version 3.

	DataService stores whatever migrate() returns. Adding a field later:
	  1. Bump Schema.VERSION.
	  2. Add a default in template().
	  3. Write a `if version < N` step in migrate() that fills existing saves.
	reconcile() only fills missing keys, so it will not reset gold or wipe
	an inventory that is already there.

	Profiles are plain tables: no Color3, no Instance, no functions. That is
	what DataStores can save and what a RemoteEvent can send.
]]

local Materials = require("./Materials")

local Schema = {}

Schema.VERSION = 3
Schema.STARTER_TOKENS = 25
Schema.INVENTORY_CAP = 100

export type Trait = {
	id: string,
	name: string,
	value: number,
	unit: string,
	display: string,
}

export type Item = {
	uid: string,
	templateId: string,
	name: string,
	kind: string,
	rarity: string,
	traits: { Trait },
	stats: { any }?,
	quality: number?,
	weaponType: string?,
	slot: string?,
	setId: string?,
	poolId: string,
	obtainedAt: number,
}

export type PityState = {
	rollsSinceLegendary: number,
	totalRolls: number,
}

export type Equipped = {
	weapon: string?,
	pet: string?,
	armor: { [string]: string },
}

Schema.ARMOR_SLOTS = {
	helm = true,
	chest = true,
	legs = true,
	boots = true,
}

export type ProfileData = {
	schemaVersion: number,
	level: number,
	xp: number,
	ascension: number,
	gold: number,
	shardTokens: number,
	shardLuck: number,
	inventory: { [string]: Item },
	pets: { [string]: Item },
	pity: { [string]: PityState },
	equipped: Equipped,
	materials: { [string]: number },
	consumables: { [string]: number },
	vouchers: { [string]: number },
}

function Schema.template(): ProfileData
	return {
		schemaVersion = Schema.VERSION,
		level = 1,
		xp = 0,
		ascension = 0,
		gold = 0,
		-- Enough free cracks to playtest before any token source exists.
		shardTokens = Schema.STARTER_TOKENS,
		shardLuck = 0,
		inventory = {},
		pets = {},
		pity = {},
		equipped = {
			weapon = nil,
			pet = nil,
			armor = {},
		},
		materials = Materials.empty(),
		consumables = { [Materials.TONIC_ID] = 0 },
		vouchers = { armory = 0, pets = 0 },
	}
end

function Schema.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = Schema.deepCopy(child)
	end
	return copy
end

function Schema.xpToNext(level: number): number
	local whole = math.floor(level)
	if whole < 1 then
		whole = 1
	end
	return 100 * whole
end

local function wholeNumber(value: any, fallback: number, minimum: number): number
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= numberValue then
		return fallback
	end
	local floored = math.floor(numberValue)
	if floored < minimum then
		return minimum
	end
	return floored
end

local function optionalUid(value: any): string?
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

function Schema.reconcile(data: any): ProfileData
	if type(data) ~= "table" then
		data = {}
	end
	local defaults = Schema.template()
	for key, value in pairs(defaults) do
		if data[key] == nil then
			data[key] = Schema.deepCopy(value)
		end
	end
	if type(data.inventory) ~= "table" then
		data.inventory = {}
	end
	if type(data.pets) ~= "table" then
		data.pets = {}
	end
	if type(data.pity) ~= "table" then
		data.pity = {}
	end
	if type(data.equipped) ~= "table" then
		data.equipped = {}
	end

	data.schemaVersion = Schema.VERSION
	data.level = wholeNumber(data.level, 1, 1)
	data.xp = wholeNumber(data.xp, 0, 0)
	data.ascension = wholeNumber(data.ascension, 0, 0)
	data.gold = wholeNumber(data.gold, 0, 0)
	data.shardTokens = wholeNumber(data.shardTokens, Schema.STARTER_TOKENS, 0)
	data.shardLuck = wholeNumber(data.shardLuck, 0, 0)
	data.equipped.weapon = optionalUid(data.equipped.weapon)
	data.equipped.pet = optionalUid(data.equipped.pet)
	-- An equipped id that is not in the bag must not survive. The client
	-- names whatever this points at, so a stale id would look like a sword
	-- the player does not have.
	if data.equipped.weapon ~= nil and data.inventory[data.equipped.weapon] == nil then
		data.equipped.weapon = nil
	end
	if data.equipped.pet ~= nil and data.pets[data.equipped.pet] == nil then
		data.equipped.pet = nil
	end
	local armor = {}
	if type(data.equipped.armor) == "table" then
		for slot, uid in pairs(data.equipped.armor) do
			if Schema.ARMOR_SLOTS[slot] == true and data.inventory[uid] ~= nil then
				armor[slot] = uid
			end
		end
	end
	data.equipped.armor = armor
	data.materials = Materials.sanitize(data.materials)
	data.consumables = Materials.sanitizeCounts(data.consumables, { Materials.TONIC_ID })
	data.vouchers = Materials.sanitizeCounts(data.vouchers, Materials.VOUCHER_AREAS)
	return data
end

--[[
	Returns the migrated profile, or nil plus a reason.

	"corrupt" and "newer" must not be overwritten by the caller. A newer
	version means a future server already saved this player; an old server
	should refuse the session instead of rolling the data backwards.
]]
function Schema.migrate(raw: any): (ProfileData?, string?)
	if raw == nil then
		raw = {}
	elseif type(raw) ~= "table" then
		return nil, "corrupt"
	end

	local version = raw.schemaVersion
	if version == nil then
		version = 0
	elseif type(version) ~= "number" or version ~= version then
		return nil, "corrupt"
	end
	if version > Schema.VERSION then
		return nil, "newer"
	end

	if version < 1 then
		-- Version 1 is the first shipped shape. There is nothing to rewrite;
		-- reconcile fills keys that were never saved.
		raw.schemaVersion = 1
		version = 1
	end

	if version < 2 then
		-- Armor slots. Older saves only had a weapon and a pet.
		if type(raw.equipped) ~= "table" then
			raw.equipped = {}
		end
		if type(raw.equipped.armor) ~= "table" then
			raw.equipped.armor = {}
		end
		raw.schemaVersion = 2
		version = 2
	end

	if version < 3 then
		-- Materials, tonics, and roll vouchers. Older saves had none of these.
		if type(raw.materials) ~= "table" then
			raw.materials = {}
		end
		if type(raw.consumables) ~= "table" then
			raw.consumables = {}
		end
		if type(raw.vouchers) ~= "table" then
			raw.vouchers = {}
		end
		raw.schemaVersion = 3
		version = 3
	end

	-- Next version goes here, then bump Schema.VERSION and template():
	-- if version < 4 then
	--     raw.boosts = raw.boosts or {}
	--     raw.schemaVersion = 4
	--     version = 4
	-- end

	return Schema.reconcile(raw), nil
end

function Schema.pityBucket(data: ProfileData, poolId: string): PityState
	local pity = data.pity[poolId]
	if type(pity) ~= "table" then
		pity = {
			rollsSinceLegendary = 0,
			totalRolls = 0,
		}
		data.pity[poolId] = pity
	end
	if type(pity.rollsSinceLegendary) ~= "number" or pity.rollsSinceLegendary < 0 then
		pity.rollsSinceLegendary = 0
	end
	if type(pity.totalRolls) ~= "number" or pity.totalRolls < 0 then
		pity.totalRolls = 0
	end
	return pity
end

function Schema.countItems(data: ProfileData): number
	local count = 0
	for _ in pairs(data.inventory) do
		count += 1
	end
	for _ in pairs(data.pets) do
		count += 1
	end
	return count
end

function Schema.findItem(data: ProfileData, uid: string): (Item?, { [string]: Item }?)
	local weapon = data.inventory[uid]
	if weapon ~= nil then
		return weapon, data.inventory
	end
	local pet = data.pets[uid]
	if pet ~= nil then
		return pet, data.pets
	end
	return nil, nil
end

function Schema.insertItem(data: ProfileData, item: Item)
	if item.kind == "Pet" then
		data.pets[item.uid] = item
	else
		data.inventory[item.uid] = item
	end
end

function Schema.isEquipped(data: ProfileData, uid: string): boolean
	if data.equipped.weapon == uid or data.equipped.pet == uid then
		return true
	end
	for _, slotUid in pairs(data.equipped.armor) do
		if slotUid == uid then
			return true
		end
	end
	return false
end

function Schema.clearEquip(data: ProfileData, uid: string)
	if data.equipped.weapon == uid then
		data.equipped.weapon = nil
	end
	if data.equipped.pet == uid then
		data.equipped.pet = nil
	end
	for slot, slotUid in pairs(data.equipped.armor) do
		if slotUid == uid then
			data.equipped.armor[slot] = nil
		end
	end
end

-- nil when the item is now equipped. Otherwise a reason.
function Schema.equipItem(data: ProfileData, item: Item): string?
	if item.kind == "Weapon" then
		data.equipped.weapon = item.uid
		return nil
	end
	if item.kind == "Pet" then
		data.equipped.pet = item.uid
		return nil
	end
	if item.kind == "Armor" then
		local slot = item.slot
		if type(slot) ~= "string" or Schema.ARMOR_SLOTS[slot] ~= true then
			return "That armor has no slot."
		end
		data.equipped.armor[slot] = item.uid
		return nil
	end
	return "That item cannot be equipped."
end

-- Allow-list copy sent to that player's client. Session locks are not in here.
function Schema.snapshot(data: ProfileData)
	return {
		schemaVersion = data.schemaVersion,
		level = data.level,
		xp = data.xp,
		xpToNext = Schema.xpToNext(data.level),
		ascension = data.ascension,
		gold = data.gold,
		shardTokens = data.shardTokens,
		shardLuck = data.shardLuck,
		inventory = Schema.deepCopy(data.inventory),
		pets = Schema.deepCopy(data.pets),
		pity = Schema.deepCopy(data.pity),
		equipped = {
			weapon = data.equipped.weapon,
			pet = data.equipped.pet,
			armor = Schema.deepCopy(data.equipped.armor),
		},
		materials = Schema.deepCopy(data.materials),
		consumables = Schema.deepCopy(data.consumables),
		vouchers = Schema.deepCopy(data.vouchers),
	}
end

table.freeze(Schema.ARMOR_SLOTS)

return Schema
