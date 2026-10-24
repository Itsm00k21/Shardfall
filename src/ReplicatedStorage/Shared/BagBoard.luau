--!strict

--[[
	Bag sort, filter, the NEW mark, the compare line, and the salvage prompt.

	The hub draws whatever rows() returns. Equip, lock, and salvage still
	go through the server.
]]

local HudLayout = require("./HudLayout")
local InventoryView = require("./InventoryView")
local Rarities = require("./Rarities")
local UiTheme = require("./UiTheme")

local BagBoard = {}

BagBoard.RARITIES = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
BagBoard.SORTS = { "power", "rarity", "newest", "name" }

export type Filter = {
	rarity: string,
	kind: string,
	onlyNew: boolean,
	sort: string,
}

function BagBoard.defaultFilter(): Filter
	return {
		rarity = "All",
		kind = "All",
		onlyNew = false,
		sort = "power",
	}
end

function BagBoard.kindOf(item: any): string
	if type(item) ~= "table" then
		return "Item"
	end
	local kind = item.kind
	if kind == "Weapon" or kind == "Armor" or kind == "Pet" or kind == "Relic" or kind == "Accessory" then
		return kind
	end
	return "Item"
end

function BagBoard.isNew(item: any, seenAt: number): boolean
	if type(item) ~= "table" then
		return false
	end
	local at = item.obtainedAt
	if type(at) ~= "number" then
		return false
	end
	return at > seenAt
end

function BagBoard.kinds(items: { any }): { string }
	local seen: { [string]: boolean } = {}
	local list = {}
	for _, item in ipairs(items) do
		local kind = BagBoard.kindOf(item)
		if seen[kind] ~= true then
			seen[kind] = true
			table.insert(list, kind)
		end
	end
	table.sort(list)
	return list
end

local function rank(rarity: string): number
	local value = Rarities.INDEX[rarity]
	if type(value) ~= "number" then
		return 0
	end
	return value
end

local function identity(item: any): string
	if type(item) ~= "table" then
		return ""
	end
	return tostring(item.uid or item.name or "")
end

function BagBoard.rows(items: { any }, filter: Filter, seenAt: number): { any }
	local kept = {}
	for _, item in ipairs(items) do
		if type(item) == "table" then
			local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
			local rarityOk = filter.rarity == "All" or rarity == filter.rarity
			local kindOk = filter.kind == "All" or BagBoard.kindOf(item) == filter.kind
			local newOk = not filter.onlyNew or BagBoard.isNew(item, seenAt)
			if rarityOk and kindOk and newOk then
				table.insert(kept, item)
			end
		end
	end
	table.sort(kept, function(a, b)
		if filter.sort == "newest" then
			local left = if type(a.obtainedAt) == "number" then a.obtainedAt else 0
			local right = if type(b.obtainedAt) == "number" then b.obtainedAt else 0
			if left ~= right then
				return left > right
			end
		elseif filter.sort == "name" then
			local left = tostring(a.name or "")
			local right = tostring(b.name or "")
			if left ~= right then
				return left < right
			end
		elseif filter.sort == "rarity" then
			local left = rank(tostring(a.rarity or ""))
			local right = rank(tostring(b.rarity or ""))
			if left ~= right then
				return left > right
			end
		else
			local left = InventoryView.powerOf(a)
			local right = InventoryView.powerOf(b)
			if left ~= right then
				return left > right
			end
		end
		return identity(a) < identity(b)
	end)
	return kept
end

