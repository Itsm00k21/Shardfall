--!strict

--[[
	Server round. Positions, damage, drops, and the results card are decided
	here. A tick may move and attack. It cannot set its own damage or hp.

	Leave keeps what was already picked up and what cleared waves swept in.
	Chips still on the ground for the current wave are dropped. The boss
	wave waits deathHold seconds after the killing blow before the card.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")
local Boss = require("./Boss")
local Enemies = require("./Enemies")
local Feel = require("./Feel")
local Gate = require("./Gate")
local Graybox = require("./Graybox")
local Loot = require("./Loot")
local Spawns = require("./Spawns")
local Stuck = require("./Stuck")
local Waves = require("./Waves")

local Round = {}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

local function emit(events: { any }, item: any)
	table.insert(events, item)
end

local function finite(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function positive(value: any, fallback: number): number
	if finite(value) and value > 0 then
		return value
	end
	return fallback
end

local function length(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

local function clampInside(x: number, z: number, radius: number, config: any): (number, number)
	local inner = Spawns.innerRadius(config)
	local limit = math.max(0, inner - config.spawn.margin - radius)
	local dist = length(x, z)
	if dist ~= dist then
		return 0, 0
	end
	if dist > limit and dist > 0 then
		local scale = limit / dist
		return x * scale, z * scale
	end
	return x, z
end

local function moveToward(
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	dt: number,
	radius: number,
	config: any
): (number, number)
	local dx = tx - x
	local dz = tz - z
	local dist = length(dx, dz)
	if dist < 1e-4 or dist ~= dist then
		return x, z
	end
	local step = math.min(dist, math.max(0, speed) * dt)
	return clampInside(x + dx / dist * step, z + dz / dist * step, radius, config)
end

local function axis(value: any): number
	if not finite(value) then
		return 0
	end
	return math.clamp(value, -1, 1)
end

local function livingCount(run: any): number
	local count = 0
	for _, enemy in ipairs(run.enemies) do
		if enemy.alive then
			count += 1
		end
	end
	return count
end

local function hasBoss(run: any): boolean
	for _, enemy in ipairs(run.enemies) do
		if enemy.kind == "boss" then
			return true
		end
	end
	return false
end

local function cardOf(run: any, leftEarly: boolean, died: boolean): any
	return {
		kind = "results",
		wavesCleared = run.wavesCleared,
		bestWave = run.bestWave,
		wave = run.wave,
		leftEarly = leftEarly,
		died = died,
		cleared = run.wavesCleared >= run.total and died ~= true,
		loot = {
			tokens = run.earned.tokens,
			fragments = run.earned.fragments,
			drops = table.clone(run.earned.drops),
		},
	}
end

local function showResults(run: any, leftEarly: boolean, died: boolean, events: { any })
	run.phase = if leftEarly then "left" else "results"
	run.over = true
	run.died = died
	run.card = cardOf(run, leftEarly, died)
	run.cleared = run.card.cleared
	local reason = "cleared"
	if died then
		reason = "died"
	elseif leftEarly then
		reason = "left"
	end
	emit(events, { kind = "metric", name = "run_end", reason = reason, wave = run.wave })
	emit(events, run.card)
end

local function dropFor(run: any, enemy: any, config: any, events: { any })
	local payload = Loot.payload(enemy.kind, config)
	run.nextDrop += 1
	local drop = {
		uid = run.nextDrop,
		dropId = payload.dropId,
		tokens = payload.tokens,
		fragments = payload.fragments,
		x = enemy.x,
		z = enemy.z,
		wave = run.wave,
	}
	table.insert(run.ground, drop)
	emit(events, {
		kind = "drop",
		id = drop.uid,
		dropId = drop.dropId,
		x = drop.x,
		z = drop.z,
		fragments = drop.fragments,
	})
end

local function kill(run: any, enemy: any, config: any, events: { any })
	if enemy.alive ~= true then
		return
	end
	enemy.alive = false
	enemy.hp = 0
	enemy.windLeft = 0
	if enemy.small == true then
		emit(events, Feel.deathPuff(enemy, config))
	end
	dropFor(run, enemy, config, events)
end

local function autoCollect(run: any, config: any, events: { any })
	if run.paid[run.wave] ~= true then
		local tokens = Loot.purse(run.wave, config)
		run.earned.tokens += tokens
		run.paid[run.wave] = true
		emit(events, { kind = "wavePurse", wave = run.wave, tokens = tokens })
	end
	local count = #run.ground
	for _, drop in ipairs(run.ground) do
		Loot.take(run.earned, drop)
		emit(events, {
			kind = "pickup",
			id = drop.uid,
			dropId = drop.dropId,
			tokens = drop.tokens,
			fragments = drop.fragments,
			auto = true,
		})
	end
	run.ground = {}
	emit(events, { kind = "autoCollect", count = count, wave = run.wave })
end

local function makeEnemy(load: any, placed: any, config: any, uid: number): any
	local profile = WaveArenaConfig.profile(config, load.kind)
	return {
		uid = uid,
		id = profile.id,
		kind = load.kind,
		typeIndex = load.typeIndex,
		hp = profile.hp,
		maxHp = profile.hp,
		x = placed.x,
		z = placed.z,
		radius = placed.radius,
		speed = profile.moveSpeed,
		attackRange = profile.attackRange or profile.arrive,
		attackRadius = profile.attackRadius,
		prefer = profile.prefer,
		damage = profile.damage,
		interval = profile.attackInterval,
		windupTotal = profile.windup or 0.5,
		cooldown = profile.opening or 0,
		windLeft = 0,
		warning = nil,
		alive = true,
		anchorX = placed.x,
		anchorZ = placed.z,
		stillFor = 0,
		small = load.kind ~= "boss",
	}
end

local function spawnInto(run: any, waveIndex: number, config: any): boolean
	local placed = Spawns.place(waveIndex, config)
	if not Spawns.allClear(placed) then
		return false
	end
	local loadout = Enemies.loadout(waveIndex, config)
	if #loadout ~= #placed then
		return false
	end
	local enemies = {}
	for index, unit in ipairs(placed) do
		run.nextUid += 1
		table.insert(enemies, makeEnemy(loadout[index], unit, config, run.nextUid))
	end
	run.enemies = enemies
	run.wave = waveIndex
	run.phase = "fight"
	run.hold = 0
	return true
end

local function markCleared(run: any)
	run.wavesCleared = run.wave
	if run.wave > run.bestWave then
		run.bestWave = run.wave
	end
end

local function finishWave(run: any, config: any, events: { any })
	markCleared(run)
	if hasBoss(run) then
		run.phase = "deathHold"
		run.hold = config.boss.deathHold or 1.5
		emit(events, { kind = "bossDown", hold = run.hold })
		return
	end
	autoCollect(run, config, events)
	local nextWave = run.wave + 1
	if Waves.def(nextWave, config) == nil or not spawnInto(run, nextWave, config) then
		showResults(run, false, false, events)
		return
	end
	emit(events, { kind = "wave", wave = run.wave })
	emit(events, { kind = "metric", name = "wave_reached", wave = run.wave })
end

local function collectNear(run: any, config: any, events: { any })
	local radius = config.loot.pickupRadius
	local kept = {}
	for _, drop in ipairs(run.ground) do
		if Loot.near(run.player.x, run.player.z, drop, radius) then
			Loot.take(run.earned, drop)
			emit(events, {
				kind = "pickup",
				id = drop.uid,
				dropId = drop.dropId,
				tokens = drop.tokens,
				fragments = drop.fragments,
				auto = false,
			})
		else
			table.insert(kept, drop)
		end
	end
	run.ground = kept
end

local function movePlayer(run: any, dt: number, input: any, config: any)
	local player = run.player
	local mx = axis(if typeof(input) == "table" then input.moveX else nil)
	local mz = axis(if typeof(input) == "table" then input.moveZ else nil)
	local dist = length(mx, mz)
	if dist > 1 then
		mx /= dist
		mz /= dist
	end
	if dist > 0 then
		local step = player.speed * dt
		player.x, player.z =
			clampInside(player.x + mx * step, player.z + mz * step, player.radius, config)
	end
end

local function nearest(run: any): any
	local player = run.player
	local best = nil
	local bestDist = math.huge
	for _, enemy in ipairs(run.enemies) do
		if enemy.alive then
			local dist = length(player.x - enemy.x, player.z - enemy.z)
			local reach = player.range + enemy.radius
			if dist <= reach and dist < bestDist then
				best = enemy
				bestDist = dist
			end
		end
	end
	return best
end

local function strike(run: any, input: any, dt: number, config: any, events: { any })
	local player = run.player
	local attack = typeof(input) == "table" and input.attack == true
	if attack and player.cooldown <= 0 then
		local target = nearest(run)
		if target ~= nil then
			-- input.damage is ignored. The server snapshot is player.damage.
			target.hp -= player.damage
			if target.small == true then
				emit(events, Feel.hitFlash(target, config))
			end
			if target.hp <= 0 then
				kill(run, target, config, events)
			end
		end
		player.cooldown = player.interval
		return
	end
	player.cooldown = math.max(0, player.cooldown - dt)
end

local function spotBlocked(x: number, z: number, enemy: any, run: any, config: any): boolean
	local inner = Spawns.innerRadius(config)
	if Spawns.blocked(x, z, enemy.radius, inner, Graybox.solids(config)) then
		return true
	end
	for _, other in ipairs(run.enemies) do
		if other.alive and other.uid ~= enemy.uid then
			local dx = x - other.x
			local dz = z - other.z
			local need = enemy.radius + other.radius + config.spawn.gap
			if dx * dx + dz * dz < need * need then
				return true
			end
		end
	end
	return false
end

local function placeEnemy(enemy: any, x: number, z: number, events: { any })
	enemy.x = x
	enemy.z = z
	enemy.anchorX = x
	enemy.anchorZ = z
	enemy.stillFor = 0
	emit(events, { kind = "teleport", id = enemy.uid, x = x, z = z })
end

local function recover(run: any, enemy: any, config: any, events: { any })
	local nx, nz, action = Stuck.recover(enemy, config)
	if action == "teleport" and not spotBlocked(nx, nz, enemy, run, config) then
		placeEnemy(enemy, nx, nz, events)
		return
	end
	if enemy.kind == "boss" then
		local spot = config.spawn.boss
		if not spotBlocked(spot.x, spot.z, enemy, run, config) then
			placeEnemy(enemy, spot.x, spot.z, events)
			return
		end
	end
	emit(events, { kind = "despawn", id = enemy.uid })
	kill(run, enemy, config, events)
end

local function markProgress(enemy: any)
	enemy.anchorX = enemy.x
	enemy.anchorZ = enemy.z
	enemy.stillFor = 0
end

local function enemyMind(run: any, enemy: any, dt: number, config: any, events: { any })
	local player = run.player
	local dist = length(player.x - enemy.x, player.z - enemy.z)
	if enemy.windLeft > 0 then
		enemy.windLeft -= dt
		if enemy.windLeft <= 0 then
			local damage = 0
			if enemy.kind == "boss" or enemy.attackRadius ~= nil then
				damage = Boss.damage(enemy.warning, player, true)
			elseif dist <= enemy.attackRange then
				damage = enemy.damage
			end
			markProgress(enemy)
			if damage > 0 then
				player.hp -= damage
				emit(events, {
					kind = "hit",
					who = enemy.kind,
					id = enemy.uid,
					damage = damage,
				})
			else
				emit(events, { kind = "whiff", who = enemy.kind, id = enemy.uid })
			end
			enemy.warning = nil
			enemy.cooldown = enemy.interval
		end
		return
	end
	if enemy.kind == "ranged" then
		local prefer = enemy.prefer or (enemy.attackRange * 0.7)
		if dist < prefer * 0.85 then
			local awayX = enemy.x + (enemy.x - player.x)
			local awayZ = enemy.z + (enemy.z - player.z)
			enemy.x, enemy.z =
				moveToward(enemy.x, enemy.z, awayX, awayZ, enemy.speed, dt, enemy.radius, config)
		elseif dist > enemy.attackRange then
			enemy.x, enemy.z = moveToward(
				enemy.x,
				enemy.z,
				player.x,
				player.z,
				enemy.speed,
				dt,
				enemy.radius,
				config
			)
		end
	elseif dist > enemy.attackRange * 0.85 then
		enemy.x, enemy.z =
			moveToward(enemy.x, enemy.z, player.x, player.z, enemy.speed, dt, enemy.radius, config)
	end
	enemy.cooldown -= dt
	dist = length(player.x - enemy.x, player.z - enemy.z)
	if enemy.cooldown <= 0 and dist <= enemy.attackRange then
		enemy.windLeft = enemy.windupTotal
		enemy.warning = Boss.arm({
			windup = enemy.windupTotal,
			attackRadius = enemy.attackRadius or 0,
			damage = enemy.damage,
		}, player)
		markProgress(enemy)
		emit(events, {
			kind = "warning",
			color = "red",
			x = enemy.warning.x,
			z = enemy.warning.z,
			radius = enemy.warning.radius,
			seconds = enemy.warning.seconds,
			id = enemy.uid,
			who = enemy.kind,
		})
		return
	end
	if Stuck.stalled(enemy, dt, config.stuck.seconds, config.stuck.epsilon) then
		recover(run, enemy, config, events)
	end
end

local function overlayStats(base: any, stats: any): any
	return {
		hp = positive(stats.hp, base.hp),
		damage = positive(stats.damage, base.damage),
		range = positive(stats.range, base.range),
		interval = positive(stats.interval, base.interval),
		speed = positive(stats.speed, base.speed),
		radius = positive(stats.radius, base.radius),
	}
end

local function optionsOf(options: any): (any, any)
	if typeof(options) ~= "table" then
		return nil, nil
	end
	return options.launchGate, options.config
end

function Round.enter(options: any?): any
	local launchGate, config = optionsOf(options)
	if not Gate.open(launchGate, config) then
		return nil
	end
	local cfg = cfgOf(config)
	local waveIndex = 1
	if typeof(options) == "table" and finite(options.wave) then
		waveIndex = math.floor(options.wave)
	end
	if Waves.def(waveIndex, cfg) == nil then
		return nil
	end
	local stand = cfg.player.start
	if typeof(options) == "table" and typeof(options.stand) == "table" then
		if finite(options.stand.x) and finite(options.stand.z) then
			stand = options.stand
		end
	end
	local stats = cfg.player
	if typeof(options) == "table" and typeof(options.stats) == "table" then
		stats = overlayStats(cfg.player, options.stats)
	end
	local run = {
		wave = waveIndex,
		total = Waves.count(cfg),
		phase = "fight",
		hold = 0,
		enemies = {},
		ground = {},
		earned = { tokens = 0, fragments = 0, drops = {} },
		paid = {},
		wavesCleared = 0,
		bestWave = 0,
		over = false,
		cleared = false,
		died = false,
		card = nil,
		seconds = 0,
		nextUid = 0,
		nextDrop = 0,
		announced = false,
		origin = cfg.arena.origin,
		player = {
			x = stand.x,
			z = stand.z,
			hp = stats.hp,
			maxHp = stats.hp,
			damage = stats.damage,
			range = stats.range,
			interval = stats.interval,
			speed = stats.speed,
			radius = stats.radius,
			cooldown = 0,
		},
	}
	if not spawnInto(run, waveIndex, cfg) then
		return nil
	end
	return run
end

local function capDt(dt: any): number?
	if not finite(dt) or dt <= 0 then
		return nil
	end
	if dt > 0.5 then
		return 0.5
	end
	return dt
end

function Round.step(run: any, dt: any, input: any, options: any?): (any, { any })
	local launchGate, config = optionsOf(options)
	if typeof(run) ~= "table" or not Gate.open(launchGate, config) then
		return nil, {}
	end
	local cfg = cfgOf(config)
	local events = {}
	local stepDt = capDt(dt)
	if stepDt == nil or run.phase == "results" or run.phase == "left" then
		return run, events
	end
	run.seconds += stepDt
	if run.announced ~= true then
		run.announced = true
		emit(events, { kind = "metric", name = "run_started", wave = run.wave })
		emit(events, { kind = "metric", name = "wave_reached", wave = run.wave })
	end
	movePlayer(run, stepDt, input, cfg)
	if run.phase == "deathHold" then
		collectNear(run, cfg, events)
		run.hold -= stepDt
		if run.hold <= 0 then
			autoCollect(run, cfg, events)
			showResults(run, false, false, events)
		end
		return run, events
	end
	strike(run, input, stepDt, cfg, events)
	if livingCount(run) == 0 then
		finishWave(run, cfg, events)
		return run, events
	end
	for _, enemy in ipairs(run.enemies) do
		if enemy.alive then
			enemyMind(run, enemy, stepDt, cfg, events)
		end
	end
	collectNear(run, cfg, events)
	if run.player.hp <= 0 then
		run.player.hp = 0
		run.ground = {}
		showResults(run, false, true, events)
		return run, events
	end
	if livingCount(run) == 0 then
		finishWave(run, cfg, events)
	end
	return run, events
end

function Round.leave(run: any, options: any?): (any, { any })
	local launchGate, config = optionsOf(options)
	if typeof(run) ~= "table" or not Gate.open(launchGate, config) then
		return nil, {}
	end
	local cfg = cfgOf(config)
	local events = {}
	if run.phase == "results" or run.phase == "left" then
		return run, events
	end
	if run.phase == "deathHold" then
		autoCollect(run, cfg, events)
	else
		run.ground = {}
	end
	showResults(run, true, false, events)
	return run, events
end

function Round.skip(run: any, options: any?): (any, { any })
	local launchGate, config = optionsOf(options)
	if typeof(run) ~= "table" or not Gate.open(launchGate, config) then
		return nil, {}
	end
	if run.phase ~= "fight" and run.phase ~= "deathHold" then
		return run, {}
	end
	local cfg = cfgOf(config)
	local events = {}
	for _, enemy in ipairs(run.enemies) do
		if enemy.alive then
			kill(run, enemy, cfg, events)
		end
	end
	markCleared(run)
	autoCollect(run, cfg, events)
	local nextWave = run.wave + 1
	if Waves.def(nextWave, cfg) == nil or not spawnInto(run, nextWave, cfg) then
		showResults(run, false, false, events)
		return run, events
	end
	emit(events, { kind = "wave", wave = run.wave })
	return run, events
end

function Round.spawnBoss(run: any, options: any?): (any, { any })
	local launchGate, config = optionsOf(options)
	if typeof(run) ~= "table" or not Gate.open(launchGate, config) then
		return nil, {}
	end
	if run.phase == "results" or run.phase == "left" then
		return run, {}
	end
	local cfg = cfgOf(config)
	local events = {}
	run.ground = {}
	local index = Waves.bossIndex(cfg)
	spawnInto(run, index, cfg)
	run.over = false
	emit(events, { kind = "wave", wave = run.wave })
	emit(events, { kind = "metric", name = "wave_reached", wave = run.wave })
	return run, events
end

return Round
