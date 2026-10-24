--!strict

--[[
	Server entry for the Phase 3 wave arena.

	build() and begin() do nothing unless both guards are on:
	LaunchGate.waveArena == true, and WaveArenaConfig.enabled == true.
	Requiring this module does not spawn parts, start a wave, or touch
	player data. It is not called from the live hub or Rootvault.

	When a round is allowed, the roster still comes only from config.
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

-- init.luau is the folder module, so Lune resolves these from src/server.
local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")
local Camera = require("./WaveArena/Camera")
local Gate = require("./WaveArena/Gate")
local Graybox = require("./WaveArena/Graybox")
local HubPad = require("./WaveArena/HubPad")
local Hud = require("./WaveArena/Hud")
local Round = require("./WaveArena/Round")
local Spawns = require("./WaveArena/Spawns")
local Waves = require("./WaveArena/Waves")

local WaveArena = {}

export type Run = {
	wave: number,
	over: boolean,
	roster: { Waves.Unit },
	spawned: { Spawns.Placed },
}

local function ready(launchGate: any, config: any): any?
	if not Gate.open(launchGate, config) then
		return nil
	end
	local cfg = if config == nil then WaveArenaConfig else config
	if typeof(cfg) ~= "table" or typeof(cfg.arena) ~= "table" then
		return nil
	end
	if cfg.arena.diameter < cfg.minDiameter then
		return nil
	end
	if cfg.arena.diameter + 1e-6 < Spawns.minimumDiameter(cfg) then
		return nil
	end
	local densest = Spawns.place(Waves.densest(cfg), cfg)
	local boss = Spawns.place(Waves.bossIndex(cfg), cfg)
	if not Spawns.allClear(densest) or not Spawns.allClear(boss) then
		return nil
	end
	return cfg
end

local function resolve(options: any): (any, any, any)
	if typeof(options) ~= "table" then
		return nil, nil, nil
	end
	return options.launchGate, options.config, options.create
end

function WaveArena.build(options: any?): { Graybox.PartPlan }?
	local launchGate, config, create = resolve(options)
	local cfg = ready(launchGate, config)
	if cfg == nil then
		return nil
	end
	local parts = Graybox.plan(cfg)
	if #parts == 0 then
		return nil
	end
	if create ~= nil then
		for _, part in ipairs(parts) do
			create(part)
		end
	end
	return parts
end

function WaveArena.begin(options: any?): Run?
	local launchGate, config = resolve(options)
	local cfg = ready(launchGate, config)
	if cfg == nil then
		return nil
	end
	local spawned = Spawns.place(1, cfg)
	if not Spawns.allClear(spawned) then
		return nil
	end
	return {
		wave = 1,
		over = false,
		roster = Waves.roster(1, cfg),
		spawned = spawned,
	}
end

function WaveArena.advance(run: any, options: any?): Run?
	local launchGate, config = resolve(options)
	local cfg = ready(launchGate, config)
	if cfg == nil or typeof(run) ~= "table" or typeof(run.wave) ~= "number" then
		return nil
	end
	local nextWave = run.wave + 1
	if Waves.def(nextWave, cfg) == nil then
		return {
			wave = run.wave,
			over = true,
			roster = {},
			spawned = {},
		}
	end
	local spawned = Spawns.place(nextWave, cfg)
	return {
		wave = nextWave,
		over = false,
		roster = Waves.roster(nextWave, cfg),
		spawned = spawned,
	}
end

function WaveArena.hubPad(options: any?): any
	local launchGate, config = resolve(options)
	return HubPad.plan(launchGate, config)
end

-- Arena parts plus the hub pad. Nil, and create is not called, while gated.
function WaveArena.present(options: any?): any
	local launchGate, config, create = resolve(options)
	if not Gate.open(launchGate, config) then
		return nil
	end
	local parts = WaveArena.build(options)
	local pad = HubPad.plan(launchGate, config)
	if parts == nil or pad == nil then
		return nil
	end
	if create ~= nil then
		create(pad)
	end
	return { arena = parts, pad = pad }
end

function WaveArena.enter(options: any?): any
	return Round.enter(options)
end

function WaveArena.step(run: any, dt: any, input: any, options: any?): (any, { any })
	return Round.step(run, dt, input, options)
end

function WaveArena.settle(run: any, reason: any, options: any?): (any, { any })
	return Round.settle(run, reason, options)
end

function WaveArena.skip(run: any, options: any?): (any, { any })
	return Round.skip(run, options)
end

function WaveArena.spawnBoss(run: any, options: any?): (any, { any })
	return Round.spawnBoss(run, options)
end

function WaveArena.hud(run: any, options: any?): any
	local launchGate, config = resolve(options)
	return Hud.snapshot(run, Gate.open(launchGate, config), config)
end

function WaveArena.camera(eye: any, center: any, size: { number }, config: any?): any
	local cfg = if config == nil then WaveArenaConfig else config
	return Camera.correct(eye, center, size, cfg)
end

function WaveArena.dev(action: any, run: any, options: any?): any
	local launchGate, config = resolve(options)
	if not Gate.open(launchGate, config) then
		return {
			ok = false,
			error = "The wave arena is off (LaunchGate.waveArena), so this does nothing yet.",
		}
	end
	if action == "enter" then
		local started = Round.enter(options)
		if started == nil then
			return { ok = false, error = "Could not enter the arena." }
		end
		return { ok = true, message = "Entered the wave arena.", run = started }
	end
	if action == "skip" then
		if typeof(run) ~= "table" then
			return { ok = false, error = "No arena run." }
		end
		local updated = Round.skip(run, options)
		if updated == nil then
			return { ok = false, error = "No arena run." }
		end
		return { ok = true, message = "Skipped the wave.", run = updated }
	end
	if action == "boss" then
		if typeof(run) ~= "table" then
			return { ok = false, error = "No arena run." }
		end
		local updated = Round.spawnBoss(run, options)
		if updated == nil then
			return { ok = false, error = "No arena run." }
		end
		return { ok = true, message = "Spawned the boss.", run = updated }
	end
	return { ok = false, error = "Unknown arena action." }
end

return WaveArena
