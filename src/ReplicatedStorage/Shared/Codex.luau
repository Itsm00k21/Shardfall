--!strict

--[[
	Codex unlocks. Pure rules.

	A short Codex unlocks one entry per mechanic as the player
	discovers it. It looks up info and does not nag. It never
	blocks progress and never forces reading.

	Ten entries, in this order:
	  attack: Attack/combos
	  dodge: Dodge
	  perfect: Perfect dodge
	  skills: Skills
	  telegraphs: Telegraph colors
	  shards: Shards/sockets
	  doors: Door choices
	  pets: Pets
	  crafting: Crafting
	  rarity: Rarity colors

	The server passes which of those it has already seen. An
	entry unlocks once. Unlocking pays nothing: no keys, gold,
	cosmetic, or title.

	Stuck hints are frozen. attack says "Keep swinging". dodge
	says "Dodge!". The other eight have no sentence. Skills,
	telegraphs, shards, and crafting are a glow or an arrow,
	not Codex text. hint returns a sentence only when the caller
	passes stuck for that one entry, that entry is unlocked, and
	it has a sentence. At most one hint. The clock stays with
	the caller.

	paid does not unlock an entry. A productId, robux, cost, or
	skip field unlocks nothing. This module does not take a user
	id. Each call returns a new table and does not write the
	input. No clock. No RNG. Nothing here costs Robux.

	Loading-screen tips are not this module. Training Grove is
	not this module. It stands alone. It does not load another
	module. Nothing in src loads this module.
]]

local Codex = {}

Codex.ERRORS = table.freeze({
	state = "That codex record is unusable.",
	seen = "That seen record is unusable.",
	entry = "That entry is not in the codex.",
	request = "That hint request is unusable.",
	paid = "A paid skip is refused.",
	id = "A user id or a guild id is refused.",
	rules = "The codex rules are unusable.",
})

Codex.CONFIG = table.freeze({
	keys = 0,
	gold = 0,
})

local function entryRow(id: string, label: string, hint: string?)
	if hint == nil then
		return table.freeze({
			id = id,
			label = label,
		})
	end
	return table.freeze({
		id = id,
		label = label,
		hint = hint,
	})
end

Codex.ENTRIES = table.freeze({
	entryRow("attack", "Attack/combos", "Keep swinging"),
	entryRow("dodge", "Dodge", "Dodge!"),
	entryRow("perfect", "Perfect dodge", nil),
	entryRow("skills", "Skills", nil),
	entryRow("telegraphs", "Telegraph colors", nil),
	entryRow("shards", "Shards/sockets", nil),
	entryRow("doors", "Door choices", nil),
	entryRow("pets", "Pets", nil),
	entryRow("crafting", "Crafting", nil),
	entryRow("rarity", "Rarity colors", nil),
})

local order: { string } = {}
for _, entry in ipairs(Codex.ENTRIES) do
	table.insert(order, entry.id)
end
Codex.ORDER = table.freeze(order)

export type Entry = {
	id: string,
	label: string,
	hint: string?,
}

export type Unlocked = {
	attack: boolean,
	dodge: boolean,
	perfect: boolean,
	skills: boolean,
	telegraphs: boolean,
	shards: boolean,
	doors: boolean,
	pets: boolean,
	crafting: boolean,
	rarity: boolean,
}

export type State = {
	unlocked: Unlocked,
}

export type Opened = {
	ok: boolean,
	state: State,
	error: string?,
}

export type Page = {
	id: string,
	label: string,
}

export type Unlock = {
	ok: boolean,
	state: State,
	discovered: { string },
	keys: number,
	gold: number,
	error: string?,
}

export type Lookup = {
	ok: boolean,
	state: State,
	entries: { Page },
	error: string?,
}

export type Hint = {
	ok: boolean,
	state: State,
	entry: string?,
	hint: string?,
	error: string?,
}

local ERRORS = Codex.ERRORS
local CONFIG = Codex.CONFIG

