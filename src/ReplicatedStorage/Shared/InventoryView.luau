--!strict

--[[
	Filter, sort, and compare for the player inventory.

	The client draws whatever query() returns. Salvage and equip still go
	through the server. This module only decides which rows are visible and
	how a selected piece lines up against the one already worn.
]]

local ChestConfig = require("./ChestConfig")
local ItemBases = require("./ItemBases")
local Materials = require("./Materials")
local Pools = require("./Pools")
local Rarities = require("./Rarities")
local Schema = require("./Schema")
local Stats = require("./Stats")

local InventoryView = {}

export type Query = {
	tab: string,
	rarities: { [string]: boolean },
	realm: string?,
	slot: string?,
	sockets: number?,
	socketsAtLeast: number?,
	equipped: string,
	locked: string,
	search: string,
	sort: string,
	now: number,
}

export type Row = {
	id: string,
	kind: string,
	name: string,
	rarity: string,
	realm: string,
	slot: string?,
	sockets: number,
	equipped: boolean,
	locked: boolean,
	favorite: boolean,
	power: number,
	obtainedAt: number,
	count: number,
	item: any?,
}

export type CompareLine = {
	id: string,
	name: string,
	yours: string,
	theirs: string,
	delta: string,
}

InventoryView.TABS = { "weapons", "armor", "accessories", "pets", "materials", "items", "chests" }

InventoryView.SORTS = { "power", "rarity", "newest", "name" }

local STAT_ORDER = {
	"damage",
	"attack_speed",
	"crit_chance",
	"crit_damage",
	"health",
	"defense",
	"pet_damage",
	"pet_health",
}

local function rarityRank(name: string): number
	local rank = Rarities.INDEX[name]
	if type(rank) ~= "number" then
		return 0
	end
	return rank
end

function InventoryView.defaultQuery(): Query
	return {
		tab = "weapons",
		rarities = {},
		realm = nil,
		slot = nil,
		sockets = nil,
		socketsAtLeast = nil,
		equipped = "all",
		locked = "all",
		search = "",
		sort = "power",
		now = 0,
	}
end

function InventoryView.slotChoices(tab: string): { string }
	if tab == "weapons" then
		return { "sword", "greatsword", "bow", "staff", "dagger", "hammer" }
	end
	if tab == "armor" then
		return { "helm", "chest", "legs", "boots" }
	end
	if tab == "accessories" then
		return { "ring", "amulet", "charm" }
	end
	return {}
end

function InventoryView.emptyText(tab: string): string
	if tab == "weapons" then
		return "No weapons yet. Crack a shard in the Armory."
	end
	if tab == "armor" then
		return "No armor yet."
	end
	if tab == "accessories" then
		return "No rings, amulets, or charms yet."
	end
	if tab == "pets" then
		return "No pets yet. Crack a shard in the Pet Garden."
	end
	if tab == "materials" then
		return "No materials yet."
	end
	if tab == "chests" then
		return "No chests yet. Daily login, Rootvault, and Verdant enemies can drop one."
	end
	return "No consumables, scrolls, or boosts."
end

function InventoryView.powerOf(item: any): number
	if type(item) ~= "table" then
		return 0
	end
	local quality = item.quality
	if type(quality) ~= "number" or quality ~= quality then
		quality = 0
	end
	quality = math.clamp(quality, 0, 1)
	local stars = item.stars
	if type(stars) ~= "number" or stars ~= stars then
		stars = 0
	end
	return rarityRank(tostring(item.rarity)) * 1000 + quality * 100 + stars * 10
end

function InventoryView.realmOf(item: any): string
	if type(item) ~= "table" then
		return ""
	end
	if type(item.poolId) == "string" then
		local pool = Pools.get(item.poolId)
		if pool ~= nil then
			return pool.name
		end
	end
	local ascension = 0
	if type(item.templateId) == "string" then
		local base = ItemBases.get(item.templateId)
		if base ~= nil then
			ascension = base.ascension
		end
	end
	return Materials.realmForAscension(ascension)
end

function InventoryView.salvageBlock(profile: any, item: any): string?
	if type(item) ~= "table" then
		return "You do not have that item."
	end
	if item.kind ~= "Weapon" and item.kind ~= "Armor" then
		return "Only weapons and armor can be salvaged."
	end
	if item.locked == true then
		return "That item is locked."
	end
	if
		type(profile) == "table"
		and type(item.uid) == "string"
		and Schema.isEquipped(profile, item.uid)
	then
		return "Unequip it before salvaging."
	end
	return nil
