--!strict
-- The Bag detail pane compares the selected item with the one worn in the
-- same slot. Marks come from the values as shown, so 1.15 vs 1.1500001
-- reads "=", not a red minus.

local Economy = require("./Economy")
local Stats = require("./Stats")
local UpgradeScale = require("./UpgradeScale")

local BagCompare = {}

export type Row = {
	id: string,
	text: string,
	mark: string?,
	tone: string,
}

export type Detail = {
	state: string,
	header: string,
	otherUid: string?,
	other: any?,
	rows: { Row },
	power: Row,
	boost: Row?,
}

-- The uid worn in the item's slot, whether or not it is this item.
function BagCompare.equippedUid(profile: any, item: any): string?
	if type(profile) ~= "table" or type(item) ~= "table" or type(profile.equipped) ~= "table" then
		return nil
	end
	local equipped = profile.equipped
	local uid = nil
	if item.kind == "Weapon" then
		uid = equipped.weapon
	elseif item.kind == "Pet" then
		uid = equipped.pet
	elseif item.kind == "Armor" and type(item.slot) == "string" and type(equipped.armor) == "table" then
		uid = equipped.armor[item.slot]
	elseif
		item.kind == "Accessory"
		and type(item.slot) == "string"
		and type(equipped.accessories) == "table"
	then
		uid = equipped.accessories[item.slot]
	end
	if type(uid) ~= "string" or uid == "" then
		return nil
	end
	return uid
end

local function lookup(profile: any, uid: string): any?
	if type(profile.inventory) == "table" and type(profile.inventory[uid]) == "table" then
		return profile.inventory[uid]
	end
	if type(profile.pets) == "table" and type(profile.pets[uid]) == "table" then
		return profile.pets[uid]
	end
	return nil
end

-- Saved stat values. While upgradeScale is on, UpgradeScale.preview
-- boosts them by the forge upgrade, so both sides compare as they fight.
-- Off: the saved numbers, exactly as before. Nothing here writes.
function BagCompare.statMap(item: any, enabled: boolean?): { [string]: number }
	local map: { [string]: number } = {}
	if type(item) ~= "table" or type(item.stats) ~= "table" then
		return map
	end
	for _, stat in ipairs(item.stats) do
		if type(stat) == "table" and type(stat.id) == "string" and type(stat.value) == "number" then
			map[stat.id] = stat.value
		end
	end
	local preview = UpgradeScale.preview(item, enabled)
	if preview.enabled and preview.upgrade > 0 then
		for _, line in ipairs(preview.lines) do
			map[line.id] = line.value
		end
	end
	return map
end

-- "Upgrade +3  stats x1.24" while upgradeScale is on and the item has a
-- forge level. nil otherwise.
function BagCompare.boost(item: any, enabled: boolean?): Row?
	local preview = UpgradeScale.preview(item, enabled)
	if not preview.enabled or preview.upgrade <= 0 then
		return nil
	end
	return {
		id = "boost",
		text = string.format("Upgrade +%d  stats x%.2f", preview.upgrade, preview.multiplier),
		mark = nil,
		tone = "gain",
	}
end

-- The value exactly as the pane prints it.
function BagCompare.shown(id: string, value: number): string
	local definition = Stats.DEFS[id]
	if definition ~= nil and definition.unit == "percent" then
		return string.format("%.1f%%", value * 100)
	end
	if definition ~= nil and definition.decimals > 0 then
		return string.format("%." .. tostring(definition.decimals) .. "f", value)
	end
	return string.format("%d", math.floor(value + 0.5))
end

function BagCompare.format(id: string, value: number): string
	local definition = Stats.DEFS[id]
	local name = if definition ~= nil then definition.name else id
	return name .. "  " .. BagCompare.shown(id, value)
end

-- "=" when the shown values match, "+" when yours is higher, "-" when lower.
function BagCompare.mark(id: string, mine: number, theirs: number): (string, string)
	local left = BagCompare.shown(id, mine)
	local right = BagCompare.shown(id, theirs)
	if left == right then
		return "=", "same"
	end
	if mine > theirs then
		return "+", "gain"
	end
	return "-", "loss"
