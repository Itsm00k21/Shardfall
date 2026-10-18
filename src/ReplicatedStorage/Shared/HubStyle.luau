--!strict

--[[
	Hub structure from docs/design/mockups.

	Roll is a pedestal beside odds, with x1 and x10 on the crack row.
	Bag is pills, a grid, a detail pane, and eight slots.
	Pets is a list beside a detail pane.

	The mockups draw a blue gem. That is not a currency here.
	There is no x100 button. paid does not move a rect or change a
	cost. Nothing here costs Robux.
]]

local Economy = require("./Economy")
local InventoryView = require("./InventoryView")

local HubStyle = {}

HubStyle.CLOSE = "CLOSE"
HubStyle.EQUIP = "EQUIP"
HubStyle.CRACK_ONE = "CRACK x1"
HubStyle.CRACK_TEN = "CRACK x10"
HubStyle.CRACK_PET = "CRACK PET SHARD"
HubStyle.CURRENCIES = { "Gold", "Shards", "Keys", "Mastery" }

local PILLS = {
	{ id = "All", label = "All", icon = "bag" },
	{ id = "Weapons", label = "Weapons", icon = "attack" },
	{ id = "Armor", label = "Armor", icon = "class" },
	{ id = "Relics", label = "Relics", icon = "ult" },
	{ id = "Pets", label = "Pets", icon = "pet" },
}

local CHIP = { "equip", "claim", "close", "button" }

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
}

export type Spot = {
	id: string,
	label: string,
	x: number,
	y: number,
	w: number,
	h: number,
}

