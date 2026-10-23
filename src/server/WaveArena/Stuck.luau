--!strict

--[[
	An enemy who has not moved `epsilon` studs for `seconds` is stuck.
	Recovery steps them toward the arena centre. If that step is shorter
	than minShift, the caller removes them so the wave can finish.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")
local Spawns = require("./Spawns")

local Stuck = {}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

local function length(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

function Stuck.stalled(body: any, dt: number, seconds: number, epsilon: number): boolean
	local dx = body.x - body.anchorX
	local dz = body.z - body.anchorZ
	if dx == dx and dz == dz and dx * dx + dz * dz > epsilon * epsilon then
		body.anchorX = body.x
		body.anchorZ = body.z
		body.stillFor = 0
		return false
	end
	body.stillFor += dt
	return body.stillFor >= seconds
end

-- Returns the candidate point and "teleport" or "despawn".
function Stuck.recover(body: any, config: any?): (number, number, string)
	local cfg = cfgOf(config)
	local step = cfg.stuck.teleportStuds
	local minShift = cfg.stuck.minShift
	local x = body.x
	local z = body.z
	local dist = length(x, z)
	local nx = 0
	local nz = 0
	if dist == dist and dist > step then
		local scale = (dist - step) / dist
		nx = x * scale
		nz = z * scale
	end
	local inner = Spawns.innerRadius(cfg)
	nx, nz = Spawns.insideFloor(nx, nz, body.radius, inner, cfg.spawn.margin)
	local dx = nx - x
	local dz = nz - z
	if dx ~= dx or dx * dx + dz * dz < minShift * minShift then
		return x, z, "despawn"
	end
	return nx, nz, "teleport"
end

return Stuck
