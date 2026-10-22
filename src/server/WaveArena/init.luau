--!strict

--[[
	Server entry for the Phase 3 wave arena.

	build() and begin() do nothing unless both guards are on:
	LaunchGate.waveArena == true, and WaveArenaConfig.enabled == true.
	Requiring this module does not spawn parts, start a wave, or touch
	player data. It is not called from the live hub or Rootvault.

	When a round is allowed, the roster still comes only from config.
]]

-- init.luau is the folder module, so Lune resolves these from src/server.
local WaveArenaConfig = require("../shared/Config/WaveArenaConfig")
local Gate = require("./WaveArena/Gate")
local Graybox = require("./WaveArena/Graybox")
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

return WaveArena
