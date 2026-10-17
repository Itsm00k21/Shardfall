--!strict

--[[
	Story Echo chip on the right edge of the safe rect.

	place(viewportX, viewportY) returns { x, y, w, h }. The margin is
	UiTheme.safeMargin. The chip is 128 by 28 when the safe room
	(viewportX - margin * 2) is at least 128 wide. A narrower room uses
	that room as the width, and the width does not go under 44. Height
	stays 28.

	x is viewportX - margin - width. The slots, in order, are the top
	row (y = margin), under the HP bar (HudLayout.health), and under
	the gold pills (HudLayout.pills). The gap under a blocker is 8.
	The first slot that stays inside the margin and misses the
	portrait, the HP bar, and the pills is the one returned. If none
	do, the under-pills slot is returned anyway.

	A missing or bad size is 390 by 844. That includes nil, a string,
	NaN, infinity, and any side under 200. A third argument, including
	paid = true, does not move the rect. Each call reads its arguments
	and does not write them. No clock. No RNG. No services other than
	HudLayout and UiTheme. Nothing here costs Robux.
]]

local HudLayout = require("./HudLayout")
local UiTheme = require("./UiTheme")

local EchoChip = {}

local PREFERRED_W = 128
local CHIP_H = 28
local MIN_W = 44
local GAP = 8
local FALLBACK_X = 390
local FALLBACK_Y = 844
local MIN_SIDE = 200

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

-- Safe room is viewportX - margin * 2. At least 128 keeps the chip at
-- 128. A narrower room is the width, and 44 is the floor.
local function chipWidth(viewportX: number, margin: number): number
	local room = viewportX - margin * 2
	if room >= PREFERRED_W then
		return PREFERRED_W
	end
	if room >= MIN_W then
		return room
	end
	return MIN_W
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

local function inside(slot: Rect, vx: number, vy: number, margin: number): boolean
	return slot.x >= margin
		and slot.y >= margin
		and slot.x + slot.w <= vx - margin
		and slot.y + slot.h <= vy - margin
end

local function blocked(slot: Rect, vx: number, margin: number): boolean
	return HudLayout.overlaps(slot, HudLayout.portrait(margin))
		or HudLayout.overlaps(slot, HudLayout.health(margin))
		or HudLayout.overlaps(slot, HudLayout.pills(vx, margin))
end

function EchoChip.place(viewportX: any, viewportY: any, _extra: any?): Rect
	local vx, vy = viewportOf(viewportX, viewportY)
	local margin = UiTheme.safeMargin()
	local w = chipWidth(vx, margin)
	local x = vx - margin - w
	local health = HudLayout.health(margin)
	local pills = HudLayout.pills(vx, margin)
	local order = { margin, health.y + health.h + GAP, pills.y + pills.h + GAP }
	for _, y in ipairs(order) do
		local slot = rect(x, y, w, CHIP_H)
		if inside(slot, vx, vy, margin) and not blocked(slot, vx, margin) then
			return slot
		end
	end
	return rect(x, pills.y + pills.h + GAP, w, CHIP_H)
end

return EchoChip
