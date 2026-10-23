--!strict

--[[
	Equip and unequip checks. Pure: it reads the profile and the slot
	table and does not write either.

	A slot id that is not in the config is refused. The item kind has
	to be one the slot accepts. Gear has to be owned. A skill has to be
	on the player's class. The same id cannot sit in two slots.
]]

local Validate = {}

Validate.OFF = "Equip is off."
Validate.SLOW = "Slow down a moment."
Validate.UNKNOWN_SLOT = "Unknown slot."
Validate.MISSING = "You do not have that item."
Validate.FIT = "That item does not fit this slot."
Validate.DUPLICATE = "That item is already equipped."
Validate.SKILL = "That skill is not on your class."
Validate.EMPTY = "That slot is empty."
Validate.PROFILE = "Profile is not loaded."
Validate.UPDATE = "Could not update your profile."

function Validate.validId(value: any): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= 64
		and string.match(value, "^[%w_%-]+$") ~= nil
end

local function accepts(slot: any, kind: any): boolean
	if type(slot) ~= "table" or type(slot.accepts) ~= "table" or type(kind) ~= "string" then
		return false
	end
	for _, allowed in ipairs(slot.accepts) do
		if allowed == kind then
			return true
		end
	end
	return false
end

local function slotListed(slot: any, itemSlot: any): boolean
	if type(slot.itemSlots) ~= "table" then
		return true
	end
	if type(itemSlot) ~= "string" then
		return false
	end
	for _, name in ipairs(slot.itemSlots) do
		if name == itemSlot then
			return true
		end
	end
	return false
end

local function bagItem(profile: any, source: string, itemId: string): any
	local bag = nil
	if source == "inventory" then
		bag = profile.inventory
	elseif source == "pets" then
		bag = profile.pets
	end
	if type(bag) ~= "table" then
		return nil
	end
	local item = bag[itemId]
	if type(item) ~= "table" then
		return nil
	end
	return item
end

local function classLevel(profile: any, classId: string, classes: any): number
	local xp = 0
	if type(profile.classXp) == "table" then
		local amount = profile.classXp[classId]
		if type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge then
			xp = amount
		end
	end
	if type(classes) ~= "table" or type(classes.progress) ~= "function" then
		return 1
	end
	local level = classes.progress(xp)
	if type(level) ~= "number" or level ~= level or level < 1 then
		return 1
	end
	return level
end

-- The skill record when this id is one of the class skills. The ultimate
-- is not a slot id. nil when the class does not have it.
local function classSkill(profile: any, itemId: string, classes: any): (any?, number)
	if type(profile) ~= "table" or type(classes) ~= "table" or type(classes.get) ~= "function" then
		return nil, 0
	end
	local classDef = classes.get(profile.classId)
	if type(classDef) ~= "table" or type(classDef.skills) ~= "table" then
		return nil, 0
	end
	for index, skill in ipairs(classDef.skills) do
		if type(skill) == "table" and skill.id == itemId then
			return skill, index
		end
	end
	return nil, 0
end

function Validate.skillLocked(profile: any, itemId: string, ctx: any): boolean
	local _, index = classSkill(profile, itemId, ctx.classes)
	if index < 1 then
		return false
	end
	local levels = ctx.slots.SKILL_LEVELS
	local need = nil
	if type(levels) == "table" then
		need = levels[index]
	end
	if type(need) ~= "number" then
		return true
	end
	return classLevel(profile, profile.classId, ctx.classes) < need
end

-- true when this id may occupy the slot. The second return is why not.
function Validate.holds(profile: any, slot: any, itemId: string, ctx: any): (boolean, string?)
	if type(profile) ~= "table" or type(slot) ~= "table" then
		return false, Validate.PROFILE
	end
	if not Validate.validId(itemId) then
		return false, Validate.MISSING
	end
	local source = slot.source
	if source == "inventory" or source == "pets" then
		local item = bagItem(profile, source, itemId)
		if item == nil then
			return false, Validate.MISSING
		end
		if not accepts(slot, item.kind) or not slotListed(slot, item.slot) then
			return false, Validate.FIT
		end
		return true, nil
	end
	if source == "class" then
		local skill = classSkill(profile, itemId, ctx.classes)
		if skill == nil or not accepts(slot, "Skill") then
			return false, Validate.SKILL
		end
		return true, nil
	end
	return false, Validate.FIT
end

-- Clean slot map. Does not write the profile. The first slot in ORDER
-- keeps a repeated id. Later copies and anything unowned become "".
function Validate.loadout(profile: any, ctx: any): { [string]: string }
	local slots = ctx.slots
	local saved = nil
	if type(profile) == "table" then
		saved = profile.equipLoadout
	end
	local out = {}
	local seen: { [string]: boolean } = {}
	for _, slotId in ipairs(slots.ORDER) do
		local raw = ""
		if type(saved) == "table" then
			local value = saved[slotId]
			if type(value) == "string" then
				raw = value
			end
		end
		local slot = slots.LIST[slotId]
		if raw ~= "" and seen[raw] ~= true and Validate.holds(profile, slot, raw, ctx) then
			out[slotId] = raw
			seen[raw] = true
		else
			out[slotId] = ""
		end
	end
	return out
end

function Validate.equip(profile: any, slotId: any, itemId: any, ctx: any): string?
	if type(profile) ~= "table" then
		return Validate.PROFILE
	end
	if type(slotId) ~= "string" or ctx.slots.LIST[slotId] == nil then
		return Validate.UNKNOWN_SLOT
	end
	if not Validate.validId(itemId) then
		return Validate.MISSING
	end
	local slot = ctx.slots.LIST[slotId]
	local ok, reason = Validate.holds(profile, slot, itemId, ctx)
	if not ok then
		return reason or Validate.MISSING
	end
	local current = Validate.loadout(profile, ctx)
	for _, other in ipairs(ctx.slots.ORDER) do
		if other ~= slotId and current[other] == itemId then
			return Validate.DUPLICATE
		end
	end
	return nil
end

function Validate.unequip(profile: any, slotId: any, ctx: any): string?
	if type(profile) ~= "table" then
		return Validate.PROFILE
	end
	if type(slotId) ~= "string" or ctx.slots.LIST[slotId] == nil then
		return Validate.UNKNOWN_SLOT
	end
	local current = Validate.loadout(profile, ctx)
	if current[slotId] == "" then
		return Validate.EMPTY
	end
	return nil
end

return Validate
