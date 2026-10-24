--!strict

--[[
	Server math for roadmap 3.5. Wave sizes and mixes come from
	Config/Enemies.luau. This module does not create parts, fire a
	remote, read a profile, or spend Robux.

	WaveFlowService is the gate. It calls these functions only while
	LaunchGate.enemyTypes is on. A client that requires this file can
	step a local table. It cannot grant loot or push the counter.
]]

local Enemies = require("./Config/Enemies")
local EnemyRoster = require("./EnemyRoster")

local WaveFlow = {}

export type Counter = {
	wave: number,
	left: number,
}

export type Box = {
	shape: string,
	id: number,
	kind: string,
	name: string,
	size: { number },
	color: { number },
	x: number,
	y: number,
	z: number,
	wave: number,
}

export type Member = {
	id: number,
	slot: number,
	actor: EnemyRoster.Actor,
}

export type Run = {
	wave: number,
	clear: boolean,
	nextId: number,
	members: { Member },
}

local function living(run: Run): number
	local left = 0
	for _, member in ipairs(run.members) do
		if member.actor.hp > 0 then
			left += 1
		end
	end
	return left
end

-- Kinds for one wave, in WAVE_ORDER. Nil when the wave is outside 1..4.
function WaveFlow.plan(wave: number): { string }?
	if type(wave) ~= "number" or wave ~= wave or wave ~= math.floor(wave) then
		return nil
	end
	local mix = Enemies.WAVE_MIXES[wave]
	local count = Enemies.WAVE_COUNTS[wave]
	if type(mix) ~= "table" or type(count) ~= "number" then
		return nil
	end
	local kinds = {}
	for _, role in ipairs(Enemies.WAVE_ORDER) do
		local amount = mix[role]
		if type(amount) ~= "number" or amount < 1 or amount ~= math.floor(amount) then
			return nil
		end
		for _ = 1, amount do
			table.insert(kinds, role)
		end
	end
	if #kinds ~= count then
		return nil
	end
	return kinds
end

local function spawnWave(run: Run, wave: number): boolean
	local kinds = WaveFlow.plan(wave)
	if kinds == nil then
		return false
	end
	local members = {}
	local nextId = run.nextId
	for slot, kind in ipairs(kinds) do
		local actor = EnemyRoster.spawn(kind, (slot - 1) * Enemies.WAVE_GAP, 0)
		if actor == nil then
			return false
		end
		table.insert(members, {
			id = nextId,
			slot = slot,
			actor = actor,
		})
		nextId += 1
	end
	run.nextId = nextId
	run.wave = wave
	run.clear = false
	run.members = members
	return true
end

function WaveFlow.start(): Run?
	local run: Run = {
		wave = 0,
		clear = false,
		nextId = 1,
		members = {},
	}
	if not spawnWave(run, 1) then
		return nil
	end
	return run
end

function WaveFlow.counter(run: Run): Counter
	return {
		wave = run.wave,
		left = living(run),
	}
end

function WaveFlow.boxes(run: Run): { Box }
	local boxes = {}
	for _, member in ipairs(run.members) do
		local actor = member.actor
		if actor.hp > 0 then
			local row = Enemies.TYPES[actor.kind]
			if row ~= nil then
				table.insert(boxes, {
					shape = "block",
					id = member.id,
					kind = actor.kind,
					name = row.name,
					size = { row.size[1], row.size[2], row.size[3] },
					color = { row.color[1], row.color[2], row.color[3] },
					x = actor.x,
					y = Enemies.WAVE_LIFT,
					z = actor.z,
					wave = run.wave,
				})
			end
		end
	end
	return boxes
end

-- Damage from the roster. A killing blow on the last enemy opens the
-- next wave, or marks the run clear when wave 4 is empty. A miss, a
-- dead id, or a hit that leaves HP up does not change the count.
function WaveFlow.hurt(run: Run, id: number, raw: number): number
	if run.clear == true or type(id) ~= "number" then
		return 0
	end
	local member: Member? = nil
	for _, candidate in ipairs(run.members) do
		if candidate.id == id and candidate.actor.hp > 0 then
			member = candidate
			break
		end
	end
	if member == nil then
		return 0
	end
	local taken = EnemyRoster.hurt(member.actor, raw)
	if taken <= 0 or member.actor.hp > 0 then
		return taken
	end
	if living(run) > 0 then
		return taken
	end
	local nextWave = run.wave + 1
	if Enemies.WAVE_COUNTS[nextWave] == nil or not spawnWave(run, nextWave) then
		run.clear = true
	end
	return taken
end

return WaveFlow