end

local function wornSet(profile: any): { [string]: boolean }
	local worn: { [string]: boolean } = {}
	local equipped = if type(profile) == "table" and type(profile.equipped) == "table"
		then profile.equipped
		else {}
	if type(equipped.weapon) == "string" then
		worn[equipped.weapon] = true
	end
	if type(equipped.pet) == "string" then
		worn[equipped.pet] = true
	end
	if type(equipped.armor) == "table" then
		for _, uid in pairs(equipped.armor) do
			if type(uid) == "string" then
				worn[uid] = true
			end
		end
	end
	if type(equipped.accessories) == "table" then
		for _, uid in pairs(equipped.accessories) do
			if type(uid) == "string" then
				worn[uid] = true
			end
		end
	end
	return worn
end

local function gearRow(item: any, equipped: boolean): Row?
	if type(item) ~= "table" or type(item.uid) ~= "string" or type(item.name) ~= "string" then
		return nil
	end
	local slot = nil
	if type(item.slot) == "string" and item.slot ~= "" then
		slot = item.slot
	elseif type(item.weaponType) == "string" and item.weaponType ~= "" then
		slot = item.weaponType
	end
	local sockets = item.sockets
	if type(sockets) ~= "number" or sockets ~= sockets or sockets < 0 then
		sockets = 0
	end
	local obtained = item.obtainedAt
	if type(obtained) ~= "number" or obtained ~= obtained then
		obtained = 0
	end
	return {
		id = item.uid,
		kind = tostring(item.kind),
		name = item.name,
		rarity = tostring(item.rarity or "Common"),
		realm = InventoryView.realmOf(item),
		slot = slot,
		sockets = math.floor(sockets),
		equipped = equipped,
		locked = item.locked == true,
		favorite = item.favorite == true,
		power = InventoryView.powerOf(item),
		obtainedAt = obtained,
		count = 1,
		item = item,
	}
end

local function pushGear(rows: { Row }, bag: any, worn: { [string]: boolean })
	if type(bag) ~= "table" then
		return
	end
	for _, item in pairs(bag) do
		if type(item) == "table" and type(item.uid) == "string" then
			local row = gearRow(item, worn[item.uid] == true)
			if row ~= nil then
				table.insert(rows, row)
			end
		end
	end
end

local function materialRows(profile: any, scrolls: boolean): { Row }
	local rows = {}
	local bag = if type(profile) == "table" then profile.materials else nil
	if type(bag) ~= "table" then
		return rows
	end
	for _, materialId in ipairs(Materials.ORDER) do
		local definition = Materials.DEFS[materialId]
		local count = bag[materialId]
		if type(count) == "number" and count > 0 then
			local isScroll = definition.grade == "scroll"
			if isScroll == scrolls then
				table.insert(rows, {
					id = "material:" .. materialId,
					kind = if isScroll then "Scroll" else "Material",
					name = definition.name,
					rarity = Materials.rarityName(materialId),
					realm = definition.realm,
					slot = nil,
					sockets = 0,
					equipped = false,
					locked = false,
					favorite = false,
					power = count,
					obtainedAt = 0,
					count = count,
					item = nil,
				})
			end
		end
	end
	return rows
end

