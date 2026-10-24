--!strict

--[[
	Milestone 0.4: config validation. Loads every area through the Config
	index and fails on missing ids, duplicate ids, bad odds, negative or
	NaN stats, missing strings, and references to ids that don't exist.

	Add a check here whenever a config area gains a field.

	Odds model (same as the live RarityConfig): each non-Common tier's
	"1 in N" is its real chance, 1/N. Tiers are checked rarest first and
	the one `remainder` tier (Common) absorbs whatever is left, so the
	effective chances sum to exactly 1. Common's own oneIn is a label, not
	a check: on the V1 ladder its real share is 1 - (1/4 + 1/15 + 1/100 +
	1/1000), about 67.2%.

	Allow-lists are narrow and commented. Each one names a real data
	finding that needs Kevin's call, not a gameplay change made to pass.
]]

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Config = require("../src/ReplicatedStorage/Shared/Config/Index")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Stats = require("../src/ReplicatedStorage/Shared/Stats")

-- Fields that may legitimately be negative.
-- minDot is a facing-cone threshold (a dot product). -1 means "any
-- direction", used by projectile enemies and bosses; valid range is -1..1.
local NEGATIVE_OK: { [string]: boolean } = {
	minDot = true,
}

-- Element stats that are planned but not gear stats yet. Elements.luau:
-- "luck is not a gear stat yet; Phase 2.3 adds it." Remove when it lands.
local ELEMENT_STAT_PENDING: { [string]: boolean } = {
	luck = true,
}

-- The Grovewarden set tag (no set bonus behind it) was dropped on
-- Oct 22 2026 (Kevin). Every setId on an item must name a real set.

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isPositiveInt(value: any): boolean
	return isFinite(value) and value >= 1 and math.floor(value) == value
end

local function fail(message: string)
	error(message, 2)
end

local function checkId(where: string, id: any)
	if type(id) ~= "string" or id == "" then
		fail(where .. ": missing or empty id")
	end
end

-- Keyed table: every row has a non-empty id equal to its key. Returns count.
local function checkKeyed(where: string, list: any): number
	if type(list) ~= "table" then
		fail(where .. " is not a table")
	end
	local count = 0
	for key, row in pairs(list) do
		checkId(where .. "." .. tostring(key), row.id)
		if row.id ~= key then
			fail(where .. ": key " .. tostring(key) .. " has id " .. tostring(row.id))
		end
		count += 1
	end
	if count == 0 then
		fail(where .. " is empty")
	end
	return count
end

-- List: every row has a non-empty id, unique within the list.
local function checkList(
	where: string,
	list: { any },
	seen: { [string]: boolean }?
): { [string]: boolean }
	local ids = seen or {}
	if #list == 0 then
		fail(where .. " is empty")
	end
	for index, row in ipairs(list) do
		checkId(where .. "[" .. index .. "]", row.id)
		if ids[row.id] then
			fail(where .. ": duplicate id " .. row.id)
		end
		ids[row.id] = true
	end
	return ids
end

-- An order list names each key of `keyed` exactly once.
local function checkOrder(where: string, order: { string }, keyed: { [string]: any })
	local seen = {}
	for _, id in ipairs(order) do
		if keyed[id] == nil then
			fail(where .. " names unknown id " .. tostring(id))
		end
		if seen[id] then
			fail(where .. " repeats " .. id)
		end
		seen[id] = true
	end
	for id in pairs(keyed) do
		if not seen[id] then
			fail(where .. " is missing " .. id)
		end
	end
end

local function checkNumber(where: string, field: string, value: any)
	if not isFinite(value) then
		fail(where .. "." .. field .. " is not a finite number: " .. tostring(value))
	end
	if value < 0 and not NEGATIVE_OK[field] then
		fail(where .. "." .. field .. " is negative: " .. tostring(value))
	end
end

-- Every number in a flat row is finite and non-negative (or allow-listed).
local function checkNumbers(where: string, row: { [string]: any })
	for field, value in pairs(row) do
		if type(value) == "number" then
			checkNumber(where, field, value)
		end
	end
end

local function hasString(id: string): boolean
	local row = Config.Strings.LIST[id]
	return row ~= nil and type(row.text) == "string" and row.text ~= ""
end

local function rarityKnown(id: any): boolean
	return type(id) == "string" and Config.Live.Rarities.INDEX[id] ~= nil
end

local function foldsToV1(id: string): boolean
	return Config.Rarities.TIERS[id] ~= nil or Config.Rarities.FOLD[id] ~= nil
end

