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
local Stars = require(ReplicatedStorage.Shared.Stars)
local DataService = require(script.Parent.DataService)

local InventoryService = {}

function InventoryService.add(player: Player, item: Schema.Item): (boolean, string?)
	return DataService.mutate(player, function(data)
		if Schema.findItem(data, item.uid) ~= nil then
			return "That item is already in the inventory."
		end
		if Schema.countItems(data) >= Schema.inventoryCap(data) then
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
		if item.locked == true then
			return "That item is locked."
		end
		removedName = item.name
		bag[uid] = nil
		Schema.clearEquip(data, uid)
		return nil
	end)
	return ok, err, removedName
end

function InventoryService.feed(player: Player, keptUid: string, feederUid: string)
	local summary = nil
	local ok, err = DataService.mutate(player, function(data)
		local kept, keptBag = Schema.findItem(data, keptUid)
		local feeder, feederBag = Schema.findItem(data, feederUid)
		if kept == nil or feeder == nil or keptBag == nil or feederBag == nil then
			return "You do not have that item."
		end
		if feeder.locked == true then
			return "That item is locked."
		end
		if keptBag ~= feederBag then
			return "Feed a duplicate of the same item."
		end
		local previous = if type(kept.stars) == "number" then kept.stars else 0
		local feederName = feeder.name
		local feederQuality = feeder.quality
		local preview, reason = Stars.commit(kept, feeder)
		if preview == nil then
			return reason or "Could not feed that."
		end
		feederBag[feederUid] = nil
		Schema.clearEquip(data, feederUid)
		local message: string
		if preview.stars > previous then
			message = string.format("%s is now ★%d.", tostring(kept.name), preview.stars)
			if previous < 3 and preview.stars >= 3 then
				message ..= " Starforged unlocked."
			end
			if previous < 5 and preview.stars >= 5 then
				message ..= " Ascendant unlocked."
			end
		else
			message = string.format(
				"Fed %s into %s. %s toward the next star.",
				tostring(feederName),
				tostring(kept.name),
				Stars.formatProgress(preview.starProgress)
			)
		end
		summary = {
			name = kept.name,
			stars = kept.stars,
			starProgress = kept.starProgress,
			feederName = feederName,
			feederQuality = feederQuality,
			gained = preview.gained,
			message = message,
		}
		return nil
	end)
	if not ok then
		return { ok = false, error = err or "Could not feed that." }
	end
	return { ok = true, feed = summary }
end

function InventoryService.setFlag(
	player: Player,
	uid: string,
	flag: string,
	value: boolean
): (boolean, string?)
	if flag ~= "locked" and flag ~= "favorite" then
		return false, "Unknown item flag."
	end
	return DataService.mutate(player, function(data)
		local item = Schema.findItem(data, uid)
		if item == nil then
			return "You do not have that item."
		end
		if flag == "locked" then
			item.locked = value
		else
			item.favorite = value
		end
		return nil
	end)
end

function InventoryService.equip(player: Player, uid: string): (boolean, string?)
	return DataService.mutate(player, function(data)
		local item = Schema.findItem(data, uid)
		if item == nil then
			return "You do not have that item."
		end
		return Schema.equipItem(data, item)
	end)
end

function InventoryService.unequip(player: Player, uid: string): (boolean, string?)
	return DataService.mutate(player, function(data)
		local item = Schema.findItem(data, uid)
		if item == nil then
			return "You do not have that item."
		end
		if not Schema.isEquipped(data, uid) then
			return "That item is not equipped."
		end
		Schema.clearEquip(data, uid)
		return nil
	end)
end

return InventoryService
