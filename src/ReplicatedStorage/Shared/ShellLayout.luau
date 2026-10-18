--!strict

--[[
	Desktop vs phone layout, and the sizes that keep panels on screen.

	A keyboard means desktop, even when the window is short or a trackpad
	also reports touch. Phone layout is touch with no keyboard. Panels are
	sized to the viewport. UIScale stays at 1 or above so a 44px target
	does not shrink on a short window.
]]

local ActionSlots = require("./ActionSlots")

local ShellLayout = {}

-- Zone names are stud-sized, so they shrink with distance, and they drop
-- off before the next island's label stacks on top of them. 70 studs is
-- inside one island, short of the bridge to the next one.
ShellLayout.ZONE_MAX_DISTANCE = 70
ShellLayout.ZONE_WIDTH_STUDS = 12
ShellLayout.ZONE_HEIGHT_STUDS = 2.4

-- Title uses the whole header row. Hide sits on the row under it.
ShellLayout.TITLE_ROW = 36
ShellLayout.HIDE_ROW = 44

-- Gold status line. Long enough to read, short enough that a closed panel
-- does not leave the last hint on screen.
ShellLayout.BANNER_SECONDS = 3.5

export type Box = {
	w: number,
	h: number,
}

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
}

-- Action bar sits above the bottom edge. The left reserve clears the
-- market button (16 + 64 + 8). Seven slots, 8px gaps.
ShellLayout.ACTION_H = 64
ShellLayout.ACTION_GAP = 8
ShellLayout.BAR_MARGIN = 12
ShellLayout.BAR_PAD = 8
ShellLayout.LEFT_RESERVE = 88
ShellLayout.SLOT_COUNT = 7

function ShellLayout.mobile(touchEnabled: boolean, keyboardEnabled: boolean): boolean
	return touchEnabled == true and keyboardEnabled ~= true
end

function ShellLayout.inventory(viewportX: number, viewportY: number, mobile: boolean): Box
	local margin = if mobile then 8 else 16
	local bar = ShellLayout.actionBar(viewportX, viewportY)
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local top = ShellLayout.petRect().y + ShellLayout.petRect().h + 8
	local maxW = math.max(0, loop.x - 8 - margin)
	local limitY = bar.y
	if mobile == true then
		-- The phone bag is a sheet in the safe area, above the 2x4 bar.
		-- It does not sit in the leftover strip beside the loop panel.
		maxW = math.max(0, viewportX - 32)
		top = 16
	end
	local cluster = ActionSlots.placement(viewportX, viewportY, mobile == true)
	if cluster.y < limitY then
		limitY = cluster.y
	end
	local maxH = math.max(0, limitY - 8 - top)
	local w = math.min(if mobile then maxW else 960, maxW)
	local h = math.min(if mobile then maxH else 680, maxH)
	return { w = w, h = h }
end

function ShellLayout.sidePanel(viewportX: number, viewportY: number): Box
	local margin = 12
	local thumb = 68
	local maxW = math.max(0, viewportX - margin * 2)
	local maxH = math.max(0, viewportY - margin - thumb)
	local w = math.min(360, math.floor(viewportX * 0.36))
	if w > maxW then
		w = maxW
	end
	local h = maxH
	if h > viewportY - margin * 2 then
		h = math.max(0, viewportY - margin * 2)
	end
	return { w = w, h = h }
end

function ShellLayout.thumbSize(viewportX: number): Box
	local gaps = ShellLayout.ACTION_GAP * (ShellLayout.SLOT_COUNT - 1)
	local usable = viewportX - ShellLayout.LEFT_RESERVE - ShellLayout.BAR_MARGIN - gaps
	local slot = math.floor(usable / ShellLayout.SLOT_COUNT)
	local w = math.clamp(slot, 72, 96)
	return { w = w, h = ShellLayout.ACTION_H }
end

ShellLayout.THUMBS = {
	{ id = "Attack", label = "Attack" },
	{ id = "Dodge", label = "Dodge" },
	{ id = "Skills", label = "Skills" },
	{ id = "Tonic", label = "Tonic" },
	{ id = "Inventory", label = "Items" },
	{ id = "Travel", label = "Travel" },
	{ id = "Menu", label = "Menu" },
}

function ShellLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function ShellLayout.healthRect(): Rect
	return { x = 16, y = 16, w = 220, h = 40 }
end

function ShellLayout.comboRect(): Rect
	return { x = 244, y = 16, w = 160, h = 24 }
end

function ShellLayout.petRect(): Rect
	return { x = 16, y = 60, w = 96, h = 64 }
end

function ShellLayout.raidRect(): Rect
	return { x = 120, y = 60, w = 96, h = 64 }
end

function ShellLayout.loopRect(viewportX: number, _viewportY: number): Rect
	return {
		x = viewportX - 16 - 280,
		y = 72,
		w = 280,
		h = 220,
	}
