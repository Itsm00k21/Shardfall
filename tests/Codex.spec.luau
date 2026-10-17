--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Codex = require("../src/ReplicatedStorage/Shared/Codex")

local ERRORS = Codex.ERRORS
local CONFIG = Codex.CONFIG

local HINT = {
	attack = "Keep swinging",
	dodge = "Dodge!",
}

local LABEL = {
	attack = "Attack/combos",
	dodge = "Dodge",
	perfect = "Perfect dodge",
	skills = "Skills",
	telegraphs = "Telegraph colors",
	shards = "Shards/sockets",
	doors = "Door choices",
	pets = "Pets",
	crafting = "Crafting",
	rarity = "Rarity colors",
}

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh()
	return Codex.fresh().state
end

local function blank()
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

local function seen(open: boolean, overrides: { [string]: any }?)
	local row: { [string]: any } = {
		attack = open,
		dodge = open,
		perfect = open,
		skills = open,
		telegraphs = open,
		shards = open,
		doors = open,
		pets = open,
		crafting = open,
		rarity = open,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			row[key] = value
		end
	end
	return row
end

local function paysNothing(result: any)
	expect(result.keys).toEqual(0)
	expect(result.gold).toEqual(0)
	expect(result.cosmetic).toBeNil()
	expect(result.title).toBeNil()
	expect(result.payout).toBeNil()
	expect(result.reward).toBeNil()
	expect(result.robux).toBeNil()
	expect(result.productId).toBeNil()
	expect(result.blocked).toBeNil()
	expect(result.forceRead).toBeNil()
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

local function requiresCodex(source: string): boolean
	if string.find(source, "Shared.Codex", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/Codex", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.Codex", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("Codex")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('Codex')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("Codex entries", function()
	it("freezes ten entries in table order and starts locked", function()
		local opened = Codex.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.state.unlocked).toEqual(blank())
		expect(identical(opened.state, Codex.fresh().state)).toEqual(false)
		expect(identical(opened.state.unlocked, Codex.fresh().state.unlocked)).toEqual(false)
		expect(Codex.fresh({}).state).toEqual(opened.state)

		expect(Codex.ORDER).toEqual({
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
		})
		expect(#Codex.ENTRIES).toEqual(10)
		expect(CONFIG.keys).toEqual(0)
		expect(CONFIG.gold).toEqual(0)
		for index, id in ipairs(Codex.ORDER) do
			expect(Codex.ENTRIES[index].id).toEqual(id)
			expect(Codex.ENTRIES[index].label).toEqual(LABEL[id])
			expect(Codex.ENTRIES[index].hint).toEqual(HINT[id])
		end
		expect(Codex.ENTRIES[1].hint).toEqual("Keep swinging")
		expect(Codex.ENTRIES[2].hint).toEqual("Dodge!")
		expect(Codex.ENTRIES[4].hint).toBeNil()
		expect(Codex.ENTRIES[5].hint).toBeNil()
		expect(Codex.ENTRIES[6].hint).toBeNil()
		expect(Codex.ENTRIES[9].hint).toBeNil()
	end)
end)

describe("Codex unlock", function()
	it("unlocks once in table order and pays nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local flags = seen(false, {
			skills = true,
			attack = true,
			rarity = true,
		})
		table.freeze(flags)
		local opened = Codex.unlock(state, flags)
		expect(opened.ok).toEqual(true)
		expect(opened.discovered).toEqual({ "attack", "skills", "rarity" })
		expect(identical(opened.discovered, Codex.ORDER)).toEqual(false)
		expect(opened.state.unlocked.attack).toEqual(true)
		expect(opened.state.unlocked.skills).toEqual(true)
		expect(opened.state.unlocked.rarity).toEqual(true)
		expect(opened.state.unlocked.dodge).toEqual(false)
		paysNothing(opened)
		expect(state.unlocked.attack).toEqual(false)
		expect(flags.attack).toEqual(true)
		expect(identical(opened.state, state)).toEqual(false)
		expect(identical(opened.state.unlocked, state.unlocked)).toEqual(false)
		expect(identical(opened, Codex.unlock(state, flags))).toEqual(false)

		local again = Codex.unlock(opened.state, flags)
		expect(again.ok).toEqual(true)
		expect(again.discovered).toEqual({})
		expect(again.state.unlocked.attack).toEqual(true)
		expect(again.state.unlocked.dodge).toEqual(false)
		paysNothing(again)
		expect(opened.state.unlocked.dodge).toEqual(false)

		table.freeze(opened.state)
		table.freeze(opened.state.unlocked)
		local kept = Codex.unlock(opened.state, seen(false))
		expect(kept.ok).toEqual(true)
		expect(kept.discovered).toEqual({})
		expect(kept.state.unlocked).toEqual(opened.state.unlocked)
		expect(kept.state.unlocked.attack).toEqual(true)
		paysNothing(kept)
		expect(opened.state.unlocked.rarity).toEqual(true)
	end)

	it("unlocks every entry once and still pays nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local flags = seen(true)
		table.freeze(flags)
		local opened = Codex.unlock(state, flags)
		expect(opened.ok).toEqual(true)
		expect(opened.discovered).toEqual(Codex.ORDER)
		expect(opened.state.unlocked).toEqual(seen(true))
		paysNothing(opened)
		expect(state.unlocked).toEqual(blank())
		expect(flags.dodge).toEqual(true)

		local second = Codex.unlock(opened.state, seen(true, { paid = true }))
		expect(second.ok).toEqual(true)
		expect(second.discovered).toEqual({})
		expect(second.state.unlocked).toEqual(seen(true))
		paysNothing(second)
		expect(opened.state.unlocked.pets).toEqual(true)
	end)
end)

