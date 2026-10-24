--!strict

--[[
	Raid post-run recap.

	The server passes plain tables. This module does not read players,
	filter text, grant loot, or touch saved profiles and remotes.
	It has no RNG. Thresholds and the tip table live in CONFIG.
	Nothing here costs Robux.

	Each player gets a private panel: damage, healing, deaths, and
	the mechanics they handled. Up to two tips come from that player's
	failures. The public view is party kudos and mechanic MVP awards.
	It has no damage ranking and no one else's numbers.

	Kudos are one per player per run, to someone else in that run.
	One MVP per mechanic type goes to whoever handled the most.
	A tie goes to the lower user id. No award when nobody handled any.

	An AFK removal still gets a private panel. They are left out of
	kudos and MVP. Pass removal "afk", the string "remove", or the
	RaidConduct.afk result whose state is "remove".
]]

local RaidRecap = {}

local TIPS = table.freeze({
	twins = table.freeze({
		soak = "Soak the merged twins with a partner.",
		spread = "Spread out for Briar's Thorn Volley.",
		stack = "Swap tanks before Splinter stacks reach 4.",
	}),
	sapwell = table.freeze({
		pool = "Move Sap Pools to the edge of the arena.",
		add = "Kill Saplings before they grow into Treants.",
		interrupt = "Interrupt Amber Prison to free your ally.",
	}),
	galecrown = table.freeze({
		gust = "Try using Blink on Galecrown's Gust.",
		stack = "Stack with the party for Moonlit Dive.",
		feather = "Stand behind a branch during Feather Storm.",
	}),
	awakened = table.freeze({
		soak = "Soak all four Heartroots at the same time.",
		interrupt = "Interrupt your platform's Heartwood Roar.",
		shield = "Break the Lumen shard before Thorn Wall closes.",
	}),
})

RaidRecap.CONFIG = table.freeze({
	tipLimit = 2,
	tips = TIPS,
})

RaidRecap.MECHANICS = table.freeze({ "soak", "interrupt", "stack", "add" })

RaidRecap.REMOVALS = table.freeze({
	afk = true,
	kick = true,
})

-- RaidConduct.afk uses this state when the 90s removal fires.
RaidRecap.AFK_STATE = "remove"

RaidRecap.PRESENT_STATES = table.freeze({
	ok = true,
	warning = true,
	paused = true,
})

RaidRecap.ERRORS = table.freeze({
	run = "That raid recap is unusable.",
	roster = "That raid roster is unusable.",
	member = "That player recap is unusable.",
	userId = "That player id is unusable.",
	duplicate = "That player is listed twice.",
	damage = "That damage total is unusable.",
	healing = "That healing total is unusable.",
	deaths = "That death count is unusable.",
	mechanics = "That mechanic tally is unusable.",
	mechanic = "That mechanic type is unusable.",
	failures = "That failure list is unusable.",
	failure = "That mechanic failure is unusable.",
	removal = "That removal is not a known cause.",
	kudos = "That kudos list is unusable.",
	kudosEntry = "That kudos entry is unusable.",
	selfKudos = "You cannot give kudos to yourself.",
	absentSelf = "You are not in this run.",
	absent = "That player is not in this run.",
	already = "You already gave kudos this run.",
	afkGive = "An AFK-removed player cannot give kudos.",
	afkReceive = "An AFK-removed player cannot receive kudos.",
})

local VERBS = table.freeze({
	soak = "soaked",
	interrupt = "interrupted",
	stack = "stacked",
})

local KNOWN_MECHANICS: { [string]: boolean } = {}
for _, name in ipairs(RaidRecap.MECHANICS) do
	KNOWN_MECHANICS[name] = true
end

export type Mechanics = {
	soak: number,
	interrupt: number,
	stack: number,
	add: number,
}

export type Kudos = {
	fromUserId: number,
	toUserId: number,
}

export type Award = {
	mechanic: string,
	userId: number,
}

