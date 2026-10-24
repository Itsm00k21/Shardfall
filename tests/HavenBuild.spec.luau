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
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local HavenLife = require("../src/ReplicatedStorage/Shared/HavenLife")
local SavedWorld = require("../src/ReplicatedStorage/Shared/SavedWorld")
local ShellLayout = require("../src/ReplicatedStorage/Shared/ShellLayout")
local Travel = require("../src/ReplicatedStorage/Shared/Travel")
local VerdantScatter = require("../src/ReplicatedStorage/Shared/VerdantScatter")

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

local function vector3(x: number?, y: number?, z: number?): Mock
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

-- Matches Roblox CFrame.Angles / fromMatrix well enough to measure floors.
local function cframe(
	px: number,
	py: number,
	pz: number,
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number
): Mock
	local self = {
		Position = vector3(px, py, pz),
		XVector = vector3(r00, r10, r20),
		YVector = vector3(r01, r11, r21),
		ZVector = vector3(r02, r12, r22),
		r00 = r00,
		r01 = r01,
		r02 = r02,
		r10 = r10,
		r11 = r11,
		r12 = r12,
		r20 = r20,
		r21 = r21,
		r22 = r22,
	}

	function self:VectorToWorldSpace(point: Mock): Mock
		return vector3(
			self.r00 * point.X + self.r01 * point.Y + self.r02 * point.Z,
			self.r10 * point.X + self.r11 * point.Y + self.r12 * point.Z,
			self.r20 * point.X + self.r21 * point.Y + self.r22 * point.Z
		)
	end

	function self:PointToWorldSpace(point: Mock): Mock
		local rotated = self:VectorToWorldSpace(point)
		return vector3(
			self.Position.X + rotated.X,
			self.Position.Y + rotated.Y,
			self.Position.Z + rotated.Z
		)
	end

	function self:PointToObjectSpace(point: Mock): Mock
		local dx = point.X - self.Position.X
		local dy = point.Y - self.Position.Y
		local dz = point.Z - self.Position.Z
		return vector3(
			self.r00 * dx + self.r10 * dy + self.r20 * dz,
			self.r01 * dx + self.r11 * dy + self.r21 * dz,
			self.r02 * dx + self.r12 * dy + self.r22 * dz
		)
	end

	return setmetatable(self, {
		__add = function(left, offset)
			return cframe(
				left.Position.X + offset.X,
				left.Position.Y + offset.Y,
				left.Position.Z + offset.Z,
				left.r00,
				left.r01,
				left.r02,
				left.r10,
				left.r11,
				left.r12,
				left.r20,
				left.r21,
				left.r22
			)
		end,
		__mul = function(left, right)
			local xAxis = left:VectorToWorldSpace(right.XVector)
			local yAxis = left:VectorToWorldSpace(right.YVector)
			local zAxis = left:VectorToWorldSpace(right.ZVector)
			local origin = left:PointToWorldSpace(right.Position)
			return cframe(
				origin.X,
				origin.Y,
				origin.Z,
				xAxis.X,
				yAxis.X,
				zAxis.X,
				xAxis.Y,
				yAxis.Y,
				zAxis.Y,
				xAxis.Z,
				yAxis.Z,
				zAxis.Z
			)
		end,
	})
end

local function angles(rx: number, ry: number, rz: number): Mock
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	return cframe(
		0,
		0,
		0,
		cy * cz,
		-cy * sz,
		sy,
		sx * sy * cz + cx * sz,
		-sx * sy * sz + cx * cz,
		-sx * cy,
		-cx * sy * cz + sx * sz,
		cx * sy * sz + sx * cz,
		cx * cy
	)
end

