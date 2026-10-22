--!strict

--[[
	Phase 3 wave arena. Sequencing, spawn clearance, and pathing are pure.
	The graybox stays unbuilt unless LaunchGate.waveArena and
	WaveArenaConfig.enabled are both true.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local WaveArenaConfig = require("../src/shared/Config/WaveArenaConfig")
local WaveArena = require("../src/server/WaveArena")
local Gate = require("../src/server/WaveArena/Gate")
local Graybox = require("../src/server/WaveArena/Graybox")
local Pathing = require("../src/server/WaveArena/Pathing")
local Spawns = require("../src/server/WaveArena/Spawns")
local Waves = require("../src/server/WaveArena/Waves")

local function lengthOf(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

local FILES = {
	"src/shared/Config/WaveArenaConfig.luau",
	"src/server/WaveArena/init.luau",
	"src/server/WaveArena/Gate.luau",
	"src/server/WaveArena/Waves.luau",
	"src/server/WaveArena/Spawns.luau",
	"src/server/WaveArena/Pathing.luau",
	"src/server/WaveArena/Graybox.luau",
}

local function withEnabled(on: boolean): any
	local copy = table.clone(WaveArenaConfig)
	copy.enabled = on
	return copy
end

local function opened(): any
	return {
		launchGate = { waveArena = true },
		config = withEnabled(true),
	}
end

local function named(parts: { any }, name: string): { any }
	local found = {}
	for _, part in ipairs(parts) do
		if part.name == name then
			table.insert(found, part)
		end
	end
	return found
end

describe("Wave arena guards", function()
	it("ships both switches off and does not edit LaunchGate", function()
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect((LaunchGate :: any).waveArena).toBeNil()
		expect(Gate.waveArenaOn(nil)).toEqual(false)
		expect(Gate.waveArenaOn(LaunchGate)).toEqual(false)
		expect(Gate.waveArenaOn({})).toEqual(false)
		expect(Gate.configOn(nil)).toEqual(false)
		expect(Gate.open(nil, nil)).toEqual(false)
		expect(Gate.open({ waveArena = true }, WaveArenaConfig)).toEqual(false)
		expect(Gate.open(LaunchGate, withEnabled(true))).toEqual(false)
		expect(Gate.open({ waveArena = false }, withEnabled(true))).toEqual(false)
		expect(Gate.open({ waveArena = true }, withEnabled(true))).toEqual(true)

		local gateSrc = fs.readFile("src/server/WaveArena/Gate.luau")
		expect(string.find(gateSrc, "waveArena == true", 1, true) ~= nil).toBeTrue()
		local launchSrc = fs.readFile("src/ReplicatedStorage/Shared/LaunchGate.luau")
		expect(string.find(launchSrc, "waveArena", 1, true)).toBeNil()
		local cfgSrc = fs.readFile("src/shared/Config/WaveArenaConfig.luau")
		expect(string.find(cfgSrc, "enabled = false", 1, true) ~= nil).toBeTrue()
	end)

	it("does not build or start a round while either guard is off", function()
		local calls = 0
		local function create()
			calls += 1
		end
		expect(WaveArena.build(nil)).toBeNil()
		expect(WaveArena.build({ create = create })).toBeNil()
		expect(WaveArena.build({ launchGate = { waveArena = true }, create = create })).toBeNil()
		expect(WaveArena.build({ config = withEnabled(true), create = create })).toBeNil()
		expect(WaveArena.begin(nil)).toBeNil()
		expect(WaveArena.begin({ launchGate = { waveArena = true } })).toBeNil()
		expect(WaveArena.advance({ wave = 1 }, { config = withEnabled(true) })).toBeNil()
		expect(calls).toEqual(0)
	end)

	it("builds the graybox only when both guards are on", function()
		local calls = 0
		local options = opened()
		options.create = function()
			calls += 1
		end
		local parts = WaveArena.build(options)
		expect(parts ~= nil).toBeTrue()
		expect(calls).toEqual(#(parts :: { any }))
		expect(calls > 0).toBeTrue()
	end)

	it("refuses an arena smaller than the biggest wave", function()
		local copy = withEnabled(true)
		copy.minDiameter = 1
		copy.arena = table.clone(WaveArenaConfig.arena)
		copy.chaser = {
			id = "wave_chaser",
			size = { 30, 10, 30 },
			moveSpeed = 11,
			arrive = 6,
		}
		expect(Spawns.minimumDiameter(copy) > copy.arena.diameter).toBeTrue()
		local calls = 0
		expect(WaveArena.build({
			launchGate = { waveArena = true },
			config = copy,
			create = function()
				calls += 1
			end,
		})).toBeNil()
		expect(calls).toEqual(0)

		local tiny = withEnabled(true)
		tiny.arena = table.clone(WaveArenaConfig.arena)
		tiny.arena.diameter = 100
		expect(WaveArena.build({ launchGate = { waveArena = true }, config = tiny })).toBeNil()
	end)

	it("stays off the live hub, Rootvault, remotes, and Robux", function()
		for _, path in ipairs(FILES) do
			local source = fs.readFile(path)
			expect(string.find(source, "DungeonService", 1, true)).toBeNil()
			expect(string.find(source, "DataService", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
			expect(string.find(source, "Schema", 1, true)).toBeNil()
			expect(string.find(source, "Robux", 1, true)).toBeNil()
		end
		local boot = fs.readFile("src/ServerScriptService/ShardfallServer/init.server.luau")
		expect(string.find(boot, "WaveArena", 1, true)).toBeNil()
	end)
end)

describe("Wave sequence", function()
	it("follows config: 6, 8, 10, 12, then a boss and 4 adds", function()
		expect(Waves.count()).toEqual(5)
		local counts = { 6, 8, 10, 12 }
		for index, count in ipairs(counts) do
			local wave = Waves.def(index)
			expect(wave.kind).toEqual("chaser")
			expect(wave.count).toEqual(count)
			local roster = Waves.roster(index)
			expect(#roster).toEqual(count)
			expect(roster[1].id).toEqual("wave_chaser")
		end
		local boss = Waves.def(5)
		expect(boss.kind).toEqual("boss")
		expect(boss.adds).toEqual(4)
		local roster = Waves.roster(5)
		expect(#roster).toEqual(5)
		expect(roster[1].id).toEqual("wave_boss")
		expect(roster[1].kind).toEqual("boss")
		local adds = 0
		for _, unit in ipairs(roster) do
			if unit.kind == "add" then
				adds += 1
				expect(unit.id).toEqual("wave_add")
			end
		end
		expect(adds).toEqual(4)
		expect(Waves.densest()).toEqual(4)
		expect(Waves.bodies(Waves.def(Waves.densest()))).toEqual(12)
	end)

	it("ignores indexes that are not in the config", function()
		expect(#Waves.roster(0)).toEqual(0)
		expect(#Waves.roster(99)).toEqual(0)
		expect(#Waves.roster("nope")).toEqual(0)
		expect(Waves.def(0)).toBeNil()
	end)

	it("reads a replacement wave list instead of a hardcoded count", function()
		local custom = table.clone(WaveArenaConfig)
		custom.waves = {
			{ count = 2, kind = "chaser" },
			{ count = 1, kind = "boss", adds = 4 },
		}
		expect(#Waves.roster(1, custom)).toEqual(2)
		expect(#Waves.roster(2, custom)).toEqual(5)
		expect(Waves.roster(1, WaveArenaConfig)[1].id).toEqual("wave_chaser")
	end)

	it("runs the five waves in order and then stops", function()
		local options = opened()
		local run = WaveArena.begin(options)
		expect(run ~= nil).toBeTrue()
		local current = run :: any
		expect(current.wave).toEqual(1)
		expect(Spawns.allClear(current.spawned)).toBeTrue()
		local seen = { #current.roster }
		while current.over ~= true do
			current = WaveArena.advance(current, options)
			expect(current ~= nil).toBeTrue()
			table.insert(seen, #current.roster)
			if current.over ~= true then
				expect(Spawns.allClear(current.spawned)).toBeTrue()
			end
		end
		expect(seen).toEqual({ 6, 8, 10, 12, 5, 0 })
		expect(current.over).toEqual(true)
	end)
end)

describe("Spawn clearance", function()
	it("steps inward and keeps a footprint inside the round floor", function()
		local step = WaveArenaConfig.spawn.step
		local x, z = Spawns.stepInward(10, 0, step)
		expect(x).toBeCloseTo(10 - step, 1e-6)
		expect(z).toEqual(0)
		local cx, cz = Spawns.stepInward(1, 1, step)
		expect(cx).toEqual(0)
		expect(cz).toEqual(0)
		local inner = Spawns.innerRadius()
		local radius = WaveArenaConfig.footprint(WaveArenaConfig, "chaser")
		local margin = WaveArenaConfig.spawn.margin
		local fx, fz = Spawns.insideFloor(inner + 20, -8, radius, inner, margin)
		local limit = inner - margin - radius
		expect(math.abs(lengthOf(fx, fz) - limit) < 1e-4).toBeTrue()
		expect(WaveArenaConfig.spawn.tries * step >= WaveArenaConfig.arena.wallThickness).toBeTrue()
	end)

	it("rejects a point in the wall and walks a crowded spot inward", function()
		local inner = Spawns.innerRadius()
		local radius = WaveArenaConfig.footprint(WaveArenaConfig, "chaser")
		expect(Spawns.blocked(inner + 1, 0, radius, inner, {})).toBeTrue()
		local x, z, ok = Spawns.clear(inner + 8, 4, radius, WaveArenaConfig, {}, {})
		expect(ok).toBeTrue()
		local limit = inner - WaveArenaConfig.spawn.margin - radius
		expect(lengthOf(x, z) <= limit + 1e-4).toBeTrue()

		local occupied = { { x = limit, z = 0, radius = radius } }
		local mx, mz, moved = Spawns.clear(limit, 0, radius, WaveArenaConfig, {}, occupied)
		expect(moved).toBeTrue()
		expect(mx < limit - 0.5).toBeTrue()
		expect(math.abs(mz) < 1e-6).toBeTrue()

		local solid = { x = 0, z = 0, hx = 5000, hz = 5000, yaw = 0 }
		local _, _, cleared = Spawns.clear(20, 0, 2, WaveArenaConfig, { solid }, {})
		expect(cleared).toBeFalse()
	end)

	it("places the biggest wave and the boss wave off the walls and off each other", function()
		local solids = Graybox.solids()
		local inner = Spawns.innerRadius()
		for _, index in ipairs({ Waves.densest(), Waves.bossIndex() }) do
			local placed = Spawns.place(index)
			expect(Spawns.allClear(placed)).toBeTrue()
			expect(#placed).toEqual(Waves.bodies(Waves.def(index)))
			for i, unit in ipairs(placed) do
				expect(Spawns.blocked(unit.x, unit.z, unit.radius, inner, solids)).toBeFalse()
				local edge = lengthOf(unit.x, unit.z) + unit.radius
				expect(edge <= inner - WaveArenaConfig.spawn.margin + 1e-4).toBeTrue()
				for j = i + 1, #placed do
					local other = placed[j]
					local need = unit.radius + other.radius + WaveArenaConfig.spawn.gap
					local dx = unit.x - other.x
					local dz = unit.z - other.z
					expect(dx * dx + dz * dz >= need * need - 1e-4).toBeTrue()
				end
			end
		end
		local bossWave = Spawns.place(Waves.bossIndex())
		local boss = bossWave[1]
		expect(boss.kind).toEqual("boss")
		expect(boss.x).toEqual(WaveArenaConfig.spawn.boss.x)
		expect(boss.z).toEqual(WaveArenaConfig.spawn.boss.z)
		local gates: { [number]: boolean } = {}
		for _, unit in ipairs(Spawns.place(Waves.densest())) do
			gates[unit.gate] = true
		end
		expect(gates[1]).toEqual(true)
		expect(gates[2]).toEqual(true)
		expect(gates[3]).toEqual(true)
	end)
end)

describe("Wave arena graybox", function()
	it("is a round floor at least 120 studs across with 3 gates", function()
		expect(WaveArenaConfig.arena.diameter >= 120).toBeTrue()
		expect(WaveArenaConfig.arena.diameter >= Spawns.minimumDiameter()).toBeTrue()
		expect(Spawns.minimumDiameter() >= 120).toBeTrue()
		expect(WaveArenaConfig.gates.count).toEqual(3)

		local parts = Graybox.plan()
		local floors = named(parts, "WaveArenaFloor")
		local gates = named(parts, "WaveArenaGate")
		local walls = named(parts, "WaveArenaWall")
		local posts = named(parts, "WaveArenaPost")
		expect(#floors).toEqual(1)
		expect(floors[1].shape).toEqual("Cylinder")
		expect(floors[1].size[2] >= 120).toBeTrue()
		expect(floors[1].size[3] >= 120).toBeTrue()
		expect(floors[1].size[2]).toEqual(WaveArenaConfig.arena.diameter)
		expect(#gates).toEqual(3)
		expect(#posts).toEqual(6)
		expect(#walls < WaveArenaConfig.arena.wallSegments).toBeTrue()
		expect(#walls > 0).toBeTrue()
		for _, gate in ipairs(gates) do
			expect(gate.canCollide).toEqual(false)
		end
		for _, post in ipairs(posts) do
			expect(post.canCollide).toEqual(true)
		end
		expect(floors[1].canCollide).toEqual(true)
		local origin = WaveArenaConfig.arena.origin
		expect(origin.z).toEqual(12000)
		for _, part in ipairs(parts) do
			expect(part.position[3] > 8000).toBeTrue()
			local dx = part.position[1] - origin.x
			local dz = part.position[3] - origin.z
			expect(lengthOf(dx, dz) <= WaveArenaConfig.arena.diameter / 2 + 1).toBeTrue()
		end
	end)
end)

describe("Wave pathing", function()
	it("walks one tick inward and then along the ring", function()
		local body = {
			id = "wave_chaser",
			kind = "chaser",
			x = 40,
			z = 0,
			radius = 2,
			speed = 10,
			arrive = 6,
			slotX = 10,
			slotZ = 0,
		}
		Pathing.nudge(body, 1, 60)
		expect(body.x).toBeCloseTo(30, 1e-6)
		expect(body.z).toBeCloseTo(0, 1e-6)
		body.x = 10
		body.z = 0
		body.slotX = 0
		body.slotZ = 10
		Pathing.nudge(body, 0.01, 60)
		expect(body.z > 0).toBeTrue()
		expect(lengthOf(body.x, body.z)).toBeCloseTo(10, 1e-4)
	end)

	it("clears the largest wave in 30 seconds without entering geometry", function()
		local index = Waves.densest()
		local placed = Spawns.place(index)
		expect(#placed).toEqual(12)
		local before = placed[1].x
		local sim = Pathing.simulate(placed, WaveArenaConfig, WaveArenaConfig.path.stuckSeconds)
		expect(placed[1].x).toEqual(before)
		expect(sim.seconds >= 30 - 1e-6).toBeTrue()
		expect(#sim.stuck).toEqual(0)
		expect(sim.inGeometry).toEqual(0)
		local inner = Spawns.innerRadius()
		for i, body in ipairs(sim.bodies) do
			expect(lengthOf(body.x - body.slotX, body.z - body.slotZ) <= 0.5).toBeTrue()
			expect(lengthOf(body.x, body.z) + body.radius < inner).toBeTrue()
			expect(lengthOf(body.slotX, body.slotZ) < inner * 0.5).toBeTrue()
			for j = i + 1, #sim.bodies do
				local other = sim.bodies[j]
				local dx = body.slotX - other.slotX
				local dz = body.slotZ - other.slotZ
				local need = body.radius + other.radius
				expect(dx * dx + dz * dz >= need * need - 1e-3).toBeTrue()
			end
		end
	end)

	it("brings the boss and 4 adds in without getting stuck", function()
		local placed = Spawns.place(Waves.bossIndex())
		expect(#placed).toEqual(5)
		local sim = Pathing.simulate(placed)
		expect(#sim.stuck).toEqual(0)
		expect(sim.inGeometry).toEqual(0)
		expect(sim.seconds >= 30 - 1e-6).toBeTrue()
	end)

	it("leaves a post and still reaches a spot", function()
		local post = nil
		for _, solid in ipairs(Graybox.solids()) do
			if solid.hx < 2 then
				post = solid
				break
			end
		end
		expect(post ~= nil).toBeTrue()
		local radius = WaveArenaConfig.footprint(WaveArenaConfig, "chaser")
		local start = {
			{
				id = "wave_chaser",
				kind = "chaser",
				x = (post :: any).x,
				z = (post :: any).z,
				radius = radius,
				speed = WaveArenaConfig.chaser.moveSpeed,
				arrive = WaveArenaConfig.chaser.arrive,
			},
		}
		local inner = Spawns.innerRadius()
		expect(Spawns.blocked(start[1].x, start[1].z, radius, inner, Graybox.solids())).toBeTrue()
		local sim = Pathing.simulate(start)
		expect(#sim.stuck).toEqual(0)
		local body = sim.bodies[1]
		expect(Spawns.blocked(body.x, body.z, body.radius, inner, Graybox.solids())).toBeFalse()
	end)
end)