local function cycle(order: { string }, current: string): string
	local index = 1
	for cursor, name in ipairs(order) do
		if name == current then
			index = cursor
		end
	end
	return order[(index % #order) + 1]
end

function BagBoard.nextRarity(current: string): string
	return cycle(BagBoard.RARITIES, current)
end

function BagBoard.nextSort(current: string): string
	return cycle(BagBoard.SORTS, current)
end

function BagBoard.nextKind(current: string, kinds: { string }): string
	local order = { "All" }
	for _, kind in ipairs(kinds) do
		table.insert(order, kind)
	end
	return cycle(order, current)
end

local function equippedUid(profile: any, item: any): string?
	if type(profile) ~= "table" or type(profile.equipped) ~= "table" or type(item) ~= "table" then
		return nil
	end
	local equipped = profile.equipped
	if item.kind == "Weapon" and type(equipped.weapon) == "string" then
		return equipped.weapon
	end
	if item.kind == "Pet" and type(equipped.pet) == "string" then
		return equipped.pet
	end
	return nil
end

function BagBoard.summary(profile: any, item: any): string
	local worn = equippedUid(profile, item)
	if type(item) == "table" and worn ~= nil and worn == item.uid then
		return "Equipped."
	end
	local other = InventoryView.counterpart(profile, item)
	if other == nil then
		return "Nothing equipped in this slot."
	end
	local delta = InventoryView.powerOf(item) - InventoryView.powerOf(other)
	return string.format("Vs %s  power %+d", tostring(other.name or "equipped"), delta)
end

export type Tip = {
	name: string,
	rarity: string,
	lines: { string },
}

export type TipBox = {
	x: number,
	y: number,
	w: number,
	h: number,
}

function BagBoard.tip(profile: any, item: any): Tip
	local name = "Item"
	local rarity = "Common"
	if type(item) == "table" then
		if type(item.name) == "string" and item.name ~= "" then
			name = item.name
		end
		if type(item.rarity) == "string" and item.rarity ~= "" then
			rarity = item.rarity
		end
	end
	local lines = {}
	local other = InventoryView.counterpart(profile, item)
	if other ~= nil then
		for _, row in ipairs(InventoryView.compare(item, other)) do
			local text = row.name .. "  " .. row.yours
			if row.delta ~= "" and row.delta ~= "0" then
				text = text .. "  " .. row.delta
			end
			table.insert(lines, text)
		end
		local delta = InventoryView.powerOf(item) - InventoryView.powerOf(other)
		table.insert(lines, string.format("Vs %s  power %+d", tostring(other.name or "equipped"), delta))
	else
		for _, line in ipairs(InventoryView.statLines(item)) do
			table.insert(lines, line)
		end
		local worn = equippedUid(profile, item)
		if type(item) == "table" and worn ~= nil and worn == item.uid then
			table.insert(lines, "Equipped.")
		elseif type(item) == "table" then
			table.insert(lines, "Nothing equipped in this slot.")
		end
	end
	return {
		name = name,
		rarity = rarity,
		lines = lines,
	}
end

-- A hover card beside the bag cell. It stays inside an 8px screen inset.
function BagBoard.tipPlace(
	cardX: number,
	cardY: number,
	cardW: number,
	cardH: number,
	screenW: number,
	screenH: number,
	lineCount: number
): TipBox
	local function finite(value: number, fallback: number): number
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return fallback
		end
		return value
	end
	local width = finite(screenW, 390)
	local height = finite(screenH, 844)
	local count = finite(lineCount, 1)
	if count < 1 then
		count = 1
	end
	local boxW = 220
	local boxH = 28 + count * 18
	local originX = finite(cardX, 8)
	local originY = finite(cardY, 8)
	local span = finite(cardW, 0)
	local tall = finite(cardH, 0)
	local rail = HudLayout.railFit(height, 16, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, width)
	local left = rail.x + rail.w
	if left < 8 then
		left = 8
	end
	local x = originX + span + 8
	local y = originY
	if span + boxW + 16 > width then
		x = left
		y = originY + tall + 8
	elseif x + boxW > width - 8 then
		x = originX - boxW - 8
	end
	if x < left then
		x = left
	end
	if x + boxW > width - 8 then
		boxW = math.max(120, width - left - 8)
		x = left
	end
	if y + boxH > height - 8 then
		y = height - 8 - boxH
	end
	if y < 8 then
		y = 8
	end
	if y + boxH > height - 8 then
		boxH = math.max(36, height - 16)
		y = 8
	end
	return { x = x, y = y, w = boxW, h = boxH }
end

function BagBoard.confirm(rarity: string): string
	return string.format(
		"Salvage every %s weapon and armor piece that is not locked or equipped?",
		rarity
	)
end

return BagBoard
