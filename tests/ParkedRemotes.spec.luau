--!strict

--[[
	T-244. Every parked remote and its server handler refuses while the
	launch gates are off, and the profile snapshot does not change.
	A remote named in Remotes.luau that is neither an M1 action nor a
	parked action fails this file.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local RateLimiter = require("../src/ServerScriptService/ShardfallServer/RateLimiter")
local RemoteCaller = require("../src/ReplicatedStorage/Shared/RemoteCaller")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

-- Incoming actions the M1 loop is allowed to call. Server pushes are not
-- player actions, but they are still remotes named in Remotes.luau.
local M1_ALLOWED = {
	GetProfile = true,
	GetOdds = true,
	RollShard = true,
	RollShards = true,
	OpenChest = true,
	ChooseChest = true,
	MergeChest = true,
	BuyChest = true,
	ClaimLogin = true,
	EquipItem = true,
	UnequipItem = true,
	RemoveItem = true,
	Debug = true,
	DevGrant = true,
	Dungeon = true,
	Craft = true,
	BuyGoldShop = true,
	Travel = true,
	SetShake = true,
	SetAudio = true,
	SetSettings = true,
	SetGraphicsQuality = true,
	SetItemLock = true,
	SetItemFavorite = true,
	FeedItem = true,
	SetAutoFarm = true,
	SetAutoAttack = true,
	UseTonic = true,
	SetActionBar = true,
	UseActionSlot = true,
	Attack = true,
	Dodge = true,
	Steer = true,
	HatchPet = true,
	PetCare = true,
	PaintPet = true,
	FavoritePet = true,
	Loops = true,
	RerollDaily = true,
	UpgradeGear = true,
	Onboard = true,
	SetClass = true,
	PickTalent = true,
	UseSkill = true,
	PolicyUpdated = true,
	ProfileUpdated = true,
}

local SERVICE_CALLS = {
	{ "CraftService", "salvage", { "piece-1" } },
	{ "CraftService", "salvageRarity", { "Common" } },
	{ "PetService", "fuse", { "pet-a", "pet-b" } },
	{ "TradeService", "handle", { "commit", {} } },
	{ "MarketService", "handle", { "buy", { id = 1 } } },
	{ "LoopService", "claim", {} },
	{ "LoopService", "premium", {} },
	{ "LoopService", "claimPremium", {} },
	{ "ChestService", "setOptions", { "dust", "Common" } },
	{ "ChestService", "buyBundle", {} },
	{ "ChestService", "buyDust", { "briar_edge" } },
	{ "TravelService", "buyPass", {} },
	{ "RollService", "rollPaid", { "verdant", true } },
	{ "RollService", "buyPrismPack", {} },
	{ "RollService", "buyLuckBoost", {} },
	{ "RollService", "buyForgeBoost", {} },
	{ "RollService", "buyInventoryExpansion", {} },
	{ "RaidService", "queue", { "story", "flex" } },
	{ "RaidService", "post", { "Learning", "story" } },
	{ "RaidService", "join", { 1 } },
	{ "RaidService", "practice", { 1, 1 } },
	{ "RaidService", "buy", { "student" } },
	{ "RaidService", "leave", {} },
	{ "RaidService", "ready", {} },
	{ "DungeonService", "startDailyBoss", {} },
}

local function namesIn(source: string, kind: string): { string }
	local found = {}
	local seen = {}
	for name in string.gmatch(source, kind .. '%("([%w]+)"%)') do
		if seen[name] ~= true then
			seen[name] = true
			table.insert(found, name)
		end
	end
	return found
end

local function parkedMap(source: string): { [string]: string }
	local from = string.find(source, "local PARKED_ACTION", 1, true)
	local to = string.find(source, "local function guard", from or 1, true)
	expect(from ~= nil and to ~= nil).toBeTrue()
	local body = string.sub(source, from :: number, (to :: number) - 1)
	local map = {}
	for name, flag in string.gmatch(body, '([%w]+)%s*=%s*"([%w]+)"') do
		map[name] = flag
	end
	return map
end

local function makeNode(className: string, name: string)
	local node = {
		ClassName = className,
		Name = name,
		Parent = nil,
		children = {},
		OnServerInvoke = nil,
		OnServerEvent = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
	}
	local function findChild(childName: string)
		for _, child in ipairs(node.children) do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end
	function node:IsA(kind: string): boolean
		return kind == self.ClassName
			or kind == "Instance"
			or (self.ClassName == "RemoteFunction" and (kind == "RemoteFunction" or kind == "RemoteEvent"))
	end
	function node:FindFirstChild(childName: string)
		return findChild(childName)
	end
	function node:WaitForChild(childName: string, _timeout: number?)
		local found = findChild(childName)
		if found ~= nil then
			return found
		end
		local className = if childName == "Remotes" or childName == "Shared" then "Folder" else "RemoteFunction"
		local created = makeNode(className, childName)
		created.Parent = self
		table.insert(self.children, created)
		return created
	end
	return setmetatable(node, {
		__index = function(self, key)
			if type(key) ~= "string" then
				return nil
			end
			local found = findChild(key)
			if found ~= nil then
				return found
			end
			local created = makeNode("ModuleScript", key)
			created.Parent = self
			table.insert(self.children, created)
			return created
		end,
	})
end

local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
end

local function blankService()
	return setmetatable({}, {
		__index = function()
			return function()
				return nil
			end
		end,
	})
end

-- Load-time calls that are not the parked handler. The handler itself
-- returns before any of these stubs are used.
local function dependency(name: string, real)
	if real[name] ~= nil then
		return real[name]
	end
	if name == "CombatService" then
		return {
			bindEcho = function() end,
		}
	end
	if name == "MarketBoard" then
		return {
			new = function()
				return {}
			end,
		}
	end
	if name == "Dungeons" then
		return { ENEMY_SPAWNS = {} }
	end
	return {}
end

local function loadModule(path: string, scriptName: string, dataService, playerFolder, recorded)
	local realTypeof = typeof
	local replicated = makeNode("ReplicatedStorage", "ReplicatedStorage")
	if recorded ~= nil then
		local plainWait = replicated.WaitForChild
		function replicated:WaitForChild(childName: string, timeout: number?)
			local child = plainWait(self, childName, timeout)
			if childName == "Remotes" then
				local plainChild = child.WaitForChild
				function child:WaitForChild(name: string, childTimeout: number?)
					local remote = plainChild(self, name, childTimeout)
					recorded[name] = remote
					return remote
				end
			end
			return child
		end
	end
	local server = playerFolder or makeNode("Folder", "ShardfallServer")
	local script = makeNode("ModuleScript", scriptName)
	script.Parent = server
	table.insert(server.children, script)
	local players = {
		PlayerRemoving = signal(),
		PlayerAdded = signal(),
		GetPlayers = function()
			return {}
		end,
	}
	local services = {
		ReplicatedStorage = replicated,
		Players = players,
		RunService = { Heartbeat = signal() },
	}
	local game = {
		JobId = "",
		PlaceId = 0,
		PrivateServerId = "",
		PrivateServerOwnerId = 0,
	}
	function game:GetService(name: string)
		local found = services[name]
		if found == nil then
			found = blankService()
			services[name] = found
		end
		return found
	end
	local real = {
		LaunchGate = LaunchGate,
		RateLimiter = RateLimiter,
		RemoteCaller = RemoteCaller,
		DataService = dataService,
	}
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
		os = os,
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
						return 0
					end,
					NextInteger = function()
						return 1
					end,
				}
			end,
		},
		game = game,
		script = script,
		typeof = function(value)
			if type(value) == "table" and value.ClassName == "Player" then
				return "Instance"
			end
			return realTypeof(value)
		end,
		require = function(module)
			local name = if type(module) == "table" then module.Name else ""
			return dependency(name, real)
		end,
	}
	local source = fs.readFile(path)
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = scriptName,
		environment = environment,
	})
	return chunk(), server
