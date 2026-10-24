--!strict

--[[
	Server owner for the V1 wave flow (roadmap 3.5) and the wave-5 boss
	(roadmap 3.6).

	LaunchGate.SHOW.enemyTypes ships false. While it is off, start, hurt,
	and publish do nothing: no gray box, no damage, no counter push, no
	boss event. init.server does not call this module, so a normal boot
	never starts a run. The counter remote is server to client only.

	A boss-wave clear can pay Roll Tokens when the caller passes a
	profile and a persist callback. persist runs before the counter is
	fired. The callback must save and must not tell the client. A
	second clear for that run while the save is in flight does not pay
	again and does not fire. With no profile, the counter behaves as
	before and nothing is paid. The flag still has to be on. Boot does
	not call this module.

	RunResults is a second server-to-client event. Its bossClear card
	is copied from the commit result after the save returns. A failed
	or unsaved grant is granted false. The client cannot supply the card.

	bossEnter and bossDown go to an analytics hook when one exists.
	That hook is ReplicatedStorage.Shared.Analytics.event, or the
	sink.analytics function a caller passes. The analytics module is
	absent on this branch, so the lookup is a no-op.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel. The service describes
	gray blocks. It does not parent them.
]]

local LaunchGate
local WaveFlow
local Enemies
local BossClearReward
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	WaveFlow = require(Shared.WaveFlow)
	Enemies = require(Shared.Config.Enemies)
	BossClearReward = require(Shared.BossClearReward)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	WaveFlow = require("../../ReplicatedStorage/Shared/WaveFlow")
	Enemies = require("../../ReplicatedStorage/Shared/Config/Enemies")
	BossClearReward = require("../../ReplicatedStorage/Shared/BossClearReward")
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

local function pushBoxes(run: WaveFlow.Run, build: ((WaveFlow.Box) -> any)?)
	if build == nil then
		return
	end
	for _, box in ipairs(WaveFlow.boxes(run)) do
		build(box)
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
	local build = if sink ~= nil then sink.build else nil
	pushBoxes(run, build)
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
		if after.wave ~= before.wave then
			pushBoxes(run, sink.build)
		end
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	noteBoss(sink, run, before.wave, wasBoss)
	return taken
end

return WaveFlowService
