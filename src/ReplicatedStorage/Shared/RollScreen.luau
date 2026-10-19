--!strict

--[[
	Roll screen layout and labels (Kevin's Oct 19 build, screens A and D).

	A (desktop): the meters sit above one CTA row. CRACK x1 is the wide
	primary button with its shard cost; x10 (with a -10% tag) and AUTO
	are its siblings. The odds panel's Details button opens the full odds.

	D (phone, page width <= RollConfig.PHONE_PAGE_W): the CTA stack is
	pinned to the bottom thumb zone. CRACK is full width, and under it is
	a row of x10, AUTO and ODDS. The meters stack on two lines above it.

	layout(pageW, pageH) returns rects in page coordinates. Pure: no
	clock, no RNG, no services. Every number comes from RollConfig.
	Nothing here costs Robux.
]]

local RarityConfig = require("./RarityConfig")
local RollConfig = require("./RollConfig")

local RollScreen = {}

RollScreen.CRACK_LABEL = "CRACK x1" -- same copy as HubStyle.CRACK_ONE
RollScreen.TEN_LABEL = "x10"
RollScreen.AUTO_LABEL = "AUTO"
RollScreen.AUTO_ON_LABEL = "AUTO ON"
RollScreen.ODDS_LABEL = "ODDS"
RollScreen.DETAILS_LABEL = "Details"

export type Rect = { x: number, y: number, w: number, h: number }

export type Layout = {
	phone: boolean,
	crack: Rect,
	ten: Rect,
	auto: Rect,
	odds: Rect?,
	meter: Rect,
	luck: Rect,
	pity: Rect,
	reserved: number,
}

local function size(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	if value < 80 then
		return fallback
	end
	return math.floor(value)
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = math.max(1, w), h = math.max(1, h) }
end

-- Splits `w` into `count` widths with RollConfig.GAP between them; the
-- last one takes the rounding so the row ends exactly at `w`.
local function split(w: number, count: number): { number }
	local gap = RollConfig.GAP
	local each = math.floor((w - gap * (count - 1)) / count)
	local out = {}
	local used = 0
	for index = 1, count do
		local slot = if index == count then w - used else each
		table.insert(out, slot)
		used += slot + gap
	end
	return out
end

function RollScreen.isPhone(pageW: any): boolean
	return size(pageW, 280) <= RollConfig.PHONE_PAGE_W
end

function RollScreen.layout(pageW: any, pageH: any): Layout
	local width = size(pageW, 280)
	local height = size(pageH, 320)
	local edge = RollConfig.EDGE
	local gap = RollConfig.GAP
	local inner = width - edge * 2
	local phone = width <= RollConfig.PHONE_PAGE_W
	if phone then
		local rowH = RollConfig.PHONE_ROW_H
		local rowY = height - edge - rowH
		local crackH = RollConfig.PHONE_CRACK_H
		local crackY = rowY - gap - crackH
		local meterH = RollConfig.METER_H * 2 + 4
		local meterY = crackY - 6 - meterH
		local slots = split(inner, 3)
		local x2 = edge + slots[1] + gap
		local x3 = x2 + slots[2] + gap
		return {
			phone = true,
			crack = rect(edge, crackY, inner, crackH),
			ten = rect(edge, rowY, slots[1], rowH),
			auto = rect(x2, rowY, slots[2], rowH),
			odds = rect(x3, rowY, slots[3], rowH),
			meter = rect(edge, meterY, inner, meterH),
			luck = rect(0, 0, inner, RollConfig.METER_H),
			pity = rect(0, RollConfig.METER_H + 4, inner, RollConfig.METER_H),
			reserved = height - meterY,
		}
	end
	local ctaH = RollConfig.CTA_H
	local ctaY = height - edge - ctaH
	local crackW = math.floor(inner * RollConfig.CRACK_SHARE)
	local tenW = math.floor(inner * RollConfig.TEN_SHARE)
	local autoW = inner - crackW - tenW - gap * 2
	local meterH = RollConfig.METER_H
	local meterY = ctaY - 6 - meterH
	local half = math.floor((inner - gap) / 2)
	return {
		phone = false,
		crack = rect(edge, ctaY, crackW, ctaH),
		ten = rect(edge + crackW + gap, ctaY, tenW, ctaH),
		auto = rect(edge + crackW + gap + tenW + gap, ctaY, autoW, ctaH),
		odds = nil,
		meter = rect(edge, meterY, inner, meterH),
		luck = rect(0, 0, half, meterH),
		pity = rect(half + gap, 0, inner - half - gap, meterH),
		reserved = height - meterY,
	}
end

-- Cost chip text for a press of `count` cracks.
function RollScreen.costText(count: any): string
	return tostring(RollConfig.cost(count))
end

function RollScreen.autoLabel(on: any): string
	return if on == true then RollScreen.AUTO_ON_LABEL else RollScreen.AUTO_LABEL
end

-- The tenth-crack x2 luck meter: lit pips out of BONUS_EVERY and its line.
function RollScreen.luckPips(shardRolls: any): (number, string)
	local rolls = 0
	if type(shardRolls) == "number" and shardRolls == shardRolls and shardRolls > 0 and shardRolls < math.huge then
		rolls = math.floor(shardRolls)
	end
	local lit = rolls % RarityConfig.BONUS_EVERY
	return lit, RarityConfig.bonusLabel(rolls)
end

return RollScreen
