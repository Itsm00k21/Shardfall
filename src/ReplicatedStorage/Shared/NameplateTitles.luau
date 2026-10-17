--!strict

--[[
	Nameplate title unlocks. Pure rules.

	Forty titles. Each one is nameplate text. No stat, no luck,
	no drop chance, no marks, no Robux item. This is not a board
	filter and it does not filter text.

	The caller passes the counters and the booleans the server
	already decided. Practice Grove does not count. An unlock
	sticks once. The weekly mark-cap title stays after that
	counter drops, including a week reset.

	Unlocking pays nothing. paid does not unlock a title the
	counters have not earned, and it does not block one they
	have. A productId, robux, cost, or skip field grants nothing.
	This module does not take a user id or a guild id. Each call
	returns a new table and does not write the input. No clock.
	No RNG. Nothing here costs Robux.

	Five reserved names stay on their old sources and are not
	ids here. It stands alone. It does not load another module.
	Nothing in src loads this module.
]]

local NameplateTitles = {}

NameplateTitles.ERRORS = table.freeze({
	state = "That title record is unusable.",
	progress = "That progress is unusable.",
	paid = "A paid skip is refused.",
	id = "A user id or a guild id is refused.",
	rules = "The title rules are unusable.",
})

local RUNGS = table.freeze({ "common", "uncommon", "rare", "epic", "legendary" })
local RARE_OR_BETTER = table.freeze({ "rare", "epic", "legendary", "mythic" })
local EPIC_OR_BETTER = table.freeze({ "epic", "legendary", "mythic" })
local LEGEND_OR_BETTER = table.freeze({ "legendary", "mythic" })

local FIELDS = table.freeze({
	"perfectDodges",
	"rooms",
	"launches",
	"cracks",
	"hatches",
	"trades",
	"tonics",
	"listings",
	"rootvaultNormal",
	"skills",
	"bonusCracks",
	"storyWings",
	"party",
	"logins",
	"combos",
	"thorns",
	"rootvaultHard",
	"classes",
	"affinity",
	"bond",
	"normalWings",
	"friendClears",
	"rootvaultNightmare",
	"epicPity",
	"legendPity",
	"species",
	"wings",
	"itemBases",
	"sameWing",
	"raidMarksEarned",
	"awakenedNormal",
	"mythicItems",
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
	"mythic",
})

local function counter(id: string, name: string, rarity: string, count: number, field: string)
	return table.freeze({
		id = id,
		name = name,
		rarity = rarity,
		count = count,
		field = field,
	})
end

local function summed(id: string, name: string, rarity: string, count: number, fields: { string })
	return table.freeze({
		id = id,
		name = name,
		rarity = rarity,
		count = count,
		sum = fields,
	})
end

local function paired(
	id: string,
	name: string,
	rarity: string,
	count: number,
	field: string,
	also: string,
	alsoCount: number
)
	return table.freeze({
		id = id,
		name = name,
		rarity = rarity,
		count = count,
		field = field,
		also = also,
		alsoCount = alsoCount,
	})
end

local function ladder(id: string, name: string, rarity: string, count: number, fields: { string })
	return table.freeze({
		id = id,
		name = name,
		rarity = rarity,
		count = count,
		each = fields,
	})
end

