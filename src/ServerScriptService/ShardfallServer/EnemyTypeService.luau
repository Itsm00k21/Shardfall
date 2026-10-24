--!strict

--[[
	Server owner for the V1 chaser, ranged, and tank.

	LaunchGate.SHOW.enemyTypes ships false. While it is off, spawn, step,
	hurt, and present do nothing: no movement, no damage, no gray box.
	init.server does not call this module, so a normal boot never builds
	a part. There is no remote and no profile write.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel.
]]

local LaunchGate
local EnemyRoster
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	EnemyRoster = require(Shared.EnemyRoster)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	EnemyRoster = require("../../ReplicatedStorage/Shared/EnemyRoster")
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

function EnemyTypeService.step(actor: EnemyRoster.Actor, targetX: number, targetZ: number, dt: number): number
	if not EnemyTypeService.open() then
		return 0
	end
	return EnemyRoster.step(actor, targetX, targetZ, dt)
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
