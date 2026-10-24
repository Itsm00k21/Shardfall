--!strict

--[[
	Server owner for the V1 wave flow (roadmap 3.5) and the wave-5 boss
	(roadmap 3.6).

	LaunchGate.SHOW.enemyTypes ships false. While it is off, start, hurt,
	and publish do nothing: no gray box, no damage, no counter push, no
	boss event. init.server does not call this module, so a normal boot
	never starts a run. The counter remote is server to client only.
	There is no profile write.

	bossEnter and bossDown go to an analytics hook when one exists.
	That hook is ReplicatedStorage.Shared.Analytics.event, or the
	sink.analytics function a caller passes. Neither path writes a save.
	The module is absent on this branch, so the lookup is a no-op.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel. Gray blocks live in
	EnemyPool. That module reuses them. This file does not create them.
]]

local LaunchGate
local WaveFlow
local Enemies
local EnemyPool
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	WaveFlow = require(Shared.WaveFlow)
	Enemies = require(Shared.Config.Enemies)
	EnemyPool = require(script.Parent.EnemyPool)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	WaveFlow = require("../../ReplicatedStorage/Shared/WaveFlow")
	Enemies = require("../../ReplicatedStorage/Shared/Config/Enemies")
	EnemyPool = require("./EnemyPool")
end

local WaveFlowService = {}

WaveFlowService.REMOTE = "WaveCounter"
WaveFlowService.BOSS_ENTER = "bossEnter"
WaveFlowService.BOSS_DOWN = "bossDown"

export type Payload = {
	wave: number,
	left: number,
}

export type EventDetail = {
	wave: number,
	adds: number?,
}

export type Sink = {
	player: any?,
	fire: ((any, Payload) -> ())?,
	build: ((WaveFlow.Box) -> any)?,
	analytics: ((string, EventDetail) -> ())?,
	platform: string?,
}

function WaveFlowService.open(): boolean
	return LaunchGate.on("enemyTypes")
end

local analyticsEvent: ((string, EventDetail) -> ())? = nil
local analyticsLooked = false

-- Shared.Analytics.event, once, if that module is in the tree.
local function lookupAnalytics(): ((string, EventDetail) -> ())?
	if analyticsLooked then
		return analyticsEvent
	end
	analyticsLooked = true
	local loaded: any = nil
	if game ~= nil and game.GetService ~= nil then
		local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
		local moduleScript = if shared ~= nil then shared:FindFirstChild("Analytics") else nil
		if moduleScript ~= nil and moduleScript:IsA("ModuleScript") then
			local ok, result = pcall(require, moduleScript)
			if ok then
				loaded = result
			end
		end
	else
		local ok, result = pcall(require, "../../ReplicatedStorage/Shared/Analytics")
		if ok then
			loaded = result
		end
	end
	if type(loaded) == "table" and type(loaded.event) == "function" then
		analyticsEvent = loaded.event
	end
	return analyticsEvent
end

local function emit(sink: Sink?, name: string, detail: EventDetail)
	local hook = if sink ~= nil then sink.analytics else nil
	if type(hook) ~= "function" then
		hook = lookupAnalytics()
	end
	if type(hook) == "function" then
		pcall(hook, name, detail)
	end
end

local function bossAlive(run: WaveFlow.Run): boolean
	local boss = Enemies.BOSS
	if boss == nil then
		return false
	end
	for _, member in ipairs(run.members) do
		if member.actor.kind == boss.id and member.actor.hp > 0 then
			return true
		end
	end
	return false
end

local function noteBoss(sink: Sink?, run: WaveFlow.Run, beforeWave: number, wasBoss: boolean)
	if run.wave == Enemies.BOSS_WAVE and beforeWave ~= Enemies.BOSS_WAVE then
		emit(sink, WaveFlowService.BOSS_ENTER, {
			wave = run.wave,
			adds = Enemies.BOSS_ADDS,
		})
	end
	if wasBoss and not bossAlive(run) then
		emit(sink, WaveFlowService.BOSS_DOWN, {
			wave = run.wave,
		})
	end