describe("Codex lookup", function()
	it("lists unlocked pages in order and does not nag", function()
		local state = fresh()
		local empty = Codex.lookup(state)
		expect(empty.ok).toEqual(true)
		expect(empty.entries).toEqual({})
		expect(empty.hint).toBeNil()
		expect(empty.stuck).toBeNil()
		expect(identical(empty.state, state)).toEqual(false)
		expect(state.unlocked).toEqual(blank())

		local flags = seen(false)
		flags.dodge = true
		flags.pets = true
		flags.crafting = true
		local opened = Codex.unlock(state, flags)
		table.freeze(opened.state)
		table.freeze(opened.state.unlocked)
		local shown = Codex.lookup(opened.state)
		local nagged = Codex.lookup(opened.state, { stuck = "attack" })
		expect(shown.ok).toEqual(true)
		expect(shown.entries).toEqual({
			{ id = "dodge", label = "Dodge" },
			{ id = "pets", label = "Pets" },
			{ id = "crafting", label = "Crafting" },
		})
		expect(nagged).toEqual(shown)
		expect(shown.hint).toBeNil()
		expect(shown.entries[1].hint).toBeNil()
		expect(shown.entries[3].hint).toBeNil()
		expect(identical(shown.entries, Codex.lookup(opened.state).entries)).toEqual(false)
		expect(identical(shown.entries[1], Codex.ENTRIES[2])).toEqual(false)
		expect(Codex.ENTRIES[2].hint).toEqual("Dodge!")
		expect(opened.state.unlocked.dodge).toEqual(true)
		expect(opened.state.unlocked.attack).toEqual(false)
		for _, page in ipairs(shown.entries) do
			expect(page.hint).toBeNil()
			expect(page.label == "Keep swinging").toEqual(false)
			expect(page.label == "Dodge!").toEqual(false)
		end
	end)
end)

