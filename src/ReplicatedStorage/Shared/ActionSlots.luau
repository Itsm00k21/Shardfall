--!strict

--[[
	The eight-slot action bar.

	Slots hold a class skill, the Healing Tonic, or an owned item. The
	server accepts a layout only when every filled slot is one of those and
	none is repeated. Keys are 1 through 8. Shift stays dodge and F stays
	interact; neither is a slot.

	On a controller the D-pad fires slots 1-4. Holding ButtonL1 fires slots 5-8.

	Skill unlocks follow the class list: levels 1, 2, 4, 6, then 10 for the
	ultimate. A locked skill can sit on the bar. Using it is refused.
]]

local Classes = require("./Classes")
local Materials = require("./Materials")
local UiTheme = require("./UiTheme")

local ActionSlots = {}

ActionSlots.COUNT = 8
ActionSlots.TONIC_COOLDOWN = 8
ActionSlots.PADLOCK = "\u{1F512}"
ActionSlots.UNLOCK = { 1, 2, 4, 6, 10 }
ActionSlots.KEYS = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" }

local LABELS = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
}

export type Slot = {
	kind: string,
	id: string,
}

export type Bar = {
	locked: boolean,
	slots: { Slot },
}

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
}

export type Place = {
	x: number,
	y: number,
	w: number,
	h: number,
	slot: number,
	gap: number,
	columns: number,
	rows: number,
	mobile: boolean,
}

local function emptySlot(): Slot
	return { kind = "empty", id = "" }
end

local function listed(classId: string, skillId: string): (Classes.Skill?, number)
	local classDef = Classes.get(classId)
	if classDef == nil or skillId == "" then
		return nil, 0
	end
	for index, skill in ipairs(classDef.skills) do
		if skill.id == skillId then
			return skill, index
		end
	end
	if classDef.ultimate.id == skillId then
		return classDef.ultimate, 5
	end
	return nil, 0
end

local function ownsItem(profile: any, uid: string): boolean
	if type(profile) ~= "table" or uid == "" then
		return false
	end
	if type(profile.inventory) == "table" and profile.inventory[uid] ~= nil then
		return true
	end
	if type(profile.pets) == "table" and profile.pets[uid] ~= nil then
		return true
	end
	return false
end

local function itemOf(profile: any, uid: string): any
	if type(profile) ~= "table" then
		return nil
	end
	if type(profile.inventory) == "table" and profile.inventory[uid] ~= nil then
		return profile.inventory[uid]
	end
	if type(profile.pets) == "table" then
		return profile.pets[uid]
	end
	return nil
end

function ActionSlots.level(profile: any, classId: string): number
	local xp = 0
	if type(profile) == "table" and type(profile.classXp) == "table" then
		local amount = profile.classXp[classId]
		if type(amount) == "number" then
			xp = amount
		end
	end
	return Classes.progress(xp)
end

function ActionSlots.keyLabel(index: number): string
	local key = ActionSlots.KEYS[index]
	if key == nil then
		return ""
	end
	local label = LABELS[key]
	if label == nil then
		return key
	end
	return label
end

function ActionSlots.indexForKey(name: string): number?
	if type(name) ~= "string" then
		return nil
	end
	for index, key in ipairs(ActionSlots.KEYS) do
		if name == key or name == LABELS[key] then
			return index
		end
	end
	return nil
end

function ActionSlots.castKey(classId: string, skillId: string): any
	local _skill, index = listed(classId, skillId)
	if index >= 1 and index <= 4 then
		return index
	end
	if index == 5 then
		return "ult"
	end
	return nil
end

function ActionSlots.defaults(classId: string): Bar
	local slots: { Slot } = {}
	for index = 1, ActionSlots.COUNT do
		slots[index] = emptySlot()
	end
	local classDef = Classes.get(classId)
	if classDef ~= nil then
		for index, skill in ipairs(classDef.skills) do
			if index <= 4 then
				slots[index] = { kind = "skill", id = skill.id }
			end
		end
		slots[5] = { kind = "skill", id = classDef.ultimate.id }
		slots[6] = { kind = "consumable", id = Materials.TONIC_ID }
	end
	return { locked = false, slots = slots }