describe("Config validation: ids", function()
	it("loads every area as a table", function()
		for _, area in ipairs(Config.AREAS) do
			expect(type((Config :: any)[area])).toEqual("table")
		end
	end)

	it("gives every item a unique id that looks itself up", function()
		local all = Config.Items.all()
		local ids = checkList("Items", all)
		for _, base in ipairs(all) do
			expect(Config.Items.get(base.id) == base).toBeTrue()
			if type(base.name) ~= "string" or base.name == "" then
				fail("Items." .. base.id .. " has no name")
			end
		end
		expect(next(ids) ~= nil).toBeTrue()
	end)

	it("keys rarities, pity, elements, enemies, difficulties and strings by id", function()
		checkKeyed("Rarities.TIERS", Config.Rarities.TIERS)
		checkKeyed("Rarities.PITY", Config.Rarities.PITY)
		checkKeyed("Elements.LIST", Config.Elements.LIST)
		checkKeyed("Enemies", Config.Enemies)
		checkKeyed("Economy.DIFFICULTIES", Config.Economy.DIFFICULTIES)
		checkKeyed("Strings.LIST", Config.Strings.LIST)
		checkKeyed("Live.Difficulties", Config.Live.Difficulties)
	end)

	it("has order lists that name every keyed entry once", function()
		checkOrder("Rarities.ORDER", Config.Rarities.ORDER, Config.Rarities.TIERS)
		checkOrder("Elements.ORDER", Config.Elements.ORDER, Config.Elements.LIST)
		checkOrder(
			"Economy.DIFFICULTY_ORDER",
			Config.Economy.DIFFICULTY_ORDER,
			Config.Economy.DIFFICULTIES
		)
	end)

	it("gives every set, piece and bonus a unique id", function()
		local sets = Config.SetBonuses.all()
		checkList("SetBonuses", sets)
		local pieces: { [string]: boolean } = {}
		local bonuses: { [string]: boolean } = {}
		local classes: { [string]: boolean } = {}
		for _, set in ipairs(sets) do
			checkList("SetBonuses." .. set.id .. ".pieces", set.pieces, pieces)
			checkList("SetBonuses." .. set.id .. ".bonuses", set.bonuses, bonuses)
			if classes[set.classId] then
				fail("SetBonuses: two sets for class " .. set.classId)
			end
			classes[set.classId] = true
			expect(Config.SetBonuses.get(set.classId) == set).toBeTrue()
			for _, piece in ipairs(set.pieces) do
				expect(Config.SetBonuses.piece(piece.id) == piece).toBeTrue()
			end
		end
	end)

	it("gives every dungeon and room a unique id", function()
		local dungeons = Config.Dungeons.all()
		checkList("Dungeons", dungeons)
		for _, dungeon in ipairs(dungeons) do
			expect(Config.Dungeons.get(dungeon.id) == dungeon).toBeTrue()
			if #dungeon.rooms > 0 then
				checkList("Dungeons." .. dungeon.id .. ".rooms", dungeon.rooms)
			end
		end
	end)

	it("gives every economy wave a unique id in wave order", function()
		checkList("Economy.WAVES", Config.Economy.WAVES)
		for index, wave in ipairs(Config.Economy.WAVES) do
			expect(wave.wave).toEqual(index)
		end
	end)
end)

