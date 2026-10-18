--!strict

--[[
	Rects for the always-on shell. Coordinates are inside the safe GUI,
	so CoreUISafeInsets are already applied by the ScreenGui.

	RAIL_COUNT is the mid-left rail. toastHost is the card stack
	HudShell draws from toast. equipPrompt sits one pad under that
	stack. BannerFit and the starter-goal tracker read those rects.
]]

local ToastQueue = require("./ToastQueue")
local UiTheme = require("./UiTheme")

local HudLayout = {}

-- HudShell's RAIL list stays this long.
HudLayout.RAIL_COUNT = 7
-- Equip and Keep start this far down the prompt frame.
HudLayout.PROMPT_LABEL = 36

export type Rect = { x: number, y: number, w: number, h: number }

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function HudLayout.portrait(margin: number): Rect
	return rect(margin, margin, 56, 56)
end

function HudLayout.health(margin: number): Rect
	local portrait = HudLayout.portrait(margin)
	return rect(portrait.x + portrait.w + 8, margin, 220, 56)
end

function HudLayout.pills(viewportX: number, margin: number): Rect
	-- Gold, Mastery, and Shards. 108px each, plus the 8px gaps.
	local width = 340
	local room = viewportX - margin * 2
	if width > room then
		width = math.max(44, math.floor(room))
	end
	return rect(math.max(margin, viewportX - margin - width), margin + 36, width, 36)
end

function HudLayout.counters(gold: number, mastery: number, shards: number): { string }
	local function whole(value: number): number
		if
			type(value) ~= "number"
			or value ~= value
			or value == math.huge
			or value == -math.huge
		then
			return 0
		end
		return math.floor(value)
	end
	return {
		string.format("Gold %d", whole(gold)),
		string.format("Mastery %d", whole(mastery)),
		string.format("Shards %d", whole(shards)),
	}
end

function HudLayout.rail(viewportY: number, margin: number, count: number, button: number): Rect
	local gap = 8
	local height = count * button + math.max(0, count - 1) * gap
	local y = math.max(margin + 72, math.floor((viewportY - height) / 2))
	return rect(margin, y, button, height)
end

function HudLayout.toast(viewportX: number, margin: number): Rect
	local width = math.min(420, math.max(160, viewportX - 240))
	local x = math.floor((viewportX - width) / 2)
	return rect(x, margin + 64, width, 36)
end

-- ToastQueue.MAX cards, with one pad between each card.
function HudLayout.toastHost(viewportX: number, margin: number): Rect
	local toast = HudLayout.toast(viewportX, margin)
	local gap = UiTheme.PAD
	local cards = ToastQueue.MAX
	local height = toast.h * cards + gap * (cards - 1)
	return rect(toast.x, toast.y, toast.w, height)
end

-- The Equip / Keep frame, one pad under the toast stack.
function HudLayout.equipPrompt(viewportX: number, margin: number): Rect
	local host = HudLayout.toastHost(viewportX, margin)
	local gap = UiTheme.PAD
	local height = HudLayout.PROMPT_LABEL + UiTheme.TOUCH + gap
	return rect(host.x, host.y + host.h + gap, host.w, height)
end

-- Skills sit to the left and above the jump button. The jump rect is in
-- the same space as the HUD (subtract the ScreenGui AbsolutePosition).
function HudLayout.skills(
	viewportX: number,
	viewportY: number,
	jumpX: number,
	jumpY: number,
	jumpW: number,
	button: number
): { Rect }
	local gap = 8
	local clusterX = jumpX - button - gap
	if jumpW > 0 then
		clusterX = jumpX - button - gap
	end
	local clusterY = jumpY
	if clusterX < 8 then
		clusterX = math.max(8, viewportX - button * 2 - gap - 16)
		clusterY = math.max(8, viewportY - button * 3 - 24)
	end
	local slots = {}
	-- Two columns of three on the left of the jump button.
	table.insert(slots, rect(clusterX, clusterY, button, button))
	table.insert(slots, rect(clusterX, clusterY - button - gap, button, button))
	table.insert(slots, rect(clusterX - button - gap, clusterY, button, button))
	table.insert(slots, rect(clusterX - button - gap, clusterY - button - gap, button, button))
	table.insert(slots, rect(clusterX, clusterY - (button + gap) * 2, button, button))
	table.insert(
		slots,
		rect(clusterX - button - gap, clusterY - (button + gap) * 2, button, button)
	)
	return slots
end

function HudLayout.hub(viewportX: number, viewportY: number, margin: number): Rect
	local w = math.floor(math.clamp(viewportX * 0.72, 280, 860))
	local h = math.floor(math.clamp(viewportY * 0.78, 220, 640))
	local x = math.floor((viewportX - w) / 2)
	local y = math.max(margin, math.floor((viewportY - h) / 2))
	if y + h > viewportY - margin then
		h = math.max(160, viewportY - margin - y)
	end
	return rect(x, y, w, h)