describe("Codex hint", function()
	it("returns one sentence only when that entry is unlocked", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local locked = Codex.hint(state, { stuck = "attack" })
		expect(locked.ok).toEqual(true)
		expect(locked.entry).toEqual("attack")
		expect(locked.hint).toBeNil()
		expect(locked.state.unlocked.attack).toEqual(false)
		expect(state.unlocked.attack).toEqual(false)
		expect(locked.blocked).toBeNil()
		expect(locked.forceRead).toBeNil()

		local opened = Codex.unlock(state, seen(false, { attack = true, dodge = true }))
		table.freeze(opened.state)
		table.freeze(opened.state.unlocked)
		local attack = Codex.hint(opened.state, { stuck = "attack" })
		expect(attack.ok).toEqual(true)
		expect(attack.entry).toEqual("attack")
		expect(attack.hint).toEqual("Keep swinging")
		expect(type(attack.hint)).toEqual("string")
		expect(attack.hints).toBeNil()
		expect(attack.dodge).toBeNil()
		expect(attack.label).toBeNil()
		expect(attack.state.unlocked.dodge).toEqual(true)
		expect(identical(attack.state, opened.state)).toEqual(false)
		expect(opened.state.unlocked.attack).toEqual(true)

		local dodge = Codex.hint(opened.state, { stuck = "dodge" })
		expect(dodge.hint).toEqual("Dodge!")
		expect(dodge.entry).toEqual("dodge")
		expect(dodge.hints).toBeNil()
		expect(dodge.attack).toBeNil()
		expect(dodge.hint == "Keep swinging").toEqual(false)
		expect(opened.state.unlocked.dodge).toEqual(true)

		local both = Codex.hint(opened.state, { stuck = { "attack", "dodge" } })
		expect(both.ok).toEqual(false)
		expect(both.error).toEqual(ERRORS.request)
		expect(both.hint).toBeNil()
		expect(both.entry).toBeNil()
		expect(both.state.unlocked).toEqual(opened.state.unlocked)

		local clock = Codex.hint(opened.state, { stuck = "attack", elapsed = 8 })
		expect(clock.ok).toEqual(false)
		expect(clock.error).toEqual(ERRORS.request)
		expect(clock.hint).toBeNil()
		expect(opened.state.unlocked.attack).toEqual(true)
	end)

	it("returns no sentence for the other eight", function()
		local opened = Codex.unlock(fresh(), seen(true))
		local sentences = 0
		for index, id in ipairs(Codex.ORDER) do
			local result = Codex.hint(opened.state, { stuck = id })
			expect(result.ok).toEqual(true)
			expect(result.entry).toEqual(id)
			expect(result.hint).toEqual(Codex.ENTRIES[index].hint)
			expect(result.hints).toBeNil()
			if Codex.ENTRIES[index].hint ~= nil then
				sentences += 1
			end
		end
		expect(sentences).toEqual(2)
		for _, id in ipairs({
			"perfect",
			"skills",
			"telegraphs",
			"shards",
			"doors",
			"pets",
			"crafting",
			"rarity",
		}) do
			local result = Codex.hint(opened.state, { stuck = id })
			expect(result.hint).toBeNil()
			expect(result.entry).toEqual(id)
		end

		local quiet = Codex.hint(opened.state, nil)
		expect(quiet.ok).toEqual(true)
		expect(quiet.hint).toBeNil()
		expect(quiet.entry).toBeNil()
		expect(Codex.hint(opened.state, {}).hint).toBeNil()
		expect(Codex.hint(opened.state, { paid = false }).hint).toBeNil()
	end)
end)

