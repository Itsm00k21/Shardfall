--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local CombatMath = require("../src/ReplicatedStorage/Shared/CombatMath")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local TrainingGrove = require("../src/ReplicatedStorage/Shared/TrainingGrove")

local function instance(className: string, name: string)
	local object = {
		ClassName = className,
		Name = name,
		children = {},
	}
	function object:FindFirstChild(childName: string)
		for _, child in ipairs(self.children) do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end
	return setmetatable(object, {
		__index = function(self, key)
			return self:FindFirstChild(key)
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				rawset(self, "Parent", value)
				if value ~= nil then
					table.insert(value.children, self)
				end
				return
			end
			rawset(self, key, value)
		end,
	})
end

local function loadGrove()
	local replicated = instance("ReplicatedStorage", "ReplicatedStorage")
	local shared = instance("Folder", "Shared")
	shared.Parent = replicated
	local modules = {
		CombatMath = CombatMath,
		Haven = Haven,
		Schema = Schema,
		TrainingGrove = TrainingGrove,
	}
	local scripts = {}
	for name in pairs(modules) do
		local module = instance("ModuleScript", name)
		module.Parent = shared
		scripts[module] = modules[name]
	end
	local players = {
		PlayerRemoving = {
			Connect = function(_signal, _callback)
				return {
					Disconnect = function() end,
				}
			end,
		},
	}
	local environment = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		pairs = pairs,
		pcall = pcall,
		print = print,
		select = select,
		tostring = tostring,
		type = type,
		typeof = typeof,
		warn = warn,
		math = math,
		string = string,
		table = table,
		os = os,
		game = {
			GetService = function(_game, name)
				if name == "ReplicatedStorage" then
					return replicated
				end
				if name == "Players" then
					return players
				end
				error("no service " .. tostring(name), 2)
			end,
		},
		require = function(module)
			local loaded = scripts[module]
			if loaded == nil then
				error("unexpected require", 2)
			end
			return loaded
		end,
	}
	local source = fs.readFile("src/ServerScriptService/ShardfallServer/GroveService.luau")
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = "GroveService",
		environment = environment,
	})
	return chunk()
end

local GroveService = loadGrove()

local function profile()
	local data = Schema.template()
	data.gold = 15
	data.shardKeys = 40
	return data
end

local function ribbons(data): number
	local count = 0
	for _, item in pairs(data.inventory) do
		if type(item) == "table" and item.templateId == "grove_ribbon" then
			count += 1
		end
	end
	return count
end

local function step(data, damage: number, healing: number?, elapsed: number?)
	return GroveService.commit(data, {
		damage = damage,
		healing = healing,
		elapsed = elapsed or 0,
	}, "grove-ribbon-uid", 10)
end

