--!strict

--[[
	In-memory Gate Ring. The server assigns slots. The client does not.

	A player on the pad takes the lowest free slot. Slot order does not
	reshuffle when someone leaves. The leader is the earliest joiner still
	here. Friends-only blocks new people who are not the leader's friends
	and does not kick anyone already in. Hard needs every member at the
	configured level. Nothing here writes a profile.
]]

local function sharedRoot()
	if game ~= nil and game.GetService ~= nil then
		local folder = script.Parent
		if folder ~= nil and folder.Name == "server" then
			return require(folder:WaitForChild("SharedRequire"))
		end
		if folder ~= nil and folder.Parent ~= nil then
			return require(folder.Parent:WaitForChild("SharedRequire"))
		end
		error("SharedRequire is not beside this module")
	end
	local source = debug.info(1, "s")
	local marker = "src/server/"
	local at = string.find(source, marker, 1, true)
	if at == nil then
		error("SharedRequire could not see src/server in " .. source)
	end
	local rest = string.sub(source, at + #marker)
	local _, slashes = string.gsub(rest, "/", "")
	if slashes == 0 then
		return require("./SharedRequire")
	end
	local prefix = ""
	local parent = string.char(46, 46)
	for _ = 1, slashes do
		prefix ..= parent .. "/"
	end
	return require(prefix .. "SharedRequire")
end

local SharedRequire = sharedRoot()

local PartyGatherConfig = SharedRequire.module("Config/PartyGather")

local Party = {}

export type Member = {
	userId: number,
	name: string,
	slot: number,
	level: number,
	joinedAt: number,
	pendingLeave: number?,
}

export type State = {
	members: { Member },
	friendsOnly: boolean,
	tier: string,
	phase: string,
	countdownEnds: number?,
	startingEnds: number?,
	bumped: { [number]: boolean },
}

export type Actor = {
	userId: number,
	name: string?,
	level: number?,
	levelKnown: boolean?,
	x: number?,
	y: number?,
	z: number?,
	friendKnown: boolean?,
	friendOfLeader: boolean?,
}

export type Event = {
	kind: string,
	userId: number?,
	reason: string?,
	slot: number?,
	n: number?,
	tier: string?,
	mult: number?,
	roster: { Member }?,
}

local function cfgOf(config: any): any
	return if config == nil then PartyGatherConfig else config
end

local function reset(state: State, config: any)
	local party = cfgOf(config).party
	state.members = {}
	state.friendsOnly = party.friendsOnlyDefault == true
	state.tier = "Normal"
	state.phase = "idle"
	state.countdownEnds = nil
	state.startingEnds = nil
	state.bumped = {}
end

function Party.new(config: any?): State
	local state: State = {
		members = {},
		friendsOnly = false,
		tier = "Normal",
		phase = "idle",
		countdownEnds = nil,
		startingEnds = nil,
		bumped = {},
	}
	reset(state, config)
	return state
end

function Party.multiplier(n: number, config: any?): number
	if n < 1 then
		return 1
	end
	local steps = math.floor(cfgOf(config).party.hpPerExtra * 10 + 0.5)
	return (10 + steps * (n - 1)) / 10
end

local function findMember(state: State, userId: number): (Member?, number?)
	for index, member in ipairs(state.members) do
		if member.userId == userId then
			return member, index
		end
	end
	return nil, nil
end

local function slotTaken(state: State, slotId: number): boolean
	for _, member in ipairs(state.members) do
		if member.slot == slotId then
			return true
		end
	end
	return false
end

local function nextSlot(state: State, config: any): number?
	for _, slot in ipairs(config.slots) do
		if not slotTaken(state, slot.id) then
			return slot.id
		end
	end
	return nil
end

local function onPad(actor: Actor, config: any): boolean
	if type(actor.x) ~= "number" or type(actor.z) ~= "number" or type(actor.y) ~= "number" then
		return false
	end
	local pad = config.pad
	local dx = (actor.x :: number) - pad.x
	local dz = (actor.z :: number) - pad.z
	if dx * dx + dz * dz > pad.radius * pad.radius then
		return false
	end
	local dy = (actor.y :: number) - pad.y
	return dy >= -2 and dy <= pad.vertical
end

local function nearestFree(state: State, actor: Actor, config: any): number?
	local best: number? = nil
	local bestDist: number? = nil
	local ax = if type(actor.x) == "number" then actor.x else config.pad.x
	local az = if type(actor.z) == "number" then actor.z else config.pad.z
	for _, slot in ipairs(config.slots) do
		if not slotTaken(state, slot.id) then
			local dx = config.pad.x + slot.x - ax
			local dz = config.pad.z + slot.z - az
			local dist = dx * dx + dz * dz
			if bestDist == nil or dist < bestDist then
				best = slot.id
				bestDist = dist
			end
		end
	end
	return best
end

local function ranksOk(state: State, config: any): boolean
	local need = config.party.hardLevel
	for _, member in ipairs(state.members) do
		if member.level < need then
			return false
		end
	end
	return true
end

local function copyMember(member: Member): Member
	return {
		userId = member.userId,
		name = member.name,
		slot = member.slot,
		level = member.level,
		joinedAt = member.joinedAt,
		pendingLeave = nil,
	}
end

local function enforceTier(state: State, config: any, events: { Event })
	if state.tier == "Hard" and not ranksOk(state, config) then
		state.tier = "Normal"
		table.insert(events, { kind = "tier", tier = "Normal", reason = "level" })
	end
end

local function removeAt(state: State, index: number, config: any, events: { Event })
	local member = state.members[index]
	local wasLeader = index == 1
	state.bumped[member.userId] = nil
	table.remove(state.members, index)
	table.insert(events, { kind = "leave", userId = member.userId, slot = member.slot })
	if #state.members == 0 then
		reset(state, config)
		table.insert(events, { kind = "reset" })
		return
	end
	if wasLeader then
		table.insert(events, { kind = "leader", userId = state.members[1].userId })
	end
	enforceTier(state, config, events)
end

local function refuse(events: { Event }, actor: Actor, reason: string, slot: number?)
	table.insert(events, {
		kind = "refuse",
		userId = actor.userId,
		reason = reason,
		slot = slot,
	})
end

local function beginStart(state: State, now: number, config: any, events: { Event })
	state.phase = "starting"
	state.startingEnds = now + config.party.startSweep
	state.countdownEnds = nil
	table.insert(events, { kind = "lock", n = #state.members, tier = state.tier })
end

function Party.observe(state: State, actor: Actor, now: number, config: any?): { Event }
	local cfg = cfgOf(config)
	local events: { Event } = {}
	if type(actor.userId) ~= "number" then
		return events
	end
	local member, index = findMember(state, actor.userId)
	if not onPad(actor, cfg) then
		if member == nil or index == nil then
			return events
		end
		if member.pendingLeave == nil then
			member.pendingLeave = now + cfg.party.leaveGrace
			return events
		end
		if now >= (member.pendingLeave :: number) then
			removeAt(state, index, cfg, events)
		end
		return events
	end
	if member ~= nil then
		member.pendingLeave = nil
		return events
	end
	if state.phase == "starting" then
		refuse(events, actor, "starting", nil)
		return events
	end
	local slotId = nextSlot(state, cfg)
	if slotId == nil or #state.members >= cfg.party.cap then
		refuse(events, actor, "full", nil)
		return events
	end
	if state.friendsOnly and #state.members > 0 then
		if actor.friendKnown ~= true then
			return events
		end
		if actor.friendOfLeader ~= true then
			refuse(events, actor, "friends", nearestFree(state, actor, cfg))
			return events
		end
	end
	if state.tier == "Hard" then
		if actor.levelKnown ~= true then
			return events
		end
		local level = if type(actor.level) == "number" then actor.level else 1
		if level < cfg.party.hardLevel then
			refuse(events, actor, "level", nearestFree(state, actor, cfg))
			return events
		end
	end
	local fresh = #state.members == 0
	local name = if type(actor.name) == "string" and actor.name ~= "" then actor.name else "Player"
	local level = if type(actor.level) == "number" then actor.level else 1
	table.insert(state.members, {
		userId = actor.userId,
		name = name,
		slot = slotId,
		level = level,
		joinedAt = now,
		pendingLeave = nil,
	})
	if fresh then
		state.phase = "gather"
		state.countdownEnds = now + cfg.party.countdown
	elseif state.countdownEnds ~= nil then
		local left = state.countdownEnds - now
		if left < cfg.party.lateJoinUnder and state.bumped[actor.userId] ~= true then
			state.countdownEnds = now + cfg.party.lateJoinBump
			state.bumped[actor.userId] = true
		end
	end
	table.insert(events, {
		kind = "join",
		userId = actor.userId,
		slot = slotId,
		n = #state.members,
	})
	return events
end

function Party.drop(state: State, userId: number, config: any?): { Event }
	local cfg = cfgOf(config)
	local events: { Event } = {}
	local _, index = findMember(state, userId)
	if index == nil then
		return events
	end
	removeAt(state, index, cfg, events)
	return events
end

local function leaderId(state: State): number?
	local lead = state.members[1]
	if lead == nil then
		return nil
	end
	return lead.userId
end

function Party.setFriendsOnly(state: State, userId: number, on: boolean, _config: any?): { Event }
	local events: { Event } = {}
	if state.phase ~= "gather" then
		table.insert(events, { kind = "refuse", userId = userId, reason = "phase" })
		return events
	end
	if leaderId(state) ~= userId then
		table.insert(events, { kind = "refuse", userId = userId, reason = "leader" })
		return events
	end
	state.friendsOnly = on == true
	table.insert(events, { kind = "friends", userId = userId, n = if state.friendsOnly then 1 else 0 })
	return events
end

function Party.setTier(state: State, userId: number, tier: string, config: any?): { Event }
	local cfg = cfgOf(config)
	local events: { Event } = {}
	if state.phase ~= "gather" then
		table.insert(events, { kind = "refuse", userId = userId, reason = "phase" })
		return events
	end
	if leaderId(state) ~= userId then
		table.insert(events, { kind = "refuse", userId = userId, reason = "leader" })
		return events
	end
	if tier ~= "Normal" and tier ~= "Hard" then
		table.insert(events, { kind = "refuse", userId = userId, reason = "tier" })
		return events
	end
	if tier == "Hard" and not ranksOk(state, cfg) then
		table.insert(events, { kind = "refuse", userId = userId, reason = "level" })
		return events
	end
	state.tier = tier
	table.insert(events, { kind = "tier", userId = userId, tier = tier })
	return events
end

function Party.startNow(state: State, userId: number, now: number, config: any?): { Event }
	local cfg = cfgOf(config)
	local events: { Event } = {}
	if state.phase ~= "gather" or leaderId(state) ~= userId then
		table.insert(events, { kind = "refuse", userId = userId, reason = "leader" })
		return events
	end
	beginStart(state, now, cfg, events)
	return events
end

function Party.tick(state: State, now: number, config: any?): { Event }
	local cfg = cfgOf(config)
	local events: { Event } = {}
	if state.phase == "gather" and state.countdownEnds ~= nil and now >= (state.countdownEnds :: number) and #state.members > 0 then
		beginStart(state, now, cfg, events)
	end
	if state.phase == "starting" and state.startingEnds ~= nil and now >= (state.startingEnds :: number) then
		if #state.members == 0 then
			reset(state, cfg)
			table.insert(events, { kind = "reset" })
			return events
		end
		local roster = {}
		for _, member in ipairs(state.members) do
			table.insert(roster, copyMember(member))
		end
		local n = #roster
		local mult = Party.multiplier(n, cfg)
		local tier = state.tier
		reset(state, cfg)
		table.insert(events, {
			kind = "start",
			n = n,
			tier = tier,
			mult = mult,
			roster = roster,
		})
	end
	return events
end

export type SlotView = {
	id: number,
	x: number,
	z: number,
	userId: number?,
	name: string?,
	role: string,
}

export type View = {
	phase: string,
	n: number,
	cap: number,
	leaderUserId: number?,
	friendsOnly: boolean,
	tier: string,
	secondsLeft: number?,
	mult: number,
	sweep: number,
	slots: { SlotView },
}

function Party.view(state: State, now: number, config: any?): View
	local cfg = cfgOf(config)
	local secondsLeft: number? = nil
	if state.phase == "gather" and state.countdownEnds ~= nil then
		local left = (state.countdownEnds :: number) - now
		if left < 0 then
			left = 0
		end
		secondsLeft = left
	end
	local sweep = 0
	if state.phase == "starting" and state.startingEnds ~= nil then
		local span = cfg.party.startSweep
		if span > 0 then
			sweep = 1 - (((state.startingEnds :: number) - now) / span)
			if sweep < 0 then
				sweep = 0
			elseif sweep > 1 then
				sweep = 1
			end
		end
	end
	local lead = leaderId(state)
	local slots: { SlotView } = {}
	for _, slot in ipairs(cfg.slots) do
		local occupant: Member? = nil
		for _, member in ipairs(state.members) do
			if member.slot == slot.id then
				occupant = member
			end
		end
		local role = "open"
		local userId: number? = nil
		local name: string? = nil
		if occupant ~= nil then
			userId = occupant.userId
			name = occupant.name
			role = if occupant.userId == lead then "leader" else "member"
		elseif state.friendsOnly then
			role = "friends"
		end
		table.insert(slots, {
			id = slot.id,
			x = cfg.pad.x + slot.x,
			z = cfg.pad.z + slot.z,
			userId = userId,
			name = name,
			role = role,
		})
	end
	return {
		phase = state.phase,
		n = #state.members,
		cap = cfg.party.cap,
		leaderUserId = lead,
		friendsOnly = state.friendsOnly,
		tier = state.tier,
		secondsLeft = secondsLeft,
		mult = Party.multiplier(#state.members, cfg),
		sweep = sweep,
		slots = slots,
	}
end

return Party
