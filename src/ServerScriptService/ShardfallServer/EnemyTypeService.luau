--!strict

--[[
	Server owner for the V1 chaser, ranged, and tank.

	LaunchGate.SHOW.enemyTypes ships false. While it is off, spawn, step,
	hurt, and present do nothing: no movement, no damage, no gray box.
	init.server does not call this module, so a normal boot never builds
	a part. While the flag is on, a ranged shot is checked with a
	Workspace raycast before damage. There is no remote and no profile write.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel.
]]

local LaunchGate
local EnemyRoster
local Enemies
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	EnemyRoster = require(Shared.EnemyRoster)
	Enemies = require(Shared.Config.Enemies)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	EnemyRoster = require("../../ReplicatedStorage/Shared/EnemyRoster")
	Enemies = require("../../ReplicatedStorage/Shared/Config/Enemies")
end

local EnemyTypeService = {}

function EnemyTypeService.open(): boolean
	return LaunchGate.on("enemyTypes")
end

function EnemyTypeService.spawn(kind: string, x: number, z: number): EnemyRoster.Actor?
	if not EnemyTypeService.open() then
		return nil
	end
	return EnemyRoster.spawn(kind, x, z)
end

-- Server ray from muzzle to aim. A hit that is not the two bodies blocks
-- the shot. No DataModel (the test runner) is a clear lane. A raycast
-- error fails closed so a broken cast cannot grant damage.
local function worldBlocked(x0: number, z0: number, x1: number, z1: number): boolean
	if game == nil or game.GetService == nil then
		return false
	end
	local dx = x1 - x0
	local dz = z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	local pad = Enemies.LOS_PAD
	if length <= pad * 2 then
		return false
	end
	local scale = pad / length
	local origin = Vector3.new(x0 + dx * scale, Enemies.SHOT_Y, z0 + dz * scale)
	local direction = Vector3.new(dx * (1 - scale * 2), 0, dz * (1 - scale * 2))
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		return workspace:Raycast(origin, direction, params)
	end)
	if not ok then
		return true
	end
	return hit ~= nil
end

function EnemyTypeService.step(
	actor: EnemyRoster.Actor,
	targetX: number,
	targetZ: number,
	dt: number,
	blocked: EnemyRoster.Cast?
): number
	if not EnemyTypeService.open() then
		return 0
	end
	local function sight(x0: number, z0: number, x1: number, z1: number): boolean
		if blocked ~= nil and blocked(x0, z0, x1, z1) == true then
			return true
		end
		return worldBlocked(x0, z0, x1, z1)
	end
	return EnemyRoster.step(actor, targetX, targetZ, dt, sight)
end

function EnemyTypeService.hurt(actor: EnemyRoster.Actor, raw: number): number
	if not EnemyTypeService.open() then
		return 0
	end
	return EnemyRoster.hurt(actor, raw)
end

-- build is called once per type, with a block spec, only while the flag is on.
function EnemyTypeService.present(build: ((EnemyRoster.Box) -> any)?): { [string]: any }?
	if not EnemyTypeService.open() then
		return nil
	end
	local made = {}
	for index, kind in ipairs(EnemyRoster.order()) do
		local box = EnemyRoster.graybox(kind, index)
		if box == nil then
			return nil
		end
		if build ~= nil then
			made[kind] = build(box)
		else
			made[kind] = box
		end
	end
	return made
end

return EnemyTypeService
