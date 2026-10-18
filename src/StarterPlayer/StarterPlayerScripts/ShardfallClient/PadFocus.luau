--!strict

--[[
	Client focus math for the hub ring. PadNav owns the next index, the
	deadzone, and which D-pad keys count. This module asks PadNav for
	those, then picks a nearer control on left and right.

	Up and down follow the focus list and wrap. Left and right jump to
	the nearest control in that direction, and wrap the same way when
	nothing sits there. A stick past the deadzone takes one step and
	waits until the tilt comes back inside. A small tilt does nothing.

	canvas scrolls a row into a ScrollingFrame. The button's absolute
	position already includes the current scroll, so the result is the
	canvas position that brings the row fully into the view.

	A third argument, including paid = true, changes nothing. Each call
	reads its arguments and does not write them. No clock. No RNG. No
	services. Nothing here costs Robux.
]]

local PadNav = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PadNav"))

local PadFocus = {}

PadFocus.DEADZONE = PadNav.DEADZONE
PadFocus.SPREAD = 8

local KEY_DIRECTION: { [string]: string } = {
	DPadDown = "down",
	DPadUp = "up",
	DPadLeft = "left",
	DPadRight = "right",
}

export type Stick = {
	direction: string?,
	held: string,
}

export type Canvas = {
	x: number,
	y: number,
}

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function component(source: any, key: string): number
	if type(source) ~= "table" then
		return 0
	end
	return finite(source[key]) or 0
end

function PadFocus.direction(keyName: any, extra: any): string?
	if PadNav.counts(keyName, extra) ~= true or type(keyName) ~= "string" then
		return nil
	end
	return KEY_DIRECTION[keyName]
end

local function countOf(count: any): number
	local number = finite(count)
	if number == nil or number < 1 then
		return 0
	end
	return math.floor(number)
end

local function indexOf(index: any, count: number): number
	local number = finite(index)
	if count < 1 or number == nil or number < 1 or number > count then
		return 1
	end
	return math.floor(number)
end

local function wrap(count: number, index: number, direction: string): number
	local key = "DPadUp"
	if direction == "down" then
		key = "DPadDown"
	elseif direction == "right" then
		key = "DPadRight"
	elseif direction == "left" then
		key = "DPadLeft"
	end
	return PadNav.next({ count = count, index = index, held = "" }, key).index
end

local function center(boxes: any, index: number): (number, number)
	local box = if type(boxes) == "table" then boxes[index] else nil
	local x = component(box, "x")
	local y = component(box, "y")
	local w = component(box, "w")
	local h = component(box, "h")
	return x + w / 2, y + h / 2
end

local function nearest(index: number, count: number, direction: string, boxes: any): number?
	if type(boxes) ~= "table" then
		return nil
	end
	local fromX, fromY = center(boxes, index)
	local bestIndex = nil
	local bestDistance = math.huge
	for cursor = 1, count do
		if cursor ~= index and boxes[cursor] ~= nil then
			local x, y = center(boxes, cursor)
			local dx = x - fromX
			local dy = y - fromY
			local along = 0
			local across = 0
			if direction == "right" then
				along = dx
				across = math.abs(dy)
			elseif direction == "left" then
				along = -dx
				across = math.abs(dy)
			end
			if along > PadFocus.SPREAD and across <= along then
				local distance = along * along + across * across
				if distance < bestDistance then
					bestDistance = distance
					bestIndex = cursor
				end
			end
		end
	end
	return bestIndex
end

function PadFocus.step(index: any, count: any, direction: any, boxes: any, _extra: any): number
	local total = countOf(count)
	local cursor = indexOf(index, total)
	if total < 1 or type(direction) ~= "string" then
		return cursor
	end
	if direction ~= "up" and direction ~= "down" and direction ~= "left" and direction ~= "right" then
		return cursor
	end
	if direction == "left" or direction == "right" then
		local hit = nearest(cursor, total, direction, boxes)
		if hit ~= nil then
			return hit
		end
	end
	return wrap(total, cursor, direction)
end

local function stickDirection(x: number, y: number): string?
	local ax = math.abs(x)
	local ay = math.abs(y)
	if ax <= PadFocus.DEADZONE and ay <= PadFocus.DEADZONE then
		return nil
	end
	if ay >= ax then
		return if y > 0 then "up" else "down"
	end
	return if x > 0 then "right" else "left"
end

function PadFocus.stick(x: any, y: any, held: any, _extra: any): Stick
	local px = finite(x)
	local py = finite(y)
	local previous = if type(held) == "string" then held else ""
	if px == nil or py == nil then
		return { direction = nil, held = previous }
	end
	local direction = stickDirection(px, py)
	if direction == nil then
		return { direction = nil, held = "" }
	end
	if previous == direction then
		return { direction = nil, held = direction }
	end
	return { direction = direction, held = direction }
end

function PadFocus.canvas(frame: any, item: any, _extra: any): Canvas?
	if type(frame) ~= "table" or type(item) ~= "table" then
		return nil
	end
	local frameX = component(frame, "x")
	local frameY = component(frame, "y")
	local frameW = component(frame, "w")
	local frameH = component(frame, "h")
	local itemX = component(item, "x")
	local itemY = component(item, "y")
	local itemW = component(item, "w")
	local itemH = component(item, "h")
	local canvasX = component(frame, "canvasX")
	local canvasY = component(frame, "canvasY")
	local dx = 0
	local dy = 0
	if itemX < frameX then
		dx = itemX - frameX
	elseif itemX + itemW > frameX + frameW then
		dx = itemX + itemW - (frameX + frameW)
	end
	if itemY < frameY then
		dy = itemY - frameY
	elseif itemY + itemH > frameY + frameH then
		dy = itemY + itemH - (frameY + frameH)
	end
	if dx == 0 and dy == 0 then
		return nil
	end
	return { x = canvasX + dx, y = canvasY + dy }
end

return PadFocus
