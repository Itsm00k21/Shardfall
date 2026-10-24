--!strict

--[[
	T6 big-roll beam, server side.

	LaunchGate.bigRollBeam ships false. While it is off, offer and pump
	do nothing and a roll already queued is dropped. The server decides
	the tier from Config.BigRoll. A plain client table is not a roll.

	One RollAnnounce payload carries the line and, when a slot is free,
	the beam. Per server: one beam live, three queued, four chat lines
	in thirty seconds, one event per player per eight seconds. Epic and
	below still fold into "+N more big rolls" once that chat cap is full.
	Legendary and above never fold: each one keeps its own named line.
	Nothing is saved. Nothing costs Robux. Mythic cross-server announce
	is not this path.
]]

local LaunchGate = require("./LaunchGate")
local Rarities = require("./Rarities")
local RarityConfig = require("./RarityConfig")
local BigRoll = require("./Config/BigRoll")

local BigRollBeam = {}

local MARK = {}

type Slot = {
	userId: number,
	displayName: string,
	itemName: string,
	rarity: string,
	count: number,
	epicCount: number,
	due: number,
	notedAt: number,
	anchor: string,
	order: number,
}

type Beam = {
	start: number,
	ends: number,
}

type Memory = {
	queue: { Slot },
	beams: { Beam },
	busy: { [number]: number },
	stash: { [number]: number },
	epicHits: { [number]: { number } },
	muteUntil: { [number]: number },
	windowStart: number,
	sentInWindow: number,
	overflow: number,
	order: number,
	droppedBeam: number,
}

local function blank(): Memory
	return {
		queue = {},
		beams = {},
		busy = {},
		stash = {},
		epicHits = {},
		muteUntil = {},
		windowStart = 0,
		sentInWindow = 0,
		overflow = 0,
		order = 0,
		droppedBeam = 0,
	}
end

local state: Memory = blank()