end

function HudLayout.bottomLeftEmpty(viewportX: number, viewportY: number): Rect
	return rect(0, viewportY - 96, math.floor(viewportX * 0.28), 96)
end

-- Left icon column inside the hub panel. Buttons stay at least 44 tall;
-- the column itself scrolls when the panel is short.
function HudLayout.tabColumn(panelW: number, panelH: number): Rect
	local pad = 8
	local width = math.min(132, math.max(96, math.floor(panelW * 0.28)))
	if width > panelW - pad * 2 then
		width = math.max(44, panelW - pad * 2)
	end
	return rect(pad, pad, width, math.max(44, panelH - pad * 2))
end

-- Page area to the right of the tab column, under the header bar.
function HudLayout.hubBody(panelW: number, panelH: number): Rect
	local tabs = HudLayout.tabColumn(panelW, panelH)
	local gap = 12
	local header = UiTheme.HEADER + UiTheme.PAD
	local x = tabs.x + tabs.w + gap
	local y = header
	local w = math.max(44, panelW - x - 8)
	local h = math.max(44, panelH - y - 8)
	return rect(x, y, w, h)
end

export type Grid = {
	columns: number,
	rows: number,
	cellW: number,
	cellH: number,
	gap: number,
}

-- Card cells stay at least 44px and the row fits the host width.
function HudLayout.cardGrid(width: number, height: number, count: number): Grid
	local gap = 12
	local minCell = 44
	local prefer = 112
	local host = math.max(1, math.floor(width))
	local columns = 1
	if host >= prefer then
		columns = math.max(1, math.floor((host + gap) / (prefer + gap)))
	end
	local function cellOf(cols: number): number
		if cols <= 1 then
			return host
		end
		return math.floor((host - gap * (cols - 1)) / cols)
	end
	while columns > 1 and cellOf(columns) < minCell do
		columns -= 1
	end
	while columns > 1 and cellOf(columns) * columns + gap * (columns - 1) > host do
		columns -= 1
	end
	local cellW = cellOf(columns)
	if cellW < minCell and host >= minCell then
		cellW = minCell
		columns = 1
	end
	-- Icon, name, Equip, and Lock need this much. A short viewport
	-- scrolls; it does not squash the cell and spill the buttons.
	local cellH = math.max(188, math.min(220, cellW + 48))
	if type(height) ~= "number" then
		cellH = 188
	end
	local rows = math.max(1, math.ceil(math.max(count, 1) / columns))
	return {
		columns = columns,
		rows = rows,
		cellW = cellW,
		cellH = cellH,
		gap = gap,
	}
end

export type RailFit = { x: number, y: number, w: number, h: number, button: number }

-- Shrinks the icon only after the preferred size no longer fits.
-- The button never drops below `minimum` (44).
function HudLayout.railFit(
	viewportY: number,
	margin: number,
	count: number,
	preferred: number,
	minimum: number
): RailFit
	local gap = 8
	local safeCount = math.max(1, count)
	local floorSize = math.max(1, minimum)
	local button = math.max(floorSize, preferred)
	local function heightOf(size: number): number
		return safeCount * size + (safeCount - 1) * gap
	end
	local available = math.max(floorSize, viewportY - margin * 2)
	if heightOf(button) > available then
		button = math.floor((available - (safeCount - 1) * gap) / safeCount)
		if button < floorSize then
			button = floorSize
		end
	end
	local height = heightOf(button)
	local y = math.floor((viewportY - height) / 2)
	if y < margin then
		y = margin
	end
	if y + height > viewportY - margin then
		y = math.max(0, viewportY - margin - height)
	end
	return { x = margin, y = y, w = button, h = height, button = button }
end

-- Bottom-left of the safe area. Hidden on a phone unless debug is on.
function HudLayout.stamp(
	viewportY: number,
	margin: number,
	touch: boolean,
	debug: boolean,
	left: number?
): Rect?
	if touch and not debug then
		return nil
	end
	local height = 16
	local y = math.max(margin, viewportY - margin - height)
	local x = margin
	if type(left) == "number" and left > x then
		x = left
	end
	return rect(x, y, 140, height)
end

-- phone, tablet, console, or pc. Height breaks a short 1280-wide TV
-- out of the desktop layout.
function HudLayout.breakpoint(width: number, height: number): string
	if width < 900 or height < 500 then
		return "phone"
	end
	if width < 1280 then
		return "tablet"
	end
	if height <= 800 then
		return "console"
	end
	return "pc"
end

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return HudLayout
