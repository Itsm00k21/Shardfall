--!strict
-- [Ghost] The x10 roll pace and its end-of-batch summary grid (Kevin, Oct 23).
--
--   STEP                  the most seconds one card may take inside a batch.
--   fast(plan)            a CrackReveal plan squeezed to <= STEP, same shape.
--   row(item, result, isNew)
--                         one summary tile: name, rarity, NEW / ★ up /
--                         auto-salvaged badges and a short line.
--   tiles(items, meta)    rows for the batch in roll order.
--   headline(tiles)       "x10: 2 NEW · 1 ★ up · 3 auto-salvaged (+24 Essence)".
--   layout(vx, vy, phone, count)
--                         the summary panel and its grid, fitted to the screen.
--
-- Pure: no Instances, so the specs and the Studio preview share it.

local RollSummary = {}

RollSummary.STEP = 0.3
RollSummary.SKIP = "Skip"
RollSummary.AGAIN = "Roll again"
RollSummary.CLOSE = "Close"
RollSummary.NEW = "NEW"
RollSummary.STAR_UP = "★ up"
RollSummary.SALVAGED = "Auto-salvaged"

export type Tile = {
	name: string,
	rarity: string,
	kind: string,
	isNew: boolean,
	starUp: boolean,
	salvaged: boolean,
	essence: number,
	badges: { string },
	line: string,
}

local function whole(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return math.floor(value)
end

-- Every timing field of the plan scales by the same factor, so the crack,
-- the tension and the burst keep their order and the name still shows.
function RollSummary.fast(plan: any): any
	if type(plan) ~= "table" then
		return plan
	end
	local seconds = plan.seconds
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= RollSummary.STEP then
		return plan
	end
	local k = RollSummary.STEP / seconds
	local out = table.clone(plan)
	for key, value in pairs(plan) do
		if type(value) == "number" and (key == "seconds" or string.sub(key, -3) == "End") then
			out[key] = value * k
		end
	end
	out.seconds = RollSummary.STEP
	return out
end

function RollSummary.row(item: any, result: any, isNew: any): Tile
	local source = if type(item) == "table" then item else {}
	local info = if type(result) == "table" then result else {}
	local rarity = if type(source.rarity) == "string"
		then source.rarity
		elseif type(info.rarity) == "string" then info.rarity
		else "Common"
	local name = if type(source.name) == "string" and source.name ~= "" then source.name else "Shard"
	local kind = if type(source.kind) == "string" then source.kind else ""
	local salvaged = info.autoSalvaged == true
	local old, new = whole(info.oldLevel), whole(info.newLevel)
	local starUp = info.merged == true and (old == nil or new == nil or new > old)
	local essence = whole(info.essenceGained) or whole(info.essence) or 0
	-- A salvaged drop never reached the bag, so it is not "NEW".
	local fresh = isNew == true and not starUp and not salvaged
	local badges = {}
	if fresh then
		table.insert(badges, RollSummary.NEW)
	end
	if starUp then
		table.insert(badges, RollSummary.STAR_UP)
	end
	if salvaged then
		table.insert(badges, RollSummary.SALVAGED)
	end
	local line = rarity
	if salvaged then
		line = string.format("Auto-salvaged +%d Essence", whole(info.essenceGained) or 0)
	elseif starUp and old ~= nil and new ~= nil then
		line = string.format("★ %d -> ★ %d", old, new)
	end
	return {
		name = name,
		rarity = rarity,
		kind = kind,
		isNew = fresh,
		starUp = starUp,
		salvaged = salvaged,
		essence = if salvaged then whole(info.essenceGained) or 0 else essence,
		badges = badges,
		line = line,
	}
end

-- meta maps an item table to the tile built when it landed. Items with no
-- entry still get a plain tile, so the grid never has a hole.
function RollSummary.tiles(items: any, meta: any): { Tile }
	local out = {}
	if type(items) ~= "table" then
		return out
	end
	for _, item in ipairs(items) do
		local known = if type(meta) == "table" then meta[item] else nil
		if type(known) == "table" then
			table.insert(out, known)
		else
			table.insert(out, RollSummary.row(item, nil, false))
		end
	end
	return out
end

function RollSummary.headline(tiles: { Tile }): string
	local fresh, ups, gone, gain = 0, 0, 0, 0
	for _, tile in ipairs(tiles) do
		if tile.isNew then
			fresh += 1
		end
		if tile.starUp then
			ups += 1
		end
		if tile.salvaged then
			gone += 1
			gain += tile.essence
		end
	end
	local parts = {}
	if fresh > 0 then
		table.insert(parts, string.format("%d NEW", fresh))
	end
	if ups > 0 then
		table.insert(parts, string.format("%d ★ up", ups))
	end
	if gone > 0 then
		table.insert(parts, string.format("%d auto-salvaged (+%d Essence)", gone, gain))
	end
	local head = string.format("x%d results", #tiles)
	if #parts == 0 then
		return head
	end
	return head .. ": " .. table.concat(parts, " · ")
end

export type Rect = { x: number, y: number, w: number, h: number }
export type Layout = {
	panel: Rect,
	cols: number,
	rows: number,
	cell: number,
	gap: number,
	pad: number,
	head: number,
	foot: number,
	grid: Rect,
}

RollSummary.PAD = 12
RollSummary.GAP = 8
RollSummary.HEAD = 44
RollSummary.FOOT = 52
RollSummary.MAX_CELL = 104
RollSummary.MIN_CELL = 56
RollSummary.MIN_W = 300

function RollSummary.layout(vx: number, vy: number, phone: boolean?, count: number?): Layout
	local n = math.max(1, math.floor(count or 10))
	local margin = if phone then 8 else 24
	local pad, gap = RollSummary.PAD, RollSummary.GAP
	local head, foot = RollSummary.HEAD, RollSummary.FOOT
	local maxW = math.max(RollSummary.MIN_W, vx - margin * 2)
	local cols = math.min(5, n)
	local cell = math.floor((math.min(maxW, 640) - pad * 2 - gap * (cols - 1)) / cols)
	if cell < RollSummary.MIN_CELL and cols > 4 and n > 4 then
		cols = 4
		cell = math.floor((math.min(maxW, 640) - pad * 2 - gap * (cols - 1)) / cols)
	end
	cell = math.min(cell, RollSummary.MAX_CELL)
	local rows = math.ceil(n / cols)
	local roomH = vy - margin * 2 - pad * 2 - head - foot - gap * (rows - 1)
	if rows * cell > roomH then
		cell = math.max(40, math.floor(roomH / rows))
	end
	local gridW = cols * cell + gap * (cols - 1)
	local gridH = rows * cell + gap * (rows - 1)
	local w = math.max(RollSummary.MIN_W, gridW + pad * 2)
	w = math.min(w, math.max(gridW + pad * 2, maxW))
	local h = pad + head + gridH + foot + pad
	local x = math.floor((vx - w) / 2)
	local y = math.max(margin, math.floor((vy - h) / 2))
	return {
		panel = { x = x, y = y, w = w, h = h },
		cols = cols,
		rows = rows,
		cell = cell,
		gap = gap,
		pad = pad,
		head = head,
		foot = foot,
		grid = { x = math.floor((w - gridW) / 2), y = pad + head, w = gridW, h = gridH },
	}
end

return table.freeze(RollSummary)
