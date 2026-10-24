--!strict

--[[
	Server owner for the V1 wave flow (roadmap 3.5), the wave-5 boss
	(roadmap 3.6), and the stuck-enemy watchdog (roadmap 3.8).

	LaunchGate.SHOW.enemyTypes ships false. While it is off, start, hurt,
	step, and publish do nothing: no gray box, no damage, no counter push,
	no boss event, no nudge, no respawn. init.server requires this module
	so PlayerRemoving and BindToClose connect, and it does not start a run.
	The counter remote is server to client only. There is no profile write
	from the watchdog. The watchdog does not fire a remote and does not
	build a HUD line.

	A boss-wave clear can pay Roll Tokens when the caller passes a
	profile and a persist callback. persist runs before the counter is
	fired. The callback must save and must not tell the client. A
	second clear for that run while the save is in flight does not pay
	again and does not fire. With no profile, the counter behaves as
	before and nothing is paid. The flag still has to be on.

	RunResults is a second server-to-client event. Its bossClear card
	is copied from the commit result after the save returns. A failed
	or unsaved grant is granted false. The client cannot supply the card.

	bossEnter and bossDown go to an analytics hook when one exists.
	That hook is ReplicatedStorage.Shared.Analytics.event, or the
	sink.analytics function a caller passes. The analytics module is
	absent on this branch, so the lookup is a no-op.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel. Gray blocks live in
	EnemyPool. That module reuses them. This file does not create them.
	stop destroys that run's parts, marks the run stopped, and releases
	its EnemyPerf slots. clear, wipe, PlayerRemoving, and BindToClose
	all call stop. A later hurt or present sees the mark and returns.
]]

local LaunchGate
local WaveFlow
local Enemies
local BossClearReward
local EnemyPool
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	WaveFlow = require(Shared.WaveFlow)
	Enemies = require(Shared.Config.Enemies)
	BossClearReward = require(Shared.BossClearReward)
	EnemyPool = require(script.Parent.EnemyPool)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	WaveFlow = require("../../ReplicatedStorage/Shared/WaveFlow")
	Enemies = require("../../ReplicatedStorage/Shared/Config/Enemies")
	BossClearReward = require("../../ReplicatedStorage/Shared/BossClearReward")
	EnemyPool = require("./EnemyPool")
end

local WaveFlowService = {}

WaveFlowService.REMOTE = "WaveCounter"
WaveFlowService.RESULTS = "RunResults"
WaveFlowService.BOSS_ENTER = "bossEnter"
WaveFlowService.BOSS_DOWN = "bossDown"

export type Payload = {
	wave: number,
	left: number,
}

export type BossClearCard = {
	granted: boolean,
	tokens: number,
}

export type Results = {
	bossClear: BossClearCard,
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
	-- Server profile. Absent means the clear is not paid.
	profile: any?,
	-- Save the profile. Must return true only after the write sticks.
	-- Must not tell the client. Called before fire on a boss clear.
	persist: ((any) -> boolean)?,
	-- RunResults. Separate from the wave counter.
	results: ((any, Results) -> ())?,
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

local function deliverResults(player: any, payload: Results, fire: ((any, Results) -> ())?): boolean
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
	local remote = folder:FindFirstChild(WaveFlowService.RESULTS)
	if remote == nil or not remote:IsA("RemoteEvent") then
		return false
	end
	remote:FireClient(player, payload)
	return true
end

-- One table. bossClear is the saved grant, not a client claim.
function WaveFlowService.publishResults(player: any, result: any, fire: ((any, Results) -> ())?): boolean
	if not WaveFlowService.open() or player == nil then
		return false
	end
	local card = BossClearReward.card(result)
	local payload = {
		bossClear = {
			granted = card.granted,
			tokens = card.tokens,
		},
	}
	return deliverResults(player, payload, fire)
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
	player: any,
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
		player = nil,
	}
	tracks[run] = created
	return created
end

-- End of a run. Parts are destroyed and this entry is dropped, so the
-- pool cannot outlive clear, wipe, PlayerRemoving, or BindToClose.
function WaveFlowService.stop(run: WaveFlow.Run?)
	if run == nil then
		return
	end
	-- Runtime only. Not saved. A stale hurt must not build a new pool.
	run.stopped = true
	WaveFlow.release(run)
	local owned = tracks[run]
	if owned == nil then
		return
	end
	tracks[run] = nil
	owned.pool.destroy()
