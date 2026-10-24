--!strict

--[[
	Phase 3 fight. The gate, the three enemy types, ground loot, the boss
	slam, the death hold, the stuck check, and the dev buttons. Both
	switches ship off, so none of this builds until they are on.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Boss = require("../src/server/WaveArena/Boss")
local Camera = require("../src/server/WaveArena/Camera")
local Enemies = require("../src/server/WaveArena/Enemies")
local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local Haven = require("../src/ReplicatedStorage/Shared/Haven")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Spawns = require("../src/server/WaveArena/Spawns")
local WaveArena = require("../src/server/WaveArena")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local FILES = {
	"src/ReplicatedStorage/Shared/Config/WaveArenaConfig.luau",
	"src/server/WaveArena/init.luau",
	"src/server/WaveArena/Round.luau",
	"src/server/WaveArena/Enemies.luau",
	"src/server/WaveArena/Loot.luau",
	"src/server/WaveArena/Session.luau",
	"src/server/WaveArena/Settle.luau",
	"src/server/WaveArena/Stuck.luau",
	"src/server/WaveArena/Boss.luau",
	"src/server/WaveArena/Feel.luau",
	"src/server/WaveArena/Camera.luau",
	"src/server/WaveArena/Hud.luau",
	"src/server/WaveArena/HubPad.luau",
	"src/server/WaveArena/Gate.luau",
}

local function withEnabled(on: boolean): any
	local copy = table.clone(WaveArenaConfig)
	copy.enabled = on
	return copy
end

local function opened(config: any): any
	return {
		launchGate = { waveArena = true },
		config = config,
	}
end

local function fightConfig(): any
	local copy = withEnabled(true)
	copy.player = {
		hp = 500,
		damage = 12,
		range = 100,
		interval = 0,
		speed = 0,
		radius = 2,
		start = { x = 0, z = 0 },
	}
	copy.chaser = {
		id = "wave_chaser",
		size = { 3.2, 2.2, 4.2 },
		moveSpeed = 0,
		arrive = 6,
		hp = 12,
		damage = 1,
		attackRange = 0,
		attackInterval = 5,
		windup = 0.5,
		opening = 10,
	}
	copy.boss = {
		id = "wave_boss",
		size = { 8, 9, 7 },
		moveSpeed = 0,
		arrive = 8,
		adds = 0,
		hp = 12,
		damage = 22,
		attackRange = 100,
		attackRadius = 8,
		attackInterval = 10,
		windup = 1,
		opening = 0,
		deathHold = 1.5,
	}
	copy.waves = {
		{ count = 2, kind = "chaser" },
		{ count = 1, kind = "boss", adds = 0 },
	}
	copy.mix = { { "chaser" }, { "chaser" } }
	copy.loot = {
		pickupRadius = 12,
		drops = WaveArenaConfig.loot.drops,
		waveTokens = { 1, 5 },
	}
	return copy
end

local function findKind(events: { any }, kind: string): any
	for _, event in ipairs(events) do
		if event.kind == kind then
			return event
		end
	end
	return nil
end

describe("Wave arena fight gate", function()
	it("builds nothing and shows nothing while either switch is off", function()
		local calls = 0
		local function create()
			calls += 1
		end
		expect(WaveArena.hubPad(nil)).toBeNil()
		expect(WaveArena.hubPad({ launchGate = { waveArena = true }, create = create })).toBeNil()
		expect(WaveArena.hubPad({ config = withEnabled(true), create = create })).toBeNil()
		expect(WaveArena.present({ create = create })).toBeNil()
		expect(WaveArena.enter(nil)).toBeNil()
		expect(WaveArena.enter({ launchGate = LaunchGate, config = withEnabled(true) })).toBeNil()
		expect(
			WaveArena.hud({ wave = 1, total = 5, enemies = {}, card = { kind = "results" } }, nil)
		).toBeNil()
		expect(WaveArena.dev("enter", nil, nil).ok).toEqual(false)
		expect(WaveArena.dev("skip", nil, { launchGate = { waveArena = true } }).ok).toEqual(false)
		expect(calls).toEqual(0)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
	end)

	it("places a Shard Gate near spawn only when both switches are on", function()
		local calls = 0
		local options = opened(withEnabled(true))
		options.create = function()
			calls += 1
		end
		local shown = WaveArena.present(options)
		expect(shown ~= nil).toBeTrue()
		expect(shown.pad.name).toEqual("ShardGate")
		expect(shown.pad.prompt).toEqual("Shard Gate")
		expect(shown.pad.canCollide).toEqual(false)
		expect(shown.pad.destination[3]).toEqual(12000)
		expect(calls).toEqual(#shown.arena + 1)
		-- Haven spawn is (0, 124, 30). The pad is a short walk south of it.
		local dx = shown.pad.position[1]
		local dz = shown.pad.position[3] - 30
		expect(math.sqrt(dx * dx + dz * dz) < 30).toBeTrue()
		expect(shown.pad.position[3] > 30).toBeTrue()
		expect(shown.pad.position[2] > 120 and shown.pad.position[2] < 124).toBeTrue()
		-- Shard Gate prompt reach is 12. The Grove post prompt reach is 8.
		local grove = Haven.GROVE
		local dx = shown.pad.position[1] - grove.x
		local dz = shown.pad.position[3] - grove.z
		expect(math.sqrt(dx * dx + dz * dz) > 12 + 8).toBeTrue()
	end)
end)

describe("Wave arena enemy types", function()
	it("keeps three config-driven types and the 6, 8, 10, 12, boss wave", function()
		expect(WaveArenaConfig.types.chaser).toEqual(1)
		expect(WaveArenaConfig.types.ranged).toEqual(2)
		expect(WaveArenaConfig.types.tank).toEqual(3)
		expect(WaveArenaConfig.tank.hp > WaveArenaConfig.chaser.hp).toBeTrue()
		expect(WaveArenaConfig.ranged.hp ~= WaveArenaConfig.chaser.hp).toBeTrue()
		expect(WaveArenaConfig.ranged.attackRange > WaveArenaConfig.chaser.attackRange).toBeTrue()
		expect(WaveArenaConfig.tank.moveSpeed < WaveArenaConfig.chaser.moveSpeed).toBeTrue()
		expect(WaveArenaConfig.arena.diameter).toEqual(90)
		expect(WaveArenaConfig.gates.count).toEqual(3)

		local function saw(index: number, kind: string): boolean
			for _, unit in ipairs(Enemies.loadout(index)) do
				if unit.kind == kind then
					return true
				end
			end
			return false
		end
		expect(#Enemies.loadout(1)).toEqual(6)
		expect(saw(1, "chaser")).toEqual(true)
		expect(saw(1, "ranged")).toEqual(false)
		expect(saw(1, "tank")).toEqual(false)
		expect(Enemies.loadout(1)[1].typeIndex).toEqual(1)
		expect(saw(2, "ranged")).toEqual(true)
		expect(saw(3, "tank")).toEqual(true)
		expect(#Enemies.loadout(4)).toEqual(12)
		expect(saw(4, "tank")).toEqual(true)
		local boss = Enemies.loadout(5)
		expect(#boss).toEqual(5)
		expect(boss[1].kind).toEqual("boss")
		expect(boss[1].id).toEqual("wave_boss")
		local adds = 0
		for _, unit in ipairs(boss) do
			if unit.kind == "add" then
				adds += 1
			end
		end
		expect(adds).toEqual(4)

		local options = opened(withEnabled(true))
		options.wave = 4
		local run = WaveArena.enter(options)
		expect(run ~= nil).toBeTrue()
		expect(#(run :: any).enemies).toEqual(12)
		local placed = Spawns.place(4)
		expect(Spawns.allClear(placed)).toBeTrue()
		expect((run :: any).enemies[1].x).toEqual(placed[1].x)
		expect((run :: any).enemies[1].z).toEqual(placed[1].z)
	end)

	it("pays the economy sheet in memory and does not touch a profile", function()
		local sum = 0
		for index, amount in ipairs(WaveArenaConfig.loot.waveTokens) do
			expect(amount).toEqual(Economy.WAVES[index].tokens)
			sum += amount
		end
		expect(sum).toEqual(Economy.NORMAL_CLEAR_TOKENS)
		expect(WaveArenaConfig.loot.pickupRadius).toEqual(12)
		for _, path in ipairs(FILES) do
			local source = fs.readFile(path)
			expect(string.find(source, "DataService", 1, true)).toBeNil()
			expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
			expect(string.find(source, "Schema", 1, true)).toBeNil()
			expect(string.find(source, "Robux", 1, true)).toBeNil()
		end
	end)
end)

describe("Wave arena loot", function()
	it("leaves chips on the ground until you are inside 12 studs", function()
		local config = fightConfig()
		config.chaser = table.clone(config.chaser)
		config.chaser.hp = 36
		local options = opened(config)
		local run = WaveArena.enter(options)
		expect(run ~= nil).toBeTrue()
		local current = run :: any
		local _, events =
			WaveArena.step(current, 0.5, { attack = true, damage = 99999, hp = 1 }, options)
		local wounded = current.enemies[1]
		if current.enemies[2].hp < wounded.hp then
			wounded = current.enemies[2]
		end
		-- Server damage is 12. The tick cannot set damage or hp.
		expect(wounded.hp).toEqual(24)
		expect(current.player.hp).toEqual(500)
		expect(findKind(events, "hitFlash") ~= nil).toBeTrue()
		expect(findKind(events, "deathPuff")).toBeNil()
		expect(#current.ground).toEqual(0)

		WaveArena.step(current, 0.5, { attack = true }, options)
		local _, killed = WaveArena.step(current, 0.5, { attack = true }, options)
		expect(findKind(killed, "deathPuff") ~= nil).toBeTrue()
		expect(#current.ground).toEqual(1)
		expect(current.earned.fragments).toEqual(0)

		local drop = current.ground[1]
		current.player.x = drop.x + 12.1
		current.player.z = drop.z
		WaveArena.step(current, 0.1, {}, options)
		expect(#current.ground).toEqual(1)
		expect(current.earned.fragments).toEqual(0)

		current.player.x = drop.x + 12
		WaveArena.step(current, 0.1, {}, options)
		expect(#current.ground).toEqual(0)
		expect(current.earned.fragments).toEqual(1)
	end)

	it("sweeps the rest at the end of the wave and keeps it on disconnect", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		WaveArena.step(run, 0.5, { attack = true }, options)
		expect(run.wave).toEqual(2)
		expect(#run.ground).toEqual(0)
		expect(run.earned.fragments).toEqual(2)
		expect(run.earned.tokens).toEqual(1)
		expect(run.wavesCleared).toEqual(1)

		local _, left = WaveArena.settle(run, "disconnect", options)
		local card = findKind(left, "results")
		expect(card ~= nil).toBeTrue()
		expect(card.reason).toEqual("disconnect")
		expect(card.cleared).toEqual(false)
		expect(card.loot.tokens).toEqual(1)
		expect(card.loot.fragments).toEqual(2)
		expect(card.wavesCleared).toEqual(1)
		expect(run.phase).toEqual("results")
	end)

	it("keeps uncollected chips once on a wipe", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		expect(#run.ground).toEqual(1)
		local _, left = WaveArena.settle(run, "wipe", options)
		expect(run.earned.fragments).toEqual(1)
		expect(run.earned.tokens).toEqual(0)
		expect(#run.ground).toEqual(0)
		expect(findKind(left, "results").loot.fragments).toEqual(1)
		expect(findKind(left, "results").reason).toEqual("wipe")
		local _, again = WaveArena.settle(run, "disconnect", options)
		expect(#again).toEqual(0)
		expect(run.earned.fragments).toEqual(1)
		expect(run.earned.tokens).toEqual(0)
	end)
end)

describe("Wave arena boss", function()
	it("deals damage only after the red warning, and only inside the circle", function()
		local warning = Boss.arm({ windup = 1.8, attackRadius = 8, damage = 22 }, { x = 1, z = 2 })
		expect(warning.color).toEqual("red")
		expect(warning.seconds >= 0.5).toBeTrue()
		expect(Boss.damage(warning, { x = 1, z = 2 }, false)).toEqual(0)
		expect(Boss.damage(warning, { x = 1, z = 2 }, true)).toEqual(22)
		expect(Boss.damage(warning, { x = 40, z = 2 }, true)).toEqual(0)

		local config = fightConfig()
		config.waves = { { count = 1, kind = "boss", adds = 0 } }
		config.boss = {
			id = "wave_boss",
			size = { 8, 9, 7 },
			moveSpeed = 0,
			arrive = 8,
			adds = 0,
			hp = 9999,
			damage = 22,
			attackRange = 30,
			attackRadius = 8,
			attackInterval = 10,
			windup = 1,
			opening = 0,
			deathHold = 1.5,
		}
		config.player = {
			hp = 100,
			damage = 0,
			range = 0,
			interval = 1,
			speed = 100,
			radius = 2,
			start = { x = 0, z = 8 },
		}
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		local _, first = WaveArena.step(run, 0.5, {}, options)
		local warned = findKind(first, "warning")
		expect(warned ~= nil).toBeTrue()
		expect(warned.color).toEqual("red")
		expect(warned.seconds).toEqual(1)
		expect(findKind(first, "hit")).toBeNil()
		expect(run.player.hp).toEqual(100)

		local _, second = WaveArena.step(run, 0.5, { moveX = 1 }, options)
		expect(findKind(second, "hit")).toBeNil()
		expect(run.player.hp).toEqual(100)

		local _, third = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(third, "whiff") ~= nil).toBeTrue()
		expect(run.player.hp).toEqual(100)

		run.player.x = 0
		run.player.z = 8
		run.enemies[1].cooldown = 0
		run.enemies[1].windLeft = 0
		WaveArena.step(run, 0.5, {}, options)
		expect(run.player.hp).toEqual(100)
		local _, landed = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(landed, "hit")).toBeNil()
		local _, boom = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(boom, "hit") ~= nil).toBeTrue()
		expect(run.player.hp).toEqual(78)
	end)

	it("waits 1.5 seconds after the boss falls before the results card", function()
		local config = fightConfig()
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		WaveArena.step(run, 0.5, { attack = true }, options)
		WaveArena.step(run, 0.5, { attack = true }, options)
		local _, killed = WaveArena.step(run, 0.5, { attack = true }, options)
		expect(findKind(killed, "deathPuff")).toBeNil()
		expect(findKind(killed, "bossDown") ~= nil).toBeTrue()
		expect(findKind(killed, "results")).toBeNil()
		expect(run.phase).toEqual("deathHold")
		expect(run.card).toBeNil()
		expect(run.earned.tokens).toEqual(1)
		expect(#run.ground).toEqual(1)
		local hud = WaveArena.hud(run, options)
		expect(hud.boss.shown).toEqual(false)
		expect(hud.card).toBeNil()
		expect(hud.text).toEqual("Wave 2 / 2")

		WaveArena.step(run, 10, {}, options)
		expect(run.card).toBeNil()
		expect(run.phase).toEqual("deathHold")
		WaveArena.step(run, 0.5, {}, options)
		expect(run.card).toBeNil()
		local _, done = WaveArena.step(run, 0.5, {}, options)
		local card = findKind(done, "results")
		expect(card ~= nil).toBeTrue()
		expect(card.reason).toEqual("clear")
		expect(card.cleared).toEqual(true)
		expect(card.loot.tokens).toEqual(6)
		expect(card.loot.fragments).toEqual(6)
		expect(#run.ground).toEqual(0)
		expect(run.bestWave).toEqual(2)
	end)

	it(
		"shows a boss bar that tracks hp, and keeps the clear if you disconnect during the pause",
		function()
			local config = fightConfig()
			config.boss = table.clone(config.boss)
			config.boss.hp = 24
			local options = opened(config)
			options.wave = 2
			local run = WaveArena.enter(options) :: any
			local before = WaveArena.hud(run, options)
			expect(before.boss.shown).toEqual(true)
			expect(before.boss.ratio).toEqual(1)
			expect(before.boss.maxHp).toEqual(24)
			WaveArena.step(run, 0.5, { attack = true }, options)
			local mid = WaveArena.hud(run, options)
			expect(mid.boss.shown).toEqual(true)
			expect(mid.boss.hp).toEqual(12)
			expect(mid.boss.ratio).toEqual(0.5)
			WaveArena.step(run, 0.5, { attack = true }, options)
			expect(run.phase).toEqual("deathHold")
			expect(WaveArena.hud(run, options).boss.shown).toEqual(false)
			local _, left = WaveArena.settle(run, "disconnect", options)
			local card = findKind(left, "results")
			expect(card.reason).toEqual("disconnect")
			expect(card.cleared).toEqual(true)
			expect(card.loot.tokens).toEqual(5)
			expect(card.loot.fragments).toEqual(4)
			expect(run.phase).toEqual("results")
			local _, again = WaveArena.settle(run, "wipe", options)
			expect(#again).toEqual(0)
			expect(run.earned.tokens).toEqual(5)
			expect(run.earned.fragments).toEqual(4)
		end
	)
end)

describe("Wave arena stuck and camera", function()
	it("teleports an enemy that has not moved, and despawns one that cannot", function()
		local config = fightConfig()
		config.waves = { { count = 1, kind = "chaser" } }
		config.chaser = {
			id = "wave_chaser",
			size = { 3.2, 2.2, 4.2 },
			moveSpeed = 0,
			arrive = 6,
			hp = 9999,
			damage = 0,
			attackRange = 0,
			attackInterval = 5,
			windup = 0.5,
			opening = 10,
		}
		config.player = {
			hp = 200,
			damage = 0,
			range = 8,
			interval = 1,
			speed = 0,
			radius = 2,
			start = { x = 0, z = -18 },
		}
		config.stuck = { seconds = 1, epsilon = 0.75, teleportStuds = 16, minShift = 4 }
		local options = opened(config)
		local run = WaveArena.enter(options) :: any
		local enemy = run.enemies[1]
		-- Inside the 90-stud floor. 40 is past the wall and gets clamped.
		enemy.x = 30
		enemy.z = 0
		enemy.anchorX = 30
		enemy.anchorZ = 0
		enemy.stillFor = 0
		enemy.speed = 0
		local _, waiting = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(waiting, "teleport")).toBeNil()
		expect(enemy.x).toEqual(30)
		local _, moved = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(moved, "teleport") ~= nil).toBeTrue()
		expect(enemy.x).toBeCloseTo(14, 1e-4)
		expect(enemy.alive).toEqual(true)

		enemy.x = 0
		enemy.z = 0
		enemy.anchorX = 0
		enemy.anchorZ = 0
		enemy.stillFor = 0
		WaveArena.step(run, 0.5, {}, options)
		local _, gone = WaveArena.step(run, 0.5, {}, options)
		expect(findKind(gone, "despawn") ~= nil).toBeTrue()
		expect(findKind(gone, "deathPuff") ~= nil).toBeTrue()
		expect(enemy.alive).toEqual(false)
		expect(#run.ground + run.earned.fragments >= 1).toBeTrue()
	end)

	it("pushes the camera out of the boss and leaves an outside eye alone", function()
		local size = WaveArenaConfig.boss.size
		local center = { x = 10, y = 8, z = 4 }
		local jammed = Camera.correct({ x = 10, y = 8, z = 4 }, center, size, WaveArenaConfig)
		expect(jammed.moved).toEqual(true)
		expect(Camera.inside(jammed, center, size, WaveArenaConfig)).toEqual(false)
		local far = { x = 10, y = 8, z = 80 }
		local clear = Camera.correct(far, center, size, WaveArenaConfig)
		expect(clear.moved).toEqual(false)
		expect(clear.x).toEqual(far.x)
		expect(clear.y).toEqual(far.y)
		expect(clear.z).toEqual(far.z)
		local room = Camera.room(center, size, WaveArenaConfig)
		expect(room.name).toEqual("WaveArenaCameraRoom")
		expect(room.canCollide).toEqual(false)
		expect(room.size[1]).toEqual(size[1] + WaveArenaConfig.camera.roomPad * 2)
		expect(room.size[2]).toEqual(size[2] + WaveArenaConfig.camera.roomPad * 2)
		expect(room.size[3]).toEqual(size[3] + WaveArenaConfig.camera.roomPad * 2)
		local nudged = WaveArena.camera({ x = 10, y = 8, z = 4 }, center, size, WaveArenaConfig)
		expect(nudged.moved).toEqual(true)
	end)
end)

describe("Wave arena dev buttons", function()
	it("hides enter, skip, and spawn boss while the arena is off", function()
		local hidden = {}
		for _, label in ipairs(DevTools.hiddenLabels()) do
			hidden[label] = true
		end
		expect(hidden["Enter arena"]).toEqual(true)
		expect(hidden["Skip wave"]).toEqual(true)
		expect(hidden["Spawn boss"]).toEqual(true)
		expect(DevTools.blocked("WaveArena", "enter")).toEqual(DevTools.offMessage("waveArena"))
		expect(DevTools.blocked("WaveArena", "skip", function()
			return true
		end)).toBeNil()
		local off = WaveArena.dev("boss", nil, nil)
		expect(off.ok).toEqual(false)
		expect(off.error).toEqual(DevTools.offMessage("waveArena"))
	end)

	it("enters, skips a wave, and spawns the boss when the switches are on", function()
		local config = fightConfig()
		local options = opened(config)
		local entered = WaveArena.dev("enter", nil, options)
		expect(entered.ok).toEqual(true)
		expect(entered.message).toEqual("Entered the wave arena.")
		expect(entered.run.wave).toEqual(1)
		expect(#entered.run.enemies).toEqual(2)

		local skipped = WaveArena.dev("skip", entered.run, options)
		expect(skipped.ok).toEqual(true)
		expect(skipped.message).toEqual("Skipped the wave.")
		expect(skipped.run.wave).toEqual(2)
		expect(skipped.run.enemies[1].kind).toEqual("boss")
		expect(skipped.run.earned.tokens).toEqual(1)

		local again = WaveArena.dev("enter", nil, options)
		local boss = WaveArena.dev("boss", again.run, options)
		expect(boss.ok).toEqual(true)
		expect(boss.message).toEqual("Spawned the boss.")
		expect(boss.run.enemies[1].kind).toEqual("boss")
		expect(boss.run.earned.tokens).toEqual(0)
		expect(boss.run.phase).toEqual("fight")

		local real = opened(withEnabled(true))
		local live = WaveArena.dev("enter", nil, real)
		local finale = WaveArena.dev("boss", live.run, real)
		expect(finale.run.wave).toEqual(5)
		expect(#finale.run.enemies).toEqual(5)
		expect(finale.run.enemies[1].id).toEqual("wave_boss")
	end)
end)
