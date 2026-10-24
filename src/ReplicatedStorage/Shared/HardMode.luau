--!strict

--[[
	Shard Gate difficulty. The numbers live in Config/Economy.

	Normal and Hard are the V1 offer. Medium, Nightmare, and Insane stay
	in that table and are refused while LaunchGate.extraDifficulties is off.

	A play session joins on Normal. Each player's tier is server memory
	for that player only. One pick does not change anyone else. This
	module does not read or write a profile.

	Hard is offered only while HardMode.isHardReal() is true. That is
	LaunchGate.hardMode (ships off) and the arena Hard multipliers
	actually applying. The pad stays on Normal until both are true.
]]

local Economy = require("./Config/Economy")
local LaunchGate = require("./LaunchGate")
local WaveArenaConfig = require("./Config/WaveArenaConfig")

local HardMode = {}

HardMode.GATE = "gate"
HardMode.JOIN = "normal"
HardMode.REFUSED = "Hard unlocks at Lv 5."
HardMode.PAD_REFUSED = "This party is on Hard (Lv 5)."
HardMode.CLOSED = "That difficulty is closed."

local PARKED: { [string]: boolean } = {
	medium = true,
	nightmare = true,
	insane = true,
}

-- Per player. There is no server-wide slot. A missing key is Normal.
local sessions: { [string]: string } = {}
local joins: { [string]: string } = {}

-- The old gate id is not a player. Writing it would lock every pad touch.
local function playerKey(id: any): string?
	if id == nil or id == HardMode.GATE then
		return nil
	end
	if type(id) == "number" then
		if id ~= id or id <= 0 or id >= math.huge then
			return nil
		end
		return "p:" .. tostring(math.floor(id))
	end
	if type(id) == "string" and id ~= "" then
		return "p:" .. id
	end
	return nil
end

local function wholeLevel(level: any): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	if level >= math.huge or level <= -math.huge then
		return 1
	end
	local whole = math.floor(level)
	if whole < 1 then
		return 1
	end
	return whole
end

local function clean(requested: any): string?
	if type(requested) ~= "string" then
		return nil
	end
	if requested == "" then
		return nil
	end
	return string.lower(requested)
end

function HardMode.parked(id: string): boolean
	return PARKED[id] == true
end

-- The arena row is the Core Loop (2× HP, 1.5× damage, 2× pay) and it
-- matches the economy Hard row. A 1× row does not count as Hard.
function HardMode.applies(row: any): boolean
	local econ = Economy.DIFFICULTIES.hard
	if type(row) ~= "table" or type(econ) ~= "table" then
		return false
	end
	if row.hpMultiplier ~= 2 or row.damageMultiplier ~= 1.5 then
		return false
	end
	if row.tokenMultiplier ~= 2 or row.fragmentMultiplier ~= 2 then
		return false
	end
	return row.hpMultiplier == econ.hpMultiplier
		and row.damageMultiplier == econ.damageMultiplier
		and row.tokenMultiplier == econ.tokenMultiplier
		and row.fragmentMultiplier == econ.fragmentMultiplier
end

-- One check. Flag on is not enough: the arena multipliers have to apply.
function HardMode.isHardReal(): boolean
	return LaunchGate.on("hardMode") == true and HardMode.applies(WaveArenaConfig.hard)
end

function HardMode.offered(id: string): boolean
	if Economy.DIFFICULTIES[id] == nil then
		return false
	end
	if id == "hard" and HardMode.isHardReal() ~= true then
		return false
	end
	if PARKED[id] == true and LaunchGate.on("extraDifficulties") ~= true then
		return false
	end
	return true
end

-- A brand-new session has no saved tier.
function HardMode.joinTier(): string
	return HardMode.JOIN
end

-- Player join. This player starts on Normal. Every other player stays.
-- A profile is not an argument on purpose.
function HardMode.noteJoin(userId: any): string
	local key = playerKey(userId)
	if key == nil then
		return HardMode.JOIN
	end
	joins[key] = HardMode.JOIN
	sessions[key] = HardMode.JOIN
	return HardMode.JOIN
end

function HardMode.joinedTier(userId: any): string
	local key = playerKey(userId)
	if key == nil then
		return HardMode.JOIN
	end
	return joins[key] or HardMode.JOIN
end

function HardMode.release(userId: any)
	local key = playerKey(userId)
	if key == nil then
		return
	end
	sessions[key] = nil
	joins[key] = nil
end

-- nil, blank, or an unknown name joins on Normal.
-- A parked name is refused. Hard under the level gate is refused.
function HardMode.accept(level: any, requested: any): (string?, string?)
	local lv = wholeLevel(level)
	local id = clean(requested)
	if id == nil or Economy.DIFFICULTIES[id] == nil then
		id = HardMode.JOIN
	end
	if not HardMode.offered(id) then
		return nil, HardMode.CLOSED
	end
	local row = Economy.DIFFICULTIES[id]
	if lv < row.levelGate then
		if id == "hard" then
			return nil, HardMode.REFUSED
		end
		return nil, string.format("Level %d opens %s.", row.levelGate, id)
	end
	return id, nil
end

-- Resets one player's session to Normal. A shared gate id writes nothing.
function HardMode.open(id: any): string
	local key = playerKey(id)
	if key == nil then
		return HardMode.JOIN
	end
	sessions[key] = HardMode.JOIN
	return HardMode.JOIN
end

function HardMode.sessionTier(id: any): string
	local key = playerKey(id)
	if key == nil then
		return HardMode.JOIN
	end
	return sessions[key] or HardMode.JOIN
end

-- Remembers a tier for this player only. A refusal writes nothing.
-- A missing player id writes nothing, so it cannot flip the server.
function HardMode.select(level: any, requested: any, id: any): (string?, string?)
	local accepted, why = HardMode.accept(level, requested)
	if accepted == nil then
		return nil, why
	end
	local key = playerKey(id)
	if key == nil then
		return nil, HardMode.CLOSED
	end
	sessions[key] = accepted
	return accepted, nil
end

-- The pad reads this player's tier. Someone else's Hard does not refuse
-- them, pull them onto Hard, or change their tier.
function HardMode.touch(level: any, id: any): (string?, string?)
	local tier = HardMode.sessionTier(id)
	local accepted, why = HardMode.accept(level, tier)
	if accepted == nil and tier == "hard" then
		if HardMode.isHardReal() ~= true then
			return nil, HardMode.CLOSED
		end
		return nil, HardMode.REFUSED
	end
	return accepted, why
end

function HardMode.scalePay(amount: any, multiplier: any): number
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount >= math.huge then
		return 0
	end
	if type(multiplier) ~= "number" or multiplier ~= multiplier or multiplier < 0 then
		return 0
	end
	if multiplier >= math.huge then
		return 0
	end
	return math.floor(amount * multiplier + 0.5)
end

local function payRow(tier: any)
	local id = clean(tier)
	if id == nil or Economy.DIFFICULTIES[id] == nil then
		id = HardMode.JOIN
	end
	return Economy.DIFFICULTIES[id]
end

function HardMode.tokens(tier: any, amount: number): number
	return HardMode.scalePay(amount, payRow(tier).tokenMultiplier)
end

function HardMode.fragments(tier: any, amount: number): number
	return HardMode.scalePay(amount, payRow(tier).fragmentMultiplier)
end

return HardMode
