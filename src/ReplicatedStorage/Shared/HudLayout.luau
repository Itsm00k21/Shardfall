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

-- Height of the portrait pill column when `shown` pills are visible.
function HudLayout.pillColumnHeight(shown: number?): number
	local count = math.clamp(math.floor(tonumber(shown) or PILL_COUNT), 0, PILL_COUNT)
	if count == 0 then
		return 0
	end
	return count * 32 + (count - 1) * PILL_GAP
end

-- shown is how many currency pills are visible (defaults to all of them).
-- On a portrait phone the hub's top sits under that pill column.
function HudLayout.hub(viewportX: number, viewportY: number, margin: number, shown: number?): Rect
	local w = math.floor(math.clamp(viewportX * 0.72, 280, 860))
	local h = math.floor(math.clamp(viewportY * 0.78, 220, 640))
	local x = math.floor((viewportX - w) / 2)
	local y = math.max(margin, math.floor((viewportY - h) / 2))
	local vx = axisWidth(viewportX)
	if vx > 0 and vx < 500 then
		local column = HudLayout.pillColumnHeight(shown)
		local floor = if column > 0 then margin + column + PILL_GAP else 0
		if y < floor then
			y = floor
		end
	end
	if y + h > viewportY - margin then
		h = math.max(160, viewportY - margin - y)
	end
	-- A centered portrait hub covers the rail. Park it on the rail's right.
	local rail = HudLayout.railFit(viewportY, margin, HudLayout.RAIL_COUNT, 64, 44, viewportX)
	local railRect = rect(rail.x, rail.y, rail.w, rail.h)
	if HudLayout.overlaps(rect(x, y, w, h), railRect) then
		x = rail.x + rail.w
		local limit = viewportX - margin
		if x + w > limit then
			w = math.max(44, limit - x)
		end
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

export type RailFit = { x: number, y: number, w: number, h: number, button: number, gap: number }

-- Shrinks the icon only after the preferred size no longer fits.
-- The button stays at `minimum` (44) unless a tighter gap still covers the HP bar.
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
	-- Sit under the bar, inside the 16px inset. Tighten the gap, then
	-- the button. The button stays at the 44px floor when that still fits.
	if
		type(viewportX) == "number"
		and viewportX == viewportX
		and viewportX > 0
		and viewportX < math.huge
	then
		local hp = HudLayout.health(margin, viewportX)
		local placed = { x = x, y = y, w = button, h = height }
		if HudLayout.overlaps(placed, hp) then
			local gutter = gap
			local belowHp = hp.y + hp.h + gutter
			local function stack(size: number, pad: number): number
				return safeCount * size + math.max(0, safeCount - 1) * pad
			end
			local room = viewportY - margin - belowHp
			local size = button
			local pad = gap
			if stack(size, pad) > room then
				local slots = math.max(1, safeCount - 1)
				local fitted = math.floor((room - safeCount * size) / slots)
				if fitted < 0 then
					fitted = 0
				elseif fitted > pad then
					fitted = pad
				end
				pad = fitted
			end
			if stack(size, pad) > room then
				local inner = room - math.max(0, safeCount - 1) * pad
				size = math.floor(inner / safeCount)
				if size < 1 then
					size = 1
				end
			end
			if size < floorSize and stack(floorSize, pad) <= room then
				size = floorSize
			end
			button = size
			gap = pad
			height = stack(button, gap)
			x = margin
			y = belowHp
		end
	end
	return { x = x, y = y, w = button, h = height, button = button, gap = gap }
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

-- The bag's filter scroller: a horizontal strip whose scroll bar sits under
-- the chips, so a narrow host (390 px phone) scrolls instead of clipping
-- the last chips or shaving their bottoms.
HudLayout.FILTER_BAR_GAP = 8

export type FilterBar = { height: number, canvasW: number, scrolls: boolean }