end

local function deliver(player: any, payload: Payload, fire: ((any, Payload) -> ())?): boolean
	if fire ~= nil then
		fire(player, payload)
		return true
	end
	if game == nil or game.GetService == nil then
		return false
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then
		return false
	end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if folder == nil then
		return false
	end
	local remote = folder:FindFirstChild(WaveFlowService.REMOTE)
	if remote == nil or not remote:IsA("RemoteEvent") then
		return false
	end
	remote:FireClient(player, payload)
	return true
end

-- One table, two fields. Callers cannot add a third field to the wire.
function WaveFlowService.publish(player: any, run: WaveFlow.Run?, fire: ((any, Payload) -> ())?): boolean
	if not WaveFlowService.open() or run == nil or player == nil then
		return false
	end
	local counter = WaveFlow.counter(run)
	local payload = {
		wave = counter.wave,
		left = counter.left,
	}
	return deliver(player, payload, fire)
end

type Track = {
	pool: EnemyPool.Pool,
	shown: { [number]: boolean },
}

local tracks: { [WaveFlow.Run]: Track } = {}

local function track(run: WaveFlow.Run): Track
	local found = tracks[run]
	if found ~= nil then
		return found
	end
	local created: Track = {
		pool = EnemyPool.create(),
		shown = {},
	}
	tracks[run] = created
	return created
end

-- Bind a pooled block to each living enemy. Fresh ids are described
-- once. Dead ids go back to the pool before the next bind, so a queued
-- spawn reuses a block instead of making another.
local function present(run: WaveFlow.Run, build: ((WaveFlow.Box) -> any)?)
	local owned = track(run)
	local living: { [number]: boolean } = {}
	local boxes = WaveFlow.boxes(run)
	for _, box in ipairs(boxes) do
		living[box.id] = true
	end
	owned.pool.releaseExcept(living)
	for _, box in ipairs(boxes) do
		owned.pool.bind(box.id, box.kind, box)
		if owned.shown[box.id] ~= true then
			owned.shown[box.id] = true
			if build ~= nil then
				build(box)
			end
		end
	end
end

function WaveFlowService.counter(run: WaveFlow.Run?): WaveFlow.Counter?
	if not WaveFlowService.open() or run == nil then
		return nil
	end
	return WaveFlow.counter(run)
end

function WaveFlowService.start(sink: Sink?): WaveFlow.Run?
	if not WaveFlowService.open() then
		return nil
	end
	local platform = if sink ~= nil then sink.platform else nil
	local run = WaveFlow.start(Enemies.aliveCap(platform))
	if run == nil then
		return nil
	end
	local build = if sink ~= nil then sink.build else nil
	present(run, build)
	if sink ~= nil then
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	noteBoss(sink, run, 0, false)
	return run
end

function WaveFlowService.hurt(run: WaveFlow.Run?, id: number, raw: number, sink: Sink?): number
	if not WaveFlowService.open() or run == nil then
		return 0
	end
	local before = WaveFlow.counter(run)
	local wasBoss = bossAlive(run)
	local taken = WaveFlow.hurt(run, id, raw)
	local build = if sink ~= nil then sink.build else nil
	present(run, build)
	local after = WaveFlow.counter(run)
	if sink ~= nil and (after.wave ~= before.wave or after.left ~= before.left) then
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	noteBoss(sink, run, before.wave, wasBoss)
	return taken
end

function WaveFlowService.body(run: WaveFlow.Run?, id: number): EnemyPool.Body?
	if not WaveFlowService.open() or run == nil or type(id) ~= "number" then
		return nil
	end
	local owned = tracks[run]
	if owned == nil then
		return nil
	end
	return owned.pool.body(id)
end

function WaveFlowService.pool(run: WaveFlow.Run?): EnemyPool.Stats?
	if not WaveFlowService.open() or run == nil then
		return nil
	end
	local owned = tracks[run]
	if owned == nil then
		return nil
	end
	return owned.pool.stats()
end

return WaveFlowService
