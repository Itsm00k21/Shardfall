--!strict

--[[
	Gold banner rect.

	fit(viewportX, viewportY, textScale) returns a new rect and the
	text size for that line. The viewport is already the safe area.
	The rect stays inside it. Height is the line, and the bottom
	stops at the top of HudLayout.toast.

	Text size is max(UiTheme.MIN_TEXT, floor(16 * scale + 0.5)).
	A missing or bad scale is 1, so the size stays 16. Bad means
	nil, not a number, NaN, <= 0, or infinity.

	Extra arguments are ignored. paid, a product id, Robux, cost,
	and skip do not move the rect. No clock. No RNG. No services.
	Nothing here costs Robux.
]]

local HudLayout = require("./HudLayout")
local UiTheme = require("./UiTheme")

local BannerFit = {}

local BASE_TEXT = 16

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
	textSize: number,
}

local function scaleOf(value: any): number
	if type(value) ~= "number" then
		return 1
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return 1
	end
	if value <= 0 then
		return 1
	end
	return value
end

local function axis(value: any): number
	if type(value) ~= "number" then
		return 0
	end
	if value ~= value or value == math.huge or value == -math.huge or value <= 0 then
		return 0
	end
	return math.floor(value)
end

local function textSizeOf(scale: number): number
	return math.max(UiTheme.MIN_TEXT, math.floor(BASE_TEXT * scale + 0.5))
end

function BannerFit.fit(viewportX: any, viewportY: any, textScale: any): Rect
	local vx = axis(viewportX)
	local vy = axis(viewportY)
	local textSize = textSizeOf(scaleOf(textScale))
	local pad = UiTheme.PAD
	local x = math.min(pad, vx)
	local y = math.min(pad, vy)
	local right = math.min(pad, vx - x)
	local w = vx - x - right
	if w < 0 then
		w = 0
	end
	local toast = HudLayout.toast(vx, UiTheme.safeMargin())
	local limit = toast.y
	if limit > vy then
		limit = vy
	end
	if limit < y then
		limit = y
	end
	local room = limit - y
	-- 8px above and below the glyphs, the same pad the label already uses.
	local line = textSize + pad * 2
	local h = line
	if h > room then
		h = room
	end
	if h < 0 then
		h = 0
	end
	return {
		x = x,
		y = y,
		w = w,
		h = h,
		textSize = textSize,
	}
end

return BannerFit
