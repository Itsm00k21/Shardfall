--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Build = require("../src/ReplicatedStorage/Shared/Build")
local StarterGoals = require("../src/ReplicatedStorage/Shared/StarterGoals")

local function loadHud()
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
			"require(",
		}
		for _, word in ipairs(banned) do
			expect(string.find(hud, word, 1, true)).toBeNil()
		end
		expect(string.find(client, "StarterGoalHud.present", 1, true)).toBeNil()
	end)
end)
