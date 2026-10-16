--!strict

--[[
	Verdant Relic Sets. Heartwood Hard drops one 4-piece set per class.

	Pieces are raid-drop only. They are tradeable on the Market Board
	and not bound. stamp sets bound = false and tradeable = true on a
	copy and does not write the input. Two pieces unlock a 2-piece
	bonus. Four unlock that and a 4-piece bonus. The bonuses change how
	the class plays. They do not add flat damage, health, or defense,
	and nothing here costs Robux.

	The server passes plain tables. This module does not read profiles,
	grant loot, roll drops, or touch DataStores and remotes. Class ids
	match Classes. Slots match Schema.ARMOR_SLOTS.

	count / active read an equipped loadout: a list of piece ids or
	items, a helm/chest/legs/boots map, or `{ armor = { helm = id } }`.
	A piece in the wrong slot of a map does not count. Duplicates and
	other classes do not count. An inventory map is not a loadout.

	setPct reads what you own. Pass a piece count, a list, or an
	inventory map (`{ [uid] = item }`). A bare id string is 0. The
	result is an integer 0, 25, 50, 75, or 100 for the fullest set.
]]

local RelicSets = {}

RelicSets.PIECE_COUNT = 4
RelicSets.RAID = "heartwood"
RelicSets.DIFFICULTY = "hard"
RelicSets.SOURCE = "heartwood_hard"

local CLASS_IDS = { "warden", "tidecaller", "forgeborn", "frostblade", "voidcaster" }
local SLOT_LIST = { "helm", "chest", "legs", "boots" }
local SLOT_OK: { [string]: boolean } = {}
for _, slot in ipairs(SLOT_LIST) do
	SLOT_OK[slot] = true
end
table.freeze(CLASS_IDS)
table.freeze(SLOT_LIST)
table.freeze(SLOT_OK)

RelicSets.CLASS_IDS = CLASS_IDS
RelicSets.SLOTS = SLOT_LIST

export type Piece = {
	id: string,
	name: string,
	classId: string,
	setId: string,
	slot: string,
	kind: string,
	rarity: string,
	source: string,
	bound: boolean,
	tradeable: boolean,
}

export type Bonus = {
	id: string,
	name: string,
	pieces: number,
	skillId: string,
	note: string,
	radius: number?,
	interval: number?,
	duration: number?,
	share: number?,
	shareOf: string?,
	cleanses: number?,
	slow: number?,
	angle: number?,
	chill: number?,
	distance: number?,
	spread: number?,
}

export type SetDef = {
	id: string,
	name: string,
	classId: string,
	source: string,
	pieces: { Piece },
	bonuses: { Bonus },
}

local function makePiece(classId: string, setId: string, slot: string, name: string): Piece
	return {
		id = setId .. "_" .. slot,
		name = name,
		classId = classId,
		setId = setId,
		slot = slot,
		kind = "Armor",
		rarity = "Epic",
		source = RelicSets.SOURCE,
		bound = true,
		tradeable = false,
	}
end

