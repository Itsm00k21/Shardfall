--!strict

--[[
	The player profile shape, version 26.

	DataService stores whatever migrate() returns. Adding a field later:
	  1. Bump Schema.VERSION.
	  2. Add a default in template().
	  3. Write a `if version < N` step in migrate() that fills existing saves.
	reconcile() only fills missing keys, so it will not reset gold or wipe
	an inventory that is already there.

	Profiles are plain tables: no Color3, no Instance, no functions. That is
	what DataStores can save and what a RemoteEvent can send.

	Stage B adds gearEssence, autoSalvage, and autoSalvageRarity without a
	version bump. schemaVersion stays 26 so a v26 server still loads the
	save. #381's migration list is not on this base. When it lands, register
	one copy-first step for those three fields. Do not publish a v27
	document before that list exists: a higher version looks newer, and a
	v26 server refuses the load. #387 writes the same gearEssence field.
]]

local ActionSlots = require("./ActionSlots")
local Audio = require("./Audio")
local Classes = require("./Classes")
local EquipSlots = require("./Config/EquipSlots")
local ShardCoreConfig = require("./Config/ShardCore")
local CraftingLevel = require("./CraftingLevel")
local Materials = require("./Materials")
local Loops = require("./Loops")
local Progression = require("./Progression")
local Quality = require("./Quality")
local Settings = require("./Settings")
local Stars = require("./Stars")
local StarterGoalPay = require("./StarterGoalPay")
local Travel = require("./Travel")

local Schema = {}

local function firstSessionKit()
	return require("./FirstSessionKit")
end

-- Frozen Codex ids. A true flag sticks. Only boolean true counts.
local CODEX_IDS = {
	"attack",
	"dodge",
	"perfect",
	"skills",
	"telegraphs",
	"shards",
	"doors",
	"pets",
	"crafting",
	"rarity",
}

local function readCodexFlags(value: any): { [string]: boolean }
	local source = nil
	if type(value) == "table" and type(value.unlocked) == "table" then
		source = value.unlocked
	end
	local unlocked = {}
	for _, id in ipairs(CODEX_IDS) do
		unlocked[id] = source ~= nil and source[id] == true
	end
	return unlocked
end

local function blankCodex(): { unlocked: { [string]: boolean } }
	return { unlocked = readCodexFlags(nil) }
end

local function callRefused(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	if value.productId ~= nil or value.robux ~= nil or value.cost ~= nil or value.skip ~= nil then
		return true
	end
	if
		value.userId ~= nil
		or value.UserId ~= nil
		or value.playerId ~= nil
		or value.PlayerId ~= nil
	then
		return true
	end
	if value.guildId ~= nil or value.GuildId ~= nil then
		return true
	end
	return false
end

-- A failed unlock keeps the previous flags. A success stores that state.
-- A product id, Robux, cost, skip, user id, or guild id is a failure.
-- Neither call writes the arguments. Nothing here grants keys or gold.
function Schema.applyCodex(saved: any, result: any): { unlocked: { [string]: boolean } }
	local accepted = type(result) == "table"
		and result.ok == true
		and type(result.state) == "table"
		and not callRefused(result)
		and not callRefused(result.state)
	if accepted then
		return { unlocked = readCodexFlags(result.state) }
	end
	return { unlocked = readCodexFlags(saved) }
end

local function wholeGrove(value: any): number
	if type(value) ~= "number" or value ~= value or value >= math.huge or value <= -math.huge then
		return 0
	end
	local floored = math.floor(value)
	if floored < 0 then
		return 0
	end
	return floored
end

local function blankGrove()
	return {
		hits = 0,
		damage = 0,
		healing = 0,
		up = true,
		dummy = false,
		dodge = false,
		colors = {
			red = false,
			yellow = false,
			purple = false,
			blue = false,
		},
		room = false,
		cosmetic = false,
	}
end

local function readGrove(value: any)
	if type(value) ~= "table" then
		return blankGrove()
	end
	local colors = if type(value.colors) == "table" then value.colors else nil
	return {
		hits = wholeGrove(value.hits),
		damage = wholeGrove(value.damage),
		healing = wholeGrove(value.healing),
		up = value.up ~= false,
		dummy = value.dummy == true,
		dodge = value.dodge == true,
		colors = {
			red = colors ~= nil and colors.red == true,
			yellow = colors ~= nil and colors.yellow == true,
			purple = colors ~= nil and colors.purple == true,
			blue = colors ~= nil and colors.blue == true,
		},
		room = value.room == true,
		cosmetic = value.cosmetic == true,
	}
end

-- A failed grove call keeps the previous record. Keys and gold are not stored.
-- A product id, Robux, cost, skip, user id, or guild id is a failure.
function Schema.applyGrove(saved: any, result: any)
	local accepted = type(result) == "table"
		and result.ok == true
		and type(result.state) == "table"
		and not callRefused(result)
		and not callRefused(result.state)
	if accepted then
		return readGrove(result.state)
	end
	return readGrove(saved)
end

Schema.VERSION = 26
Schema.STARTER_TOKENS = 10
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
	stars: number?,
	starProgress: number?,
	perks: { string }?,
	locked: boolean?,
	favorite: boolean?,
	sockets: number?,
	upgrade: number?,
}

export type PityState = {
	rollsSinceLegendary: number,
	totalRolls: number,
}

export type Equipped = {
	weapon: string?,
	pet: string?,
	armor: { [string]: string },
	accessories: { [string]: string },
}

Schema.ARMOR_SLOTS = {
	helm = true,
	chest = true,
	legs = true,
	boots = true,
}

