--!strict

--[[
	Phase 2 equip. The five slots live in Config/EquipSlots. This module
	writes equipLoadout only. The legacy equipped weapon, armor, and pet
	are left alone, and so are gold and the bag.

	Stat totals are computed here. They are not saved. With upgradeScale
	on, a piece's stat is multiplied from item.upgrade (+0 is ×1).
	The slot's level field is that same upgrade. There is no item.level.
]]

local Totals = require("./Totals")
local Validate = require("./Validate")

local EquipService = {}

local function copyAccepts(slot: any): { string }
	local accepts = {}
	if type(slot) == "table" and type(slot.accepts) == "table" then
		for _, kind in ipairs(slot.accepts) do
			if type(kind) == "string" then
				table.insert(accepts, kind)
			end
		end
	end
	return accepts
end

local function pieceLevel(profile: any, slot: any, itemId: string, ctx: any): number?
	if itemId == "" or type(slot) ~= "table" or slot.source == "class" then
		return nil
	end
	if not Validate.holds(profile, slot, itemId, ctx) then
		return nil
	end
	local item = nil
	if slot.source == "inventory" and type(profile.inventory) == "table" then
		item = profile.inventory[itemId]
	elseif slot.source == "pets" and type(profile.pets) == "table" then
		item = profile.pets[itemId]
	end
	if type(item) ~= "table" then
		return nil
	end
	if
		ctx.gearEnabled == true
		and type(ctx.gearConfig) == "table"
		and type(ctx.gearConfig.storedUpgrade) == "function"
	then
		return ctx.gearConfig.storedUpgrade(item.upgrade)
	end
	local upgrade = item.upgrade
	if type(upgrade) ~= "number" or upgrade ~= upgrade or upgrade < 0 or upgrade >= math.huge then
		return 0
	end
	local whole = math.floor(item.upgrade)
	if whole > 10 then
		return 10
	end
	return whole
end

function EquipService.view(profile: any, ctx: any): any
	local loadout = Validate.loadout(profile, ctx)
	local slots = {}
	for _, slotId in ipairs(ctx.slots.ORDER) do
		local slot = ctx.slots.LIST[slotId]
		local itemId = loadout[slotId]
		local locked = false
		if type(slot) == "table" and slot.source == "class" and itemId ~= "" then
			locked = Validate.skillLocked(profile, itemId, ctx)
		end
		table.insert(slots, {
			id = slotId,
			name = if type(slot) == "table" and type(slot.name) == "string" then slot.name else slotId,
			accepts = copyAccepts(slot),
			source = if type(slot) == "table" and type(slot.source) == "string" then slot.source else "",
			itemId = itemId,
			locked = locked,
			level = pieceLevel(profile, slot, itemId, ctx),
		})
	end
	return {
		ok = true,
		loadout = loadout,
		stats = Totals.compute(profile, loadout, ctx),
		slots = slots,
		elements = Totals.elements(profile, loadout, ctx),
	}
end

function EquipService.equip(profile: any, slotId: any, itemId: any, ctx: any): (boolean, string?, any?)
	local reason = Validate.equip(profile, slotId, itemId, ctx)
	if reason ~= nil then
		return false, reason, nil
	end
	local loadout = Validate.loadout(profile, ctx)
	local previous = loadout[slotId]
	loadout[slotId] = itemId
	profile.equipLoadout = loadout
	local view = EquipService.view(profile, ctx)
	if previous ~= "" then
		view.replaced = previous
	end
	return true, nil, view
end

function EquipService.unequip(profile: any, slotId: any, ctx: any): (boolean, string?, any?)
	local reason = Validate.unequip(profile, slotId, ctx)
	if reason ~= nil then
		return false, reason, nil
	end
	local loadout = Validate.loadout(profile, ctx)
	local removed = loadout[slotId]
	loadout[slotId] = ""
	profile.equipLoadout = loadout
	local view = EquipService.view(profile, ctx)
	view.removed = removed
	return true, nil, view
end

local function firstId(bag: any, kind: string, used: { [string]: boolean }): string?
	if type(bag) ~= "table" then
		return nil
	end
	local best = nil
	for id, item in pairs(bag) do
		if type(id) == "string" and used[id] ~= true and type(item) == "table" and item.kind == kind then
			if best == nil or id < best then
				best = id
			end
		end
	end
	return best
end

-- Seats the first owned piece in each gear slot, then the first class
-- skills. Does not grant items and does not touch the legacy equipped map.
function EquipService.fillOwned(profile: any, ctx: any): number
	if type(profile) ~= "table" then
		return 0
	end
	local loadout = Validate.loadout(profile, ctx)
	local used: { [string]: boolean } = {}
	local seated = 0
	for _, slotId in ipairs(ctx.slots.ORDER) do
		local slot = ctx.slots.LIST[slotId]
		local itemId = nil
		if type(slot) == "table" and slot.source == "inventory" then
			local kind = slot.accepts[1]
			itemId = firstId(profile.inventory, kind, used)
		elseif type(slot) == "table" and slot.source == "pets" then
			itemId = firstId(profile.pets, "Pet", used)
		elseif type(slot) == "table" and slot.source == "class" and type(ctx.classes) == "table" then
			local classDef = ctx.classes.get(profile.classId)
			if type(classDef) == "table" and type(classDef.skills) == "table" then
				for _, skill in ipairs(classDef.skills) do
					if type(skill) == "table" and type(skill.id) == "string" and used[skill.id] ~= true then
						itemId = skill.id
						break
					end
				end
			end
		end
		if itemId ~= nil and Validate.holds(profile, slot, itemId, ctx) then
			loadout[slotId] = itemId
			used[itemId] = true
			seated += 1
		else
			loadout[slotId] = ""
		end
	end
	profile.equipLoadout = loadout
	return seated
end

return EquipService
