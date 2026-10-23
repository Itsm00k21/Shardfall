--!strict

--[[
	Phase 2 slot rules (ROADMAP 2.1). Data only.

	EquipService reads ORDER and LIST. It does not hardcode the five
	names. source says where the id has to live:

	  inventory — a bag uid whose kind is in accepts
	  pets — a pet uid whose kind is in accepts
	  class — a skill id on the player's class (not the ultimate)

	itemSlots, when present, also requires item.slot to be one of those
	names. The armor slot leaves it off, so any Armor piece fits the one
	armor slot. countsElement is a gear slot that can carry an element.

	SKILL_LEVELS is the class level that unlocks skill index 1..4. A
	locked skill may still sit in the slot. This table does not cast it.
]]

local EquipSlots = {}

EquipSlots.SKILL_LEVELS = table.freeze({ 1, 2, 4, 6 })

EquipSlots.ORDER = table.freeze({ "weapon", "armor", "pet", "skill1", "skill2" })

EquipSlots.LIST = table.freeze({
	weapon = table.freeze({
		id = "weapon",
		name = "Weapon",
		accepts = table.freeze({ "Weapon" }),
		source = "inventory",
		countsElement = true,
	}),
	armor = table.freeze({
		id = "armor",
		name = "Armor",
		accepts = table.freeze({ "Armor" }),
		source = "inventory",
		countsElement = true,
	}),
	pet = table.freeze({
		id = "pet",
		name = "Pet",
		accepts = table.freeze({ "Pet" }),
		source = "pets",
		countsElement = true,
	}),
	skill1 = table.freeze({
		id = "skill1",
		name = "Skill 1",
		accepts = table.freeze({ "Skill" }),
		source = "class",
		countsElement = false,
	}),
	skill2 = table.freeze({
		id = "skill2",
		name = "Skill 2",
		accepts = table.freeze({ "Skill" }),
		source = "class",
		countsElement = false,
	}),
})

function EquipSlots.empty(): { [string]: string }
	local loadout = {}
	for _, id in ipairs(EquipSlots.ORDER) do
		loadout[id] = ""
	end
	return loadout
end

-- A string the client may see. Luau %w does not include "_", and skill
-- ids use one, so the underscore is listed on its own. Anything else
-- is an empty slot.
local function kept(stored: any): string
	if type(stored) ~= "string" or stored == "" or #stored > 64 then
		return ""
	end
	if string.match(stored, "^[%w_%-]+$") == nil then
		return ""
	end
	return stored
end

-- Snapshot shape. Drops unknown keys and junk values. Does not check
-- ownership; the equip service does that on the copy it returns.
function EquipSlots.publicCopy(value: any): { [string]: string }
	local loadout = EquipSlots.empty()
	if type(value) ~= "table" then
		return loadout
	end
	for _, id in ipairs(EquipSlots.ORDER) do
		loadout[id] = kept(value[id])
	end
	return loadout
end

return table.freeze(EquipSlots)