describe("Config validation: odds", function()
	it("has positive whole 1-in-N odds that get rarer by rank", function()
		local previous = 0
		for rank, id in ipairs(Config.Rarities.ORDER) do
			local tier = Config.Rarities.TIERS[id]
			expect(tier.rank).toEqual(rank)
			if not isPositiveInt(tier.oneIn) then
				fail("Rarities." .. id .. ".oneIn must be a positive whole number")
			end
			expect(tier.oneIn).toBeGreaterThan(previous)
			previous = tier.oneIn
		end
	end)

	it("has exactly one remainder tier, the commonest", function()
		local remainders = 0
		for _, tier in pairs(Config.Rarities.TIERS) do
			expect(type(tier.remainder)).toEqual("boolean")
			if tier.remainder then
				remainders += 1
			end
		end
		expect(remainders).toEqual(1)
		expect(Config.Rarities.TIERS[Config.Rarities.ORDER[1]].remainder).toBeTrue()
	end)

	it("sums to 1 with strictly decreasing effective chances", function()
		local listed = 0
		for _, tier in pairs(Config.Rarities.TIERS) do
			if not tier.remainder then
				listed += 1 / tier.oneIn
			end
		end
		-- The listed tiers must leave room for the remainder tier.
		expect(listed).toBeLessThan(1)
		local total = 0
		local previous = math.huge
		for _, id in ipairs(Config.Rarities.ORDER) do
			local tier = Config.Rarities.TIERS[id]
			local chance = if tier.remainder then 1 - listed else 1 / tier.oneIn
			expect(chance).toBeGreaterThan(0)
			expect(chance).toBeLessThan(previous)
			previous = chance
			total += chance
		end
		expect(total).toBeCloseTo(1, 1e-9)
	end)

	it("has positive whole pity that reaches a guarantee", function()
		for key, pity in pairs(Config.Rarities.PITY) do
			if Config.Rarities.TIERS[pity.tier] == nil then
				fail("Rarities.PITY." .. key .. " names unknown tier " .. tostring(pity.tier))
			end
			if not isPositiveInt(pity.hard) then
				fail("Rarities.PITY." .. key .. ".hard must be a positive whole number")
			end
			if pity.softFrom ~= nil then
				if not isPositiveInt(pity.softFrom) then
					fail("Rarities.PITY." .. key .. ".softFrom must be a positive whole number")
				end
				expect(pity.softFrom).toBeLessThan(pity.hard)
				expect(isFinite(pity.softStep) and pity.softStep > 0).toBeTrue()
				-- Base chance plus the soft ramp hits 100% by the hard roll.
				local base = 1 / Config.Rarities.TIERS[pity.tier].oneIn
				local atHard = base + pity.softStep * (pity.hard - pity.softFrom)
				expect(atHard >= 1 - 1e-9).toBeTrue()
			end
		end
		-- Legendary is the only V1 pity (Kevin, Oct 22: Epic pity cut).
		local tiers = {}
		for _, pity in pairs(Config.Rarities.PITY) do
			table.insert(tiers, pity.tier)
		end
		expect(tiers).toEqual({ "Legendary" })
	end)

	it("folds reserved live ids into a V1 tier", function()
		for from, to in pairs(Config.Rarities.FOLD) do
			expect(rarityKnown(from)).toBeTrue()
			expect(Config.Rarities.TIERS[to] ~= nil).toBeTrue()
			expect(Config.Rarities.TIERS[from] == nil).toBeTrue()
		end
	end)

	it("has positive whole live pity, Legendary only, from Config.Rarities", function()
		expect((Config.Live.RollConfig :: any).EPIC_PITY).toBeNil()
		expect(isPositiveInt(Config.Live.RollConfig.LEGENDARY_PITY)).toBeTrue()
		expect(Config.Live.RollConfig.LEGENDARY_PITY).toEqual(Config.Rarities.PITY.legendary.hard)
	end)
end)

describe("Config validation: drop tables", function()
	it("gives every kill drop a sane chance and count", function()
		local enemies = 0
		for enemyId in pairs(Config.Rewards.ENEMIES) do
			enemies += 1
			local entries = Config.Rewards.entries(enemyId)
			if entries == nil or #entries == 0 then
				fail("Rewards." .. enemyId .. " has no drop rows")
			end
			local anyPositive = false
			for _, entry in ipairs(entries :: { any }) do
				local where = "Rewards." .. enemyId .. "." .. tostring(entry.id)
				checkId(where, entry.id)
				if Materials.DEFS[entry.id] == nil then
					fail(where .. " is not a material")
				end
				checkNumber(where, "chance", entry.chance)
				if entry.chance > 1 then
					fail(where .. ".chance is above 1")
				end
				if entry.chance > 0 then
					anyPositive = true
				end
				if
					not isPositiveInt(entry.min)
					or not isPositiveInt(entry.max)
					or entry.min > entry.max
				then
					fail(where .. " has a bad min/max count")
				end
			end
			if not anyPositive then
				fail("Rewards." .. enemyId .. " can never drop anything")
			end
		end
		expect(enemies).toBeGreaterThan(0)
	end)

	it("gives every roll pool positive weights on real items", function()
		local poolIds: { [string]: boolean } = {}
		for _, pool in ipairs(Pools.all()) do
			checkId("Pools", pool.id)
			if poolIds[pool.id] then
				fail("Pools: duplicate id " .. pool.id)
			end
			poolIds[pool.id] = true
			if #pool.entries == 0 then
				fail("Pools." .. pool.id .. " is empty")
			end
			local seen: { [string]: boolean } = {}
			for _, entry in ipairs(pool.entries) do
				local where = "Pools." .. pool.id .. "." .. tostring(entry.templateId)
				if Config.Items.get(entry.templateId) == nil then
					fail(where .. " is not an item")
				end
				if seen[entry.templateId] then
					fail(where .. " is listed twice")
				end
				seen[entry.templateId] = true
				checkNumber(where, "weight", entry.weight)
				if entry.weight <= 0 then
					fail(where .. " has no weight")
				end
			end
		end
	end)

	it("gives every dungeon clear sane rewards", function()
		for _, dungeon in ipairs(Config.Dungeons.all()) do
			local reward = dungeon.rewards
			if reward ~= nil then
				local where = "Dungeons." .. dungeon.id .. ".rewards"
				checkNumbers(where, reward :: any)
				expect(reward.heartwoodChance <= 1).toBeTrue()
				expect(reward.voucherChance <= 1).toBeTrue()
				for id, count in pairs(reward.materials) do
					if Materials.DEFS[id] == nil then
						fail(where .. " pays unknown material " .. id)
					end
					checkNumber(where .. ".materials", id, count)
				end
			end
		end
	end)

	it("pays positive whole tokens and multipliers in the V1 economy", function()
		for _, wave in ipairs(Config.Economy.WAVES) do
			expect(isPositiveInt(wave.tokens)).toBeTrue()
		end
		local previous = 0
		for _, id in ipairs(Config.Economy.DIFFICULTY_ORDER) do
			local row = Config.Economy.DIFFICULTIES[id]
			checkNumbers("Economy.DIFFICULTIES." .. id, row)
			expect(row.tokenMultiplier).toBeGreaterThan(previous)
			previous = row.tokenMultiplier
			expect(isPositiveInt(row.levelGate)).toBeTrue()
		end
	end)
end)

