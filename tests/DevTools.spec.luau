--!strict

--[[
	Owner-only Dev Tools panel (Kevin, Oct 22): "have no way of knowing if
	something was added" and "maybe it should have its own expandable
	menu". Every press must come back with one line that says what
	changed, a parked system must say it is off, and Settings must not
	carry the dev rows any more.
]]

local fs = require("@lune/fs")
local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local DebugTools = require("../src/ReplicatedStorage/Shared/DebugTools")
local DevAccess = require("../src/ReplicatedStorage/Shared/DevAccess")
local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Materials = require("../src/ReplicatedStorage/Shared/Materials")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")

local SERVER = "src/ServerScriptService/ShardfallServer/"
local CLIENT = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"

local function profile()
	return {
		level = 1,
		xp = 10,
		gold = 547,
		shardKeys = 0,
		gems = 0,
		shardDust = 0,
		eventTokens = 0,
		eggs = 1,
		chests = {},
		shardTokens = 49,
		prismTokens = 0,
		shardLuck = 0,
		luckBoost = 0,
		forgeBoostUntil = 0,
		ascension = 0,
		materials = Materials.empty(),
	}
end

local function allOff(_flag: string): boolean
	return false
end

local function allOn(_flag: string): boolean
	return true
end

describe("Dev Tools messages", function()
	it("says what each profile action added and the new total", function()
		local data = profile()
		local ok, text = DebugTools.apply(data, "gold")
		expect(ok).toEqual(true)
		expect(text).toEqual("+1000 Gold (now 1547).")
		expect(select(2, DebugTools.apply(data, "level"))).toEqual("Level 20 (was 1).")
		expect(select(2, DebugTools.apply(data, "keys"))).toEqual("+20 Shard Keys (now 20).")
		expect(select(2, DebugTools.apply(data, "eggs"))).toEqual("+1 Egg (now 2).")
		expect(select(2, DebugTools.apply(data, "chest"))).toEqual("+1 Rare chest (now 1).")
		expect(DebugTools.apply(data, "nope")).toEqual(false)
	end)

	it("says what each grant changed", function()
		local data = profile()
		expect(select(2, DebugTools.grant(data, "tokens", 0))).toEqual("+5 Shards (now 54).")
		expect(data.shardTokens).toEqual(54)
		expect(select(2, DebugTools.grant(data, "luck", 0))).toEqual("+25 Shard Luck (now 25).")
		expect(select(2, DebugTools.grant(data, "prisms", 0))).toEqual("+5 Prism Tokens (now 5).")
		local _, forge = DebugTools.grant(data, "forgeboost", 1000)
		expect(string.find(forge, "Forge Boost on", 1, true) ~= nil).toBeTrue()
		expect(data.forgeBoostUntil > 1000).toBeTrue()
		local _, boost = DebugTools.grant(data, "boost", 0)
		expect(string.find(boost, "Luck Boost on", 1, true) ~= nil).toBeTrue()
		expect(select(2, DebugTools.grant(data, "ascension", 0))).toEqual(
			string.format("Ascension 0 -> 1 (max %d).", Pools.MAX_ASCENSION)
		)
		expect(DebugTools.grant(data, "nope", 0)).toEqual(false)
	end)

	it("lists the materials bundle and where to find it", function()
		local data = profile()
		local ok, text = DebugTools.grant(data, "materials", 0)
		expect(ok).toEqual(true)
		expect(string.find(text, "materials (see Bag)", 1, true) ~= nil).toBeTrue()
		expect(string.find(text, Materials.displayName("wood") .. " x8", 1, true) ~= nil).toBeTrue()
		expect(data.materials.wood).toEqual(8)
	end)

	it("says when a grant hits its cap instead of pretending", function()
		local data = profile()
		data.shardLuck = 500
		expect(select(2, DebugTools.grant(data, "luck", 0))).toEqual("Shard Luck already at the cap (500).")
		data.ascension = Pools.MAX_ASCENSION
		local _, text = DebugTools.grant(data, "ascension", 0)
		expect(string.find(text, "already at the max", 1, true) ~= nil).toBeTrue()
	end)
end)

