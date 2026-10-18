--!strict

--[[
	Roll-tab progress stack.

	caption(label, counter, goal) prints "Legendary  28 / 1000" when the
	goal is a positive finite number. Otherwise it prints "Relic  no pity".
	It never prints " / -" or "0 / -".

	stack(kind, counters, width) includes Epic, Legendary, Relic, and
	Mythic only when that tier's goal is a positive finite number, then
	an Odds row. Rows do not overlap. Gear and pets share the geometry.
	A bad width is 280. kind is "pets" only when the caller passed "pets".

	visual(kind) is a drawn crystal. image is always "". Pets are green.
	Gear is slate. Neither fill is white.

	A third argument, including paid = true, does not change the caption,
	the stack, or the crystal. Each call reads its arguments and does not
	write them. No clock. No RNG. No services. Nothing here costs Robux.
]]

local ShardBoard = {}

local ORDER = { "Epic", "Legendary", "Relic", "Mythic" }
local BAR_H = 36
local ODDS_H = 28
local GAP = 8
local FALLBACK_W = 280

export type Row = {
	id: string,
	text: string,
	y: number,
	h: number,
	bar: boolean,
}

export type Stack = {
	kind: string,
	w: number,
	h: number,
	rows: { Row },
}

export type Visual = {
	w: number,
	h: number,
	fill: { number },
	crack: { number },
	crackH: number,
	image: string,
}

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function entry(counters: any, id: string): any
	if type(counters) ~= "table" then
		return nil
	end
	local row = counters[id]
	if row == nil then
		row = counters[string.lower(id)]
	end
	return row
end

local function goalOf(counters: any, id: string): number?
	local row = entry(counters, id)
	local goal = if type(row) == "table" then row.goal else nil
	local value = finite(goal)
	if value == nil or value <= 0 then
		return nil
	end
	return value
end

local function counterOf(counters: any, id: string): number
	local row = entry(counters, id)
	local counter = if type(row) == "table" then row.counter else nil
	local value = finite(counter)
	if value == nil then
		return 0
	end
	return math.max(0, math.floor(value))
end

function ShardBoard.caption(label: any, counter: any, goal: any, _extra: any?): string
	local name = if type(label) == "string" and label ~= "" then label else "Pity"
	local target = finite(goal)
	if target == nil or target <= 0 then
		return name .. "  no pity"
	end
	local shown = finite(counter)
	if shown == nil then
		shown = 0
	end
	return string.format("%s  %d / %d", name, math.max(0, math.floor(shown)), math.floor(target))
end

function ShardBoard.pityText(counter: any, goal: any, _extra: any?): string
	local target = finite(goal)
	if target == nil or target <= 0 then
		return "Pity"
	end
	local shown = finite(counter)
	if shown == nil then
		shown = 0
	end
	return string.format("Pity %d/%d", math.max(0, math.floor(shown)), math.floor(target))
end

-- The counter sits on the right. The lock sits just to its left.
-- Phone (280) and desktop (720) both keep the two apart.
function ShardBoard.pityPlace(width: any, counter: any, goal: any, _extra: any?)
	local span = finite(width)
	if span == nil or span < 80 then
		span = FALLBACK_W
	end
	local text = ShardBoard.pityText(counter, goal)
	local lockW = 16
	local gap = 6
	local right = 8
	local countW = math.min(span - 36, math.max(88, #text * 8))
	local countX = span - right - countW
	local lockX = countX - gap - lockW
	if lockX < 8 then
		lockX = 8
		countX = lockX + lockW + gap
		countW = math.max(48, span - right - countX)
	end
	return {
		text = text,
		lockX = lockX,
		lockW = lockW,
		lockH = 16,
		countX = countX,
		countW = countW,
		w = span,
	}
end

function ShardBoard.stack(kind: any, counters: any, width: any, _extra: any?): Stack
	local span = finite(width)
	if span == nil or span <= 0 then
		span = FALLBACK_W
	end
	local rows: { Row } = {}
	local y = 0
	for _, id in ipairs(ORDER) do
		local goal = goalOf(counters, id)
		if goal ~= nil then
			table.insert(rows, {
				id = id,
				text = ShardBoard.caption(id, counterOf(counters, id), goal),
				y = y,
				h = BAR_H,
				bar = true,
			})
			y += BAR_H + GAP
		end
	end
	table.insert(rows, {
		id = "Odds",
		text = "Odds",
		y = y,
		h = ODDS_H,
		bar = false,
	})
	return {
		kind = if kind == "pets" then "pets" else "gear",
		w = span,
		h = y + ODDS_H,
		rows = rows,
	}
end

function ShardBoard.visual(kind: any, _extra: any?): Visual
	local pets = kind == "pets"
	return {
		w = 28,
		h = 40,
		fill = if pets then { 86, 150, 112 } else { 132, 142, 156 },
		crack = { 18, 16, 22 },
		crackH = 14,
		image = "",
	}
end

return ShardBoard