local function itemRows(profile: any, now: number): { Row }
	local rows = materialRows(profile, true)
	local consumables = if type(profile) == "table" then profile.consumables else nil
	local tonics = if type(consumables) == "table" then consumables[Materials.TONIC_ID] else 0
	if type(tonics) == "number" and tonics > 0 then
		table.insert(rows, {
			id = "consumable:" .. Materials.TONIC_ID,
			kind = "Consumable",
			name = Materials.TONIC_NAME,
			rarity = "Common",
			realm = "Verdant Wilds",
			slot = nil,
			sockets = 0,
			equipped = false,
			locked = false,
			favorite = false,
			power = tonics,
			obtainedAt = 0,
			count = tonics,
			item = nil,
		})
	end
	local luck = if type(profile) == "table" then profile.luckBoost else 0
	if type(luck) == "number" and luck > 0 then
		table.insert(rows, {
			id = "boost:luck",
			kind = "Boost",
			name = "Luck Boost",
			rarity = "Rare",
			realm = "",
			slot = nil,
			sockets = 0,
			equipped = false,
			locked = false,
			favorite = false,
			power = luck,
			obtainedAt = 0,
			count = 1,
			item = nil,
		})
	end
	local untilTime = if type(profile) == "table" then profile.forgeBoostUntil else 0
	if type(untilTime) == "number" and untilTime > now then
		table.insert(rows, {
			id = "boost:forge",
			kind = "Boost",
			name = "Forge Boost",
			rarity = "Epic",
			realm = "",
			slot = nil,
			sockets = 0,
			equipped = false,
			locked = false,
			favorite = false,
			power = 1,
			obtainedAt = untilTime,
			count = 1,
			item = nil,
		})
	end
	return rows
end

local function tabKind(tab: string): string?
	if tab == "weapons" then
		return "Weapon"
	end
	if tab == "armor" then
		return "Armor"
	end
	if tab == "accessories" then
		return "Accessory"
	end
	if tab == "pets" then
		return "Pet"
	end
	return nil
end

local function raritySelected(rarities: { [string]: boolean }): boolean
	for _, on in pairs(rarities) do
		if on == true then
			return true
		end
	end
	return false
end

local function chestRows(profile: any): { Row }
	local rows = {}
	local bag = if type(profile) == "table" then profile.chests else nil
	for index, tier in ipairs(ChestConfig.TIERS) do
		local count = 0
		if type(bag) == "table" and type(bag[tier]) == "number" then
			count = bag[tier]
		end
		table.insert(rows, {
			id = "chest:" .. tier,
			kind = "Chest",
			name = tier .. " Chest",
			rarity = tier,
			realm = "",
			slot = nil,
			sockets = 0,
			equipped = false,
			locked = false,
			favorite = false,
			power = index,
			obtainedAt = index,
			count = count,
			item = nil,
		})
	end
	return rows
end

local function matches(row: Row, query: Query): boolean
	if row.kind == "Chest" then
		local needle = string.lower(query.search or "")
		if needle ~= "" and string.find(string.lower(row.name), needle, 1, true) == nil then
			return false
		end
		return true
	end
	if raritySelected(query.rarities) and query.rarities[row.rarity] ~= true then
		return false
	end
	if type(query.realm) == "string" and query.realm ~= "" and row.realm ~= query.realm then
		return false
	end
	if type(query.slot) == "string" and query.slot ~= "" and row.slot ~= query.slot then
		return false
	end
	if query.sockets ~= nil and row.sockets ~= query.sockets then
		return false
	end
	if query.socketsAtLeast ~= nil and row.sockets < query.socketsAtLeast then
		return false
	end
	if query.equipped == "equipped" and not row.equipped then
		return false
	end
	if query.equipped == "unequipped" and row.equipped then
		return false
	end
	if query.locked == "locked" and not row.locked then
		return false
	end
	if query.locked == "unlocked" and row.locked then
		return false
	end
	local needle = string.lower(query.search or "")
	if needle ~= "" and string.find(string.lower(row.name), needle, 1, true) == nil then
		return false
	end
	return true
end

local function byName(a: Row, b: Row): boolean
	local left = string.lower(a.name)
	local right = string.lower(b.name)
	if left ~= right then
		return left < right
	end
	return a.id < b.id
end

function InventoryView.query(profile: any, query: Query): { Row }
	local pool: { Row } = {}
	local kind = tabKind(query.tab)
	if kind ~= nil then
		local worn = wornSet(profile)
		if kind == "Pet" then
			local pets = if type(profile) == "table" then profile.pets else nil
			pushGear(pool, pets, worn)
		else
			local bag = if type(profile) == "table" then profile.inventory else nil
			pushGear(pool, bag, worn)
		end
		local filtered = {}
		for _, row in ipairs(pool) do
			if row.kind == kind then
				table.insert(filtered, row)
			end
		end
		pool = filtered
	elseif query.tab == "materials" then
		pool = materialRows(profile, false)
	elseif query.tab == "items" then
		pool = itemRows(profile, query.now or 0)
	elseif query.tab == "chests" then
		pool = chestRows(profile)
	end

	local rows = {}
	for _, row in ipairs(pool) do
		if matches(row, query) then
			table.insert(rows, row)
		end
	end

	table.sort(rows, function(a, b)
		if query.sort == "name" then
			return byName(a, b)
		end
		if query.sort == "newest" then
			if a.obtainedAt ~= b.obtainedAt then
				return a.obtainedAt > b.obtainedAt
			end
			return byName(a, b)
		end
		if query.sort == "rarity" then
			local left = rarityRank(a.rarity)
			local right = rarityRank(b.rarity)
			if left ~= right then
				return left > right
			end
			return byName(a, b)
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		return byName(a, b)
	end)
	return rows
