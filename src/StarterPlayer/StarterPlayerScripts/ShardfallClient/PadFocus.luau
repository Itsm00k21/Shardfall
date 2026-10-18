--!strict

--[[
	Controller focus for the hub.

	Up and down walk the focus order: tabs, the close button, then the
	open page. Left and right jump to the nearest control in that
	direction when the layout has one, and otherwise take the same step
	as up and down. Controls that share one point (a list the engine has
	not positioned yet) are stacked so a sideways step can still leave
	the column.

	The ring is a white stroke, the same idea as the selected hotbar
	slot in docs/design/UI_STYLE.md. Thickness 4 stays readable on a
	phone and at TV distance. The color is UiTheme text white, which
	clears contrast 4.5 on the hub body, panel, and header.

	This module does not fire action-bar slots. While the hub is closed
	the D-pad still uses slots 1-4 and LB plus the D-pad uses slots 5-8
	(Keybinds.PAD). ButtonY stays dodge. ButtonR1 stays the light attack.
	ButtonX stays heavy. ButtonA confirms only while the hub is open.

	A third argument, including paid = true, does not change a step.
	Nothing here costs Robux.
]]

local PadFocus = {}

PadFocus.DEADZONE = 0.55
PadFocus.RING = 4
PadFocus.RING_RGB = { 244, 240, 252 }
PadFocus.SPREAD = 8

export type Entry = {
	x: number,
	y: number,
	w: number,
	h: number,
	column: number,
	order: number,
	seq: number,
}

local function finite(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return value
end

local function rowOf(entry: any, index: number): Entry
	local source = if type(entry) == "table" then entry else {}
	return {
		x = finite(source.x, 0),
		y = finite(source.y, 0),
		w = finite(source.w, 0),
		h = finite(source.h, 0),
		column = finite(source.column, 0),
		order = finite(source.order, 0),
		seq = finite(source.seq, index),
	}
end

local function before(a: Entry, b: Entry): boolean
	if a.column ~= b.column then
		return a.column < b.column
	end
	if a.order ~= b.order then
		return a.order < b.order
	end
	if a.y ~= b.y then
		return a.y < b.y
	end
	if a.x ~= b.x then
		return a.x < b.x
	end
	return a.seq < b.seq
end

function PadFocus.direction(keyName: any): string?
	if keyName == "DPadUp" then
		return "up"
	end
	if keyName == "DPadDown" then
		return "down"
	end
	if keyName == "DPadLeft" then
		return "left"
	end
	if keyName == "DPadRight" then
		return "right"
	end
	return nil
end

-- One step when the stick leaves the deadzone. Holding the same
-- direction does not repeat. +Y is up, matching the gamepad stick.
function PadFocus.stick(x: any, y: any, held: any, _extra: any): (string?, string)
	if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then
		return nil, ""
	end
	if x == math.huge or y == math.huge or x == -math.huge or y == -math.huge then
		return nil, ""
	end
	local ax = math.abs(x)
	local ay = math.abs(y)
	if ax < PadFocus.DEADZONE and ay < PadFocus.DEADZONE then
		return nil, ""
	end
	local direction: string
	if ay >= ax then
		direction = if y > 0 then "up" else "down"
	else
		direction = if x > 0 then "right" else "left"
	end
	local previous = if type(held) == "string" then held else ""
	if previous == direction then
		return nil, direction
	end
	return direction, direction
end

local function readingIndex(entries: { any }, index: number, direction: string): number
	local count = #entries
	local rows: { Entry } = {}
	local perm = {}
	for cursor, entry in ipairs(entries) do
		rows[cursor] = rowOf(entry, cursor)
		perm[cursor] = cursor
	end
	table.sort(perm, function(a: number, b: number): boolean
		return before(rows[a], rows[b])
	end)
	local place = 1
	for cursor, slot in ipairs(perm) do
		if slot == index then
			place = cursor
		end
	end
	local nextPlace = place
	if direction == "down" or direction == "right" then
		nextPlace = (place % count) + 1
	else
		nextPlace = ((place - 2) % count) + 1
	end
	return perm[nextPlace]
end

local function quant(value: number): number
	return math.floor(value / PadFocus.SPREAD + 0.5)
end

-- Stack controls that share a point so a sideways step can see the column.
function PadFocus.present(entries: { any }): { Entry }
	local rows: { Entry } = {}
	local groups: { [string]: { Entry } } = {}
	local order: { string } = {}
	for index, entry in ipairs(entries) do
		local row = rowOf(entry, index)
		rows[index] = row
		local key = tostring(quant(row.x + row.w / 2)) .. ":" .. tostring(quant(row.y + row.h / 2))
		local group = groups[key]
		if group == nil then
			group = {}
			groups[key] = group
			table.insert(order, key)
		end
		table.insert(group, row)
	end
	for _, key in ipairs(order) do
		local group = groups[key]
		if #group > 1 then
			table.sort(group, before)
			local anchor = group[1]
			local step = math.max(anchor.h, 44)
			for place, row in ipairs(group) do
				row.x = anchor.x
				row.y = anchor.y + (place - 1) * (step + PadFocus.SPREAD)
			end
		end
	end
	return rows
end

local function aim(from: Entry, to: Entry, direction: string): number?
	local dx = (to.x + to.w / 2) - (from.x + from.w / 2)
	local dy = (to.y + to.h / 2) - (from.y + from.h / 2)
	local along = 0
	local across = 0
	if direction == "up" then
		along = -dy
		across = math.abs(dx)
	elseif direction == "down" then
		along = dy
		across = math.abs(dx)
	elseif direction == "left" then
		along = -dx
		across = math.abs(dy)
	elseif direction == "right" then
		along = dx
		across = math.abs(dy)
	else
		return nil
	end
	if along <= PadFocus.SPREAD then
		return nil
	end
	if across > along * 1.25 then
		return nil
	end
	return along + across * 2
end

function PadFocus.spatial(entries: { any }, index: number, direction: string): number?
	local rows = PadFocus.present(entries)
	local from = rows[index]
	if from == nil then
		return nil
	end
	local best: number? = nil
	local bestScore = math.huge
	local bestSeq = math.huge
	for cursor, entry in ipairs(rows) do
		if cursor ~= index then
			local score = aim(from, entry, direction)
			if
				score ~= nil and (score < bestScore or (score == bestScore and entry.seq < bestSeq))
			then
				best = cursor
				bestScore = score
				bestSeq = entry.seq
			end
		end
	end
	return best
end

function PadFocus.step(entries: { any }, index: number, direction: string, _extra: any): number
	local count = if type(entries) == "table" then #entries else 0
	if count == 0 then
		return 1
	end
	if
		type(index) ~= "number"
		or index ~= index
		or index == math.huge
		or index == -math.huge
		or index < 1
		or index > count
		or index ~= math.floor(index)
	then
		index = 1
	end
	if direction == "up" or direction == "down" then
		return readingIndex(entries, index, direction)
	end
	if direction == "left" or direction == "right" then
		local spatial = PadFocus.spatial(entries, index, direction)
		if spatial ~= nil then
			return spatial
		end
		return readingIndex(entries, index, direction)
	end
	return index
end

return PadFocus