end

function ShellLayout.marketButton(_viewportX: number, viewportY: number): Rect
	return { x = 16, y = viewportY - 80, w = 64, h = 64 }
end

function ShellLayout.actionBar(viewportX: number, viewportY: number): Rect
	local slot = ShellLayout.thumbSize(viewportX)
	local gaps = ShellLayout.ACTION_GAP * (ShellLayout.SLOT_COUNT - 1)
	local barW = ShellLayout.SLOT_COUNT * slot.w + gaps
	local space = viewportX - ShellLayout.LEFT_RESERVE - ShellLayout.BAR_MARGIN
	local x = ShellLayout.LEFT_RESERVE + math.max(0, math.floor((space - barW) / 2))
	local y = viewportY - ShellLayout.BAR_MARGIN - slot.h
	return { x = x, y = y, w = barW, h = slot.h }
end

-- Screen-space rect of the live action row. The ScreenGui yields insetTop
-- and insetBottom, and the row is anchored to that GUI's bottom:
-- AnchorPoint (0.5, 1), Position (0.5, 0, 1, -BAR_MARGIN). Padding sits
-- inside the row so the 64px buttons stay on screen.
function ShellLayout.anchoredActionBar(
	viewportX: number,
	viewportY: number,
	insetTop: number,
	insetBottom: number
): Rect
	local top = if type(insetTop) == "number" then math.max(0, insetTop) else 0
	local bottomInset = if type(insetBottom) == "number" then math.max(0, insetBottom) else 0
	local guiBottom = viewportY - bottomInset
	local slot = ShellLayout.thumbSize(math.max(0, viewportX))
	local gaps = ShellLayout.ACTION_GAP * (ShellLayout.SLOT_COUNT - 1)
	local barW = ShellLayout.SLOT_COUNT * slot.w + gaps + ShellLayout.BAR_PAD * 2
	local h = slot.h + ShellLayout.BAR_PAD * 2
	local x = math.max(0, math.floor((viewportX - barW) / 2))
	local edge = guiBottom - ShellLayout.BAR_MARGIN
	local y = edge - h
	if y < top then
		h = math.max(0, edge - top)
		y = edge - h
	end
	return { x = x, y = y, w = barW, h = h }
end

function ShellLayout.debugRect(viewportX: number, viewportY: number): Rect
	local combo = ShellLayout.comboRect()
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local x = combo.x + combo.w + 8
	local w = loop.x - 8 - x
	if w > 520 then
		w = 520
	end
	if w < 64 then
		w = 64
	end
	return { x = x, y = 16, w = w, h = 64 }
end

function ShellLayout.doorRect(viewportX: number, viewportY: number): Rect
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local bar = ShellLayout.actionBar(viewportX, viewportY)
	local pet = ShellLayout.petRect()
	local w = 420
	local h = 72
	local right = loop.x - 8
	if w > right - 16 then
		w = math.max(200, right - 16)
	end
	local x = math.floor((16 + right - w) / 2)
	if x < 16 then
		x = 16
	end
	if x + w > right then
		x = math.max(16, right - w)
	end
	local y = bar.y - 8 - h
	local minY = pet.y + pet.h + 8
	if y < minY then
		y = minY
	end
	return { x = x, y = y, w = w, h = h }
end

function ShellLayout.classRect(viewportX: number, viewportY: number): Rect
	local door = ShellLayout.doorRect(viewportX, viewportY)
	local pet = ShellLayout.petRect()
	local w = math.min(360, door.w)
	local bottom = door.y - 8
	local minY = pet.y + pet.h + 8
	local y = bottom - 220
	if y < minY then
		y = minY
	end
	local h = bottom - y
	if h < 0 then
		h = 0
	end
	return { x = door.x, y = y, w = w, h = h }
end

function ShellLayout.menuRect(viewportX: number, viewportY: number): Rect
	local door = ShellLayout.doorRect(viewportX, viewportY)
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local pet = ShellLayout.petRect()
	local y = pet.y + pet.h + 16
	local bottom = door.y - 8
	local h = bottom - y
	if h < 0 then
		h = 0
	end
	local w = math.min(360, math.floor(viewportX * 0.36))
	local maxW = math.max(160, loop.x - 8 - 16)
	if w > maxW then
		w = maxW
	end
	return { x = 16, y = y, w = w, h = h }
end

-- Odds and version readout. The roll sheet draws this on the left.
function ShellLayout.oddsRect(): Rect
	return { x = 12, y = 72, w = 230, h = 250 }
end