local titles = table.freeze({
	counter("soft_step", "Soft Step", "Common", 10, "perfectDodges"),
	counter("room_one", "Room One", "Common", 1, "rooms"),
	counter("tenth_launch", "Tenth Launch", "Common", 10, "launches"),
	counter("one_pull", "One Pull", "Common", 1, "cracks"),
	counter("first_hatch", "First Hatch", "Common", 1, "hatches"),
	counter("one_trade", "One Trade", "Common", 1, "trades"),
	counter("tonic_made", "Tonic Made", "Common", 1, "tonics"),
	counter("listed_once", "Listed Once", "Common", 1, "listings"),
	counter("vault_walker", "Vault Walker", "Uncommon", 1, "rootvaultNormal"),
	counter("skill_hand", "Skill Hand", "Uncommon", 50, "skills"),
	counter("tenth_luck", "Tenth Luck", "Uncommon", 1, "bonusCracks"),
	counter("story_leaf", "Story Leaf", "Uncommon", 1, "storyWings"),
	counter("door_four", "Door Four", "Uncommon", 4, "party"),
	counter("morning_seven", "Morning Seven", "Uncommon", 7, "logins"),
	counter("combo_spark", "Combo Spark", "Uncommon", 1, "combos"),
	counter("thorn_made", "Thorn Made", "Uncommon", 1, "thorns"),
	counter("deep_vault", "Deep Vault", "Rare", 1, "rootvaultHard"),
	counter("five_classes", "Five Classes", "Rare", 5, "classes"),
	summed("rare_chip", "Rare Chip", "Rare", 1, RARE_OR_BETTER),
	counter("hundred_pulls", "Hundred Pulls", "Rare", 100, "cracks"),
	counter("full_stars", "Full Stars", "Rare", 5, "affinity"),
	counter("full_bond", "Full Bond", "Rare", 5, "bond"),
	counter("normal_leaf", "Normal Leaf", "Rare", 1, "normalWings"),
	counter("friend_clear", "Friend Clear", "Rare", 1, "friendClears"),
	counter("night_root", "Night Root", "Epic", 1, "rootvaultNightmare"),
	counter("pity_ready", "Pity Ready", "Epic", 100, "epicPity"),
	summed("epic_seen", "Epic Seen", "Epic", 1, EPIC_OR_BETTER),
	counter("all_eight", "All Eight", "Epic", 8, "species"),
	counter("four_wings", "Four Wings", "Epic", 4, "wings"),
	counter("card_stack", "Card Stack", "Epic", 20, "itemBases"),
	summed("legend_chip", "Legend Chip", "Legendary", 3, LEGEND_OR_BETTER),
	ladder("gold_ladder", "Gold Ladder", "Legendary", 5, RUNGS),
	counter("two_depths", "Two Depths", "Legendary", 1, "sameWing"),
	counter("long_count", "Long Count", "Legendary", 1000, "legendPity"),
	paired("full_garden", "Full Garden", "Legendary", 8, "species", "affinity", 5),
	counter("capped_pouch", "Capped Pouch", "Legendary", 600, "raidMarksEarned"),
	counter("awakened_name", "Awakened Name", "Mythic", 1, "awakenedNormal"),
	counter("mythic_reel", "Mythic Reel", "Mythic", 1, "mythic"),
	paired("nightglass", "Nightglass", "Mythic", 1, "rootvaultNightmare", "normalWings", 1),
	paired("prism_name", "Prism Name", "Mythic", 1000, "cracks", "mythicItems", 1),
})

local counts: { [string]: number } = {}
local also: { [string]: number } = {}
local order: { string } = {}
for _, row in ipairs(titles) do
	counts[row.id] = row.count
	table.insert(order, row.id)
	if row.alsoCount ~= nil then
		also[row.id] = row.alsoCount
	end
end

NameplateTitles.CONFIG = table.freeze({
	keys = 0,
	gold = 0,
	marks = 0,
	stats = 0,
	luck = 0,
	rung = 1,
	counts = table.freeze(counts),
	also = table.freeze(also),
	rungs = RUNGS,
	titles = titles,
})

NameplateTitles.TITLES = titles
NameplateTitles.ORDER = table.freeze(order)
NameplateTitles.FIELDS = FIELDS

export type State = {
	unlocked: { [string]: boolean },
}

export type Plate = {
	id: string,
	name: string,
	rarity: string,
}

export type Opened = {
	ok: boolean,
	state: State,
	error: string?,
}

export type Unlocked = {
	ok: boolean,
	state: State,
	granted: { string },
	titles: { Plate },
	keys: number,
	gold: number,
	marks: number,
	stats: number,
	luck: number,
	error: string?,
}

export type Painted = {
	ok: boolean,
	state: State,
	titles: { Plate },
	keys: number,
	gold: number,
	marks: number,
	stats: number,
	luck: number,
	error: string?,
}

local ERRORS = NameplateTitles.ERRORS
local CONFIG = NameplateTitles.CONFIG
local TITLES = NameplateTitles.TITLES
local ORDER = NameplateTitles.ORDER

