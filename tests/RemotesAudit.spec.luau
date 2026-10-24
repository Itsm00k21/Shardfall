--!strict

--[[
	Phase 0.7 remotes audit. Loads the real Remotes.luau with recording
	stub services, then calls the handlers that gained a check:

	  - NaN and inf numbers stop at the remote (OpenChest, ChooseChest,
	    RerollDaily, UseSkill, UseActionSlot).
	  - UpgradeGear, PaintPet and FavoritePet check ids and sizes.
	  - PetCare is parked (LaunchGate.petCare, Oct 22) and refuses first.
	  - Dungeon("enter", "heartwood") is closed while raids is parked.

	Valid input still reaches the same service call with the same args.
	See docs/qa/remotes_audit.md.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local RemoteCaller = require("../src/ReplicatedStorage/Shared/RemoteCaller")

local NAN = 0 / 0
local INF = math.huge
local GUID = "0F3C9A1E-5B7D-4C2A-9E11-ABCDEF012345"

local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
end

local function makeNode(className: string, name: string): any
	local node: any = { ClassName = className, Name = name, children = {} }
	function node:IsA(kind: string): boolean
		return kind == self.ClassName or kind == "Instance"
	end
	function node:WaitForChild(childName: string, _timeout: number?)
		local found = self.children[childName]
		if found == nil then
			local kind = if childName == "Remotes" then "Folder" else "RemoteFunction"
			if childName == "Attack" or childName == "Dodge" or childName == "Steer" then
				kind = "RemoteEvent"
			end
			found = makeNode(kind, childName)
			found.OnServerEvent = signal()
			self.children[childName] = found
		end
		return found
	end
	function node:FindFirstChild(childName: string)
		return self.children[childName]
	end
	return setmetatable(node, {
		__index = function(_self, key)
			if type(key) ~= "string" then
				return nil
			end
			return makeNode("ModuleScript", key)
		end,
	})
end

type Call = { service: string, method: string, args: { any } }

local function load()
	local calls: { Call } = {}
	local function recorder(serviceName: string)
		return setmetatable({}, {
			__index = function(_self, method)
				return function(...)
					-- respond() reads these on every reply; they are not the handler's service.
					if serviceName ~= "DataService" and serviceName ~= "PolicyCache" then
						table.insert(
							calls,
							{ service = serviceName, method = method, args = { ... } }
						)
					end
					return { ok = true }
				end
			end,
		})
	end
	local real = {
		LaunchGate = LaunchGate,
		RemoteCaller = RemoteCaller,
		RateLimiter = {
			take = function()
				return true
			end,
			forget = function() end,
		},
	}
	local replicated = makeNode("ReplicatedStorage", "ReplicatedStorage")
	local services = {
		ReplicatedStorage = replicated,
		Players = { PlayerRemoving = signal(), PlayerAdded = signal() },
	}
	local game = {}
	function game:GetService(name: string)
		return services[name] or {}
	end
	local server = makeNode("Folder", "ShardfallServer")
	local script = makeNode("ModuleScript", "Remotes")
	script.Parent = server
	local realTypeof = typeof
	local environment = {
		assert = assert,
		error = error,
		ipairs = ipairs,
		pairs = pairs,
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		warn = function() end,
		math = math,
		string = string,
		table = table,
		os = os,
		debug = debug,
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
			if real[name] ~= nil then
				return real[name]
			end
			return recorder(name)
		end,
	}
	local source = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
	local chunk = luau.load(luau.compile(source, { debugLevel = 2 }), {
		debugName = "Remotes",
		environment = environment,
	})
	local remotes = chunk()
	remotes.bind()
	local folder = replicated:WaitForChild("Remotes")
	local player: any = { ClassName = "Player", Name = "Audit", UserId = 77, Parent = {} }
	function player:IsA(kind: string): boolean
		return kind == "Player" or kind == "Instance"
	end
	local function invoke(name: string, ...)
		local remote = folder.children[name]
		assert(remote ~= nil and type(remote.OnServerInvoke) == "function", name .. " is not bound")
		local before = #calls
		local result = remote.OnServerInvoke(player, ...)
		local reached = if #calls > before then calls[#calls] else nil
		return result, reached
	end
	return invoke
end

local function refused(invoke, name: string, message: string, ...)
	local result, reached = invoke(name, ...)
	if result.ok ~= false or result.error ~= message or reached ~= nil then
		error(
			string.format(
				"%s should refuse with %q before the service; got ok=%s error=%s reached=%s",
				name,
				message,
				tostring(result.ok),
				tostring(result.error),
				if reached ~= nil then reached.service .. "." .. reached.method else "nil"
			),
			0
		)
	end
end

local function passes(invoke, name: string, service: string, method: string, ...): { any }
	local result, reached = invoke(name, ...)
	if reached == nil or reached.service ~= service or reached.method ~= method then
		error(
			string.format(
				"%s should reach %s.%s; got ok=%s error=%s",
				name,
				service,
				method,
				tostring(result.ok),
				tostring(result.error)
			),
			0
		)
	end
	expect(result.ok).toEqual(true)
	return reached.args
end

describe("Remotes audit (Phase 0.7)", function()
	it("stops NaN and inf numbers at the remote", function()
		local invoke = load()
		for _, bad in ipairs({ NAN, INF, -INF }) do
			refused(invoke, "OpenChest", "Pick how many chests to open.", "Common", bad)
			refused(invoke, "ChooseChest", "Pick one of the three cards.", bad)
			refused(invoke, "RerollDaily", "Pick a daily.", bad)
			refused(invoke, "UseSkill", "That skill slot is empty.", bad)
			refused(invoke, "UseActionSlot", "That slot is empty.", bad)
		end
		refused(invoke, "ChooseChest", "Pick one of the three cards.", "1")
		refused(invoke, "RerollDaily", "Pick a daily.", nil)
		refused(invoke, "UseActionSlot", "That slot is empty.", { 1 })
	end)

	it("passes valid numbers through unchanged", function()
		local invoke = load()
		local args = passes(invoke, "OpenChest", "ChestService", "open", "Common", 3)
		expect(args[2]).toEqual("Common")
		expect(args[3]).toEqual(3)
		args = passes(invoke, "OpenChest", "ChestService", "open", "Rare", nil)
		expect(args[3]).toBeNil()
		args = passes(invoke, "ChooseChest", "ChestService", "choose", 2)
		expect(args[2]).toEqual(2)
		args = passes(invoke, "RerollDaily", "LoopService", "reroll", 3)
		expect(args[2]).toEqual(3)
		args = passes(invoke, "UseSkill", "ClassService", "cast", 1)
		expect(args[2]).toEqual(1)
		args = passes(invoke, "UseSkill", "ClassService", "cast", "ult")
		expect(args[2]).toEqual("ult")
		args = passes(invoke, "UseActionSlot", "ActionBarService", "use", 8)
		expect(args[2]).toEqual(8)
	end)

	it("checks gear and companion ids and pet colors", function()
		local invoke = load()
		local huge = string.rep("x", 4096)
		for _, bad in ipairs({ nil, 5, "", huge, "a b", { GUID } } :: { any }) do
			refused(invoke, "UpgradeGear", "Pick a piece of gear.", bad)
		end
		passes(invoke, "UpgradeGear", "CraftService", "upgrade", GUID)

		refused(invoke, "PetCare", "That is closed.", huge, "pet")
		refused(invoke, "PetCare", "That is closed.", GUID, "feed")

		refused(invoke, "FavoritePet", "Pick a companion.", "", true)
		passes(invoke, "FavoritePet", "PetService", "favorite", GUID, true)

		refused(invoke, "PaintPet", "Pick a color.", GUID, huge)
		refused(invoke, "PaintPet", "Pick a color.", GUID, "red;drop")
		refused(invoke, "PaintPet", "Pick a color.", GUID, 3)
		refused(invoke, "PaintPet", "Pick a color.", GUID, "verdant", string.rep("s", 33))
		refused(invoke, "PaintPet", "Pick a color.", GUID, "verdant", "sap", "glow!")
		refused(invoke, "PaintPet", "Pick a color.", huge, "verdant")
		local args =
			passes(invoke, "PaintPet", "PetService", "paint", GUID, "verdant", "sap", "none")
		expect(args[3]).toEqual("verdant")
		expect(args[4]).toEqual("sap")
		expect(args[5]).toEqual("none")
		args = passes(invoke, "PaintPet", "PetService", "paint", GUID, "slate", nil, nil)
		expect(args[4]).toBeNil()
	end)

	it("closes Dungeon enter for the parked raid only", function()
		expect(LaunchGate.on("raids")).toEqual(false)
		local invoke = load()
		refused(invoke, "Dungeon", "That is closed.", "enter", "heartwood", "story")
		passes(invoke, "Dungeon", "DungeonService", "action", "enter", "rootvault", "normal")
		passes(invoke, "Dungeon", "DungeonService", "action", "enter", nil, nil)
		passes(invoke, "Dungeon", "DungeonService", "action", "enter", "rootvault_waves", nil)
		passes(invoke, "Dungeon", "DungeonService", "action", "leave")
		-- A door id of "heartwood" is not an enter; the door check owns it.
		passes(invoke, "Dungeon", "DungeonService", "action", "door", "heartwood")
	end)

	it("LaunchGate.dungeonOpen follows the raids switch", function()
		expect(LaunchGate.dungeonOpen("heartwood")).toEqual(false)
		expect(LaunchGate.dungeonOpen("rootvault")).toEqual(true)
		expect(LaunchGate.dungeonOpen(nil)).toEqual(true)
		expect(LaunchGate.dungeonOpen(12)).toEqual(true)
		LaunchGate.SHOW.raids = true
		local opened = LaunchGate.dungeonOpen("heartwood")
		LaunchGate.SHOW.raids = false
		expect(opened).toEqual(true)
	end)
end)
