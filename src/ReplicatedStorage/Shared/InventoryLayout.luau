--!strict

--[[
	[Ghost] Geometry for the one full Inventory (Phase 3).

	modal(vx, vy, opts) centers the window in the space the HUD leaves:
	right of the left rail, under the HP card, with a max size so it does
	not sprawl on a big monitor. On a phone it is a sheet with a small
	safe margin.

	chrome(w, h, phone) stacks header, tabs, one filter row, the thin
	action bar, and the body. When the window is short the tabs move
	into the header row so the grid keeps at least two card rows.

	grid(gridW, phone, gridH) picks 4 to 6 columns (3 to 6 on a phone)
	from the width and returns square-ish cells, small enough for two
	rows in gridH. card(cellW, cellH) places the
	centered icon, the name, the +level line, and the badges.

	Pure: no Instances. Specs cover it under Lune.
]]

local InventoryLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }

InventoryLayout.MAX_W = 1180
InventoryLayout.MAX_H = 680
InventoryLayout.MIN_W = 560
InventoryLayout.WIDTH_SHARE = 0.88
InventoryLayout.RAIL_GAP = 12
InventoryLayout.TOP = 132
InventoryLayout.MARGIN = 16
InventoryLayout.BOTTOM = 8
InventoryLayout.PHONE_MARGIN = 8
InventoryLayout.PAD = 10
InventoryLayout.GAP = 6
InventoryLayout.ROW_H = 36
InventoryLayout.PHONE_ROW_H = 40
InventoryLayout.ACTION_H = 40
InventoryLayout.CELL_GAP = 8
InventoryLayout.SCROLL_W = 8
InventoryLayout.MIN_CELL = 118
InventoryLayout.PHONE_MIN_CELL = 96
InventoryLayout.DETAIL_MIN = 270
InventoryLayout.DETAIL_MAX = 340
InventoryLayout.COMPACT_H = 560

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

export type ModalOpts = {
	phone: boolean?,
	railRight: number?,
	top: number?,
}

function InventoryLayout.modal(vx: number, vy: number, opts: ModalOpts?): Rect
	local o: ModalOpts = opts or {}
	if o.phone == true then
		local m = InventoryLayout.PHONE_MARGIN
		return rect(m, m, vx - m * 2, vy - m * 2)
	end
	local railRight = if type(o.railRight) == "number" then o.railRight else 80
	local left = math.max(InventoryLayout.MARGIN, railRight + InventoryLayout.RAIL_GAP)
	local top = if type(o.top) == "number" then o.top else InventoryLayout.TOP
	local availW = math.max(0, vx - left - InventoryLayout.MARGIN)
	local availH = math.max(0, vy - top - InventoryLayout.BOTTOM)
	local want = math.max(InventoryLayout.MIN_W, math.floor(vx * InventoryLayout.WIDTH_SHARE))
	local w = math.min(availW, want, InventoryLayout.MAX_W)
	local h = math.min(availH, InventoryLayout.MAX_H)
	local x = left + math.floor((availW - w) / 2)
	return rect(x, top, w, h)
end

export type Chrome = {
	header: Rect,
	tabs: Rect,
	filters: Rect,
	actions: Rect,
	body: Rect,
	compact: boolean,
	rowH: number,
}

-- actions=false drops the action bar row (gear salvage off).
function InventoryLayout.chrome(w: number, h: number, phone: boolean?, actions: boolean?): Chrome
	local pad = InventoryLayout.PAD
	local gap = InventoryLayout.GAP
	local rowH = if phone == true then InventoryLayout.PHONE_ROW_H else InventoryLayout.ROW_H
	local innerW = math.max(0, w - pad * 2)
	local compact = h < InventoryLayout.COMPACT_H
	local y = pad
	local header = rect(pad, y, innerW, rowH)
	y += rowH + gap
	local tabs: Rect
	if compact then
		-- Tabs share the header row: the title on the left, buttons right.
		tabs = rect(pad + 150, pad, math.max(0, innerW - 150 - 230), rowH)
	else
		tabs = rect(pad, y, innerW, rowH)
		y += rowH + gap
	end
	local filters = rect(pad, y, innerW, rowH)
	y += rowH + gap
	local actionRect = rect(pad, y, innerW, 0)
	if actions ~= false then
		actionRect = rect(pad, y, innerW, InventoryLayout.ACTION_H)
		y += InventoryLayout.ACTION_H + gap
	end
	local body = rect(pad, y, innerW, h - y - pad)
	return {
		header = header,
		tabs = tabs,
		filters = filters,
		actions = actionRect,
		body = body,
		compact = compact,
		rowH = rowH,
	}
end

function InventoryLayout.detailW(bodyW: number, phone: boolean?): number
	if phone == true then
		return bodyW
	end
	local want = math.floor(bodyW * 0.3)
	return math.clamp(want, InventoryLayout.DETAIL_MIN, InventoryLayout.DETAIL_MAX)
end

export type Grid = { cols: number, cellW: number, cellH: number, gap: number }

-- gridH (optional): the grid height, so a short window still shows two
-- rows of cards (cells shrink, more columns fit).
function InventoryLayout.grid(gridW: number, phone: boolean?, gridH: number?): Grid
	local gap = InventoryLayout.CELL_GAP
	local usable = math.max(0, gridW - InventoryLayout.SCROLL_W)
	local minCell = if phone == true then InventoryLayout.PHONE_MIN_CELL else InventoryLayout.MIN_CELL
	local lo = if phone == true then 3 else 4
	local hi = 6
	local fit = math.floor((usable + gap) / (minCell + gap))
	local cols = math.clamp(fit, lo, hi)
	local cellW = math.max(60, math.floor((usable - (cols - 1) * gap) / cols))
	-- Never wider than ~1.35x the minimum: big windows get more columns,
	-- not giant cards.
	cellW = math.min(cellW, math.floor(minCell * 1.35))
	if type(gridH) == "number" and gridH > 0 then
		local twoRows = math.floor((gridH - gap) / 2)
		if twoRows < cellW then
			cellW = math.max(72, twoRows)
			cols = math.clamp(math.floor((usable + gap) / (cellW + gap)), lo, hi)
		end
	end
	local cellH = cellW
	return { cols = cols, cellW = cellW, cellH = cellH, gap = gap }
end

export type Card = {
	art: Rect,
	name: Rect,
	level: Rect,
	marks: Rect,
	badge: Rect,
	lock: Rect,
}

function InventoryLayout.card(cellW: number, cellH: number): Card
	local pad = 6
	local marksH = 14
	local levelH = 15
	local nameH = 30
	local marksY = cellH - pad - marksH
	local levelY = marksY - levelH
	local nameY = levelY - nameH
	local artH = math.max(20, nameY - pad - 2)
	local artS = math.min(artH, cellW - pad * 2)
	local innerW = cellW - pad * 2
	return {
		art = rect(math.floor((cellW - artS) / 2), pad + math.floor((artH - artS) / 2), artS, artS),
		name = rect(pad, nameY, innerW, nameH),
		level = rect(pad, levelY, innerW, levelH),
		marks = rect(pad, marksY, innerW, marksH),
		badge = rect(4, 4, 20, 20),
		lock = rect(cellW - 4 - 22, 4, 22, 22),
	}
end

return InventoryLayout