end

function InventoryView.counterpart(profile: any, item: any): any?
	if type(profile) ~= "table" or type(item) ~= "table" or type(profile.equipped) ~= "table" then
		return nil
	end
	local equipped = profile.equipped
	local uid = nil
	if item.kind == "Weapon" then
		uid = equipped.weapon
	elseif item.kind == "Pet" then
		uid = equipped.pet
	elseif
		item.kind == "Armor"
		and type(item.slot) == "string"
		and type(equipped.armor) == "table"
	then
		uid = equipped.armor[item.slot]
	elseif
		item.kind == "Accessory"
		and type(item.slot) == "string"
		and type(equipped.accessories) == "table"
	then
		uid = equipped.accessories[item.slot]
	end
	if type(uid) ~= "string" or uid == item.uid then
		return nil
	end
	local found = Schema.findItem(profile, uid)
	return found
end

local function statValue(item: any, statId: string): number?
	if type(item) ~= "table" or type(item.stats) ~= "table" then
		return nil
	end
	for _, stat in ipairs(item.stats) do
		if type(stat) == "table" and stat.id == statId and type(stat.value) == "number" then
			return stat.value
		end
	end
	return nil
end

local function formatStat(statId: string, value: number?): string
	if value == nil then
		return "—"
	end
	return Stats.formatValue({
		id = statId,
		name = "",
		value = value,
		min = 0,
		max = 0,
		unit = "flat",
		roll = 0,
	})
end

function InventoryView.compare(yours: any, theirs: any): { CompareLine }
	local lines = {}
	if type(yours) ~= "table" or type(theirs) ~= "table" then
		return lines
	end
	local seen: { [string]: boolean } = {}
	local order = table.clone(STAT_ORDER)
	local function consider(item: any)
		if type(item) ~= "table" or type(item.stats) ~= "table" then
			return
		end
		for _, stat in ipairs(item.stats) do
			if type(stat) == "table" and type(stat.id) == "string" and seen[stat.id] ~= true then
				seen[stat.id] = true
				local known = false
				for _, id in ipairs(order) do
					if id == stat.id then
						known = true
					end
				end
				if not known then
					table.insert(order, stat.id)
				end
			end
		end
	end
	consider(yours)
	consider(theirs)
	for _, statId in ipairs(order) do
		local left = statValue(yours, statId)
		local right = statValue(theirs, statId)
		if left ~= nil or right ~= nil then
			local definition = Stats.DEFS[statId]
			local delta = ""
			if left ~= nil and right ~= nil then
				local gap = left - right
				local shown = formatStat(statId, math.abs(gap))
				if gap > 0 then
					delta = "+" .. shown
				elseif gap < 0 then
					delta = "-" .. shown
				else
					delta = "0"
				end
			end
			table.insert(lines, {
				id = statId,
				name = if definition ~= nil then definition.name else statId,
				yours = formatStat(statId, left),
				theirs = formatStat(statId, right),
				delta = delta,
			})
		end
	end
	return lines
end

function InventoryView.statLines(item: any): { string }
	local lines = {}
	if type(item) ~= "table" or type(item.stats) ~= "table" then
		return lines
	end
	for _, stat in ipairs(item.stats) do
		if type(stat) == "table" and type(stat.id) == "string" and type(stat.value) == "number" then
			local definition = Stats.DEFS[stat.id]
			local name = if type(stat.name) == "string" and stat.name ~= ""
				then stat.name
				elseif definition ~= nil then definition.name
				else stat.id
			table.insert(lines, name .. "  " .. formatStat(stat.id, stat.value))
		end
	end
	return lines
end

return InventoryView