end

describe("Parked remotes", function()
	it("names every remote as an M1 action or a parked action", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local parked = parkedMap(source)
		local seen = {}
		for _, kind in ipairs({ "functionRemote", "eventRemote" }) do
			for _, name in ipairs(namesIn(source, kind)) do
				seen[name] = true
				local allowed = M1_ALLOWED[name] == true
				local closed = parked[name] ~= nil
				if allowed == closed then
					error(name .. " must be an M1 action or a parked action, not both and not neither", 0)
				end
				if closed then
					expect(LaunchGate.on(parked[name])).toEqual(false)
				end
			end
		end
		for name in pairs(parked) do
			if seen[name] ~= true then
				error(name .. " is parked but Remotes.luau does not bind it", 0)
			end
		end
	end)

	it("refuses every parked remote and server handler without writing the profile", function()
		for flag in pairs(LaunchGate.SHOW) do
			expect(LaunchGate.on(flag)).toEqual(false)
		end
		local fresh = Schema.migrate(nil)
		assert(fresh ~= nil)
		local profile = Schema.deepCopy(fresh)
		local before = Schema.deepCopy(profile)
		local writes = 0
		local dataService = {
			mutate = function(_player, callback)
				writes += 1
				local reason = callback(profile)
				if type(reason) == "string" then
					return false, reason
				end
				return true, nil
			end,
			get = function()
				return profile
			end,
			snapshot = function()
				return Schema.deepCopy(profile)
			end,
			isPersistent = function()
				return false
			end,
			onChanged = function() end,
		}
		local player = {
			ClassName = "Player",
			Name = "M1",
			UserId = 42,
			Parent = {},
		}
		function player:IsA(kind: string): boolean
			return kind == "Player" or kind == "Instance"
		end

		local source = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local parked = parkedMap(source)
		local recorded = {}
		local remotes = loadModule(
			"src/ServerScriptService/ShardfallServer/Remotes.luau",
			"Remotes",
			dataService,
			nil,
			recorded
		)
		remotes.bind()
		local invoked = 0
		local parkedCount = 0
		for name in pairs(parked) do
			parkedCount += 1
			local remote = recorded[name]
			if remote == nil or type(remote.OnServerInvoke) ~= "function" then
				error(name .. " did not bind a handler", 0)
			end
			local shot = Schema.deepCopy(profile)
			local result = remote.OnServerInvoke(player, "story", "flex", true)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual("That is closed.")
			expect(Schema.deepCopy(profile)).toEqual(shot)
			invoked += 1
		end
		expect(invoked).toEqual(parkedCount)
		expect(parkedCount > 0).toBeTrue()

		for _, row in ipairs(SERVICE_CALLS) do
			local fileName = row[1]
			local method = row[2]
			local args = row[3]
			local service = loadModule(
				"src/ServerScriptService/ShardfallServer/" .. fileName .. ".luau",
				fileName,
				dataService,
				nil
			)
			local shot = Schema.deepCopy(profile)
			local result
			if method == "premium" then
				result = service.premium()
			else
				result = service[method](player, args[1], args[2], args[3])
			end
			if type(result) ~= "table" or result.error ~= "That is closed." then
				error(fileName .. "." .. method .. " did not refuse", 0)
			end
			expect(result.ok).toEqual(false)
			expect(Schema.deepCopy(profile)).toEqual(shot)
		end

		expect(writes).toEqual(0)
		expect(Schema.deepCopy(profile)).toEqual(before)
	end)
end)
