--!strict

--[[
	Runs HavenBuilder.build outside Studio.

	Roblox rejects a script write to Workspace.StreamingEnabled. The mock
	does the same, so this fails if the builder starts doing that again.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")

type Mock = any

local function enumNode(path: string): Mock
	return setmetatable({ __enum = path }, {
		__index = function(self, key)
			local child = enumNode(path .. "." .. tostring(key))
			rawset(self, key, child)
			return child
		end,
	})
end

local function cframe(): Mock
	return setmetatable({
		Position = { X = 0, Y = 0, Z = 0 },
	}, {
		__mul = function()
			return cframe()
		end,
	})
end

local function vector3(x: number?, y: number?, z: number?): Mock
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local BASE_PART = {
	Part = true,
	SpawnLocation = true,
}

local function instance(className: string): Mock
	local object = {
		ClassName = className,
		Name = className,
		children = {},
		attributes = {},
	}
	local methods = {}

	function methods:SetAttribute(key: string, value: any)
		self.attributes[key] = value
	end

	function methods:GetAttribute(key: string): any
		return self.attributes[key]
	end

	function methods:IsA(class: string): boolean
		if class == "Instance" or class == self.ClassName then
			return true
		end
		if class == "BasePart" and BASE_PART[self.ClassName] == true then
			return true
		end
		return false
	end

	function methods:GetDescendants(): { Mock }
		local list = {}
		local function walk(node: Mock)
			for _, child in ipairs(node.children) do
				table.insert(list, child)
				walk(child)
			end
		end
		walk(self)
		return list
	end

	function methods:FindFirstChild(name: string): Mock?
		for _, child in ipairs(self.children) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end

	function methods:Destroy()
		self.Parent = nil
	end

	return setmetatable(object, {
		__index = function(self, key)
			local method = methods[key]
			if method ~= nil then
				return method
			end
			for _, child in ipairs(self.children) do
				if child.Name == key then
					return child
				end
			end
			return nil
		end,
		__newindex = function(self, key, value)
			if
				key == "StreamingEnabled"
				or key == "StreamingMinRadius"
				or key == "StreamingTargetRadius"
			then
				error(
					"The current thread cannot write '" .. key .. "' (lacking capability Plugin)",
					2
				)
			end
			if key == "Parent" then
				local previous = rawget(self, "Parent")
				if previous ~= nil then
					for index, child in ipairs(previous.children) do
						if child == self then
							table.remove(previous.children, index)
							break
						end
					end
				end
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

local function findNamed(root: Mock, name: string): Mock?
	if root.Name == name then
		return root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function loadBuilder(): (Mock, { Mock }, Mock)
	local heartbeats = {}
	local workspace = instance("Workspace")
	rawset(workspace, "StreamingEnabled", true)
	rawset(workspace, "StreamingMinRadius", 128)
	rawset(workspace, "StreamingTargetRadius", 512)

	local replicated = instance("ReplicatedStorage")
	local shared = instance("Folder")
	shared.Name = "Shared"
	shared.Parent = replicated
	local dungeonModule = instance("ModuleScript")
	dungeonModule.Name = "Dungeons"
	dungeonModule.Parent = shared
	local havenModule = instance("ModuleScript")
	havenModule.Name = "Haven"
	havenModule.Parent = shared

	local runService = {
		Heartbeat = {
			Connect = function(_heartbeat, callback)
				local connection = {
					Connected = true,
					callback = callback,
				}
				function connection:Disconnect()
					self.Connected = false
				end
				table.insert(heartbeats, connection)
				return connection
			end,
		},
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
		workspace = workspace,
		Enum = enumNode("Enum"),
		Color3 = {
			fromRGB = function(red, green, blue)
				return { R = red, G = green, B = blue }
			end,
		},
		Vector3 = { new = vector3 },
		CFrame = {
			new = function()
				return cframe()
			end,
			Angles = function()
				return cframe()
			end,
			lookAt = function()
				return cframe()
			end,
		},
		UDim2 = {
			fromOffset = function(x, y)
				return { X = x, Y = y }
			end,
			fromScale = function(x, y)
				return { X = x, Y = y }
			end,
		},
		Instance = { new = instance },
		game = {
			GetService = function(_game, name)
				if name == "ReplicatedStorage" then
					return replicated
				end
				if name == "RunService" then
					return runService
				end
				if name == "Workspace" then
					return workspace
				end
				error("no service " .. tostring(name), 2)
			end,
		},
		require = function(module)
			if module == dungeonModule then
				return Dungeons
			end
			if module == havenModule then
				return Haven
			end
			error("unexpected require", 2)
		end,
	}

	local source = fs.readFile("src/ServerScriptService/ShardfallServer/HavenBuilder.luau")
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = "HavenBuilder",
		environment = environment,
	})
	return chunk(), heartbeats, workspace
end

describe("HavenBuilder", function()
	it("builds the plaza, districts, and arches without writing streaming", function()
		local builder, heartbeats, workspace = loadBuilder()
		local baseplateSpawn = instance("SpawnLocation")
		baseplateSpawn.Name = "SpawnLocation"
		baseplateSpawn.Parent = workspace

		local hub = instance("Model")
		hub.Name = "Hub"
		hub.Parent = workspace
		local count = builder.build(hub)

		expect(type(count) == "number" and count >= 40).toBeTrue()
		expect(workspace.StreamingEnabled).toEqual(true)
		expect(hub.ModelStreamingMode.__enum).toEqual("Enum.ModelStreamingMode.Persistent")
		expect(findNamed(hub, "LumenHeart") ~= nil).toBeTrue()
		expect(findNamed(hub, "BossPlaza") ~= nil).toBeTrue()
		expect(findNamed(hub, "HubSpawn") ~= nil).toBeTrue()
		expect(findNamed(hub, "Forge") ~= nil).toBeTrue()
		expect(findNamed(hub, "Market") ~= nil).toBeTrue()
		expect(findNamed(hub, "GuildHall") ~= nil).toBeTrue()
		expect(findNamed(hub, "PetGarden") ~= nil).toBeTrue()
		expect(findNamed(hub, "Observatory") ~= nil).toBeTrue()
		expect(findNamed(hub, "verdant") ~= nil).toBeTrue()
		expect(findNamed(hub, "sunken") ~= nil).toBeTrue()
		expect(findNamed(hub, "ember") ~= nil).toBeTrue()
		expect(findNamed(hub, "frost") ~= nil).toBeTrue()
		expect(findNamed(hub, "void") ~= nil).toBeTrue()

		local enter = findNamed(hub, "EnterPad")
		expect(enter ~= nil).toBeTrue()
		expect(enter:GetAttribute("EnterDungeon")).toEqual(Dungeons.ROOTVAULT_ID)
		expect(baseplateSpawn.Enabled).toEqual(false)
		expect(baseplateSpawn.Transparency).toEqual(1)
		expect(findNamed(hub, "HubSpawn").Transparency ~= 1).toBeTrue()

		expect(#heartbeats >= 1).toBeTrue()
		heartbeats[1].callback(0.2)
		expect(heartbeats[1].Connected).toBeTrue()
	end)
end)
