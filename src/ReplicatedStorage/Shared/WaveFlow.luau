--!strict

--[[
	Server math for roadmap 3.5 and the wave-5 boss (3.6). Wave sizes,
	the boss, and the four adds come from Config/Enemies.luau. This
	module does not create parts, fire a remote, read a profile, or
	spend Robux.

	WaveFlowService passes the alive cap. Spawns past that cap wait on
	the run queue and join as others die. With no cap, a wave spawns
	every enemy at once, which is what a direct start() does.

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

export type Pending = {
	kind: string,
	slot: number,
}

export type Run = {
	wave: number,
	clear: boolean,
	nextId: number,
	members: { Member },
	queue: { Pending },
	cap: number?,
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

local function waiting(run: Run): number
	if run.queue == nil then
		return 0
	end
	return #run.queue
end

local function pushMember(members: { Member }, nextId: number, slot: number, kind: string): number?
	local actor = EnemyRoster.spawn(kind, (slot - 1) * Enemies.WAVE_GAP, 0)
	if actor == nil then
		return nil
	end
	table.insert(members, {
		id = nextId,
		slot = slot,
		actor = actor,
	})
	return nextId + 1
end

-- Boss first, then adds in WAVE_ORDER. Nil when the mix is not four adds.
local function bossPlan(): { string }?
	local boss = Enemies.BOSS
	local mix = Enemies.BOSS_ADD_MIX
	local adds = Enemies.BOSS_ADDS
	if boss == nil or type(boss.id) ~= "string" or type(mix) ~= "table" or type(adds) ~= "number" then
		return nil
	end
	local kinds = { boss.id }
	local sum = 0
	for _, role in ipairs(Enemies.WAVE_ORDER) do
		local amount = mix[role]
		if amount == nil then
			amount = 0
		end
		if type(amount) ~= "number" or amount < 0 or amount ~= math.floor(amount) then
			return nil
		end
		for _ = 1, amount do
			table.insert(kinds, role)
		end
		sum += amount
	end
	for key in pairs(mix) do
		if table.find(Enemies.WAVE_ORDER, key) == nil then
			return nil
		end
	end
	if sum ~= adds or #kinds ~= adds + 1 then
		return nil
	end
	return kinds
end

-- Kinds for one wave. Trash waves follow WAVE_ORDER. Wave 5 is the boss
-- plan. Nil when the wave is outside that list.
function WaveFlow.plan(wave: number): { string }?
	if type(wave) ~= "number" or wave ~= wave or wave ~= math.floor(wave) then
		return nil
	end
	if wave == Enemies.BOSS_WAVE then
		return bossPlan()
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

-- How many of this wave may be alive. Nil or a non-positive cap means
-- the whole wave. A smaller cap leaves the rest on the queue, in order.
local function roomFor(run: Run, count: number): number
	local cap = run.cap
	if type(cap) ~= "number" or cap ~= cap or cap < 1 or cap >= count then
		return count
	end
	return math.floor(cap)
end

local function spawnWave(run: Run, wave: number): boolean
	local kinds = WaveFlow.plan(wave)
	if kinds == nil then
		return false
	end
	local room = roomFor(run, #kinds)
	local members = {}
	local queue: { Pending } = {}
	local nextId = run.nextId
	for slot, kind in ipairs(kinds) do
		if #members < room then
			local advanced = pushMember(members, nextId, slot, kind)
			if advanced == nil then
				return false
			end
			nextId = advanced
		else
			table.insert(queue, {
				kind = kind,
				slot = slot,
			})
		end
	end
	run.nextId = nextId
	run.wave = wave
	run.clear = false
	run.members = members
	run.queue = queue
	return true
end

-- Pull queued spawns until the cap is full or the queue is empty.
local function fill(run: Run)
	local cap = run.cap
	if type(cap) ~= "number" or cap < 1 then
		return
	end
	local room = math.floor(cap) - living(run)
	while room > 0 and waiting(run) > 0 do
		local pending = table.remove(run.queue, 1)
		if pending == nil then
			break
		end
		local advanced = pushMember(run.members, run.nextId, pending.slot, pending.kind)
		if advanced == nil then
			table.insert(run.queue, 1, pending)
			return
		end
		run.nextId = advanced
		room -= 1
	end
end

function WaveFlow.start(cap: number?): Run?
	local run: Run = {
		wave = 0,
		clear = false,
		nextId = 1,
		members = {},
		queue = {},
		cap = nil,
	}
	if type(cap) == "number" and cap == cap and cap >= 1 then
		run.cap = math.floor(cap)
	end
	if not spawnWave(run, 1) then
		return nil
	end
	return run
end

function WaveFlow.counter(run: Run): Counter
	return {
		wave = run.wave,
		left = living(run) + waiting(run),
	}
end

function WaveFlow.boxes(run: Run): { Box }
	local boxes = {}
	for _, member in ipairs(run.members) do
		local actor = member.actor
		if actor.hp > 0 then
			local row = Enemies.row(actor.kind)
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
-- next wave. The run is clear when the boss wave is empty. A miss, a
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
	if living(run) > 0 or waiting(run) > 0 then
		fill(run)
		if living(run) > 0 then
			return taken
		end
	end
	local nextWave = run.wave + 1
	if not spawnWave(run, nextWave) then
		run.clear = true
	end
	return taken
end

return WaveFlow
