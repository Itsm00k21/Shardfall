--!strict

--[[
	Launch safety.

	Shutdown has to save and release every loaded profile, including one
	whose player is already gone from GetPlayers(). A second roll, salvage,
	or equip in the same moment must not grant a second item, a second
	pile of currency, or a second spend. Schema stays 26. Launch flags
	stay off. Nothing here deletes a save.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local Elements = require("../src/ReplicatedStorage/Shared/Config/Elements")
local EquipSlots = require("../src/ReplicatedStorage/Shared/Config/EquipSlots")
local EquipStats = require("../src/ReplicatedStorage/Shared/Config/EquipStats")
local GearLevels = require("../src/ReplicatedStorage/Shared/Config/GearLevels")
local GearSalvage = require("../src/ReplicatedStorage/Shared/GearSalvage")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local SessionLock = require("../src/ReplicatedStorage/Shared/SessionLock")
local EquipService = require("../src/server/EquipService/EquipService")

local JOB = "launch-safety"
local POOL = "verdant_armory"

local shared = {}
for _, name in ipairs(fs.readDir("src/ReplicatedStorage/Shared")) do
	if string.sub(name, -5) == ".luau" then
		local stem = string.sub(name, 1, -6)
		shared[stem] = require("../src/ReplicatedStorage/Shared/" .. stem)
	end
end

-- CallBudget from disk closes over Lune's task. The sandbox has its own.
shared.CallBudget = {
	DATASTORE_SECONDS = 4,
	run = function(_seconds: number, callback: () -> any): (boolean, any)
		local ok, value = pcall(callback)
		if not ok then
			return false, value
		end
		return true, value
	end,
}

local function makePlayer(name: string, userId: number, players: any)
	local row = {
		ClassName = "Player",
		Name = name,
		UserId = userId,
		Parent = players,
		kicked = nil,
	}
	function row:IsA(kind: string): boolean
		return kind == "Player" or kind == "Instance"
	end
	function row:Kick(message: string)
		self.kicked = message
	end
	return row
end

type BootOptions = {
	studio: boolean?,
	denyKey: string?,
	seed: { [string]: any }?,
}

local function boot(list: { { name: string, id: number } }, options: BootOptions?)
	local opts = options or {}
	local inner = shared.MemoryStore.new()
	if opts.seed ~= nil then
		for key, document in pairs(opts.seed) do
			inner:updateAsync(key, function(_current)
				return document
			end)
		end
	end
	local adapter = {
		persistent = true,
	}
	function adapter:updateAsync(key: string, transform)
		if opts.denyKey ~= nil and key == opts.denyKey then
			error("store down")
		end
		return inner:updateAsync(key, transform)
	end

	local players = {}
	local services = {}
	local closing = nil
	local function signal()
		local bucket = {}
		return {
			Connect = function(_self, fn)
				table.insert(bucket, fn)
				return { Disconnect = function() end }
			end,
		}
	end
	services.Players = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		GetPlayers = function()
			return players
		end,
	}
	services.RunService = {
		Heartbeat = signal(),
		IsStudio = function()
			return opts.studio == true
		end,
	}
	local guid = 0
	services.HttpService = {
		GenerateGUID = function(_self, _wrap)
			guid += 1
			return string.format("guid-%d", guid)
		end,
		JSONEncode = function()
			return "{}"
		end,
		JSONDecode = function()
			return {}
		end,
	}
	services.ReplicatedStorage = setmetatable({
		Name = "ReplicatedStorage",
		ClassName = "ReplicatedStorage",
	}, {
		__index = function(_self, key)
			if key == "Shared" then
				return setmetatable({ Name = "Shared", ClassName = "Folder" }, {
					__index = function(_folder, child)
						return { Name = child, __shared = true }
					end,
				})
			end
			return { Name = key }
		end,
	})

	local loaded = {}
	local game = {
		JobId = JOB,
		PlaceId = 7,
		PrivateServerId = "",
		PrivateServerOwnerId = 0,
	}
	function game:GetService(name: string)
		local found = services[name]
		if found == nil then
			found = {}
			services[name] = found
		end
		return found
	end
	function game:BindToClose(fn)
		closing = fn
	end

	local server = setmetatable({ Name = "ShardfallServer", ClassName = "Folder" }, {
		__index = function(_self, key)
			return { Name = key, __server = true }
		end,
	})

	local realTypeof = typeof
	local env
	local function loadServer(name: string)
		if loaded[name] ~= nil then
			return loaded[name]
		end
		local path = "src/ServerScriptService/ShardfallServer/" .. name .. ".luau"
		local chunk = luau.load(luau.compile(fs.readFile(path)), {
			debugName = name,
			environment = env,
		})
		local previous = env.script
		env.script = { Name = name, ClassName = "ModuleScript", Parent = server }
		local result = chunk()
		env.script = previous
		loaded[name] = result
		return result
	end

	env = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		xpcall = xpcall,
		print = function() end,
		select = select,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		warn = function() end,
		math = math,
		string = string,
		table = table,
		os = os,
		debug = debug,
		coroutine = coroutine,
		task = {
			spawn = function(fn)
				local co = coroutine.create(fn)
				local ok, err = coroutine.resume(co)
				if not ok then
					error(tostring(err), 0)
				end
			end,
			defer = function(fn)
				local co = coroutine.create(fn)
				local ok, err = coroutine.resume(co)
				if not ok then
					error(tostring(err), 0)
				end
			end,
			delay = function(_seconds, fn)
				coroutine.resume(coroutine.create(fn))
			end,
			wait = function()
				coroutine.yield()
			end,
		},
		Random = {
			new = function()
				return {
					NextNumber = function()
						return 0.99
					end,
					NextInteger = function(_self, minimum, _maximum)
						return minimum
					end,
				}
			end,
		},
		game = game,
		script = { Name = "boot", Parent = server, ClassName = "ModuleScript" },
		typeof = function(value)
			if type(value) == "table" and value.ClassName == "Player" then
				return "Instance"
			end
			return realTypeof(value)
		end,
		require = function(mod)
			if type(mod) ~= "table" then
				error("require " .. tostring(mod), 0)
			end
			if mod.__shared == true then
				local found = shared[mod.Name]
				if found == nil then
					error("missing shared " .. tostring(mod.Name), 0)
				end
				return found
			end
			if mod.__server == true then
				return loadServer(mod.Name)
			end
			error("bad require " .. tostring(mod.Name), 0)
		end,
	}

	loaded.StoreAdapter = {
		connect = function()
			return adapter, nil
		end,
	}
	loaded.PolicyCache = {
		allowPaid = function()
			return false, "closed", "closed"
		end,
		public = function()
			return { ready = false }
		end,
	}

	for _, spec in ipairs(list) do
		table.insert(players, makePlayer(spec.name, spec.id, services.Players))
	end

	local data = loadServer("DataService")
	data.start()
	if closing == nil then
		error("DataService.start did not bind close", 0)
	end

	local world = {
		data = data,
		players = players,
		close = closing,
		load = loadServer,
	}
	function world.read(key: string)
		local seen = nil
		inner:updateAsync(key, function(current)
			seen = current
			return nil
		end)
		return seen
	end
	function world.drop(player)
		for index, candidate in ipairs(players) do
			if candidate == player then
				table.remove(players, index)
				break
			end
		end
		player.Parent = nil
	end
	return world
