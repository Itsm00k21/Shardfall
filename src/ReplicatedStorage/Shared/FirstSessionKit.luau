--!strict

--[[
	First-session mint. FirstSession stays pure.

	The kit is granted once, after the profile has a server class id.
	A skip before that grants nothing. An alt is a new profile and
	starts the kit fresh. There is no account flag.

	Armor is the Common catalog vest. Forgeborn has no Rare hammer, so
	that weapon is the Common iron hammer. The other classes keep the
	existing Rare weapon, with one socket. No template is added.

	ItemBases has no Accessory row. verdant_ring is a combo flag, not
	gear, so the ring slot stays empty.

	The first companion is Shardjaw. A new accepted grant adds one
	companion when that species is not already on the profile.
	Existing companions stay, including a returning mossback. This
	does not hatch, and it does not put a pet in the inventory.
	Cute ids stay banned.
]]

local FirstSession = require("./FirstSession")
local ItemBases = require("./ItemBases")
local RollMath = require("./RollMath")
local Schema = require("./Schema")

local FirstSessionKit = {}

FirstSessionKit.ARMOR_ID = "woven_bark_vest"
FirstSessionKit.RING_ID = nil

local WEAPONS: { [string]: string } = {
	warden = "thornbound_blade",
	tidecaller = "mycelium_staff",
	forgeborn = "iron_hammer",
	frostblade = "nightbriar",
	voidcaster = "galevine_bow",
}
FirstSessionKit.WEAPONS = table.freeze(WEAPONS)

local BANNED: { [string]: boolean } = {
	moss_hare = true,
	acorn_newt = true,
	mossback = true,
	tide_sprite = true,
	living_bark_cuirass = true,
	green_tyrant = true,
	verdant_ring = true,
	beastbone_hammer = true,
}

local GOAL_IDS = { "roll", "chest", "miniboss", "forge" }

local function blankGranted()
	return {
		roll = false,
		chest = false,
		miniboss = false,
		forge = false,
	}
end

function FirstSessionKit.blank(returning: boolean?)
	return {
		returning = returning == true,
		granted = blankGranted(),
	}
end

function FirstSessionKit.normalize(raw: any)
	local granted = blankGranted()
	local returning = false
	if type(raw) == "table" then
		returning = raw.returning == true
		if type(raw.granted) == "table" then
			for _, id in ipairs(GOAL_IDS) do
				granted[id] = raw.granted[id] == true
			end
		end
	end
	return {
		returning = returning,
		granted = granted,
	}
end

local function stateOf(record)
	return {
		returning = record.returning == true,
		granted = {
			roll = record.granted.roll == true,
			chest = record.granted.chest == true,
			miniboss = record.granted.miniboss == true,
			forge = record.granted.forge == true,
		},
	}
end

local function refused(reason: string)
	return {
		ok = false,
		accepted = false,
		error = reason,
	}
end

local floorRng = {
	nextNumber = function(_self): number
		return 0
	end,
	nextInteger = function(_self, minValue: number, _maxValue: number): number
		return minValue
	end,
}

local function catalogRow(templateId: string): any
	if BANNED[templateId] == true then
		return nil
	end
	local base = ItemBases.get(templateId)
	if type(base) ~= "table" or base.id ~= templateId then
		return nil
	end
	if base.kind == "Pet" then
		return nil
	end
	return base
end

local function shardjawRecord()
	return {
		species = "shardjaw",
		name = "Shardjaw",
		role = "Gatherer",
		rarity = "Common",
		personality = "Grumpy",
		level = 1,
		xp = 0,
		bond = 1,
		affinity = 1,
		favorite = false,
		colors = { primary = "slate", secondary = "shard", glow = "none" },
		journal = { "First companion" },
		perk = "auto_collect",
	}
end

local function ownsShardjaw(data: any): boolean
	if type(data.companions) ~= "table" then
		return false
	end
	for _, pet in pairs(data.companions) do
		if type(pet) == "table" and pet.species == "shardjaw" then
			return true
		end
	end
	return false
end