end

function ActionSlots.fresh(): { [string]: Bar }
	local bars: { [string]: Bar } = {}
	for _, classDef in ipairs(Classes.all()) do
		bars[classDef.id] = ActionSlots.defaults(classDef.id)
	end
	return bars
end

local function readSlot(classId: string, raw: any, profile: any, strict: boolean): (Slot?, string?)
	if raw == nil or (type(raw) == "table" and (raw.kind == nil or raw.kind == "empty")) then
		return emptySlot(), nil
	end
	if type(raw) ~= "table" or type(raw.kind) ~= "string" then
		if strict then
			return nil, "That slot is not a skill or item."
		end
		return emptySlot(), nil
	end
	local id = if type(raw.id) == "string" then raw.id else ""
	if raw.kind == "skill" then
		local skill = listed(classId, id)
		if skill == nil then
			if strict then
				return nil, "That skill is not on this class."
			end
			return emptySlot(), nil
		end
		return { kind = "skill", id = id }, nil
	end
	if raw.kind == "consumable" then
		if id ~= Materials.TONIC_ID then
			if strict then
				return nil, "That item cannot be used."
			end
			return emptySlot(), nil
		end
		return { kind = "consumable", id = id }, nil
	end
	if raw.kind == "item" then
		if not ownsItem(profile, id) then
			if strict then
				return nil, "You do not have that item."
			end
			return emptySlot(), nil
		end
		return { kind = "item", id = id }, nil
	end
	if strict then
		return nil, "That slot is not a skill or item."
	end
	return emptySlot(), nil
end

local function token(slot: Slot): string?
	if slot.kind == "empty" or slot.id == "" then
		return nil
	end
	return slot.kind .. ":" .. slot.id
end

function ActionSlots.accept(classId: string, slots: any, locked: any, profile: any): (Bar?, string?)
	if Classes.get(classId) == nil then
		return nil, "That class is not in the beta."
	end
	if type(slots) ~= "table" then
		return nil, "The bar needs 8 slots."
	end
	if slots[ActionSlots.COUNT + 1] ~= nil then
		return nil, "The bar holds 8 slots."
	end
	local cleaned: { Slot } = {}
	local seen: { [string]: boolean } = {}
	for index = 1, ActionSlots.COUNT do
		local slot, why = readSlot(classId, slots[index], profile, true)
		if slot == nil then
			return nil, why
		end
		local key = token(slot)
		if key ~= nil then
			if seen[key] == true then
				return nil, "That skill or item is already on the bar."
			end
			seen[key] = true
		end
		cleaned[index] = slot
	end
	return { locked = locked == true, slots = cleaned }, nil
end

function ActionSlots.repair(classId: string, saved: any, profile: any): Bar
	if Classes.get(classId) == nil then
		return ActionSlots.defaults("")
	end
	if type(saved) ~= "table" or type(saved.slots) ~= "table" then
		return ActionSlots.defaults(classId)
	end
	local cleaned: { Slot } = {}
	local seen: { [string]: boolean } = {}
	for index = 1, ActionSlots.COUNT do
		local slot = readSlot(classId, saved.slots[index], profile, false)
		if slot == nil then
			slot = emptySlot()
		end
		local key = token(slot)
		if key ~= nil and seen[key] == true then
			slot = emptySlot()
		elseif key ~= nil then
			seen[key] = true
		end
		cleaned[index] = slot
	end
	return { locked = saved.locked == true, slots = cleaned }
end

function ActionSlots.reconcile(source: any, profile: any): { [string]: Bar }
	local bars: { [string]: Bar } = {}
	for _, classDef in ipairs(Classes.all()) do
		local saved = nil
		if type(source) == "table" then
			saved = source[classDef.id]
		end
		bars[classDef.id] = ActionSlots.repair(classDef.id, saved, profile)
	end
	return bars
