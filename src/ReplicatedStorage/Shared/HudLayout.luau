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
HudLayout.RAIL_COUNT = 6
-- Equip and Keep start this far down the prompt frame.
HudLayout.PROMPT_LABEL = 36

export type Rect = { x: number, y: number, w: number, h: number }

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function HudLayout.portrait(margin: number): Rect
	return rect(margin, margin, 56, 56)
end

function HudLayout.health(margin: number, viewportX: number?): Rect
	local portrait = HudLayout.portrait(margin)
	local width = 220
	-- A portrait phone keeps a 108px counter column on the right.
	-- The HP bar stops 8px before that column. Wide screens stay 220.
	if
		type(viewportX) == "number"
		and viewportX == viewportX
		and viewportX > 0
		and viewportX < 500
	then
		local start = portrait.x + portrait.w + 8
		local limit = viewportX - margin - 108 - 8
		local room = math.floor(limit - start)
		if room < width then
			width = room
		end
		if width < 0 then
			width = 0
		end
	end
	return rect(portrait.x + portrait.w + 8, margin, width, 56)
end

-- Gold, Mastery, and Shards. 108px each, plus the 8px gaps.
local PILL_W = 108
local PILL_GAP = 8
local PILL_COUNT = 3

local function axisWidth(viewportX: number): number
	if type(viewportX) ~= "number" or viewportX ~= viewportX then
		return 0
	end
	if viewportX == math.huge or viewportX == -math.huge or viewportX < 0 then
		return 0
	end
	return viewportX
end

function HudLayout.pills(viewportX: number, margin: number): Rect
	local vx = axisWidth(viewportX)
	local span = PILL_COUNT * PILL_W + (PILL_COUNT - 1) * PILL_GAP
	local room = vx - margin * 2
	local function fitWidth(want: number): number
		if want > room then
			return math.max(44, math.floor(math.max(0, room)))
		end
		return want
	end
	-- Portrait phone: one column, clear of the centered toast host.
	if vx > 0 and vx < 500 then
		local width = fitWidth(PILL_W)
		local height = PILL_COUNT * 32 + (PILL_COUNT - 1) * PILL_GAP
		return rect(math.max(margin, vx - margin - width), margin, width, height)
	end
	local width = fitWidth(span)
	local x = math.max(margin, vx - margin - width)
	local y = margin + 36
	local height = 36
	local strip = rect(x, y, width, height)
	local toast = HudLayout.toast(vx, margin)
	-- Landscape phones: the 36px strip crosses the toast. Sit in the
	-- band under a 1.4 banner and on the toast's top edge.
	if toast.h > 0 and HudLayout.overlaps(strip, toast) then
		y = margin + 32
		height = toast.y - y
		if height < 0 then
			height = 0
		end
		strip = rect(x, y, width, height)
	end
	return strip
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
	local left = math.min(margin, math.max(0, viewportX))
	local right = viewportX - left
	-- Leave the counter column (108) plus an 8px gutter.
	if type(viewportX) == "number" and viewportX > 0 and viewportX < 500 then
		right = viewportX - margin - 108 - 8
	end
	if right < left then
		right = left
	end
	local room = math.max(0, right - left)
	if width > room then
		width = math.floor(room)
	end
	if width < 0 then
		width = 0
	end
	local x = math.floor((viewportX - width) / 2)
	if x < left then
		x = left
	end
	if x + width > right then
		x = math.max(left, right - width)
	end
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
	-- Icon, name, tip, Lock, and Equip. 228 keeps Lock under the tip.
	-- A short viewport scrolls; it does not squash the cell.
	local cellH = math.max(228, math.min(240, cellW + 48))
	if type(height) ~= "number" then
		cellH = 228
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
	minimum: number,
	viewportX: number?
): RailFit
	local gap = 8
	local safeCount = math.max(1, count)
	local floorSize = math.max(1, minimum)
	local button = math.max(floorSize, preferred)
	local function heightOf(size: number): number
		return safeCount * size + (safeCount - 1) * gap
	end
	local available = math.max(floorSize, viewportY - margin * 2)
	-- A short viewport cannot keep the preferred icon. Use the floor
	-- so the quest tracker still has a lane beside the rail.
	if heightOf(button) > available then
		button = floorSize
	end
	local height = heightOf(button)
	local y = math.floor((viewportY - height) / 2)
	if y < margin then
		y = margin
	end
	if y + height > viewportY - margin then
		y = math.max(0, viewportY - margin - height)
	end
	local x = margin
	local face = HudLayout.portrait(margin)
	local railRect = { x = x, y = y, w = button, h = height }
	if HudLayout.overlaps(railRect, face) then
		local below = face.y + face.h + gap
		local room = viewportY - margin - below
		if height <= room then
			y = below
		else
			x = face.x + face.w + gap
		end
	end
	-- A short landscape phone used to park that slide on the HP bar.
	if type(viewportX) == "number" and viewportX == viewportX and viewportX > 0 and viewportX < math.huge then
		local hp = HudLayout.health(margin, viewportX)
		local placed = { x = x, y = y, w = button, h = height }
		if HudLayout.overlaps(placed, hp) then
			local belowHp = hp.y + hp.h + gap
			local endY = belowHp + height
			if endY <= viewportY then
				x = margin
				y = belowHp
			end
		end
	end
	return { x = x, y = y, w = button, h = height, button = button }
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