describe("Codex paid", function()
	it("does not unlock an entry just because the roll was paid", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local function flags(paid: any)
			return seen(false, { attack = true, paid = paid })
		end
		local free = Codex.unlock(state, flags(false))
		local paid = Codex.unlock(state, flags(true))
		local omitted = Codex.unlock(state, flags(nil))
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.discovered).toEqual({ "attack" })
		expect(paid.state.unlocked.attack).toEqual(true)
		expect(paid.state.unlocked.dodge).toEqual(false)
		paysNothing(paid)
		expect(state.unlocked.attack).toEqual(false)

		local idle = Codex.unlock(state, seen(false, { paid = true }))
		expect(idle.ok).toEqual(true)
		expect(idle.discovered).toEqual({})
		expect(idle.state.unlocked).toEqual(blank())
		paysNothing(idle)

		local hinted = Codex.hint(free.state, { stuck = "attack", paid = true })
		local hintedFree = Codex.hint(free.state, { stuck = "attack", paid = false })
		local hintedOmit = Codex.hint(free.state, { stuck = "attack" })
		expect(hinted).toEqual(hintedFree)
		expect(hintedOmit).toEqual(hintedFree)
		expect(hinted.hint).toEqual("Keep swinging")
		expect(hinted.state.unlocked.dodge).toEqual(false)
	end)

	it("refuses a paid skip and unlocks nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		local opened = Codex.unlock(state, seen(false, { attack = true, dodge = true }))
		table.freeze(opened.state)
		table.freeze(opened.state.unlocked)
		local function refused(extra: { [string]: any })
			local flags = seen(true)
			for key, value in pairs(extra) do
				flags[key] = value
			end
			table.freeze(flags)
			local result = Codex.unlock(state, flags)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.paid)
			expect(result.discovered).toEqual({})
			paysNothing(result)
			expect(result.state.unlocked).toEqual(blank())
			expect(result.userId).toBeNil()
			local request: { [string]: any } = { stuck = "attack" }
			for key, value in pairs(extra) do
				request[key] = value
			end
			local hinted = Codex.hint(opened.state, request)
			expect(hinted.ok).toEqual(false)
			expect(hinted.error).toEqual(ERRORS.paid)
			expect(hinted.hint).toBeNil()
			expect(hinted.entry).toBeNil()
			expect(hinted.state.unlocked.attack).toEqual(true)
			expect(hinted.productId).toBeNil()
			expect(hinted.robux).toBeNil()
		end
		refused({ productId = "codex_skip" })
		refused({ robux = 25 })
		refused({ robux = 0 })
		refused({ cost = 1 })
		refused({ cost = 0 })
		refused({ skip = true })
		refused({ skip = false })
		expect(state.unlocked).toEqual(blank())
		expect(opened.state.unlocked.attack).toEqual(true)
		expect(opened.state.unlocked.dodge).toEqual(true)
	end)
end)

