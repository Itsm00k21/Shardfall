--!strict

--[[
	Gray-box pool for the gated wave flow.

	One anchored block stands in for each alive enemy. A death parks
	that block. The next spawn reuses it and clears health, target,
	projectile, every attribute, and every child. Release does not
	destroy the block. Destroy runs only when the pool itself is
	destroyed at the end of a run.

	WaveFlowService is the only caller, and only while enemyTypes is on.
	This module does not read a profile, fire a remote, or touch the HUD.
	With no DataModel (the test runner) the block is a plain table.
]]

local Enemies
if game ~= nil and game.GetService ~= nil then
	Enemies = require(game:GetService("ReplicatedStorage").Shared.Config.Enemies)
else
	Enemies = require("../../ReplicatedStorage/Shared/Config/Enemies")
end

local EnemyPool = {}

export type Body = {
	kind: string,
	health: number,
	target: any,
	projectile: any,
	part: any,
	live: boolean,
}

export type Stats = {
	created: number,
	inUse: number,
	free: number,
}

export type Pool = {
	acquire: (string) -> Body,
	release: (Body) -> (),
	bind: (number, string, any) -> Body,
	releaseExcept: ({ [number]: boolean }) -> (),
	body: (number) -> Body?,
	stats: () -> Stats,
	destroy: () -> (),
}

local docked: any = nil

local function dock(): any
	if game == nil or game.GetService == nil then
		return nil
	end
	if docked ~= nil and docked.Parent ~= nil then
		return docked
	end
	local found = workspace:FindFirstChild("WaveEnemyPool")
	if found ~= nil and found:IsA("Folder") then
		docked = found
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = "WaveEnemyPool"
	folder.Parent = workspace
	docked = folder
	return folder
end

local function defaultMake(kind: string): any
	if game ~= nil and game.GetService ~= nil then
		local part = Instance.new("Part")
		part.Name = kind
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		return part
	end
	local part = {
		Name = kind,
		health = 0,
		target = nil,
		projectile = nil,
		attributes = {},
		children = {},
		destroyed = false,
	}
	function part:GetAttributes(): { [string]: any }
		local copy = {}
		for key, value in pairs(self.attributes) do
			if value ~= nil then
				copy[key] = value
			end
		end
		return copy
	end
	function part:SetAttribute(name: string, value: any)
		self.attributes[name] = value
	end
	function part:GetChildren(): { any }
		return self.children
	end
	function part:Destroy()
		if self.destroyed == true then
			return
		end
		self.destroyed = true
		self.Parent = nil
		local kids = self.children
		self.children = {}
		self.attributes = {}
		for _, child in ipairs(kids) do
			if type(child) == "table" and type(child.Destroy) == "function" then
				child:Destroy()
			end
		end
	end
	return part
end

local function readAttributes(part: any): { [string]: any }
	if type(part) == "table" and type(part.GetAttributes) == "function" then
		return part:GetAttributes()
	end
	if type(part) == "table" and type(part.attributes) == "table" then
		return part.attributes
	end
	if typeof(part) == "Instance" then
		return part:GetAttributes()
	end
	return {}
end

local function writeAttribute(part: any, name: string, value: any)
	if type(part) == "table" and type(part.SetAttribute) == "function" then
		part:SetAttribute(name, value)
		return
	end
	if type(part) == "table" and type(part.attributes) == "table" then
		part.attributes[name] = value
		return
	end
	if typeof(part) == "Instance" then
		part:SetAttribute(name, value)
	end
end

local function readChildren(part: any): { any }
	if type(part) == "table" and type(part.GetChildren) == "function" then
		return part:GetChildren()
	end
	if type(part) == "table" and type(part.children) == "table" then
		return part.children
	end
	if typeof(part) == "Instance" then
		return part:GetChildren()
	end
	return {}
end

-- Attributes go to nil. Children are destroyed. The part itself stays.
local function clearAttributesAndChildren(part: any)
	if part == nil then
		return
	end
	local names = {}
	for name in pairs(readAttributes(part)) do
		table.insert(names, name)
	end
	for _, name in ipairs(names) do
		writeAttribute(part, name, nil)
	end
	local kids = readChildren(part)
	local copy = {}
	for _, child in ipairs(kids) do
		table.insert(copy, child)
	end
	for _, child in ipairs(copy) do
		local tableDestroy = type(child) == "table" and type(child.Destroy) == "function"
		if tableDestroy or typeof(child) == "Instance" then
			child:Destroy()
		end
	end
	if type(part) == "table" and type(part.children) == "table" then
		table.clear(part.children)
	end
