--!strict

--[[
	Server owner for the V1 wave flow (roadmap 3.5).

	LaunchGate.SHOW.enemyTypes ships false. While it is off, start, hurt,
	and publish do nothing: no gray box, no damage, no counter push.
	init.server does not call this module, so a normal boot never starts
	a run. The counter remote is server to client only. There is no
	profile write.

	Studio can require the module. Lune loads the same file through the
	relative path when `game` is not a DataModel. The service describes
	gray blocks. It does not parent them.
]]

local LaunchGate
local WaveFlow
if game ~= nil and game.GetService ~= nil then
	local Shared = game:GetService("ReplicatedStorage").Shared
	LaunchGate = require(Shared.LaunchGate)
	WaveFlow = require(Shared.WaveFlow)
else
	LaunchGate = require("../../ReplicatedStorage/Shared/LaunchGate")
	WaveFlow = require("../../ReplicatedStorage/Shared/WaveFlow")
end

local WaveFlowService = {}

WaveFlowService.REMOTE = "WaveCounter"

export type Payload = {
	wave: number,
	left: number,
}

export type Sink = {
	player: any?,
	fire: ((any, Payload) -> ())?,
	build: ((WaveFlow.Box) -> any)?,
}

function WaveFlowService.open(): boolean
	return LaunchGate.on("enemyTypes")
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

local function pushBoxes(run: WaveFlow.Run, build: ((WaveFlow.Box) -> any)?)
	if build == nil then
		return
	end
	for _, box in ipairs(WaveFlow.boxes(run)) do
		build(box)
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
	local run = WaveFlow.start()
	if run == nil then
		return nil
	end
	local build = if sink ~= nil then sink.build else nil
	pushBoxes(run, build)
	if sink ~= nil then
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	return run
end

function WaveFlowService.hurt(run: WaveFlow.Run?, id: number, raw: number, sink: Sink?): number
	if not WaveFlowService.open() or run == nil then
		return 0
	end
	local before = WaveFlow.counter(run)
	local taken = WaveFlow.hurt(run, id, raw)
	local after = WaveFlow.counter(run)
	if after.wave ~= before.wave and sink ~= nil then
		pushBoxes(run, sink.build)
	end
	if sink ~= nil and (after.wave ~= before.wave or after.left ~= before.left) then
		WaveFlowService.publish(sink.player, run, sink.fire)
	end
	return taken
end

return WaveFlowService