local function mint(templateId: string, uid: string, sockets: number): any?
	local base = catalogRow(templateId)
	if base == nil then
		return nil
	end
	local item = RollMath.mint(templateId, {
		uid = uid,
		now = 0,
		poolId = "first_session",
	}, floorRng)
	item.sockets = sockets
	return item
end

function FirstSessionKit.grant(data: any)
	if type(data) ~= "table" then
		return refused(FirstSession.ERRORS.state)
	end
	local classId = data.classId
	if type(classId) ~= "string" or FirstSession.ELEMENTS[classId] == nil then
		return refused(FirstSession.ERRORS.class)
	end
	local weaponId = WEAPONS[classId]
	local weapon = if type(weaponId) == "string" then catalogRow(weaponId) else nil
	local armor = catalogRow(FirstSessionKit.ARMOR_ID)
	if weapon == nil or weapon.kind ~= "Weapon" or weapon.ascension ~= 0 then
		return refused(FirstSession.ERRORS.rules)
	end
	if classId == "forgeborn" then
		if weapon.rarity ~= "Common" or weaponId ~= "iron_hammer" then
			return refused(FirstSession.ERRORS.rules)
		end
	elseif weapon.rarity ~= "Rare" then
		return refused(FirstSession.ERRORS.rules)
	end
	if
		armor == nil
		or armor.kind ~= "Armor"
		or armor.rarity ~= "Common"
		or armor.slot ~= "chest"
	then
		return refused(FirstSession.ERRORS.rules)
	end
	local record = FirstSessionKit.normalize(data.firstSession)
	local skipped = FirstSession.skip(stateOf(record), { classId = classId })
	if skipped.ok ~= true then
		return {
			ok = false,
			accepted = false,
			error = skipped.error,
		}
	end
	local open = {}
	for _, reward in ipairs(skipped.rewards) do
		if type(reward) == "table" and type(reward.step) == "string" then
			open[reward.step] = true
		end
	end
	if open.chest ~= true and open.miniboss ~= true then
		data.firstSession = FirstSessionKit.normalize({
			returning = skipped.state.returning,
			granted = skipped.state.granted,
		})
		return {
			ok = true,
			accepted = false,
			state = data.firstSession,
		}
	end
	local room = Schema.inventoryCap(data) - Schema.countItems(data)
	local need = 0
	if open.chest == true then
		need += 1
	end
	if open.miniboss == true then
		need += 1
	end
	if room < need then
		return refused("Inventory is full.")
	end
	local weaponItem = nil
	local armorItem = nil
	if open.chest == true then
		local sockets = if weapon.rarity == "Rare" then 1 else 0
		weaponItem = mint(weaponId :: string, "first-session-weapon", sockets)
		if weaponItem == nil or weaponItem.kind ~= "Weapon" then
			return refused(FirstSession.ERRORS.rules)
		end
	end
	if open.miniboss == true then
		armorItem = mint(FirstSessionKit.ARMOR_ID, "first-session-armor", 0)
		if armorItem == nil or armorItem.kind ~= "Armor" then
			return refused(FirstSession.ERRORS.rules)
		end
	end
	if weaponItem ~= nil then
		Schema.insertItem(data, weaponItem)
		Schema.equipItem(data, weaponItem)
	end
	if armorItem ~= nil then
		Schema.insertItem(data, armorItem)
		Schema.equipItem(data, armorItem)
	end
	data.firstSession = FirstSessionKit.normalize({
		returning = skipped.state.returning,
		granted = skipped.state.granted,
	})
	local petId = nil
	if not ownsShardjaw(data) then
		if type(data.companions) ~= "table" then
			data.companions = {}
		end
		table.insert(data.companions, shardjawRecord())
		petId = "shardjaw"
	end
	return {
		ok = true,
		accepted = true,
		state = data.firstSession,
		weaponId = if open.chest == true then weaponId else nil,
		armorId = if open.miniboss == true then FirstSessionKit.ARMOR_ID else nil,
		ringId = FirstSessionKit.RING_ID,
		petId = petId,
	}
end

return FirstSessionKit