end

local function writePart(part: any, kind: string, health: number)
	clearAttributesAndChildren(part)
	if type(part) == "table" then
		part.Name = kind
		part.health = health
		part.target = nil
		part.projectile = nil
	end
	if typeof(part) == "Instance" then
		part.Name = kind
	end
	writeAttribute(part, "Health", health)
	writeAttribute(part, "Target", nil)
end

local function reset(body: Body, kind: string)
	local row = Enemies.row(kind)
	local health = if row ~= nil then row.maxHealth else 0
	body.kind = kind
	body.health = health
	body.target = nil
	body.projectile = nil
	body.live = true
	writePart(body.part, kind, health)
end

local function park(part: any)
	clearAttributesAndChildren(part)
	if type(part) == "table" then
		part.health = 0
		part.target = nil
		part.projectile = nil
		part.Parent = nil
	end
	writeAttribute(part, "Health", 0)
	writeAttribute(part, "Target", nil)
	if typeof(part) == "Instance" then
		part.Parent = nil
	end
end

local function destroyPart(part: any)
	if part == nil then
		return
	end
	clearAttributesAndChildren(part)
	if type(part) == "table" and type(part.Destroy) == "function" then
		part:Destroy()
		return
	end
	if typeof(part) == "Instance" then
		part:Destroy()
	end
end

local function place(body: Body, spot: any)
	local part = body.part
	if part == nil or type(spot) ~= "table" then
		return
	end
	if game == nil or game.GetService == nil or typeof(part) ~= "Instance" then
		return
	end
	if type(spot.size) == "table" and type(spot.color) == "table" then
		part.Size = Vector3.new(spot.size[1], spot.size[2], spot.size[3])
		part.Color = Color3.fromRGB(spot.color[1], spot.color[2], spot.color[3])
	end
	if type(spot.x) == "number" and type(spot.y) == "number" and type(spot.z) == "number" then
		part.Position = Vector3.new(spot.x, spot.y, spot.z)
	end
	local parent = dock()
	if parent ~= nil then
		part.Parent = parent
	end
end

function EnemyPool.create(make: ((string) -> any)?): Pool
	local factory = if make ~= nil then make else defaultMake
	local freeList: { Body } = {}
	local byId: { [number]: Body } = {}
	local made: { Body } = {}
	local created = 0
	local out = 0

	local function acquire(kind: string): Body
		local body = table.remove(freeList)
		if body == nil then
			body = {
				kind = kind,
				health = 0,
				target = nil,
				projectile = nil,
				part = factory(kind),
				live = false,
			}
			created += 1
			table.insert(made, body)
		end
		reset(body, kind)
		out += 1
		return body
	end

	local function release(body: Body)
		if body.live ~= true then
			return
		end
		body.live = false
		body.target = nil
		body.projectile = nil
		body.health = 0
		park(body.part)
		out -= 1
		table.insert(freeList, body)
	end

	local function bind(id: number, kind: string, spot: any): Body
		local current = byId[id]
		if current ~= nil then
			return current
		end
		local body = acquire(kind)
		byId[id] = body
		place(body, spot)
		return body
	end

	local function releaseExcept(living: { [number]: boolean })
		local stale = {}
		for id in pairs(byId) do
			if living[id] ~= true then
				table.insert(stale, id)
			end
		end
		for _, id in ipairs(stale) do
			local body = byId[id]
			byId[id] = nil
			if body ~= nil then
				release(body)
			end
		end
	end

	local function bodyOf(id: number): Body?
		return byId[id]
	end

	local function stats(): Stats
		return {
			created = created,
			inUse = out,
			free = #freeList,
		}
	end

	local function destroy()
		local doomed = table.clone(made)
		table.clear(made)
		table.clear(freeList)
		local ids = {}
		for id in pairs(byId) do
			table.insert(ids, id)
		end
		for _, id in ipairs(ids) do
			byId[id] = nil
		end
		out = 0
		created = 0
		for _, body in ipairs(doomed) do
			body.live = false
			body.target = nil
			body.projectile = nil
			body.health = 0
			local part = body.part
			body.part = nil
			destroyPart(part)
		end
	end

	return {
		acquire = acquire,
		release = release,
		bind = bind,
		releaseExcept = releaseExcept,
		body = bodyOf,
		stats = stats,
		destroy = destroy,
	}
end

return EnemyPool
