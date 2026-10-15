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
		expect(baseplate.Parent).toBeNil()
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
						elseif part.Name == "Bridge" then
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

		local bridges = findAll(hub, "Bridge")
		local goals = {}
		for _, district in ipairs(Haven.DISTRICTS) do
			table.insert(goals, {
				name = district.name,
				x = district.x,
				z = district.z,
				radius = district.radius,
			})
		end
		local shelfZ = Haven.PORTALS[1].z
		local shelf = findNamed(hub, "RealmArches"):FindFirstChild("Ground")
		table.insert(goals, {
			name = "portal shelf",
			x = 0,
			z = shelfZ,
			radius = shelf.Size.Z / 2,
		})
		if #bridges < #goals then
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
		end

		walk(Haven.SPAWN.x, Haven.SPAWN.z, 0, 0, "spawn to plaza")
		for _, goal in ipairs(goals) do
			local rimX, rimZ = approach(0, 0, goal.x, goal.z, Haven.PLAZA_RADIUS)
			local farX, farZ = approach(goal.x, goal.z, 0, 0, goal.radius)
			walk(Haven.SPAWN.x, Haven.SPAWN.z, rimX, rimZ, "spawn to " .. goal.name)
			walk(rimX, rimZ, goal.x, goal.z, goal.name)
			local function onto(cx: number, cz: number, rx: number, rz: number)
				local dx = cx - rx
				local dz = cz - rz
				local distance = math.sqrt(dx * dx + dz * dz)
				local ox = rx + dx / distance * 2
				local oz = rz + dz / distance * 2
				if not onBridge(ox, oz) then
					error(goal.name .. " bridge overlaps the floor by less than 2 studs", 2)
				end
			end
			onto(0, 0, rimX, rimZ)
			onto(goal.x, goal.z, farX, farZ)
		end

		local left = Haven.PORTALS[1]
		local right = Haven.PORTALS[#Haven.PORTALS]
		walk(left.x, left.z, right.x, right.z, "portal row")
		local names = {
			verdant = "Verdant Wilds",
			sunken = "Sunken Reach",
			ember = "Emberforge",
			frost = "Frostveil",
			void = "Void Rift",
		}
		for _, portal in ipairs(Haven.PORTALS) do
			local arch = findNamed(hub, portal.id)
			local labeled = false
			for _, child in ipairs(arch:GetDescendants()) do
				if child:GetAttribute("HavenLabel") == names[portal.id] then
					labeled = true
				end
				if child.Name == "Sign" and child.CanCollide == true then
					error(portal.name .. " sign can be stood on", 2)
				end
			end
			if not labeled then
				error(portal.id .. " is not labeled " .. names[portal.id], 2)
			end
			if not supported(portal.x, portal.z) then
				error(portal.name .. " arch is not on the shelf", 2)
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
		for _, child in ipairs(hub:GetDescendants()) do
			if child:GetAttribute("HavenLabel") == "Armory" then
				armoryLabel = true
			end
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "armory" then
				armoryPrompt = true
			end
			if child:IsA("ProximityPrompt") and child:GetAttribute("HavenAction") == "pets" then
				petsPrompt = true
			end
		end
		expect(armoryLabel).toBeTrue()
		expect(armoryPrompt).toBeTrue()
		expect(petsPrompt).toBeTrue()

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
	end)
end)