end

function ActionSlots.barFor(bars: any, classId: string): Bar
	if type(bars) == "table" and type(bars[classId]) == "table" and type(bars[classId].slots) == "table" then
		return bars[classId]
	end
	return ActionSlots.defaults(classId)
end

local function cloneBar(bar: Bar): Bar
	local slots: { Slot } = {}
	for index = 1, ActionSlots.COUNT do
		local slot = bar.slots[index]
		if slot == nil then
			slots[index] = emptySlot()
		else
			slots[index] = { kind = slot.kind, id = slot.id }
		end
	end
	return { locked = bar.locked == true, slots = slots }
end

function ActionSlots.swap(bar: Bar, fromIndex: number, toIndex: number): (Bar?, string?)
	if bar.locked == true then
		return nil, "Bar is locked."
	end
	if fromIndex < 1 or fromIndex > ActionSlots.COUNT or toIndex < 1 or toIndex > ActionSlots.COUNT then
		return nil, "That slot is empty."
	end
	local nextBar = cloneBar(bar)
	local held = nextBar.slots[fromIndex]
	nextBar.slots[fromIndex] = nextBar.slots[toIndex]
	nextBar.slots[toIndex] = held
	return nextBar, nil
end

function ActionSlots.clear(bar: Bar, index: number): (Bar?, string?)
	if bar.locked == true then
		return nil, "Bar is locked."
	end
	if index < 1 or index > ActionSlots.COUNT then
		return nil, "That slot is empty."
	end
	local nextBar = cloneBar(bar)
	nextBar.slots[index] = emptySlot()
	return nextBar, nil
end

function ActionSlots.drop(bar: Bar, index: number, slot: Slot): (Bar?, string?)
	if bar.locked == true then
		return nil, "Bar is locked."
	end
	if index < 1 or index > ActionSlots.COUNT then
		return nil, "That slot is empty."
	end
	local nextBar = cloneBar(bar)
	local key = token(slot)
	if key ~= nil then
		for other = 1, ActionSlots.COUNT do
			if other ~= index and token(nextBar.slots[other]) == key then
				nextBar.slots[other] = emptySlot()
			end
		end
	end
	nextBar.slots[index] = { kind = slot.kind, id = slot.id }
	return nextBar, nil
end

function ActionSlots.block(
	classId: string,
	slot: Slot,
	profile: any,
	cooling: boolean,
	inRange: boolean?
): string?
	if slot.kind == "empty" or slot.id == "" then
		return nil
	end
	if slot.kind == "skill" then
		local skill, index = listed(classId, slot.id)
		if skill == nil then
			return "That skill is not on this class."
		end
		local need = ActionSlots.UNLOCK[index]
		if need == nil then
			need = 1
		end
		if ActionSlots.level(profile, classId) < need then
			return string.format("Locked until Lv %d", need)
		end
		if cooling then
			return "On cooldown"
		end
		if inRange == false and skill.radius > 0 then
			return "Out of range"
		end
		return nil
	end
	if slot.kind == "consumable" then
		local count = 0
		if type(profile) == "table" and type(profile.consumables) == "table" then
			local owned = profile.consumables[slot.id]
			if type(owned) == "number" then
				count = math.floor(owned)
			end
		end
		if count < 1 then
			return "You have no Healing Tonic."
		end
		if cooling then
			return "On cooldown"
		end
		return nil
	end
	if slot.kind == "item" then
		if not ownsItem(profile, slot.id) then
			return "You do not have that item."
		end
		local item = itemOf(profile, slot.id)
		local kind = if type(item) == "table" then item.kind else nil
		if kind ~= "Consumable" and kind ~= "Usable" then
			return "That item cannot be used."
		end
		if cooling then
			return "On cooldown"
		end
		return nil
	end
	return "That slot is empty."
end