-- The live action bar. Phone is the 2x4 cluster. Desktop is one row of 8.
function HudLayout.actionCluster(viewportX: number, viewportY: number): Rect
	local ActionSlots = require("./ActionSlots")
	local phone = HudLayout.breakpoint(viewportX, viewportY) == "phone"
	local place = ActionSlots.placement(viewportX, viewportY, phone)
	return rect(place.x, place.y, place.w, place.h)
end

function HudLayout.chipWidth(label: string): number
	local text = if type(label) == "string" then label else ""
	return math.max(UiTheme.TOUCH, #text * 8 + 20)
end

export type ChipRow = {
	chips: { Rect },
	width: number,
	height: number,
}

-- One horizontal row. A short host scrolls; the chips stay full width.
function HudLayout.filterRow(labels: { string }): ChipRow
	local gap = UiTheme.PAD
	local height = UiTheme.TOUCH
	local x = 0
	local chips: { Rect } = {}
	for _, label in ipairs(labels) do
		local width = HudLayout.chipWidth(label)
		table.insert(chips, rect(x, 0, width, height))
		x += width + gap
	end
	if x > 0 then
		x -= gap
	end
	return { chips = chips, width = x, height = height }
end

export type BagCard = {
	icon: Rect,
	name: Rect,
	tip: Rect,
	lock: Rect,
	equip: Rect,
	badge: Rect,
}

-- Parts of a hub bag card. Lock sits under the tip. Equip sits under Lock.
function HudLayout.bagCard(cellW: number, cellH: number): BagCard
	local pad = 8
	local touch = UiTheme.TOUCH
	local textW = math.max(0, cellW - pad * 2)
	return {
		icon = rect(pad, pad, 36, 36),
		name = rect(pad, 48, textW, 36),
		tip = rect(pad, 86, textW, 32),
		lock = rect(cellW - pad - touch, cellH - 56 - touch, touch, touch),
		equip = rect(pad, cellH - pad - touch, textW, touch),
		badge = rect(cellW - pad - touch, pad, touch, 22),
	}
end

export type InventoryCard = {
	name: Rect,
	marks: Rect,
}

-- Name above the marks line. The two boxes do not share a pixel.
function HudLayout.inventoryCard(cellW: number, cellH: number): InventoryCard
	local pad = 8
	local marksH = 16
	local marksY = math.max(pad, cellH - 6 - marksH)
	local nameH = math.max(UiTheme.MIN_TEXT, marksY - pad - 4)
	return {
		name = rect(pad, pad, math.max(0, cellW - pad * 2), nameH),
		marks = rect(pad, marksY, math.max(0, cellW - pad * 2), marksH),
	}
end

export type BagChrome = {
	header: Rect,
	tabs: Rect,
	filters: Rect,
	body: Rect,
}

-- Header, tabs, and filters stack. Each row stays tall enough for a 44px button.
-- The body is whatever remains and scrolls.
function HudLayout.bagChrome(width: number, height: number): BagChrome
	local pad = 8
	local innerW = math.max(0, width - pad * 2)
	local budget = height - pad * 2 - pad * 3
	if budget < 0 then
		budget = 0
	end
	local rowH = 44
	local bodyH = budget - rowH * 3
	if bodyH < 0 then
		bodyH = 0
		rowH = math.max(36, math.floor(budget / 3))
	end
	local y = pad
	local header = rect(pad, y, innerW, rowH)
	y += rowH + pad
	local tabs = rect(pad, y, innerW, rowH)
	y += rowH + pad
	local filters = rect(pad, y, innerW, rowH)
	y += rowH + pad
	local body = rect(pad, y, innerW, math.max(0, height - pad - y))
	return {
		header = header,
		tabs = tabs,
		filters = filters,
		body = body,
	}
end

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

export type Onboard = {
	card: Rect,
	continueButton: Rect,
	skip: Rect,
	tracker: Rect,
}

-- Intro card and the goal line. Both sit under the counters. A short
-- landscape phone puts the goal line beside the card so it stays above
-- the action bar. Button rects are inside the card.
function HudLayout.onboard(viewportX: number, viewportY: number): Onboard
	local margin = 16
	local gap = 8
	local vx = math.max(200, math.floor(axisWidth(viewportX)))
	local rawY = viewportY
	local vy = 720
	if type(rawY) == "number" and rawY == rawY and rawY >= 200 and rawY < math.huge then
		vy = math.floor(rawY)
	end
	local health = HudLayout.health(margin, vx)
	local pills = HudLayout.pills(vx, margin)
	local bar = HudLayout.actionCluster(vx, vy)
	local top = math.max(health.y + health.h, pills.y + pills.h) + gap
	local bottom = bar.y - gap
	local cardH = 144
	local trackH = 72
	local cardW = math.min(460, vx - margin * 2)
	local cardX = math.max(margin, math.floor((vx - cardW) / 2))
	local cardY = top
	local tracker: Rect
	if bottom - top >= cardH + gap + trackH then
		tracker = rect(cardX, cardY + cardH + gap, math.min(280, cardW), trackH)
	else
		local trackW = 168
		cardW = math.min(460, math.max(200, vx - margin * 2 - gap - trackW))
		cardX = margin + trackW + gap
		if cardX + cardW > vx - margin then
			cardW = math.max(160, vx - margin - cardX)
		end
		local room = bottom - cardY
		if room < cardH then
			cardH = math.max(120, room)
		end
		tracker = rect(margin, cardY, trackW, cardH)
	end
	local card = rect(cardX, cardY, cardW, cardH)
	local buttonH = UiTheme.TOUCH
	local buttonW = math.floor((card.w - 24 - gap) / 2)
	if buttonW > 140 then
		buttonW = 140
	end
	if buttonW < 1 then
		buttonW = 1
	end
	local buttonsW = buttonW * 2 + gap
	local buttonX = math.floor((card.w - buttonsW) / 2)
	local buttonY = card.h - 12 - buttonH
	if buttonY < 36 then
		buttonY = 36
	end
	return {
		card = card,
		continueButton = rect(buttonX, buttonY, buttonW, buttonH),
		skip = rect(buttonX + buttonW + gap, buttonY, buttonW, buttonH),
		tracker = tracker,
	}
end

return HudLayout