Schema.ACCESSORY_SLOTS = {
	ring = true,
	amulet = true,
	charm = true,
}

export type ProfileData = {
	schemaVersion: number,
	level: number,
	xp: number,
	ascension: number,
	gold: number,
	shardTokens: number,
	prismTokens: number,
	shardLuck: number,
	luckBoost: number,
	inventory: { [string]: Item },
	pets: { [string]: Item },
	pity: { [string]: PityState },
	equipped: Equipped,
	gearEssence: number,
	materials: { [string]: number },
	consumables: { [string]: number },
	vouchers: { [string]: number },
	craftingLevel: number,
	craftingXp: number,
	craftingMilestones: { number },
	milestoneTable: { any },
	forgeBoostUntil: number,
	inventoryBonus: number,
	petSlotBonus: number,
	waystones: { [string]: boolean },
	lastTravel: number,
	travelPass: boolean,
	graphicsQuality: string,
	shardRolls: number,
	sinceEpic: number,
	sinceLegendary: number,
	quickRoll: boolean,
	quickRollUntil: number,
	vip: boolean,
	shake: boolean,
	chests: { [string]: number },
	shardKeys: number,
	shardDust: number,
	rareChestsSinceEpic: number,
	epicChestsSinceLegendary: number,
	lastLoginDay: number,
	loginStreak: number,
	lastDailyBossDay: number,
	lastWeeklyBossWeek: number,
	chestDuplicates: string,
	chestSalvageBelow: string,
	autoSalvage: boolean,
	autoSalvageRarity: string,
	pendingChest: any,
	musicVolume: number,
	sfxVolume: number,
	classId: string,
	classXp: { [string]: number },
	classTalent: { [string]: string },
	onboardStep: string,
	onboardDone: boolean,
	restCharges: number,
	welcomeCharges: number,
	lastSeen: number,
	milestoneTitle: string,
	welcomeNote: string,
	gems: number,
	eventTokens: number,
	ledger: { any },
	receipts: { [string]: boolean },
	eggs: number,
	companions: { any },
	dailies: { any },
	weekly: { any },
	weeklyWeek: number,
	board: { any },
	boardLines: number,
	passXp: number,
	passClaimed: number,
	firstClearDay: number,
	nightmareBest: number,
	dailyBonusDay: number,
	dailyRerollDay: number,
	raidMarks: number,
	raidMarksEarned: number,
	raidMarkWeek: number,
	raidLock: { [string]: number },
	raidPity: { [string]: number },
	raidStory: boolean,
	raidEcho: number,
	raidBest: number,
	tradeDay: number,
	tradeValueToday: number,
	tradeLocked: boolean,
	tradeFlagged: boolean,
	verifiedTrader: boolean,
	tradeCleanSince: number,
	tradeHandoff: boolean,
	uiSettings: Settings.Data,
	starterGoals: any,
	firstSession: any,
	actionBars: { [string]: any },
	codex: { unlocked: { [string]: boolean } },
	trainingGrove: { [string]: any },
	-- [ECHO hook] Additive. schemaVersion stays 26. item.upgrade already exists.
	equipLoadout: { [string]: string },
	gearEssence: number,
	-- [ECHO hook] Core level per weapon uid. Missing uid is 0. Items are not written.
	shardCores: { [string]: number },
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
		prismTokens = 0,
		shardLuck = 0,
		luckBoost = 0,
		inventory = {},
		pets = {},
		pity = {},
		equipped = {
			weapon = nil,
			pet = nil,
			armor = {},
			accessories = {},
		},
		-- [ECHO hook] Phase 2 slots. Empty until the player equips.
		equipLoadout = EquipSlots.empty(),
		-- [ECHO hook] Duplicate overflow record. Stage B spends it. Stage C spends it too.
		gearEssence = 0,
		-- [ECHO hook] Shard Core levels. Empty until the player feeds a weapon.
		shardCores = {},
		materials = Materials.empty(),
		consumables = { [Materials.TONIC_ID] = 0 },
		vouchers = { armory = 0, pets = 0 },
		craftingLevel = 1,
		craftingXp = 0,
		craftingMilestones = {},
		milestoneTable = CraftingLevel.copyTable(),
		forgeBoostUntil = 0,
		inventoryBonus = 0,
		petSlotBonus = 0,
		waystones = {},
		lastTravel = 0,
		travelPass = false,
		graphicsQuality = "",
		shardRolls = 0,
		sinceEpic = 0,
		sinceLegendary = 0,
		quickRoll = false,
		quickRollUntil = 0,
		vip = false,
		shake = true,
		chests = {
			Common = 0,
			Uncommon = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 0,
		},
		shardKeys = 0,
		shardDust = 0,
		rareChestsSinceEpic = 0,
		epicChestsSinceLegendary = 0,
		lastLoginDay = -1,
		loginStreak = 0,
		lastDailyBossDay = -1,
		lastWeeklyBossWeek = -1,
		chestDuplicates = "dust",
		chestSalvageBelow = "",
		-- Off until the player turns it on. Does not salvage the bag.
		autoSalvage = false,
		autoSalvageRarity = "",
		pendingChest = nil,
		musicVolume = Audio.DEFAULT_MUSIC,
		sfxVolume = Audio.DEFAULT_SFX,
		classId = "",
		classXp = {},
		classTalent = {},
		onboardStep = "open",
		onboardDone = false,
		restCharges = 0,
		welcomeCharges = 0,
		lastSeen = 0,
		milestoneTitle = "",
		welcomeNote = "",
		gems = 0,
		eventTokens = 0,
		ledger = {},
		receipts = {},
		eggs = 1,
		companions = {},
		dailies = {},
		weekly = {},
		weeklyWeek = -1,
		board = {},
		boardLines = 0,
		passXp = 0,
		passClaimed = 0,
		firstClearDay = -1,
		nightmareBest = 0,
		dailyBonusDay = -1,
		dailyRerollDay = -1,
		raidMarks = 0,
		raidMarksEarned = 0,
		raidMarkWeek = -1,
		raidLock = {},
		raidPity = {},
		raidStory = false,
		raidEcho = 0,
		raidBest = 0,
		tradeDay = 0,
		tradeValueToday = 0,
		tradeLocked = false,
		tradeFlagged = false,
		verifiedTrader = false,
		tradeCleanSince = 0,
		tradeHandoff = false,
		uiSettings = Settings.default(),
		starterGoals = StarterGoalPay.blank(),
		firstSession = firstSessionKit().blank(false),
		actionBars = ActionSlots.fresh(),
		codex = blankCodex(),
		trainingGrove = blankGrove(),
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
	return Progression.xpToNext(level)
end

local AUTO_RARITY = {
	Common = true,
	Uncommon = true,
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythic = true,
	Secret = true,
}

local function wholeNumber(value: any, fallback: number, minimum: number): number
	local numberValue = tonumber(value)
	-- Positive infinity is a number. Floor keeps it, and the next save
	-- would store inf for gold and the other wallets.
	if
		numberValue == nil
		or numberValue ~= numberValue
		or numberValue >= math.huge
		or numberValue <= -math.huge
	then
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
	-- A missing bag is a new or partial profile. A string or number is
	-- corrupt. Leave that value in place so a save cannot replace it with {}.
	if data.inventory == nil then
		data.inventory = {}
	end
	if data.pets == nil then
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
	Progression.settle(data)
	data.ascension = wholeNumber(data.ascension, 0, 0)
	data.gold = wholeNumber(data.gold, 0, 0)
	data.shardTokens = wholeNumber(data.shardTokens, Schema.STARTER_TOKENS, 0)
	data.prismTokens = wholeNumber(data.prismTokens, 0, 0)
	data.shardLuck = wholeNumber(data.shardLuck, 0, 0)
	data.luckBoost = wholeNumber(data.luckBoost, 0, 0)
	data.craftingLevel = wholeNumber(data.craftingLevel, 1, 1)
	if data.craftingLevel > CraftingLevel.MAX then
		data.craftingLevel = CraftingLevel.MAX
	end
	data.craftingXp = wholeNumber(data.craftingXp, 0, 0)
	if data.craftingLevel >= CraftingLevel.MAX then
		data.craftingXp = 0
	end
	CraftingLevel.settle(data)
	data.forgeBoostUntil = wholeNumber(data.forgeBoostUntil, 0, 0)
	data.inventoryBonus = wholeNumber(data.inventoryBonus, 0, 0)
	if data.inventoryBonus > 500 then
		data.inventoryBonus = 500
	end
	data.petSlotBonus = wholeNumber(data.petSlotBonus, 0, 0)
	if data.petSlotBonus > 5 then
		data.petSlotBonus = 5
	end
	local knownStones = {}
	for _, id in ipairs(Travel.ids()) do
		knownStones[id] = true
	end
	local stones = {}
	if type(data.waystones) == "table" then
		for id, unlocked in pairs(data.waystones) do
			if knownStones[id] == true and unlocked == true then
				stones[id] = true
			end
		end
	end
	data.waystones = stones
	data.lastTravel = wholeNumber(data.lastTravel, 0, 0)
	if data.lastTravel > os.time() then
		data.lastTravel = 0
	end
	data.travelPass = data.travelPass == true
	local quality = Quality.normalize(data.graphicsQuality)
	data.graphicsQuality = if quality == nil then "" else quality
	data.shardRolls = wholeNumber(data.shardRolls, 0, 0)
	if data.shardRolls > 1000000000 then
		data.shardRolls = 1000000000
	end
	data.sinceEpic = wholeNumber(data.sinceEpic, 0, 0)
	data.sinceLegendary = wholeNumber(data.sinceLegendary, 0, 0)
	data.quickRoll = data.quickRoll == true
	data.quickRollUntil = wholeNumber(data.quickRollUntil, 0, 0)
	data.vip = data.vip == true
	data.shake = data.shake ~= false
	data.musicVolume = Audio.clampVolume(data.musicVolume)
	data.uiSettings = Settings.normalize(data.uiSettings)
	if Classes.get(data.classId) == nil then
		data.classId = ""
	end
	local classXp = {}
	if type(data.classXp) == "table" then
		for classId, amount in pairs(data.classXp) do
			if Classes.get(classId) ~= nil then
				classXp[classId] = wholeNumber(amount, 0, 0)
			end
		end
	end
	data.classXp = classXp
	local classTalent = {}
	if type(data.classTalent) == "table" then
		for classId, talentId in pairs(data.classTalent) do
			if type(talentId) == "string" and Classes.validTalent(classId, talentId) then
				classTalent[classId] = talentId
			end
		end
	end
	data.classTalent = classTalent
	if type(data.onboardStep) ~= "string" or data.onboardStep == "" then
		data.onboardStep = "open"
	end
	data.onboardDone = data.onboardDone == true
	data.restCharges = wholeNumber(data.restCharges, 0, 0)
	data.welcomeCharges = wholeNumber(data.welcomeCharges, 0, 0)
	data.lastSeen = wholeNumber(data.lastSeen, 0, 0)
	if type(data.milestoneTitle) ~= "string" then
		data.milestoneTitle = ""
	end
	if type(data.welcomeNote) ~= "string" then
		data.welcomeNote = ""
	end
	data.gems = wholeNumber(data.gems, 0, 0)
	data.eventTokens = wholeNumber(data.eventTokens, 0, 0)
	if type(data.ledger) ~= "table" then
		data.ledger = {}
	end
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	data.eggs = wholeNumber(data.eggs, 0, 0)
	if type(data.companions) ~= "table" then
		data.companions = {}
	end
	if type(data.dailies) ~= "table" then
		data.dailies = {}
	end
	if type(data.weekly) ~= "table" then
		data.weekly = {}
	end
	if type(data.board) ~= "table" then
		data.board = {}
	end
	data.passXp = wholeNumber(data.passXp, 0, 0)
	data.passClaimed = wholeNumber(data.passClaimed, 0, 0)
	data.boardLines = wholeNumber(data.boardLines, 0, 0)
	data.nightmareBest = wholeNumber(data.nightmareBest, 0, 0)
	data.raidMarks = wholeNumber(data.raidMarks, 0, 0)
	data.raidMarksEarned = wholeNumber(data.raidMarksEarned, 0, 0)
	data.raidEcho = wholeNumber(data.raidEcho, 0, 0)
	if data.raidEcho > 5 then
		data.raidEcho = 5
	end
	data.raidBest = wholeNumber(data.raidBest, 0, 0)
	data.raidStory = data.raidStory == true
	data.tradeDay = wholeNumber(data.tradeDay, 0, 0)
	data.tradeValueToday = wholeNumber(data.tradeValueToday, 0, 0)
	data.tradeCleanSince = wholeNumber(data.tradeCleanSince, 0, 0)
	data.tradeLocked = data.tradeLocked == true
	data.tradeFlagged = data.tradeFlagged == true
	data.verifiedTrader = data.verifiedTrader == true
	data.tradeHandoff = data.tradeHandoff == true
	data.starterGoals = StarterGoalPay.normalize(data.starterGoals)
	data.firstSession = firstSessionKit().normalize(data.firstSession)
	data.actionBars = ActionSlots.reconcile(data.actionBars, data)
	data.codex = { unlocked = readCodexFlags(data.codex) }
	data.trainingGrove = readGrove(data.trainingGrove)
	if type(data.raidLock) ~= "table" then
		data.raidLock = {}
	end
	if type(data.raidPity) ~= "table" then
		data.raidPity = {}
	end
	data.sfxVolume = Audio.clampVolume(data.sfxVolume)
	if type(data.chests) ~= "table" then
		data.chests = {}
	end
	for _, tier in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }) do
		data.chests[tier] = wholeNumber(data.chests[tier], 0, 0)
		if data.chests[tier] > 999 then
			data.chests[tier] = 999
		end
	end
	data.shardKeys = wholeNumber(data.shardKeys, 0, 0)
	if data.shardKeys > 99999 then
		data.shardKeys = 99999
	end
	StarterGoalPay.collect(data)
	if data.shardKeys > 99999 then
		data.shardKeys = 99999
	end
	data.shardDust = wholeNumber(data.shardDust, 0, 0)
	if data.shardDust > 999999 then
		data.shardDust = 999999
	end
	data.rareChestsSinceEpic = wholeNumber(data.rareChestsSinceEpic, 0, 0)
	data.epicChestsSinceLegendary = wholeNumber(data.epicChestsSinceLegendary, 0, 0)
	data.loginStreak = wholeNumber(data.loginStreak, 0, 0)
	local function stamp(value: any): number
		local numberValue = tonumber(value)
		if numberValue == nil or numberValue ~= numberValue then
			return -1
		end
		return math.floor(numberValue)
	end
	data.lastLoginDay = stamp(data.lastLoginDay)
	data.lastDailyBossDay = stamp(data.lastDailyBossDay)
	data.lastWeeklyBossWeek = stamp(data.lastWeeklyBossWeek)
	data.firstClearDay = stamp(data.firstClearDay)
	data.weeklyWeek = stamp(data.weeklyWeek)
	data.dailyBonusDay = stamp(data.dailyBonusDay)
	data.dailyRerollDay = stamp(data.dailyRerollDay)
	data.raidMarkWeek = stamp(data.raidMarkWeek)
	if data.chestDuplicates ~= "star" then
		data.chestDuplicates = "dust"
	end
	if type(data.chestSalvageBelow) ~= "string" then
		data.chestSalvageBelow = ""
	end
	if type(data.autoSalvageRarity) ~= "string" or AUTO_RARITY[data.autoSalvageRarity] ~= true then
		data.autoSalvageRarity = ""
	end
	if data.autoSalvage ~= true or data.autoSalvageRarity == "" then
		data.autoSalvage = false
	else
		data.autoSalvage = true
	end
	local earned = {}
	for _, row in ipairs(CraftingLevel.MILESTONES) do
		if data.craftingLevel >= row.level then
			table.insert(earned, row.level)
		end
	end
	data.craftingMilestones = earned
	data.milestoneTable = CraftingLevel.copyTable()
	data.equipped.weapon = optionalUid(data.equipped.weapon)
	data.equipped.pet = optionalUid(data.equipped.pet)
	-- An equipped id that is not in the bag must not survive. The client
	-- names whatever this points at, so a stale id would look like a sword
	-- the player does not have.
	if
		type(data.inventory) == "table"
		and data.equipped.weapon ~= nil
		and data.inventory[data.equipped.weapon] == nil
	then
		data.equipped.weapon = nil
	end
	if
		type(data.pets) == "table"
		and data.equipped.pet ~= nil
		and data.pets[data.equipped.pet] == nil
	then
		data.equipped.pet = nil
	end
	local armor = {}
	if type(data.equipped.armor) == "table" and type(data.inventory) == "table" then
		for slot, uid in pairs(data.equipped.armor) do
			if Schema.ARMOR_SLOTS[slot] == true and data.inventory[uid] ~= nil then
				armor[slot] = uid
			end
		end
	end
	data.equipped.armor = armor
	local accessories = {}
	if type(data.equipped.accessories) == "table" and type(data.inventory) == "table" then
		for slot, uid in pairs(data.equipped.accessories) do
			if Schema.ACCESSORY_SLOTS[slot] == true and data.inventory[uid] ~= nil then
				accessories[slot] = uid
			end
		end
	end
	data.equipped.accessories = accessories
	-- [ECHO hook] Keep a stored loadout. Drop junk. Do not add item.level.
	if type(data.equipLoadout) ~= "table" then
		data.equipLoadout = EquipSlots.empty()
	end
	data.equipLoadout = EquipSlots.publicCopy(data.equipLoadout)
	data.gearEssence = wholeNumber(data.gearEssence, 0, 0)
	if data.gearEssence > 1000000000 then
		data.gearEssence = 1000000000
	end
	-- [ECHO hook] Keep stored core levels. Drop junk. Do not write the items.
	data.shardCores = ShardCoreConfig.sanitize(data.shardCores)
	if data.materials == nil or type(data.materials) == "table" then
		data.materials = Materials.sanitize(data.materials)
	end
	data.consumables = Materials.sanitizeCounts(data.consumables, { Materials.TONIC_ID })
	data.vouchers = Materials.sanitizeCounts(data.vouchers, Materials.VOUCHER_AREAS)
	local function sanitizeGear(item: any)
		if type(item) ~= "table" then
			return
		end
		local stars = wholeNumber(item.stars, 0, 0)
		if stars > Stars.MAX then
			stars = Stars.MAX
		end
		item.stars = stars
		local progress = tonumber(item.starProgress)
		if progress == nil or progress ~= progress or progress < 0 then
			progress = 0
		elseif progress > 1 then
			progress = 1
		end
		if stars >= Stars.MAX then
			progress = 0
		end
		item.starProgress = progress
		item.perks = Stars.perkIds(stars)
		item.locked = item.locked == true
		item.favorite = item.favorite == true
		local sockets = wholeNumber(item.sockets, 0, 0)
		if sockets > 6 then
			sockets = 6
		end
		item.sockets = sockets
		local upgrade = wholeNumber(item.upgrade, 0, 0)
		if upgrade > 10 then
			upgrade = 10
		end
		item.upgrade = upgrade
		Stars.applyStats(item)
	end
	if type(data.inventory) == "table" then
		for _, item in pairs(data.inventory) do
			sanitizeGear(item)
		end
	end
	if type(data.pets) == "table" then
		for _, item in pairs(data.pets) do
			sanitizeGear(item)
		end
	end
	return data
