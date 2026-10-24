--!strict

--[[
	Shard Gate difficulty. The numbers live in Config/Economy.

	Normal and Hard are the V1 offer. Medium, Nightmare, and Insane stay
	in that table and are refused while LaunchGate.extraDifficulties is off.

	A play session joins on Normal. The pad tier is server memory for this
	session only. This module does not read or write a profile.
]]

local Economy = require("./Config/Economy")
local LaunchGate = require("./LaunchGate")

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

local sessions: { [string]: string } = {}
local joins: { [string]: string } = {}

local function sessionKey(id: any): string
	if type(id) == "string" and id ~= "" then
		return id
	end
	return HardMode.GATE
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

function HardMode.offered(id: string): boolean
	if Economy.DIFFICULTIES[id] == nil then
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

-- Player join. Always Normal. A profile is not an argument on purpose.
function HardMode.noteJoin(userId: any): string
	local key = tostring(userId)
	joins[key] = HardMode.JOIN
	return joins[key]
end

function HardMode.joinedTier(userId: any): string
	return joins[tostring(userId)] or HardMode.JOIN
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

-- Opens (or resets) a pad session on Normal. Does not read a profile.
function HardMode.open(id: any): string
	local key = sessionKey(id)
	sessions[key] = HardMode.JOIN
	return sessions[key]
end

function HardMode.sessionTier(id: any): string
	return sessions[sessionKey(id)] or HardMode.JOIN
end

-- Remembers a tier for this server session only. A refusal leaves the
-- previous tier alone.
function HardMode.select(level: any, requested: any, id: any): (string?, string?)
	local accepted, why = HardMode.accept(level, requested)
	if accepted == nil then
		return nil, why
	end
	sessions[sessionKey(id)] = accepted
	return accepted, nil
end

-- Stepping on the pad uses the session tier. Under Lv 5 on Hard is refused
-- and the session tier stays so the leader's pick is not dropped.
function HardMode.touch(level: any, id: any): (string?, string?)
	local tier = HardMode.sessionTier(id)
	local accepted, why = HardMode.accept(level, tier)
	if accepted == nil and tier == "hard" then
		return nil, HardMode.PAD_REFUSED
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