function ShellLayout.travelRect(viewportX: number, viewportY: number): Rect
	local menu = ShellLayout.menuRect(viewportX, viewportY)
	local odds = ShellLayout.oddsRect()
	local bar = ShellLayout.actionBar(viewportX, viewportY)
	local health = ShellLayout.healthRect()
	local left = math.max(menu.x + menu.w, odds.x + odds.w) + 16
	local y = math.max(odds.y, health.y + health.h + 8)
	local bottom = bar.y - 8
	local h = math.max(0, bottom - y)
	local right = viewportX - 16
	local w = math.min(320, right - left)
	if w < 160 then
		w = math.max(120, right - left)
	end
	return { x = left, y = y, w = w, h = h }
end

function ShellLayout.captureRect(viewportX: number, viewportY: number): Rect
	local health = ShellLayout.healthRect()
	local bar = ShellLayout.actionBar(viewportX, viewportY)
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local pet = ShellLayout.petRect()
	local w = 340
	local h = 210
	local right = loop.x - 8
	if w > right - 16 then
		w = math.max(220, right - 16)
	end
	local bottom = bar.y - 8
	local y = pet.y + pet.h + 8
	if y + h > bottom then
		y = bottom - h
	end
	local minY = health.y + health.h + 8
	if y < minY then
		y = minY
	end
	if y + h > bottom then
		h = math.max(64, bottom - y)
	end
	local x = math.floor((16 + right - w) / 2)
	if x < 16 then
		x = 16
	end
	local box = { x = x, y = y, w = w, h = h }
	if ShellLayout.overlaps(box, health) then
		box.x = health.x + health.w + 8
		if box.x + box.w > right then
			box.w = math.max(64, right - box.x)
		end
	end
	return box
end

function ShellLayout.cueRect(viewportX: number, viewportY: number): Rect
	local loop = ShellLayout.loopRect(viewportX, viewportY)
	local raid = ShellLayout.raidRect()
	local x = raid.x + raid.w + 8
	local right = loop.x - 8
	local w = math.min(280, math.max(0, right - x))
	return { x = x, y = 88, w = w, h = 36 }
end

function ShellLayout.labelFits(label: string, width: number): boolean
	return #label * 8 + 10 <= width
end

function ShellLayout.zoneVisible(distance: number): boolean
	if type(distance) ~= "number" or distance ~= distance then
		return false
	end
	return distance >= 0 and distance <= ShellLayout.ZONE_MAX_DISTANCE
end

-- 1 beside the camera, about a third of that at the cutoff, 0 past it.
function ShellLayout.zoneScale(distance: number): number
	if not ShellLayout.zoneVisible(distance) then
		return 0
	end
	local span = ShellLayout.ZONE_MAX_DISTANCE
	if span <= 0 then
		return 1
	end
	local along = math.clamp(distance / span, 0, 1)
	return 1 - along * 0.65
end

-- Centered menu sheet. It stays above the action bar on a short window.
function ShellLayout.menuSheet(viewportX: number, viewportY: number): Rect
	local bar = ShellLayout.actionBar(viewportX, viewportY)
	local margin = 16
	local top = 72
	local bottom = bar.y - 12
	local w = math.min(400, math.max(160, viewportX - margin * 2))
	local h = math.min(420, math.max(0, bottom - top))
	local x = math.max(margin, math.floor((viewportX - w) / 2))
	local y = top
	if y + h > bottom then
		h = math.max(0, bottom - y)
	end
	return { x = x, y = y, w = w, h = h }
end

-- Skills sheet. Same band as the menu so the class list is not a bare header.
function ShellLayout.skillsRect(viewportX: number, viewportY: number): Rect
	local sheet = ShellLayout.menuSheet(viewportX, viewportY)
	return { x = sheet.x, y = sheet.y, w = sheet.w, h = sheet.h }
end

export type DebugGrid = {
	x: number,
	y: number,
	w: number,
	h: number,
	columns: number,
	rows: number,
	margin: number,
}

-- Debug grants wrap under the toggle. The frame's right edge stays inside
-- the safe inset by at least 8px, and the grid starts below the toggle.
function ShellLayout.debugGrid(
	viewportX: number,
	viewportY: number,
	margin: number,
	count: number,
	cellW: number,
	cellH: number,
	gap: number
): DebugGrid
	local pad = math.max(8, margin)
	local toggleH = 32
	local y = pad + toggleH + pad
	local frameW = math.max(cellW, viewportX - pad * 2)
	local usable = math.max(cellW, frameW - pad * 2 - 8)
	local stride = cellW + gap
	local columns = math.max(1, math.floor((usable + gap) / stride))
	local total = math.max(1, count)
	local rows = math.ceil(total / columns)
	local contentH = rows * cellH + math.max(0, rows - 1) * gap + pad * 2
	local maxH = math.max(cellH + pad * 2, viewportY - y - 16)
	local h = math.min(contentH, maxH)
	local x = math.max(pad, viewportX - pad - frameW)
	return {
		x = x,
		y = y,
		w = frameW,
		h = h,
		columns = columns,
		rows = rows,
		margin = pad,
	}
end

return ShellLayout