end

--[[
	Returns the migrated profile, or nil plus a reason.

	"corrupt" and "newer" must not be overwritten by the caller. A newer
	version means a future server already saved this player; an old server
	should refuse the session instead of rolling the data backwards.
]]

-- A missing schemaVersion still walks the steps, but a field that is
-- already stored stays. A real older version still receives the default.
local function keepExisting(versionless: boolean, current: any, replacement: any): any
	if versionless and current ~= nil then
		return current
	end
	return replacement
end

local function corruptCollection(value: any): boolean
	return value ~= nil and type(value) ~= "table"
end

function Schema.migrate(raw: any): (ProfileData?, string?)
	if raw == nil then
		-- A missing key is a new player. The version walk treats nil as 0,
		-- and the v14 step would mark the tutorial finished.
		return Schema.template(), nil
	elseif type(raw) ~= "table" then
		return nil, "corrupt"
	elseif
		corruptCollection(raw.inventory)
		or corruptCollection(raw.pets)
		or corruptCollection(raw.materials)
	then
		-- Replacing a string bag with {} would store an empty profile.
		return nil, "corrupt"
	end

	local version = raw.schemaVersion
	local versionless = version == nil
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

	if version < 4 then
		-- Star level. Older gear has no stars. The rolled number becomes
		-- baseValue so a later feed can multiply it without compounding.
		local function stamp(bag: any)
			if type(bag) ~= "table" then
				return
			end
			for _, item in pairs(bag) do
				if type(item) == "table" then
					if type(item.stars) ~= "number" then
						item.stars = 0
					end
					if type(item.starProgress) ~= "number" then
						item.starProgress = 0
					end
					if type(item.stats) == "table" then
						for _, stat in ipairs(item.stats) do
							if
								type(stat) == "table"
								and type(stat.baseValue) ~= "number"
								and type(stat.value) == "number"
							then
								stat.baseValue = stat.value
							end
						end
					end
				end
			end
		end
		stamp(raw.inventory)
		stamp(raw.pets)
		raw.schemaVersion = 4
		version = 4
	end

	if version < 5 then
		-- Prism Tokens are the Robux wallet. Luck Boost is purchased luck.
		-- Neither is copied from Shard Tokens.
		if type(raw.prismTokens) ~= "number" then
			raw.prismTokens = 0
		end
		if type(raw.luckBoost) ~= "number" then
			raw.luckBoost = 0
		end
		raw.schemaVersion = 5
		version = 5
	end

	if version < 6 then
		-- Crafting Level, the milestone table, and a timed Forge Boost.
		if type(raw.craftingLevel) ~= "number" then
			raw.craftingLevel = 1
		end
		if type(raw.craftingXp) ~= "number" then
			raw.craftingXp = 0
		end
		if type(raw.craftingMilestones) ~= "table" then
			raw.craftingMilestones = {}
		end
		if type(raw.forgeBoostUntil) ~= "number" then
			raw.forgeBoostUntil = 0
		end
		raw.schemaVersion = 6
		version = 6
	end

	if version < 7 then
		-- Lock, favorite, and socket count live on each piece. Extra bag
		-- slots from a future purchase start at zero. Accessories are a
		-- separate equip map so rings do not occupy armor slots.
		if type(raw.inventoryBonus) ~= "number" then
			raw.inventoryBonus = 0
		end
		if type(raw.equipped) ~= "table" then
			raw.equipped = {}
		end
		if type(raw.equipped.accessories) ~= "table" then
			raw.equipped.accessories = {}
		end
		local function stampItem(bag: any)
			if type(bag) ~= "table" then
				return
			end
			for _, item in pairs(bag) do
				if type(item) == "table" then
					if item.locked ~= true then
						item.locked = false
					end
					if item.favorite ~= true then
						item.favorite = false
					end
					if type(item.sockets) ~= "number" then
						item.sockets = 0
					end
				end
			end
		end
		stampItem(raw.inventory)
		stampItem(raw.pets)
		raw.schemaVersion = 7
		version = 7
	end

	if version < 8 then
		-- Waystones, the travel clock, and the unsold travel pass.
		if type(raw.waystones) ~= "table" then
			raw.waystones = {}
		end
		if type(raw.lastTravel) ~= "number" then
			raw.lastTravel = 0
		end
		if raw.travelPass ~= true then
			raw.travelPass = false
		end
		raw.schemaVersion = 8
		version = 8
	end

	if version < 9 then
		-- Graphics quality stays empty until this player picks a tier
		-- or a touch device writes the Low default.
		if Quality.normalize(raw.graphicsQuality) == nil then
			raw.graphicsQuality = ""
		end
		raw.schemaVersion = 9
		version = 9
	end

	if version < 10 then
		-- Global shard pity, the Quick Roll unlock, VIP, and the shake toggle.
		-- Older per-pool pity stays where it is; these counters start fresh.
		if type(raw.shardRolls) ~= "number" then
			raw.shardRolls = 0
		end
		if type(raw.sinceEpic) ~= "number" then
			raw.sinceEpic = 0
		end
		if type(raw.sinceLegendary) ~= "number" then
			raw.sinceLegendary = 0
		end
		if raw.quickRoll ~= true then
			raw.quickRoll = false
		end
		if type(raw.quickRollUntil) ~= "number" then
			raw.quickRollUntil = 0
		end
		if raw.vip ~= true then
			raw.vip = false
		end
		if raw.shake ~= false then
			raw.shake = true
		end
		raw.schemaVersion = 10
		version = 10
	end

	if version < 11 then
		-- Chests, Shard Keys, and Shard Dust. Login and boss clocks stay
		-- at -1 so the first claim of a week still pays.
		if type(raw.chests) ~= "table" then
			raw.chests = {}
		end
		if type(raw.shardKeys) ~= "number" then
			raw.shardKeys = 0
		end
		if type(raw.shardDust) ~= "number" then
			raw.shardDust = 0
		end
		if type(raw.rareChestsSinceEpic) ~= "number" then
			raw.rareChestsSinceEpic = 0
		end
		if type(raw.epicChestsSinceLegendary) ~= "number" then
			raw.epicChestsSinceLegendary = 0
		end
		if type(raw.lastLoginDay) ~= "number" then
			raw.lastLoginDay = -1
		end
		if type(raw.loginStreak) ~= "number" then
			raw.loginStreak = 0
		end
		if type(raw.lastDailyBossDay) ~= "number" then
			raw.lastDailyBossDay = -1
		end
		if type(raw.lastWeeklyBossWeek) ~= "number" then
			raw.lastWeeklyBossWeek = -1
		end
		if raw.chestDuplicates ~= "star" then
			raw.chestDuplicates = "dust"
		end
		if type(raw.chestSalvageBelow) ~= "string" then
			raw.chestSalvageBelow = ""
		end
		raw.schemaVersion = 11
		version = 11
	end

	if version < 12 then
		-- Music and SFX sliders. 1 is full. The Haven track still starts at
		-- its own bed volume and the slider multiplies that.
		if tonumber(raw.musicVolume) == nil then
			raw.musicVolume = Audio.DEFAULT_MUSIC
		end
		if tonumber(raw.sfxVolume) == nil then
			raw.sfxVolume = Audio.DEFAULT_SFX
		end
		raw.schemaVersion = 12
		version = 12
	end

	if version < 13 then
		if type(raw.classId) ~= "string" then
			raw.classId = ""
		end
		if type(raw.classXp) ~= "table" then
			raw.classXp = {}
		end
		if type(raw.classTalent) ~= "table" then
			raw.classTalent = {}
		end
		raw.schemaVersion = 13
		version = 13
	end

	if version < 14 then
		if type(raw.onboardStep) ~= "string" then
			raw.onboardStep = "haven"
		end
		if versionless then
			if type(raw.onboardDone) ~= "boolean" then
				raw.onboardDone = true
			end
		elseif raw.onboardDone ~= true then
			raw.onboardDone = true
		end
		raw.schemaVersion = 14
		version = 14
	end

	if version < 15 then
		raw.restCharges = keepExisting(versionless, raw.restCharges, 0)
		raw.welcomeCharges = keepExisting(versionless, raw.welcomeCharges, 0)
		raw.lastSeen = keepExisting(versionless, raw.lastSeen, os.time())
		raw.milestoneTitle = keepExisting(versionless, raw.milestoneTitle, "")
		raw.welcomeNote = keepExisting(versionless, raw.welcomeNote, "")
		raw.schemaVersion = 15
		version = 15
	end

	if version < 16 then
		raw.gems = keepExisting(versionless, raw.gems, 0)
		raw.eventTokens = keepExisting(versionless, raw.eventTokens, 0)
		raw.ledger = keepExisting(versionless, raw.ledger, {})
		raw.receipts = keepExisting(versionless, raw.receipts, {})
		raw.schemaVersion = 16
		version = 16
	end

	if version < 17 then
		raw.eggs = keepExisting(versionless, raw.eggs, 1)
		raw.companions = keepExisting(versionless, raw.companions, {})
		raw.schemaVersion = 17
		version = 17
	end

	if version < 18 then
		raw.dailies = keepExisting(versionless, raw.dailies, {})
		raw.weekly = keepExisting(versionless, raw.weekly, {})
		raw.weeklyWeek = keepExisting(versionless, raw.weeklyWeek, -1)
		raw.board = keepExisting(versionless, raw.board, {})
		raw.boardLines = keepExisting(versionless, raw.boardLines, 0)
		raw.passXp = keepExisting(versionless, raw.passXp, 0)
		raw.passClaimed = keepExisting(versionless, raw.passClaimed, 0)
		raw.firstClearDay = keepExisting(versionless, raw.firstClearDay, -1)
		raw.nightmareBest = keepExisting(versionless, raw.nightmareBest, 0)
		raw.dailyBonusDay = keepExisting(versionless, raw.dailyBonusDay, -1)
		raw.dailyRerollDay = keepExisting(versionless, raw.dailyRerollDay, -1)
		raw.schemaVersion = 18
		version = 18
	end

	if version < 19 then
		raw.raidMarks = keepExisting(versionless, raw.raidMarks, 0)
		raw.raidMarksEarned = keepExisting(versionless, raw.raidMarksEarned, 0)
		raw.raidMarkWeek = keepExisting(versionless, raw.raidMarkWeek, -1)
		raw.raidLock = keepExisting(versionless, raw.raidLock, {})
		raw.raidPity = keepExisting(versionless, raw.raidPity, {})
		raw.raidStory = keepExisting(versionless, raw.raidStory, false)
		raw.raidEcho = keepExisting(versionless, raw.raidEcho, 0)
		raw.raidBest = keepExisting(versionless, raw.raidBest, 0)
		raw.schemaVersion = 19
		version = 19
	end

	if version < 20 then
		raw.tradeDay = keepExisting(versionless, raw.tradeDay, 0)
		raw.tradeValueToday = keepExisting(versionless, raw.tradeValueToday, 0)
		raw.tradeLocked = keepExisting(versionless, raw.tradeLocked, false)
		raw.tradeFlagged = keepExisting(versionless, raw.tradeFlagged, false)
		raw.verifiedTrader = keepExisting(versionless, raw.verifiedTrader, false)
		raw.tradeCleanSince = keepExisting(versionless, raw.tradeCleanSince, 0)
		raw.tradeHandoff = keepExisting(versionless, raw.tradeHandoff, false)
		raw.schemaVersion = 20
		version = 20
	end

	if version < 21 then
		raw.uiSettings = keepExisting(versionless, raw.uiSettings, Settings.default())
		raw.schemaVersion = 21
		version = 21
	end

	-- T-049 named 22 for raidLuck and never shipped. This is the free version.
	-- A save from 21 starts unpaid. Do not copy onboardDone or another profile.
	if version < 22 then
		raw.starterGoals = keepExisting(versionless, raw.starterGoals, StarterGoalPay.blank())
		raw.schemaVersion = 22
		version = 22
	end

	-- A save that already finished onboarding does not get this kit.
	-- A new profile stays returning false. Do not copy another account.
	if version < 23 then
		raw.firstSession = keepExisting(
			versionless,
			raw.firstSession,
			firstSessionKit().blank(raw.onboardDone == true)
		)
		raw.schemaVersion = 23
		version = 23
	end

	-- Per-class action bars. A save with none gets the class defaults.
	-- Do not copy another profile's layout.
	if version < 24 then
		raw.actionBars = keepExisting(versionless, raw.actionBars, ActionSlots.fresh())
		raw.schemaVersion = 24
		version = 24
	end

	-- Codex seen flags. A save from 24 starts locked. Do not copy another profile.
	if version < 25 then
		raw.codex = keepExisting(versionless, raw.codex, blankCodex())
		raw.schemaVersion = 25
		version = 25
	end

	-- Training Grove. A save from 25 starts empty. Do not copy another profile.
	-- Do not fold this into codex. Keys and gold are not stored.
	if version < 26 then
		raw.trainingGrove = keepExisting(versionless, raw.trainingGrove, blankGrove())
		raw.schemaVersion = 26
		version = 26
	end

	return Schema.reconcile(raw), nil