local EXPECTED_ID = {
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

local EXPECTED_LABEL = {
	"Attack/combos",
	"Dodge",
	"Perfect dodge",
	"Skills",
	"Telegraph colors",
	"Shards/sockets",
	"Door choices",
	"Pets",
	"Crafting",
	"Rarity colors",
}

local EXPECTED_HINT: { [string]: string } = {
	attack = "Keep swinging",
	dodge = "Dodge!",
}

local FLAG_KEYS: { [string]: boolean } = {
	attack = true,
	dodge = true,
	perfect = true,
	skills = true,
	telegraphs = true,
	shards = true,
	doors = true,
	pets = true,
	crafting = true,
	rarity = true,
}

local function rulesOk(): string?
	if CONFIG.keys ~= 0 or CONFIG.gold ~= 0 then
		return ERRORS.rules
	end
	local seenConfig = 0
	for key in pairs(CONFIG) do
		if key ~= "keys" and key ~= "gold" then
			return ERRORS.rules
		end
		seenConfig += 1
	end
	if seenConfig ~= 2 then
		return ERRORS.rules
	end
	if #Codex.ORDER ~= 10 or #Codex.ENTRIES ~= 10 or #EXPECTED_ID ~= 10 then
		return ERRORS.rules
	end
	local seenId: { [string]: boolean } = {}
	local hintCount = 0
	for index, id in ipairs(Codex.ORDER) do
		local entry = Codex.ENTRIES[index]
		if type(id) ~= "string" or entry == nil or entry.id ~= id or id ~= EXPECTED_ID[index] then
			return ERRORS.rules
		end
		if seenId[id] == true or entry.label ~= EXPECTED_LABEL[index] then
			return ERRORS.rules
		end
		local expectedHint = EXPECTED_HINT[id]
		if expectedHint == nil then
			if entry.hint ~= nil then
				return ERRORS.rules
			end
		else
			if entry.hint ~= expectedHint then
				return ERRORS.rules
			end
			hintCount += 1
		end
		seenId[id] = true
	end
	if hintCount ~= 2 then
		return ERRORS.rules
	end
	return nil
end

local function blankUnlocked(): Unlocked
	return {
		attack = false,
		dodge = false,
		perfect = false,
		skills = false,
		telegraphs = false,
		shards = false,
		doors = false,
		pets = false,
		crafting = false,
		rarity = false,
	}
end

local function blankState(): State
	return {
		unlocked = blankUnlocked(),
	}
end

local function copyUnlocked(unlocked: Unlocked): Unlocked
	return {
		attack = unlocked.attack,
		dodge = unlocked.dodge,
		perfect = unlocked.perfect,
		skills = unlocked.skills,
		telegraphs = unlocked.telegraphs,
		shards = unlocked.shards,
		doors = unlocked.doors,
		pets = unlocked.pets,
		crafting = unlocked.crafting,
		rarity = unlocked.rarity,
	}
end

local function copyState(state: State): State
	return {
		unlocked = copyUnlocked(state.unlocked),
	}
end

local function foreign(
	value: { [any]: any },
	allowPaid: boolean,
	allow: { [string]: boolean },
	shapeErr: string
): string?
	if
		value.userId ~= nil
		or value.UserId ~= nil
		or value.playerId ~= nil
		or value.PlayerId ~= nil
		or value.guildId ~= nil
		or value.GuildId ~= nil
	then
		return ERRORS.id
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

local function flagsLook(value: any): boolean
	return type(value.attack) == "boolean"
		and type(value.dodge) == "boolean"
		and type(value.perfect) == "boolean"
		and type(value.skills) == "boolean"
		and type(value.telegraphs) == "boolean"
		and type(value.shards) == "boolean"
		and type(value.doors) == "boolean"
		and type(value.pets) == "boolean"
		and type(value.crafting) == "boolean"
		and type(value.rarity) == "boolean"
end

local function readFlags(value: any, allowPaid: boolean, shapeErr: string): (Unlocked?, string?)
	if type(value) ~= "table" then
		return nil, shapeErr
	end
	local problem = foreign(value, allowPaid, FLAG_KEYS, shapeErr)
	if problem ~= nil then
		return nil, problem
	end
	if allowPaid and value.paid ~= nil and type(value.paid) ~= "boolean" then
		return nil, shapeErr
	end
	if not flagsLook(value) then
		return nil, shapeErr
	end
	return {
		attack = value.attack,
		dodge = value.dodge,
		perfect = value.perfect,
		skills = value.skills,
		telegraphs = value.telegraphs,
		shards = value.shards,
		doors = value.doors,
		pets = value.pets,
		crafting = value.crafting,
		rarity = value.rarity,
	},
		nil
end

local function readState(value: any): (State?, string?)
	if type(value) ~= "table" then
		return nil, ERRORS.state
	end
	local problem = foreign(value, false, { unlocked = true }, ERRORS.state)
	if problem ~= nil then
		return nil, problem
	end
	local unlocked, unlockedErr = readFlags(value.unlocked, false, ERRORS.state)
	if unlocked == nil then
		return nil, unlockedErr or ERRORS.state
	end
	return {
		unlocked = unlocked,
	}, nil
end

local function isEntry(value: any): boolean
	return value == "attack"
		or value == "dodge"
		or value == "perfect"
		or value == "skills"
		or value == "telegraphs"
		or value == "shards"
		or value == "doors"
		or value == "pets"
		or value == "crafting"
		or value == "rarity"
end

local function readRequest(value: any): (string?, string?)
	if value == nil then
		return nil, nil
	end
	if type(value) ~= "table" then
		return nil, ERRORS.request
	end
	local problem = foreign(value, true, { stuck = true }, ERRORS.request)
	if problem ~= nil then
		return nil, problem
	end
	if value.paid ~= nil and type(value.paid) ~= "boolean" then
		return nil, ERRORS.request
	end
	if value.stuck == nil then
		return nil, nil
	end
	if type(value.stuck) ~= "string" then
		return nil, ERRORS.request
	end
	if not isEntry(value.stuck) then
		return nil, ERRORS.entry
	end
	return value.stuck, nil
end

local function entryById(id: string): Entry?
	for _, entry in ipairs(Codex.ENTRIES) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

local function page(id: string): Page
	local entry = entryById(id)
	local label = ""
	if entry ~= nil then
		label = entry.label
	end
	return {
		id = id,
		label = label,
	}
end

local function isOpen(unlocked: Unlocked, id: string): boolean
	if id == "attack" then
		return unlocked.attack
	elseif id == "dodge" then
		return unlocked.dodge
	elseif id == "perfect" then
		return unlocked.perfect
	elseif id == "skills" then
		return unlocked.skills
	elseif id == "telegraphs" then
		return unlocked.telegraphs
	elseif id == "shards" then
		return unlocked.shards
	elseif id == "doors" then
		return unlocked.doors
	elseif id == "pets" then
		return unlocked.pets
	elseif id == "crafting" then
		return unlocked.crafting
	elseif id == "rarity" then
		return unlocked.rarity
	end
	return false
end

local function sentence(id: string): string?
	local entry = entryById(id)
	if entry == nil then
		return nil
	end
	return entry.hint
end

local function applySeen(state: State, seen: Unlocked): State
	return {
		unlocked = {
			attack = state.unlocked.attack or seen.attack,
			dodge = state.unlocked.dodge or seen.dodge,
			perfect = state.unlocked.perfect or seen.perfect,
			skills = state.unlocked.skills or seen.skills,
			telegraphs = state.unlocked.telegraphs or seen.telegraphs,
			shards = state.unlocked.shards or seen.shards,
			doors = state.unlocked.doors or seen.doors,
			pets = state.unlocked.pets or seen.pets,
			crafting = state.unlocked.crafting or seen.crafting,
			rarity = state.unlocked.rarity or seen.rarity,
		},
	}
end

local function pushNew(ids: { string }, before: boolean, after: boolean, id: string)
	if before == false and after == true then
		table.insert(ids, id)
	end
end

local function discoveredIds(before: Unlocked, after: Unlocked): { string }
	local ids = {}
	pushNew(ids, before.attack, after.attack, "attack")
	pushNew(ids, before.dodge, after.dodge, "dodge")
	pushNew(ids, before.perfect, after.perfect, "perfect")
	pushNew(ids, before.skills, after.skills, "skills")
	pushNew(ids, before.telegraphs, after.telegraphs, "telegraphs")
	pushNew(ids, before.shards, after.shards, "shards")
	pushNew(ids, before.doors, after.doors, "doors")
	pushNew(ids, before.pets, after.pets, "pets")
	pushNew(ids, before.crafting, after.crafting, "crafting")
	pushNew(ids, before.rarity, after.rarity, "rarity")
	return ids
end

local function pages(unlocked: Unlocked): { Page }
	local list = {}
	if unlocked.attack then
		table.insert(list, page("attack"))
	end
	if unlocked.dodge then
		table.insert(list, page("dodge"))
	end
	if unlocked.perfect then
		table.insert(list, page("perfect"))
	end
	if unlocked.skills then
		table.insert(list, page("skills"))
	end
	if unlocked.telegraphs then
		table.insert(list, page("telegraphs"))
	end
	if unlocked.shards then
		table.insert(list, page("shards"))
	end
	if unlocked.doors then
		table.insert(list, page("doors"))
	end
	if unlocked.pets then
		table.insert(list, page("pets"))
	end
	if unlocked.crafting then
		table.insert(list, page("crafting"))
	end
	if unlocked.rarity then
		table.insert(list, page("rarity"))
	end
	return list
end

local function kept(current: State?): State
	if current == nil then
		return blankState()
	end
	return copyState(current)
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

local function failUnlock(state: State, err: string): Unlock
	return {
		ok = false,
		state = state,
		discovered = {},
		keys = 0,
		gold = 0,
		error = err,
	}
end

local function failLookup(state: State, err: string): Lookup
	return {
		ok = false,
		state = state,
		entries = {},
		error = err,
	}
end

local function failHint(state: State, err: string): Hint
	return {
		ok = false,
		state = state,
		error = err,
	}
end

function Codex.fresh(options: any): Opened
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

function Codex.unlock(state: any, seen: any): Unlock
	local broken = rulesOk()
	if broken ~= nil then
		return failUnlock(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local flags, seenErr = readFlags(seen, true, ERRORS.seen)
	local refused = refusal(stateErr, seenErr)
	if refused ~= nil then
		return failUnlock(kept(current), refused)
	end
	if current == nil then
		return failUnlock(blankState(), stateErr or ERRORS.state)
	end
	if flags == nil then
		return failUnlock(copyState(current), seenErr or ERRORS.seen)
	end
	local nextState = applySeen(current, flags)
	return {
		ok = true,
		state = nextState,
		discovered = discoveredIds(current.unlocked, nextState.unlocked),
		keys = CONFIG.keys,
		gold = CONFIG.gold,
	}
end

function Codex.lookup(state: any): Lookup
	local broken = rulesOk()
	if broken ~= nil then
		return failLookup(blankState(), broken)
	end
	local current, stateErr = readState(state)
	if current == nil then
		return failLookup(blankState(), stateErr or ERRORS.state)
	end
	return {
		ok = true,
		state = copyState(current),
		entries = pages(current.unlocked),
	}
end

function Codex.hint(state: any, request: any): Hint
	local broken = rulesOk()
	if broken ~= nil then
		return failHint(blankState(), broken)
	end
	local current, stateErr = readState(state)
	local stuck, requestErr = readRequest(request)
	local refused = refusal(stateErr, requestErr)
	if refused ~= nil then
		return failHint(kept(current), refused)
	end
	if current == nil then
		return failHint(blankState(), stateErr or ERRORS.state)
	end
	if requestErr ~= nil then
		return failHint(copyState(current), requestErr)
	end
	local text = nil
	if stuck ~= nil and isOpen(current.unlocked, stuck) then
		text = sentence(stuck)
	end
	return {
		ok = true,
		state = copyState(current),
		entry = stuck,
		hint = text,
	}
end

return Codex
