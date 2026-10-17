--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Build = require("../src/ReplicatedStorage/Shared/Build")
local ClientChrome = require("../src/ReplicatedStorage/Shared/ClientChrome")
local LegacyChrome = require("../src/ReplicatedStorage/Shared/LegacyChrome")
local LoadingTips = require("../src/ReplicatedStorage/Shared/LoadingTips")

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function tipsFromContent(): { { id: string, topic: string, chars: number, text: string } }
	local rows = {}
	for line in string.gmatch(fs.readFile("docs/content/loading_tips.md"), "[^\n]+") do
		if string.sub(line, 1, 7) == "| `tip_" then
			local body = string.sub(line, 2, -2)
			local parts = {}
			for part in string.gmatch(body, "[^|]+") do
				table.insert(parts, trim(part))
			end
			local id = string.match(parts[1], "^`(tip_%d%d)`$")
			local chars = tonumber(parts[3])
			if id ~= nil and chars ~= nil and #parts == 4 then
				table.insert(rows, {
					id = id,
					topic = parts[2],
					chars = chars,
					text = parts[4],
				})
			end
		end
	end
	return rows
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

local function requiresTips(source: string): boolean
	if string.find(source, 'WaitForChild("LoadingTips")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('LoadingTips')", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/LoadingTips", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared.LoadingTips", 1, true) ~= nil then
		return true
	end
	return false
end

describe("LoadingTips list", function()
	it("locks sixty ids in file order", function()
		local rows = tipsFromContent()
		expect(#rows).toEqual(60)
		expect(#LoadingTips.TIPS).toEqual(60)
		expect(LoadingTips.COUNT).toEqual(60)
		local topics = { "controls", "rolls", "pity", "raids", "pets", "crafting" }
		for index, row in ipairs(rows) do
			local id = string.format("tip_%02d", index)
			expect(row.id).toEqual(id)
			expect(row.topic).toEqual(topics[math.ceil(index / 10)])
			expect(#row.text).toEqual(row.chars)
			expect(row.chars).toBeLessThan(90)
			expect(LoadingTips.TIPS[index].id).toEqual(id)
			expect(LoadingTips.TIPS[index].topic).toEqual(row.topic)
			expect(LoadingTips.TIPS[index].text).toEqual(row.text)
			expect(LoadingTips.line(index - 1)).toEqual(LoadingTips.TIPS[index])
		end
		expect(LoadingTips.TIPS[1].text).toEqual(
			"Attack is E. Dodge is Q. Heavy is R. Sprint is Shift."
		)
		expect(LoadingTips.TIPS[36].text).toEqual(
			"Wings: Thornwarden Twins, Mother Sapwell, Galecrown, Grandmother Gnarl Awakened."
		)
		expect(LoadingTips.TIPS[60].text).toEqual(
			"Duplicates can pay Dust. A higher rarity pays more Dust."
		)
	end)

	it("wraps a whole-number step at 60 and starts at tip_01", function()
		expect(LoadingTips.line(0)).toEqual(LoadingTips.TIPS[1])
		expect(LoadingTips.line(0) == LoadingTips.TIPS[1]).toBeTrue()
		expect(LoadingTips.line(1).id).toEqual("tip_02")
		expect(LoadingTips.line(59).id).toEqual("tip_60")
		expect(LoadingTips.line(60)).toEqual(LoadingTips.TIPS[1])
		expect(LoadingTips.line(60) == LoadingTips.line(0)).toBeTrue()
		expect(LoadingTips.line(61).id).toEqual("tip_02")
		expect(LoadingTips.line(119).id).toEqual("tip_60")
		expect(LoadingTips.line(120)).toEqual(LoadingTips.line(0))
		expect(LoadingTips.line(60.0).id).toEqual("tip_01")
	end)

	it("returns nothing for a bad step and does not throw", function()
		local function ask(step: any): any
			return LoadingTips.line(step)
		end
		expect(ask(nil)).toBeNil()
		expect(ask(-1)).toBeNil()
		expect(ask(-60)).toBeNil()
		expect(ask(-0.5)).toBeNil()
		expect(ask(0.5)).toBeNil()
		expect(ask(1.5)).toBeNil()
		expect(ask(math.huge)).toBeNil()
		expect(ask(-math.huge)).toBeNil()
		expect(ask(0 / 0)).toBeNil()
		expect(ask("0")).toBeNil()
		expect(ask("tip_01")).toBeNil()
		expect(ask(true)).toBeNil()
		expect(ask(false)).toBeNil()
		expect(ask({})).toBeNil()
		expect(ask({ step = 0, paid = true })).toBeNil()
	end)
end)

describe("LoadingTips paid hop", function()
	it("keeps the same line when a paid flag is set", function()
		expect(LoadingTips.line(0, nil)).toEqual(LoadingTips.line(0))
		local hops = {
			true,
			false,
			{ paid = true },
			{ paid = false },
			{ productId = 13579 },
			{ robux = 25 },
			{ cost = 10 },
			{ skip = true },
			{ paid = true, productId = 1, robux = 25, cost = 10, skip = true },
			{ paid = true, productId = "shard_hop", robux = 0, cost = 0, skip = false },
		}
		for _, hop in ipairs(hops) do
			expect(LoadingTips.line(0, hop)).toEqual(LoadingTips.line(0))
			expect(LoadingTips.line(0, hop) == LoadingTips.line(0)).toBeTrue()
			expect(LoadingTips.line(59, hop).id).toEqual("tip_60")
			expect(LoadingTips.line(60, hop)).toEqual(LoadingTips.line(0))
		end
		local paid = { paid = true, productId = 9, robux = 80, cost = 80, skip = true }
		local free = LoadingTips.line(4)
		expect(LoadingTips.line(4, paid).text).toEqual(free.text)
		expect(LoadingTips.line(4, paid).id).toEqual("tip_05")
	end)
end)

describe("LoadingTips isolation", function()
	it("freezes the list and does not roll, wait, or read the clock", function()
		expect(function()
			LoadingTips.TIPS[1] = LoadingTips.TIPS[2]
		end).toThrow()
		expect(function()
			LoadingTips.TIPS[1].text = "nope"
		end).toThrow()
		local source = fs.readFile("src/ReplicatedStorage/Shared/LoadingTips.luau")
		local banned = {
			"require(",
			"math.random",
			"os.time",
			"os.clock",
			"os.date",
			"Random.new",
			"GetService",
			"DateTime",
			"tick(",
			"task.",
			"Marketplace",
			"DataStore",
			"loading_tips",
			"readFile",
		}
		for _, word in ipairs(banned) do
			expect(string.find(source, word, 1, true)).toBeNil()
		end
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresTips(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		table.sort(callers)
		expect(callers).toEqual({
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoadingHud.luau",
		})
	end)

	it("paints the next tip for a join and a teleport without a pass branch", function()
		local hud =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/LoadingHud.luau")
		expect(string.find(hud, "LoadingTips.line", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "LocalPlayerArrivedFromTeleport", 1, true)).toBeGreaterThan(0)
		expect(string.find(hud, "OnTeleport", 1, true)).toBeGreaterThan(0)
		local banned = {
			"MarketplaceService",
			"GamePass",
			"UserOwnsGamePass",
			"productId",
			"PromptPurchase",
			"ProcessReceipt",
		}
		for _, word in ipairs(banned) do
			expect(string.find(hud, word, 1, true)).toBeNil()
		end
		local client =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau")
		local stampLine = 'print("[Shardfall] build ' .. Build.STAMP .. ' client")'
		expect(string.find(client, stampLine, 1, true)).toBeGreaterThan(0)
		local _, mounts = string.gsub(client, "LoadingHud.start", "")
		expect(mounts).toEqual(1)
		local clearAt = string.find(client, "clearStaleGuis(playerGui)", 1, true)
		local startAt = string.find(client, "LoadingHud.start(playerGui)", 1, true)
		expect(clearAt ~= nil and startAt ~= nil).toBeTrue()
		expect((clearAt :: number) < (startAt :: number)).toBeTrue()
		expect(ClientChrome.shouldClear("ShardfallLoading")).toEqual(true)
		expect(LegacyChrome.shouldDestroy("ShardfallLoading")).toEqual(false)
	end)
end)