end

function WaveFlowService.wipe(run: WaveFlow.Run?)
	WaveFlowService.stop(run)
end

-- The wave run owned by this player, if one is still tracked.
function WaveFlowService.runFor(player: any): WaveFlow.Run?
	if player == nil then
		return nil
	end
	for run, owned in pairs(tracks) do
		if owned.player == player then
			return run
		end
	end
	return nil
end

function WaveFlowService.entries(): number
	local count = 0
	for _ in pairs(tracks) do
		count += 1
	end
	return count
end

function WaveFlowService.onPlayerRemoving(player: any)
	if player == nil then
		return
	end
	local ending = {}
	for run, owned in pairs(tracks) do
		if owned.player == player then
			table.insert(ending, run)
		end
	end
	for _, run in ipairs(ending) do
		WaveFlowService.stop(run)
	end
end

function WaveFlowService.onClose()
	local ending = {}
	for run in pairs(tracks) do
		table.insert(ending, run)
	end
	for _, run in ipairs(ending) do
		WaveFlowService.stop(run)
	end
end

-- Bind a pooled block to each living enemy. Fresh ids are described
-- once. Dead ids go back to the pool before the next bind, so a later
-- wave reuses a block instead of making another.
local function present(run: WaveFlow.Run, build: ((WaveFlow.Box) -> any)?)
	if tracks[run] == nil and run.stopped == true then
		return
	end
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

-- Save the boss-clear grant before the caller fires the counter.
-- The second return is the commit result. RunResults is built from that.
-- No profile means there is nothing to pay and the counter may still go out.
local function payClear(sink: Sink, run: WaveFlow.Run): (boolean, BossClearReward.Result?)
	if sink.profile == nil or run.clear ~= true or run.wave ~= Enemies.BOSS_WAVE then
		return true, nil
	end
	if run.rewarded == true then
		return true, nil
	end
	local result = BossClearReward.commit(sink.profile, run.id, sink.persist)
	if result.saved == true then
		run.rewarded = true
		return true, result
	end
	return false, result
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
	local run = WaveFlow.start()
	if run == nil then
		return nil
	end
	local owned = track(run)
	owned.player = if sink ~= nil then sink.player else nil
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
	if tracks[run] == nil and run.stopped == true then
		return 0
	end
	local before = WaveFlow.counter(run)
	local wasBoss = bossAlive(run)
	local taken = WaveFlow.hurt(run, id, raw)
	local build = if sink ~= nil then sink.build else nil
	if run.clear ~= true then
		present(run, build)
	end
	local after = WaveFlow.counter(run)
	local needsPay = sink ~= nil and sink.profile ~= nil and run.clear == true and run.rewarded ~= true
	local paid = true
	if needsPay and sink ~= nil then
		local result: BossClearReward.Result? = nil
		paid, result = payClear(sink, run)
		WaveFlowService.publishResults(sink.player, result, sink.results)
	end
	local changed = after.wave ~= before.wave or after.left ~= before.left
	if sink ~= nil and paid and (changed or needsPay) then
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	noteBoss(sink, run, before.wave, wasBoss)
	if run.clear == true then
		WaveFlowService.stop(run)
	end
	return taken
end

-- One tick of movement and the stall clock. Nil while the flag is off,
-- so a boot with enemyTypes false does not move, nudge, or respawn anyone.
-- This does not publish the counter and does not write a profile.
function WaveFlowService.step(
	run: WaveFlow.Run?,
	targetX: number,
	targetZ: number,
	dt: number,
	obstacles: { WaveFlow.Obstacle }?
): { WaveFlow.Pulse }?
	if not WaveFlowService.open() or run == nil then
		return nil
	end
	return WaveFlow.step(run, targetX, targetZ, dt, obstacles)
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

if game ~= nil and game.GetService ~= nil then
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		WaveFlowService.onPlayerRemoving(player)
	end)
	game:BindToClose(function()
		WaveFlowService.onClose()
	end)
end

return WaveFlowService
