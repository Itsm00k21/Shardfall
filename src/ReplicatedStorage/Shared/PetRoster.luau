--!strict

--[[
	The first pet-shard roster.

	Shardjaw, Thorn Lantern, and Glass Kestrel are the companions the
	Roll tab cracks. They are useful, not cute. The equipped pet's
	template id selects the effect. This module does not roll and does
	not spend gold.
]]

local PetRoster = {}

export type Companion = {
	id: string,
	name: string,
	rarity: string,
	effect: string,
	ability: string,
}

PetRoster.STARTER = {
	{
		id = "shardjaw",
		name = "Shardjaw",
		rarity = "Common",
		effect = "collect",
		ability = "Auto-collect drops",
	},
	{
		id = "thorn_lantern",
		name = "Thorn Lantern",
		rarity = "Uncommon",
		effect = "ping",
		ability = "Key ping",
	},
	{
		id = "glass_kestrel",
		name = "Glass Kestrel",
		rarity = "Rare",
		effect = "flash",
		ability = "Dodge flash",
	},
}

local byId: { [string]: Companion } = {}
for _, row in ipairs(PetRoster.STARTER) do
	byId[row.id] = row
end

function PetRoster.get(id: any): Companion?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function PetRoster.effect(id: any): string?
	local row = PetRoster.get(id)
	if row == nil then
		return nil
	end
	return row.effect
end

function PetRoster.equippedId(profile: any): string?
	if type(profile) ~= "table" or type(profile.equipped) ~= "table" then
		return nil
	end
	local uid = profile.equipped.pet
	if type(uid) ~= "string" or type(profile.pets) ~= "table" then
		return nil
	end
	local pet = profile.pets[uid]
	if type(pet) ~= "table" or type(pet.templateId) ~= "string" then
		return nil
	end
	return pet.templateId
end

function PetRoster.equippedEffect(profile: any): string?
	return PetRoster.effect(PetRoster.equippedId(profile))
end

return PetRoster
