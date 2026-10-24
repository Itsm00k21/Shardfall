--!strict

--[[
	Spawn points and clearance.

	A footprint is clamped inside the round floor with a margin, then tested
	against wall segments, gate posts, and footprints already placed. If it
	hits, it steps toward the centre (the same step the Rootvault clearance
	pass used) until it is clear or the try count runs out.

	The floor slab is not a solid. Spawns stand on it.
]]

local function sharedRoot()
	if game ~= nil and game.GetService ~= nil then
		local folder = script.Parent
		if folder ~= nil and folder.Name == "server" then
			return require(folder:WaitForChild("SharedRequire"))
		end
		if folder ~= nil and folder.Parent ~= nil then
			return require(folder.Parent:WaitForChild("SharedRequire"))
		end
		error("SharedRequire is not beside this module")
	end
	local source = debug.info(1, "s")
	local marker = "src/server/"
	local at = string.find(source, marker, 1, true)
	if at == nil then
		error("SharedRequire could not see src/server in " .. source)
	end
	local rest = string.sub(source, at + #marker)
	local _, slashes = string.gsub(rest, "/", "")
	if slashes == 0 then
		return require("./SharedRequire")
	end
	local prefix = ""
	local parent = string.char(46, 46)
	for _ = 1, slashes do
		prefix ..= parent .. "/"
	end
	return require(prefix .. "SharedRequire")
end

local SharedRequire = sharedRoot()

local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")
local Graybox = require("./Graybox")
local Waves = require("./Waves")

local Spawns = {}

export type Spot = {
	x: number,
	z: number,
	radius: number,
}

export type Placed = {
	id: string,
	kind: string,
	x: number,
	z: number,
	radius: number,
	speed: number,
	arrive: number,
	gate: number,
	clear: boolean,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Spawns.innerRadius(config: any?): number
	return Graybox.innerRadius(config)
end

function Spawns.insideFloor(
	x: number,
	z: number,
	reach: number,
	inner: number,
	margin: number
): (number, number)
	local limit = math.max(0, inner - margin - reach)
	local dist = math.sqrt(x * x + z * z)
	if dist ~= dist then
		return 0, 0
	end
	if dist <= limit or dist == 0 then
		return x, z
	end
	local scale = limit / dist
	return x * scale, z * scale
end

-- One step toward the arena centre, never past it.
function Spawns.stepInward(x: number, z: number, step: number): (number, number)
	local length = math.sqrt(x * x + z * z)
	if length ~= length or length <= step then
		return 0, 0
	end
	local scale = (length - step) / length
	return x * scale, z * scale
end

function Spawns.hitsSolid(x: number, z: number, radius: number, solid: any): boolean
	local dx = x - solid.x
	local dz = z - solid.z
	local cosine = math.cos(solid.yaw)
	local sine = math.sin(solid.yaw)
	-- Local +Z points outward along yaw. Local +X is the tangent.
	local lx = -sine * dx + cosine * dz
	local lz = cosine * dx + sine * dz
	local clx = math.clamp(lx, -solid.hx, solid.hx)
	local clz = math.clamp(lz, -solid.hz, solid.hz)
	local ex = lx - clx
	local ez = lz - clz
	return ex * ex + ez * ez <= radius * radius
end

function Spawns.blocked(
	x: number,
	z: number,
	radius: number,
	inner: number,
	solids: { any }
): boolean
	local limit = inner - radius
	if x * x + z * z > limit * limit + 1e-4 then
		return true
	end
	for _, solid in ipairs(solids) do
		if Spawns.hitsSolid(x, z, radius, solid) then
			return true
		end
	end
	return false
end

local function crowded(
	x: number,
	z: number,
	radius: number,
	gap: number,
	occupied: { Spot }
): boolean
	for _, other in ipairs(occupied) do
		local dx = x - other.x
		local dz = z - other.z
		local need = radius + other.radius + gap
		if dx * dx + dz * dz < need * need then
			return true
		end
	end
	return false
end

function Spawns.clear(
	x: number,
	z: number,
	radius: number,
	config: any?,
	solids: { any }?,
	occupied: { Spot }?
): (number, number, boolean)
	local cfg = cfgOf(config)
	local inner = Spawns.innerRadius(cfg)
	local blocks = if solids == nil then Graybox.solids(cfg) else solids
	local taken = if occupied == nil then {} else occupied
	local cx, cz = Spawns.insideFloor(x, z, radius, inner, cfg.spawn.margin)
	local function hit(px: number, pz: number): boolean
		if Spawns.blocked(px, pz, radius, inner, blocks) then
			return true
		end
		return crowded(px, pz, radius, cfg.spawn.gap, taken)
	end
	if not hit(cx, cz) then
		return cx, cz, true
	end
	for _ = 1, cfg.spawn.tries do
		cx, cz = Spawns.stepInward(cx, cz, cfg.spawn.step)
		if not hit(cx, cz) then
			return cx, cz, true
		end
	end
	return cx, cz, false
end

function Spawns.minimumDiameter(config: any?): number
	local cfg = cfgOf(config)
	local perGate = 1
	for _, wave in ipairs(cfg.waves) do
		local load = math.ceil(Waves.gateLoad(wave) / cfg.gates.count)
		if load > perGate then
			perGate = load
		end
	end
	local radius = WaveArenaConfig.footprint(cfg, "chaser")
	local span = cfg.spawn.margin
		+ radius
		+ math.max(0, perGate - 1) * (radius * 2 + cfg.spawn.gap)
		+ radius
	local bossR = WaveArenaConfig.footprint(cfg, "boss")
	local boss = cfg.spawn.boss
	local bossNeed = math.max(math.abs(boss.x), math.abs(boss.z)) + bossR + cfg.spawn.margin
	local inner = math.max(span, bossNeed)
	local diameter = (inner + cfg.arena.wallThickness) * 2
	if diameter < cfg.minDiameter then
		return cfg.minDiameter
	end
	return diameter
end

function Spawns.place(index: any, config: any?): { Placed }
	local cfg = cfgOf(config)
	local roster = Waves.roster(index, cfg)
	local solids = Graybox.solids(cfg)
	local inner = Spawns.innerRadius(cfg)
	local angles = Graybox.gateAngles(cfg)
	local occupied: { Spot } = {}
	local placed: { Placed } = {}
	local gateSlot: { [number]: number } = {}
	local gateUse = 0
	for _, unit in ipairs(roster) do
		local profile = WaveArenaConfig.profile(cfg, unit.kind)
		local radius = WaveArenaConfig.footprint(cfg, unit.kind)
		local x = 0
		local z = 0
		local gate = 0
		if unit.kind == "boss" then
			x = cfg.spawn.boss.x
			z = cfg.spawn.boss.z
		else
			gateUse += 1
			gate = ((gateUse - 1) % cfg.gates.count) + 1
			local slot = gateSlot[gate] or 0
			gateSlot[gate] = slot + 1
			local angle = angles[gate]
			local radial = inner - cfg.spawn.margin - radius - slot * (radius * 2 + cfg.spawn.gap)
			if radial < 0 then
				radial = 0
			end
			x = math.cos(angle) * radial
			z = math.sin(angle) * radial
		end
		local cx, cz, ok = Spawns.clear(x, z, radius, cfg, solids, occupied)
		table.insert(occupied, { x = cx, z = cz, radius = radius })
		table.insert(placed, {
			id = unit.id,
			kind = unit.kind,
			x = cx,
			z = cz,
			radius = radius,
			speed = profile.moveSpeed,
			arrive = profile.arrive,
			gate = gate,
			clear = ok,
		})
	end
	return placed
end

function Spawns.allClear(placed: { Placed }): boolean
	if #placed == 0 then
		return false
	end
	for _, unit in ipairs(placed) do
		if unit.clear ~= true then
			return false
		end
	end
	return true
end

return Spawns
