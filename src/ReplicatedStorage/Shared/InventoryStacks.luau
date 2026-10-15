--!strict

--[[
	Display grouping for the inventory panel.

	Profiles keep every drop under its own uid. This module only decides
	which of those rows can share a line in the UI. Identical template,
	rarity, kind, and traits stack ("Training Pup x3"). A different trait
	roll stays on its own line, and the uid list on a stack is how Equip
	and Drop still target one item.

	An equipped copy is pulled out of the stack so the bag still shows that
	item by name. The loadout names a weapon or pet only when that uid is in
	the bag.
]]

local Rarities = require("./Rarities")

local InventoryStacks = {}

export type Stack = {
	name: string,
	count: number,
	rarity: string,
	kind: string,
	traits: { any },
	uids: { string },
	equipped: boolean,
}

export type Loadout = {
	weapon: string,
	pet: string,
	bonus: string,
}

local function traitParts(traits: any): { string }
	local parts = {}
	if type(traits) ~= "table" then
		return parts
	end
	for _, trait in ipairs(traits) do
		if type(trait) == "table" then
			table.insert(
				parts,
				string.format("%s=%s", tostring(trait.id), tostring(trait.display or trait.value))
			)
		end
	end
	table.sort(parts)
	return parts
end

function InventoryStacks.bonusLine(traits: any): string
	if type(traits) ~= "table" then
		return "None"
	end
	local parts = {}
	for _, trait in ipairs(traits) do
		if type(trait) == "table" and trait.name ~= nil then
			local display = trait.display
			if display == nil or display == "" then
				table.insert(parts, tostring(trait.name))
			else
				table.insert(parts, string.format("%s %s", tostring(trait.name), tostring(display)))
			end
		end
	end
	if #parts == 0 then
		return "None"
	end
	return table.concat(parts, " · ")
end

local function stackKey(item: any): string
	return table.concat({
		tostring(item.templateId),
		tostring(item.kind),
		tostring(item.rarity),
		table.concat(traitParts(item.traits), ","),
	}, "\0")
end

local function singleton(item: any, equipped: boolean): Stack
	local uid = item.uid
	return {
		name = tostring(item.name),
		count = 1,
		rarity = tostring(item.rarity),
		kind = tostring(item.kind),
		traits = if type(item.traits) == "table" then item.traits else {},
		uids = if type(uid) == "string" then { uid } else {},
		equipped = equipped,
	}
end

local function compare(a: Stack, b: Stack): boolean
	if a.equipped ~= b.equipped then
		return a.equipped
	end
	local left = Rarities.INDEX[a.rarity] or 0
	local right = Rarities.INDEX[b.rarity] or 0
	if left ~= right then
		return left > right
	end
	if a.name ~= b.name then
		return a.name < b.name
	end
	return a.uids[1] ~= nil and b.uids[1] ~= nil and a.uids[1] < b.uids[1]
end

function InventoryStacks.group(entries: { any }): { Stack }
	local equippedRows = {}
	local buckets: { [string]: Stack } = {}
	local piled = {}
	for _, entry in ipairs(entries) do
		local item = if type(entry) == "table" then entry.item else nil
		if type(item) ~= "table" then
			continue
		end
		if entry.equipped == true then
			table.insert(equippedRows, singleton(item, true))
		else
			local key = stackKey(item)
			local stack = buckets[key]
			if stack == nil then
				stack = singleton(item, false)
				stack.count = 0
				stack.uids = {}
				buckets[key] = stack
				table.insert(piled, stack)
			end
			stack.count += 1
			if type(item.uid) == "string" then
				table.insert(stack.uids, item.uid)
			end
		end
	end
	table.sort(equippedRows, compare)
	table.sort(piled, compare)
	local result = table.clone(equippedRows)
	for _, stack in ipairs(piled) do
		table.insert(result, stack)
	end
	return result
end

local function findUid(profile: any, uid: any): any
	if type(profile) ~= "table" or type(uid) ~= "string" or uid == "" then
		return nil
	end
	if type(profile.inventory) == "table" and type(profile.inventory[uid]) == "table" then
		return profile.inventory[uid]
	end
	if type(profile.pets) == "table" and type(profile.pets[uid]) == "table" then
		return profile.pets[uid]
	end
	return nil
end

function InventoryStacks.loadout(profile: any): Loadout
	local equipped = if type(profile) == "table" and type(profile.equipped) == "table"
		then profile.equipped
		else {}
	local weapon = findUid(profile, equipped.weapon)
	local pet = findUid(profile, equipped.pet)
	local traits = {}
	local function take(item: any)
		if type(item) == "table" and type(item.traits) == "table" then
			for _, trait in ipairs(item.traits) do
				table.insert(traits, trait)
			end
		end
	end
	take(weapon)
	take(pet)
	return {
		weapon = if weapon ~= nil then tostring(weapon.name) else "None",
		pet = if pet ~= nil then tostring(pet.name) else "None",
		bonus = InventoryStacks.bonusLine(traits),
	}
end

return InventoryStacks