function HudLayout.filterBar(hostW: number, labels: { string }): FilterBar
	local row = HudLayout.filterRow(labels)
	local w = if type(hostW) == "number" and hostW == hostW and hostW > 0 then hostW else 0
	return {
		height = row.height + HudLayout.FILTER_BAR_GAP,
		canvasW = row.width,
		scrolls = row.width > w,
	}
end

export type BagCard = {
	icon: Rect,
	name: Rect,
	tip: Rect,
	lock: Rect,
	equip: Rect,
	badge: Rect,
	gem: Rect,
	glow: Rect,
}

HudLayout.BAG_ICON = 56

-- Parts of a hub bag card (A2 tile look): a rarity gem top-left, the icon
-- centred on a rarity glow, the name centred under it, the tip left of Lock,
-- Equip along the bottom. The glow sits behind the icon and may overlap it.
function HudLayout.bagCard(cellW: number, cellH: number): BagCard
	local pad = 8
	local touch = UiTheme.TOUCH
	local textW = math.max(0, cellW - pad * 2)
	local icon = HudLayout.BAG_ICON
	local glow = icon + 28
	return {
		icon = rect(math.floor((cellW - icon) / 2), 34, icon, icon),
		glow = rect(math.floor((cellW - glow) / 2), 20, glow, glow),
		gem = rect(pad + 2, pad + 4, 12, 12),
		name = rect(pad, 94, textW, 34),
		tip = rect(pad, 130, math.max(0, textW - touch - 4), 32),
		lock = rect(cellW - pad - touch, cellH - 56 - touch, touch, touch),
		equip = rect(pad, cellH - pad - touch, textW, touch),
		badge = rect(cellW - pad - touch, pad, touch, 22),
	}
end

-- Compact bag card (task 18, option 1): icon, name and Equip only. Used
-- while the item detail pane is open, when full cards would be cut off.
HudLayout.COMPACT_CARD_H = 120

export type CompactCard = { icon: Rect, name: Rect, equip: Rect }

function HudLayout.bagCardCompact(cellW: number, cellH: number): CompactCard
	local pad = 8
	local touch = UiTheme.TOUCH
	local w = if type(cellW) == "number" and cellW == cellW
		then math.max(touch + pad * 2, cellW)
		else 120
	local h = if type(cellH) == "number" and cellH == cellH
		then math.max(HudLayout.COMPACT_CARD_H, cellH)
		else HudLayout.COMPACT_CARD_H
	return {
		-- Name gets its own full-width line under the icon: beside a 44 px icon
		-- it only had ~49 px at 390 and broke words mid-way.
		icon = rect(pad, pad, 30, 30),
		name = rect(pad, pad + 30 + 4, math.max(0, w - pad * 2), 24),
		equip = rect(pad, h - pad - touch, math.max(0, w - pad * 2), touch),
	}
end

-- Pills, filters, the action row, and the gaps that sit above the bag cards.
function HudLayout.bagChromeAboveCards(): number
	local action = UiTheme.PAD + UiTheme.TOUCH + UiTheme.PAD
	local filters = UiTheme.TOUCH
	return UiTheme.PAD + UiTheme.TOUCH + UiTheme.GAP + filters + UiTheme.GAP + action + UiTheme.GAP
end

-- Distance from the top of the bag list to the centre of the first Equip.
function HudLayout.bagEquipCentre(listHeight: number, cellH: number): number
	local card = HudLayout.bagCard(math.max(44, cellH), cellH)
	local centre = card.equip.y + card.equip.h / 2
	if HudLayout.bagCardsLead(listHeight, cellH) then
		return UiTheme.PAD + centre
	end
	return HudLayout.bagChromeAboveCards() + centre
end

-- True when pills and the action row would push Equip's centre past the list.
function HudLayout.bagCardsLead(listHeight: number, cellH: number): boolean
	if type(listHeight) ~= "number" or listHeight ~= listHeight or listHeight <= 0 then
		return false
	end
	if type(cellH) ~= "number" or cellH ~= cellH or cellH <= 0 then
		return false
	end
	local card = HudLayout.bagCard(math.max(44, cellH), cellH)
	local centre = card.equip.y + card.equip.h / 2
	return HudLayout.bagChromeAboveCards() + centre > listHeight
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
	collapse: Rect,
	pill: Rect,
	tracker: Rect,
	goalsTab: Rect,
}