local function clock(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function clean(text: string, limit: number): string
	local stripped = string.gsub(text, "[%c<>]", "")
	if #stripped > limit then
		return string.sub(stripped, 1, limit)
	end
	return stripped
end

local function legendary(rarity: string): boolean
	return Rarities.rank(rarity) >= Rarities.rank("Legendary")
end

function BigRollBeam.qualifies(rarity: any, config: any?): boolean
	local row = if type(config) == "table" then config else BigRoll
	if type(rarity) ~= "string" or type(row.MIN_TIER) ~= "string" then
		return false
	end
	if Rarities.INDEX[rarity] == nil or Rarities.INDEX[row.MIN_TIER] == nil then
		return false
	end
	return Rarities.rank(rarity) >= Rarities.rank(row.MIN_TIER)
end

function BigRollBeam.delay(rarity: string, quick: boolean, config: any?): number
	local row = if type(config) == "table" then config else BigRoll
	local floor = if type(row.MIN_AFTER) == "number" then row.MIN_AFTER else 0.6
	local reveal = RarityConfig.reveal(rarity, quick == true)
	local seconds = reveal.skipAfter
	if quick ~= true then
		local pad = if type(row.REVEAL_PAD) == "number" then row.REVEAL_PAD else 0
		seconds = reveal.reelSeconds + reveal.landSeconds + reveal.cutscene + pad
	end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < floor then
		return floor
	end
	return seconds
end

local function anchorFor(x: any, z: any, config: any): string
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return "crackstone"
	end
	local spawn = config.SPAWN
	if type(spawn) ~= "table" then
		return "crackstone"
	end
	local dx = x - spawn.x
	local dz = z - spawn.z
	local radius = config.HUB_RADIUS
	if type(radius) ~= "number" or math.sqrt(dx * dx + dz * dz) > radius then
		return "crackstone"
	end
	return "roller"
end

local function look(rarity: string, config: any, field: string): number
	local book = config[field]
	local value = if type(book) == "table" then book[rarity] else nil
	if type(value) == "number" then
		return value
	end
	if type(book) == "table" and legendary(rarity) and type(book.Legendary) == "number" then
		return book.Legendary
	end
	if type(book) == "table" and type(book.Epic) == "number" then
		return book.Epic
	end
	return 0
end

local function lineText(name: string, rarity: string, item: string, count: number, epicCount: number): string
	if legendary(rarity) and epicCount >= 1 then
		local noun = if epicCount == 1 then "Epic" else "Epics"
		return string.format("★ **%s** pulled a **LEGENDARY** and %d %s!", name, epicCount, noun)
	end
	if rarity == "Epic" and count > 1 then
		return string.format("✦ **%s** pulled %d Epics!", name, count)
	end
	if legendary(rarity) and count > 1 then
		return string.format("★ **%s** pulled %d **LEGENDARY** %s!", name, count, item)
	end
	local mark = if legendary(rarity) then "★" else "✦"
	local word = if legendary(rarity) then "LEGENDARY" else rarity
	local article = if rarity == "Epic" then "an" else "a"
	return string.format("%s **%s** pulled %s **%s** %s!", mark, name, article, word, item)
end

function BigRollBeam.reset()
	state = blank()
end

function BigRollBeam.forget(userId: number)
	if type(userId) ~= "number" then
		return
	end
	state.busy[userId] = nil
	state.stash[userId] = nil
	state.epicHits[userId] = nil
	state.muteUntil[userId] = nil
end

-- What a client FireServer can hand us. It never becomes a roll.
function BigRollBeam.onClient(_player: any, _rarity: any, _item: any): nil
	return nil
end

-- Only RollService builds this, from the draw it just saved.
function BigRollBeam.serverRoll(fields: any): any
	if type(fields) ~= "table" or fields.client ~= nil then
		return nil
	end
	local userId = fields.userId
	if type(userId) ~= "number" or userId ~= userId or userId < 1 or userId ~= math.floor(userId) then
		return nil
	end
	if type(fields.displayName) ~= "string" or type(fields.itemName) ~= "string" then
		return nil
	end
	local displayName = clean(fields.displayName, 64)
	local itemName = clean(fields.itemName, 80)
	if displayName == "" or itemName == "" then
		return nil
	end
	if type(fields.rarity) ~= "string" or Rarities.INDEX[fields.rarity] == nil then
		return nil
	end
	local count = fields.count
	if count == nil then
		count = 1
	end
	if type(count) ~= "number" or count ~= count or count < 1 or count > 10 or count ~= math.floor(count) then
		return nil
	end
	local epicCount = fields.epicCount
	if epicCount == nil then
		epicCount = if fields.rarity == "Epic" then count else 0
	end
	if
		type(epicCount) ~= "number"
		or epicCount ~= epicCount
		or epicCount < 0
		or epicCount > count
		or epicCount ~= math.floor(epicCount)
	then
		return nil
	end
	local fact = {
		userId = userId,
		displayName = displayName,
		itemName = itemName,
		rarity = fields.rarity,
		count = count,
		epicCount = epicCount,
		quick = fields.quick == true,
		x = fields.x,
		z = fields.z,
	}
	fact[MARK] = true
	return fact
end

local function enqueue(fact: any, due: number, notedAt: number, anchor: string)
	state.order += 1
	local slot: Slot = {
		userId = fact.userId,
		displayName = fact.displayName,
		itemName = fact.itemName,
		rarity = fact.rarity,
		count = fact.count,
		epicCount = fact.epicCount,
		due = due,
		notedAt = notedAt,
		anchor = anchor,
		order = state.order,
	}
	table.insert(state.queue, slot)
end

function BigRollBeam.offer(fact: any, now: number, config: any?)
	if not LaunchGate.on("bigRollBeam") then
		return
	end
	local at = clock(now)
	if at == nil or type(fact) ~= "table" or fact[MARK] ~= true then
		return
	end
	local cfg = if type(config) == "table" then config else BigRoll
	local ok = BigRoll.validate(cfg)
	if not ok or not BigRollBeam.qualifies(fact.rarity, cfg) then
		return
	end
	local wait = BigRollBeam.delay(fact.rarity, fact.quick == true, cfg)
	local userId = fact.userId
	local busy = state.busy[userId] or 0
	if at < busy then
		if not legendary(fact.rarity) then
			state.stash[userId] = (state.stash[userId] or 0) + fact.count
			return
		end
		local due = math.max(busy, at + wait)
		state.busy[userId] = due + cfg.PLAYER_GAP
		enqueue(fact, due, at, anchorFor(fact.x, fact.z, cfg))
		return
	end
	state.busy[userId] = at + cfg.PLAYER_GAP
	enqueue(fact, at + wait, at, anchorFor(fact.x, fact.z, cfg))
end

local function muted(userId: number, now: number): boolean
	local untilAt = state.muteUntil[userId]
	return type(untilAt) == "number" and now < untilAt
end

local function noteEpic(userId: number, now: number, config: any)
	local kept = {}
	local prior = state.epicHits[userId]
	if prior ~= nil then
		for _, hit in ipairs(prior) do
			if now - hit < config.EPIC_WINDOW then
				table.insert(kept, hit)
			end
		end
	end
	table.insert(kept, now)
	state.epicHits[userId] = kept
	if #kept >= config.EPIC_BURST then
		state.muteUntil[userId] = now + config.EPIC_MUTE
	end
end

local function takeBeam(now: number, hold: number, fade: number, gap: number, queueCap: number): number?
	local live = {}
	local lastEnds = now
	local queued = 0
	for _, beam in ipairs(state.beams) do
		if beam.ends > now then
			table.insert(live, beam)
			if beam.start > now then
				queued += 1
			end
			if beam.ends > lastEnds then
				lastEnds = beam.ends
			end
		end
	end
	state.beams = live
	if queued >= queueCap then
		state.droppedBeam += 1
		return nil
	end
	local start = now
	if #live > 0 then
		start = lastEnds + gap
	end
	table.insert(state.beams, {
		start = start,
		ends = start + hold + fade,
	})
	return start
end

local function expireWindow(now: number, sink: (any) -> (), config: any)
	if state.windowStart == 0 or now < state.windowStart + config.CHAT_WINDOW then
		return
	end
	if state.overflow > 0 then
		sink({
			kind = "bigRoll",
			overflow = true,
			count = state.overflow,
			text = string.format("+%d more big rolls.", state.overflow),
			beam = false,
			at = now,
			crossServer = false,
		})
	end
	state.overflow = 0
	state.windowStart = 0
	state.sentInWindow = 0
end

local function emit(slot: Slot, now: number, sink: (any) -> (), config: any)
	local extra = state.stash[slot.userId] or 0
	state.stash[slot.userId] = nil
	local count = slot.count + extra
	local epicCount = slot.epicCount + extra
	expireWindow(now, sink, config)
	if state.windowStart == 0 then
		state.windowStart = now
		state.sentInWindow = 0
	end
	local isLegendary = legendary(slot.rarity)
	-- The chat cap still folds Epic and below into the unnamed summary.
	-- A Legendary (or anything above it) always keeps a named line, and
	-- does not take a slot once the cap is already full.
	if state.sentInWindow >= config.CHAT_MAX and not isLegendary then
		state.overflow += 1
		state.droppedBeam += 1
		return
	end
	if state.sentInWindow < config.CHAT_MAX then
		state.sentInWindow += 1
	end
	local beam = true
	local beamAt = nil
	if not isLegendary and muted(slot.userId, now) then
		beam = false
	end
	if beam then
		local hold = look(slot.rarity, config, "BEAM_HOLD")
		local start = takeBeam(now, hold, config.FADE, config.GAP, config.QUEUE)
		if start == nil then
			beam = false
		else
			beamAt = start
		end
	end
	if not isLegendary then
		noteEpic(slot.userId, now, config)
	end
	local payload: { [string]: any } = {
		kind = "bigRoll",
		userId = slot.userId,
		displayName = slot.displayName,
		itemName = slot.itemName,
		rarity = slot.rarity,
		count = count,
		epicCount = epicCount,
		at = slot.notedAt,
		text = lineText(slot.displayName, slot.rarity, slot.itemName, count, epicCount),
		beam = beam,
		crossServer = false,
	}
	if beam then
		payload.beamAt = beamAt
		payload.anchor = slot.anchor
		payload.height = look(slot.rarity, config, "BEAM_HEIGHT")
		payload.hold = look(slot.rarity, config, "BEAM_HOLD")
	end
	sink(payload)
end

function BigRollBeam.pump(now: number, sink: (any) -> (), config: any?)
	if not LaunchGate.on("bigRollBeam") then
		if
			state.order ~= 0
			or #state.queue > 0
			or state.overflow > 0
			or next(state.busy) ~= nil
			or next(state.stash) ~= nil
		then
			state = blank()
		end
		return
	end
	local at = clock(now)
	if at == nil or type(sink) ~= "function" then
		return
	end
	local cfg = if type(config) == "table" then config else BigRoll
	if not BigRoll.validate(cfg) then
		return
	end
	expireWindow(at, sink, cfg)
	table.sort(state.queue, function(a: Slot, b: Slot)
		if a.due == b.due then
			return a.order < b.order
		end
		return a.due < b.due
	end)
	local due = {}
	local kept = {}
	for _, slot in ipairs(state.queue) do
		if slot.due <= at then
			table.insert(due, slot)
		else
			table.insert(kept, slot)
		end
	end
	state.queue = kept
	for _, slot in ipairs(due) do
		emit(slot, at, sink, cfg)
	end
end

return BigRollBeam
