--!strict
-- [Ghost] The x10 roll pace and its end-of-batch summary grid (Kevin, Oct 23).
--
--   STEP                  the most seconds one card may take inside a batch.
--   fast(plan)            a CrackReveal plan squeezed to <= STEP, same shape.
--   row(item, result, isNew)
--                         one summary tile: name, rarity, NEW / ★ up /
--                         auto-salvaged badges and a short line.
--   batch(rows, owned)    one tile per server batch row, in roll order, with
--                         exactly one outcome each (see OUTCOMES). `owned`
--                         is the templateId set from BEFORE the batch, so a
--                         dupe of gear Kevin already had is never NEW, and a
--                         repeat inside the batch chains its stars per copy.
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
RollSummary.FED = "★ fed"
RollSummary.ESSENCE = "Essence"
RollSummary.COPY = "Copy"
RollSummary.STAR_CAP = 5

-- Every tile has exactly one of these. A dupe feeds 34-100% of a star
-- (Shared/Stars), so a merge that does not finish a star is "fed".
RollSummary.OUTCOMES = table.freeze({ "new", "starUp", "fed", "essence", "copy", "salvaged" })

export type Tile = {
	name: string,
	rarity: string,
	kind: string,
	isNew: boolean,
	starUp: boolean,
	salvaged: boolean,
	outcome: string,
	stars: number?,
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

local BADGE = {
	new = RollSummary.NEW,
	starUp = RollSummary.STAR_UP,
	fed = RollSummary.FED,
	essence = RollSummary.ESSENCE,
	copy = RollSummary.COPY,
	salvaged = RollSummary.SALVAGED,
}

-- chainFrom (optional): the stars this copy already reached earlier in the
-- batch, so a repeat reads ★1 -> ★2 after ★0 -> ★1.
function RollSummary.row(item: any, result: any, isNew: any, chainFrom: number?): Tile
	local source = if type(item) == "table" then item else {}
	local info = if type(result) == "table" then result else {}
	local rarity = if type(source.rarity) == "string"
		then source.rarity
		elseif type(info.rarity) == "string" then info.rarity
		else "Common"
	local name = if type(source.name) == "string" and source.name ~= "" then source.name else "Shard"
	local kind = if type(source.kind) == "string" then source.kind else ""
	local outcome
	local stars: number? = nil
	local line = rarity
	local essence = 0
	if info.autoSalvaged == true then
		outcome = "salvaged"
		essence = whole(info.essenceGained) or 0
		line = string.format("Auto-salvaged +%d Essence", essence)
	elseif info.merged == true then
		local old = whole(info.oldLevel)
		local new = whole(info.newLevel)
		if old == nil then
			old = whole(source.stars) or 0
		end
		if chainFrom ~= nil and old < chainFrom then
			old = chainFrom
		end
		if new == nil or new < old then
			new = old
		end
		local gained = whole(info.essenceGained) or whole(info.essence) or 0
		if new > old then
			outcome = "starUp"
			line = string.format("★ %d -> ★ %d", old, new)
		elseif old >= RollSummary.STAR_CAP or gained > 0 then
			outcome = "essence"
			essence = gained
			line = string.format("★ %d · +%d Essence", old, gained)
		else
			outcome = "fed"
			line = string.format("★ %d · toward ★ %d", old, old + 1)
		end
		stars = new
	elseif isNew == true then
		outcome = "new"
	else
		outcome = "copy"
	end
	return {
		name = name,
		rarity = rarity,
		kind = kind,
		isNew = outcome == "new",
		starUp = outcome == "starUp",
		salvaged = outcome == "salvaged",
		outcome = outcome,
		stars = stars,
		essence = essence,
		badges = { BADGE[outcome] },
		line = line,
	}
end

-- rows: the server's batch.items ({ item, merged, oldLevel, newLevel,
-- essence, autoSalvaged, essenceGained }). owned: templateId -> true for
-- what the profile held before the batch (RollLoop.ownedTemplates).
function RollSummary.batch(rows: any, owned: any): { Tile }
	local out = {}
	if type(rows) ~= "table" then
		return out
	end
	local seen: { [string]: boolean } = {}
	if type(owned) == "table" then
		for id, has in pairs(owned) do
			if has == true and type(id) == "string" then
				seen[id] = true
			end
		end
	end
	local reached: { [string]: number } = {}
	for _, row in ipairs(rows) do
		local info = if type(row) == "table" then row else {}
		local item = if type(info.item) == "table" then info.item else {}
		local templateId = if type(item.templateId) == "string" and item.templateId ~= ""
			then item.templateId
			else nil
		local uid = if type(item.uid) == "string" then item.uid else nil
		local fresh = templateId ~= nil and seen[templateId] ~= true
		local chain = if uid ~= nil then reached[uid] else nil
		local tile = RollSummary.row(item, info, fresh, chain)
		if tile.stars ~= nil and uid ~= nil then
			reached[uid] = tile.stars
		end
		if tile.outcome ~= "salvaged" and templateId ~= nil then
			seen[templateId] = true
		end
		table.insert(out, tile)
	end
	return out
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

-- The counts come from the same outcome the badges show, so the header
-- always adds up to the grid.
function RollSummary.headline(tiles: { Tile }): string
	local count: { [string]: number } = {}
	local gain: { [string]: number } = {}
	for _, tile in ipairs(tiles) do
		local outcome = tile.outcome or (if tile.salvaged
			then "salvaged"
			elseif tile.starUp then "starUp"
			elseif tile.isNew then "new"
			else "copy")
		count[outcome] = (count[outcome] or 0) + 1
		gain[outcome] = (gain[outcome] or 0) + (tile.essence or 0)
	end
	local parts = {}
	local function add(key: string, text: string)
		local n = count[key] or 0
		if n > 0 then
			table.insert(parts, string.format(text, n, gain[key] or 0))
		end
	end
	add("new", "%d NEW")
	add("starUp", "%d ★ up")
	add("fed", "%d ★ fed")
	add("essence", "%d at ★5 (+%d Essence)")
	add("copy", if (count.copy or 0) > 1 then "%d copies" else "%d copy")
	add("salvaged", "%d auto-salvaged (+%d Essence)")
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
	cellH: number,
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
	-- Narrow tiles (phone portrait) grow taller so the 2-line name and the
	-- result line never sit on top of each other.
	local cellH = cell
	if cell < 84 then
		cellH = math.max(cell, math.min(cell + 36, math.floor(roomH / rows)))
	end
	local gridW = cols * cell + gap * (cols - 1)
	local gridH = rows * cellH + gap * (rows - 1)
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
		cellH = cellH,
		gap = gap,
		pad = pad,
		head = head,
		foot = foot,
		grid = { x = math.floor((w - gridW) / 2), y = pad + head, w = gridW, h = gridH },
	}
end

return table.freeze(RollSummary)