-- Intro card and the goal list (Kevin, Oct 23: smaller, off the screen
-- centre and off the character). The card sits top-left under the
-- counters, right of the mid-left rail when the two would meet. The goal
-- list sits on the right edge under the pills. A viewport too narrow for
-- both side by side stacks the goals under the card on the right.
-- collapse is the card's chevron (inside the card). pill is where the
-- collapsed card goes; goalsTab is where the collapsed goals go.
-- Button rects are inside the card.
--
-- [Ghost] Oct 24 (Kevin's clip): on a mouse screen the card sat right
-- against the Hero/Bag rail and under the toast stack. When the view is
-- not a phone and not touch, the card now drops to the lower left: right
-- of the rail, on the action bar's top band, and left of the screen
-- centre, so it never touches the rail, the toasts, the equip prompt, or
-- the character. Phones and touch screens keep the top band (the
-- thumbstick owns the lower left), still right of the rail.
function HudLayout.onboard(viewportX: number, viewportY: number, touch: boolean?): Onboard
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
	local cardH = 120
	local trackW = math.min(240, math.max(168, math.floor(vx * 0.24)))
	local trackH = 72
	local tabW = 112
	local tabH = 36
	-- Always right of the mid-left rail's column (Oct 24): the rail's
	-- hover tips open to its right, and a card above the rail still read
	-- as sitting on it.
	local railFit = HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, 64, 44, vx)
	local cardX = railFit.x + railFit.w + gap
	local cardY = top
	local sideRoom = vx - margin - trackW - gap - cardX
	local cardW = math.min(340, sideRoom)
	local tracker: Rect
	if cardW >= 220 then
		tracker = rect(vx - margin - trackW, top, trackW, trackH)
	else
		-- Narrow: the card takes the row and the goals go under it.
		cardW = math.max(160, math.min(340, vx - margin - cardX))
		trackW = math.min(trackW, vx - margin * 2)
		tracker = rect(vx - margin - trackW, cardY + cardH + gap, trackW, trackH)
	end
	local room = bottom - cardY
	if room < cardH then
		cardH = math.max(112, room)
	end
	if tracker.y + tracker.h > bottom then
		tracker = rect(tracker.x, math.max(top, bottom - tracker.h), tracker.w, tracker.h)
	end
	local lowLane = touch ~= true and HudLayout.breakpoint(vx, vy) ~= "phone"
	if lowLane then
		local lowX = railFit.x + railFit.w + gap
		local lowW = math.min(340, math.floor(vx / 2) - lowX)
		local lowH = 120
		local lowY = bar.y - gap - lowH
		if lowW >= 220 and lowY >= top then
			cardX = lowX
			cardY = lowY
			cardW = lowW
			cardH = lowH
			-- The goals keep the top-right lane under the pills.
			tracker = rect(vx - margin - trackW, top, trackW, trackH)
		end
	end
	local card = rect(cardX, cardY, cardW, cardH)
	local buttonH = UiTheme.TOUCH
	local buttonW = math.floor((card.w - 24 - gap) / 2)
	if buttonW > 132 then
		buttonW = 132
	end
	if buttonW < 1 then
		buttonW = 1
	end
	local buttonX = 12
	local buttonY = card.h - 10 - buttonH
	if buttonY < 36 then
		buttonY = 36
	end
	local chevron = 28
	return {
		card = card,
		continueButton = rect(buttonX, buttonY, buttonW, buttonH),
		skip = rect(buttonX + buttonW + gap, buttonY, buttonW, buttonH),
		collapse = rect(card.w - 8 - chevron, 6, chevron, chevron),
		pill = rect(cardX, cardY, math.min(280, cardW), tabH),
		tracker = tracker,
		goalsTab = rect(vx - margin - tabW, tracker.y, tabW, tabH),
	}
end

return HudLayout