local SETS: { SetDef } = {
	{
		id = "verdant_warden",
		name = "Heartwood Bulwark",
		classId = "warden",
		source = RelicSets.SOURCE,
		pieces = {
			makePiece("warden", "verdant_warden", "helm", "Bulwark Mask"),
			makePiece("warden", "verdant_warden", "chest", "Bulwark Cuirass"),
			makePiece("warden", "verdant_warden", "legs", "Bulwark Greaves"),
			makePiece("warden", "verdant_warden", "boots", "Bulwark Treads"),
		},
		bonuses = {
			{
				id = "planted_taunt",
				name = "Planted Taunt",
				pieces = 2,
				skillId = "deep_roots",
				note = "While you stand still, taunt foes within 10 studs every 6 seconds. No damage.",
				radius = 10,
				interval = 6,
			},
			{
				id = "barkskin_share",
				name = "Barkskin Share",
				pieces = 4,
				skillId = "barkskin",
				note = "Barkskin also shields allies within 12 for 8% of your max HP. Yours is unchanged.",
				radius = 12,
				share = 0.08,
				shareOf = "casterMaxHp",
			},
		},
	},
	{
		id = "verdant_tidecaller",
		name = "Springwell",
		classId = "tidecaller",
		source = RelicSets.SOURCE,
		pieces = {
			makePiece("tidecaller", "verdant_tidecaller", "helm", "Springwell Circlet"),
			makePiece("tidecaller", "verdant_tidecaller", "chest", "Springwell Robe"),
			makePiece("tidecaller", "verdant_tidecaller", "legs", "Springwell Leggings"),
			makePiece("tidecaller", "verdant_tidecaller", "boots", "Springwell Sandals"),
		},
		bonuses = {
			{
				id = "pool_cleanse",
				name = "Pool Cleanse",
				pieces = 2,
				skillId = "healing_pool",
				note = "The first ally who enters Healing Pool is cleansed once.",
				cleanses = 1,
			},
			{
				id = "ebb_jump",
				name = "Ebb Jump",
				pieces = 4,
				skillId = "ebb_flow",
				note = "Your overflow shield jumps to the lowest ally within 16. You do not keep it.",
				radius = 16,
			},
		},
	},
	{
		id = "verdant_forgeborn",
		name = "Kilnheart",
		classId = "forgeborn",
		source = RelicSets.SOURCE,
		pieces = {
			makePiece("forgeborn", "verdant_forgeborn", "helm", "Kilnheart Helm"),
			makePiece("forgeborn", "verdant_forgeborn", "chest", "Kilnheart Plate"),
			makePiece("forgeborn", "verdant_forgeborn", "legs", "Kilnheart Legguards"),
			makePiece("forgeborn", "verdant_forgeborn", "boots", "Kilnheart Sabatons"),
		},
		bonuses = {
			{
				id = "charge_slow",
				name = "Cinder Trail",
				pieces = 2,
				skillId = "molten_charge",
				note = "Foes in the Molten Charge trail are slowed by 20% for 2 seconds. No extra damage.",
				slow = 0.2,
				duration = 2,
			},
			{
				id = "guard_cone",
				name = "Quenched Slam",
				pieces = 4,
				skillId = "hammerfall",
				note = "After a block, the next Hammerfall within 4 seconds is a 120 degree cone of radius 8.",
				duration = 4,
				angle = 120,
				radius = 8,
			},
		},
	},
	{
		id = "verdant_frostblade",
		name = "Rimewake",
		classId = "frostblade",
		source = RelicSets.SOURCE,
		pieces = {
			makePiece("frostblade", "verdant_frostblade", "helm", "Rimewake Hood"),
			makePiece("frostblade", "verdant_frostblade", "chest", "Rimewake Coat"),
			makePiece("frostblade", "verdant_frostblade", "legs", "Rimewake Leggings"),
			makePiece("frostblade", "verdant_frostblade", "boots", "Rimewake Boots"),
		},
		bonuses = {
			{
				id = "dash_patch",
				name = "Rime Path",
				pieces = 2,
				skillId = "glacial_dash",
				note = "Glacial Dash leaves a radius 4 patch for 3 seconds. Crossing it applies 1 Chill.",
				duration = 3,
				radius = 4,
				chill = 1,
			},
			{
				id = "shatter_spread",
				name = "Shatter Spread",
				pieces = 4,
				skillId = "shatter",
				note = "Shatter applies 1 Chill to other foes within 8 studs. No extra crit damage.",
				chill = 1,
				radius = 8,
			},
		},
	},
	{
		id = "verdant_voidcaster",
		name = "Riftweave",
		classId = "voidcaster",
		source = RelicSets.SOURCE,
		pieces = {
			makePiece("voidcaster", "verdant_voidcaster", "helm", "Riftweave Cowl"),
			makePiece("voidcaster", "verdant_voidcaster", "chest", "Riftweave Mantle"),
			makePiece("voidcaster", "verdant_voidcaster", "legs", "Riftweave Trousers"),
			makePiece("voidcaster", "verdant_voidcaster", "boots", "Riftweave Steps"),
		},
		bonuses = {
			{
				id = "blink_pull",
				name = "Blink Pull",
				pieces = 2,
				skillId = "blink",
				note = "Blink pulls foes within 8 studs, 4 studs toward the spot you left. No damage.",
				radius = 8,
				distance = 4,
			},
			{
				id = "unstable_jump",
				name = "Unstable Hex",
				pieces = 4,
				skillId = "hex",
				note = "While Unstable, Hex jumps to 1 foe within 12 when the hexed foe dies. No Void spent.",
				spread = 1,
				radius = 12,
			},
		},
	},
}

local byClass: { [string]: SetDef } = {}
local bySet: { [string]: SetDef } = {}
local byPiece: { [string]: Piece } = {}

local function freezeSet(setDef: SetDef)
	for _, row in ipairs(setDef.pieces) do
		table.freeze(row)
	end
	table.freeze(setDef.pieces)
	for _, row in ipairs(setDef.bonuses) do
		table.freeze(row)
	end
	table.freeze(setDef.bonuses)
	table.freeze(setDef)
end

for _, setDef in ipairs(SETS) do
	byClass[setDef.classId] = setDef
	bySet[setDef.id] = setDef
	for _, row in ipairs(setDef.pieces) do
		byPiece[row.id] = row
	end
	freezeSet(setDef)
end
table.freeze(SETS)

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function idFrom(entry: any): string?
	if type(entry) == "string" then
		if entry == "" then
			return nil
		end
		return entry
	end
	if type(entry) ~= "table" then
		return nil
	end
	if type(entry.templateId) == "string" and entry.templateId ~= "" then
		return entry.templateId
	end
	if type(entry.pieceId) == "string" and entry.pieceId ~= "" then
		return entry.pieceId
	end
	if type(entry.id) == "string" and entry.id ~= "" then
		return entry.id
	end
	return nil
end

local function addId(seen: { [string]: boolean }, id: string?, slot: string?)
	if id == nil then
		return
	end
	if slot ~= nil then
		local row = byPiece[id]
		if row ~= nil and row.slot ~= slot then
			return
		end
	end
	seen[id] = true
end