describe("Dev Tools gates", function()
	it("refuses a parked system with a clear line", function()
		expect(DevTools.blocked("DevGrant", "chests", allOff)).toEqual(
			"The chest system is off (LaunchGate.chests), so this does nothing yet."
		)
		expect(DevTools.blocked("Debug", "chest", allOff) ~= nil).toBeTrue()
		expect(DevTools.blocked("Debug", "raid", allOff) ~= nil).toBeTrue()
		expect(DevTools.blocked("DevGrant", "prisms", allOff) ~= nil).toBeTrue()
		expect(DevTools.blocked("Debug", "gold", allOff)).toBeNil()
		expect(DevTools.blocked("DevGrant", "materials", allOff)).toBeNil()
		expect(DevTools.blocked("DevGrant", "chests", allOn)).toBeNil()
		expect(DevTools.blocked("Debug", 5, allOff)).toBeNil()
	end)

	it("hides the parked buttons with today's LaunchGate and lists them", function()
		local hidden = DevTools.hiddenLabels()
		local set = {}
		for _, label in ipairs(hidden) do
			set[label] = true
		end
		expect(LaunchGate.on("chests")).toEqual(false)
		expect(set["Chest pack"]).toEqual(true)
		expect(set["+1 Rare chest"]).toEqual(true)
		expect(set["+1000 Gold"]).toBeNil()
		expect(#DevTools.hiddenLabels(allOn)).toEqual(0)
	end)

	it("has one button per action and no Settings-style duplicates", function()
		local seen = {}
		local ids = {}
		for _, section in ipairs(DevTools.SECTIONS) do
			expect(#section.title > 0).toBeTrue()
			for _, item in ipairs(section.entries) do
				local key = item.remote .. ":" .. item.arg
				expect(seen[key]).toBeNil()
				expect(ids[item.id]).toBeNil()
				seen[key] = true
				ids[item.id] = true
			end
		end
		expect(seen["Debug:gold"]).toEqual(true)
		expect(seen["DevGrant:tokens"]).toEqual(true)
		expect(seen["Dungeon:skip"]).toEqual(true)
	end)
end)

describe("Dev Tools result text", function()
	it("toasts the server line, the refusal, and a thrown call", function()
		expect({ DevTools.resultText("x", true, { ok = true, message = "+5 Shards (now 54)." }) }).toEqual({
			true,
			"+5 Shards (now 54).",
		})
		expect({ DevTools.resultText("Gold", true, { ok = false, error = DevAccess.DENIED }) }).toEqual({
			false,
			"Gold: " .. DevAccess.DENIED,
		})
		expect({ DevTools.resultText("Boss", true, { ok = true }) }).toEqual({ true, "Boss: done." })
		local ok, text = DevTools.resultText("Gold", false, "remote down")
		expect(ok).toEqual(false)
		expect(string.find(text, "remote down", 1, true) ~= nil).toBeTrue()
		expect((DevTools.resultText("Gold", true, nil))).toEqual(false)
		expect(DevTools.outputLine(true, "+1000 Gold (now 1547).")).toEqual("[Dev] ok +1000 Gold (now 1547).")
	end)
end)

describe("Dev Tools layout", function()
	it("keeps the button and side panel on screen, under the pills, off the centre", function()
		for _, size in ipairs({ { 1280, 800 }, { 1920, 1080 }, { 390, 844 }, { 844, 390 } }) do
			local vx, vy = size[1], size[2]
			local button, panel = DevTools.layout(vx, vy, 16)
			expect(button.x >= 0 and button.x + button.w <= vx).toBeTrue()
			expect(button.y >= 0 and button.y + button.h <= vy).toBeTrue()
			expect(panel.x >= 0 and panel.x + panel.w <= vx).toBeTrue()
			expect(panel.y > button.y and panel.y + panel.h <= vy).toBeTrue()
			expect(panel.w <= 300).toBeTrue()
			if vx >= 800 then
				-- A side panel: the left half of the screen stays clear.
				expect(panel.x > vx / 2).toBeTrue()
			end
		end
	end)
end)

describe("Dev Tools wiring", function()
	it("checks access and gates on the server and sends a message", function()
		local debugService = fs.readFile(SERVER .. "DebugService.luau")
		local roll = fs.readFile(SERVER .. "RollService.luau")
		expect(string.find(debugService, 'DevTools.blocked("Debug", action)', 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, 'DevTools.blocked("DevGrant", kind)', 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "DebugTools.grant(data, kind, os.time())", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "return { ok = true, message = message }", 1, true) ~= nil).toBeTrue()
		local accessAt = string.find(roll, "DevAccess.player(player)", string.find(roll, "function RollService.devGrant", 1, true), true)
		local gateAt = string.find(roll, 'DevTools.blocked("DevGrant", kind)', 1, true)
		expect(accessAt ~= nil and gateAt ~= nil and (accessAt :: number) < (gateAt :: number)).toBeTrue()
	end)

	it("moves the rows out of Settings into the panel, which toasts and prints", function()
		local hub = fs.readFile(CLIENT .. "MenuHub.luau")
		local hud = fs.readFile(CLIENT .. "DebugHud.luau")
		local client = fs.readFile(CLIENT .. "init.client.luau")
		expect(string.find(hub, '"Debug  "', 1, true)).toBeNil()
		expect(string.find(hub, '"Grant  "', 1, true)).toBeNil()
		expect(string.find(hud, "DevTools.SECTIONS", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "DevTools.resultText(", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "DevTools.outputLine(", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "hooks.toast", 1, true) ~= nil).toBeTrue()
		expect(string.find(hud, "Modal = true", 1, true)).toBeNil()
		expect(string.find(hud, "ContextActionService", 1, true)).toBeNil()
		expect(string.find(client, 'retireChrome("ShardfallDebug")', 1, true)).toBeNil()
		expect(string.find(client, "hudShell.toast(message)", string.find(client, "DebugHud.start(", 1, true), true) ~= nil).toBeTrue()
	end)
end)
