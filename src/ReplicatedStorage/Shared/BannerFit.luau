--!strict

--[[
	Gold banner lane.

	fit(viewportX, viewportY, textScale) returns a new rect and the
	text size. The viewport is already the safe area. Text size is
	max(UiTheme.MIN_TEXT, floor(16 * scale + 0.5)). A missing or bad
	scale is 1, so the size stays 16.

	Height is one line, textSize plus 8px above and below. The rect
	takes the highest strip that is at least 160px wide and misses
	the portrait, the HP bar, HudLayout.RAIL_COUNT rail buttons,
	HudLayout.toastHost, HudLayout.equipPrompt, the currency pills,
	and the hub close button. On a landscape phone that strip is
	the top row, 8px in and to the right of the HP bar. On a portrait
	phone the top row is narrower than 160, so the strip sits 8px
	under the equip prompt and 8px to the right of the rail. A line
	that would pass the bottom of the viewport is shortened. The
	font is not.

	Extra arguments are ignored. paid, a product id, Robux, cost,
	and skip do not move the rect. No clock. No RNG. No services.
	Nothing here costs Robux.
]]

local HudLayout = require("./HudLayout")
local UiTheme = require("./UiTheme")

local BannerFit = {}

local BASE_TEXT = 16
-- HudLayout.toast never goes under this width.
local LANE_MIN = 160

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
	textSize: number,
}

type Box = { x: number, y: number, w: number, h: number }

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

local function box(x: number, y: number, w: number, h: number): Box
	return { x = x, y = y, w = w, h = h }
end

-- Portrait, HP, rail, toast stack, equip prompt, currency pills, and
-- the hub close button. The lane has to miss every one of these.
local function occupied(vx: number, vy: number, margin: number): { Box }
	local pad = UiTheme.PAD
	local hub = HudLayout.hub(vx, vy, margin)
	local rail = HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, vx)
	return {
		HudLayout.portrait(margin),
		HudLayout.health(margin, vx),
		HudLayout.pills(vx, margin),
		HudLayout.toastHost(vx, margin),
		HudLayout.equipPrompt(vx, margin),
		box(rail.x, rail.y, rail.w, rail.h),
		box(hub.x + hub.w - pad - UiTheme.TOUCH, hub.y + pad, UiTheme.TOUCH, UiTheme.TOUCH),
	}
end

local function crosses(y: number, h: number, obstacle: Box): boolean
	return h > 0
		and obstacle.h > 0
		and obstacle.w > 0
		and y < obstacle.y + obstacle.h
		and obstacle.y < y + h
end

-- Widest gap inside the 8px viewport inset, with an 8px gutter off
-- every blocker that crosses this strip. Equal gaps keep the left one.
local function widest(vx: number, y: number, h: number, blockers: { Box }): (number, number)
	local pad = UiTheme.PAD
	local leftBound = math.min(pad, vx)
	local rightInset = math.min(pad, math.max(0, vx - leftBound))
	local rightBound = vx - rightInset
	if h <= 0 or rightBound <= leftBound then
		return leftBound, 0
	end
	local cuts: { { number } } = {}
	for _, obstacle in ipairs(blockers) do
		if crosses(y, h, obstacle) then
			table.insert(cuts, { obstacle.x - pad, obstacle.x + obstacle.w + pad })
		end
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local merged: { { number } } = {}
	for _, cut in ipairs(cuts) do
		local last = merged[#merged]
		if last == nil or cut[1] > last[2] then
			table.insert(merged, { cut[1], cut[2] })
		elseif cut[2] > last[2] then
			last[2] = cut[2]
		end
	end
	local cursor = leftBound
	local bestX = leftBound
	local bestW = 0
	for _, cut in ipairs(merged) do
		local stop = cut[1]
		if stop > rightBound then
			stop = rightBound
		end
		if stop > cursor then
			local gap = stop - cursor
			if gap > bestW then
				bestW = gap
				bestX = cursor
			end
		end
		if cut[2] > cursor then
			cursor = cut[2]
		end
	end
	if cursor < rightBound then
		local gap = rightBound - cursor
		if gap > bestW then
			bestW = gap
			bestX = cursor
		end
	end
	if bestW < 0 then
		bestW = 0
	end
	return bestX, bestW
end

local function measure(vx: number, vy: number, y: number, line: number, blockers: { Box }): Rect
	if y < 0 then
		y = 0
	end
	if y > vy then
		y = vy
	end
	local room = vy - y
	local h = line
	if h > room then
		h = room
	end
	if h < 0 then
		h = 0
	end
	local x, w = widest(vx, y, h, blockers)
	return {
		x = x,
		y = y,
		w = w,
		h = h,
		textSize = 0,
	}
end

function BannerFit.fit(viewportX: any, viewportY: any, textScale: any): Rect
	local vx = axis(viewportX)
	local vy = axis(viewportY)
	local textSize = textSizeOf(scaleOf(textScale))
	local pad = UiTheme.PAD
	local margin = UiTheme.safeMargin()
	local line = textSize + pad * 2
	local blockers = occupied(vx, vy, margin)
	local top = measure(vx, vy, math.min(pad, vy), line, blockers)
	local minWide = math.min(LANE_MIN, math.max(0, vx - pad * 2))
	local chosen = top
	if top.w < minWide then
		local prompt = HudLayout.equipPrompt(vx, margin)
		local below = prompt.y + prompt.h + pad
		if below < vy then
			local lower = measure(vx, vy, below, line, blockers)
			if lower.w > top.w then
				chosen = lower
			end
		end
	end
	chosen.textSize = textSize
	return chosen
end

return BannerFit
