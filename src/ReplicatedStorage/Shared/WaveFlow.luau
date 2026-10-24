--!strict

--[[
	Server math for roadmap 3.5 and the wave-5 boss (3.6). Wave sizes,
	the boss, and the four adds come from Config/Enemies.luau. This
	module does not create parts, fire a remote, read a profile, or
	spend Robux. A wave spawns every enemy at once. Each spawn claims
	one slot from EnemyPerf, and a death or a stop releases it. This
	module does not keep a second cap or a stuck watchdog.

	WaveFlowService is the gate. It calls these functions only while
	LaunchGate.enemyTypes is on. A client that requires this file can
	step a local table. It cannot grant loot or push the counter.
]]

local Enemies = require("./Config/Enemies")
local EnemyPerf = require("./Config/EnemyPerf")
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
	-- Runtime only. stop sets this. It is not a save field.
	stopped: boolean?,
	perf: EnemyPerf.Pool?,
	held: { string }?,
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

-- Drop every slot this run still holds. Alive returns to zero.
function WaveFlow.release(run: Run)
	local held = run.held
	local pool = run.perf
	if held == nil or pool == nil then
		return
	end
	while #held > 0 do
		local kind = table.remove(held)
		if type(kind) == "string" then
			EnemyPerf.release(pool, kind)
		end
	end
end

local function releaseOne(run: Run, kind: string)
	local held = run.held
	local pool = run.perf
	if held == nil or pool == nil then
		return
	end
	local at = table.find(held, kind)
	if at == nil then
		return
	end
	table.remove(held, at)
	EnemyPerf.release(pool, kind)
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
	-- The previous wave is gone. Free those slots before claiming this one,
	-- so two waves never stack against the single cap of 22.
	WaveFlow.release(run)
	local pool = run.perf
	local held = run.held
	local kept = {}
	for index, kind in ipairs(kinds) do
		local keep = pool == nil or held == nil
		if pool ~= nil and held ~= nil then
			local action = EnemyPerf.claim(pool, kind)
			if action == "queued" then
				table.remove(pool.queued)
			else
				table.insert(held, kind)
				keep = true
			end
		end
		local member = members[index]
		if keep and member ~= nil then
			table.insert(kept, member)
		end
	end
	run.nextId = nextId
	run.wave = wave
	run.clear = false
	run.members = kept
	return true
end

function WaveFlow.start(): Run?
	local run: Run = {
		wave = 0,
		clear = false,
		nextId = 1,
		members = {},
		stopped = false,
		perf = EnemyPerf.newPool(),
		held = {},
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
	releaseOne(run, member.actor.kind)
	if living(run) > 0 then
		return taken
	end
	local nextWave = run.wave + 1
	if not spawnWave(run, nextWave) then
		run.clear = true
	end
	return taken
end

return WaveFlow