describe("Codex inputs", function()
	it("refuses a bad record or a user id without throwing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.unlocked)
		expect(Codex.fresh("no").error).toEqual(ERRORS.state)
		expect(Codex.fresh({ returning = true }).error).toEqual(ERRORS.state)
		expect(Codex.fresh({ paid = true }).error).toEqual(ERRORS.state)
		expect(Codex.fresh({ userId = 7 }).error).toEqual(ERRORS.id)
		expect(Codex.fresh({ userId = 7 }).state.unlocked).toEqual(blank())
		expect(Codex.fresh({ userId = 7 }).userId).toBeNil()
		expect(Codex.unlock(nil, seen(false)).error).toEqual(ERRORS.state)
		expect(Codex.unlock(state, nil).error).toEqual(ERRORS.seen)
		expect(Codex.lookup(nil).error).toEqual(ERRORS.state)
		expect(Codex.lookup(nil).entries).toEqual({})
		expect(Codex.hint(nil, { stuck = "attack" }).error).toEqual(ERRORS.state)
		expect(Codex.hint(state, "attack").error).toEqual(ERRORS.request)
		expect(Codex.hint(state, { stuck = "grove" }).error).toEqual(ERRORS.entry)
		expect(Codex.hint(state, { stuck = "loading" }).error).toEqual(ERRORS.entry)
		expect(Codex.hint(state, { stuck = 1 }).error).toEqual(ERRORS.request)
		expect(Codex.hint(state, { stuck = "" }).error).toEqual(ERRORS.entry)
		expect(Codex.unlock(state, { "attack" }).error).toEqual(ERRORS.seen)
		expect(Codex.unlock(state, { "attack" }).discovered).toEqual({})
		expect(Codex.unlock(state, { "attack" }).state.unlocked).toEqual(blank())

		local partial = { attack = true }
		local missing = Codex.unlock(state, partial)
		expect(missing.ok).toEqual(false)
		expect(missing.error).toEqual(ERRORS.seen)
		expect(missing.discovered).toEqual({})
		expect(missing.state.unlocked.attack).toEqual(false)
		paysNothing(missing)
		expect(partial.attack).toEqual(true)
		expect(state.unlocked.attack).toEqual(false)

		local badFlag = seen(true)
		badFlag.attack = "yes"
		expect(Codex.unlock(state, badFlag).error).toEqual(ERRORS.seen)
		local badPaid = seen(false)
		badPaid.paid = "yes"
		expect(Codex.unlock(state, badPaid).error).toEqual(ERRORS.seen)
		expect(Codex.hint(state, { stuck = "attack", paid = "yes" }).error).toEqual(ERRORS.request)
		local clocked = seen(true)
		clocked.elapsed = 8
		local timed = Codex.unlock(state, clocked)
		expect(timed.error).toEqual(ERRORS.seen)
		expect(timed.discovered).toEqual({})
		expect(timed.state.unlocked).toEqual(blank())

		local withGold = { unlocked = blank(), gold = 10 }
		local gold = Codex.unlock(withGold, seen(true))
		expect(gold.error).toEqual(ERRORS.state)
		expect(gold.gold).toEqual(0)
		expect(gold.keys).toEqual(0)
		expect(gold.discovered).toEqual({})
		expect(withGold.gold).toEqual(10)

		local extra = { unlocked = blank() }
		extra.unlocked.extra = true
		expect(Codex.lookup(extra).error).toEqual(ERRORS.state)
		local dropped = blank()
		dropped.rarity = nil
		expect(Codex.lookup({ unlocked = dropped }).error).toEqual(ERRORS.state)
		local numbered = blank()
		numbered.doors = 1
		expect(Codex.unlock({ unlocked = numbered }, seen(true)).error).toEqual(ERRORS.state)

		local both = seen(true)
		both.userId = 1
		both.productId = "skip"
		local ranked = Codex.unlock(state, both)
		expect(ranked.ok).toEqual(false)
		expect(ranked.error).toEqual(ERRORS.id)
		expect(ranked.discovered).toEqual({})
		expect(ranked.state.unlocked).toEqual(blank())
		expect(ranked.userId).toBeNil()
		expect(ranked.productId).toBeNil()

		local function refuseId(key: string, value: any)
			local flags = seen(true)
			flags[key] = value
			local result = Codex.unlock(state, flags)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.id)
			expect(result.discovered).toEqual({})
			expect(result.state.unlocked).toEqual(blank())
			expect(result[key]).toBeNil()
			paysNothing(result)
			local hinted = Codex.hint(state, { stuck = "attack", [key] = value })
			expect(hinted.ok).toEqual(false)
			expect(hinted.error).toEqual(ERRORS.id)
			expect(hinted.hint).toBeNil()
			expect(hinted[key]).toBeNil()
		end
		refuseId("userId", 15)
		refuseId("UserId", 15)
		refuseId("playerId", 15)
		refuseId("PlayerId", 15)
		refuseId("guildId", "grove")
		refuseId("GuildId", "grove")
		expect(state.unlocked).toEqual(blank())
	end)

	it("freezes the codex tables", function()
		expect(function()
			Codex.ERRORS.paid = "nope"
		end).toThrow()
		expect(function()
			Codex.CONFIG.keys = 10
		end).toThrow()
		expect(function()
			Codex.CONFIG.gold = 5
		end).toThrow()
		expect(function()
			Codex.ORDER[1] = "dodge"
		end).toThrow()
		expect(function()
			Codex.ENTRIES[1] = { id = "attack", label = "nope" }
		end).toThrow()
		expect(function()
			local row = Codex.ENTRIES[1]
			row.hint = "nope"
		end).toThrow()
		expect(function()
			local row = Codex.ENTRIES[3]
			row.label = "nope"
		end).toThrow()
	end)
end)

describe("Codex isolation", function()
	it("is required by nothing in src and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/Codex.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.date", 1, true)).toBeNil()
		expect(string.find(source, "Random", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStore", 1, true)).toBeNil()
		expect(string.find(source, "MemoryStore", 1, true)).toBeNil()
		expect(string.find(source, "Marketplace", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresCodex(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