local function cframeNew(x: any, y: number?, z: number?): Mock
	if type(x) == "table" then
		return cframe(x.X, x.Y, x.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	return cframe(x or 0, y or 0, z or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end

local function cross(a: Mock, b: Mock): Mock
	return vector3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end

local function unit(v: Mock): Mock
	local magnitude = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	if magnitude < 1e-8 then
		return vector3(0, 1, 0)
	end
	return vector3(v.X / magnitude, v.Y / magnitude, v.Z / magnitude)
end

local function fromMatrix(pos: Mock, vx: Mock, vy: Mock, vz: Mock?): Mock
	local axisZ = vz
	if axisZ == nil then
		axisZ =
			vector3(vx.Y * vy.Z - vx.Z * vy.Y, vx.Z * vy.X - vx.X * vy.Z, vx.X * vy.Y - vx.Y * vy.X)
	end
	return cframe(
		pos.X,
		pos.Y,
		pos.Z,
		vx.X,
		vy.X,
		axisZ.X,
		vx.Y,
		vy.Y,
		axisZ.Y,
		vx.Z,
		vy.Z,
		axisZ.Z
	)
end

local BASE_PART = {
	Part = true,
	WedgePart = true,
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

	function methods:Clone(): Mock
		local copy = instance(self.ClassName)
		for key, value in pairs(self) do
			if
				key ~= "children"
				and key ~= "Parent"
				and key ~= "attributes"
				and key ~= "ClassName"
			then
				rawset(copy, key, value)
			end
		end
		for key, value in pairs(self.attributes) do
			copy:SetAttribute(key, value)
		end
		return copy
	end

	if className == "ProximityPrompt" then
		rawset(object, "Triggered", {
			Connect = function(_signal, _callback)
				return {
					Disconnect = function() end,
				}
			end,
		})
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

local function findAll(root: Mock, name: string): { Mock }
	local list = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name then
			table.insert(list, descendant)
		end
	end
	return list
end

local function worldBox(part: Mock): (number, number, number, number, number, number)
	local size = part.Size
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local point = part.CFrame:PointToWorldSpace(
					vector3(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
				)
				minX = math.min(minX, point.X)
				minY = math.min(minY, point.Y)
				minZ = math.min(minZ, point.Z)
				maxX = math.max(maxX, point.X)
				maxY = math.max(maxY, point.Y)
				maxZ = math.max(maxZ, point.Z)
			end
		end
	end
	return minX, minY, minZ, maxX, maxY, maxZ
end

local function shapeName(part: Mock): string
	if part.Shape == nil then
		return "Block"
	end
	return part.Shape.__enum or "Block"
end

local function requireNear(actual: number, expected: number, epsilon: number, label: string)
	if math.abs(actual - expected) > epsilon then
		error(
			string.format("%s: expected %.2f ± %.2f, got %.2f", label, expected, epsilon, actual),
			2
		)
	end
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
	local scatterModule = instance("ModuleScript")
	scatterModule.Name = "VerdantScatter"
	scatterModule.Parent = shared
	local lifeModule = instance("ModuleScript")
	lifeModule.Name = "HavenLife"
	lifeModule.Parent = shared
	local travelModule = instance("ModuleScript")
	travelModule.Name = "Travel"
	travelModule.Parent = shared
	local shellModule = instance("ModuleScript")
	shellModule.Name = "ShellLayout"
	shellModule.Parent = shared
	local savedModule = instance("ModuleScript")
	savedModule.Name = "SavedWorld"
	savedModule.Parent = shared
	local gateModule = instance("ModuleScript")
	gateModule.Name = "LaunchGate"
	gateModule.Parent = shared

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
		NumberRange = {
			new = function(minValue, maxValue)
				return { Min = minValue, Max = maxValue or minValue }
			end,
		},
		NumberSequence = {
			new = function(value)
				return { value = value }
			end,
		},
		ColorSequence = {
			new = function(color)
				return { color = color }
			end,
		},
		workspace = workspace,
		Enum = enumNode("Enum"),
		Color3 = {
			fromRGB = function(red, green, blue)
				return { R = red, G = green, B = blue }
			end,
		},
		Vector3 = { new = vector3 },
		CFrame = {
			new = cframeNew,
			Angles = angles,
			fromMatrix = fromMatrix,
			lookAt = function(at, target, up)
				local upv = up or vector3(0, 1, 0)
				local look = unit(vector3(target.X - at.X, target.Y - at.Y, target.Z - at.Z))
				local right = unit(cross(upv, look))
				local newUp = cross(look, right)
				return fromMatrix(at, right, newUp, vector3(-look.X, -look.Y, -look.Z))
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
			if module == scatterModule then
				return VerdantScatter
			end
			if module == lifeModule then
				return HavenLife
			end
			if module == travelModule then
				return Travel
			end
			if module == shellModule then
				return ShellLayout
			end
			if module == savedModule then
				return SavedWorld
			end
			if module == gateModule then
				return LaunchGate
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
		local baseplate = instance("Part")
		baseplate.Name = "Baseplate"
		baseplate.Parent = workspace
		local baseplateSpawn = instance("SpawnLocation")
		baseplateSpawn.Name = "SpawnLocation"
		baseplateSpawn.Parent = workspace

		local hub = instance("Model")
		hub.Name = "Haven"
		local buried = instance("Folder")
		buried.Name = "ShardfallWorld"
		buried.Parent = workspace
		hub.Parent = buried
		local count = builder.build(hub)

		expect(type(count) == "number" and count >= 40).toBeTrue()
		expect(workspace.StreamingEnabled).toEqual(true)
		expect(hub.Parent).toEqual(workspace)
		expect(hub.ModelStreamingMode.__enum).toEqual("Enum.ModelStreamingMode.Persistent")
		expect(baseplate.Parent).toEqual(workspace)
		builder.clearDefaults()
		expect(baseplate.Parent).toBeNil()
		expect(findNamed(hub, "LumenHeart") ~= nil).toBeTrue()
		expect(findNamed(hub, "BossPlaza") ~= nil).toBeTrue()
		expect(findNamed(hub, "HubSpawn") ~= nil).toBeTrue()
		expect(findNamed(hub, "Forge") ~= nil).toBeTrue()
		expect(findNamed(hub, "Market") ~= nil).toBeTrue()
		expect(findNamed(hub, "GuildHall") ~= nil).toBeTrue()
		expect(findNamed(hub, "PetGarden") ~= nil).toBeTrue()
		expect(findNamed(hub, "Observatory") ~= nil).toBeTrue()
		expect(findNamed(hub, "rootvault") ~= nil).toBeTrue()
		expect(findNamed(hub, "heartwood") ~= nil).toBeTrue()
		expect(findNamed(hub, "tidecrypt") ~= nil).toBeTrue()
		expect(findNamed(hub, "ember") ~= nil).toBeTrue()
		expect(findNamed(hub, "frost") ~= nil).toBeTrue()
		expect(findNamed(hub, "void") ~= nil).toBeTrue()
		expect(findNamed(hub, "RealmArches"):FindFirstChild("Ground")).toBeNil()

		local enter = findNamed(hub, "EnterPad")
		expect(enter ~= nil).toBeTrue()
		expect(enter:GetAttribute("EnterDungeon")).toEqual(Dungeons.ROOTVAULT_ID)
		expect(baseplateSpawn.Parent).toBeNil()
		expect(findNamed(hub, "HubSpawn").Transparency ~= 1).toBeTrue()

		expect(#heartbeats >= 1).toBeTrue()
		heartbeats[1].callback(0.2)
		expect(heartbeats[1].Connected).toBeTrue()
	end)

	it("lays flat floors, a crystal, and bridges that meet the islands", function()
		local turned = angles(0, 0, math.pi / 2):PointToWorldSpace(vector3(1, 0, 0))
		requireNear(turned.Y, 1, 1e-6, "Angles Z local X")
		requireNear(turned.X, 0, 1e-6, "Angles Z local X")
		local yawed = angles(0, math.pi / 2, 0):PointToWorldSpace(vector3(1, 0, 0))
		requireNear(yawed.Z, -1, 1e-6, "Angles Y local X")

		local builder, heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Hub"
		local count = builder.build(hub)
		expect(count >= 40).toBeTrue()

		local function floorBlock(part: Mock, label: string)
			if shapeName(part) ~= "Enum.PartType.Block" then
				error(label .. " is " .. shapeName(part) .. ", not a block", 2)
			end
			if part.Transparency ~= 0 then
				error(label .. " is transparent", 2)
			end
			if part.CanCollide ~= true or part.Anchored ~= true then
				error(label .. " is not a solid anchored floor", 2)
			end
			local _x0, minY, _z0, _x1, maxY = worldBox(part)
			requireNear(maxY, Haven.FLOOR_Y, 0.25, label .. " top")
			requireNear(maxY - minY, part.Size.Y, 0.25, label .. " thickness")
		end

		print("Haven top-down bounds (center xyz, top y, world extents xyz)")
		local function dump(part: Mock)
			local minX, minY, minZ, maxX, maxY, maxZ = worldBox(part)
			local pos = part.CFrame.Position
			print(
				string.format(
					"  %-14s %7.1f %7.1f %7.1f  top %6.1f  ext %6.1f %6.1f %6.1f",
					part.Name,
					pos.X,
					pos.Y,
					pos.Z,
					maxY,
					maxX - minX,
					maxY - minY,
					maxZ - minZ
				)
			)
		end

		local interesting = {}
		for _, descendant in ipairs(hub:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Anchored ~= true then
				error(descendant.Name .. " is not anchored", 2)
			end
			if
				descendant:IsA("BasePart")
				and (
					descendant.Name == "Ground"
					or descendant.Name == "Rock"
					or descendant.Name == "Bridge"
					or descendant.Name == "Landing"
					or descendant.Name == "HubSpawn"
					or descendant.Name == "LumenHeart"
					or descendant.Name == "CrystalShard"
					or descendant.Name == "OrbitShard"
					or descendant.Name == "PillarL"
					or descendant.Name == "Drum"
					or descendant.Name == "Trunk"
				)
			then
				table.insert(interesting, descendant)
			end
		end
		table.sort(interesting, function(a, b)
			if a.Name == b.Name then
				return a.CFrame.Position.X < b.CFrame.Position.X
			end
			return a.Name < b.Name
		end)
		for _, part in ipairs(interesting) do
			dump(part)
		end

		local cols, rows = 64, 28
		local minX, maxX = -230, 230
		local minZ, maxZ = -120, 260
		print(
			"map  north(-Z) at top, +X to the right   # floor  = bridge  S spawn  * heart  A arch"
		)
		for row = 0, rows - 1 do
			local z = minZ + (maxZ - minZ) * (row + 0.5) / rows
			local rank = { [" "] = 0, ["#"] = 1, ["="] = 2, ["A"] = 3, ["*"] = 4, ["S"] = 5 }
			local line = {}
			for col = 0, cols - 1 do
				local x = minX + (maxX - minX) * (col + 0.5) / cols
				local mark = " "
				for _, part in ipairs(interesting) do
					local bx0, _by0, bz0, bx1, _by1, bz1 = worldBox(part)
					if x >= bx0 and x <= bx1 and z >= bz0 and z <= bz1 then
						local nextMark = mark
						if part.Name == "HubSpawn" then
							nextMark = "S"
						elseif part.Name == "LumenHeart" or part.Name == "CrystalShard" then
							nextMark = "*"
						elseif part.Name == "PillarL" then
							nextMark = "A"
						elseif part.Name == "Bridge" or part.Name == "Landing" then
							nextMark = "="
						elseif part.Name == "Ground" then
							nextMark = "#"
						end
						if (rank[nextMark] or 0) > (rank[mark] or 0) then
							mark = nextMark
						end
					end
				end
				table.insert(line, mark)
			end
			print(table.concat(line))
		end

		local plaza = findNamed(hub, "BossPlaza"):FindFirstChild("Ground")
		floorBlock(plaza, "plaza")
		local _px0, _py0, _pz0, _px1, plazaTop, _pz1 = worldBox(plaza)
		requireNear(plazaTop, Haven.FLOOR_Y, 0.2, "plaza top")
		local spawn = findNamed(hub, "HubSpawn")
		local _sx0, spawnBottom, _sz0, _sx1, _sy1, _sz1 = worldBox(spawn)
		requireNear(spawnBottom, plazaTop, 0.2, "spawn sitting on the plaza")
		local spawnPos = spawn.CFrame.Position
		local spawnReach = spawnPos.X * spawnPos.X + spawnPos.Z * spawnPos.Z
		if spawnReach > (Haven.PLAZA_RADIUS - 8) * (Haven.PLAZA_RADIUS - 8) then
			error("spawn is not on the plaza", 2)
		end

		local floors = {
			{ "Forge", Haven.district("forge") },
			{ "Market", Haven.district("market") },
			{ "GuildHall", Haven.district("guild") },
			{ "PetGarden", Haven.district("garden") },
			{ "Observatory", Haven.district("observatory") },
		}
		for _, floor in ipairs(floors) do
			local model = findNamed(hub, floor[1])
			local ground = model:FindFirstChild("Ground")
			floorBlock(ground, floor[1])
			local _a, _b, _c, _d, top = worldBox(ground)
			requireNear(top, Haven.FLOOR_Y, 0.2, floor[1] .. " top")
			local center = ground.CFrame.Position
			requireNear(center.X, floor[2].x, 0.5, floor[1] .. " x")
			requireNear(center.Z, floor[2].z, 0.5, floor[1] .. " z")
		end

		for _, part in ipairs(hub:GetDescendants()) do
			if part:IsA("BasePart") and shapeName(part) == "Enum.PartType.Cylinder" then
				error(part.Name .. " is still a cylinder", 2)
			end
		end

		local function onDeck(part: Mock, x: number, z: number): boolean
			if part.CanCollide ~= true or part.Anchored ~= true then
				return false
			end
			local pos = part.CFrame.Position
			local size = part.Size
			local topY = pos.Y + part.CFrame.YVector.Y * size.Y / 2
			if topY < Haven.FLOOR_Y - 0.75 or topY > Haven.FLOOR_Y + 2 then
				return false
			end
			local localPoint = part.CFrame:PointToObjectSpace(vector3(x, pos.Y, z))
			return math.abs(localPoint.X) <= size.X / 2 + 0.5
				and math.abs(localPoint.Z) <= size.Z / 2 + 0.5
		end

		local decks = {}
		for _, descendant in ipairs(hub:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name ~= "Sign" then
				table.insert(decks, descendant)
			end
		end

		local function supported(x: number, z: number): boolean
			for _, deck in ipairs(decks) do
				if onDeck(deck, x, z) then
					return true
				end
			end
			return false
		end

		local function onBridge(x: number, z: number): boolean
			for _, deck in ipairs(decks) do
				if deck.Name == "Bridge" and onDeck(deck, x, z) then
					return true
				end
			end
			return false
		end

		local function walk(x1: number, z1: number, x2: number, z2: number, label: string)
			local dx = x2 - x1
			local dz = z2 - z1
			local distance = math.sqrt(dx * dx + dz * dz)
			local steps = math.max(1, math.ceil(distance / 2))
			for step = 0, steps do
				local t = step / steps
				local x = x1 + dx * t
				local z = z1 + dz * t
				if not supported(x, z) then
					error(
						string.format(
							"%s has no floor at (%.1f, %.1f), step %d/%d",
							label,
							x,
							z,
							step,
							steps
						),
						2
					)
				end
			end
		end

		local function approach(
			x1: number,
			z1: number,
			x2: number,
			z2: number,
			inset: number
		): (number, number)
			local dx = x2 - x1
			local dz = z2 - z1
			local distance = math.sqrt(dx * dx + dz * dz)
			return x1 + dx / distance * inset, z1 + dz / distance * inset
		end

		local function faceExit(halfX: number, halfZ: number, dirX: number, dirZ: number): number
			local tx = if math.abs(dirX) > 1e-6 then halfX / math.abs(dirX) else math.huge
			local tz = if math.abs(dirZ) > 1e-6 then halfZ / math.abs(dirZ) else math.huge
			return math.min(tx, tz)
		end

		local function deckTop(part: Mock): number
			local pos = part.CFrame.Position
			return pos.Y + part.CFrame.YVector.Y * part.Size.Y / 2
		end

		local bridges = findAll(hub, "Bridge")
		local landings = findAll(hub, "Landing")
		local goals = {}
		local rimGoals = {}
		for _, district in ipairs(Haven.DISTRICTS) do
			local goal = {
				name = district.name,
				x = district.x,
				z = district.z,
				halfX = district.radius,
				halfZ = district.radius,
			}
			if district.id == "garden" or district.id == "observatory" then
				table.insert(rimGoals, goal)
			else
				table.insert(goals, goal)
			end
		end
		walk(Haven.SPAWN.x, Haven.SPAWN.z, Haven.SHOP.x, Haven.SHOP.z, "spawn to shop")
		if #bridges < #goals + #rimGoals or #landings < #goals + #rimGoals then
			error("missing a bridge", 2)
		end
		for _, span in ipairs(bridges) do
			floorBlock(span, "bridge")
			if span.Size.X < 8 or span.Size.Y < 2 then
				error(
					string.format("bridge is %.1f wide and %.1f thick", span.Size.X, span.Size.Y),
					2
				)
			end
			local drop = Haven.FLOOR_Y - deckTop(span)
			if drop < 0.05 or drop > 0.25 then
				error(string.format("bridge tongue sits %.3f below the floor", drop), 2)
			end
		end
		for _, deck in ipairs(landings) do
			floorBlock(deck, "landing")
			if deck.Size.X < 8 or deck.Size.Y < 2 then
				error(
					string.format("landing is %.1f wide and %.1f thick", deck.Size.X, deck.Size.Y),
					2
				)
			end
			if math.abs(deckTop(deck) - (Haven.FLOOR_Y + Haven.LAYER)) > 0.01 then
				error("landing is not lifted off the floor", 2)
			end
		end

		local function footprintOf(part: Mock): Haven.Footprint
			local right = part.CFrame.XVector
			local forward = part.CFrame.ZVector
			local pos = part.CFrame.Position
			return {
				x = pos.X,
				z = pos.Z,
				rightX = right.X,
				rightZ = right.Z,
				forwardX = forward.X,
				forwardZ = forward.Z,
				halfX = part.Size.X / 2,
				halfZ = part.Size.Z / 2,
			}
		end

		local function isWalkPlate(part: Mock): boolean
			if part:IsA("BasePart") ~= true then
				return false
			end
			if part.Transparency ~= nil and part.Transparency >= 1 then
				return false
			end
			local up = part.CFrame.YVector
			if up == nil or up.Y < 0.99 then
				return false
			end
			if
				part.Name == "Ground"
				or part.Name == "Landing"
				or part.Name == "Bridge"
				or part.Name == "HubSpawn"
				or part.Name == "Station"
				or part.Name == "Pond"
				or part.Name == "Pedestal"
				or part.Name == "Rock"
			then
				return true
			end
			local size = part.Size
			return part.CanCollide == true and size.X >= 8 and size.Z >= 8 and size.Y <= 12
		end

		local plates = {}
		for _, descendant in ipairs(hub:GetDescendants()) do
			if isWalkPlate(descendant) then
				table.insert(plates, descendant)
			end
		end
		for left = 1, #plates do
			for right = left + 1, #plates do
				local a = plates[left]
				local b = plates[right]
				if Haven.coplanarTops(footprintOf(a), deckTop(a), footprintOf(b), deckTop(b)) then
					local aParent = if a.Parent ~= nil then a.Parent.Name else "?"
					local bParent = if b.Parent ~= nil then b.Parent.Name else "?"
					error(
						string.format(
							"%s/%s and %s/%s share a top at %.3f",
							aParent,
							a.Name,
							bParent,
							b.Name,
							deckTop(a)
						),
						2
					)
				end
			end
		end

		walk(Haven.SPAWN.x, Haven.SPAWN.z, 0, 0, "spawn to plaza")
		for _, goal in ipairs(goals) do
			local rimX, rimZ = approach(0, 0, goal.x, goal.z, Haven.PLAZA_RADIUS)
			walk(Haven.SPAWN.x, Haven.SPAWN.z, rimX, rimZ, "spawn to " .. goal.name)
			walk(rimX, rimZ, goal.x, goal.z, goal.name)
			local function onto(
				cx: number,
				cz: number,
				halfX: number,
				halfZ: number,
				tx: number,
				tz: number
			)
				local dx = tx - cx
				local dz = tz - cz
				local distance = math.sqrt(dx * dx + dz * dz)
				local dirX = dx / distance
				local dirZ = dz / distance
				local face = faceExit(halfX, halfZ, dirX, dirZ)
				local ox = cx + dirX * (face - 2)
				local oz = cz + dirZ * (face - 2)
				if not onBridge(ox, oz) then
					error(goal.name .. " bridge tongue does not reach 2 studs under the floor", 2)
				end
			end
			onto(0, 0, Haven.PLAZA_RADIUS, Haven.PLAZA_RADIUS, goal.x, goal.z)
			onto(goal.x, goal.z, goal.halfX, goal.halfZ, 0, 0)
		end

		local function segmentDistance(
			x1: number,
			z1: number,
			x2: number,
			z2: number,
			px: number,
			pz: number
		): number
			local dx = x2 - x1
			local dz = z2 - z1
			local length = dx * dx + dz * dz
			local t = 0
			if length > 1e-6 then
				t = ((px - x1) * dx + (pz - z1) * dz) / length
				if t < 0 then
					t = 0
				elseif t > 1 then
					t = 1
				end
			end
			local missX = px - (x1 + dx * t)
			local missZ = pz - (z1 + dz * t)
			return math.sqrt(missX * missX + missZ * missZ)
		end

		for _, goal in ipairs(rimGoals) do
			local rimX, rimZ = Haven.courtRim(goal.x, goal.z)
			walk(Haven.SPAWN.x, Haven.SPAWN.z, rimX, rimZ, "spawn to " .. goal.name .. " rim")
			walk(rimX, rimZ, goal.x, goal.z, goal.name)
			local function ontoRim(
				cx: number,
				cz: number,
				halfX: number,
				halfZ: number,
				tx: number,
				tz: number
			)
				local dx = tx - cx
				local dz = tz - cz
				local distance = math.sqrt(dx * dx + dz * dz)
				local dirX = dx / distance
				local dirZ = dz / distance
				local face = faceExit(halfX, halfZ, dirX, dirZ)
				local ox = cx + dirX * (face - 2)
				local oz = cz + dirZ * (face - 2)
				if not onBridge(ox, oz) then
					error(goal.name .. " bridge tongue does not reach 2 studs under the floor", 2)
				end
			end
			ontoRim(rimX, rimZ, 8, 8, goal.x, goal.z)
			ontoRim(goal.x, goal.z, goal.halfX, goal.halfZ, rimX, rimZ)
			for _, portal in ipairs(Haven.PORTALS) do
				local miss = segmentDistance(rimX, rimZ, goal.x, goal.z, portal.x, portal.z)
				if miss < 8 then
					error(
						string.format(
							"%s bridge passes %.1f studs from %s",
							goal.name,
							miss,
							portal.name
						),
						2
					)
				end
			end
		end

		-- Flat horizontal tops that overlap in XZ must not share a Y.
		local function flatTop(part: Mock): boolean
			if part.Transparency >= 1 then
				return false
			end
			if shapeName(part) == "Enum.PartType.Ball" then
				return false
			end
			return math.abs(part.CFrame.YVector.Y) > 0.99
		end

		local function xzCorners(part: Mock): { Mock }
			local cf = part.CFrame
			local hx = part.Size.X / 2
			local hz = part.Size.Z / 2
			local points = {}
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					table.insert(points, cf:PointToWorldSpace(vector3(sx * hx, 0, sz * hz)))
				end
			end
			return points
		end

		local function overlapOn(
			pointsA: { Mock },
			pointsB: { Mock },
			ax: number,
			az: number
		): number?
			local function span(points: { Mock }): (number, number)
				local lo = math.huge
				local hi = -math.huge
				for _, point in ipairs(points) do
					local dot = point.X * ax + point.Z * az
					lo = math.min(lo, dot)
					hi = math.max(hi, dot)
				end
				return lo, hi
			end
			local a0, a1 = span(pointsA)
			local b0, b1 = span(pointsB)
			local overlap = math.min(a1, b1) - math.max(a0, b0)
			if overlap <= 0 then
				return nil
			end
			return overlap
		end

		local function penetration(a: Mock, b: Mock): number
			local cornersA = xzCorners(a)
			local cornersB = xzCorners(b)
			local best = math.huge
			local function consider(axis: Mock)
				if best < 0 then
					return
				end
				local mag = math.sqrt(axis.X * axis.X + axis.Z * axis.Z)
				if mag < 1e-6 then
					return
				end
				local hit = overlapOn(cornersA, cornersB, axis.X / mag, axis.Z / mag)
				if hit == nil then
					best = -1
				else
					best = math.min(best, hit)
				end
			end
			consider(a.CFrame.XVector)
			consider(a.CFrame.ZVector)
			consider(b.CFrame.XVector)
			consider(b.CFrame.ZVector)
			return best
		end

		local function partLabel(part: Mock): string
			local owner = if part.Parent ~= nil then part.Parent.Name else "?"
			return owner .. "." .. part.Name
		end

		local flats = {}
		for _, descendant in ipairs(hub:GetDescendants()) do
			if descendant:IsA("BasePart") and flatTop(descendant) then
				table.insert(flats, descendant)
			end
		end
		for i = 1, #flats do
			for j = i + 1, #flats do
				local left = flats[i]
				local right = flats[j]
				if
					math.abs(deckTop(left) - deckTop(right)) < 0.01
					and penetration(left, right) > 0.05
				then
					error(
						string.format(
							"%s and %s share a top at y=%.3f",
							partLabel(left),
							partLabel(right),
							deckTop(left)
						),
						2
					)
				end
			end
		end

		local left = Haven.PORTALS[1]
		local right = Haven.PORTALS[#Haven.PORTALS]
		walk(left.x, left.z, right.x, right.z, "portal row")
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			local labeled = false
			for _, child in ipairs(arch:GetDescendants()) do
				if child:GetAttribute("HavenLabel") == portal.name then
					labeled = true
				end
				if child.Name == "Sign" and child.CanCollide == true then
					error(portal.name .. " sign can be stood on", 2)
				end
			end
			if not labeled then
				error(portal.id .. " is not labeled " .. portal.name, 2)
			end
			if not supported(portal.x, portal.z) then
				error(portal.name .. " arch is not on the court", 2)
			end
			if portal.z > 200 then
				error(portal.name .. " is still on the old shelf", 2)
			end
		end
		local districtLabels = {
			Forge = "Forge",
			Market = "Market",
			GuildHall = "Guild Hall",
			PetGarden = "Pet Garden",
			Observatory = "Observatory",
		}
		for modelName, label in pairs(districtLabels) do
			local model = findNamed(hub, modelName)
			local found = false
			for _, child in ipairs(model:GetDescendants()) do
				if child:GetAttribute("HavenLabel") == label then
					found = true
					if child.CanCollide == true then
						error(label .. " sign can be stood on", 2)
					end
				end
			end
			if not found then
				error(modelName .. " has no " .. label .. " label", 2)
			end
		end
		local armoryLabel = false
		local armoryPrompt = false
		local petsPrompt = false
		local marketPrompt = false
		local shrinePrompt = false
		for _, child in ipairs(hub:GetDescendants()) do
			if child:GetAttribute("HavenLabel") == "Armory" then
				armoryLabel = true
			end
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "armory" then
				armoryPrompt = true
				expect(child.ActionText).toEqual("Armory")
			end
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "pets" then
				petsPrompt = true
			end
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "market" then
				marketPrompt = true
				expect(child.ActionText).toEqual("Market Board")
				local host: any = child.Parent
				local onRim = false
				while host ~= nil do
					if host.Name == "RimShop" then
						onRim = true
					end
					if host.Name == "Market" then
						error("Market Board prompt is still on the island", 2)
					end
					host = host.Parent
				end
				expect(onRim).toBeTrue()
			end
			if child:IsA("ProximityPrompt") and child.ActionText == "Shrine" then
				shrinePrompt = true
				expect(child:GetAttribute("HavenMessage")).toEqual("The shrine wakes inside a run.")
				expect(child:GetAttribute("HavenAction")).toEqual("soon")
			end
		end
		expect(armoryLabel).toBeTrue()
		expect(armoryPrompt).toBeTrue()
		expect(petsPrompt).toBeTrue()
		expect(marketPrompt).toEqual(false) -- market parked: no prompt
		expect(shrinePrompt).toBeTrue()

		local heart = findNamed(hub, "LumenHeart")
		if shapeName(heart) == "Enum.PartType.Cylinder" then
			error("Lumen Heart is a cylinder", 2)
		end
		local _h0, heartBottom = worldBox(heart)
		if heartBottom < Haven.FLOOR_Y - 1 then
			error("Lumen Heart hangs below the plaza", 2)
		end
		local shards = findAll(hub, "CrystalShard")
		if #shards < 6 then
			error("crystal needs a cluster of shards", 2)
		end
		for _, shard in ipairs(shards) do
			if shapeName(shard) == "Enum.PartType.Cylinder" then
				error("crystal shard is a cylinder", 2)
			end
			local _s0, shardBottom, _s2, _s3, shardTop = worldBox(shard)
			if shardBottom < Haven.FLOOR_Y - 1 then
				error(string.format("crystal shard dips into the void at y=%.1f", shardBottom), 2)
			end
			if shardTop - shardBottom < 18 then
				error("crystal shard is too short to read as a crystal", 2)
			end
		end
		local orbits = findAll(hub, "OrbitShard")
		if #orbits < 6 then
			error("orbiting shards are missing", 2)
		end
		heartbeats[1].callback(0.4)
		for index, orbit in ipairs(orbits) do
			local pos = orbit.CFrame.Position
			local radius = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
			if radius < 14 or radius > 26 or pos.Y < Haven.FLOOR_Y + 8 then
				error(string.format("orbit shard %d is not circling the heart", index), 2)
			end
		end

		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			local pillar = arch:FindFirstChild("PillarL")
			local lintel = arch:FindFirstChild("Lintel")
			if pillar == nil or lintel == nil then
				error(portal.id .. " is not an arch", 2)
			end
			local _a0, pillarBottom, _a2, _a3, pillarTop = worldBox(pillar)
			requireNear(pillarBottom, Haven.FLOOR_Y, 0.5, portal.id .. " pillar base")
			if lintel.CFrame.Position.Y < pillarTop - 1 then
				error(portal.id .. " lintel is not across the top", 2)
			end
		end

		local liveCounts: { [string]: number } = {}
		for _, dungeon in ipairs(Dungeons.all()) do
			if dungeon.implemented == true and dungeon.endless ~= true then
				liveCounts[dungeon.id] = 0
			end
		end
		local enterPads = 0
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			local lights = 0
			local prompt = nil
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("PointLight") then
					lights += 1
					if child.Shadows == true or child.Range > 18 then
						error(portal.id .. " accent light is out of budget", 2)
					end
				end
				if child:IsA("ProximityPrompt") then
					local action = child:GetAttribute("HavenAction")
					if action ~= "waves" and action ~= "practice" then
						prompt = child
					end
				end
				if child.Name == "EnterPad" then
					enterPads += 1
					expect(child:GetAttribute("EnterDungeon")).toEqual(Dungeons.ROOTVAULT_ID)
				end
			end
			if lights ~= 1 then
				error(portal.id .. " needs one accent light", 2)
			end
			if portal.id == "heartwood" then
				local raidPrompts = 0
				for _, child in ipairs(arch:GetDescendants()) do
					if child:IsA("ProximityPrompt") then
						raidPrompts += 1
					end
				end
				expect(LaunchGate.on("raids")).toEqual(false)
				expect(raidPrompts).toEqual(0)
				expect(arch:FindFirstChild("PillarL") ~= nil).toBeTrue()
				expect(arch:FindFirstChild("PillarR") ~= nil).toBeTrue()
				expect(arch:FindFirstChild("Lintel") ~= nil).toBeTrue()
				expect(arch:FindFirstChild("Glow") ~= nil).toBeTrue()
				expect(arch:FindFirstChild("EnterPad")).toBeNil()
				expect(arch:FindFirstChild("Seal")).toBeNil()
			elseif prompt == nil or prompt.MaxActivationDistance ~= Haven.GATE_REACH then
				error(portal.id .. " prompt reach is not the gate reach", 2)
			elseif portal.id == "rootvault" then
				expect(prompt:GetAttribute("HavenAction")).toEqual("rootvault")
				expect(prompt.ActionText).toEqual("Enter")
			else
				expect(prompt:GetAttribute("HavenAction")).toEqual("soon")
				expect(prompt:GetAttribute("HavenMessage")).toEqual(portal.message)
				expect(arch:FindFirstChild("Seal") ~= nil).toBeTrue()
				expect(arch:FindFirstChild("EnterPad")).toBeNil()
			end
			local dungeonId = arch:GetAttribute("DungeonId")
			if type(dungeonId) == "string" and liveCounts[dungeonId] ~= nil then
				liveCounts[dungeonId] += 1
			end
		end
		expect(enterPads).toEqual(1)
		for id, count in pairs(liveCounts) do
			if count ~= 1 then
				error(id .. " has " .. tostring(count) .. " arches", 2)
			end
		end

		local stones = findAll(hub, "NoviceStone")
		if #stones ~= 5 then
			error(string.format("expected 5 novice stones, found %d", #stones), 2)
		end
		for _, stone in ipairs(stones) do
			for _, child in ipairs(stone:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					error("novice stone has a prompt", 2)
				end
			end
		end

		local inlayTop = Haven.FLOOR_Y + Haven.LAYER
		local function laneHit(x: number, z: number): string?
			for _, part in ipairs(hub:GetDescendants()) do
				if
					part:IsA("BasePart")
					and part.Name ~= "HubSpawn"
					and part.CanCollide == true
					and (part.Transparency == nil or part.Transparency < 1)
				then
					local top = part.CFrame.Position.Y + part.CFrame.YVector.Y * part.Size.Y / 2
					if top > inlayTop + 0.02 then
						local localPoint = part.CFrame:PointToObjectSpace(vector3(x, part.CFrame.Position.Y, z))
						if
							math.abs(localPoint.X) <= part.Size.X / 2
							and math.abs(localPoint.Z) <= part.Size.Z / 2
						then
							local owner = if part.Parent ~= nil then part.Parent.Name else "?"
							return owner .. "." .. part.Name
						end
					end
				end
			end
			return nil
		end
		for _, portal in ipairs(Haven.PORTALS) do
			local bearing = math.rad(portal.bearing or 0)
			local dirX = math.sin(bearing)
			local dirZ = math.cos(bearing)
			local sideX = math.cos(bearing)
			local sideZ = -math.sin(bearing)
			for radius = 8, Haven.GATE_RADIUS - 8, 2 do
				for _, side in ipairs({ -5, 0, 5 }) do
					local x = Haven.SPAWN.x + dirX * radius + sideX * side
					local z = Haven.SPAWN.z + dirZ * radius + sideZ * side
					local hit = laneHit(x, z)
					if hit ~= nil then
						error(
							string.format(
								"%s lane hits %s at (%.1f, %.1f)",
								portal.name,
								hit,
								x,
								z
							),
							2
						)
					end
				end
			end
		end

		local landmarkNames = {
			Waterfall = true,
			FallLip = true,
			Waystone = true,
			WaystoneCrystal = true,
			SkyShard = true,
			LumenHeart = true,
			ForgeFlame = true,
			ForgeBasin = true,
			Anvil = true,
			TownsfolkFlag = true,
			CrystalShard = true,
			LightBeam = true,
			OrbitShard = true,
		}
		local seen: { [string]: number } = {}
		for _, part in ipairs(hub:GetDescendants()) do
			if part:IsA("BasePart") and landmarkNames[part.Name] == true then
				seen[part.Name] = (seen[part.Name] or 0) + 1
				local size = part.Size
				local mag = math.sqrt(size.X * size.X + size.Y * size.Y + size.Z * size.Z)
				if mag <= 1 then
					error(string.format("%s size magnitude %.2f", part.Name, mag), 2)
				end
				if type(part.Transparency) ~= "number" or part.Transparency >= 0.5 then
					error(string.format("%s transparency %.2f", part.Name, part.Transparency), 2)
				end
			end
		end
		for _, name in ipairs({
			"Waterfall",
			"Waystone",
			"LumenHeart",
			"SkyShard",
			"ForgeFlame",
			"TownsfolkFlag",
		}) do
			if (seen[name] or 0) < 1 then
				error(name .. " was not built", 2)
			end
		end
		if (seen.Waterfall or 0) < 6 then
			error("expected a waterfall on the plaza and each district", 2)
		end

		local inView = 0
		for _, fall in ipairs(findAll(hub, "Waterfall")) do
			if fall.Parent ~= hub then
				error("waterfall should be a direct child of Haven", 2)
			end
			if math.abs(fall.CFrame.ZVector.Y) < 0.9 then
				error(string.format("waterfall is flat (Z.Y=%.2f)", fall.CFrame.ZVector.Y), 2)
			end
			local _f0, bottom, _f2, _f3, top = worldBox(fall)
			if top < Haven.FLOOR_Y + 8 then
				error(string.format("waterfall top %.1f is too low to see from the walk", top), 2)
			end
			if bottom > Haven.FLOOR_Y - 4 then
				error("waterfall does not hang below the walk", 2)
			end
			local pos = fall.CFrame.Position
			local angle = math.atan2(pos.X - Haven.SPAWN.x, Haven.SPAWN.z - pos.Z)
			if math.abs(angle) < math.rad(35) then
				inView += 1
			end
		end
		if inView < 2 then
			error("plaza waterfalls are outside the spawn view", 2)
		end

		local folks = findAll(hub, "Townsfolk")
		if #folks ~= 3 then
			error(string.format("expected 3 townsfolk, found %d", #folks), 2)
		end
		for _, folk in ipairs(folks) do
			if folk.Parent ~= hub then
				error("townsfolk should be a direct child of Haven", 2)
			end
			local flag = folk:FindFirstChild("TownsfolkFlag")
			if flag == nil or not flag:IsA("BasePart") then
				error("townsfolk has no flag", 2)
			end
			local _n0, _n1, _n2, _n3, flagTop = worldBox(flag)
			if flagTop < Haven.FLOOR_Y + 16 then
				error(string.format("townsfolk flag top is only %.1f", flagTop), 2)
			end
		end
	end)

	it("dresses each arch and keeps lanes and prompt radii clear", function()
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)

		local liveCounts: { [string]: number } = {}
		for _, dungeon in ipairs(Dungeons.all()) do
			if dungeon.implemented == true and dungeon.endless ~= true then
				liveCounts[dungeon.id] = 0
			elseif dungeon.endless == true then
				liveCounts[dungeon.id] = 0
			end
		end

		local function inkSum(color: Mock): number
			return color.R + color.G + color.B
		end

		local function closestDistance(part: Mock, point: Mock): number
			local localPoint = part.CFrame:PointToObjectSpace(point)
			local hx = part.Size.X / 2
			local hy = part.Size.Y / 2
			local hz = part.Size.Z / 2
			local cx = math.clamp(localPoint.X, -hx, hx)
			local cy = math.clamp(localPoint.Y, -hy, hy)
			local cz = math.clamp(localPoint.Z, -hz, hz)
			local dx = localPoint.X - cx
			local dy = localPoint.Y - cy
			local dz = localPoint.Z - cz
			return math.sqrt(dx * dx + dy * dy + dz * dz)
		end

		local function owningArch(node: Mock): Mock?
			local cursor = node
			while cursor ~= nil do
				if cursor.Parent ~= nil and cursor.Parent.Name == "RealmArches" then
					return cursor
				end
				cursor = cursor.Parent
			end
			return nil
		end

		local function inLane(portal: Haven.Place, x: number, z: number): boolean
			local bearing = math.rad(portal.bearing or 0)
			local dirX = math.sin(bearing)
			local dirZ = math.cos(bearing)
			local sideX = math.cos(bearing)
			local sideZ = -math.sin(bearing)
			local dx = x - Haven.SPAWN.x
			local dz = z - Haven.SPAWN.z
			local radius = dx * dirX + dz * dirZ
			local lateral = dx * sideX + dz * sideZ
			return radius >= 8 and radius <= Haven.GATE_RADIUS - 6 and math.abs(lateral) <= 5
		end

		-- Above the pad and the inlay, under head height. Sky shards are not a lane.
		local walkLow = Haven.FLOOR_Y + 1.25
		local walkHigh = Haven.FLOOR_Y + 8
		local function partBlocksLane(part: Mock, portal: Haven.Place): boolean
			if part.Transparency ~= nil and part.Transparency >= 1 then
				return false
			end
			local _x0, minY, _z0, _x1, maxY = worldBox(part)
			if maxY <= walkLow or minY >= walkHigh then
				return false
			end
			local size = part.Size
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local point = part.CFrame:PointToWorldSpace(
							vector3(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
						)
						if point.Y > walkLow and point.Y < walkHigh and inLane(portal, point.X, point.Z) then
							return true
						end
					end
				end
			end
			local bearing = math.rad(portal.bearing or 0)
			local dirX = math.sin(bearing)
			local dirZ = math.cos(bearing)
			local sideX = math.cos(bearing)
			local sideZ = -math.sin(bearing)
			for radius = 8, Haven.GATE_RADIUS - 6, 2 do
				for _, side in ipairs({ -5, 0, 5 }) do
					local x = Haven.SPAWN.x + dirX * radius + sideX * side
					local z = Haven.SPAWN.z + dirZ * radius + sideZ * side
					for y = walkLow + 0.5, walkHigh - 0.5, 2 do
						local localPoint = part.CFrame:PointToObjectSpace(vector3(x, y, z))
						if
							math.abs(localPoint.X) <= part.Size.X / 2
							and math.abs(localPoint.Y) <= part.Size.Y / 2
							and math.abs(localPoint.Z) <= part.Size.Z / 2
						then
							return true
						end
					end
				end
			end
			return false
		end

		local promptHosts = {}
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			expect(arch:GetAttribute("GateDress")).toEqual(portal.dress)
			local dressed = false
			local parts = 0
			local lights = 0
			local emitters = 0
			local plate = nil
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("BasePart") then
					parts += 1
				end
				if child:IsA("PointLight") then
					lights += 1
				end
				if child:IsA("ParticleEmitter") then
					emitters += 1
				end
				if child:GetAttribute("GateDress") == portal.dress then
					dressed = true
				end
				if child:IsA("BillboardGui") then
					plate = child
				end
			end
			expect(dressed).toBeTrue()
			expect(lights).toEqual(1)
			local vfx = builder.GATE_VFX[portal.id]
			local expectedEmitters = if vfx ~= nil then #vfx.emitters else 0
			expect(emitters).toEqual(expectedEmitters)
			if parts > 12 then
				error(portal.id .. " has " .. tostring(parts) .. " parts", 2)
			end
			if plate == nil or plate.MaxDistance < 90 or plate.AlwaysOnTop ~= false then
				error(portal.id .. " name plate is not readable from the pad", 2)
			end
			local title = nil
			local subline = nil
			local backing = plate:FindFirstChild("Plate")
			if backing == nil or inkSum(backing.BackgroundColor3) > 80 or backing.BackgroundTransparency > 0.15 then
				error(portal.id .. " name plate is not high contrast", 2)
			end
			for _, child in ipairs(plate:GetDescendants()) do
				if child:IsA("TextLabel") and child.Name == "Title" then
					title = child
				elseif child:IsA("TextLabel") and child.Name == "Subline" then
					subline = child
				end
			end
			if title == nil or title.Text ~= portal.name or title.TextSize < 24 then
				error(portal.id .. " title is missing", 2)
			end
			if title.Font.__enum ~= "Enum.Font.BuilderSansBold" or title.TextStrokeTransparency > 0.2 then
				error(portal.id .. " title is not bold", 2)
			end
			if inkSum(title.TextColor3) < 680 then
				error(portal.id .. " title ink is too dim", 2)
			end
			if subline == nil or subline.Text ~= portal.subline then
				error(portal.id .. " subline is missing", 2)
			end
			if subline.Font.__enum ~= "Enum.Font.BuilderSansBold" then
				error(portal.id .. " subline is not bold", 2)
			end
			local glow = arch:FindFirstChild("EnterPad") or arch:FindFirstChild("Glow")
			if glow == nil then
				error(portal.id .. " has no mouth", 2)
			end
			if not Haven.gateOpen(portal) then
				expect(glow.Transparency).toEqual(0.75)
				expect(arch:FindFirstChild("Seal") ~= nil).toBeTrue()
			else
				expect(glow.Transparency).toEqual(0.35)
				expect(arch:FindFirstChild("Seal")).toBeNil()
				local color = portal.color
				expect(glow.Color.R).toEqual(color[1])
				expect(glow.Color.G).toEqual(color[2])
				expect(glow.Color.B).toEqual(color[3])
			end
			local pillar = arch:FindFirstChild("PillarL")
			if portal.dress == "roots" or portal.dress == "bark" then
				expect(pillar.Material.__enum).toEqual("Enum.Material.Wood")
			elseif portal.dress == "basalt" then
				expect(pillar.Material.__enum).toEqual("Enum.Material.Basalt")
			elseif portal.dress == "ice" then
				expect(pillar.Material.__enum).toEqual("Enum.Material.Ice")
				expect(arch:FindFirstChild("PillarR").Size.Y < pillar.Size.Y - 4).toBeTrue()
			elseif portal.dress == "obsidian" then
				expect(glow.Color.R <= 24 and glow.Color.G <= 24 and glow.Color.B <= 30).toBeTrue()
			end
			local dungeonId = arch:GetAttribute("DungeonId")
			if type(dungeonId) == "string" and liveCounts[dungeonId] ~= nil then
				liveCounts[dungeonId] += 1
			end
			table.insert(promptHosts, glow.CFrame.Position)
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					local host = child.Parent
					if host == nil or closestDistance(host, glow.CFrame.Position) > Haven.GATE_REACH + 6 then
						error(portal.id .. " prompt sits off its arch", 2)
					end
				end
			end
		end
		for id, count in pairs(liveCounts) do
			local dungeon = Dungeons.get(id)
			local expectCount = if dungeon.endless == true then 0 else 1
			if count ~= expectCount then
				error(id .. " has " .. tostring(count) .. " arches", 2)
			end
		end

		local rootArch = findNamed(hub, "rootvault")
		local heartArch = findNamed(hub, "heartwood")
		expect(math.abs(heartArch.PillarL.Size.Y - rootArch.PillarL.Size.Y - 4) < 0.05).toBeTrue()
		local waves = nil
		local heartPrompts = 0
		for _, child in ipairs(rootArch:GetDescendants()) do
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "waves" then
				waves = child
			end
		end
		for _, child in ipairs(heartArch:GetDescendants()) do
			if child:IsA("ProximityPrompt") then
				heartPrompts += 1
			end
		end
		if waves == nil or waves.Parent.Name ~= "PillarL" or waves.ActionText ~= "Waves" then
			error("Waves is not on the Rootvault pier", 2)
		end
		expect(waves.MaxActivationDistance).toEqual(Haven.PIER_REACH)
		expect(LaunchGate.on("raids")).toEqual(false)
		expect(heartPrompts).toEqual(0)
		expect(heartArch:FindFirstChild("PillarL") ~= nil).toBeTrue()

		local inlays = findAll(hub, "Inlay")
		expect(#inlays).toEqual(6)
		table.sort(inlays, function(a, b)
			local aa = math.atan2(a.CFrame.Position.X - Haven.SPAWN.x, a.CFrame.Position.Z - Haven.SPAWN.z)
			local bb = math.atan2(b.CFrame.Position.X - Haven.SPAWN.x, b.CFrame.Position.Z - Haven.SPAWN.z)
			return aa < bb
		end)
		expect(inlays[1]:GetAttribute("GateId")).toEqual("rootvault")
		expect(inlays[1]:GetAttribute("GateLit")).toEqual(true)
		expect(inlays[2]:GetAttribute("GateId")).toEqual("heartwood")
		expect(inlays[2]:GetAttribute("GateLit")).toEqual(true)
		expect(inlays[2].Color.R).toEqual(214)
		expect(inlays[2].Color.G).toEqual(140)
		expect(inlays[2].Color.B).toEqual(64)
		for index = 3, #inlays do
			expect(inlays[index]:GetAttribute("GateLit")).toEqual(false)
		end

		for i = 1, #promptHosts do
			for j = i + 1, #promptHosts do
				local left = promptHosts[i]
				local right = promptHosts[j]
				local dx = left.X - right.X
				local dy = left.Y - right.Y
				local dz = left.Z - right.Z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance <= Haven.GATE_REACH * 2 then
					error("two gate prompts overlap", 2)
				end
			end
		end

		local inlayTop = Haven.FLOOR_Y + Haven.LAYER
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			for _, part in ipairs(hub:GetDescendants()) do
				if part:IsA("BasePart") and partBlocksLane(part, portal) then
					local owner = if part.Parent ~= nil then part.Parent.Name else "?"
					error(
						string.format("%s lane hits %s.%s", portal.name, owner, part.Name),
						2
					)
				end
			end
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					local host = child.Parent
					local center = host.CFrame.Position
					local radius = child.MaxActivationDistance
					for _, part in ipairs(hub:GetDescendants()) do
						if
							part:IsA("BasePart")
							and (part.Transparency == nil or part.Transparency < 1)
							and owningArch(part) ~= arch
						then
							local top = part.CFrame.Position.Y + part.CFrame.YVector.Y * part.Size.Y / 2
							local gap = closestDistance(part, center)
							if top > inlayTop + 0.02 and gap <= radius then
								local owner = if part.Parent ~= nil then part.Parent.Name else "?"
								error(
									string.format(
										"%s %s prompt r=%.1f at (%.1f, %.1f, %.1f) hits %s.%s gap %.2f",
										portal.name,
										tostring(child:GetAttribute("HavenAction")),
										radius,
										center.X,
										center.Y,
										center.Z,
										owner,
										part.Name,
										gap
									),
									2
								)
							end
						end
					end
				end
			end
		end
	end)

	it("caps gate lights and emitters and keeps the walk and prompts clear", function()
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)

		local expected = {
			rootvault = { brightness = 0.45, range = 16, r = 64, g = 196, b = 96, rate = 6, emitters = 1, name = "mist" },
			heartwood = { brightness = 0.35, range = 14, r = 214, g = 140, b = 64, rate = 5, emitters = 1, name = "ash" },
			tidecrypt = { brightness = 0.4, range = 14, r = 36, g = 96, b = 140, rate = 4, emitters = 2, name = "sheet" },
			ember = { brightness = 0.3, range = 12, r = 255, g = 120, b = 40, rate = 6, emitters = 1, name = "sparks" },
			frost = { brightness = 0.4, range = 16, r = 186, g = 228, b = 255, rate = 3, emitters = 1, name = "wisp" },
			void = { brightness = 0.2, range = 10, r = 120, g = 60, b = 180, rate = 0, emitters = 0, name = "" },
		}
		local forbidden = { "flower", "firefly", "face", "sparkle" }
		local function banned(name: string): boolean
			local lower = string.lower(name)
			for _, word in ipairs(forbidden) do
				if string.find(lower, word, 1, true) ~= nil then
					return true
				end
			end
			return false
		end

		local totalEmitters = 0
		local promptHosts = {}
		for _, portal in ipairs(Haven.PORTALS) do
			local spec = expected[portal.id]
			if spec == nil then
				error("missing light spec for " .. portal.id, 2)
			end
			local arch = findNamed(hub, portal.id)
			local lights = 0
			local emitters = 0
			local light = nil
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("PointLight") then
					lights += 1
					light = child
				elseif child:IsA("ParticleEmitter") then
					emitters += 1
					totalEmitters += 1
					if child.Rate > builder.RATE_CAP or child.Rate <= 0 then
						error(portal.id .. " emitter rate is " .. tostring(child.Rate), 2)
					end
					if spec.name ~= "" and child.Name ~= spec.name then
						error(portal.id .. " emitter is " .. tostring(child.Name), 2)
					end
					if spec.rate > 0 and child.Rate ~= spec.rate then
						error(portal.id .. " rate is " .. tostring(child.Rate), 2)
					end
				end
				if banned(child.Name) then
					error(portal.id .. " has a " .. child.Name, 2)
				end
			end
			expect(lights).toEqual(1)
			expect(emitters).toEqual(spec.emitters)
			if light == nil then
				error(portal.id .. " has no light", 2)
			end
			expect(light.Shadows).toEqual(false)
			expect(light.Range <= builder.RANGE_CAP).toBeTrue()
			expect(light.Range).toEqual(spec.range)
			expect(light.Color.R).toEqual(spec.r)
			expect(light.Color.G).toEqual(spec.g)
			expect(light.Color.B).toEqual(spec.b)
			expect(light:GetAttribute("GateBrightness")).toEqual(spec.brightness)
			local glow = arch:FindFirstChild("EnterPad") or arch:FindFirstChild("Glow")
			if glow == nil or glow.Material.__enum ~= "Enum.Material.Neon" or glow.Transparency >= 1 then
				error(portal.id .. " neon mouth does not read", 2)
			end
			if not Haven.gateOpen(portal) then
				expect(light.Enabled).toEqual(false)
				expect(light.Brightness).toEqual(0)
				expect(glow.Transparency).toEqual(0.75)
				local seal = arch:FindFirstChild("Seal")
				if seal == nil or seal.Transparency >= 0.2 then
					error(portal.id .. " seal does not read with particles off", 2)
				end
			else
				expect(light.Enabled).toEqual(true)
				expect(light.Brightness).toEqual(spec.brightness)
				expect(glow.Transparency).toEqual(0.35)
				expect(arch:FindFirstChild("Seal")).toBeNil()
			end
			table.insert(promptHosts, glow.CFrame.Position)
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("ProximityPrompt") then
					local reach = child.MaxActivationDistance
					local hostName = if child.Parent ~= nil then child.Parent.Name else ""
					local onMouth = hostName == "EnterPad" or hostName == "Glow"
					local onPier = hostName == "PillarL"
					if onMouth and reach ~= Haven.GATE_REACH then
						error(portal.id .. " mouth prompt reach changed", 2)
					elseif onPier and reach ~= Haven.PIER_REACH then
						error(portal.id .. " pier prompt reach changed", 2)
					elseif not onMouth and not onPier then
						error(portal.id .. " prompt moved onto " .. hostName, 2)
					end
				end
			end
		end
		if totalEmitters > builder.EMITTER_CAP then
			error("gate emitters " .. tostring(totalEmitters) .. " exceed the cap", 2)
		end
		expect(totalEmitters).toEqual(6)
		local voidArch = findNamed(hub, "void")
		for _, child in ipairs(voidArch:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				error("void has an emitter", 2)
			end
		end
		local root = findNamed(hub, "rootvault")
		local shaft = root:FindFirstChild("Shaft")
		if shaft == nil or shaft.Transparency ~= 0.5 or shaft.Size.X ~= 1 or shaft.Size.Z ~= 1 then
			error("rootvault shaft is not the 1-stud noon column", 2)
		end
		expect(findNamed(hub, "heartwood"):FindFirstChild("Shaft")).toBeNil()

		local mist = nil
		local sparks = nil
		for _, child in ipairs(root:GetDescendants()) do
			if child:IsA("ParticleEmitter") and child.Name == "mist" then
				mist = child
			end
		end
		for _, child in ipairs(findNamed(hub, "ember"):GetDescendants()) do
			if child:IsA("ParticleEmitter") and child.Name == "sparks" then
				sparks = child
			end
		end
		if mist == nil or mist.Lifetime.Min ~= 1.2 or mist.Lifetime.Max ~= 2 then
			error("rootvault mist lifetime is not 1.2–2.0", 2)
		end
		if sparks == nil or sparks.Lifetime.Min ~= 0.3 or sparks.Lifetime.Max ~= 0.6 then
			error("ember sparks lifetime is not 0.3–0.6", 2)
		end

		local ring = findNamed(hub, "CourtRing")
		if ring == nil then
			error("court ring is missing", 2)
		end
		local guides = 0
		local litGuides = 0
		local walkLow = Haven.FLOOR_Y + 1.25
		for _, child in ipairs(ring:GetDescendants()) do
			if child:IsA("PointLight") or child:IsA("ParticleEmitter") or child:IsA("ProximityPrompt") then
				error("court ring adds a " .. child.ClassName, 2)
			end
			if banned(child.Name) then
				error("court has a " .. child.Name, 2)
			end
			if child.Name == "CourtGuide" then
				guides += 1
				if child.CanCollide == true or child.CastShadow == true then
					error("court guide collides or casts a shadow", 2)
				end
				local _x0, _minY, _z0, _x1, maxY = worldBox(child)
				if maxY > walkLow then
					error(string.format("court guide rises into the walk at y %.2f", maxY), 2)
				end
				if child:GetAttribute("GateLit") == true then
					litGuides += 1
					local gateId = child:GetAttribute("GateId")
					local marked = if type(gateId) == "string" then Haven.portal(gateId) else nil
					if marked == nil or Haven.gateOpen(marked) ~= true or child.Transparency >= 0.5 then
						error("open court guide is not a bright live-gate mark", 2)
					end
					local color = marked.color
					if child.Color.R ~= color[1] or child.Color.G ~= color[2] or child.Color.B ~= color[3] then
						error(tostring(gateId) .. " court guide is not that gate's color", 2)
					end
				elseif child.Transparency < 0.8 then
					error("sealed court guide is too bright", 2)
				end
			end
		end
		-- Six ring ticks, plus one path toward each open gate.
		expect(guides).toEqual(8)
		expect(litGuides).toEqual(4)

		for i = 1, #promptHosts do
			for j = i + 1, #promptHosts do
				local left = promptHosts[i]
				local right = promptHosts[j]
				local dx = left.X - right.X
				local dy = left.Y - right.Y
				local dz = left.Z - right.Z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if distance <= Haven.GATE_REACH * 2 then
					error("two gate prompts overlap", 2)
				end
			end
		end

		local pulsed = builder.mouthLook(0.45, 0.35, false, 0.15, 0.75, nil, false)
		requireNear(pulsed.brightness, 0.525, 0.002, "open pulse")
		expect(pulsed.enabled).toEqual(true)
		expect(pulsed.particles).toEqual(true)
		expect(pulsed.transparency).toEqual(0.35)
		local approached = builder.mouthLook(0.45, 0.35, false, 0.15, 0, 12, false)
		requireNear(approached.brightness, 0.63, 0.002, "approach brighten")
		requireNear(approached.transparency, 0.2, 0.002, "approach neon")
		local outside = builder.mouthLook(0.45, 0.35, false, 0.15, 0, 12.01, false)
		expect(outside.transparency).toEqual(0.35)
		requireNear(outside.brightness, 0.45, 0.002, "outside approach")
		local quiet = builder.mouthLook(0.45, 0.35, false, 0.15, 0.75, 4, true)
		requireNear(quiet.brightness, 0.63, 0.002, "reduced approach")
		expect(quiet.particles).toEqual(false)
		local sealed = builder.mouthLook(0.35, 0.75, true, 0.15, 0.75, nil, false)
		expect(sealed.enabled).toEqual(false)
		expect(sealed.brightness).toEqual(0)
		expect(sealed.transparency).toEqual(0.75)
		expect(sealed.particles).toEqual(true)
		local sealedNear = builder.mouthLook(0.35, 0.75, true, 0.15, 0.75, 6, false)
		expect(sealedNear.enabled).toEqual(true)
		expect(sealedNear.brightness).toEqual(builder.SEALED_NEAR)
		requireNear(sealedNear.transparency, 0.62, 0.002, "sealed approach")
		local sealedQuiet = builder.mouthLook(0.35, 0.75, true, 0, 0, nil, true)
		expect(sealedQuiet.particles).toEqual(false)
		expect(sealedQuiet.enabled).toEqual(false)

		local rootGlow = root:FindFirstChild("EnterPad")
		local rootLight = rootGlow:FindFirstChild("PointLight")
		builder.stepGates(0.75, {})
		requireNear(rootLight.Brightness, 0.525, 0.002, "stepped pulse")
		expect(rootGlow.Transparency).toEqual(0.35)
		local heart = findNamed(hub, "heartwood")
		local heartGlow = heart:FindFirstChild("Glow")
		local heartLight = heartGlow:FindFirstChild("PointLight")
		expect(heartLight.Enabled).toEqual(true)
		requireNear(heartLight.Brightness, 0.425, 0.002, "heartwood pulse")
		expect(heartGlow.Transparency).toEqual(0.35)
		expect(heartGlow.Color.R).toEqual(214)
		expect(heartGlow.Color.G).toEqual(140)
		expect(heartGlow.Color.B).toEqual(64)
		expect(heart:FindFirstChild("Seal")).toBeNil()
		local mouth = rootGlow.CFrame.Position
		builder.stepGates(0, {
			{ x = mouth.X, z = mouth.Z, reduced = false },
		})
		requireNear(rootLight.Brightness, 0.705, 0.002, "stepped approach")
		requireNear(rootGlow.Transparency, 0.2, 0.002, "stepped neon")
		builder.stepGates(0, {
			{ x = Haven.SPAWN.x, z = Haven.SPAWN.z, reduced = true },
		})
		expect(mist.Enabled).toEqual(false)
		requireNear(rootLight.Brightness, 0.45, 0.002, "quiet holds the rest brightness")
		local heartAt = heartGlow.CFrame.Position
		builder.stepGates(0, {
			{ x = heartAt.X, z = heartAt.Z + 6, reduced = false },
		})
		expect(heartLight.Enabled).toEqual(true)
		requireNear(heartLight.Brightness, 0.605, 0.002, "heartwood approach")
		requireNear(heartGlow.Transparency, 0.2, 0.002, "heartwood approach neon")
		expect(heart:FindFirstChild("Seal")).toBeNil()
		local tide = findNamed(hub, "tidecrypt")
		local tideGlow = tide:FindFirstChild("Glow")
		local tideLight = tideGlow:FindFirstChild("PointLight")
		local tideAt = tideGlow.CFrame.Position
		builder.stepGates(0, {
			{ x = tideAt.X, z = tideAt.Z + 6, reduced = false },
		})
		expect(tideLight.Enabled).toEqual(true)
		expect(tideLight.Brightness).toEqual(builder.SEALED_NEAR)
		expect(tide:FindFirstChild("Seal") ~= nil).toBeTrue()
		expect(tideGlow.Transparency > 0.6).toBeTrue()
	end)

	it("matches each gate's seal and court ring to its live prompt", function()
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)
		local ring = findNamed(hub, "CourtRing")
		if ring == nil then
			error("court ring is missing", 2)
		end
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			local glow = arch:FindFirstChild("EnterPad") or arch:FindFirstChild("Glow")
			if glow == nil then
				error(portal.id .. " has no mouth", 2)
			end
			local prompt = nil
			for _, child in ipairs(glow:GetDescendants()) do
				if child:IsA("ProximityPrompt") and child.Parent == glow then
					prompt = child
				end
			end
			local live = false
			if portal.id == "heartwood" and not LaunchGate.on("raids") then
				if prompt ~= nil then
					error("heartwood mouth still has a raid prompt", 2)
				end
				live = true
			elseif prompt == nil then
				error(portal.id .. " mouth has no prompt", 2)
			else
				live = prompt:GetAttribute("HavenAction") ~= "soon"
			end
			local seal = arch:FindFirstChild("Seal")
			local segment = false
			local litSegment = false
			for _, child in ipairs(ring:GetDescendants()) do
				if child.Name == "CourtGuide" and child:GetAttribute("GateId") == portal.id then
					segment = true
					if child:GetAttribute("GateLit") == true and child.Transparency < 0.5 then
						litSegment = true
					end
				end
			end
			local plate = nil
			for _, child in ipairs(arch:GetDescendants()) do
				if child:IsA("TextLabel") and child.Name == "Subline" then
					plate = child.Text
				end
			end
			if live then
				if seal ~= nil then
					error(portal.id .. " live prompt still has a seal bar", 2)
				end
				if not litSegment then
					error(portal.id .. " live prompt has no lit ring segment", 2)
				end
				if type(plate) ~= "string" or string.find(plate, "Sealed", 1, true) ~= nil then
					error(portal.id .. " name plate says Sealed", 2)
				end
				expect(string.find(plate, tostring(portal.level), 1, true) ~= nil).toBeTrue()
			else
				if seal == nil or not segment then
					error(portal.id .. " sealed prompt is missing its seal or ring segment", 2)
				end
				if litSegment then
					error(portal.id .. " sealed prompt lights a ring segment", 2)
				end
				if type(plate) ~= "string" or string.find(plate, "Sealed", 1, true) == nil then
					error(portal.id .. " sealed name plate dropped Sealed", 2)
				end
			end
		end
	end)

	it("keeps every island rock from catching a fall", function()
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Hub"
		builder.build(hub)
		local islands = { "BossPlaza", "Forge", "Market", "GuildHall", "PetGarden", "Observatory" }
		local rocks = 0
		for _, name in ipairs(islands) do
			local model = findNamed(hub, name)
			expect(model ~= nil).toBeTrue()
			local rock = model:FindFirstChild("Rock")
			local ground = model:FindFirstChild("Ground")
			expect(rock ~= nil and rock:IsA("BasePart")).toBeTrue()
			expect(ground ~= nil and ground:IsA("BasePart")).toBeTrue()
			expect(rock.CanCollide).toEqual(false)
			expect(ground.CanCollide).toEqual(true)
			rocks += 1
		end
		expect(rocks).toEqual(#islands)
		for _, descendant in ipairs(hub:GetDescendants()) do
			if descendant.Name == "Rock" then
				expect(descendant.CanCollide).toEqual(false)
			end
		end
	end)

	it("builds no Training Grove dummy while grove is parked", function()
		expect(LaunchGate.on("grove")).toEqual(false)
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)
		expect(#findAll(hub, "GroveDummy")).toEqual(0)
	end)

	it("stands a readable training dummy off the gate lanes", function()
		LaunchGate.SHOW.grove = true
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)
		LaunchGate.SHOW.grove = false

		local dummies = findAll(hub, "GroveDummy")
		expect(#dummies).toEqual(1)
		local dummy = dummies[1]
		expect(dummy:GetAttribute("GroveId")).toEqual("grove")

		local post = dummy:FindFirstChild("Post")
		local straw = dummy:FindFirstChild("Straw")
		local head = dummy:FindFirstChild("Head")
		local target = dummy:FindFirstChild("Target")
		local backing = dummy:FindFirstChild("TargetBack")
		expect(post ~= nil).toBeTrue()
		expect(straw ~= nil).toBeTrue()
		expect(head ~= nil).toBeTrue()
		expect(target ~= nil).toBeTrue()
		expect(backing ~= nil).toBeTrue()
		expect(post.CanCollide).toEqual(true)
		expect(straw.CanCollide).toEqual(false)
		expect(head.CanCollide).toEqual(false)
		expect(target.CanCollide).toEqual(false)
		expect(post.Size.X <= 1.2 and post.Size.Z <= 1.2).toBeTrue()
		expect(math.abs(post.CFrame.Position.X - Haven.GROVE.x) < 0.05).toBeTrue()
		expect(math.abs(post.CFrame.Position.Z - Haven.GROVE.z) < 0.05).toBeTrue()
		expect(target.CFrame.Position.Z < post.CFrame.Position.Z).toBeTrue()
		expect(target.Material.__enum ~= "Enum.Material.Neon").toBeTrue()
		expect(backing.Material.__enum ~= "Enum.Material.Neon").toBeTrue()
		local contrast = math.abs(target.Color.R - straw.Color.R)
			+ math.abs(target.Color.G - straw.Color.G)
			+ math.abs(target.Color.B - straw.Color.B)
		expect(contrast >= 180).toBeTrue()
		expect(target.Color.G > target.Color.R).toBeTrue()

		local prompts = 0
		local title = nil
		local subline = nil
		local plate = nil
		for _, child in ipairs(dummy:GetDescendants()) do
			if child:IsA("ProximityPrompt") then
				prompts += 1
				expect(child:GetAttribute("HavenAction")).toEqual("grove")
				expect(child.ActionText).toEqual("Train")
				expect(child.ObjectText).toEqual("Training Grove")
				expect(child.MaxActivationDistance).toEqual(8)
			elseif child:IsA("PointLight") or child:IsA("ParticleEmitter") or child:IsA("Decal") or child:IsA("SurfaceGui") then
				error("grove dummy has " .. child.ClassName, 2)
			elseif child:IsA("TextLabel") and child.Name == "Title" then
				title = child
			elseif child:IsA("TextLabel") and child.Name == "Subline" then
				subline = child
			elseif child:IsA("Frame") and child.Name == "Plate" then
				plate = child
			elseif child:IsA("BillboardGui") then
				expect(child.AlwaysOnTop).toEqual(false)
				expect(child.LightInfluence).toEqual(0)
				expect(child.MaxDistance >= 90).toBeTrue()
			end
		end
		expect(prompts).toEqual(1)
		expect(title.Text).toEqual("Training Grove")
		expect(subline.Text).toEqual("Hit the dummy")
		expect(title.TextStrokeTransparency).toEqual(0)
		expect(title.TextColor3.R + title.TextColor3.G + title.TextColor3.B >= 700).toBeTrue()
		expect(plate.BackgroundTransparency < 0.2).toBeTrue()
	end)

	it("leaves the Heartwood arch and omits Finder and Practice while raids are closed", function()
		expect(LaunchGate.on("raids")).toEqual(false)
		local builder, _heartbeats, _workspace = loadBuilder()
		local hub = instance("Model")
		hub.Name = "Haven"
		builder.build(hub)
		local arch = findNamed(hub, "heartwood")
		expect(arch:FindFirstChild("PillarL") ~= nil).toBeTrue()
		expect(arch:FindFirstChild("PillarR") ~= nil).toBeTrue()
		expect(arch:FindFirstChild("Lintel") ~= nil).toBeTrue()
		expect(arch:FindFirstChild("Glow") ~= nil).toBeTrue()
		expect(arch:FindFirstChild("Seal")).toBeNil()
		expect(arch:FindFirstChild("EnterPad")).toBeNil()
		for _, child in ipairs(arch:GetDescendants()) do
			if child:IsA("ProximityPrompt") then
				error("Heartwood still has a " .. tostring(child.ActionText) .. " prompt", 2)
			end
		end
		local root = findNamed(hub, "rootvault")
		local enter = nil
		local waves = nil
		for _, child in ipairs(root:GetDescendants()) do
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "rootvault" then
				enter = child
			elseif child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "waves" then
				waves = child
			end
		end
		expect(enter ~= nil and enter.ActionText == "Enter").toBeTrue()
		expect(waves ~= nil and waves.ActionText == "Waves").toBeTrue()
	end)
end)
