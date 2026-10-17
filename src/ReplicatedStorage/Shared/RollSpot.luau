--!strict

--[[
	The Gear / Pets / x10 row on the Roll tab.

	place(width) returns a band that stays inside that width. A row
	wide enough for "Gear Shards" keeps one line of three. A narrower
	row puts Gear and x10 on the first line and gives Pet Shards the
	full second line, so the pet label does not paint over its
	neighbors.

	A missing or bad width is the 140px phone band. That includes nil,
	a string, NaN, infinity, and anything under 44. A second argument,
	including paid = true, does not move the band. Each call reads its
	arguments and does not write them. No clock. No RNG. No services.
	Nothing here costs Robux.
]]

local RollSpot = {}

local GAP = 8
local BUTTON_H = 44
local MIN_WIDTH = 44
local PHONE_WIDTH = 140
local CHAR = 8
local TEXT_PAD = 16
local FULL_GEAR = 11 * CHAR + TEXT_PAD

local GEAR = "GearShards"
local PETS = "PetShards"
local TEN = "TimesTen"

local FULL: { [string]: string } = {
	[GEAR] = "Gear Shards",
	[PETS] = "Pet Shards",
	[TEN] = "x10",
}

local SHORT: { [string]: string } = {
	[GEAR] = "Gear",
	[PETS] = "Pets",
	[TEN] = "x10",
}

export type Spot = {
	id: string,
	label: string,
	x: number,
	y: number,
	w: number,
	h: number,
}

export type Band = {
	w: number,
	h: number,
	buttons: { Spot },
}

local function widthOf(value: any): number
	if type(value) ~= "number" then
		return PHONE_WIDTH
	end
	if value ~= value or value == math.huge or value == -math.huge or value < MIN_WIDTH then
		return PHONE_WIDTH
	end
	return math.floor(value)
end

local function labelFor(id: string, slotW: number): string
	local full = FULL[id]
	local short = SHORT[id]
	if type(full) == "string" and slotW >= CHAR * #full + TEXT_PAD then
		return full
	end
	if type(short) == "string" then
		return short
	end
	return "x10"
end

local function pack(width: number, count: number): ({ number }, number)
	local gap = GAP
	local gaps = count - 1
	if width < gap * gaps + count then
		gap = 0
	end
	local each = math.floor((width - gap * gaps) / count)
	if each < 1 then
		each = 1
		gap = 0
	end
	local widths = {}
	local cursor = 0
	for index = 1, count do
		local slotW = each
		if index == count then
			slotW = width - cursor
			if slotW < 1 then
				slotW = 1
			end
		end
		table.insert(widths, slotW)
		cursor += slotW + gap
	end
	return widths, gap
end

local function spot(id: string, x: number, y: number, w: number): Spot
	return {
		id = id,
		label = labelFor(id, w),
		x = x,
		y = y,
		w = w,
		h = BUTTON_H,
	}
end

function RollSpot.place(width: any, _extra: any?): Band
	local row = widthOf(width)
	local across, gap = pack(row, 3)
	if across[1] >= FULL_GEAR then
		return {
			w = row,
			h = BUTTON_H,
			buttons = {
				spot(GEAR, 0, 0, across[1]),
				spot(PETS, across[1] + gap, 0, across[2]),
				spot(TEN, across[1] + gap + across[2] + gap, 0, across[3]),
			},
		}
	end
	local pair, pairGap = pack(row, 2)
	return {
		w = row,
		h = BUTTON_H * 2 + GAP,
		buttons = {
			spot(GEAR, 0, 0, pair[1]),
			spot(PETS, 0, BUTTON_H + GAP, row),
			spot(TEN, pair[1] + pairGap, 0, pair[2]),
		},
	}
end

return RollSpot
