--!strict

--[[
	Drives the same builder DungeonService.spawnEnemy calls.

	Recipe counts alone stayed green while Studio showed a single sliding
	block, because the rig's limbs were unanchored physics parts. This builds
	every Rootvault room enemy and the forest kit through that builder.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local ModelFactory = require("../src/ReplicatedStorage/Shared/ModelFactory")
local VerdantScatter = require("../src/ReplicatedStorage/Shared/VerdantScatter")

type Mock = any

local warnings: { string } = {}

local function enumNode(path: string): Mock
	return setmetatable({ __enum = path }, {
		__index = function(self, key)
			local child = enumNode(path .. "." .. tostring(key))
			rawset(self, key, child)
			return child
		end,
	})
end

local function vector3(x: number?, y: number?, z: number?): Mock
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local function cframe(x: number, y: number, z: number): Mock
	local self = {
		X = x,
		Y = y,
		Z = z,
		Position = vector3(x, y, z),
	}
	return setmetatable(self, {
		__mul = function(left, right)
			return cframe(left.X + right.X, left.Y + right.Y, left.Z + right.Z)
		end,
	})
end

local BASE_PART = {
	Part = true,
	WedgePart = true,
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

	function methods:GetChildren(): { Mock }
		return self.children
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

	function methods:FindFirstChildOfClass(classNameToFind: string): Mock?
		for _, child in ipairs(self.children) do
			if child:IsA(classNameToFind) then
				return child
			end
		end
		return nil
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

local function load(path: string, environment: { [string]: any }): any
	local source = fs.readFile(path)
	local bytecode = luau.compile(source, { debugLevel = 2 })
	local chunk = luau.load(bytecode, {
		debugName = path,
		environment = environment,
	})
	return chunk()
end

local function environment(): { [string]: any }
	return {
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
		warn = function(...)
			local parts = {}
			for index = 1, select("#", ...) do
				table.insert(parts, tostring(select(index, ...)))
			end
			table.insert(warnings, table.concat(parts, " "))
		end,
		math = math,
		string = string,
		table = table,
		Enum = enumNode("Enum"),
		Color3 = {
			fromRGB = function(red, green, blue)
				return { R = red, G = green, B = blue }
			end,
		},
		Vector3 = { new = vector3 },
		NumberRange = {
			new = function(min: number, max: number)
				return { Min = min, Max = max }
			end,
		},
		NumberSequence = {
			new = function(value: number)
				return { value = value }
			end,
		},
		ColorSequence = {
			new = function(color: any)
				return { color = color }
			end,
		},
		CFrame = {
			new = function(x: number?, y: number?, z: number?)
				return cframe(x or 0, y or 0, z or 0)
			end,
			Angles = function(_rx: number, _ry: number, _rz: number)
				return cframe(0, 0, 0)
			end,
		},
		Instance = { new = instance },
	}
end

local function slice(source: string, from: string, to: string): string
	local startAt = string.find(source, from, 1, true)
	assert(startAt ~= nil, "missing " .. from)
	local endAt = string.find(source, to, startAt + #from, true)
	assert(endAt ~= nil, "missing " .. to)
	return string.sub(source, startAt, endAt - 1)
end

local function shapeLabel(part: Mock): string
	if part.Shape == nil then
		return ""
	end
	return part.Shape.__enum or ""
end

describe("Rootvault spawn", function()
	it("builds a multi-part anchored rig for every Rootvault room enemy", function()
		table.clear(warnings)
		local env = environment()
		local factory = load("src/ReplicatedStorage/Shared/ModelFactory.luau", env)
		local dungeon = Dungeons.get(Dungeons.ROOTVAULT_ID)
		assert(dungeon ~= nil, "Rootvault missing")

		local roster: { [string]: boolean } = {}
		for _, room in ipairs(dungeon.rooms) do
			for _, kind in ipairs(room.enemies) do
				roster[kind] = true
			end
		end
		for _, kind in ipairs(ModelFactory.MONSTERS) do
			expect(roster[kind]).toBeTrue()
		end

		local folder = instance("Folder")
		folder.Name = "Active"
		for _, kind in ipairs(ModelFactory.MONSTERS) do
			local definition = Dungeons.enemy(kind)
			assert(definition ~= nil, kind)
			local root = factory.buildEnemy(
				folder,
				kind,
				cframe(0, definition.size[2] / 2, 8),
				vector3(definition.size[1], definition.size[2], definition.size[3]),
				definition.name
			)
			expect(root ~= nil).toBeTrue()
			local model = root.Parent
			expect(model.Name).toEqual(kind)
			expect(model.Parent).toEqual(folder)
			expect(model:GetAttribute("ShardfallKind")).toEqual(kind)
			expect(root.Name).toEqual(definition.name)
			expect(root.Name ~= "AJ_H20").toBeTrue()
			expect(root.Transparency).toEqual(1)
			expect(root.Anchored).toBeTrue()
			expect(root.CanCollide).toBeFalse()
			expect(root.CanTouch).toBeFalse()
			expect(root.CanQuery).toBeTrue()
			expect(root.Size.X).toEqual(definition.size[1])
			expect(root.Size.Y).toEqual(definition.size[2])
			expect(root.Size.Z).toEqual(definition.size[3])

			local visuals = 0
			for _, descendant in ipairs(model:GetDescendants()) do
				expect(descendant.ClassName ~= "Motor6D").toBeTrue()
				expect(descendant.ClassName ~= "Humanoid").toBeTrue()
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).toBeTrue()
					expect(descendant.CanCollide).toBeFalse()
					expect(descendant.CanTouch).toBeFalse()
					expect(string.find(shapeLabel(descendant), "Cylinder", 1, true)).toBeNil()
					if descendant ~= root then
						visuals += 1
					end
				end
			end
			expect(visuals).toEqual(ModelFactory.partCount(kind))
			expect(visuals >= 4).toBeTrue()
			factory.step(root, 0.35, true)
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).toBeTrue()
					expect(descendant.CanCollide).toBeFalse()
				end
			end
		end

		local brute = Dungeons.enemy("root_brute")
		assert(brute ~= nil)
		local den = factory.buildEnemy(
			folder,
			"root_brute",
			cframe(-8, brute.size[2] / 2, 8),
			vector3(brute.size[1], brute.size[2], brute.size[3]),
			brute.name
		)
		local torso = nil
		for _, descendant in ipairs(den.Parent:GetDescendants()) do
			if descendant.Name == "Torso" then
				torso = descendant
			end
		end
		expect(torso ~= nil).toBeTrue()
		expect(torso.Anchored).toBeTrue()
		expect(torso.CanCollide).toBeFalse()
		expect(#den.Parent:GetDescendants() > 3).toBeTrue()

		local character = instance("Model")
		character.Name = "PlayerCharacter"
		local humanoid = instance("Humanoid")
		humanoid.Parent = character
		local before = #character:GetDescendants()
		local refused = factory.buildEnemy(
			character,
			"root_brute",
			cframe(0, 3, 0),
			vector3(5.2, 5.6, 4.4),
			"Root Brute"
		)
		expect(refused).toBeNil()
		expect(#character:GetDescendants()).toEqual(before)
		local heard = false
		for _, message in ipairs(warnings) do
			if string.find(message, "under a character", 1, true) ~= nil then
				heard = true
			end
		end
		expect(heard).toBeTrue()

		table.clear(warnings)
		expect(
			factory.buildEnemy(folder, "missing_kind", cframe(0, 1, 0), vector3(2, 2, 2), "Missing")
		).toBeNil()
		expect(#warnings >= 1).toBeTrue()
		expect(string.find(warnings[1], "No rig recipe", 1, true) ~= nil).toBeTrue()
	end)

	it("dresses a Rootvault room with anchored kit pieces and Verdant fog", function()
		table.clear(warnings)
		local env = environment()
		local factory = load("src/ReplicatedStorage/Shared/ModelFactory.luau", env)
		local look = load("src/ReplicatedStorage/Shared/VerdantLook.luau", env)
		local half = 28
		local spots = VerdantScatter.room(1 * 9176 + 13, half, "wild")
		local dressing = instance("Model")
		dressing.Name = "Dressing"
		local trees = 0
		local parts = 0
		for _, spot in ipairs(spots) do
			local prop = factory.place(
				dressing,
				spot.kind,
				cframe(spot.x, spot.y, spot.z),
				spot.yaw,
				spot.scale
			)
			expect(prop ~= nil).toBeTrue()
			local pieces = 0
			for _, descendant in ipairs(prop:GetDescendants()) do
				if descendant:IsA("BasePart") then
					pieces += 1
					parts += 1
					expect(descendant.Anchored).toBeTrue()
					expect(descendant.CanCollide).toBeFalse()
					expect(descendant.CanTouch).toBeFalse()
					expect(string.find(shapeLabel(descendant), "Cylinder", 1, true)).toBeNil()
				end
			end
			expect(pieces >= 1).toBeTrue()
			if string.sub(spot.kind, 1, 5) == "tree_" then
				trees += 1
				expect(pieces >= 4).toBeTrue()
			end
		end
		expect(trees >= 4).toBeTrue()
		expect(parts > 20).toBeTrue()
		expect(#warnings).toEqual(0)

		local lighting = instance("Lighting")
		expect(look.apply(lighting)).toBeTrue()
		expect(lighting.ClockTime).toEqual(15.4)
		expect(lighting.FogStart).toEqual(48)
		expect(lighting.FogEnd).toEqual(320)
		expect(lighting:FindFirstChild("VerdantAtmosphere") ~= nil).toBeTrue()
		expect(lighting:FindFirstChild("VerdantGrade") ~= nil).toBeTrue()
		expect(lighting:FindFirstChild("VerdantBloom") ~= nil).toBeTrue()
		expect(lighting:FindFirstChild("VerdantSunRays") ~= nil).toBeTrue()
		expect(lighting:FindFirstChild("VerdantAtmosphere").Density > 0).toBeTrue()
	end)

	it("keeps the live spawn and lighting path on rigs, with a warning if a rig fails", function()
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		local spawnBody = slice(source, "local function spawnEnemy", "local function spawnRoom")
		expect(string.find(spawnBody, "ModelFactory.buildEnemy", 1, true) ~= nil).toBeTrue()
		expect(string.find(spawnBody, "rig failed", 1, true) ~= nil).toBeTrue()
		expect(string.find(spawnBody, "Enum.Material.Grass", 1, true)).toBeNil()
		expect(string.find(spawnBody, "Motor6D", 1, true)).toBeNil()

		local roomBody = slice(source, "local function buildRoom", "local function buildWorld")
		expect(string.find(roomBody, "ModelFactory.place", 1, true) ~= nil).toBeTrue()
		expect(string.find(roomBody, "Forest kit missing", 1, true) ~= nil).toBeTrue()
		expect(string.find(roomBody, "ModelStreamingMode.Atomic", 1, true) ~= nil).toBeTrue()

		local startBody = slice(source, "function DungeonService.start()", "return DungeonService")
		expect(string.find(startBody, "VerdantLook.apply", 1, true) ~= nil).toBeTrue()
		expect(string.find(startBody, "Verdant lighting failed", 1, true) ~= nil).toBeTrue()
		expect(string.find(startBody, "Verdant lighting on", 1, true) ~= nil).toBeTrue()

		local enterBody =
			slice(source, "function DungeonService.enter", "function DungeonService.advance")
		local teleportAt =
			string.find(enterBody, "teleport(player, roomSpawn(run.placeIndex))", 1, true)
		local spawnAt = string.find(enterBody, "spawnRoom(player, run)", 1, true)
		expect(teleportAt ~= nil and spawnAt ~= nil and teleportAt < spawnAt).toBeTrue()
	end)
end)