local FIELD_SET: { [string]: boolean } = {}
for _, field in ipairs(FIELDS) do
	FIELD_SET[field] = true
end

local ALLOW: { [string]: boolean } = {
	practice = true,
}
for _, field in ipairs(FIELDS) do
	ALLOW[field] = true
end

local FLAG_KEYS: { [string]: boolean } = {}
for _, id in ipairs(ORDER) do
	FLAG_KEYS[id] = true
end

local EXPECTED_FIELD: { [string]: string } = {
	soft_step = "perfectDodges",
	room_one = "rooms",
	tenth_launch = "launches",
	one_pull = "cracks",
	first_hatch = "hatches",
	one_trade = "trades",
	tonic_made = "tonics",
	listed_once = "listings",
	vault_walker = "rootvaultNormal",
	skill_hand = "skills",
	tenth_luck = "bonusCracks",
	story_leaf = "storyWings",
	door_four = "party",
	morning_seven = "logins",
	combo_spark = "combos",
	thorn_made = "thorns",
	deep_vault = "rootvaultHard",
	five_classes = "classes",
	hundred_pulls = "cracks",
	full_stars = "affinity",
	full_bond = "bond",
	normal_leaf = "normalWings",
	friend_clear = "friendClears",
	night_root = "rootvaultNightmare",
	pity_ready = "epicPity",
	all_eight = "species",
	four_wings = "wings",
	card_stack = "itemBases",
	two_depths = "sameWing",
	long_count = "legendPity",
	capped_pouch = "raidMarksEarned",
	awakened_name = "awakenedNormal",
	mythic_reel = "mythic",
}

local SENTINEL: { [string]: number } = {
	soft_step = 10,
	tenth_launch = 10,
	skill_hand = 50,
	door_four = 4,
	morning_seven = 7,
	five_classes = 5,
	hundred_pulls = 100,
	full_stars = 5,
	full_bond = 5,
	pity_ready = 100,
	all_eight = 8,
	four_wings = 4,
	card_stack = 20,
	legend_chip = 3,
	gold_ladder = 5,
	long_count = 1000,
	full_garden = 8,
	capped_pouch = 600,
	prism_name = 1000,
}

local SPECIAL: { [string]: boolean } = {
	rare_chip = true,
	epic_seen = true,
	legend_chip = true,
	gold_ladder = true,
	full_garden = true,
	nightglass = true,
	prism_name = true,
}

local RARITY_TOTAL: { [string]: number } = {
	Common = 8,
	Uncommon = 8,
	Rare = 8,
	Epic = 6,
	Legendary = 6,
	Mythic = 4,
}

local CONFIG_KEYS: { [string]: boolean } = {
	keys = true,
	gold = true,
	marks = true,
	stats = true,
	luck = true,
	rung = true,
	counts = true,
	also = true,
	rungs = true,
	titles = true,
}

local ROW_KEYS: { [string]: boolean } = {
	id = true,
	name = true,
	rarity = true,
	count = true,
	field = true,
	sum = true,
	each = true,
	also = true,
	alsoCount = true,
}

local ID_FIELDS = { "userId", "UserId", "playerId", "PlayerId", "guildId", "GuildId" }

local function keyCount(value: { [any]: any }, allow: { [string]: boolean }): number?
	local seen = 0
	for key in pairs(value) do
		if type(key) ~= "string" or allow[key] ~= true then
			return nil
		end
		seen += 1
	end
	return seen
end

local function listIs(left: any, right: { string }): boolean
	if type(left) ~= "table" or #left ~= #right then
		return false
	end
	for index, value in ipairs(right) do
		if left[index] ~= value then
			return false
		end
	end
	return true
end

local function noPair(row): boolean
	return row.also == nil and row.alsoCount == nil
end