end

-- Old per-pool counter. The crack does not write it. sinceEpic and
-- sinceLegendary are the live pity. Leave the field so old saves still load.
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
	if type(data.equipped.accessories) == "table" then
		for _, slotUid in pairs(data.equipped.accessories) do
			if slotUid == uid then
				return true
			end
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
	if type(data.equipped.accessories) == "table" then
		for slot, slotUid in pairs(data.equipped.accessories) do
			if slotUid == uid then
				data.equipped.accessories[slot] = nil
			end
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
	if item.kind == "Accessory" then
		local slot = item.slot
		if type(slot) ~= "string" or Schema.ACCESSORY_SLOTS[slot] ~= true then
			return "That accessory has no slot."
		end
		if type(data.equipped.accessories) ~= "table" then
			data.equipped.accessories = {}
		end
		data.equipped.accessories[slot] = item.uid
		return nil
	end
	return "That item cannot be equipped."
end

function Schema.inventoryCap(data: any): number
	local bonus = 0
	if
		type(data) == "table"
		and type(data.inventoryBonus) == "number"
		and data.inventoryBonus > 0
	then
		bonus = math.floor(data.inventoryBonus)
	end
	return Schema.INVENTORY_CAP + bonus
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
		prismTokens = data.prismTokens,
		shardLuck = data.shardLuck,
		luckBoost = data.luckBoost,
		inventory = Schema.deepCopy(data.inventory),
		pets = Schema.deepCopy(data.pets),
		pity = Schema.deepCopy(data.pity),
		equipped = {
			weapon = data.equipped.weapon,
			pet = data.equipped.pet,
			armor = Schema.deepCopy(data.equipped.armor),
			accessories = Schema.deepCopy(data.equipped.accessories),
		},
		equipLoadout = EquipSlots.publicCopy(data.equipLoadout),
		gearEssence = data.gearEssence,
		shardCores = ShardCoreConfig.sanitize(data.shardCores),
		inventoryBonus = data.inventoryBonus,
		petSlotBonus = data.petSlotBonus,
		inventoryCap = Schema.inventoryCap(data),
		materials = Schema.deepCopy(data.materials),
		consumables = Schema.deepCopy(data.consumables),
		vouchers = Schema.deepCopy(data.vouchers),
		craftingLevel = data.craftingLevel,
		craftingXp = data.craftingXp,
		craftingXpToNext = CraftingLevel.xpToNext(data.craftingLevel),
		craftingMilestones = Schema.deepCopy(data.craftingMilestones),
		milestoneTable = Schema.deepCopy(data.milestoneTable),
		forgeBoostUntil = data.forgeBoostUntil,
		waystones = Schema.deepCopy(data.waystones),
		lastTravel = data.lastTravel,
		travelPass = data.travelPass,
		graphicsQuality = data.graphicsQuality,
		shardRolls = data.shardRolls,
		sinceEpic = data.sinceEpic,
		sinceLegendary = data.sinceLegendary,
		quickRoll = data.quickRoll,
		quickRollUntil = data.quickRollUntil,
		vip = data.vip,
		shake = data.shake,
		chests = Schema.deepCopy(data.chests),
		shardKeys = data.shardKeys,
		shardDust = data.shardDust,
		rareChestsSinceEpic = data.rareChestsSinceEpic,
		epicChestsSinceLegendary = data.epicChestsSinceLegendary,
		lastLoginDay = data.lastLoginDay,
		loginStreak = data.loginStreak,
		lastDailyBossDay = data.lastDailyBossDay,
		lastWeeklyBossWeek = data.lastWeeklyBossWeek,
		chestDuplicates = data.chestDuplicates,
		chestSalvageBelow = data.chestSalvageBelow,
		autoSalvage = data.autoSalvage,
		autoSalvageRarity = data.autoSalvageRarity,
		pendingChest = Schema.deepCopy(data.pendingChest),
		musicVolume = data.musicVolume,
		sfxVolume = data.sfxVolume,
		classId = data.classId,
		classXp = Schema.deepCopy(data.classXp),
		classTalent = Schema.deepCopy(data.classTalent),
		classLevel = Classes.progress(data.classXp[data.classId] or 0),
		onboardStep = data.onboardStep,
		onboardDone = data.onboardDone,
		restCharges = data.restCharges,
		welcomeCharges = data.welcomeCharges,
		lastSeen = data.lastSeen,
		milestoneTitle = data.milestoneTitle,
		welcomeNote = data.welcomeNote,
		gems = data.gems,
		eventTokens = data.eventTokens,
		eggs = data.eggs,
		companions = Schema.deepCopy(data.companions),
		dailies = Schema.deepCopy(data.dailies),
		weekly = Schema.deepCopy(data.weekly),
		board = Schema.deepCopy(data.board),
		boardLines = data.boardLines,
		passXp = data.passXp,
		passTier = select(2, Loops.passXp(data.passXp, 0)),
		passClaimed = data.passClaimed,
		nightmareBest = data.nightmareBest,
		dailyBossReady = data.lastDailyBossDay ~= Loops.dayNumber(os.time()),
		raidMarks = data.raidMarks,
		raidStory = data.raidStory,
		raidEcho = data.raidEcho,
		raidBest = data.raidBest,
		tradeLocked = data.tradeLocked,
		tradeFlagged = data.tradeFlagged,
		verifiedTrader = data.verifiedTrader,
		tradeHandoff = data.tradeHandoff,
		uiSettings = Settings.normalize(data.uiSettings),
		starterGoalTracker = StarterGoalPay.tracker(data),
		actionBars = Schema.deepCopy(data.actionBars),
		codex = { unlocked = readCodexFlags(data.codex) },
		trainingGrove = readGrove(data.trainingGrove),
	}
end

table.freeze(Schema.ARMOR_SLOTS)
table.freeze(Schema.ACCESSORY_SLOTS)

return Schema
