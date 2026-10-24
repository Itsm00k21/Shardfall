--!strict

--[[
	Wave HUD fields on the server snapshot.

	In the arena: enemiesLeft, addsLeft, bossName or "Wave n/n", the
	difficulty tier, isHardReal, and secondsLeft. Outside: the same fields
	at rest, and nil while the arena switch is off. isHardReal follows
	HardMode.isHardReal(). schemaVersion stays 26. Nothing is saved.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Hud = require("../src/server/WaveArena/Hud")
local HardMode = require("../src/ReplicatedStorage/Shared/HardMode")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveArena = require("../src/server/WaveArena")
local WaveArenaConfig = require("../src/ReplicatedStorage/Shared/Config/WaveArenaConfig")

local function opened(config: any): any
	return {
		launchGate = { waveArena = true },
		config = config,
	}
end

local function enabled(): any
	local copy = table.clone(WaveArenaConfig)
	copy.enabled = true
	copy.timeout = 90
	return copy
end

local function fight(extra: any): any
	local run = {
		inArena = true,
		wave = 1,
		total = 5,
		phase = "fight",
		tier = "normal",
		seconds = 0,
		enemies = {},
		card = nil,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			run[key] = value
		end
	end
	return run
end

describe("Wave HUD snapshot", function()
	it("ships the arena flags off and schema 26", function()
		expect(Schema.VERSION).toEqual(26)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.on("waveArena")).toEqual(false)
		expect(LaunchGate.on("hardMode")).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		local source = fs.readFile("src/server/WaveArena/Hud.luau")
		expect(string.find(source, "HardMode.isHardReal()", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "local HARD_IS_REAL = false", 1, true)).toBeNil()
		expect(string.find(source, "isHardReal = true", 1, true)).toBeNil()
	end)

	it("returns no snapshot while the arena is closed", function()
		local run = fight({
			enemies = {
				{ kind = "boss", alive = true, name = "Ash Warden", hp = 10, maxHp = 10 },
			},
		})
		expect(Hud.snapshot(run, false)).toBeNil()
		expect(Hud.snapshot(nil, false)).toBeNil()
		expect(WaveArena.hud(run, nil)).toBeNil()
		expect(WaveArena.hud(run, { launchGate = { waveArena = false }, config = enabled() })).toBeNil()
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
	end)

	it("returns every field at rest outside the arena", function()
		local config = enabled()
		local leaked = {
			inArena = false,
			wave = 4,
			total = 5,
			tier = "hard",
			seconds = 80,
			phase = "fight",
			card = { kind = "results" },
			enemies = {
				{ kind = "chaser", alive = true },
				{ kind = "add", alive = true },
				{ kind = "boss", alive = true, name = "Ash Warden", hp = 8, maxHp = 8 },
			},
		}
		local direct = Hud.snapshot(leaked, true, config)
		local missing = WaveArena.hud(nil, opened(config))
		for _, hud in ipairs({ direct, missing }) do
			expect(type(hud.enemiesLeft)).toEqual("number")
			expect(hud.enemiesLeft).toEqual(0)
			expect(type(hud.addsLeft)).toEqual("number")
			expect(hud.addsLeft).toEqual(0)
			expect(hud.bossName).toBeNil()
			expect(hud.label).toBeNil()
			expect(type(hud.isHardReal)).toEqual("boolean")
			expect(hud.isHardReal).toEqual(false)
			expect(hud.secondsLeft).toBeNil()
			expect(hud.boss.shown).toEqual(false)
			expect(hud.text).toEqual("")
		end
		expect(type(direct.difficulty)).toEqual("string")
		expect(direct.difficulty).toEqual("hard")
		expect(type(missing.difficulty)).toEqual("string")
		expect(missing.difficulty).toEqual("normal")
		local host = fs.readFile("src/ServerScriptService/ShardfallServer/WaveArenaHost.luau")
		expect(string.find(host, "local hud = arena.hud(run, options(config))", 1, true) ~= nil).toBeTrue()
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)

	it("counts a normal wave and the seconds left, including the last minute", function()
		local config = enabled()
		local run = fight({
			wave = 2,
			total = 5,
			seconds = 0,
			enemies = {
				{ kind = "chaser", alive = true },
				{ kind = "ranged", alive = true },
				{ kind = "tank", alive = false },
				{ kind = "add", alive = false },
			},
		})
		local hud = Hud.snapshot(run, true, config)
		expect(type(hud.enemiesLeft)).toEqual("number")
		expect(hud.enemiesLeft).toEqual(2)
		expect(type(hud.addsLeft)).toEqual("number")
		expect(hud.addsLeft).toEqual(0)
		expect(hud.bossName).toBeNil()
		expect(type(hud.label)).toEqual("string")
		expect(hud.label).toEqual("Wave 2/5")
		expect(hud.text).toEqual("Wave 2 / 5")
		expect(type(hud.difficulty)).toEqual("string")
		expect(hud.difficulty).toEqual("normal")
		expect(hud.isHardReal).toEqual(false)
		expect(type(hud.secondsLeft)).toEqual("number")
		expect(hud.secondsLeft).toEqual(90)

		run.seconds = 29
		expect(Hud.snapshot(run, true, config).secondsLeft).toEqual(61)
		run.seconds = 30
		expect(Hud.snapshot(run, true, config).secondsLeft).toEqual(60)
		run.seconds = 31
		expect(Hud.snapshot(run, true, config).secondsLeft).toEqual(59)
		run.seconds = 100
		expect(Hud.snapshot(run, true, config).secondsLeft).toEqual(0)
	end)

	it("names a living boss and counts its adds, then returns the wave label", function()
		local config = enabled()
		local run = fight({
			wave = 5,
			total = 5,
			tier = "HARD",
			seconds = 40,
			enemies = {
				{ kind = "boss", alive = true, name = "Ash Warden", hp = 40, maxHp = 80 },
				{ kind = "add", alive = true },
				{ kind = "add", alive = true },
				{ kind = "add", alive = false },
				{ kind = "chaser", alive = false },
			},
		})
		local hud = Hud.snapshot(run, true, config)
		expect(hud.enemiesLeft).toEqual(1)
		expect(hud.addsLeft).toEqual(2)
		expect(type(hud.bossName)).toEqual("string")
		expect(hud.bossName).toEqual("Ash Warden")
		expect(hud.label).toBeNil()
		expect(hud.difficulty).toEqual("hard")
		expect(hud.isHardReal).toEqual(false)
		expect(hud.secondsLeft).toEqual(50)
		expect(hud.boss.shown).toEqual(true)
		expect(hud.text).toEqual("Wave 5 / 5")

		run.enemies[1].alive = false
		run.enemies[1].name = ""
		local after = Hud.snapshot(run, true, config)
		expect(after.enemiesLeft).toEqual(0)
		expect(after.addsLeft).toEqual(2)
		expect(after.bossName).toBeNil()
		expect(after.label).toEqual("Wave 5/5")
		expect(after.boss.shown).toEqual(false)

		run.enemies[1].alive = true
		run.enemies[1].name = nil
		expect(Hud.snapshot(run, true, config).bossName).toEqual("Boss")
	end)

	it("fills the same fields from a live wave and a live boss wave", function()
		local config = enabled()
		local options = opened(config)
		options.tier = "hard"
		local wave = WaveArena.enter(options)
		expect(wave ~= nil).toBeTrue()
		local hud = WaveArena.hud(wave, options)
		expect(hud.enemiesLeft).toEqual(6)
		expect(hud.addsLeft).toEqual(0)
		expect(hud.bossName).toBeNil()
		expect(hud.label).toEqual("Wave 1/5")
		expect(hud.text).toEqual("Wave 1 / 5")
		-- A hard request stays Normal while the flag is off.
		expect(wave.tier).toEqual("normal")
		expect(hud.difficulty).toEqual("normal")
		expect(hud.isHardReal).toEqual(false)
		expect(hud.secondsLeft).toEqual(90)
		expect(hud.phase).toEqual("fight")

		options.wave = 5
		local boss = WaveArena.enter(options)
		expect(boss ~= nil).toBeTrue()
		local bossHud = WaveArena.hud(boss, options)
		expect(bossHud.enemiesLeft).toEqual(1)
		expect(bossHud.addsLeft).toEqual(4)
		expect(bossHud.bossName).toEqual("Boss")
		expect(bossHud.label).toBeNil()
		expect(boss.tier).toEqual("normal")
		expect(bossHud.difficulty).toEqual("normal")
		expect(bossHud.isHardReal).toEqual(false)
		expect(bossHud.secondsLeft).toEqual(90)
		expect(bossHud.boss.shown).toEqual(true)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(WaveArenaConfig.enabled).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)

	it("reads isHardReal from HardMode, true only while the flag and the hard row agree", function()
		local previous = LaunchGate.SHOW.hardMode
		local function restore()
			LaunchGate.SHOW.hardMode = previous
		end
		local config = enabled()
		local run = fight({ tier = "hard" })
		local ok, err = pcall(function()
			expect(HardMode.applies(WaveArenaConfig.hard)).toEqual(true)
			LaunchGate.SHOW.hardMode = false
			expect(HardMode.isHardReal()).toEqual(false)
			expect(Hud.snapshot(run, true, config).isHardReal).toEqual(false)
			expect(Hud.snapshot({ inArena = false, tier = "hard" }, true, config).isHardReal).toEqual(false)
			LaunchGate.SHOW.hardMode = true
			expect(HardMode.isHardReal()).toEqual(true)
			expect(Hud.snapshot(run, true, config).isHardReal).toEqual(true)
			expect(Hud.snapshot({ inArena = false, tier = "hard" }, true, config).isHardReal).toEqual(true)
		end)
		restore()
		if not ok then
			error(err, 0)
		end
		expect(LaunchGate.SHOW.hardMode).toEqual(false)
		expect(LaunchGate.SHOW.waveArena).toEqual(false)
		expect(Schema.VERSION).toEqual(26)
	end)
end)