end

function BagCompare.detail(profile: any, item: any, powerOf: (any) -> number): Detail
	local equippedUid = BagCompare.equippedUid(profile, item)
	local other = if equippedUid ~= nil then lookup(profile, equippedUid) else nil
	local state = "empty"
	local header = "Nothing equipped in this slot."
	if equippedUid ~= nil and type(item) == "table" and equippedUid == item.uid then
		state = "equipped"
		header = "Equipped"
		other = nil
	elseif other ~= nil then
		state = "compare"
		header = "Compared with " .. tostring(other.name or "equipped") .. " (equipped)"
	end
	local mine = BagCompare.statMap(item)
	local theirs = if state == "compare" then BagCompare.statMap(other) else {}
	local ids = {}
	local marked: { [string]: boolean } = {}
	for id in pairs(mine) do
		marked[id] = true
		table.insert(ids, id)
	end
	for id in pairs(theirs) do
		if marked[id] ~= true then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local rows: { Row } = {}
	for _, id in ipairs(ids) do
		local value = mine[id] or 0
		local row: Row = { id = id, text = BagCompare.format(id, value), mark = nil, tone = "text" }
		if state == "compare" then
			local mark, tone = BagCompare.mark(id, value, theirs[id] or 0)
			row.mark = mark
			row.tone = tone
			row.text = row.text .. "  " .. mark
		end
		table.insert(rows, row)
	end
	local power = math.floor(powerOf(item) + 0.5)
	local powerRow: Row = { id = "power", text = string.format("Power  %d", power), mark = nil, tone = "text" }
	if state == "compare" then
		local theirsPower = math.floor(powerOf(other) + 0.5)
		local mark = "="
		local tone = "same"
		if power > theirsPower then
			mark, tone = "+", "gain"
		elseif power < theirsPower then
			mark, tone = "-", "loss"
		end
		powerRow.mark = mark
		powerRow.tone = tone
		powerRow.text = powerRow.text .. "  " .. mark
	end
	return {
		state = state,
		header = header,
		otherUid = if state == "compare" then equippedUid else nil,
		other = if state == "compare" then other else nil,
		rows = rows,
		power = powerRow,
		boost = BagCompare.boost(item),
	}
end

function BagCompare.level(item: any): number
	if type(item) ~= "table" then
		return 0
	end
	local level = tonumber(item.upgrade)
	if level == nil or level ~= level or level <= 0 then
		return 0
	end
	return math.floor(level)
end

-- The title shows the forge level the server already stored.
function BagCompare.title(item: any): string
	local name = if type(item) == "table" then tostring(item.name or "Item") else "Item"
	local level = BagCompare.level(item)
	local stars = if type(item) == "table" then tonumber(item.stars) else nil
	if stars ~= nil and stars == stars and stars >= 1 then
		name = name .. "  " .. string.rep("★", math.min(5, math.floor(stars)))
	end
	if level > 0 then
		return name .. "  +" .. tostring(level)
	end
	return name
end

local function grouped(amount: number): string
	local out = tostring(math.max(0, math.floor(amount)))
	while true do
		local nextOut, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		out = nextOut
		if count == 0 then
			break
		end
	end
	return out
end

-- A refusal the player can act on. Gold shortfalls name the price.
function BagCompare.refusal(reason: any, item: any): string
	local text = if type(reason) == "string" and reason ~= "" then reason else "Could not upgrade that."
	if text == "Not enough gold." then
		local cost = Economy.upgradeCost(BagCompare.level(item))
		return "Need " .. grouped(cost) .. " gold"
	end
	return text
end

function BagCompare.success(note: any, item: any): string
	if type(note) == "string" and note ~= "" then
		return "Upgraded " .. note
	end
	return "Upgraded " .. BagCompare.title(item)
end

return BagCompare