end

local function lockStatus(document): string
	if type(document) ~= "table" then
		return "missing"
	end
	return SessionLock.status(document.Lock, os.time(), JOB, SessionLock.TIMEOUT_SECONDS)
end

local function sword(uid: string): any
	return {
		uid = uid,
		templateId = "iron_sword",
		name = "Iron Sword",
		kind = "Weapon",
		rarity = "Common",
		traits = {},
		poolId = "dev",
		obtainedAt = 1,
		locked = false,
		stats = { { id = "damage", value = 12 } },
	}
end

local function withSalvage(fn: () -> ())
	local previous = LaunchGate.SHOW.gearSalvage
	LaunchGate.SHOW.gearSalvage = true
	GearSalvage._reset()
	local ok, err = pcall(fn)
	LaunchGate.SHOW.gearSalvage = previous
	GearSalvage._reset()
	if not ok then
		error(err, 0)
	end
end

local function equipCtx(gearOn: boolean): any
	return {
		slots = EquipSlots,
		stats = EquipStats,
		elements = Elements,
		classes = Classes,
		gearConfig = GearLevels,
		gearEnabled = gearOn,
	}
end

describe("Launch safety", function()
	it("saves and releases every loaded profile on shutdown", function()
		local world = boot({
			{ name = "A", id = 1 },
			{ name = "B", id = 2 },
			{ name = "C", id = 3 },
		})
		local golds = { 11, 22, 33 }
		for index, gold in ipairs(golds) do
			local player = world.players[index]
			expect(world.data.get(player) ~= nil).toBeTrue()
			expect(world.data.get(player).schemaVersion).toEqual(26)
			local ok, err = world.data.mutate(player, function(data)
				data.gold = gold
				return nil
			end)
			expect(ok).toEqual(true)
			expect(err).toBeNil()
			-- The claim wrote the template. The mutate is only in memory
			-- until shutdown.
			expect(world.read("Player_" .. tostring(index)).Data.gold).toEqual(0)
		end

		local dropped = world.players[3]
		world.drop(dropped)
		expect(#world.players).toEqual(2)
		expect(world.data.get(dropped).gold).toEqual(33)

		world.close()

		for index, gold in ipairs(golds) do
			local stored = world.read("Player_" .. tostring(index))
			expect(stored.Data.gold).toEqual(gold)
			expect(stored.Data.schemaVersion).toEqual(26)
			expect(lockStatus(stored)).toEqual("free")
			expect(stored.Lock.jobId).toEqual("")
		end
		expect(world.data.get(world.players[1])).toBeNil()
		expect(world.data.get(world.players[2])).toBeNil()
		expect(world.data.get(dropped)).toBeNil()
	end)

	it("releases an ephemeral profile without writing over the stored save", function()
		local world = boot({
			{ name = "Live", id = 8 },
			{ name = "Memory", id = 9 },
		}, {
			studio = true,
			denyKey = "Player_9",
			seed = {
				Player_9 = {
					Data = { gold = 999, schemaVersion = 26 },
					Lock = SessionLock.claim(os.time(), "other-server", 7),
				},
			},
		})
		local live = world.players[1]
		local memory = world.players[2]
		expect(world.data.get(live) ~= nil).toBeTrue()
		expect(world.data.get(memory) ~= nil).toBeTrue()
		expect(live.kicked).toBeNil()
		expect(memory.kicked).toBeNil()
		local ok, err = world.data.mutate(live, function(data)
			data.gold = 44
			return nil
		end)
		expect(ok).toEqual(true)
		expect(err).toBeNil()
		expect(world.read("Player_9").Data.gold).toEqual(999)

		world.close()

		local saved = world.read("Player_8")
		expect(saved.Data.gold).toEqual(44)
		expect(saved.Data.schemaVersion).toEqual(26)
		expect(lockStatus(saved)).toEqual("free")
		local kept = world.read("Player_9")
		expect(kept.Data.gold).toEqual(999)
		expect(kept.Data.schemaVersion).toEqual(26)
		expect(kept.Lock.jobId).toEqual("other-server")
		expect(world.data.get(live)).toBeNil()
		expect(world.data.get(memory)).toBeNil()
	end)

	it("does not grant or spend twice when roll is invoked twice", function()
		local world = boot({
			{ name = "Free", id = 11 },
			{ name = "Batch", id = 12 },
			{ name = "Singles", id = 13 },
		})
		local rolls = world.load("RollService")

		local free = world.players[1]
		local first = rolls.rollFree(free, POOL, false)
		local second = rolls.rollFree(free, POOL, false)
		local freeData = world.data.get(free)
		expect(first.ok).toEqual(true)
		expect(second.ok).toEqual(false)
		expect(second.error).toEqual("Roll cooling down.")
		expect(freeData.shardTokens).toEqual(Schema.STARTER_TOKENS - 1)
		expect(Schema.countItems(freeData)).toEqual(1)

		local batch = world.players[2]
		local funded, fundErr = world.data.mutate(batch, function(data)
			data.shardTokens = 30
			return nil
		end)
		expect(funded).toEqual(true)
		expect(fundErr).toBeNil()
		local ten = rolls.rollMany(batch, POOL, 10)
		local tenAgain = rolls.rollMany(batch, POOL, 10)
		local batchData = world.data.get(batch)
		expect(ten.ok).toEqual(true)
		expect(ten.count).toEqual(10)
		expect(tenAgain.ok).toEqual(false)
		expect(tenAgain.error).toEqual("Roll cooling down.")
		expect(batchData.shardTokens).toEqual(21)
		expect(Schema.countItems(batchData)).toEqual(10)

		local singles = world.players[3]
		local one = rolls.rollMany(singles, POOL, 1)
		local oneAgain = rolls.rollMany(singles, POOL, 1)
		local singleData = world.data.get(singles)
		expect(one.ok).toEqual(true)
		expect(one.count).toEqual(1)
		expect(oneAgain.ok).toEqual(false)
		expect(oneAgain.error).toEqual("Roll cooling down.")
		expect(singleData.shardTokens).toEqual(Schema.STARTER_TOKENS - 1)
		expect(Schema.countItems(singleData)).toEqual(1)
	end)

	it("rejects roll, salvage, and equip that start during an open mutate", function()
		withSalvage(function()
			local world = boot({ { name = "Race", id = 21 } })
			local player = world.players[1]
			local rolls = world.load("RollService")
			local salvage = world.load("GearSalvageService")
			local inventory = world.load("InventoryService")
			local ready, readyErr = world.data.mutate(player, function(data)
				data.shardTokens = 30
				data.gold = 80
				data.gearEssence = 0
				Schema.insertItem(data, sword("blade"))
				return nil
			end)
			expect(ready).toEqual(true)
			expect(readyErr).toBeNil()
			local looked = salvage.nudge(player, "Common")
			expect(looked.ok).toEqual(true)

			local nested = {}
			local thread = coroutine.create(function()
				return world.data.mutate(player, function(data)
					data.shardTokens -= 1
					coroutine.yield()
					return "nope"
				end)
			end)
			local started, paused = coroutine.resume(thread)
			expect(started).toEqual(true)
			expect(paused).toBeNil()
			expect(coroutine.status(thread)).toEqual("suspended")

			nested.roll = rolls.rollMany(player, POOL, 10)
			nested.salvage = salvage.salvageNow(player, looked.token)
			local equipped, equipErr = inventory.equip(player, "blade")
			nested.equipped = equipped
			nested.equipErr = equipErr

			local resumed, saved, saveErr = coroutine.resume(thread)
			expect(resumed).toEqual(true)
			expect(saved).toEqual(false)
			expect(saveErr).toEqual("nope")

			expect(nested.roll.ok).toEqual(false)
			expect(nested.roll.error).toEqual("Profile is busy.")
			expect(nested.salvage.ok).toEqual(false)
			expect(nested.salvage.error).toEqual("Profile is busy.")
			expect(nested.equipped).toEqual(false)
			expect(nested.equipErr).toEqual("Profile is busy.")

			local data = world.data.get(player)
			expect(data.shardTokens).toEqual(30)
			expect(data.gold).toEqual(80)
			expect(data.gearEssence).toEqual(0)
			expect(data.inventory.blade ~= nil).toBeTrue()
			expect(data.equipped.weapon).toBeNil()
			expect(Schema.countItems(data)).toEqual(1)
		end)
	end)

	it("pays salvage once when the same confirm runs twice", function()
		withSalvage(function()
			local world = boot({ { name = "Salvage", id = 31 } })
			local player = world.players[1]
			local salvage = world.load("GearSalvageService")
			local ready, readyErr = world.data.mutate(player, function(data)
				data.gold = 15
				data.gearEssence = 0
				Schema.insertItem(data, sword("blade"))
				return nil
			end)
			expect(ready).toEqual(true)
			expect(readyErr).toBeNil()
			local looked = salvage.nudge(player, "Common")
			expect(looked.ok).toEqual(true)
			expect(world.data.get(player).inventory.blade ~= nil).toBeTrue()

			local done = salvage.salvageNow(player, looked.token)
			local again = salvage.salvageNow(player, looked.token)
			local data = world.data.get(player)
			expect(done.ok).toEqual(true)
			expect(done.gained).toEqual(1)
			expect(again.ok).toEqual(false)
			expect(data.gearEssence).toEqual(1)
			expect(data.gold).toEqual(15)
			expect(data.inventory.blade).toBeNil()
			expect(Schema.countItems(data)).toEqual(0)
		end)
	end)

	it("keeps one copy when the same weapon is equipped twice", function()
		local world = boot({ { name = "Equip", id = 41 } })
		local player = world.players[1]
		local inventory = world.load("InventoryService")
		local ready, readyErr = world.data.mutate(player, function(data)
			data.gold = 80
			data.shardTokens = 4
			Schema.insertItem(data, sword("blade"))
			return nil
		end)
		expect(ready).toEqual(true)
		expect(readyErr).toBeNil()

		local first, firstErr = inventory.equip(player, "blade")
		local second, secondErr = inventory.equip(player, "blade")
		local data = world.data.get(player)
		expect(first).toEqual(true)
		expect(firstErr).toBeNil()
		expect(second).toEqual(true)
		expect(secondErr).toBeNil()
		expect(data.equipped.weapon).toEqual("blade")
		expect(data.inventory.blade.uid).toEqual("blade")
		expect(Schema.countItems(data)).toEqual(1)
		expect(data.gold).toEqual(80)
		expect(data.shardTokens).toEqual(4)
	end)

	it("does not clone a piece or spend gold when phase-2 equip runs twice", function()
		local data = {
			gold = 80,
			shardTokens = 4,
			inventory = {},
			pets = {},
			equipped = { weapon = nil, pet = nil, armor = {}, accessories = {} },
			classId = "warden",
			classXp = { warden = 0 },
		}
		local item = sword("w1")
		data.inventory.w1 = item
		local ctx = equipCtx(false)
		local ok, reason = EquipService.equip(data, "weapon", "w1", ctx)
		local again, againReason = EquipService.equip(data, "weapon", "w1", ctx)
		expect(ok).toEqual(true)
		expect(reason).toBeNil()
		expect(again).toEqual(true)
		expect(againReason).toBeNil()
		expect(data.equipLoadout.weapon).toEqual("w1")
		expect(data.inventory.w1).toEqual(item)
		expect(Schema.countItems(data)).toEqual(1)
		expect(data.gold).toEqual(80)
		expect(data.shardTokens).toEqual(4)
		expect(data.equipped.weapon).toBeNil()
	end)

	it("leaves schema 26 and every launch flag off", function()
		expect(Schema.VERSION).toEqual(26)
		local flags = 0
		for id, on in pairs(LaunchGate.SHOW) do
			flags += 1
			expect(on).toEqual(false)
			expect(LaunchGate.on(id)).toEqual(false)
		end
		expect(flags > 0).toBeTrue()
	end)
end)
