--!strict

--[[
	LoopHud's quest lines and the card geometry. The module touches
	GetService at load, so the spec compiles it with a stub DataModel and
	the real Loops / UiTheme modules.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local function loadLoopHud()
	local loopsToken = { Name = "Loops" }
	local themeToken = { Name = "UiTheme" }
	local shared = {
		WaitForChild = function(_self, name)
			if name == "Loops" then
				return loopsToken
			end
			if name == "UiTheme" then
				return themeToken
			end
			error("missing " .. tostring(name), 2)
		end,
	}
	local replicated = {
		WaitForChild = function(_self, name)
			if name == "Shared" then
				return shared
			end
			error("missing " .. tostring(name), 2)
		end,
	}
	local environment = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		print = print,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = typeof,
		warn = warn,
		math = math,
		string = string,
		table = table,
		require = function(module)
			if module == loopsToken then
				return Loops
			end
			if module == themeToken then
				return UiTheme
			end
			error("unexpected require", 2)
		end,
		game = {
			GetService = function(_game, name)
				if name == "Players" then
					return { LocalPlayer = {} }
				end
				if name == "ReplicatedStorage" then
					return replicated
				end
				error("no service " .. tostring(name), 2)
			end,
		},
	}
	local source =
		fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoopHud.luau")
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = "LoopHud",
		environment = environment,
	})
	return chunk()
end

local LoopHud = loadLoopHud()

local function overlaps(a, b): boolean
	if a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0 then
		return false
	end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

local function widest(lines): number
	local best = 0
	for _, line in ipairs(lines) do
		if #line.text > best then
			best = #line.text
		end
	end
	return best
end

