--!strict

--[[
	Gray-box pool for the gated wave flow.

	One anchored block stands in for each alive enemy. A death parks
	that block. The next spawn reuses it and clears health, target, and
	projectile. Nothing on this path calls Destroy.

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
	return {
		Name = kind,
		health = 0,
		target = nil,
		projectile = nil,
	}
end

local function writePart(part: any, kind: string, health: number)
	if type(part) == "table" then
		part.Name = kind
		part.health = health
		part.target = nil
		part.projectile = nil
	end
	if game == nil or game.GetService == nil or typeof(part) ~= "Instance" then
		return
	end
	part.Name = kind
	part:SetAttribute("Health", health)
	part:SetAttribute("Target", nil)
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
	if type(part) == "table" then
		part.health = 0
		part.target = nil
		part.projectile = nil
		part.Parent = nil
	end
	if game == nil or game.GetService == nil or typeof(part) ~= "Instance" then
		return
	end
	part:SetAttribute("Health", 0)
	part:SetAttribute("Target", nil)
	part.Parent = nil
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

	return {
		acquire = acquire,
		release = release,
		bind = bind,
		releaseExcept = releaseExcept,
		body = bodyOf,
		stats = stats,
	}
end

return EnemyPool