function ActionSlots.tint(reason: string?): string?
	if reason == nil or reason == "" then
		return nil
	end
	if string.find(reason, "Locked", 1, true) ~= nil then
		return "locked"
	end
	if reason == "On cooldown" then
		return "cooldown"
	end
	if reason == "Out of range" then
		return "range"
	end
	return "unusable"
end

function ActionSlots.lockLabel(classId: string, slot: Slot, profile: any): string?
	local reason = ActionSlots.block(classId, slot, profile, false, true)
	if reason == nil then
		return nil
	end
	local levelText = string.match(reason, "Lv %d+")
	if levelText == nil then
		return nil
	end
	return ActionSlots.PADLOCK .. " " .. levelText
end

function ActionSlots.glyph(classId: string, slot: Slot): (string, { number })
	if slot.kind == "skill" then
		local skill = listed(classId, slot.id)
		local letter = "S"
		if skill ~= nil and skill.name ~= "" then
			letter = string.upper(string.sub(skill.name, 1, 1))
		end
		local classDef = Classes.get(classId)
		local color = { 255, 220, 140 }
		if classDef ~= nil then
			color = { classDef.palette[1], classDef.palette[2], classDef.palette[3] }
		end
		return letter, color
	end
	if slot.kind == "consumable" then
		return "+", { 140, 230, 170 }
	end
	if slot.kind == "item" then
		return "I", { 220, 214, 240 }
	end
	return "", { 244, 240, 252 }
end

function ActionSlots.describe(classId: string, slot: Slot, profile: any): (string, string)
	if slot.kind == "skill" then
		local skill = listed(classId, slot.id)
		if skill ~= nil then
			return skill.name, skill.note
		end
	end
	if slot.kind == "consumable" then
		return Materials.TONIC_NAME, "Restores some health."
	end
	if slot.kind == "item" then
		local item = itemOf(profile, slot.id)
		if type(item) == "table" then
			local name = if type(item.name) == "string" then item.name else "Item"
			local note = if type(item.kind) == "string" then item.kind else "Item"
			return name, note
		end
	end
	return "", ""
end

function ActionSlots.stacks(slot: Slot, profile: any): number?
	if slot.kind ~= "consumable" then
		return nil
	end
	if type(profile) ~= "table" or type(profile.consumables) ~= "table" then
		return 0
	end
	local owned = profile.consumables[slot.id]
	if type(owned) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(owned))
end

function ActionSlots.border(slot: Slot, profile: any): { number }
	if slot.kind == "consumable" then
		local red, green, blue = UiTheme.rarityColor("Common")
		return { red, green, blue }
	end
	if slot.kind == "item" then
		local rarity = "Common"
		local item = itemOf(profile, slot.id)
		if type(item) == "table" and type(item.rarity) == "string" then
			rarity = item.rarity
		end
		local red, green, blue = UiTheme.rarityColor(rarity)
		return { red, green, blue }
	end
	return { 255, 206, 96 }
end

function ActionSlots.secondsLeft(readyAt: number, now: number): number
	if type(readyAt) ~= "number" or type(now) ~= "number" then
		return 0
	end
	local left = readyAt - now
	if left <= 0 then
		return 0
	end
	return math.ceil(left - 1e-6)
end

function ActionSlots.sweep(elapsed: number, total: number): number
	if type(elapsed) ~= "number" or type(total) ~= "number" or total <= 0 then
		return 0
	end
	local cover = 1 - (elapsed / total)
	if cover < 0 then
		return 0
	end
	if cover > 1 then
		return 1
	end
	return cover
end

function ActionSlots.fromRow(row: any): Slot?
	if type(row) ~= "table" then
		return nil
	end
	local id = row.id
	if row.kind == "Consumable" or (type(id) == "string" and string.sub(id, 1, 11) == "consumable:") then
		return { kind = "consumable", id = Materials.TONIC_ID }
	end
	if type(row.uid) == "string" and row.uid ~= "" then
		return { kind = "item", id = row.uid }
	end
	return nil
end

