--!strict

--[[
	Stat totals from the slot table, the stat definitions, and Elements.
	Nothing here is written onto the profile. A missing or wild config
	number contributes nothing rather than a made-up bonus.
]]

local Validate = require("./Validate")

local Totals = {}

local function finiteNonNegative(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= math.huge then
		return nil
	end
	return value
end

local function elementMult(stats: any): number
	if type(stats) ~= "table" then
		return 0
	end
	local mult = finiteNonNegative(stats.ELEMENT_MULT)
	if mult == nil then
		return 0
	end
	if mult > 1 then
		return 1
	end
	return mult
end

local function elementFlat(stats: any, statId: string): number
	if type(stats) ~= "table" or type(stats.ELEMENT_FLAT) ~= "table" then
		return 0
	end
	return finiteNonNegative(stats.ELEMENT_FLAT[statId]) or 0
end

local function baseOf(def: any): number
	return finiteNonNegative(def.base) or 0
end

-- First finite, non-negative line with this id. A second line on the
-- same piece is ignored so a corrupt row cannot double a stat.
local function rolled(item: any, statId: string): number?
	if type(item) ~= "table" or type(item.stats) ~= "table" then
		return nil
	end
	for _, stat in ipairs(item.stats) do
		if type(stat) == "table" and stat.id == statId then
			local value = finiteNonNegative(stat.value)
			if value ~= nil then
				return value
			end
		end
	end
	return nil
end

local function scales(elements: any, elementId: any, statId: string): boolean
	if type(elementId) ~= "string" or type(elements) ~= "table" or type(elements.LIST) ~= "table" then
		return false
	end
	local row = elements.LIST[elementId]
	if type(row) ~= "table" or type(row.stats) ~= "table" then
		return false
	end
	for _, scaled in ipairs(row.stats) do
		if scaled == statId then
			return true
		end
	end
	return false
end

local function gearPiece(profile: any, slot: any, itemId: string, ctx: any): any
	if type(slot) ~= "table" or slot.source == "class" or itemId == "" then
		return nil
	end
	if not Validate.holds(profile, slot, itemId, ctx) then
		return nil
	end
	if slot.source == "inventory" and type(profile.inventory) == "table" then
		return profile.inventory[itemId]
	end
	if slot.source == "pets" and type(profile.pets) == "table" then
		return profile.pets[itemId]
	end
	return nil
end

-- The piece's contribution to one stat, after its element scale. nil
-- when the piece does not have that stat and the element adds no flat.
local function contribution(item: any, statId: string, ctx: any): number?
	local value = rolled(item, statId)
	local scaled = scales(ctx.elements, item.element, statId)
	local flat = 0
	if scaled then
		flat = elementFlat(ctx.stats, statId)
	end
	if value == nil and flat <= 0 then
		return nil
	end
	local amount = value or 0
	-- +0 is ×1. The scale reads item.upgrade and only runs while the
	-- caller has upgradeScale on (ctx.gearEnabled). It is not written back.
	if value ~= nil and ctx.gearEnabled == true and type(ctx.gearConfig) == "table" then
		local scale = ctx.gearConfig.multiplier(item.upgrade, item.rarity)
		if type(scale) == "number" and scale == scale and scale >= 0 and scale <= 10 then
			amount *= scale
		end
	end
	if scaled then
		amount *= 1 + elementMult(ctx.stats)
	end
	return amount + flat
end

local function slotIdsFor(def: any, slots: any): { string }
	if type(def.from) == "table" and #def.from > 0 then
		return def.from
	end
	return slots.ORDER
end

local function textOf(def: any, value: number): string
	local decimals = finiteNonNegative(def.decimals) or 0
	decimals = math.floor(decimals)
	if decimals > 4 then
		decimals = 4
	end
	if def.unit == "percent" then
		return string.format("%." .. tostring(decimals) .. "f%%", value * 100)
	end
	if decimals <= 0 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%." .. tostring(decimals) .. "f", value)
end

local function applyCap(def: any, value: number): number
	if value < 0 then
		return 0
	end
	local cap = finiteNonNegative(def.cap)
	if cap ~= nil and value > cap then
		return cap
	end
	return value
end

function Totals.compute(profile: any, loadout: { [string]: string }, ctx: any): any
	local lines = {}
	local byId = {}
	local stats = ctx.stats
	local order = if type(stats) == "table" and type(stats.ORDER) == "table" then stats.ORDER else {}
	local defs = if type(stats) == "table" and type(stats.DEFS) == "table" then stats.DEFS else {}
	for _, statId in ipairs(order) do
		local def = defs[statId]
		if type(def) == "table" then
			local total = baseOf(def)
			local fromGear = false
			if def.stack == "replace" then
				for _, slotId in ipairs(slotIdsFor(def, ctx.slots)) do
					local slot = ctx.slots.LIST[slotId]
					local piece = gearPiece(profile, slot, loadout[slotId] or "", ctx)
					if piece ~= nil then
						local amount = contribution(piece, statId, ctx)
						if amount ~= nil then
							total = amount
							fromGear = true
							break
						end
					end
				end
			elseif def.stack == "add" then
				for _, slotId in ipairs(slotIdsFor(def, ctx.slots)) do
					local slot = ctx.slots.LIST[slotId]
					local piece = gearPiece(profile, slot, loadout[slotId] or "", ctx)
					if piece ~= nil then
						local amount = contribution(piece, statId, ctx)
						if amount ~= nil then
							total += amount
							fromGear = true
						end
					end
				end
			end
			total = applyCap(def, total)
			byId[statId] = total
			table.insert(lines, {
				id = statId,
				name = if type(def.name) == "string" then def.name else statId,
				value = total,
				unit = if type(def.unit) == "string" then def.unit else "flat",
				text = textOf(def, total),
				fromGear = fromGear,
			})
		end
	end
	return { lines = lines, byId = byId }
end

function Totals.elements(profile: any, loadout: { [string]: string }, ctx: any): { [string]: number }
	local counts = {}
	local elements = ctx.elements
	if type(elements) == "table" and type(elements.ORDER) == "table" then
		for _, elementId in ipairs(elements.ORDER) do
			counts[elementId] = 0
		end
	end
	for _, slotId in ipairs(ctx.slots.ORDER) do
		local slot = ctx.slots.LIST[slotId]
		if type(slot) == "table" and slot.countsElement == true then
			local piece = gearPiece(profile, slot, loadout[slotId] or "", ctx)
			if type(piece) == "table" and type(piece.element) == "string" and counts[piece.element] ~= nil then
				counts[piece.element] += 1
			end
		end
	end
	return counts
end

return Totals