local function span(value: any, fallback: number, minimum: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	local whole = math.floor(value)
	if whole < minimum then
		return fallback
	end
	return whole
end

local function grouped(amount: number): string
	local text = tostring(math.max(0, math.floor(amount)))
	local out = text
	while true do
		local nextOut, count = string.gsub(out, "^(%d+)(%d%d%d)", "%1,%2")
		out = nextOut
		if count == 0 then
			break
		end
	end
	return out
end

function HubStyle.pills(): { { id: string, label: string, icon: string } }
	local copy = {}
	for _, pill in ipairs(PILLS) do
		table.insert(copy, { id = pill.id, label = pill.label, icon = pill.icon })
	end
	return copy
end

function HubStyle.chipTone(index: number): string
	local slot = math.floor(index)
	if slot ~= slot or slot < 1 then
		slot = 1
	end
	local at = ((slot - 1) % #CHIP) + 1
	return CHIP[at]
end

function HubStyle.inPill(item: any, pill: any): boolean
	if pill == nil or pill == "All" then
		return true
	end
	if type(item) ~= "table" then
		return false
	end
	local kind = if type(item.kind) == "string" then item.kind else ""
	local slot = if type(item.slot) == "string" then item.slot else ""
	if pill == "Weapons" then
		return kind == "Weapon" or item.weaponType ~= nil
	end
	if pill == "Armor" then
		return kind == "Armor"
			or slot == "helm"
			or slot == "chest"
			or slot == "legs"
			or slot == "boots"
	end
	if pill == "Relics" then
		return kind == "Relic" or item.relic == true
	end
	if pill == "Pets" then
		return kind == "Pet" or type(item.species) == "string"
	end
	return false
end

function HubStyle.capacityLine(profile: any, _extra: any?): string
	local used = 0
	local cap = 100
	if type(profile) == "table" then
		if type(profile.inventory) == "table" then
			for _ in pairs(profile.inventory) do
				used += 1
			end
		end
		if type(profile.pets) == "table" then
			for _ in pairs(profile.pets) do
				used += 1
			end
		end
		if
			type(profile.inventoryCap) == "number"
			and profile.inventoryCap == profile.inventoryCap
			and profile.inventoryCap >= 1
			and profile.inventoryCap < math.huge
		then
			cap = math.floor(profile.inventoryCap)
		end
	end
	return string.format("Capacity: %d/%d", used, cap)
end

local function gearBucket(item: any): string?
	if type(item) ~= "table" then
		return nil
	end
	if item.kind == "Weapon" then
		return "weapon"
	end
	if item.kind == "Armor" and type(item.slot) == "string" and item.slot ~= "" then
		return "armor:" .. item.slot
	end
	if item.kind == "Accessory" and type(item.slot) == "string" and item.slot ~= "" then
		return "accessory:" .. item.slot
	end
	return nil
end

local function wornUid(profile: any, bucket: string): string?
	if type(profile) ~= "table" or type(profile.equipped) ~= "table" then
		return nil
	end
	local equipped = profile.equipped
	if bucket == "weapon" then
		if type(equipped.weapon) == "string" then
			return equipped.weapon
		end
		return nil
	end
	local kind, slot = string.match(bucket, "^(%a+):(.+)$")
	if kind == "armor" and type(equipped.armor) == "table" and type(slot) == "string" then
		local uid = equipped.armor[slot]
		if type(uid) == "string" then
			return uid
		end
	end
	if kind == "accessory" and type(equipped.accessories) == "table" and type(slot) == "string" then
		local uid = equipped.accessories[slot]
		if type(uid) == "string" then
			return uid
		end
	end
	return nil
end

function HubStyle.bestGear(profile: any, _extra: any?): { string }
	local picks = {}
	if type(profile) ~= "table" or type(profile.inventory) ~= "table" then
		return picks
	end
	local best: { [string]: any } = {}
	for _, item in pairs(profile.inventory) do
		local bucket = gearBucket(item)
		if bucket ~= nil and type(item) == "table" and type(item.uid) == "string" and item.uid ~= "" then
			local current = best[bucket]
			if current == nil or InventoryView.powerOf(item) > InventoryView.powerOf(current) then
				best[bucket] = item
			end
		end
	end
	local keys = {}
	for bucket in pairs(best) do
		table.insert(keys, bucket)
	end
	table.sort(keys)
	for _, bucket in ipairs(keys) do
		local item = best[bucket]
		if wornUid(profile, bucket) ~= item.uid then
			table.insert(picks, item.uid)
		end
	end
	return picks
end

function HubStyle.shardCount(tokens: any): string
	local count = 0
	if type(tokens) == "number" and tokens == tokens and tokens > 0 and tokens < math.huge then
		count = math.floor(tokens)
	end
	return "Shards  " .. tostring(count)
end

function HubStyle.upgradeLabel(level: any): string
	local whole = 0
	if type(level) == "number" and level == level and level > 0 and level < math.huge then
		whole = math.floor(level)
	end
	if whole >= Economy.UPGRADE_MAX then
		return "UPGRADE  Max"
	end
	local gold = Economy.upgradeCost(whole)
	return "UPGRADE  " .. grouped(gold)
end

function HubStyle.barScale(chance: any): number
	if type(chance) ~= "number" or chance ~= chance or chance <= 0 then
		return 0.04
	end
	if chance > 1 then
		return 1
	end
	if chance < 0.04 then
		return 0.04
	end
	return chance
end

function HubStyle.petPerk(pet: any): string
	if type(pet) ~= "table" then
		return "Companion"
	end
	if type(pet.ability) == "string" and pet.ability ~= "" then
		return pet.ability
	end
	if type(pet.role) == "string" and pet.role ~= "" then
		return pet.role
	end
	return "Companion"
end

function HubStyle.petStats(pet: any): { { label: string, value: string } }
	local rows = {}
	if type(pet) ~= "table" then
		return rows
	end
	local function add(label: string, value: any)
		if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
			table.insert(rows, { label = label, value = tostring(math.floor(value)) })
		elseif type(value) == "string" and value ~= "" then
			table.insert(rows, { label = label, value = value })
		end
	end
	add("Level", pet.level)
	add("Bond", pet.bond)
	add("Affinity", pet.affinity)
	add("Role", pet.role)
	return rows
end

function HubStyle.rollStage(width: any, height: any, _extra: any?)
	local w = span(width, 280, 44)
	local h = span(height, 320, 180)
	local gap = 8
	local rowH = 44
	local rowY = h - rowH
	local bodyH = rowY - gap
	if bodyH < 44 then
		bodyH = 44
	end
	local left = math.floor(w * 0.42)
	if left < 72 then
		left = math.floor(w * 0.5)
	end
	if left > w - 88 then
		left = math.max(44, w - 88)
	end
	local oddsX = left + gap
	local oddsW = w - oddsX
	if oddsW < 40 then
		oddsX = left
		oddsW = w - left
	end
	local countW = math.floor(w * 0.18)
	if countW < 64 then
		countW = 64
	end
	if countW > w * 0.3 then
		countW = math.floor(w * 0.3)
	end
	local names = {
		{ id = "Roll", label = HubStyle.CRACK_ONE },
		{ id = "TimesTen", label = HubStyle.CRACK_TEN },
		{ id = "Auto", label = "Auto" },
		{ id = "Info", label = "Info" },
	}
	local room = w - countW - gap
	local each = math.floor((room - gap * (#names - 1)) / #names)
	if each < 1 then
		each = 1
	end
	local buttons = {}
	local cursor = countW + gap
	for index, spot in ipairs(names) do
		local slot = each
		if index == #names then
			slot = w - cursor
		end
		if cursor >= w then
			cursor = math.max(0, w - 1)
			slot = 1
		elseif slot < 1 then
			slot = 1
		end
		if cursor + slot > w then
			slot = w - cursor
		end
		table.insert(buttons, {
			id = spot.id,
			label = spot.label,
			x = cursor,
			y = 0,
			w = slot,
			h = rowH,
		})
		cursor += slot + gap
	end
	return {
		w = w,
		h = h,
		pedestal = { x = 0, y = 0, w = left, h = bodyH },
		odds = { x = oddsX, y = 0, w = oddsW, h = bodyH },
		row = { x = 0, y = rowY, w = w, h = rowH },
		count = { x = 0, y = 0, w = countW, h = rowH },
		buttons = buttons,
	}
end

function HubStyle.bagStage(width: any, height: any, _extra: any?)
	local w = span(width, 280, 44)
	local h = span(height, 420, 200)
	local pillH = 44
	local loadH = 52
	local gap = 8
	local loadout = { x = 0, y = h - loadH, w = w, h = loadH }
	local splitY = pillH + gap
	local splitH = loadout.y - gap - splitY
	if splitH < 80 then
		splitH = 80
	end
	local side = w >= 640
	local gridW = if side then math.floor(w * 0.58) else w
	local detailX = if side then gridW + gap else 0
	local detailW = if side then w - detailX else w
	local gridH = if side then splitH else math.floor(splitH * 0.55)
	local detailY = if side then splitY else splitY + gridH + gap
	local detailH = if side then splitH else math.max(40, splitH - gridH - gap)
	return {
		w = w,
		h = h,
		pills = { x = 0, y = 0, w = w, h = pillH },
		grid = { x = 0, y = splitY, w = gridW, h = gridH },
		detail = { x = detailX, y = detailY, w = detailW, h = detailH },
		loadout = loadout,
		slots = 8,
	}
end

function HubStyle.petStage(width: any, height: any, _extra: any?)
	local w = span(width, 280, 44)
	local h = span(height, 360, 180)
	local gap = 8
	local side = w >= 520
	local listW = if side then math.floor(w * 0.42) else w
	local detailX = if side then listW + gap else 0
	local detailW = if side then w - detailX else w
	local listH = if side then h else math.floor(h * 0.45)
	local detailY = if side then 0 else listH + gap
	local detailH = if side then h else math.max(40, h - detailY)
	return {
		w = w,
		h = h,
		list = { x = 0, y = 0, w = listW, h = listH },
		detail = { x = detailX, y = detailY, w = detailW, h = detailH },
	}
end

return HubStyle