export type Panel = {
	ok: boolean,
	userId: number,
	afk: boolean,
	lines: { string },
	tips: { string },
	damage: number,
	healing: number,
	deaths: number,
	mechanics: Mechanics,
	error: string?,
}

export type Public = {
	kudos: { Kudos },
	awards: { Award },
}

export type PublicResult = {
	ok: boolean,
	public: Public,
	error: string?,
}

export type Recap = {
	ok: boolean,
	panels: { [number]: Panel },
	public: Public,
	error: string?,
}

export type Given = {
	ok: boolean,
	kudos: { Kudos },
	error: string?,
}

type FailureNorm = {
	bossId: string,
	mechanic: string,
}

type Normalized = {
	userId: number,
	damage: number,
	healing: number,
	deaths: number,
	mechanics: Mechanics,
	failures: { FailureNorm },
	afk: boolean,
}

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function token(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = trim(value)
	if trimmed == "" then
		return nil
	end
	return string.lower(trimmed)
end

local function whole(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function userIdOf(value: any): number?
	local id = whole(value)
	if id == nil or id <= 0 then
		return nil
	end
	return id
end

local function dense(value: { any }): boolean
	local count = 0
	local maxIndex = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
			return false
		end
		count += 1
		if key > maxIndex then
			maxIndex = key
		end
	end
	return count == maxIndex
end

local function blankMechanics(): Mechanics
	return {
		soak = 0,
		interrupt = 0,
		stack = 0,
		add = 0,
	}
end

local function emptyPublic(): Public
	return {
		kudos = {},
		awards = {},
	}
end

local function tipLimit(): number
	local value = whole(RaidRecap.CONFIG.tipLimit)
	if value == nil then
		return 2
	end
	return value
end

local function readWhole(value: any, message: string): (number?, string?)
	if value == nil then
		return 0, nil
	end
	local number = whole(value)
	if number == nil then
		return nil, message
	end
	return number, nil
end

local function readRemoval(value: any): (string?, string?)
	if value == nil then
		return "", nil
	end
	if type(value) == "table" then
		if value.ok == false then
			return nil, RaidRecap.ERRORS.removal
		end
		local state = token(value.state)
		if state == RaidRecap.AFK_STATE then
			return "afk", nil
		end
		if state ~= nil and RaidRecap.PRESENT_STATES[state] == true then
			return "", nil
		end
		return nil, RaidRecap.ERRORS.removal
	end
	local name = token(value)
	if name == RaidRecap.AFK_STATE then
		return "afk", nil
	end
	if name ~= nil and RaidRecap.REMOVALS[name] == true then
		return name, nil
	end
	return nil, RaidRecap.ERRORS.removal
end

local function readMechanics(value: any): (Mechanics?, string?)
	local mechanics = blankMechanics()
	if value == nil then
		return mechanics, nil
	end
	if type(value) ~= "table" then
		return nil, RaidRecap.ERRORS.mechanics
	end
	local seen: { [string]: boolean } = {}
	for key, count in pairs(value) do
		local name = token(key)
		if name == nil or KNOWN_MECHANICS[name] ~= true then
			if name == nil then
				return nil, RaidRecap.ERRORS.mechanics
			end
			return nil, RaidRecap.ERRORS.mechanic
		end
		if seen[name] == true then
			return nil, RaidRecap.ERRORS.mechanic
		end
		local number = whole(count)
		if number == nil then
			return nil, RaidRecap.ERRORS.mechanics
		end
		seen[name] = true
		if name == "soak" then
			mechanics.soak = number
		elseif name == "interrupt" then
			mechanics.interrupt = number
		elseif name == "stack" then
			mechanics.stack = number
		else
			mechanics.add = number
		end
	end
	return mechanics, nil
end

local function readFailures(value: any): ({ FailureNorm }?, string?)
	if value == nil then
		return {}, nil
	end
	if type(value) ~= "table" or not dense(value) then
		return nil, RaidRecap.ERRORS.failures
	end
	local list: { FailureNorm } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in ipairs(value) do
		if type(entry) ~= "table" then
			return nil, RaidRecap.ERRORS.failure
		end
		local bossId = token(entry.bossId)
		local mechanic = token(entry.mechanic)
		if bossId == nil or mechanic == nil then
			return nil, RaidRecap.ERRORS.failure
		end
		local happened = true
		if entry.count ~= nil then
			local count = whole(entry.count)
			if count == nil then
				return nil, RaidRecap.ERRORS.failure
			end
			happened = count > 0
		end
		local key = bossId .. "\0" .. mechanic
		if happened and seen[key] ~= true then
			seen[key] = true
			table.insert(list, {
				bossId = bossId,
				mechanic = mechanic,
			})
		end
	end
	return list, nil
end

local function readMember(entry: any): (Normalized?, string?)
	if type(entry) ~= "table" then
		return nil, RaidRecap.ERRORS.member
	end
	local id = userIdOf(entry.userId)
	if id == nil then
		return nil, RaidRecap.ERRORS.userId
	end
	local damage, damageErr = readWhole(entry.damage, RaidRecap.ERRORS.damage)
	if damage == nil then
		return nil, damageErr or RaidRecap.ERRORS.damage
	end
	local healing, healingErr = readWhole(entry.healing, RaidRecap.ERRORS.healing)
	if healing == nil then
		return nil, healingErr or RaidRecap.ERRORS.healing
	end
	local deaths, deathsErr = readWhole(entry.deaths, RaidRecap.ERRORS.deaths)
	if deaths == nil then
		return nil, deathsErr or RaidRecap.ERRORS.deaths
	end
	local mechanics, mechanicsErr = readMechanics(entry.mechanics)
	if mechanics == nil then
		return nil, mechanicsErr or RaidRecap.ERRORS.mechanics
	end
	local failures, failuresErr = readFailures(entry.failures)
	if failures == nil then
		return nil, failuresErr or RaidRecap.ERRORS.failure
	end
	local removal, removalErr = readRemoval(entry.removal)
	if removal == nil then
		return nil, removalErr or RaidRecap.ERRORS.removal
	end
	return {
		userId = id,
		damage = damage,
		healing = healing,
		deaths = deaths,
		mechanics = mechanics,
		failures = failures,
		afk = removal == "afk",
	},
		nil
end

local function readRoster(members: any): ({ Normalized }?, string?)
	if type(members) ~= "table" or not dense(members) then
		return nil, RaidRecap.ERRORS.roster
	end
	local list: { Normalized } = {}
	local seen: { [number]: boolean } = {}
	for _, entry in ipairs(members) do
		local member, message = readMember(entry)
		if member == nil then
			return nil, message or RaidRecap.ERRORS.member
		end
		if seen[member.userId] == true then
			return nil, RaidRecap.ERRORS.duplicate
		end
		seen[member.userId] = true
		table.insert(list, member)
	end
	return list, nil
end

local function indexRoster(roster: { Normalized }): { [number]: Normalized }
	local byId: { [number]: Normalized } = {}
	for _, member in ipairs(roster) do
		byId[member.userId] = member
	end
	return byId
end

local function timesLine(count: number, verb: string): string
	if count == 1 then
		return string.format("You %s 1 time", verb)
	end
	return string.format("You %s %d times", verb, count)
end

local function deathLine(count: number): string
	if count == 1 then
		return "You died 1 time"
	end
	return string.format("You died %d times", count)
end

local function handledLine(mechanic: string, count: number): string?
	if count <= 0 then
		return nil
	end
	local verb = VERBS[mechanic]
	if verb ~= nil then
		return timesLine(count, verb)
	end
	if mechanic == "add" then
		if count == 1 then
			return "You killed 1 add"
		end
		return string.format("You killed %d adds", count)
	end
	return nil
end

local function tipsFor(failures: { FailureNorm }): { string }
	local rows: { { bossId: string, mechanic: string, tip: string } } = {}
	local bosses = RaidRecap.CONFIG.tips
	for _, failure in ipairs(failures) do
		local tip = nil
		if type(bosses) == "table" then
			local row = bosses[failure.bossId]
			if type(row) == "table" then
				tip = row[failure.mechanic]
			end
		end
		if type(tip) == "string" and tip ~= "" then
			table.insert(rows, {
				bossId = failure.bossId,
				mechanic = failure.mechanic,
				tip = tip,
			})
		end
	end
	table.sort(rows, function(left, right)
		if left.bossId ~= right.bossId then
			return left.bossId < right.bossId
		end
		return left.mechanic < right.mechanic
	end)
	local tips: { string } = {}
	local limit = tipLimit()
	local count = #rows
	if count > limit then
		count = limit
	end
	for index = 1, count do
		tips[index] = rows[index].tip
	end
	return tips
end

local function panelFrom(member: Normalized): Panel
	local lines = {
		string.format("You dealt %d damage", member.damage),
		string.format("You healed %d", member.healing),
		deathLine(member.deaths),
	}
	for _, mechanic in ipairs(RaidRecap.MECHANICS) do
		local line = handledLine(mechanic, member.mechanics[mechanic])
		if line ~= nil then
			table.insert(lines, line)
		end
	end
	return {
		ok = true,
		userId = member.userId,
		afk = member.afk,
		lines = lines,
		tips = tipsFor(member.failures),
		damage = member.damage,
		healing = member.healing,
		deaths = member.deaths,
		mechanics = member.mechanics,
	}
end

local function failPanel(id: number, message: string): Panel
	return {
		ok = false,
		userId = id,
		afk = false,
		lines = {},
		tips = {},
		damage = 0,
		healing = 0,
		deaths = 0,
		mechanics = blankMechanics(),
		error = message,
	}
end

local function awardsOf(roster: { Normalized }): { Award }
	local awards: { Award } = {}
	for _, mechanic in ipairs(RaidRecap.MECHANICS) do
		local bestId: number? = nil
		local bestCount = 0
		for _, member in ipairs(roster) do
			if member.afk ~= true then
				local count = member.mechanics[mechanic]
				local takeLead = count > bestCount
				local tieWin = count > 0
					and count == bestCount
					and bestId ~= nil
					and member.userId < bestId
				if takeLead or tieWin then
					bestId = member.userId
					bestCount = count
				end
			end
		end
		if bestId ~= nil and bestCount > 0 then
			table.insert(awards, {
				mechanic = mechanic,
				userId = bestId,
			})
		end
	end
	return awards
end

local function kudosRule(byId: { [number]: Normalized }, fromId: number, toId: number): string?
	local fromMember = byId[fromId]
	local toMember = byId[toId]
	if fromMember == nil then
		return RaidRecap.ERRORS.absentSelf
	end
	if toMember == nil then
		return RaidRecap.ERRORS.absent
	end
	if fromId == toId then
		return RaidRecap.ERRORS.selfKudos
	end
	if fromMember.afk == true then
		return RaidRecap.ERRORS.afkGive
	end
	if toMember.afk == true then
		return RaidRecap.ERRORS.afkReceive
	end
	return nil
end

local function copyKudos(list: { Kudos }): { Kudos }
	local copy: { Kudos } = {}
	for index, entry in ipairs(list) do
		copy[index] = {
			fromUserId = entry.fromUserId,
			toUserId = entry.toUserId,
		}
	end
	return copy
end

-- strict keeps a bad kudos row as an error. Display drops rule breaks
-- and keeps the first legal kudos from each player.
local function collectKudos(
	roster: { Normalized },
	kudos: any,
	strict: boolean
): ({ Kudos }?, string?)
	if kudos == nil then
		return {}, nil
	end
	if type(kudos) ~= "table" or not dense(kudos) then
		return nil, RaidRecap.ERRORS.kudos
	end
	local byId = indexRoster(roster)
	local list: { Kudos } = {}
	local seen: { [number]: boolean } = {}
	for _, entry in ipairs(kudos) do
		if type(entry) ~= "table" then
			return nil, RaidRecap.ERRORS.kudosEntry
		end
		local fromId = userIdOf(entry.fromUserId)
		local toId = userIdOf(entry.toUserId)
		if fromId == nil or toId == nil then
			return nil, RaidRecap.ERRORS.kudosEntry
		end
		local rule = kudosRule(byId, fromId, toId)
		local duplicate = seen[fromId] == true
		if rule ~= nil or duplicate then
			if strict then
				if rule ~= nil then
					return nil, rule
				end
				return nil, RaidRecap.ERRORS.already
			end
		else
			seen[fromId] = true
			table.insert(list, {
				fromUserId = fromId,
				toUserId = toId,
			})
		end
	end
	return list, nil
end

local function failGive(message: string, kudos: { Kudos }?): Given
	return {
		ok = false,
		kudos = kudos or {},
		error = message,
	}
end

local function failPublic(message: string): PublicResult
	return {
		ok = false,
		public = emptyPublic(),
		error = message,
	}
end

local function failRecap(message: string): Recap
	return {
		ok = false,
		panels = {},
		public = emptyPublic(),
		error = message,
	}
end

function RaidRecap.panel(member: any): Panel
	local normalized, message = readMember(member)
	if normalized == nil then
		local id = 0
		if type(member) == "table" then
			local parsed = userIdOf(member.userId)
			if parsed ~= nil then
				id = parsed
			end
		end
		return failPanel(id, message or RaidRecap.ERRORS.member)
	end
	return panelFrom(normalized)
end

function RaidRecap.give(members: any, kudos: any, fromUserId: any, toUserId: any): Given
	local roster, rosterErr = readRoster(members)
	if roster == nil then
		return failGive(rosterErr or RaidRecap.ERRORS.roster, nil)
	end
	local existing, kudosErr = collectKudos(roster, kudos, true)
	if existing == nil then
		return failGive(kudosErr or RaidRecap.ERRORS.kudos, nil)
	end
	local fromId = userIdOf(fromUserId)
	local toId = userIdOf(toUserId)
	if fromId == nil or toId == nil then
		return failGive(RaidRecap.ERRORS.userId, existing)
	end
	local rule = kudosRule(indexRoster(roster), fromId, toId)
	if rule ~= nil then
		return failGive(rule, existing)
	end
	for _, entry in ipairs(existing) do
		if entry.fromUserId == fromId then
			return failGive(RaidRecap.ERRORS.already, existing)
		end
	end
	local nextList = copyKudos(existing)
	table.insert(nextList, {
		fromUserId = fromId,
		toUserId = toId,
	})
	return {
		ok = true,
		kudos = nextList,
	}
end

function RaidRecap.publicView(members: any, kudos: any): PublicResult
	local roster, rosterErr = readRoster(members)
	if roster == nil then
		return failPublic(rosterErr or RaidRecap.ERRORS.roster)
	end
	local list, kudosErr = collectKudos(roster, kudos, false)
	if list == nil then
		return failPublic(kudosErr or RaidRecap.ERRORS.kudos)
	end
	return {
		ok = true,
		public = {
			kudos = list,
			awards = awardsOf(roster),
		},
	}
end

function RaidRecap.recap(run: any): Recap
	if type(run) ~= "table" then
		return failRecap(RaidRecap.ERRORS.run)
	end
	local roster, rosterErr = readRoster(run.members)
	if roster == nil then
		return failRecap(rosterErr or RaidRecap.ERRORS.roster)
	end
	local panels: { [number]: Panel } = {}
	for _, member in ipairs(roster) do
		panels[member.userId] = panelFrom(member)
	end
	local list, kudosErr = collectKudos(roster, run.kudos, false)
	if list == nil then
		return {
			ok = false,
			panels = panels,
			public = emptyPublic(),
			error = kudosErr or RaidRecap.ERRORS.kudos,
		}
	end
	return {
		ok = true,
		panels = panels,
		public = {
			kudos = list,
			awards = awardsOf(roster),
		},
	}
end

return RaidRecap