-- ownedBag also reads an inventory map. count() leaves that off so a
-- piece in the bag does not count as worn.
local function collect(equipped: any, ownedBag: boolean): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	if type(equipped) ~= "table" then
		return seen
	end
	for _, entry in ipairs(equipped) do
		addId(seen, idFrom(entry), nil)
	end
	local armor = equipped.armor
	if type(armor) == "table" then
		for slot, value in pairs(armor) do
			if SLOT_OK[slot] == true then
				addId(seen, idFrom(value), slot)
			end
		end
	end
	for slot, value in pairs(equipped) do
		if SLOT_OK[slot] == true then
			addId(seen, idFrom(value), slot)
		end
	end
	if ownedBag then
		for key, value in pairs(equipped) do
			if
				type(key) == "string"
				and SLOT_OK[key] ~= true
				and key ~= "armor"
				and type(value) == "table"
			then
				addId(seen, idFrom(value), nil)
			end
		end
	end
	return seen
end

local function classCount(classId: any, seen: { [string]: boolean }): number
	local setDef = RelicSets.get(classId)
	if setDef == nil then
		return 0
	end
	local total = 0
	for id in pairs(seen) do
		local row = byPiece[id]
		if row ~= nil and row.classId == setDef.classId then
			total += 1
		end
	end
	if total > RelicSets.PIECE_COUNT then
		return RelicSets.PIECE_COUNT
	end
	return total
end

local function pctFromPieces(pieces: number): number
	local whole = pieces
	if whole < 0 then
		whole = 0
	end
	if whole > RelicSets.PIECE_COUNT then
		whole = RelicSets.PIECE_COUNT
	end
	return math.floor(whole * 100 / RelicSets.PIECE_COUNT)
end

local function pieceRow(item: any): Piece?
	if type(item) == "string" then
		return byPiece[item]
	end
	local id = idFrom(item)
	if id == nil then
		return nil
	end
	return byPiece[id]
end

function RelicSets.all(): { SetDef }
	return SETS
end

function RelicSets.get(classId: any): SetDef?
	if type(classId) ~= "string" then
		return nil
	end
	return byClass[classId]
end

function RelicSets.piece(pieceId: any): Piece?
	if type(pieceId) ~= "string" then
		return nil
	end
	return byPiece[pieceId]
end

function RelicSets.count(classId: any, equipped: any): number
	return classCount(classId, collect(equipped, false))
end

function RelicSets.active(classId: any, equipped: any): { Bonus }
	local setDef = RelicSets.get(classId)
	if setDef == nil then
		return {}
	end
	local total = RelicSets.count(classId, equipped)
	local picked: { Bonus } = {}
	for _, bonus in ipairs(setDef.bonuses) do
		if total >= bonus.pieces then
			table.insert(picked, bonus)
		end
	end
	table.sort(picked, function(left, right)
		if left.pieces ~= right.pieces then
			return left.pieces < right.pieces
		end
		return left.id < right.id
	end)
	return picked
end

function RelicSets.setPct(owned: any): number
	if owned == nil then
		return 0
	end
	if type(owned) == "number" then
		local value = finite(owned)
		if value == nil then
			return 0
		end
		local pieces = math.floor(value)
		return pctFromPieces(pieces)
	end
	if type(owned) ~= "table" then
		return 0
	end
	local perSet: { [string]: number } = {}
	local best = 0
	for id in pairs(collect(owned, true)) do
		local row = byPiece[id]
		if row ~= nil then
			local nextCount = (perSet[row.setId] or 0) + 1
			perSet[row.setId] = nextCount
			if nextCount > best then
				best = nextCount
			end
		end
	end
	return pctFromPieces(best)
end

local function namesRelic(value: any): boolean
	if type(value) ~= "string" or value == "" then
		return false
	end
	return byPiece[value] ~= nil or bySet[value] ~= nil
end

-- A piece id, a set id, or an item whose templateId, id, pieceId, or
-- setId names one. bound is not the test. A starter with bound = true
-- is not a relic.
function RelicSets.isRelic(item: any): boolean
	if type(item) == "string" then
		return namesRelic(item)
	end
	if type(item) ~= "table" then
		return false
	end
	if namesRelic(item.templateId) then
		return true
	end
	if namesRelic(item.id) then
		return true
	end
	if namesRelic(item.pieceId) then
		return true
	end
	if namesRelic(item.setId) then
		return true
	end
	return false
end

-- A new table when `item` is a relic. The input is not written.
-- The copy is tradeable and not bound. Anything else is returned as it was.
function RelicSets.stamp(item: any): any
	if type(item) ~= "table" or not RelicSets.isRelic(item) then
		return item
	end
	local copy = table.clone(item)
	copy.bound = false
	copy.tradeable = true
	local row = pieceRow(item)
	if row ~= nil then
		copy.setId = row.setId
		copy.slot = row.slot
		copy.classId = row.classId
		if type(copy.kind) ~= "string" then
			copy.kind = row.kind
		end
		if type(copy.rarity) ~= "string" then
			copy.rarity = row.rarity
		end
		if type(copy.source) ~= "string" then
			copy.source = row.source
		end
	end
	return copy
end

return RelicSets
