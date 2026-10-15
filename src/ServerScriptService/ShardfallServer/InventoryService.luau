--!strict

--[[
	Add, remove, and equip. Add is not a remote.

	The client never sends "give me this item". Quests and other server
	systems call add() with an item they already created. A shard roll does
	not: the token spend and the insert have to share one mutate() so a
	failure gives the token back. Equip, unequip, and remove are remotes,
	and they only succeed when the uid is already in that player's profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Schema)
local DataService = require(script.Parent.DataService)

local InventoryService = {}

function InventoryService.add(player: Player, item: Schema.Item): (boolean, string?)
	return DataService.mutate(player, function(data)
		if Schema.findItem(data, item.uid) ~= nil then
			return "That item is already in the inventory."
		end
		if Schema.countItems(data) >= Schema.INVENTORY_CAP then
			return "Inventory is full."
		end
		Schema.insertItem(data, item)
		return nil
	end)
end

function InventoryService.remove(player: Player, uid: string): (boolean, string?, string?)
	local removedName: string? = nil
	local ok, err = DataService.mutate(player, function(data)
		local item, bag = Schema.findItem(data, uid)
		if item == nil or bag == nil then
			return "You do not have that item."
		end
		removedName = item.name
		bag[uid] = nil
		if data.equipped.weapon == uid then
			data.equipped.weapon = nil
		end
		if data.equipped.pet == uid then
			data.equipped.pet = nil
		end
		return nil
	end)
	return ok, err, removedName
end

function InventoryService.equip(player: Player, uid: string): (boolean, string?)
	return DataService.mutate(player, function(data)
		local item = Schema.findItem(data, uid)
		if item == nil then
			return "You do not have that item."
		end
		if item.kind == "Weapon" then
			data.equipped.weapon = uid
		elseif item.kind == "Pet" then
			data.equipped.pet = uid
		else
			return "That item cannot be equipped."
		end
		return nil
	end)
end

function InventoryService.unequip(player: Player, uid: string): (boolean, string?)
	return DataService.mutate(player, function(data)
		local item = Schema.findItem(data, uid)
		if item == nil then
			return "You do not have that item."
		end
		if data.equipped.weapon == uid then
			data.equipped.weapon = nil
		elseif data.equipped.pet == uid then
			data.equipped.pet = nil
		else
			return "That item is not equipped."
		end
		return nil
	end)
end

return InventoryService