describe("GroveService", function()
	it("counts a server hit, then a red dodge, then the four colors, and grants one ribbon", function()
		local data = profile()
		local saved = data.trainingGrove
		table.freeze(saved)
		table.freeze(saved.colors)
		local hit = step(data, 30, 8, 10)
		expect(hit.ok).toEqual(true)
		expect(hit.saved).toEqual(true)
		expect(hit.action).toEqual("hit")
		expect(hit.granted).toEqual(false)
		expect(hit.keys).toEqual(0)
		expect(hit.gold).toEqual(0)
		expect(hit.dps).toEqual(3)
		expect(hit.hps).toEqual(0.8)
		expect(saved.hits).toEqual(0)
		expect(data.trainingGrove.hits).toEqual(1)
		expect(data.trainingGrove.damage).toEqual(30)
		expect(data.trainingGrove.healing).toEqual(8)
		expect(data.trainingGrove.dummy).toEqual(true)
		expect(data.trainingGrove.up).toEqual(true)
		expect(data.trainingGrove.dodge).toEqual(false)
		expect(data.gold).toEqual(15)
		expect(data.shardKeys).toEqual(40)
		expect(data.schemaVersion).toEqual(26)
		expect(ribbons(data)).toEqual(0)

		local dodged = step(data, 1, 0, 10)
		expect(dodged.action).toEqual("dodge")
		expect(dodged.granted).toEqual(false)
		expect(data.trainingGrove.dodge).toEqual(true)
		expect(data.trainingGrove.colors.red).toEqual(false)
		expect(data.trainingGrove.room).toEqual(false)

		local order = { "red", "yellow", "purple", "blue" }
		for index, color in ipairs(order) do
			local marked = step(data, 1, 0, 10)
			expect(marked.action).toEqual("color")
			expect(data.trainingGrove.colors[color]).toEqual(true)
			if index < 4 then
				expect(marked.granted).toEqual(false)
				expect(data.trainingGrove.room).toEqual(false)
				expect(data.trainingGrove.cosmetic).toEqual(false)
			end
		end
		expect(data.trainingGrove.room).toEqual(true)
		expect(data.trainingGrove.cosmetic).toEqual(true)
		expect(ribbons(data)).toEqual(1)
		local item = data.inventory["grove-ribbon-uid"]
		expect(item.templateId).toEqual("grove_ribbon")
		expect(item.kind).toEqual("Cosmetic")
		expect(item.rarity).toEqual("Common")
		expect(item.bound).toEqual(true)
		expect(item.tradeable).toEqual(false)
		expect(item.name).toEqual("Grove Ribbon")
		expect(Schema.isEquipped(data, item.uid)).toEqual(false)
		expect(data.equipped.weapon).toBeNil()
		expect(data.equipped.pet).toBeNil()
		expect(data.gold).toEqual(15)
		expect(data.shardKeys).toEqual(40)
		expect(Schema.equipItem(data, item)).toEqual("That item cannot be equipped.")

		local again = step(data, 5, 0, 10)
		expect(again.action).toEqual("hit")
		expect(again.granted).toEqual(false)
		expect(ribbons(data)).toEqual(1)
		expect(data.trainingGrove.hits).toEqual(2)
		expect(data.gold).toEqual(15)
	end)

	it("does not grant a second ribbon when the flag is cleared and the bag already has one", function()
		local data = profile()
		for _ = 1, 6 do
			step(data, 1, 0, 0)
		end
		expect(ribbons(data)).toEqual(1)
		expect(data.trainingGrove.cosmetic).toEqual(true)
		data.trainingGrove.cosmetic = false
		local retry = step(data, 1, 0, 0)
		expect(retry.saved).toEqual(true)
		expect(data.trainingGrove.cosmetic).toEqual(true)
		expect(ribbons(data)).toEqual(1)
		expect(data.inventory["grove-ribbon-uid"].kind).toEqual("Cosmetic")
		expect(data.gold).toEqual(15)
		expect(data.shardKeys).toEqual(40)
	end)

	it("keeps the stations and withholds the ribbon when the bag is full", function()
		local data = profile()
		local ready = TrainingGrove.hit(data.trainingGrove, { damage = 4 }).state
		ready = TrainingGrove.dodge(ready, { color = "red" }).state
		for _, color in ipairs(TrainingGrove.CONFIG.colors) do
			ready = TrainingGrove.color(ready, { color = color }).state
		end
		expect(ready.cosmetic).toEqual(false)
		data.trainingGrove = ready
		local cap = Schema.inventoryCap(data)
		for index = 1, cap do
			local uid = "fill-" .. tostring(index)
			data.inventory[uid] = { uid = uid, templateId = "filler", kind = "Cosmetic" }
		end
		local blocked = step(data, 1, 0, 0)
		expect(blocked.saved).toEqual(true)
		expect(blocked.granted).toEqual(false)
		expect(blocked.error).toEqual("Inventory is full.")
		expect(data.trainingGrove.cosmetic).toEqual(false)
		expect(data.trainingGrove.dummy).toEqual(true)
		expect(data.trainingGrove.dodge).toEqual(true)
		expect(data.trainingGrove.room).toEqual(true)
		expect(ribbons(data)).toEqual(0)
		expect(data.gold).toEqual(15)
		expect(data.shardKeys).toEqual(40)

		data.inventory["fill-1"] = nil
		local granted = step(data, 1, 0, 0)
		expect(granted.granted).toEqual(true)
		expect(data.trainingGrove.cosmetic).toEqual(true)
		expect(ribbons(data)).toEqual(1)
		expect(Schema.isEquipped(data, "grove-ribbon-uid")).toEqual(false)
		expect(data.gold).toEqual(15)
	end)

	it("refuses a client payload and leaves the saved grove in place", function()
		local data = profile()
		local first = step(data, 6, 0, 0)
		expect(first.saved).toEqual(true)
		expect(data.trainingGrove.hits).toEqual(1)
		local payloads = {
			{ damage = -1 },
			{ damage = 0 / 0 },
			{ damage = math.huge },
			{ damage = 1, userId = 7 },
			{ damage = 1, UserId = 7 },
			{ damage = 1, guildId = "g" },
			{ damage = 1, state = { dummy = true, cosmetic = true } },
			{ damage = 1, color = "blue" },
			{ damage = 1, clear = true },
			{ damage = 1, productId = 1 },
			{ damage = 1, robux = 0 },
			{ damage = 1, cost = 0 },
			{ damage = 1, skip = false },
			{ damage = 1, paid = true },
			{ damage = 1, gold = 15 },
			{ damage = 1, keys = 10 },
		}
		for _, request in ipairs(payloads) do
			local before = data.trainingGrove.hits
			local outcome = GroveService.commit(data, request, "grove-ribbon-uid", 10)
			expect(outcome.ok).toEqual(false)
			expect(outcome.saved).toEqual(false)
			expect(outcome.granted).toEqual(false)
			expect(data.trainingGrove.hits).toEqual(before)
			expect(data.trainingGrove.cosmetic).toEqual(false)
			expect(ribbons(data)).toEqual(0)
			expect(data.gold).toEqual(15)
			expect(data.shardKeys).toEqual(40)
		end
	end)

	it("does not replace an inconsistent grove record", function()
		local data = profile()
		data.trainingGrove = {
			hits = 0,
			damage = 0,
			healing = 0,
			up = true,
			dummy = true,
			dodge = false,
			colors = { red = false, yellow = false, purple = false, blue = false },
			room = false,
			cosmetic = false,
		}
		local outcome = step(data, 5, 0, 0)
		expect(outcome.ok).toEqual(false)
		expect(outcome.saved).toEqual(false)
		expect(data.trainingGrove.hits).toEqual(0)
		expect(data.trainingGrove.dummy).toEqual(true)
		expect(data.gold).toEqual(15)
		expect(ribbons(data)).toEqual(0)
	end)

	it("builds the plaza call without a client id, a payout, or a second schema", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/GroveService.luau")
		local server = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		local haven = fs.readFile("src/ReplicatedStorage/Shared/Haven.luau")
		local builder = fs.readFile("src/ServerScriptService/ShardfallServer/HavenBuilder.luau")
		expect(string.find(source, "TrainingGrove.clear", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, 'color = "red"', 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "Schema.applyGrove", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "grove_ribbon", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(source, "ProcessReceipt", 1, true)).toBeNil()
		expect(string.find(source, "Robux", 1, true)).toBeNil()
		expect(string.find(source, "DungeonService", 1, true)).toBeNil()
		expect(string.find(source, "CombatFeel", 1, true)).toBeNil()
		expect(string.find(source, "RaidPractice", 1, true)).toBeNil()
		expect(string.find(source, "Codex", 1, true)).toBeNil()
		expect(string.find(source, "Onboarding", 1, true)).toBeNil()
		expect(string.find(source, "data.gold = data.gold", 1, true)).toBeNil()
		expect(string.find(source, "data.shardKeys = data.shardKeys", 1, true)).toBeNil()
		local dungeonAt = string.find(server, "DungeonService.start()", 1, true)
		local groveAt = string.find(server, "GroveService.start()", 1, true)
		expect(dungeonAt ~= nil and groveAt ~= nil and dungeonAt < groveAt).toBeTrue()
		expect(string.find(haven, "Haven.GROVE", 1, true) ~= nil).toBeTrue()
		expect(string.find(builder, "GroveDummy", 1, true) ~= nil).toBeTrue()
		expect(string.find(builder, "buildGrove(parent)", 1, true) ~= nil).toBeTrue()

		local loops = fs.readFile("src/ReplicatedStorage/Shared/Loops.luau")
		local rarity = fs.readFile("src/ReplicatedStorage/Shared/RarityConfig.luau")
		local chests = fs.readFile("src/ReplicatedStorage/Shared/ChestConfig.luau")
		expect(string.find(loops, "Loops.PREMIUM_ENABLED = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "Loops.PASS_PRODUCT_ID = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "Loops.ARCHIVE_PRODUCT_ID = 0", 1, true) ~= nil).toBeTrue()
		expect(string.find(rarity, "RarityConfig.PAID_LUCK_ENABLED = false", 1, true) ~= nil).toBeTrue()
		expect(string.find(chests, "ChestConfig.PAID_CHESTS_ENABLED = false", 1, true) ~= nil).toBeTrue()
		expect(Schema.VERSION).toEqual(26)
		expect(Haven.GROVE.x).toEqual(-16)
	end)
end)