local function fitSlot(available: number, columns: number, gap: number, prefer: number, minimum: number): number
	local slot = prefer
	while slot > minimum and columns * slot + (columns - 1) * gap > available do
		slot -= 2
	end
	if slot < minimum then
		slot = minimum
	end
	return slot
end

function ActionSlots.placement(viewportX: number, viewportY: number, mobile: boolean): Place
	local width = math.max(200, math.floor(viewportX))
	local height = math.max(200, math.floor(viewportY))
	local gap = 8
	local margin = 16
	if mobile then
		local columns = 4
		local rows = 2
		local available = width - 140 - margin * 2
		local slot = fitSlot(available, columns, gap, 56, 44)
		local barW = columns * slot + (columns - 1) * gap
		local barH = rows * slot + (rows - 1) * gap + 36
		local x = width - margin - barW
		local jump = 88
		local y = height - margin - jump - barH
		if y < 160 then
			y = math.max(160, height - margin - barH)
		end
		return {
			x = x,
			y = y,
			w = barW,
			h = barH,
			slot = slot,
			gap = gap,
			columns = columns,
			rows = rows,
			mobile = true,
		}
	end
	local columns = 8
	local slot = fitSlot(width - margin * 2, columns, gap, 64, 44)
	local barW = columns * slot + (columns - 1) * gap
	local barH = slot + 36
	local x = math.floor((width - barW) / 2)
	local y = height - margin - barH
	if y < 160 then
		y = math.max(8, height - barH)
	end
	return {
		x = x,
		y = y,
		w = barW,
		h = barH,
		slot = slot,
		gap = gap,
		columns = columns,
		rows = 1,
		mobile = false,
	}
end

export type Chrome = {
	lock: Rect,
	roll: Rect,
}

export type Face = {
	fill: { number },
	stroke: { number },
	thickness: number,
}

function ActionSlots.chrome(place: any, _extra: any?): Chrome
	local slot = 44
	local gap = 8
	if type(place) == "table" then
		if type(place.slot) == "number" and place.slot == place.slot and place.slot > 0 then
			slot = place.slot
		end
		if type(place.gap) == "number" and place.gap == place.gap and place.gap >= 0 then
			gap = place.gap
		end
	end
	return {
		lock = { x = 0, y = 4, w = slot, h = 28 },
		roll = { x = slot + gap, y = 4, w = slot, h = 28 },
	}
end

function ActionSlots.face(_extra: any?): Face
	return {
		fill = { 12, 10, 16 },
		stroke = { 255, 214, 120 },
		thickness = 3,
	}
end

function ActionSlots.joystick(viewportY: number): Rect
	return { x = 0, y = math.max(0, viewportY - 150), w = 140, h = 150 }
end

function ActionSlots.toastHost(viewportX: number): Rect
	local width = math.min(420, math.max(160, viewportX - 240))
	local x = math.floor((viewportX - width) / 2)
	return { x = x, y = 0, w = width, h = 160 }
end

function ActionSlots.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y
end

function ActionSlots.prompts(place: Place, viewportX: number, viewportY: number): { dodge: Rect, interact: Rect }
	local size = if place.mobile then 52 else 44
	local dodgeX = place.x - size - 8
	local dodgeY = place.y + place.h - size
	if dodgeX < 8 or (place.mobile and dodgeX < 140) then
		dodgeX = place.x
		dodgeY = place.y - size - 8
	end
	if dodgeY < 160 then
		dodgeY = place.y + place.h + 8
	end
	local interactX = place.x + place.w + 8
	local interactY = dodgeY
	if interactX + size > viewportX - 8 then
		interactX = math.max(8, viewportX - 8 - size)
		interactY = math.max(160, place.y - size - 8)
	end
	if interactY + size > viewportY - 8 then
		interactY = viewportY - 8 - size
	end
	return {
		dodge = { x = dodgeX, y = dodgeY, w = size, h = size },
		interact = { x = interactX, y = interactY, w = size, h = size },
	}
end

return ActionSlots