local function specialOk(row): boolean
	if row.id == "rare_chip" then
		return row.count == 1
			and listIs(row.sum, RARE_OR_BETTER)
			and row.field == nil
			and row.each == nil
			and noPair(row)
	elseif row.id == "epic_seen" then
		return row.count == 1
			and listIs(row.sum, EPIC_OR_BETTER)
			and row.field == nil
			and row.each == nil
			and noPair(row)
	elseif row.id == "legend_chip" then
		return row.count == 3
			and listIs(row.sum, LEGEND_OR_BETTER)
			and row.field == nil
			and row.each == nil
			and noPair(row)
	elseif row.id == "gold_ladder" then
		return row.count == #RUNGS
			and listIs(row.each, RUNGS)
			and row.field == nil
			and row.sum == nil
			and noPair(row)
	elseif row.id == "full_garden" then
		return row.count == 8
			and row.field == "species"
			and row.also == "affinity"
			and row.alsoCount == 5
			and row.sum == nil
			and row.each == nil
	elseif row.id == "nightglass" then
		return row.count == 1
			and row.field == "rootvaultNightmare"
			and row.also == "normalWings"
			and row.alsoCount == 1
			and row.sum == nil
			and row.each == nil
	elseif row.id == "prism_name" then
		return row.count == 1000
			and row.field == "cracks"
			and row.also == "mythicItems"
			and row.alsoCount == 1
			and row.sum == nil
			and row.each == nil
	end
	return false
end

local function plainOk(row): boolean
	local field = EXPECTED_FIELD[row.id]
	if field == nil or FIELD_SET[field] ~= true then
		return false
	end
	return row.field == field and row.sum == nil and row.each == nil and noPair(row)
end

local function rulesOk(): string?
	if CONFIG.keys ~= 0 or CONFIG.gold ~= 0 or CONFIG.marks ~= 0 then
		return ERRORS.rules
	end
	if CONFIG.stats ~= 0 or CONFIG.luck ~= 0 or CONFIG.rung ~= 1 then
		return ERRORS.rules
	end
	if keyCount(CONFIG, CONFIG_KEYS) ~= 10 then
		return ERRORS.rules
	end
	if CONFIG.titles ~= TITLES or CONFIG.rungs ~= RUNGS then
		return ERRORS.rules
	end
	if type(CONFIG.counts) ~= "table" or type(CONFIG.also) ~= "table" then
		return ERRORS.rules
	end
	if #TITLES ~= 40 or #ORDER ~= 40 or #FIELDS ~= 38 or #RUNGS ~= 5 then
		return ERRORS.rules
	end
	local fieldSeen: { [string]: boolean } = {}
	for _, field in ipairs(FIELDS) do
		if fieldSeen[field] == true or field == "practice" then
			return ERRORS.rules
		end
		fieldSeen[field] = true
	end
	local plainSeen = 0
	for _ in pairs(EXPECTED_FIELD) do
		plainSeen += 1
	end
	local specialSeen = 0
	for _ in pairs(SPECIAL) do
		specialSeen += 1
	end
	if plainSeen ~= 33 or specialSeen ~= 7 then
		return ERRORS.rules
	end
	local raritySeen: { [string]: number } = {}
	local idSeen: { [string]: boolean } = {}
	local nameSeen: { [string]: boolean } = {}
	local sentinelSeen: { [string]: boolean } = {}
	local countKeys = 0
	for id, count in pairs(CONFIG.counts) do
		if idSeen[id] == true or type(count) ~= "number" then
			return ERRORS.rules
		end
		countKeys += 1
	end
	if countKeys ~= 40 then
		return ERRORS.rules
	end
	for index, row in ipairs(TITLES) do
		if type(row) ~= "table" or keyCount(row, ROW_KEYS) == nil then
			return ERRORS.rules
		end
		if row.id ~= ORDER[index] or type(row.name) ~= "string" or row.name == "" then
			return ERRORS.rules
		end
		if idSeen[row.id] == true or nameSeen[row.name] == true then
			return ERRORS.rules
		end
		idSeen[row.id] = true
		nameSeen[row.name] = true
		if RARITY_TOTAL[row.rarity] == nil then
			return ERRORS.rules
		end
		raritySeen[row.rarity] = (raritySeen[row.rarity] or 0) + 1
		if CONFIG.counts[row.id] ~= row.count then
			return ERRORS.rules
		end
		local stamped = SENTINEL[row.id]
		if stamped ~= nil then
			if row.count ~= stamped then
				return ERRORS.rules
			end
			sentinelSeen[row.id] = true
		elseif row.count ~= 1 then
			return ERRORS.rules
		end
		if SPECIAL[row.id] == true and EXPECTED_FIELD[row.id] ~= nil then
			return ERRORS.rules
		end
		local shaped = if SPECIAL[row.id] == true then specialOk(row) else plainOk(row)
		if not shaped then
			return ERRORS.rules
		end
		if row.alsoCount ~= nil and CONFIG.also[row.id] ~= row.alsoCount then
			return ERRORS.rules
		end
		if row.alsoCount == nil and CONFIG.also[row.id] ~= nil then
			return ERRORS.rules
		end
	end
	for key, total in pairs(RARITY_TOTAL) do
		if raritySeen[key] ~= total then
			return ERRORS.rules
		end
	end
	local sentinelKeys = 0
	for key in pairs(SENTINEL) do
		if sentinelSeen[key] ~= true then
			return ERRORS.rules
		end
		sentinelKeys += 1
	end
	if sentinelKeys ~= 19 then
		return ERRORS.rules
	end
	if
		CONFIG.also.full_garden ~= 5
		or CONFIG.also.nightglass ~= 1
		or CONFIG.also.prism_name ~= 1
	then
		return ERRORS.rules
	end
	local alsoKeys = 0
	for _ in pairs(CONFIG.also) do
		alsoKeys += 1
	end
	if alsoKeys ~= 3 then
		return ERRORS.rules
	end
	return nil
