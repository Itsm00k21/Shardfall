--!strict

--[[
	P2-462-1. One Legendary roll fires one RollAnnounce.

	Flag on: tiers at or above Config.BigRoll.MIN_TIER get the beam line
	and not the older "rolled" broadcast. Flag off: that older line only,
	the same payload as before. The flag ships false. schemaVersion stays 26.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local BigRoll = require("../src/ReplicatedStorage/Shared/Config/BigRoll")
local BigRollBeam = require("../src/ReplicatedStorage/Shared/BigRollBeam")
local Currencies = require("../src/ReplicatedStorage/Shared/Currencies")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollConfig = require("../src/ReplicatedStorage/Shared/RollConfig")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionGuide = require("../src/ReplicatedStorage/Shared/SessionGuide")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local StarterGoalPay = require("../src/ReplicatedStorage/Shared/StarterGoalPay")

local POOL = "verdant_armory"

local function folder(className: string, name: string)
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
	function object:IsA(kind: string): boolean
		return kind == self.ClassName or kind == "Instance"
	end
	return setmetatable(object, {
		__index = function(self, key)
			return self:FindFirstChild(key)
		end,
	})
end

local function harness()
	local registry: { [any]: any } = {}
	local rows: { any } = {}
	local beats: { () -> () } = {}
	local now = 1000
	local guids = 0
	local active = { profile = Schema.template() }
	local scriptedNumbers: { number } = {}
	local scriptedAt = 0

	local function add(parent: any, name: string, value: any)
		local node = {
			Name = name,
			ClassName = "ModuleScript",
			Parent = parent,
		}
		table.insert(parent.children, node)
		registry[node] = value
		return node
	end

	local replicated = folder("ReplicatedStorage", "ReplicatedStorage")
	local shared = folder("Folder", "Shared")
	shared.Parent = replicated
	table.insert(replicated.children, shared)
	local modules = {
		BigRollBeam = BigRollBeam,
		Currencies = Currencies,
		GearSalvage = GearSalvage,
		LaunchGate = LaunchGate,
		Pools = Pools,
		Rarities = Rarities,
		RarityConfig = RarityConfig,
		RollConfig = RollConfig,
		RollLoop = RollLoop,
		RollMath = RollMath,
		Schema = Schema,
		SessionGuide = SessionGuide,
		Settings = Settings,
		StarterGoalPay = StarterGoalPay,
		CallBudget = {},
		DebugTools = {},
		DevAccess = {},
		DevTools = {},
	}
	for name, value in pairs(modules) do
		add(shared, name, value)
	end

	local remotes = folder("Folder", "Remotes")
	remotes.Parent = replicated
	table.insert(replicated.children, remotes)
	local announce = folder("RemoteEvent", "RollAnnounce")
	announce.Parent = remotes
	table.insert(remotes.children, announce)
	function announce:FireAllClients(payload: any)
		table.insert(rows, payload)
	end

	local server = folder("Folder", "ShardfallServer")
	local rollScript = {
		Name = "RollService",
		ClassName = "ModuleScript",
		Parent = server,
	}
	table.insert(server.children, rollScript)
	add(server, "DataService", {
		get = function()
			return active.profile
		end,
		mutate = function(_player, callback)
			local reason = callback(active.profile)
			if type(reason) == "string" then
				return false, reason
			end
			return true, nil
		end,
	})
	add(server, "PolicyCache", {
		allowPaid = function()
			return false, "closed", "closed"
		end,
	})

	local signal = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
	local players = folder("Players", "Players")
	players.PlayerRemoving = signal
	players.PlayerAdded = signal
	local runService = {
		Heartbeat = {
			Connect = function(_self, fn: () -> ())
				table.insert(beats, fn)
				return { Disconnect = function() end }
			end,
		},
		IsStudio = function()
			return true
		end,
	}
	local http = {
		GenerateGUID = function(_self, _wrap: boolean?): string
			guids += 1
			return string.format("roll-%d", guids)
		end,
	}
	local services = {
		ReplicatedStorage = replicated,
		Players = players,
		RunService = runService,
		HttpService = http,
	}
	local game = {
		JobId = "beam-dedupe-test",
		PlaceId = 0,
	}
	function game:GetService(name: string)
		local found = services[name]
		if found == nil then
			error("no service " .. tostring(name), 2)
		end
		return found
	end

	local realTypeof = typeof
	local sandboxOs = setmetatable({
		clock = function()
			return now
		end,
	}, { __index = os })
	local environment = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		xpcall = xpcall,
		print = print,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		warn = function() end,
		math = math,
		string = string,
		table = table,
		os = sandboxOs,
		debug = debug,
		coroutine = coroutine,
		task = {
			wait = function() end,
			spawn = function() end,
			defer = function() end,
			delay = function() end,
		},
		Random = {
			new = function()
				return {
					NextNumber = function()
						scriptedAt += 1
						local value = scriptedNumbers[scriptedAt]
						if type(value) == "number" then
							return value
						end
						return 0.5
					end,
					NextInteger = function(_self, minimum: number, _maximum: number)
						return minimum
					end,
				}
			end,
		},
		game = game,
		script = rollScript,
		typeof = function(value)
			if type(value) == "table" and value.ClassName == "Player" then
				return "Instance"
			end
			return realTypeof(value)
		end,
		require = function(module)
			local loaded = registry[module]
			if loaded == nil then
				local name = if type(module) == "table" then module.Name else tostring(module)
				error("unexpected require " .. tostring(name), 0)
			end
			return loaded
		end,
	}

	local source = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
	local chunk = luau.load(luau.compile(source, { debugLevel = 2 }), {
		debugName = "RollService",
		environment = environment,
	})
	local service = chunk()

	local player = {
		ClassName = "Player",
		Name = "Ada",
		DisplayName = "Ada",
		UserId = 41,
	}
	function player:IsA(kind: string): boolean
		return kind == "Player" or kind == "Instance"
	end

	local function advance(seconds: number)
		now += seconds
	end

	local function beat()
		for _, fn in ipairs(beats) do
			fn()
		end
	end

	local function clear()
		for index = #rows, 1, -1 do
			rows[index] = nil
		end
	end

	local function fresh()
		local data = Schema.template()
		data.sinceLegendary = RollConfig.LEGENDARY_PITY - 1
		data.shardTokens = 40
		active.profile = data
		return data
	end

	local function scriptNumbers(values: { number })
		scriptedNumbers = values
		scriptedAt = 0
	end

	return {
		service = service,
		player = player,
		rows = rows,
		advance = advance,
		beat = beat,
		clear = clear,
		fresh = fresh,
		clock = function()
			return now
		end,
		scriptNumbers = scriptNumbers,
	}
end

local world = harness()

local function legendaryCount(result: any): number
	local count = 0
	local items = result.items
	if type(items) ~= "table" then
		if result.rarity == "Legendary" then
			return 1
		end
		return 0
	end
	for _, row in ipairs(items) do
		if type(row) == "table" and row.rarity == "Legendary" then
			count += 1
		end
	end
	return count
end

local function oldLine(itemName: string): { [string]: any }
	return {
		text = string.format("Ada rolled %s (Legendary)", itemName),
		rarity = "Legendary",
		crossServer = false,
	}
end

local function withFlag(on: boolean, fn: () -> ())
	local previous = LaunchGate.SHOW.bigRollBeam
	LaunchGate.SHOW.bigRollBeam = on
	BigRollBeam.reset()
	world.clear()
	world.fresh()
	world.scriptNumbers({})
	world.advance(120)
	local ok, err = pcall(fn)
	LaunchGate.SHOW.bigRollBeam = previous
	BigRollBeam.reset()
	if not ok then
		error(err, 0)
	end
end

local function pump()
	world.advance(30)
	world.beat()
end

describe("Legendary RollAnnounce", function()
	it("ships the beam flag off and schema 26", function()
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
		expect(LaunchGate.on("bigRollBeam")).toEqual(false)
		expect(BigRoll.MIN_TIER).toEqual("Epic")
	end)

	it("fires exactly one RollAnnounce for each Legendary while the beam flag is on", function()
		withFlag(true, function()
			local first = world.service.rollFree(world.player, POOL, false)
			expect(first.ok).toEqual(true)
			expect(first.rarity).toEqual("Legendary")
			expect(#world.rows).toEqual(0)
			pump()
			expect(#world.rows).toEqual(1)
			expect(world.rows[1].kind).toEqual("bigRoll")
			expect(world.rows[1].rarity).toEqual("Legendary")
			expect(world.rows[1].userId).toEqual(41)
			expect(world.rows[1].crossServer).toEqual(false)
			expect(world.rows[1].beam).toEqual(true)
			expect(string.find(world.rows[1].text, "LEGENDARY", 1, true) ~= nil).toBeTrue()
			expect(string.find(world.rows[1].text, "rolled", 1, true)).toBeNil()

			world.fresh().sinceLegendary = RollConfig.LEGENDARY_PITY - 1
			world.advance(120)
			local second = world.service.rollFree(world.player, POOL, false)
			expect(second.ok).toEqual(true)
			expect(second.rarity).toEqual("Legendary")
			expect(#world.rows).toEqual(1)
			pump()
			expect(#world.rows).toEqual(2)
			expect(world.rows[2].kind).toEqual("bigRoll")
			expect(world.rows[2].rarity).toEqual("Legendary")

			world.advance(120)
			local common = world.service.rollFree(world.player, POOL, false)
			expect(common.ok).toEqual(true)
			expect(common.rarity).toEqual("Common")
			pump()
			expect(#world.rows).toEqual(2)
		end)
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
	end)

	it("keeps the old Legendary RollAnnounce while the beam flag is off", function()
		withFlag(false, function()
			local first = world.service.rollFree(world.player, POOL, false)
			expect(first.ok).toEqual(true)
			expect(first.rarity).toEqual("Legendary")
			expect(#world.rows).toEqual(1)
			expect(world.rows[1]).toEqual(oldLine(first.item.name))
			pump()
			expect(#world.rows).toEqual(1)
			expect(world.rows[1]).toEqual(oldLine(first.item.name))

			world.fresh().sinceLegendary = RollConfig.LEGENDARY_PITY - 1
			world.advance(120)
			local second = world.service.rollFree(world.player, POOL, false)
			expect(second.ok).toEqual(true)
			expect(second.rarity).toEqual("Legendary")
			expect(#world.rows).toEqual(2)
			expect(world.rows[2]).toEqual(oldLine(second.item.name))
			pump()
			expect(#world.rows).toEqual(2)
			expect(world.rows[1].kind).toBeNil()
			expect(world.rows[2].kind).toBeNil()
		end)
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
	end)

	it("fires one RollAnnounce per Legendary in an x10, flag on or off", function()
		withFlag(true, function()
			local result = world.service.rollMany(world.player, POOL, 10)
			expect(result.ok).toEqual(true)
			expect(legendaryCount(result)).toEqual(1)
			expect(#world.rows).toEqual(0)
			pump()
			expect(#world.rows).toEqual(1)
			expect(world.rows[1].kind).toEqual("bigRoll")
			expect(world.rows[1].rarity).toEqual("Legendary")
			expect(world.rows[1].count).toEqual(1)
		end)
		withFlag(false, function()
			local result = world.service.rollMany(world.player, POOL, 10)
			expect(result.ok).toEqual(true)
			expect(legendaryCount(result)).toEqual(1)
			expect(#world.rows).toEqual(1)
			expect(world.rows[1]).toEqual(oldLine(result.items[1].item.name))
			pump()
			expect(#world.rows).toEqual(1)
		end)
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
		expect(BigRoll.MIN_TIER).toEqual("Epic")
	end)

	it("names both Legendaries in an x10 and folds neither into +N more", function()
		withFlag(true, function()
			local start = world.clock()
			for userId = 1, BigRoll.CHAT_MAX do
				local fact = BigRollBeam.serverRoll({
					userId = userId,
					displayName = "P" .. tostring(userId),
					itemName = "Blade",
					rarity = "Epic",
					quick = true,
				})
				BigRollBeam.offer(fact, start)
			end
			world.advance(BigRollBeam.delay("Epic", true))
			world.beat()
			expect(#world.rows).toEqual(BigRoll.CHAT_MAX)
			for _, row in ipairs(world.rows) do
				expect(row.rarity).toEqual("Epic")
				expect(row.overflow).toBeNil()
			end

			-- Pity forces roll 1. The next scripted 0 is roll 2's Legendary
			-- check; the 0 after that picks its item. Later draws stay off
			-- Legendary and Epic.
			local draws = {}
			for _ = 1, 6 do
				table.insert(draws, 0.5)
			end
			table.insert(draws, 0)
			table.insert(draws, 0)
			world.scriptNumbers(draws)
			local result = world.service.rollMany(world.player, POOL, 10)
			expect(result.ok).toEqual(true)
			expect(result.count).toEqual(10)
			local names = {}
			for _, row in ipairs(result.items) do
				if row.rarity == "Legendary" then
					table.insert(names, row.item.name)
				end
			end
			expect(#names).toEqual(2)
			expect(#world.rows).toEqual(BigRoll.CHAT_MAX)

			world.advance(BigRoll.PLAYER_GAP + 1)
			world.beat()
			local named = {}
			for _, row in ipairs(world.rows) do
				expect(row.overflow).toBeNil()
				expect(string.find(row.text, "more big rolls", 1, true)).toBeNil()
				if row.rarity == "Legendary" then
					table.insert(named, row)
				end
			end
			expect(#named).toEqual(2)
			local pending = { named[1], named[2] }
			for _, itemName in ipairs(names) do
				local found = nil
				for index, row in ipairs(pending) do
					local text = row.text
					if
						row.kind == "bigRoll"
						and row.count == 1
						and row.displayName == "Ada"
						and string.find(text, itemName, 1, true) ~= nil
						and string.find(text, "LEGENDARY", 1, true) ~= nil
					then
						found = index
						break
					end
				end
				expect(found ~= nil).toBeTrue()
				table.remove(pending, found :: number)
			end
			expect(#pending).toEqual(0)

			local sent = #world.rows
			world.advance(BigRoll.CHAT_WINDOW)
			world.beat()
			expect(#world.rows).toEqual(sent)
			for _, row in ipairs(world.rows) do
				expect(row.overflow).toBeNil()
				expect(string.find(row.text, "more big rolls", 1, true)).toBeNil()
			end
		end)
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)

	it("skips the old line only for a tier the beam would send", function()
		local mythic = { MIN_TIER = "Mythic" }
		expect(BigRollBeam.qualifies("Legendary")).toEqual(true)
		expect(BigRollBeam.qualifies("Epic")).toEqual(true)
		expect(BigRollBeam.qualifies("Rare")).toEqual(false)
		expect(BigRollBeam.qualifies("Legendary", mythic)).toEqual(false)
		expect(BigRollBeam.qualifies("Mythic", mythic)).toEqual(true)
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		local gate = string.find(roll, 'if LaunchGate.on("bigRollBeam") and BigRollBeam.qualifies(rarity) then', 1, true)
		local body = string.find(roll, "local function broadcastRoll", 1, true)
		expect(body ~= nil and gate ~= nil and (body :: number) < (gate :: number)).toBeTrue()
		local crackAt = string.find(roll, "local function crack(", 1, true)
		local batchAt = string.find(roll, "local function crackBatch", 1, true)
		local manyAt = string.find(roll, "function RollService.rollMany", 1, true)
		expect(crackAt ~= nil and batchAt ~= nil and manyAt ~= nil).toBeTrue()
		local crack = string.sub(roll, crackAt :: number, (batchAt :: number) - 1)
		local batch = string.sub(roll, batchAt :: number, (manyAt :: number) - 1)
		expect(string.find(crack, "broadcastRoll(player.Name, captured.item.name, captured.rarity)", 1, true) ~= nil).toBeTrue()
		expect(string.find(batch, "broadcastRoll(player.Name, drawn.item.name, drawn.rarity)", 1, true) ~= nil).toBeTrue()
		expect(string.find(crack, "broadcast(", 1, true)).toBeNil()
		expect(string.find(batch, "broadcast(", 1, true)).toBeNil()
		local dropAt = string.find(roll, "function RollService.announceDrop", 1, true)
		local bindAt = string.find(roll, "function RollService.bindAnnouncements", 1, true)
		expect(dropAt ~= nil and bindAt ~= nil and (dropAt :: number) < (bindAt :: number)).toBeTrue()
		local drop = string.sub(roll, dropAt :: number, (bindAt :: number) - 1)
		expect(string.find(drop, "broadcast(name, shard, rarity, crossServer)", 1, true) ~= nil).toBeTrue()
		expect(string.find(drop, "broadcastRoll", 1, true)).toBeNil()
		expect(BigRoll.MIN_TIER).toEqual("Epic")
		expect(LaunchGate.SHOW.bigRollBeam).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)
end)
