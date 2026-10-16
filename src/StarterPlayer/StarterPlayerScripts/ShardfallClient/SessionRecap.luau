--!strict

--[[
	One line for the victory card.

	The server already counted the session. This module only formats the
	four numbers Progression.recap uses: level before, level after, Epics,
	and Relic Set percent. It does not read the profile or grant anything.

	Missing and zero fields drop out. One of a kind is singular. The line
	stays short enough for the card on a phone. Progression.luau is not
	required here: the gain is max(0, after - before), and the percent is
	clamped to 0-100, which is the same math as Progression.recap.
]]

local SessionRecap = {}

export type Recap = {
	beforeLevel: number?,
	afterLevel: number?,
	epics: number?,
	setPct: number?,
}

-- About two lines in the victory card body (308px at TextSize 15).
SessionRecap.MAX_CHARS = 60

local LEVEL_CAP = 9999
local EPIC_CAP = 999
local PREFIX = "This session: "
local QUIET = PREFIX .. "a quiet clear."

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function measure(value: any, cap: number): (number?, boolean)
	local n = finite(value)
	if n == nil then
		return nil, false
	end
	local floored = math.floor(n)
	if floored < 0 then
		return 0, false
	end
	if floored > cap then
		return cap, true
	end
	return floored, false
end

local function counted(value: number, one: string, many: string, overflow: boolean): string
	if value == 1 and not overflow then
		return "1 " .. one
	end
	if overflow then
		return tostring(value) .. "+ " .. many
	end
	return tostring(value) .. " " .. many
end

local function assemble(levels: string?, epics: string?, relic: string?): string
	local parts = {}
	if levels ~= nil then
		table.insert(parts, levels)
	end
	if epics ~= nil then
		table.insert(parts, epics)
	end
	if relic ~= nil then
		table.insert(parts, relic)
	end
	if #parts == 0 then
		return QUIET
	end
	return PREFIX .. table.concat(parts, ", ")
end

local function fit(levels: string?, epics: string?, relicLong: string?, relicShort: string?): string
	local full = assemble(levels, epics, relicLong)
	if #full <= SessionRecap.MAX_CHARS then
		return full
	end
	local shortened = assemble(levels, epics, relicShort)
	if #shortened <= SessionRecap.MAX_CHARS then
		return shortened
	end
	local dropped = assemble(levels, epics, nil)
	if #dropped <= SessionRecap.MAX_CHARS then
		return dropped
	end
	if levels ~= nil and #(PREFIX .. levels) <= SessionRecap.MAX_CHARS then
		return PREFIX .. levels
	end
	if epics ~= nil and #(PREFIX .. epics) <= SessionRecap.MAX_CHARS then
		return PREFIX .. epics
	end
	return QUIET
end

local function fromTable(data: any): string
	local saw = false
	local levelClause: string? = nil
	local beforeLevel = measure(data.beforeLevel, LEVEL_CAP)
	local afterLevel = measure(data.afterLevel, LEVEL_CAP)
	if beforeLevel ~= nil and afterLevel ~= nil then
		saw = true
		local gain = math.max(0, afterLevel - beforeLevel)
		if gain > 0 then
			levelClause = "+" .. counted(gain, "level", "levels", false)
		end
	end

	local epicClause: string? = nil
	local epics, epicOverflow = measure(data.epics, EPIC_CAP)
	if epics ~= nil then
		saw = true
		if epics > 0 then
			epicClause = counted(epics, "Epic", "Epics", epicOverflow)
		end
	end

	local relicLong: string? = nil
	local relicShort: string? = nil
	local setPct = measure(data.setPct, 100)
	if setPct ~= nil then
		saw = true
		if setPct > 0 then
			relicLong = string.format("%d%% to your Relic Set", setPct)
			relicShort = string.format("%d%% Relic Set", setPct)
		end
	end

	if not saw then
		return ""
	end
	if levelClause == nil and epicClause == nil and relicLong == nil then
		return QUIET
	end
	return fit(levelClause, epicClause, relicLong, relicShort)
end

function SessionRecap.line(source: any, afterLevel: any?, epics: any?, setPct: any?): string
	if type(source) == "table" then
		return fromTable(source)
	end
	if source == nil and afterLevel == nil and epics == nil and setPct == nil then
		return ""
	end
	return fromTable({
		beforeLevel = source,
		afterLevel = afterLevel,
		epics = epics,
		setPct = setPct,
	})
end

return SessionRecap
