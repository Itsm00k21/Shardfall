--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BannerFit = require("../src/ReplicatedStorage/Shared/BannerFit")
local Build = require("../src/ReplicatedStorage/Shared/Build")
local HudLayout = require("../src/ReplicatedStorage/Shared/HudLayout")
local StarterGoals = require("../src/ReplicatedStorage/Shared/StarterGoals")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")

local function loadHud()
	local layoutToken = { Name = "HudLayout" }
	local bannerToken = { Name = "BannerFit" }
	local themeToken = { Name = "UiTheme" }
	local shared = {
		WaitForChild = function(_self, name)
			if name == "HudLayout" then
				return layoutToken
			end
			if name == "BannerFit" then
				return bannerToken
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
	local source =
		fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau")
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = "StarterGoalHud",
		environment = {
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
				if module == layoutToken then
					return HudLayout
				end
				if module == bannerToken then
					return BannerFit
				end
				if module == themeToken then
					return UiTheme
				end
				error("unexpected require", 2)
			end,
			game = {
				GetService = function(_game, name)
					if name == "ReplicatedStorage" then
						return replicated
					end
					error("no service " .. tostring(name), 2)
				end,
			},
		},
	})
	return chunk()
end

local StarterGoalHud = loadHud()

local function counts(overrides: { [string]: any }?)
	local row: { [string]: any } = {
		forge = 0,
		rootvault = 0,
		rolls = 0,
		level = 1,
		guild = false,
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			row[key] = value
		end
	end
	return row
end

local function freshShown(overrides: { [string]: any }?)
	return StarterGoals.show(StarterGoals.fresh().state, counts(overrides))
end

local function seal(row: { [string]: any })
	return setmetatable(row, {
		__index = function(_, key)
			error("read " .. tostring(key), 2)
		end,
	})
end

describe("StarterGoalHud rows", function()
	it("paints the three fresh sentences in the order given", function()
		local shown = freshShown({ rolls = 3 })
		expect(shown.ok).toEqual(true)
		local rows = StarterGoalHud.rows(shown)
		expect(#rows).toEqual(3)
		expect(rows[1].text).toEqual("Craft your first item at the Forge")
		expect(rows[1].text).toEqual(StarterGoals.GOALS[1].text)
		expect(rows[1].progress).toEqual(0)
		expect(rows[1].goal).toEqual(1)
		expect(rows[1].line).toEqual("Craft your first item at the Forge 0/1")
		expect(rows[2].text).toEqual("Clear Rootvault")
		expect(rows[2].line).toEqual("Clear Rootvault 0/1")
		expect(rows[3].text).toEqual("Roll 10 shards")
		expect(rows[3].progress).toEqual(3)
		expect(rows[3].goal).toEqual(10)
		expect(rows[3].line).toEqual("Roll 10 shards 3/10")
		expect(shown.goals[1].text).toEqual(rows[1].text)
		expect(shown.goals[3].progress).toEqual(3)

		local mixed = StarterGoalHud.rows({
			ok = true,
			goals = {
				{ text = "Reach Lv 5", progress = 2, goal = 5 },
				{ text = "Join or browse a guild", progress = 0, goal = 1 },
				{ text = "Craft your first item at the Forge", progress = 0, goal = 1 },
			},
		})
		expect(#mixed).toEqual(3)
		expect(mixed[1].text).toEqual("Reach Lv 5")
		expect(mixed[1].line).toEqual("Reach Lv 5 2/5")
		expect(mixed[2].text).toEqual("Join or browse a guild")
		expect(mixed[3].text).toEqual("Craft your first item at the Forge")

		local four = StarterGoalHud.rows({
			ok = true,
			goals = {
				{ text = "Craft your first item at the Forge", progress = 0, goal = 1 },
				{ text = "Clear Rootvault", progress = 0, goal = 1 },
				{ text = "Roll 10 shards", progress = 1, goal = 10 },
				{ text = "Reach Lv 5", progress = 4, goal = 5 },
			},
		})
		expect(#four).toEqual(3)
		expect(four[3].text).toEqual("Roll 10 shards")
		expect(four[3].line).toEqual("Roll 10 shards 1/10")
	end)

	it("caps painted progress at the goal", function()
		local shown = freshShown({ forge = 5, rootvault = 2, rolls = 100, level = 9 })
		local painted = StarterGoalHud.rows(shown)
		expect(painted[1].line).toEqual("Craft your first item at the Forge 1/1")
		expect(painted[2].line).toEqual("Clear Rootvault 1/1")
		expect(painted[3].progress).toEqual(10)
		expect(painted[3].goal).toEqual(10)
		expect(painted[3].line).toEqual("Roll 10 shards 10/10")

		local raw = {
			text = "Roll 10 shards",
			progress = 100,
			goal = 10,
		}
		local rows = StarterGoalHud.rows({
			ok = true,
			goals = { raw },
		})
		expect(#rows).toEqual(1)
		expect(rows[1].progress).toEqual(10)
		expect(rows[1].goal).toEqual(10)
		expect(rows[1].line).toEqual("Roll 10 shards 10/10")
		expect(raw.progress).toEqual(100)
		expect(raw.goal).toEqual(10)
	end)

	it("hides an empty list and a result that is not ok", function()
		expect(StarterGoalHud.rows({ ok = true, goals = {} })).toEqual({})
		expect(StarterGoalHud.rows({
			ok = false,
			goals = {
				{ text = "Craft your first item at the Forge", progress = 0, goal = 1 },
				{ text = "Clear Rootvault", progress = 0, goal = 1 },
				{ text = "Roll 10 shards", progress = 0, goal = 10 },
			},
			error = "nope",
		})).toEqual({})
		expect(StarterGoalHud.rows({ ok = true })).toEqual({})
		expect(StarterGoalHud.rows(nil)).toEqual({})
		expect(StarterGoalHud.rows("goals")).toEqual({})
		local returning =
			StarterGoals.show(StarterGoals.fresh({ returning = true }).state, counts())
		expect(returning.ok).toEqual(true)
		expect(returning.goals).toEqual({})
		expect(StarterGoalHud.rows(returning)).toEqual({})
		local partial = StarterGoalHud.rows({
			ok = true,
			goals = {
				{ text = "Craft your first item at the Forge", goal = 1 },
				{ text = "Clear Rootvault", progress = 0, goal = 1 },
				{ text = "Roll 10 shards", progress = -1, goal = 10 },
				{ text = "Reach Lv 5", progress = 4, goal = 5 },
			},
		})
		expect(#partial).toEqual(1)
		expect(partial[1].text).toEqual("Clear Rootvault")
		expect(partial[1].line).toEqual("Clear Rootvault 0/1")
		StarterGoalHud.present({ ok = true, goals = {} })
		StarterGoalHud.present(freshShown())
	end)
end)

describe("StarterGoalHud paid flag", function()
	it("does not read a paid flag and does not change the row", function()
		local clean = StarterGoalHud.rows({
			ok = true,
			goals = {
				{ text = "Craft your first item at the Forge", progress = 0, goal = 1 },
				{ text = "Clear Rootvault", progress = 1, goal = 1 },
				{ text = "Roll 10 shards", progress = 4, goal = 10 },
			},
		})
		local flagged = {
			ok = true,
			goals = {
				{
					text = "Craft your first item at the Forge",
					progress = 0,
					goal = 1,
					paid = true,
					productId = "forge_skip",
					robux = 25,
					cost = 10,
					skip = true,
				},
				{ text = "Clear Rootvault", progress = 1, goal = 1, paid = false },
				{ text = "Roll 10 shards", progress = 4, goal = 10 },
			},
			paid = true,
			productId = 13579,
			robux = 80,
			cost = 0,
			skip = false,
		}
		expect(StarterGoalHud.rows(flagged)).toEqual(clean)
		expect(flagged.goals[1].progress).toEqual(0)
		expect(flagged.paid).toEqual(true)

		local trapped = seal({
			ok = true,
			goals = seal({
				seal({
					text = "Craft your first item at the Forge",
					progress = 0,
					goal = 1,
				}),
				seal({ text = "Clear Rootvault", progress = 0, goal = 1 }),
				seal({ text = "Roll 10 shards", progress = 100, goal = 10 }),
			}),
		})
		local rows = StarterGoalHud.rows(trapped)
		expect(#rows).toEqual(3)
		expect(rows[1].line).toEqual("Craft your first item at the Forge 0/1")
		expect(rows[2].line).toEqual("Clear Rootvault 0/1")
		expect(rows[3].progress).toEqual(10)
		expect(rows[3].line).toEqual("Roll 10 shards 10/10")
		StarterGoalHud.present(trapped)
		expect(StarterGoalHud.rows(trapped)[3].progress).toEqual(10)
	end)
end)

describe("StarterGoalHud mount", function()
	it("mounts once, starts hidden, and leaves the build print", function()
		local hud = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau"
		)
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local stampLine = 'print("[Shardfall] build ' .. Build.STAMP .. ' client")'
		expect(string.find(client, stampLine, 1, true)).toBeGreaterThan(0)
		local _, mounts = string.gsub(client, "StarterGoalHud.start", "")
		expect(mounts).toEqual(1)
		local shellAt = string.find(client, "HudShell.start(playerGui", 1, true)
		local startAt = string.find(client, "StarterGoalHud.start(playerGui)", 1, true)
		expect(shellAt ~= nil and startAt ~= nil).toBeTrue()
		expect((shellAt :: number) < (startAt :: number)).toBeTrue()
		expect(string.find(hud, "frame.Visible = false", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "function StarterGoalHud.present", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "StarterGoalHud.rows(result)", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "frame.Visible = show", 1, true)).toBeGreaterThan(0)
		local banned = {
			"paid",
			"productId",
			"robux",
			"Robux",
			"cost",
			"skip",
			"grant",
			"userId",
			"UserId",
			"guildId",
			"GuildId",
			"playerId",
			"PlayerId",
			"Shared.StarterGoals",
			"Shared/StarterGoals",
			"Parent.StarterGoals",
			'WaitForChild("StarterGoals")',
			"WaitForChild('StarterGoals')",
			"Marketplace",
			"RemoteEvent",
			"RemoteFunction",
			"InvokeServer",
			"FireServer",
		}
		local _, requires = string.gsub(hud, "require(", "")
		expect(requires).toEqual(3)
		expect(string.find(hud, 'WaitForChild("HudLayout")', 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, 'WaitForChild("BannerFit")', 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, 'WaitForChild("UiTheme")', 1, true)).toBeGreaterThan(0)
		for _, word in ipairs(banned) do
			expect(string.find(hud, word, 1, true)).toBeNil()
		end
		local presentAt = string.find(client, "StarterGoalHud.present(tracker)", 1, true)
		expect(presentAt).toBeGreaterThan(0)
		expect(string.find(client, "profile.starterGoalTracker", 1, true)).toBeGreaterThan(0)
		expect(string.find(client, "StarterGoalHud.present(tracker.goals)", 1, true)).toBeNil()
		expect(
			string.find(client, "StarterGoalHud.present(profile.starterGoalTracker.goals)", 1, true)
		).toBeNil()
		expect(string.find(client, "row.progress", 1, true)).toBeGreaterThan(0)
		expect(string.find(client, "row.goal", 1, true)).toBeGreaterThan(0)
		expect(string.find(client, "state.granted", 1, true)).toBeGreaterThan(0)
		expect(string.find(client, "if hudShell == nil then", 1, true)).toBeGreaterThan(0)
		local paintAt = string.find(client, "presentStarterGoals(latestProfile)", 1, true)
		expect(paintAt).toBeGreaterThan(startAt :: number)
		expect(string.find(client, "presentStarterGoals(profile)", 1, true)).toBeGreaterThan(0)
		expect(string.find(client, "StarterGoals.grant", 1, true)).toBeNil()
		expect(string.find(client, "StarterGoalHud.grant", 1, true)).toBeNil()
	end)
end)

describe("StarterGoalHud chrome", function()
	local function scaled(scale: number): number
		return math.max(UiTheme.MIN_TEXT, math.floor(UiTheme.MIN_TEXT * scale + 0.5))
	end

	local function withPlace(hook: any, body: () -> ())
		local previous = (HudLayout :: any).place;
		(HudLayout :: any).place = hook
		local ok, err = pcall(body);
		(HudLayout :: any).place = previous
		if not ok then
			error(tostring(err), 2)
		end
	end

	it("hides when settings.hud.hidden and applies access text scale", function()
		local hidden = StarterGoalHud.chrome({
			hud = { hidden = true, scale = 1 },
			access = { textScale = 1.4 },
		})
		expect(hidden.hidden).toEqual(true)
		expect(hidden.textScale).toEqual(1.4)
		expect(hidden.textSize).toEqual(scaled(1.4))
		expect(hidden.textSize).toEqual(20)
		expect(StarterGoalHud.shown(3, { hud = { hidden = true } })).toEqual(false)

		local shown = StarterGoalHud.chrome({
			hud = { hidden = false },
			access = { textScale = 1 },
		})
		expect(shown.hidden).toEqual(false)
		expect(shown.textSize).toEqual(UiTheme.MIN_TEXT)
		expect(StarterGoalHud.shown(3, { hud = { hidden = false } })).toEqual(true)
		expect(StarterGoalHud.shown(0, { hud = { hidden = false } })).toEqual(false)
		expect(StarterGoalHud.chrome({ hud = { hidden = 1 } }).hidden).toEqual(false)
		expect(StarterGoalHud.chrome({ access = { textScale = 0 / 0 } }).textScale).toEqual(1)

		local fromProfile = StarterGoalHud.chrome({
			uiSettings = {
				hud = { hidden = true },
				access = { textScale = 1.2 },
			},
		})
		expect(fromProfile.hidden).toEqual(true)
		expect(fromProfile.textScale).toEqual(1.2)
		expect(fromProfile.textSize).toEqual(scaled(1.2))
		StarterGoalHud.applyChrome({
			hud = { hidden = true },
			access = { textScale = 1.4 },
		})
		StarterGoalHud.present(freshShown())
		expect(StarterGoalHud.shown(3, {
			hud = { hidden = true },
			access = { textScale = 1.4 },
		})).toEqual(false)

		local hud = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau"
		)
		expect(string.find(hud, 'FindFirstChild("Chrome")', 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "frame.Parent = holder", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, 'not chrome:IsA("CanvasGroup")', 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, 'label:SetAttribute("BaseText", BASE_TEXT)', 1, true)).toBeGreaterThan(
			0
		)
		expect(string.find(hud, "hud.hidden == true", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "access.textScale", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "UDim2.fromOffset(88, 80)", 1, true)).toBeNil()
		expect(string.find(hud, "SkipTextScale", 1, true)).toBeNil()
	end)

	it("places through HudLayout.place and stays off the toast on a phone", function()
		local hud = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau"
		)
		local layoutAt = string.find(hud, "HudLayout", 1, true)
		expect(layoutAt).toBeGreaterThan(0)
		expect(string.find(hud, ".place", layoutAt :: number, true)).toBeGreaterThan(0)
		expect(string.find(hud, "HudLayout.place(viewportX, viewportY, rowCount)", 1, true)).toBeGreaterThan(
			0
		)

		local seen = false
		withPlace(function(viewportX, viewportY, rowCount)
			seen = true
			expect(viewportX).toEqual(844)
			expect(viewportY).toEqual(390)
			expect(rowCount).toEqual(3)
			return { x = 40, y = 210, w = 180, h = 48 }
		end, function()
			local placed = StarterGoalHud.place(844, 390, 3)
			expect(seen).toEqual(true)
			expect(placed.x).toEqual(40)
			expect(placed.y).toEqual(210)
			expect(placed.w).toEqual(180)
			expect(placed.h).toEqual(48)
		end)

		withPlace(function()
			return "nope"
		end, function()
			local desktop = StarterGoalHud.place(1920, 1080, 3)
			expect(desktop.x).toEqual(88)
			expect(desktop.y).toEqual(80)
			expect(desktop.w).toEqual(320)
			expect(desktop.h).toEqual(3 * 18 + 8)
		end)

		local wide = StarterGoalHud.place(1920, 1080, 3)
		expect(wide.x).toEqual(88)
		expect(wide.y).toEqual(80)
		local rail = HudLayout.railFit(1080, UiTheme.safeMargin(), 7, UiTheme.TAP, UiTheme.TOUCH)
		expect(wide.x >= rail.x + rail.w).toBeTrue()
		expect(wide.w).toEqual(320)
		local mid = StarterGoalHud.place(1280, 800, 3)
		expect(mid.x).toEqual(88)
		expect(mid.y).toEqual(80)

		local views = {
			{ 844, 390 },
			{ 390, 844 },
			{ 800, 380 },
		}
		for _, view in ipairs(views) do
			local vx = view[1]
			local vy = view[2]
			expect(HudLayout.breakpoint(vx, vy)).toEqual("phone")
			local placed = StarterGoalHud.place(vx, vy, 3)
			local margin = UiTheme.safeMargin()
			local toast = HudLayout.toast(vx, margin)
			local stack = {
				x = toast.x,
				y = toast.y,
				w = toast.w,
				h = toast.h * 3 + 8 * 2,
			}
			expect(HudLayout.overlaps(placed, toast)).toEqual(false)
			expect(HudLayout.overlaps(placed, stack)).toEqual(false)
			expect(placed.y >= toast.y + toast.h).toBeTrue()
			expect(placed.x >= margin).toBeTrue()
			expect(placed.y >= margin).toBeTrue()
			expect(placed.x + placed.w <= vx - margin + 0.01).toBeTrue()
			expect(placed.y + placed.h <= vy - margin + 0.01).toBeTrue()
			local rail =
				HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH)
			expect(HudLayout.overlaps(placed, {
				x = rail.x,
				y = rail.y,
				w = rail.w,
				h = rail.h,
			})).toEqual(false)
			local anchor = {
				x = 88,
				y = 80,
				w = 320,
				h = placed.h,
			}
			if vx < anchor.x + anchor.w + margin then
				anchor.w = vx - margin - anchor.x
			end
			expect(HudLayout.overlaps(anchor, toast)).toEqual(true)
		end
	end)
end)

describe("StarterGoalHud polish", function()
	local function promptOf(viewportX: number)
		return HudLayout.equipPrompt(viewportX, UiTheme.safeMargin())
	end

	local function withPlace(hook: any, body: () -> ())
		local previous = (HudLayout :: any).place;
		(HudLayout :: any).place = hook
		local ok, err = pcall(body);
		(HudLayout :: any).place = previous
		if not ok then
			error(tostring(err), 2)
		end
	end

	it("sizes each line to the scaled text", function()
		expect(StarterGoalHud.lineHeight(14)).toEqual(18)
		local grown = StarterGoalHud.lineHeight(20)
		expect(grown >= 20).toBeTrue()
		expect(grown).toBeGreaterThan(18)
		local scaled = StarterGoalHud.chrome({
			access = { textScale = 1.4 },
		})
		expect(scaled.textSize).toEqual(20)
		expect(scaled.lineHeight).toEqual(grown)
		expect(scaled.lineHeight).toBeGreaterThan(18)
		local rested = StarterGoalHud.place(1920, 1080, 3)
		expect(rested.x).toEqual(88)
		expect(rested.y).toEqual(80)
		expect(rested.h).toEqual(3 * 18 + 8)
		expect(rested.collapsed == true).toBeFalse()
		local placed = StarterGoalHud.place(1920, 1080, 3, scaled.textSize)
		expect(placed.x).toEqual(88)
		expect(placed.y).toEqual(80)
		expect(placed.w).toEqual(320)
		expect(placed.h).toEqual(3 * grown + 8)
		expect(placed.h).toBeGreaterThan(rested.h)
		expect(placed.collapsed == true).toBeFalse()

		local hud = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau"
		)
		expect(string.find(hud, "UDim2.new(1, -16, 0, lineH)", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "\\u{25C6}", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "function StarterGoalHud.present(result: any)", 1, true)).toBeGreaterThan(
			0
		)
		local _, presents = string.gsub(hud, "function StarterGoalHud.present", "")
		expect(presents).toEqual(1)
	end)

	it("collapses a viewport shorter than the tested phones", function()
		local phones = {
			{ 844, 390 },
			{ 390, 844 },
			{ 800, 380 },
		}
		for _, view in ipairs(phones) do
			local placed = StarterGoalHud.place(view[1], view[2], 3)
			expect(placed.collapsed == true).toBeFalse()
			expect(placed.h).toBeGreaterThan(0)
			expect(placed.w).toBeGreaterThan(0)
		end

		local short = {
			{ 844, 240 },
			{ 800, 200 },
			{ 390, 240 },
		}
		for _, view in ipairs(short) do
			local vx = view[1]
			local vy = view[2]
			expect(vy < 380).toBeTrue()
			local placed = StarterGoalHud.place(vx, vy, 3)
			expect(placed.collapsed).toEqual(true)
			expect(placed.w).toEqual(0)
			expect(placed.h).toEqual(0)
			local margin = UiTheme.safeMargin()
			local toast = HudLayout.toast(vx, margin)
			local stack = {
				x = toast.x,
				y = toast.y,
				w = toast.w,
				h = toast.h * 3 + 8 * 2,
			}
			expect(HudLayout.overlaps(placed, stack)).toEqual(false)
			expect(placed.y + placed.h <= vy).toBeTrue()
		end

		withPlace(function()
			return { x = 12, y = 14, w = 40, h = 20 }
		end, function()
			local hooked = StarterGoalHud.place(844, 240, 3)
			expect(hooked.x).toEqual(12)
			expect(hooked.y).toEqual(14)
			expect(hooked.w).toEqual(40)
			expect(hooked.h).toEqual(20)
			expect(hooked.collapsed == true).toBeFalse()
		end)
	end)

	it("hides through applyChrome when Chrome is missing", function()
		local shell =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau")
		local hud = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau"
		)
		local setAt = string.find(shell, "setProfile = function(profile: any)", 1, true)
		local callAt = string.find(shell, "StarterGoalHud.applyChrome(profile.uiSettings)", 1, true)
		expect(setAt ~= nil).toBeTrue()
		expect(callAt ~= nil).toBeTrue()
		expect((setAt :: number) < (callAt :: number)).toBeTrue()
		local _, calls =
			string.gsub(shell, "StarterGoalHud%.applyChrome%(profile%.uiSettings%)", "")
		expect(calls).toEqual(1)
		expect(string.find(shell, "require(script.Parent.StarterGoalHud)", 1, true)).toBeGreaterThan(
			0
		)
		expect(string.find(hud, "frame.Visible = show", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, 'FindFirstChild("Chrome")', 1, true)).toBeGreaterThan(0)

		local hidden = { hud = { hidden = true }, access = { textScale = 1.4 } }
		expect(StarterGoalHud.chrome(hidden).hidden).toEqual(true)
		expect(StarterGoalHud.shown(3, hidden)).toEqual(false)
		expect(StarterGoalHud.chrome(hidden).lineHeight).toEqual(StarterGoalHud.lineHeight(20))
		StarterGoalHud.applyChrome(hidden)
		expect(StarterGoalHud.shown(3, hidden)).toEqual(false)
		local shown = { hud = { hidden = false }, access = { textScale = 1 } }
		expect(StarterGoalHud.shown(3, shown)).toEqual(true)
		StarterGoalHud.applyChrome(shown)
		expect(StarterGoalHud.chrome(shown).textSize).toEqual(UiTheme.MIN_TEXT)
	end)

	it("keeps a phone tracker off the equip prompt top edge", function()
		local views = {
			{ 844, 390 },
			{ 390, 844 },
			{ 800, 380 },
		}
		for _, view in ipairs(views) do
			local vx = view[1]
			local vy = view[2]
			expect(HudLayout.breakpoint(vx, vy)).toEqual("phone")
			local placed = StarterGoalHud.place(vx, vy, 3)
			local prompt = promptOf(vx)
			local top = { x = prompt.x, y = prompt.y, w = prompt.w, h = 1 }
			expect(placed.collapsed == true).toBeFalse()
			expect(HudLayout.overlaps(placed, prompt)).toEqual(false)
			expect(HudLayout.overlaps(placed, top)).toEqual(false)
			local margin = UiTheme.safeMargin()
			expect(placed.x >= margin).toBeTrue()
			expect(placed.y >= margin).toBeTrue()
			expect(placed.x + placed.w <= vx - margin + 0.01).toBeTrue()
			expect(placed.y + placed.h <= vy - margin + 0.01).toBeTrue()
			local grown = StarterGoalHud.place(vx, vy, 3, 20)
			expect(grown.collapsed == true).toBeFalse()
			expect(grown.h).toEqual(3 * StarterGoalHud.lineHeight(20) + 8)
			expect(HudLayout.overlaps(grown, prompt)).toEqual(false)
			expect(HudLayout.overlaps(grown, top)).toEqual(false)
		end

		local desktop = StarterGoalHud.place(1920, 1080, 3)
		expect(desktop.x).toEqual(88)
		expect(desktop.y).toEqual(80)
		expect(HudLayout.overlaps(desktop, promptOf(1920))).toEqual(false)
		local mid = StarterGoalHud.place(1280, 800, 3)
		expect(mid.x).toEqual(88)
		expect(mid.y).toEqual(80)
	end)
end)
