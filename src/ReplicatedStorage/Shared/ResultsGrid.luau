--!strict

--[[
	Clear-card loot grid (Kevin's Oct 19 clip): the "Rootvault cleared" list
	printed one text line per drop, repeated names instead of stacking, and on
	a short screen ran behind Continue. Drops now merge by name into tiles
	("x5"), laid out in at most MAX_ROWS rows that always fit the card; extra
	kinds fold into one "+N" tile. The voucher line is written once.
]]

local ResultsGrid = {}

-- Tiles are 64 px with a two-line name strip under them (Oct 23 retest:
-- one 26 px line cut "Verdant Bark" to "Verdant B…").
ResultsGrid.TILE = 64
ResultsGrid.MIN_TILE = 48
ResultsGrid.GAP = 6
ResultsGrid.MAX_ROWS = 2
ResultsGrid.LABEL_H = 36

export type Tile = { name: string, count: number, color: { number }? }

export type Layout = {
	cols: number,
	rows: number,
	tile: number,
	shown: number,
	more: number,
	height: number,
}

-- Rows from the victory payload ({ name, count } or "Name xN" strings),
-- merged by display name, order of first appearance kept.
function ResultsGrid.merge(rows: any, colorOf: ((string) -> { number }?)?): { Tile }
	local out: { Tile } = {}
	local index: { [string]: Tile } = {}
	if type(rows) ~= "table" then
		return out
	end
	for _, row in ipairs(rows) do
		local name: string? = nil
		local count = 0
		if type(row) == "table" and type(row.name) == "string" then
			name = row.name
			count = math.floor(tonumber(row.count) or 0)
		elseif type(row) == "string" then
			local n, c = string.match(row, "^%s*(.-)%s*[x:]%s*(%d+)%s*$")
			if n ~= nil and n ~= "" then
				name, count = n, tonumber(c) or 0
			else
				name, count = row, 1
			end
		end
		if name ~= nil and count > 0 then
			local tile = index[name]
			if tile == nil then
				tile = { name = name, count = 0, color = if colorOf ~= nil then colorOf(name) else nil }
				index[name] = tile
				table.insert(out, tile)
			end
			tile.count += count
		end
	end
	return out
end

function ResultsGrid.countText(count: number): string
	return string.format("x%d", count)
end

-- Fits `count` tiles into `width`: shrinks tiles toward MIN_TILE to stay
-- within MAX_ROWS, then folds what is left into one "+N" tile.
function ResultsGrid.layout(width: number, count: number): Layout
	local gap = ResultsGrid.GAP
	if count <= 0 then
		return { cols = 0, rows = 0, tile = ResultsGrid.TILE, shown = 0, more = 0, height = 0 }
	end
	local tile = ResultsGrid.TILE
	local cols = math.max(1, math.floor((width + gap) / (tile + gap)))
	while math.ceil(count / cols) > ResultsGrid.MAX_ROWS and tile > ResultsGrid.MIN_TILE do
		tile -= 2
		cols = math.max(1, math.floor((width + gap) / (tile + gap)))
	end
	local capacity = cols * ResultsGrid.MAX_ROWS
	local shown, more = count, 0
	if count > capacity then
		shown = capacity - 1
		more = count - shown
	end
	local slots = shown + (if more > 0 then 1 else 0)
	local rows = math.ceil(slots / cols)
	return {
		cols = cols,
		rows = rows,
		tile = tile,
		shown = shown,
		more = more,
		height = rows * (tile + ResultsGrid.LABEL_H) + (rows - 1) * gap,
	}
end

-- The single voucher line, or the "none" line.
function ResultsGrid.voucherLine(voucher: any): string
	if voucher == "armory" then
		return "Voucher  one free Armory crack"
	elseif voucher == "pets" then
		return "Voucher  one free Pets crack"
	end
	return "No roll voucher this clear."
end

return table.freeze(ResultsGrid)