describe("Config validation: stats", function()
	it("has no negative or NaN item stats", function()
		for _, base in ipairs(Config.Items.all()) do
			local where = "Items." .. base.id
			checkNumber(where, "ascension", base.ascension)
			expect(math.floor(base.ascension) == base.ascension).toBeTrue()
			for _, stat in ipairs(base.stats or {}) do
				if Stats.DEFS[stat.id] == nil then
					fail(where .. " uses unknown stat " .. stat.id)
				end
				checkNumber(where .. "." .. stat.id, "min", stat.min)
				checkNumber(where .. "." .. stat.id, "max", stat.max)
				expect(stat.min <= stat.max).toBeTrue()
			end
		end
	end)

	it("has no negative or NaN enemy stats", function()
		for id, enemy in pairs(Config.Enemies) do
			local where = "Enemies." .. id
			checkNumbers(where, enemy :: any)
			expect(enemy.maxHealth).toBeGreaterThan(0)
			expect(enemy.minDot >= -1 and enemy.minDot <= 1).toBeTrue()
			expect(enemy.phase2At >= 0 and enemy.phase2At <= 1).toBeTrue()
			if enemy.boss then
				expect(enemy.phase2At).toBeGreaterThan(0)
			end
			if enemy.style == "projectile" then
				expect(enemy.projectileSpeed).toBeGreaterThan(0)
			end
			for _, channel in ipairs(enemy.color) do
				expect(isFinite(channel) and channel >= 0 and channel <= 255).toBeTrue()
			end
			for _, axis in ipairs(enemy.size) do
				expect(axis).toBeGreaterThan(0)
			end
		end
	end)

	it("has no negative or NaN dungeon or difficulty numbers", function()
		for _, dungeon in ipairs(Config.Dungeons.all()) do
			checkNumber("Dungeons." .. dungeon.id, "ascension", dungeon.ascension)
			checkNumber("Dungeons." .. dungeon.id, "floorSize", dungeon.floorSize)
		end
		for id, row in pairs(Config.Live.Difficulties) do
			checkNumbers("Live.Difficulties." .. id, row)
		end
	end)

	it("keeps set bonus numbers sane", function()
		for _, set in ipairs(Config.SetBonuses.all()) do
			for _, bonus in ipairs(set.bonuses) do
				checkNumbers("SetBonuses." .. bonus.id, bonus :: any)
				expect(bonus.pieces >= 1 and bonus.pieces <= Config.SetBonuses.PIECE_COUNT).toBeTrue()
			end
		end
	end)
end)

describe("Config validation: strings", function()
	it("names every V1 rarity", function()
		for _, id in ipairs(Config.Rarities.ORDER) do
			if not hasString("rarity_" .. string.lower(id)) then
				fail("Strings is missing rarity_" .. string.lower(id))
			end
		end
	end)

	it("names every difficulty, V1 and live", function()
		for id in pairs(Config.Economy.DIFFICULTIES) do
			if not hasString("difficulty_" .. id) then
				fail("Strings is missing difficulty_" .. id)
			end
		end
		for id in pairs(Config.Live.Difficulties) do
			if not hasString("difficulty_" .. id) then
				fail("Strings is missing difficulty_" .. id)
			end
		end
	end)

	it("names every element", function()
		for id, element in pairs(Config.Elements.LIST) do
			if not hasString("element_" .. id) then
				fail("Strings is missing element_" .. id)
			end
			expect(Config.Strings.LIST["element_" .. id].text).toEqual(element.name)
		end
	end)

	it("has non-empty text for every string", function()
		for id in pairs(Config.Strings.LIST) do
			expect(hasString(id)).toBeTrue()
		end
	end)
end)

