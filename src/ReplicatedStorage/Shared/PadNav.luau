--!strict

--[[
	Next index for the hub selection ring.

	D-pad Down and Right step to the next visible button. Up and Left
	step to the previous one. Either end wraps. A stick past the
	deadzone takes one step in that direction, and no further step
	until the tilt returns inside. A small tilt does nothing.

	ButtonA, ButtonB, the bumpers, ButtonX, and ButtonY do not move
	the index. paid does not move it either.

	A third argument, including paid = true, does not change the index.
	Each call reads its arguments and does not write them. No clock.
	No RNG. No services. Nothing here costs Robux.
]]

local PadNav = {}

PadNav.DEADZONE = 0.5

local KEY_DELTA: { [string]: number } = {
	DPadDown = 1,
	DPadRight = 1,
	DPadUp = -1,
	DPadLeft = -1,
}

local AXIS_DELTA: { [string]: number } = {
	down = 1,
	right = 1,
	up = -1,
	left = -1,
}

export type Cursor = {
	count: number,
	index: number,
	held: string,
}

export type Step = {
	index: number,
	held: string,
}

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function whole(value: any): number?
	local number = finite(value)
	if number == nil or number ~= math.floor(number) then
		return nil
	end
	return number
end

function PadNav.counts(keyName: any, _extra: any): boolean
	return type(keyName) == "string" and KEY_DELTA[keyName] ~= nil
end

local function readCursor(cursor: any): Cursor
	local source = if type(cursor) == "table" then cursor else {}
	local count = whole(source.count)
	local index = whole(source.index)
	local held = if type(source.held) == "string" then source.held else ""
	if count == nil or count < 1 then
		return { count = 0, index = 1, held = held }
	end
	if index == nil or index < 1 or index > count then
		index = 1
	end
	return { count = count, index = index, held = held }
end

local function wrap(count: number, index: number, delta: number): number
	local nextIndex = index + delta
	if nextIndex > count then
		return 1
	end
	if nextIndex < 1 then
		return count
	end
	return nextIndex
end

local function stickDirection(x: number, y: number): string?
	local ax = math.abs(x)
	local ay = math.abs(y)
	if ax <= PadNav.DEADZONE and ay <= PadNav.DEADZONE then
		return nil
	end
	if ay >= ax then
		return if y > 0 then "up" else "down"
	end
	return if x > 0 then "right" else "left"
end

local function readMove(move: any): (number?, string?)
	if type(move) == "string" then
		return KEY_DELTA[move], nil
	end
	if type(move) ~= "table" then
		return nil, nil
	end
	if type(move.key) == "string" then
		return KEY_DELTA[move.key], nil
	end
	local x = finite(move.x)
	local y = finite(move.y)
	if x == nil or y == nil then
		return nil, nil
	end
	local direction = stickDirection(x, y)
	if direction == nil then
		return 0, ""
	end
	return AXIS_DELTA[direction], direction
end

function PadNav.next(cursor: any, move: any, _extra: any): Step
	local place = readCursor(cursor)
	if place.count < 1 then
		return { index = 1, held = "" }
	end
	local delta, direction = readMove(move)
	if delta == nil then
		return { index = place.index, held = place.held }
	end
	if direction == nil then
		return { index = wrap(place.count, place.index, delta), held = place.held }
	end
	if direction == "" then
		return { index = place.index, held = "" }
	end
	if place.held == direction then
		return { index = place.index, held = direction }
	end
	return { index = wrap(place.count, place.index, delta), held = direction }
end

return PadNav