end

local function whole(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value < 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function blankFlags(): { [string]: boolean }
	local flags: { [string]: boolean } = {}
	for _, id in ipairs(ORDER) do
		flags[id] = false
	end
	return flags
end

local function copyFlags(flags: { [string]: boolean }): { [string]: boolean }
	local copy: { [string]: boolean } = {}
	for _, id in ipairs(ORDER) do
		copy[id] = flags[id]
	end
	return copy
end

local function blankState(): State
	return {
		unlocked = blankFlags(),
	}
end

local function copyState(state: State): State
	return {
		unlocked = copyFlags(state.unlocked),
	}
end

local function kept(current: State?): State
	if current == nil then
		return blankState()
	end
	return copyState(current)
end

local function foreign(
	value: { [any]: any },
	allowPaid: boolean,
	allow: { [string]: boolean },
	shapeErr: string
): string?
	for _, key in ipairs(ID_FIELDS) do
		if value[key] ~= nil then
			return ERRORS.id
		end
	end
	if value.productId ~= nil or value.robux ~= nil or value.cost ~= nil or value.skip ~= nil then
		return ERRORS.paid
	end
	for key in pairs(value) do
		local allowed = type(key) == "string"
			and (allow[key] == true or (allowPaid and key == "paid"))
		if not allowed then
			return shapeErr
		end
	end
	return nil
end

local function paidType(value: { [any]: any }, shapeErr: string): string?
	if value.paid ~= nil and type(value.paid) ~= "boolean" then
		return shapeErr
	end
	return nil
end

local function refusal(left: string?, right: string?): string?
	if left == ERRORS.id or right == ERRORS.id then
		return ERRORS.id
	end
	if left == ERRORS.paid or right == ERRORS.paid then
		return ERRORS.paid
	end
	return nil
end

local function readFlags(value: any): ({ [string]: boolean }?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local problem = foreign(value, false, FLAG_KEYS, ERRORS.state)
	if problem ~= nil then
		return nil, problem
	end
	local copy: { [string]: boolean } = {}
	for _, id in ipairs(ORDER) do
		if type(value[id]) ~= "boolean" then
			return nil, ERRORS.state
		end
		copy[id] = value[id]
	end
	return copy, nil
end

local function readState(value: any): (State?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local problem = foreign(value, false, { unlocked = true }, ERRORS.state)
	if problem ~= nil then
		return nil, problem
	end
	local flags, flagErr = readFlags(value.unlocked)
	if flags == nil then
		return nil, flagErr or ERRORS.state
	end
	return {
		unlocked = flags,
	}, nil
end

local function readProgress(value: any): ({ [string]: any }?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.progress
	end
	local problem = foreign(value, true, ALLOW, ERRORS.progress)
	if problem ~= nil then
		return nil, problem
	end
	local typed = paidType(value, ERRORS.progress)
	if typed ~= nil then
		return nil, typed
	end
	if type(value.practice) ~= "boolean" then
		return nil, ERRORS.progress
	end
	local copy: { [string]: any } = {
		practice = value.practice,
	}
	for _, field in ipairs(FIELDS) do
		local number = whole(value[field])
		if number == nil then
			return nil, ERRORS.progress
		end
		copy[field] = number
	end
	return copy, nil
end

local function plates(flags: { [string]: boolean }): { Plate }
	local list: { Plate } = {}
	for _, row in ipairs(TITLES) do
		if flags[row.id] == true then
			table.insert(list, {
				id = row.id,
				name = row.name,
				rarity = row.rarity,
			})
		end
	end
	return list
end

local function withPay(result)
	result.keys = CONFIG.keys
	result.gold = CONFIG.gold
	result.marks = CONFIG.marks
	result.stats = CONFIG.stats
	result.luck = CONFIG.luck
	return result
end

local function met(row, progress: { [string]: any }): boolean?
	if row.each ~= nil then
		local filled = 0
		for _, field in ipairs(row.each) do
			if progress[field] >= CONFIG.rung then
				filled += 1
			end
		end
		return filled >= row.count
	end
	local value = 0
	if row.sum ~= nil then
		for _, field in ipairs(row.sum) do
			value += progress[field]
			if value ~= value or value == math.huge or value == -math.huge then
				return nil
			end
		end
	else
		value = progress[row.field]
	end
	if value < row.count then
		return false
	end
	if row.also ~= nil and progress[row.also] < row.alsoCount then
		return false
	end
	return true
end

local function failUnlock(state: State, err: string): Unlocked
	return withPay({
		ok = false,
		state = state,
		granted = {},
		titles = plates(state.unlocked),
		error = err,
	})
end

local function failPaint(state: State, err: string): Painted
	return withPay({
		ok = false,
		state = state,
		titles = plates(state.unlocked),
		error = err,
	})
end

function NameplateTitles.fresh(options: any): Opened
	local broken = rulesOk()
	if broken ~= nil then
		return {
			ok = false,
			state = blankState(),
			error = broken,
		}
	end
	if options == nil then
		return {
			ok = true,
			state = blankState(),
		}
	end
	if type(options) ~= "table" then
		return {
			ok = false,
			state = blankState(),
			error = ERRORS.state,
		}
	end
	local problem = foreign(options, false, {}, ERRORS.state)
	if problem ~= nil then
		return {
			ok = false,
			state = blankState(),
			error = problem,
		}
	end
	return {
		ok = true,
		state = blankState(),
	}
end

function NameplateTitles.unlock(state: any, progress: any): Unlocked
	local broken = rulesOk()
	if broken ~= nil then
		return failUnlock(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local counters, progressErr = readProgress(progress)
	local refused = refusal(stateErr, progressErr)
	if refused ~= nil then
		return failUnlock(kept(current), refused)
	end
	if current == nil then
		return failUnlock(blankState(), stateErr or ERRORS.state)
	end
	if counters == nil then
		return failUnlock(copyState(current), progressErr or ERRORS.progress)
	end
	local nextFlags = copyFlags(current.unlocked)
	local granted: { string } = {}
	if counters.practice ~= true then
		for _, row in ipairs(TITLES) do
			local ready = met(row, counters)
			if ready == nil then
				return failUnlock(copyState(current), ERRORS.progress)
			end
			if ready == true and nextFlags[row.id] ~= true then
				nextFlags[row.id] = true
				table.insert(granted, row.id)
			end
		end
	end
	return withPay({
		ok = true,
		state = {
			unlocked = nextFlags,
		},
		granted = granted,
		titles = plates(nextFlags),
	})
end

function NameplateTitles.nameplate(state: any): Painted
	local broken = rulesOk()
	if broken ~= nil then
		return failPaint(blankState(), broken)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failPaint(blankState(), stateErr or ERRORS.state)
	end
	return withPay({
		ok = true,
		state = copyState(current),
		titles = plates(current.unlocked),
	})
end

return NameplateTitles