local function placeFor(profile, viewW: number, viewH: number)
	local today = LoopHud.todayLines(profile)
	local week = LoopHud.weekLines(profile)
	return LoopHud.layout(viewW, viewH, #today, #week, widest(today), widest(week)), today, week
end

local function liveProfile()
	return {
		passTier = 3,
		boardChance = 2,
		weeklyWeek = 12,
		nightmareBest = 0,
		dailyBossReady = true,
		dailies = {
			{
				id = "rooms",
				text = "Clear 2 Rootvault rooms",
				goal = 2,
				progress = 1,
				done = false,
			},
			{ id = "dodge", text = "Dodge 5 attacks", goal = 5, progress = 5, done = true },
			{ id = "hatch", text = "Hatch an egg", goal = 1, progress = 0, done = false },
		},
		weekly = {
			{
				id = "rooms",
				text = "Clear 2 Rootvault rooms",
				goal = 6,
				progress = 4,
				done = false,
			},
			{ id = "dodge", text = "Dodge 15 attacks", goal = 15, progress = 0, done = false },
			{ id = "hatch", text = "Hatch 3 eggs", goal = 3, progress = 3, done = true },
			{
				id = "forge",
				text = "Upgrade 3 pieces of gear",
				goal = 3,
				progress = 1,
				done = false,
			},
			{
				id = "pet",
				text = "Pet or feed a companion 3 times",
				goal = 3,
				progress = 0,
				done = false,
			},
		},
	}
end

describe("LoopHud weeklies", function()
	it("paints each weekly with the stored sentence and the daily counter", function()
		local profile = liveProfile()
		local week = LoopHud.weekLines(profile)
		expect(#week).toEqual(6)
		expect(week[1].text).toEqual("Weeklies")
		expect(week[1].header).toEqual(true)
		expect(week[2].text).toEqual("[ ] Clear 2 Rootvault rooms 4/6")
		expect(week[2].done).toEqual(false)
		expect(week[3].text).toEqual("[ ] Dodge 15 attacks 0/15")
		expect(week[4].text).toEqual("[x] Hatch 3 eggs 3/3")
		expect(week[4].done).toEqual(true)
		expect(week[5].text).toEqual("[ ] Upgrade 3 pieces of gear 1/3")
		expect(week[6].text).toEqual("[ ] Pet or feed a companion 3 times 0/3")
		expect(profile.weekly[1].text).toEqual("Clear 2 Rootvault rooms")
		expect(profile.weekly[1].goal).toEqual(6)
		expect(profile.weekly[1].progress).toEqual(4)
		expect(profile.weeklyWeek).toEqual(12)
		local today = LoopHud.todayLines(profile)
		expect(today[4].text).toEqual("[ ] Clear 2 Rootvault rooms 1/2")
		expect(today[5].text).toEqual("[x] Dodge 5 attacks 5/5")
		expect(today[5].done).toEqual(true)
		for _, line in ipairs(today) do
			expect(line.text == "Weeklies").toEqual(false)
			expect(string.find(line.text, "Dodge 15 attacks", 1, true)).toBeNil()
		end
	end)

	it("keeps an in-week sentence and falls back when the text is missing", function()
		local old = {
			weeklyWeek = 4,
			weekly = {
				{
					id = "rooms",
					text = "Clear 2 Rootvault rooms",
					goal = 6,
					progress = 2,
					done = false,
				},
			},
		}
		local lines = LoopHud.weekLines(old)
		expect(lines[2].text).toEqual("[ ] Clear 2 Rootvault rooms 2/6")
		expect(string.find(lines[2].text, "Clear 6 Rootvault rooms", 1, true)).toBeNil()
		expect(old.weekly[1].text).toEqual("Clear 2 Rootvault rooms")

		local missing = LoopHud.weekLines({
			weekly = {
				"stale",
				3,
				{ id = "forge", goal = 3, progress = 1, done = false },
				{ text = "   ", goal = "lots", progress = "no" },
				{ id = 8, goal = 0, progress = -2, done = false },
				{ goal = 0 / 0, progress = math.huge },
			},
		})
		expect(missing[1].text).toEqual("Weeklies")
		expect(missing[2].text).toEqual("[ ] forge 1/3")
		expect(missing[3].text).toEqual("[ ] Quest 0/1")
		expect(missing[4].text).toEqual("[ ] 8 0/1")
		expect(missing[5].text).toEqual("[ ] Quest 0/1")
		expect(LoopHud.questLine(nil)).toEqual("")
		expect(LoopHud.weekLines(nil)).toEqual({})
		expect(LoopHud.weekLines({ weekly = "old" })).toEqual({})
	end)

	it("fits five weeklies on a phone, a tall window, and a portrait", function()
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local profile = liveProfile()
		local views = {
			{ 844, 390, "side" },
			{ 800, 380, "side" },
			{ 1280, 720, "elbow" },
			{ 1920, 1080, "elbow" },
			{ 390, 844, "below" },
		}
		for _, view in ipairs(views) do
			local place, today, week = placeFor(profile, view[1], view[2])
			expect(#week).toEqual(6)
			expect(place.mode).toEqual(view[3])
			expect(place.weekScroll).toEqual(false)
			expect(place.todayScroll).toEqual(false)
			expect(place.rowH >= 18).toBeTrue()
			expect(place.week.h >= #week * place.rowH).toBeTrue()
			expect(place.today.h >= #today * place.rowH).toBeTrue()
			local longest = week[6].text
			expect(place.week.w >= #longest * 8 + 12).toBeTrue()
			expect(overlaps(place.board, place.today)).toEqual(false)
			expect(overlaps(place.board, place.week)).toEqual(false)
			expect(overlaps(place.today, place.week)).toEqual(false)
			expect(place.board).toEqual({ x = 8, y = 8, w = 124, h = 124 })
			expect(place.week.y + place.week.h <= place.panelH - 72).toBeTrue()
			expect(place.today.y + place.today.h <= place.panelH - 72).toBeTrue()
			expect(place.board.y + place.board.h <= place.panelH - 72).toBeTrue()
			expect(place.panelBottom <= place.limitBottom).toBeTrue()
			expect(place.panelW <= view[1] - 16).toBeTrue()
			expect(place.panelW >= 280).toBeTrue()
		end
		local grown = LoopHud.layout(1280, 720, 7, 6, 30, 40)
		expect(grown.panelH > 220).toBeTrue()
		expect(grown.mode).toEqual("elbow")
	end)

	it("lets today scroll on a short phone when a nightmare line is added", function()
		local profile = liveProfile()
		profile.nightmareBest = 90
		local place, _today, week = placeFor(profile, 844, 390)
		expect(place.mode).toEqual("side")
		expect(place.weekScroll).toEqual(false)
		expect(place.todayScroll).toEqual(true)
		expect(place.week.h >= #week * place.rowH).toBeTrue()
		expect(overlaps(place.board, place.week)).toEqual(false)
		expect(place.panelBottom <= place.limitBottom).toBeTrue()
	end)

	it("does not roll weeklies or bring the premium track back", function()
		local source =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoopHud.luau")
		expect(string.find(source, "rollWeekly", 1, true)).toBeNil()
		expect(string.find(source, "Loops.WEEKLY", 1, true)).toBeNil()
		expect(string.find(source, "Weeklies %d", 1, true)).toBeNil()
		expect(string.find(source, "PREMIUM_ENABLED = true", 1, true)).toBeNil()
		expect(string.find(source, "panel.Visible = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "BackgroundTransparency = 0", 1, true) ~= nil).toBeTrue()
	end)
end)