describe("Config validation: cross-references", function()
	it("only uses enemies that exist, in rooms and waves", function()
		for _, dungeon in ipairs(Config.Dungeons.all()) do
			for _, room in ipairs(dungeon.rooms) do
				for _, kind in ipairs(room.enemies) do
					if Config.Enemies[kind] == nil then
						fail(
							"Dungeons."
								.. dungeon.id
								.. "."
								.. room.id
								.. " uses unknown enemy "
								.. kind
						)
					end
				end
			end
		end
		for wave = 1, 40 do
			for _, kind in ipairs(Config.Dungeons.waveKinds(wave)) do
				if Config.Enemies[kind] == nil then
					fail("waveKinds(" .. wave .. ") uses unknown enemy " .. kind)
				end
			end
		end
		for _, list in ipairs({ Config.Dungeons.FAR_GLADE, Config.Dungeons.STRAYS }) do
			for _, kind in ipairs(list) do
				expect(Config.Enemies[kind] ~= nil).toBeTrue()
			end
		end
		for kind in pairs(Config.Dungeons.LUNGES) do
			expect(Config.Enemies[kind] ~= nil).toBeTrue()
		end
		for kind in pairs(Config.Dungeons.LOBS) do
			expect(Config.Enemies[kind] ~= nil).toBeTrue()
		end
	end)

	it("has a kill drop for every enemy and an enemy for every kill drop", function()
		for id in pairs(Config.Enemies) do
			if Config.Rewards.ENEMIES[id] == nil then
				fail("Enemies." .. id .. " has no Rewards row")
			end
		end
		for id in pairs(Config.Rewards.ENEMIES) do
			if Config.Enemies[id] == nil then
				fail("Rewards." .. id .. " is not an enemy")
			end
		end
	end)

	it("gives items live rarity ids that fold into a V1 tier", function()
		-- Items still use the live 7-tier ids (Mythic, Secret included).
		for _, base in ipairs(Config.Items.all()) do
			if not rarityKnown(base.rarity) then
				fail("Items." .. base.id .. " has unknown rarity " .. tostring(base.rarity))
			end
			expect(foldsToV1(base.rarity)).toBeTrue()
		end
		for _, set in ipairs(Config.SetBonuses.all()) do
			for _, piece in ipairs(set.pieces) do
				expect(rarityKnown(piece.rarity)).toBeTrue()
			end
		end
	end)

	it("only tags items with sets that exist", function()
		local setIds: { [string]: boolean } = {}
		for _, set in ipairs(Config.SetBonuses.all()) do
			setIds[set.id] = true
		end
		for _, base in ipairs(Config.Items.all()) do
			if base.setId ~= nil and not setIds[base.setId] then
				fail("Items." .. base.id .. " names unknown set " .. base.setId)
			end
		end
	end)

	it("keeps set pieces on real classes and slots", function()
		local classOk: { [string]: boolean } = {}
		for _, id in ipairs(Config.SetBonuses.CLASS_IDS) do
			classOk[id] = true
		end
		local slotOk: { [string]: boolean } = {}
		for _, slot in ipairs(Config.SetBonuses.SLOTS) do
			slotOk[slot] = true
		end
		for _, set in ipairs(Config.SetBonuses.all()) do
			expect(classOk[set.classId] == true).toBeTrue()
			expect(#set.pieces).toEqual(Config.SetBonuses.PIECE_COUNT)
			for _, piece in ipairs(set.pieces) do
				expect(piece.setId).toEqual(set.id)
				expect(piece.classId).toEqual(set.classId)
				expect(slotOk[piece.slot] == true).toBeTrue()
			end
		end
	end)

	it("only lets elements scale real stats", function()
		for id, element in pairs(Config.Elements.LIST) do
			expect(#element.stats).toBeGreaterThan(0)
			for _, stat in ipairs(element.stats) do
				if Stats.DEFS[stat] == nil and not ELEMENT_STAT_PENDING[stat] then
					fail("Elements." .. id .. " scales unknown stat " .. stat)
				end
			end
		end
	end)

	it("keeps live difficulties inside the V1 difficulty list", function()
		for id in pairs(Config.Live.Difficulties) do
			expect(Config.Economy.DIFFICULTIES[id] ~= nil).toBeTrue()
		end
	end)
end)
