--!strict

--[[
	Hatchery, care, and fusion.

	Eggs spend gold. Favorites and the equipped companion cannot be fused.
	The client sends ids. This module owns the numbers.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Pets = require(ReplicatedStorage.Shared.Pets)
local DataService = require(script.Parent.DataService)
local LoopService = require(script.Parent.LoopService)

local PetService = {}

local function reject(message: string)
	return { ok = false, error = message }
end

local function findPet(data, uid: string)
	if type(data.companions) ~= "table" then
		return nil
	end
	for _, pet in ipairs(data.companions) do
		if pet.uid == uid then
			return pet
		end
	end
	return nil
end

function PetService.hatch(player: Player)
	local note = ""
	local ok, err = DataService.mutate(player, function(data)
		if (data.eggs or 0) < 1 and (data.gold or 0) < Pets.EGG_COST then
			return "An egg costs 50 gold."
		end
		if (data.eggs or 0) > 0 then
			data.eggs -= 1
		else
			data.gold -= Pets.EGG_COST
		end
		local pet = Pets.hatch(math.random())
		pet.uid = HttpService:GenerateGUID(false)
		if type(data.companions) ~= "table" then
			data.companions = {}
		end
		table.insert(data.companions, pet)
		note = pet.name
		return nil
	end)
	if not ok then
		return reject(err or "Could not hatch.")
	end
	LoopService.progress(player, "hatch", 1)
	return { ok = true, name = note, profile = DataService.snapshot(player) }
end

function PetService.care(player: Player, uid: any, kind: any)
	if type(uid) ~= "string" or (kind ~= "pet" and kind ~= "feed") then
		return reject("Pet or feed a companion.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local pet = findPet(data, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		if kind == "pet" then
			Pets.pet(pet)
		else
			Pets.feed(pet)
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not do that.")
	end
	LoopService.progress(player, "pet", 1)
	return { ok = true, profile = DataService.snapshot(player) }
end

function PetService.fuse(player: Player, keepUid: any, feedUid: any)
	if not LaunchGate.on("petEvolution") then
		return reject("That is closed.")
	end
	if type(keepUid) ~= "string" or type(feedUid) ~= "string" or keepUid == feedUid then
		return reject("Pick two different companions.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local keeper = findPet(data, keepUid)
		local feeder = findPet(data, feedUid)
		if
			data.equipped ~= nil and (data.equipped.pet == keepUid or data.equipped.pet == feedUid)
		then
			return "Unequip a companion before fusing it."
		end
		local fused, reason = Pets.bond(keeper, feeder)
		if not fused then
			return reason
		end
		local nextList = {}
		for _, pet in ipairs(data.companions) do
			if pet.uid ~= feedUid then
				table.insert(nextList, pet)
			end
		end
		data.companions = nextList
		return nil
	end)
	if not ok then
		return reject(err or "Could not fuse.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function PetService.paint(player: Player, uid: any, primary: any, secondary: any, glow: any)
	if type(uid) ~= "string" or type(primary) ~= "string" then
		return reject("Pick a color.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local pet = findPet(data, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		Pets.colors(
			pet,
			primary,
			if type(secondary) == "string" then secondary else "sap",
			if type(glow) == "string" then glow else "none"
		)
		return nil
	end)
	if not ok then
		return reject(err or "Could not paint.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function PetService.favorite(player: Player, uid: any, locked: any)
	if type(uid) ~= "string" or type(locked) ~= "boolean" then
		return reject("Pick a companion.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local pet = findPet(data, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		pet.favorite = locked
		return nil
	end)
	if not ok then
		return reject(err or "Could not lock that.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

return PetService
