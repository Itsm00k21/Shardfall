--!strict

--[[
	What one Roll-tab control does.

	Each button name maps to one action. Gear is not the fallback.
	Info is a view: while it is open, Gear and Pets are not lit, and
	pressing either of them closes Info and selects that kind.
	x10, Quick, Stop, Auto, and the junk controls never change kind.

	x10 with fewer tokens than RollConfig.cost(10) says Need 9 shards and does not
	crack once. A click on Auto counts as focus, so a stale unfocused
	flag cannot swallow it.

	history places the Last 10 chips inside the row width. The last
	chip's right edge is the row width or less.

	paid does not change an action. Nothing here costs Robux.
]]

local RollBatch = require("./RollBatch")
local RollBoard = require("./RollBoard")
local RollFocus = require("./RollFocus")

local HubPress = {}

HubPress.IDS = {
	"GearShards",
	"PetShards",
	"TimesTen",
	"Auto",
	"Stop",
	"Quick",
	"Info",
	"JunkMode",
	"JunkBelow",
}

local JUNK = { "ask", "keep", "salvage" }
local BELOW = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

export type State = {
	infoOpen: boolean,
	rollKind: string,
	autoOn: boolean,
	quickOn: boolean,
	stopAt: string,
	autoJunk: string,
	junkBelow: string,
	tokens: number,
	focused: boolean,
	busy: boolean,
	batching: boolean,
}

export type Effect = {
	notice: string?,
	rollCount: number?,
	save: boolean,
	handled: boolean,
}

export type Chip = {
	x: number,
	y: number,
	w: number,
	h: number,
}

export type Strip = {
	w: number,
	h: number,
	chips: { Chip },
}

local function copy(state: State): State
	return {
		infoOpen = state.infoOpen == true,
		rollKind = if state.rollKind == "pets" then "pets" else "gear",
		autoOn = state.autoOn == true,
		quickOn = state.quickOn == true,
		stopAt = if type(state.stopAt) == "string" then state.stopAt else "Off",
		autoJunk = if type(state.autoJunk) == "string" then state.autoJunk else "ask",
		junkBelow = if type(state.junkBelow) == "string" then state.junkBelow else "Common",
		tokens = if type(state.tokens) == "number" then state.tokens else 0,
		focused = state.focused == true,
		busy = state.busy == true,
		batching = state.batching == true,
	}
end

function HubPress.blank(): State
	return {
		infoOpen = false,
		rollKind = "gear",
		autoOn = false,
		quickOn = false,
		stopAt = "Off",
		autoJunk = "ask",
		junkBelow = "Common",
		tokens = 0,
		focused = true,
		busy = false,
		batching = false,
	}
end

local function cycle(order: { string }, current: string): string
	for index, name in ipairs(order) do
		if name == current then
			return order[(index % #order) + 1]
		end
	end
	return order[1]
end

local function quiet(state: State): (State, Effect)
	return state, { notice = nil, rollCount = nil, save = false, handled = true }
end

function HubPress.press(state: State, id: string, _extra: any?): (State, Effect)
	local nextState = copy(state)
	if id == "GearShards" then
		nextState.infoOpen = false
		nextState.rollKind = "gear"
		return quiet(nextState)
	end
	if id == "PetShards" then
		nextState.infoOpen = false
		nextState.rollKind = "pets"
		return quiet(nextState)
	end
	if id == "Info" then
		nextState.infoOpen = not nextState.infoOpen
		return quiet(nextState)
	end
	if id == "TimesTen" then
		local why = RollBatch.block(nextState.tokens, 10)
		if why ~= nil then
			return nextState, { notice = why, rollCount = nil, save = false, handled = true }
		end
		if nextState.busy then
			return quiet(nextState)
		end
		return nextState, { notice = nil, rollCount = 10, save = false, handled = true }
	end
	if id == "Auto" then
		nextState.focused = true
		nextState.autoOn = RollFocus.keep(true, not nextState.autoOn)
		local rollCount = nil
		if nextState.autoOn and not nextState.busy then
			rollCount = 1
		end
		return nextState, { notice = nil, rollCount = rollCount, save = true, handled = true }
	end
	if id == "Stop" then
		nextState.stopAt = RollBoard.nextStop(nextState.stopAt)
		return quiet(nextState)
	end
	if id == "Quick" then
		nextState.quickOn = not nextState.quickOn
		return quiet(nextState)
	end
	if id == "JunkMode" then
		nextState.autoJunk = cycle(JUNK, nextState.autoJunk)
		return nextState, { notice = nil, rollCount = nil, save = true, handled = true }
	end
	if id == "JunkBelow" then
		nextState.junkBelow = cycle(BELOW, nextState.junkBelow)
		return nextState, { notice = nil, rollCount = nil, save = true, handled = true }
	end
	return nextState, { notice = nil, rollCount = nil, save = false, handled = false }
end

function HubPress.lit(state: State, id: string): boolean
	if id == "Info" then
		return state.infoOpen == true
	end
	if id == "GearShards" then
		return state.infoOpen ~= true and state.rollKind ~= "pets"
	end
	if id == "PetShards" then
		return state.infoOpen ~= true and state.rollKind == "pets"
	end
	if id == "TimesTen" then
		return state.batching == true
	end
	if id == "Auto" then
		return state.autoOn == true
	end
	if id == "Quick" then
		return state.quickOn == true
	end
	if id == "Stop" then
		return type(state.stopAt) == "string" and state.stopAt ~= "Off"
	end
	return false
end

function HubPress.history(width: any, count: any, _extra: any?): Strip
	local row = width
	if type(row) ~= "number" or row ~= row or row == math.huge or row < 44 then
		row = 280
	end
	row = math.floor(row)
	local total = count
	if type(total) ~= "number" or total ~= total or total < 1 then
		total = 0
	end
	total = math.floor(total)
	if total > 10 then
		total = 10
	end
	local gap = 4
	local minChip = 64
	local rowH = 44
	local cols = math.max(1, math.floor((row + gap) / (minChip + gap)))
	if total > 0 and cols > total then
		cols = total
	end
	local chipW = row
	if cols > 1 then
		chipW = math.floor((row - gap * (cols - 1)) / cols)
	end
	if chipW < 1 then
		chipW = 1
	end
	local rows = if total == 0 then 0 else math.ceil(total / cols)
	local chips = {}
	for index = 1, total do
		local col = (index - 1) % cols
		local line = math.floor((index - 1) / cols)
		local x = col * (chipW + gap)
		local w = chipW
		if col == cols - 1 then
			w = row - x
		end
		table.insert(chips, {
			x = x,
			y = line * (rowH + gap),
			w = w,
			h = rowH,
		})
	end
	local h = 0
	if rows > 0 then
		h = rows * rowH + (rows - 1) * gap
	end
	return { w = row, h = h, chips = chips }
end

export type Cover = {
	name: string,
	visible: boolean,
	active: boolean,
	transparency: number,
	z: number,
	modal: boolean,
	full: boolean,
}

-- An invisible full-size Active frame above the open panel eats clicks.
-- Backdrop is the dim behind the panel, so it is not a cover.
function HubPress.blocker(rows: { Cover }?): string?
	if type(rows) ~= "table" then
		return nil
	end
	for _, row in ipairs(rows) do
		if
			type(row) == "table"
			and row.name ~= "Backdrop"
			and row.visible == true
			and (row.active == true or row.modal == true)
			and type(row.transparency) == "number"
			and row.transparency >= 0.95
			and row.full == true
			and type(row.z) == "number"
			and row.z >= 4
		then
			return row.name
		end
	end
	return nil
end

return HubPress
