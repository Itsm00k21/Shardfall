--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RaidStrategy = require("../src/ReplicatedStorage/Shared/RaidStrategy")

local ERRORS = RaidStrategy.ERRORS

local function clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = clone(child)
	end
	return copy
end

local function freezeDeep(value: any)
	if type(value) ~= "table" then
		return
	end
	for _, child in pairs(value) do
		freezeDeep(child)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
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

local function mentionsStrategy(source: string): boolean
	if string.find(source, "Shared.RaidStrategy", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/RaidStrategy", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.RaidStrategy", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("RaidStrategy")', 1, true) ~= nil then
		return true
	end
	return false
end

local function lead(id: any, kind: any, x: any, y: any, extra: any?): any
	local request = {
		role = "lead",
		id = id,
		kind = kind,
		x = x,
		y = y,
	}
	if type(extra) == "table" then
		for key, child in pairs(extra) do
			request[key] = child
		end
	end
	return request
end

describe("RaidStrategy config", function()
	it("pins the kinds, the lead, and the caps", function()
		expect(RaidStrategy.CONFIG.maxMarkers).toEqual(16)
		expect(RaidStrategy.CONFIG.maxPresets).toEqual(8)
		expect(RaidStrategy.CONFIG.maxIdLength).toEqual(64)
		expect(RaidStrategy.CONFIG.leadRole).toEqual("lead")
		expect(RaidStrategy.CONFIG.kinds.stack).toEqual(true)
		expect(RaidStrategy.CONFIG.kinds.soak1).toEqual(true)
		expect(RaidStrategy.CONFIG.kinds.soak2).toEqual(true)
		expect(RaidStrategy.CONFIG.kinds.spread).toBeNil()
		expect(RaidStrategy.CONFIG.kinds.soak).toBeNil()
		expect(RaidStrategy.CONFIG.kinds.soak3).toBeNil()
		expect(RaidStrategy.CONFIG.doubleMarks).toBeNil()
		expect(RaidStrategy.CONFIG.tuesdayOffset).toBeNil()
		expect(RaidStrategy.ERRORS.role).toEqual("Only the raid lead can change the board.")
		expect(RaidStrategy.ERRORS.full).toEqual("That board is full.")
		expect(RaidStrategy.ERRORS.presetsFull).toEqual("That guild's preset list is full.")
		expect(RaidStrategy.ERRORS.missing).toEqual("That marker is not on the board.")
		expect(RaidStrategy.ERRORS.skip).toEqual(
			"The strategy board has no paid marker, preset, or skip."
		)
		local left = RaidStrategy.fresh()
		local right = RaidStrategy.fresh()
		expect(left).toEqual({ markers = {} })
		expect(left == right).toEqual(false)
		expect(RaidStrategy.freshPresets()).toEqual({ guilds = {} })
		expect(RaidStrategy.freshPresets() == RaidStrategy.freshPresets()).toEqual(false)
	end)

	it("freezes the config, the kinds, and the errors", function()
		expect(function()
			RaidStrategy.CONFIG.maxMarkers = 4
		end).toThrow()
		expect(function()
			RaidStrategy.CONFIG.kinds.spread = true
		end).toThrow()
		expect(function()
			RaidStrategy.CONFIG.kinds.stack = false
		end).toThrow()
		expect(function()
			RaidStrategy.ERRORS.skip = "nope"
		end).toThrow()
	end)

	it("stays pure and unrequired", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/RaidStrategy.luau")
		local _, requires = string.gsub(source, "require%(", "")
		expect(requires).toEqual(0)
		local banned = {
			"math.random",
			"Random.new",
			"os.time",
			"os.clock",
			"os.date",
			"os.",
			"GetService",
			"DataStore",
			"MemoryStore",
			"MarketplaceService",
			"DateTime",
			"tick(",
			"task.wait",
			"require(",
			"RaidLockout",
			"RaidMarks",
			"Raids",
			"Schema",
			"RaidService",
			"DungeonService",
			"Keybinds",
			"UiRouter",
			"weekKey",
			"tuesdayOffset",
			"doubleMarks",
			"HttpService",
			"MessagingService",
		}
		for _, needle in ipairs(banned) do
			expect(string.find(source, needle, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if
				path ~= "src/ReplicatedStorage/Shared/RaidStrategy.luau"
				and mentionsStrategy(fs.readFile(path))
			then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)

describe("RaidStrategy place", function()
	it("upserts by id and returns a new table", function()
		local request = lead("  A  ", " STACK ", -0, 1)
		local board = {
			userId = 5,
			practice = true,
			markers = {},
		}
		freezeDeep(request)
		local first = RaidStrategy.place(board, request)
		expect(first.ok).toEqual(true)
		expect(first.persist).toEqual(true)
		expect(first.error).toBeNil()
		expect(first.loot).toBeNil()
		expect(first.marks).toBeNil()
		expect(first.rewards).toBeNil()
		expect(first.state).toEqual({
			markers = {
				{ id = "A", kind = "stack", x = 0, y = 1 },
			},
		})
		expect(first.state == board).toEqual(false)
		expect(board.userId).toEqual(5)
		expect(board.markers).toEqual({})
		expect(first.state.userId).toBeNil()

		local moved = RaidStrategy.place(first.state, lead("A", "soak1", 0.25, 0.5))
		expect(moved.ok).toEqual(true)
		expect(moved.persist).toEqual(true)
		expect(moved.state.markers).toEqual({
			{ id = "A", kind = "soak1", x = 0.25, y = 0.5 },
		})
		expect(first.state.markers[1].kind).toEqual("stack")
		expect(moved.state == first.state).toEqual(false)
		expect(moved.state.markers == first.state.markers).toEqual(false)
		expect(moved.state.markers[1] == first.state.markers[1]).toEqual(false)

		local second = RaidStrategy.place(moved.state, lead("a", " Soak2 ", 0, 0))
		local third = RaidStrategy.place(second.state, lead("b", "soak2", 1, 0))
		expect(third.state.markers[1].id).toEqual("A")
		expect(third.state.markers[2].id).toEqual("a")
		expect(third.state.markers[3].id).toEqual("b")
		local shifted = RaidStrategy.place(third.state, lead("a", "stack", 0.5, 0.5))
		expect(shifted.persist).toEqual(true)
		expect(shifted.state.markers[1].id).toEqual("A")
		expect(shifted.state.markers[2]).toEqual({ id = "a", kind = "stack", x = 0.5, y = 0.5 })
		expect(shifted.state.markers[3].id).toEqual("b")
		expect(third.state.markers[2].kind).toEqual("soak2")

		local same = RaidStrategy.place(shifted.state, lead("a", "stack", 0.5, 0.5))
		expect(same.ok).toEqual(true)
		expect(same.persist).toEqual(false)
		expect(same.state.markers).toEqual(shifted.state.markers)
		expect(same.state == shifted.state).toEqual(false)

		local cap = RaidStrategy.CONFIG.maxIdLength
		local fitted = RaidStrategy.place(nil, lead(string.rep("n", cap), "stack", 0, 0))
		expect(fitted.ok).toEqual(true)
		expect(fitted.state.markers[1].id).toEqual(string.rep("n", cap))
	end)

	it("refuses an unknown kind, a blank id, or a coordinate outside 0..1", function()
		local board = RaidStrategy.place(nil, lead("keep", "stack", 0, 1)).state
		freezeDeep(board)
		local cases = {
			{ lead("  ", "stack", 0, 0), ERRORS.id },
			{ lead("", "stack", 0, 0), ERRORS.id },
			{ lead(1, "stack", 0, 0), ERRORS.id },
			{
				lead(string.rep("n", RaidStrategy.CONFIG.maxIdLength + 1), "stack", 0, 0),
				ERRORS.id,
			},
			{ lead("keep", "spread", 0, 0), ERRORS.kind },
			{ lead("keep", "soak", 0, 0), ERRORS.kind },
			{ lead("keep", "soak3", 0, 0), ERRORS.kind },
			{ lead("keep", "soak 1", 0, 0), ERRORS.kind },
			{ lead("keep", "", 0, 0), ERRORS.kind },
			{ lead("keep", 1, 0, 0), ERRORS.kind },
			{ lead("new", "stack", -0.1, 0), ERRORS.coord },
			{ lead("new", "stack", 1.1, 0), ERRORS.coord },
			{ lead("new", "stack", 0, -0.1), ERRORS.coord },
			{ lead("new", "stack", 0, 1.1), ERRORS.coord },
			{ lead("new", "stack", 0 / 0, 0), ERRORS.coord },
			{ lead("new", "stack", math.huge, 0), ERRORS.coord },
			{ lead("new", "stack", 0, -math.huge), ERRORS.coord },
			{ lead("new", "stack", "0.5", 0.5), ERRORS.coord },
			{ lead("new", "stack", nil, 0), ERRORS.coord },
			{ lead("keep", "spread", 4, 4), ERRORS.kind },
			{ lead("   ", "nope", 9, 9), ERRORS.id },
		}
		for _, case in ipairs(cases) do
			local result = RaidStrategy.place(board, case[1])
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.error).toEqual(case[2])
			expect(result.state.markers).toEqual(board.markers)
		end
		expect(board.markers).toEqual({
			{ id = "keep", kind = "stack", x = 0, y = 1 },
		})
		local edges = RaidStrategy.place(nil, lead("edge", "stack", 0, 1))
		expect(edges.state.markers[1]).toEqual({ id = "edge", kind = "stack", x = 0, y = 1 })
	end)

	it("lets only the lead place, move, or remove", function()
		local board = RaidStrategy.place(nil, lead("a", "stack", 0.2, 0.3)).state
		local roles = {
			"assistant",
			"Assistant",
			"raid lead",
			"Raid Lead",
			"tank",
			"healer",
			"dps",
			"flex",
			"",
			"  ",
		}
		for _, role in ipairs(roles) do
			local placed = RaidStrategy.place(board, {
				role = role,
				id = "b",
				kind = "soak1",
				x = 1,
				y = 1,
			})
			expect(placed.ok).toEqual(false)
			expect(placed.persist).toEqual(false)
			expect(placed.error).toEqual(ERRORS.role)
			expect(placed.state.markers).toEqual(board.markers)
			local moved = RaidStrategy.place(board, {
				role = role,
				id = "a",
				kind = "soak2",
				x = 0,
				y = 0,
			})
			expect(moved.error).toEqual(ERRORS.role)
			expect(moved.state.markers[1]).toEqual(board.markers[1])
			local removed = RaidStrategy.remove(board, { role = role, id = "a" })
			expect(removed.ok).toEqual(false)
			expect(removed.persist).toEqual(false)
			expect(removed.error).toEqual(ERRORS.role)
			expect(removed.state.markers).toEqual(board.markers)
		end
		local missingRole = RaidStrategy.place(board, { id = "b", kind = "stack", x = 0, y = 0 })
		expect(missingRole.error).toEqual(ERRORS.role)
		local numericRole = RaidStrategy.remove(board, { role = 1, id = "a" })
		expect(numericRole.error).toEqual(ERRORS.role)
		expect(board.markers).toEqual({
			{ id = "a", kind = "stack", x = 0.2, y = 0.3 },
		})
		local spaced = RaidStrategy.place(board, {
			role = "  Lead  ",
			id = "b",
			kind = "soak1",
			x = 1,
			y = 0,
		})
		expect(spaced.ok).toEqual(true)
		expect(#spaced.state.markers).toEqual(2)
		local assistantFirst = RaidStrategy.place(board, {
			role = "assistant",
			id = "b",
			kind = "spread",
			x = 5,
			y = 5,
		})
		expect(assistantFirst.error).toEqual(ERRORS.role)
	end)

	it("refuses a new marker when the board is full", function()
		local state = nil
		for index = 1, RaidStrategy.CONFIG.maxMarkers do
			local result = RaidStrategy.place(state, lead("m" .. tostring(index), "stack", 0, 0))
			expect(result.ok).toEqual(true)
			expect(result.persist).toEqual(true)
			state = result.state
		end
		expect(#state.markers).toEqual(16)
		local before = clone(state)
		local overflow = RaidStrategy.place(state, lead("extra", "soak1", 1, 1))
		expect(overflow.ok).toEqual(false)
		expect(overflow.persist).toEqual(false)
		expect(overflow.error).toEqual(ERRORS.full)
		expect(overflow.state.markers).toEqual(before.markers)
		expect(state.markers).toEqual(before.markers)
		expect(overflow.state.markers[1].id).toEqual("m1")
		expect(overflow.state.markers[16].id).toEqual("m16")

		local moved = RaidStrategy.place(state, lead("m1", "soak2", 0.5, 0.25))
		expect(moved.ok).toEqual(true)
		expect(moved.persist).toEqual(true)
		expect(#moved.state.markers).toEqual(16)
		expect(moved.state.markers[1]).toEqual({ id = "m1", kind = "soak2", x = 0.5, y = 0.25 })
		expect(moved.state.markers[2].id).toEqual("m2")
		expect(state.markers[1].kind).toEqual("stack")
		local stillFull = RaidStrategy.place(moved.state, lead("extra", "stack", 0, 1))
		expect(stillFull.error).toEqual(ERRORS.full)
		expect(#stillFull.state.markers).toEqual(16)

		local removed = RaidStrategy.remove(moved.state, { role = "lead", id = "m2" })
		expect(removed.ok).toEqual(true)
		expect(removed.persist).toEqual(true)
		expect(#removed.state.markers).toEqual(15)
		expect(removed.state.markers[1].id).toEqual("m1")
		expect(removed.state.markers[2].id).toEqual("m3")
		local added = RaidStrategy.place(removed.state, lead("extra", "stack", 0, 1))
		expect(added.ok).toEqual(true)
		expect(added.state.markers[15].id).toEqual("m16")
		expect(added.state.markers[16]).toEqual({ id = "extra", kind = "stack", x = 0, y = 1 })
		expect(removed.state.markers[15].id).toEqual("m16")
	end)
end)

describe("RaidStrategy remove", function()
	it("removes by id and refuses a missing id", function()
		local first = RaidStrategy.place(nil, lead("a", "stack", 0, 0)).state
		local second = RaidStrategy.place(first, lead("b", "soak1", 1, 1)).state
		local third = RaidStrategy.place(second, lead("c", "soak2", 0.5, 0.5)).state
		freezeDeep(third)
		local missing = RaidStrategy.remove(third, { role = "lead", id = "nope" })
		expect(missing.ok).toEqual(false)
		expect(missing.persist).toEqual(false)
		expect(missing.error).toEqual(ERRORS.missing)
		expect(missing.state.markers).toEqual(third.markers)
		expect(third.markers[2].id).toEqual("b")
		local blank = RaidStrategy.remove(third, { role = "lead", id = "   " })
		expect(blank.error).toEqual(ERRORS.id)
		local assistant = RaidStrategy.remove(third, { role = "assistant", id = "missing" })
		expect(assistant.error).toEqual(ERRORS.role)
		local cut = RaidStrategy.remove(third, { role = "lead", id = " b " })
		expect(cut.ok).toEqual(true)
		expect(cut.persist).toEqual(true)
		expect(cut.error).toBeNil()
		expect(cut.state.markers).toEqual({
			{ id = "a", kind = "stack", x = 0, y = 0 },
			{ id = "c", kind = "soak2", x = 0.5, y = 0.5 },
		})
		expect(cut.state == third).toEqual(false)
		expect(third.markers[2].id).toEqual("b")
		expect(#third.markers).toEqual(3)
	end)
end)

describe("RaidStrategy context", function()
	it("ignores practice, difficulty, the Tuesday week, and loot", function()
		local placed = RaidStrategy.place(
			nil,
			lead("s", "soak2", 0.25, 0.75, {
				practice = true,
				difficulty = "shardbreaker",
				week = 2962,
				weekKey = 2963,
				userId = 42,
				player = 7,
				loot = true,
				rewards = { "gear" },
				marks = 10,
				bossId = "twins",
				guided = true,
				phase = 3,
			})
		)
		expect(placed.ok).toEqual(true)
		expect(placed.persist).toEqual(true)
		expect(placed.state).toEqual({
			markers = {
				{ id = "s", kind = "soak2", x = 0.25, y = 0.75 },
			},
		})
		expect(placed.loot).toBeNil()
		expect(placed.marks).toBeNil()
		expect(placed.rewards).toBeNil()
		local other = RaidStrategy.place(
			placed.state,
			lead("t", "stack", 0, 1, {
				userId = 99,
				practice = false,
				difficulty = "story",
				weekKey = 1,
				loot = { item = "sword" },
			})
		)
		expect(#other.state.markers).toEqual(2)
		expect(other.state.markers[1].id).toEqual("s")
		expect(other.state.markers[2].id).toEqual("t")
		local practiceRole = RaidStrategy.place(other.state, {
			role = "assistant",
			id = "u",
			kind = "stack",
			x = 0,
			y = 0,
			practice = true,
			difficulty = "hard",
			weekKey = 2963,
		})
		expect(practiceRole.error).toEqual(ERRORS.role)
		expect(#practiceRole.state.markers).toEqual(2)
		expect(other.state.markers[2].id).toEqual("t")
	end)

	it("refuses a paid marker, preset, or skip", function()
		local keys = {
			"skip",
			"waive",
			"waiveLock",
			"waiveLockout",
			"bypass",
			"bypassLock",
			"paid",
			"robux",
			"premium",
			"price",
			"productId",
			"gamePass",
			"force",
			"unlock",
			"skipLock",
			"skipLockout",
			"paidMarker",
			"paidPreset",
			"skipCap",
			"buyMarker",
			"buyPreset",
		}
		for _, key in ipairs(keys) do
			local request = lead("a", "stack", 0.5, 0.5)
			request[key] = false
			local result = RaidStrategy.place(nil, request)
			expect(result.ok).toEqual(false)
			expect(result.persist).toEqual(false)
			expect(result.error).toEqual(ERRORS.skip)
			expect(result.state.markers).toEqual({})
			expect(result.loot).toBeNil()
		end
		local board = RaidStrategy.place(nil, lead("a", "stack", 0, 0)).state
		local field = RaidStrategy.place(board, lead("b", "soak1", 1, 1, { paidMarker = false }))
		expect(field.error).toEqual(ERRORS.skip)
		expect(field.state.markers).toEqual(board.markers)
		expect(board.markers[1].id).toEqual("a")
		local extra = RaidStrategy.place(board, lead("b", "soak1", 1, 1), { skip = true })
		expect(extra.ok).toEqual(false)
		expect(extra.persist).toEqual(false)
		expect(extra.error).toEqual(ERRORS.skip)
		expect(extra.state.markers).toEqual({})
		expect(#board.markers).toEqual(1)
		local forced = RaidStrategy.remove(board, { role = "lead", id = "a", force = true })
		expect(forced.error).toEqual(ERRORS.skip)
		expect(forced.state.markers).toEqual(board.markers)
	end)
end)

describe("RaidStrategy state", function()
	it("refuses a broken board and does not replace it", function()
		local marker = { id = "a", kind = "stack", x = 0, y = 0 }
		local hole = { marker, [3] = { id = "c", kind = "stack", x = 1, y = 1 } }
		local tooMany = {}
		for index = 1, RaidStrategy.CONFIG.maxMarkers + 1 do
			table.insert(tooMany, { id = "m" .. tostring(index), kind = "stack", x = 0, y = 0 })
		end
		local samples = {
			"board",
			1,
			true,
			{ markers = "no" },
			{ markers = { "x" } },
			{ markers = { { id = "a", kind = "stack", x = 2, y = 0 } } },
			{ markers = { { id = "a", kind = "STACK", x = 0, y = 0 } } },
			{ markers = { { id = " a ", kind = "stack", x = 0, y = 0 } } },
			{
				markers = {
					{ id = "a", kind = "stack", x = 0, y = 0 },
					{ id = "a", kind = "soak1", x = 1, y = 1 },
				},
			},
			{ markers = { { id = "a", kind = "stack", x = 0, y = math.huge } } },
			{ markers = { { id = "a", kind = "stack", x = 0, y = 0, [1] = "z" } } },
			{ markers = hole },
			{ [1] = marker, markers = { marker } },
			{ markers = tooMany },
		}
		for _, sample in ipairs(samples) do
			local before = clone(sample)
			local viewed = RaidStrategy.view(sample)
			local placed = RaidStrategy.place(sample, lead("z", "stack", 1, 1))
			local removed = RaidStrategy.remove(sample, { role = "lead", id = "a" })
			expect(viewed.ok).toEqual(false)
			expect(viewed.persist).toEqual(false)
			expect(viewed.error).toEqual(ERRORS.state)
			expect(viewed.state).toEqual({ markers = {} })
			expect(placed.error).toEqual(ERRORS.state)
			expect(placed.persist).toEqual(false)
			expect(placed.state.markers).toEqual({})
			expect(removed.error).toEqual(ERRORS.state)
			expect(sample).toEqual(before)
		end
		local nanBoard = {
			markers = {
				{ id = "a", kind = "stack", x = 0 / 0, y = 0 },
			},
		}
		local nanResult = RaidStrategy.place(nanBoard, lead("z", "stack", 1, 1))
		expect(nanResult.error).toEqual(ERRORS.state)
		expect(nanResult.persist).toEqual(false)
		expect(nanResult.state.markers).toEqual({})
		expect(nanBoard.markers[1].id).toEqual("a")
		expect(nanBoard.markers[1].y).toEqual(0)
		expect(nanBoard.markers[1].x == nanBoard.markers[1].x).toEqual(false)
		local dirty = {
			userId = 5,
			practice = true,
			loot = true,
			markers = {
				{ id = "a", kind = "stack", x = 0.5, y = 0.5, note = "mine", loot = true },
			},
		}
		local viewed = RaidStrategy.view(dirty)
		expect(viewed.ok).toEqual(true)
		expect(viewed.persist).toEqual(false)
		expect(viewed.state).toEqual({
			markers = {
				{ id = "a", kind = "stack", x = 0.5, y = 0.5 },
			},
		})
		expect(dirty.userId).toEqual(5)
		expect(dirty.markers[1].note).toEqual("mine")
		expect(viewed.state == dirty).toEqual(false)
		local peeked = RaidStrategy.view(nil)
		expect(peeked.ok).toEqual(true)
		expect(peeked.persist).toEqual(false)
		expect(peeked.state).toEqual({ markers = {} })
		local skipped = RaidStrategy.view(dirty, { practice = true })
		expect(skipped.error).toEqual(ERRORS.skip)
		expect(skipped.state.markers).toEqual({})
		expect(dirty.markers[1].id).toEqual("a")
		RaidStrategy.place(nil, nil)
		RaidStrategy.remove(nil, nil)
		RaidStrategy.view(0 / 0)
		RaidStrategy.save(nil, nil)
		RaidStrategy.load(true, { guildId = "Grove", name = "P" })
	end)
end)

describe("RaidStrategy presets", function()
	it("copies markers per guild and load does not write the preset", function()
		local live = RaidStrategy.place(nil, lead("a", "stack", 0.2, 0.4)).state
		local before = clone(live)
		local request = {
			guildId = "  Grove  ",
			name = "  Twins P2  ",
			role = "assistant",
			board = live,
			practice = true,
			difficulty = "hard",
			weekKey = 2963,
			userId = 4,
			loot = true,
		}
		local saved = RaidStrategy.save(nil, request)
		expect(saved.ok).toEqual(true)
		expect(saved.persist).toEqual(true)
		expect(saved.error).toBeNil()
		expect(saved.loot).toBeNil()
		expect(saved.state.guilds[1].guildId).toEqual("Grove")
		expect(saved.state.guilds[1].presets[1].name).toEqual("Twins P2")
		expect(saved.state.guilds[1].presets[1].markers).toEqual(before.markers)
		expect(saved.board.markers).toEqual(before.markers)
		expect(saved.board.markers == saved.state.guilds[1].presets[1].markers).toEqual(false)
		expect(saved.state.guilds[1].presets[1].markers[1] == live.markers[1]).toEqual(false)
		live.markers[1].x = 0.9
		expect(saved.state.guilds[1].presets[1].markers[1].x).toEqual(0.2)
		expect(live.markers[1].x).toEqual(0.9)

		local book = saved.state
		freezeDeep(book)
		local loaded = RaidStrategy.load(book, {
			guildId = "Grove",
			name = "Twins P2",
			role = "tank",
			board = { markers = { { id = "nope", kind = "stack", x = 0, y = 0 } } },
			practice = true,
			difficulty = "story",
			weekKey = 2962,
		})
		expect(loaded.ok).toEqual(true)
		expect(loaded.persist).toEqual(false)
		expect(loaded.error).toBeNil()
		expect(loaded.board.markers).toEqual(before.markers)
		expect(loaded.state.guilds).toEqual(book.guilds)
		expect(loaded.state == book).toEqual(false)
		expect(loaded.board.markers == book.guilds[1].presets[1].markers).toEqual(false)
		expect(loaded.board == loaded.state).toEqual(false)
		loaded.board.markers[1].x = 0.1
		expect(book.guilds[1].presets[1].markers[1].x).toEqual(0.2)
		expect(loaded.state.guilds[1].presets[1].markers[1].x).toEqual(0.2)
		expect(#book.guilds[1].presets).toEqual(1)

		local moved = RaidStrategy.place(live, lead("a", "soak1", 1, 0))
		local again = RaidStrategy.load(book, { guildId = "Grove", name = "Twins P2" })
		expect(again.board.markers[1].kind).toEqual("stack")
		expect(moved.state.markers[1].kind).toEqual("soak1")

		local missing = RaidStrategy.load(book, { guildId = "Grove", name = "nope" })
		expect(missing.ok).toEqual(false)
		expect(missing.persist).toEqual(false)
		expect(missing.error).toEqual(ERRORS.preset)
		expect(missing.board.markers).toEqual({})
		expect(missing.state.guilds).toEqual(book.guilds)
		expect(#book.guilds[1].presets).toEqual(1)

		local empty = RaidStrategy.save(nil, {
			guildId = "Grove",
			name = "Empty",
			board = { markers = {} },
		})
		expect(empty.ok).toEqual(true)
		expect(empty.state.guilds[1].presets[1].markers).toEqual({})
		local loadedEmpty = RaidStrategy.load(empty.state, { guildId = "Grove", name = "Empty" })
		expect(loadedEmpty.ok).toEqual(true)
		expect(loadedEmpty.persist).toEqual(false)
		expect(loadedEmpty.board).toEqual({ markers = {} })

		local lower = RaidStrategy.save(empty.state, {
			guildId = "grove",
			name = "Empty",
			board = live,
		})
		expect(lower.ok).toEqual(true)
		expect(#lower.state.guilds).toEqual(2)
		expect(lower.state.guilds[1].guildId).toEqual("Grove")
		expect(lower.state.guilds[2].guildId).toEqual("grove")
		local otherName = RaidStrategy.save(lower.state, {
			guildId = "Grove",
			name = "empty",
			board = { markers = {} },
		})
		expect(#otherName.state.guilds[1].presets).toEqual(2)
		expect(otherName.state.guilds[1].presets[2].name).toEqual("empty")

		local same = RaidStrategy.save(saved.state, {
			guildId = "Grove",
			name = "Twins P2",
			board = { markers = before.markers },
		})
		expect(same.ok).toEqual(true)
		expect(same.persist).toEqual(false)
		expect(same.state.guilds).toEqual(saved.state.guilds)
	end)

	it("refuses a new preset when that guild is full", function()
		local board = {
			markers = {
				{ id = "a", kind = "stack", x = 0, y = 0 },
			},
		}
		local store = nil
		for index = 1, RaidStrategy.CONFIG.maxPresets do
			local result = RaidStrategy.save(store, {
				guildId = "Grove",
				name = "P" .. tostring(index),
				board = board,
			})
			expect(result.ok).toEqual(true)
			expect(result.persist).toEqual(true)
			store = result.state
		end
		expect(#store.guilds[1].presets).toEqual(8)
		local before = clone(store)
		local ninth = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "P9",
			board = board,
		})
		expect(ninth.ok).toEqual(false)
		expect(ninth.persist).toEqual(false)
		expect(ninth.error).toEqual(ERRORS.presetsFull)
		expect(ninth.board.markers).toEqual({})
		expect(ninth.state.guilds).toEqual(before.guilds)
		expect(store).toEqual(before)
		expect(ninth.state.guilds[1].presets[1].name).toEqual("P1")
		expect(ninth.state.guilds[1].presets[8].name).toEqual("P8")

		local moved = {
			markers = {
				{ id = "a", kind = "soak2", x = 1, y = 1 },
			},
		}
		local updated = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "P1",
			board = moved,
		})
		expect(updated.ok).toEqual(true)
		expect(updated.persist).toEqual(true)
		expect(#updated.state.guilds[1].presets).toEqual(8)
		expect(updated.state.guilds[1].presets[1].markers[1].kind).toEqual("soak2")
		expect(updated.state.guilds[1].presets[1].name).toEqual("P1")
		expect(store.guilds[1].presets[1].markers[1].kind).toEqual("stack")

		local other = RaidStrategy.save(store, {
			guildId = "grove",
			name = "P1",
			board = board,
		})
		expect(other.ok).toEqual(true)
		expect(#other.state.guilds).toEqual(2)
		expect(#other.state.guilds[1].presets).toEqual(8)

		local blankGuild = RaidStrategy.save(store, {
			guildId = "   ",
			name = "P1",
			board = board,
		})
		expect(blankGuild.error).toEqual(ERRORS.guild)
		expect(blankGuild.persist).toEqual(false)
		expect(blankGuild.state.guilds).toEqual(before.guilds)
		local blankName = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "",
			board = board,
		})
		expect(blankName.error).toEqual(ERRORS.name)
		local longName = RaidStrategy.save(store, {
			guildId = "Grove",
			name = string.rep("p", RaidStrategy.CONFIG.maxIdLength + 1),
			board = board,
		})
		expect(longName.error).toEqual(ERRORS.name)
		local badBoard = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "P1",
			board = { markers = { { id = "a", kind = "spread", x = 0, y = 0 } } },
		})
		expect(badBoard.error).toEqual(ERRORS.state)
		expect(badBoard.persist).toEqual(false)
		expect(store.guilds[1].presets[1].markers[1].kind).toEqual("stack")

		local paid = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "P9",
			board = moved,
			paidPreset = 25,
			robux = 25,
		})
		expect(paid.error).toEqual(ERRORS.skip)
		expect(paid.persist).toEqual(false)
		expect(paid.state.guilds).toEqual(before.guilds)
		local extra = RaidStrategy.save(store, {
			guildId = "Grove",
			name = "P1",
			board = moved,
		}, { buyPreset = true })
		expect(extra.error).toEqual(ERRORS.skip)
		expect(extra.persist).toEqual(false)
		expect(extra.state.guilds).toEqual({})
		expect(store).toEqual(before)

		local tooMany = {}
		for index = 1, RaidStrategy.CONFIG.maxPresets + 1 do
			table.insert(tooMany, { name = "P" .. tostring(index), markers = {} })
		end
		local overflow = RaidStrategy.load({
			guilds = {
				{ guildId = "Grove", presets = tooMany },
			},
		}, { guildId = "Grove", name = "P1" })
		expect(overflow.ok).toEqual(false)
		expect(overflow.persist).toEqual(false)
		expect(overflow.error).toEqual(ERRORS.presets)
		expect(overflow.state.guilds).toEqual({})
		expect(overflow.board.markers).toEqual({})
		expect(#tooMany).toEqual(9)

		local duplicate = RaidStrategy.load({
			guilds = {
				{ guildId = "Grove", presets = {} },
				{ guildId = "Grove", presets = {} },
			},
		}, { guildId = "Grove", name = "P1" })
		expect(duplicate.error).toEqual(ERRORS.presets)
		local duplicateName = RaidStrategy.save({
			guilds = {
				{
					guildId = "Grove",
					presets = {
						{ name = "P1", markers = {} },
						{ name = "P1", markers = {} },
					},
				},
			},
		}, { guildId = "Grove", name = "P2", board = board })
		expect(duplicateName.error).toEqual(ERRORS.presets)
		expect(duplicateName.persist).toEqual(false)
		expect(duplicateName.state.guilds).toEqual({})
	end)
end)
