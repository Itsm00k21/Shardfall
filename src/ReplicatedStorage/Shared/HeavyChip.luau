--!strict

--[[
	Heavy chip on the phone combat cluster.

	place(viewportX, viewportY) returns the chip above the Dodge prompt
	from the mobile action bar. The size matches that prompt. A missing
	or bad size is 390 by 844. That includes nil, a string, NaN,
	infinity, and any side under 200.

	show(mobile) is true only when mobile is exactly true. A desktop
	bar keeps R and ButtonX and does not show the chip.

	A third argument, including paid = true, does not move the rect
	and does not change show. Each call reads its arguments and does
	not write them. No clock. No RNG. No services other than
	ActionSlots. Nothing here costs Robux.
]]

local ActionSlots = require("./ActionSlots")

local HeavyChip = {}

local FALLBACK_X = 390
local FALLBACK_Y = 844
local MIN_SIDE = 200
local GAP = 8

export type Rect = { x: number, y: number, w: number, h: number }

local function axis(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function viewportOf(viewportX: any, viewportY: any): (number, number)
	local vx = axis(viewportX)
	local vy = axis(viewportY)
	if vx == nil or vy == nil or vx < MIN_SIDE or vy < MIN_SIDE then
		return FALLBACK_X, FALLBACK_Y
	end
	return vx, vy
end

function HeavyChip.place(viewportX: any, viewportY: any, _extra: any): Rect
	local vx, vy = viewportOf(viewportX, viewportY)
	local bar = ActionSlots.placement(vx, vy, true)
	local chips = ActionSlots.prompts(bar, vx, vy)
	local dodge = chips.dodge
	return {
		x = dodge.x,
		y = dodge.y - dodge.h - GAP,
		w = dodge.w,
		h = dodge.h,
	}
end

function HeavyChip.show(mobile: any, _extra: any): boolean
	return mobile == true
end

return HeavyChip
