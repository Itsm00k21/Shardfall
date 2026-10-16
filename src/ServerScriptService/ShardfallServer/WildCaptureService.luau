--!strict

--[[
	Server rolls for shiny tames, boss pets, and evolution.

	DungeonService should call noteShiny when an enemy spawns, tame when
	that shiny is defeated, and grantBoss when Grandmother Gnarl falls.
	A client remote must not send the shiny flag or the roll. handle()
	ignores both and only tames a shiny this server already noted.

	Remotes, RateLimiter, and init are Ghost's. start() only drops the
	pending shiny when the player leaves.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PetEvolution = require(ReplicatedStorage.Shared.PetEvolution)
local WildCapture = require(ReplicatedStorage.Shared.WildCapture)

local WildCaptureService = {}

local pending: { [Player]: { [string]: number } } = {}
local started = false

local function fail(message: string)
	return { ok = false, error = message }
end

local function key(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value < 1 or #value > 64 then
		return nil
	end
	if string.match(value, "^[%w_]+$") == nil then
		return nil
	end
	return value
end

local function uidOf(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value < 1 or #value > 80 then
		return nil
	end
	if string.match(value, "^[%w%-]+$") == nil then
		return nil
	end
	return value
end

local function unitRoll(value: any): number?
	if type(value) ~= "number" or value ~= value or value < 0 or value >= 1 then
		return nil
	end
	return value
end

local function findCompanion(data: any, uid: string): (any?, number?)
	if type(data.companions) ~= "table" then
		return nil, nil
	end
	for index, pet in ipairs(data.companions) do
		if type(pet) == "table" and pet.uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

local function insertCompanion(data: any, pet: any)
	pet.uid = HttpService:GenerateGUID(false)
	if type(data.companions) ~= "table" then
		data.companions = {}
	end
	table.insert(data.companions, pet)
end

local function giveMark(player: Player, enemyId: string)
	local marked = pending[player]
	if marked == nil then
		local fresh: { [string]: number } = {}
		marked = fresh
		pending[player] = fresh
	end
	marked[enemyId] = (marked[enemyId] or 0) + 1
end

local function takeMark(player: Player, enemyId: string): boolean
	local marked = pending[player]
	if marked == nil then
		return false
	end
	local count = marked[enemyId]
	if type(count) ~= "number" or count < 1 then
		return false
	end
	if count == 1 then
		marked[enemyId] = nil
	else
		marked[enemyId] = count - 1
	end
	return true
end

local function note(player: Player, encounter: any)
	local enemyId = key(encounter.enemyId)
	if enemyId == nil or WildCapture.ENEMIES[enemyId] == nil then
		return { ok = false, error = "That creature cannot be tamed.", shiny = false }
	end
	local roll = unitRoll(encounter.roll)
	if roll == nil then
		roll = math.random()
	end
	local shiny = WildCapture.rollShiny(roll)
	if shiny then
		giveMark(player, enemyId)
	end
	return { ok = true, shiny = shiny, enemyId = enemyId }
end

local function tame(player: Player, encounter: any)
	local enemyId = key(encounter.enemyId)
	if enemyId == nil then
		return fail("Nothing to capture.")
	end
	if encounter.defeated == false then
		return fail("Defeat the shiny first.")
	end
	if not takeMark(player, enemyId) then
		return fail("No shiny is here.")
	end
	local captureRoll = unitRoll(encounter.roll)
	if captureRoll == nil then
		captureRoll = math.random()
	end
	local caughtName = ""
	local caughtSpecies = ""
	local saved, err = DataService.mutate(player, function(data)
		if not WildCapture.charmEquipped(data) then
			return "Equip a Capture Charm."
		end
		local caught, reason = WildCapture.tryCapture(true, captureRoll)
		if not caught then
			return reason
		end
		local pet, buildErr = WildCapture.shinyCompanion(enemyId)
		if pet == nil then
			return buildErr or "That creature cannot be tamed."
		end
		insertCompanion(data, pet)
		caughtName = pet.name
		caughtSpecies = pet.species
		return nil
	end)
	if not saved and err == "Profile is not loaded." then
		giveMark(player, enemyId)
		return fail(err)
	end
	if not saved then
		return fail(err or "The shiny slipped away.")
	end
	return {
		ok = true,
		name = caughtName,
		species = caughtSpecies,
		shiny = true,
		profile = DataService.snapshot(player),
	}
end

local function boss(player: Player, encounter: any)
	local bossId = key(encounter.bossId)
	if bossId == nil then
		bossId = key(encounter.enemyId)
	end
	if bossId == nil then
		return { ok = false, error = "That boss has no pet.", dropped = false }
	end
	local roll = unitRoll(encounter.roll)
	if roll == nil then
		roll = math.random()
	end
	local pet, reason = WildCapture.rollBossPet(bossId, roll)
	if pet == nil then
		return { ok = false, error = reason, dropped = false }
	end
	local saved, err = DataService.mutate(player, function(data)
		insertCompanion(data, pet)
		return nil
	end)
	if not saved then
		return fail(err or "Could not grant that pet.")
	end
	return {
		ok = true,
		dropped = true,
		name = pet.name,
		species = pet.species,
		ability = pet.ability,
		profile = DataService.snapshot(player),
	}
end

local function evolve(player: Player, encounter: any)
	local uid = uidOf(encounter.uid)
	if uid == nil then
		return fail("Pick a companion.")
	end
	local noteText = ""
	local speciesId = ""
	local saved, err = DataService.mutate(player, function(data)
		local pet, index = findCompanion(data, uid)
		if pet == nil or index == nil then
			return "That companion is not in the den."
		end
		local evolvedOk, reason, evolved, spent = PetEvolution.evolve(pet, data.materials)
		if not evolvedOk or evolved == nil or spent == nil then
			return reason
		end
		if type(data.materials) ~= "table" then
			return "Need materials."
		end
		for id, count in pairs(spent) do
			local have = data.materials[id]
			if type(have) ~= "number" or have < count then
				return "Need materials."
			end
		end
		for id, count in pairs(spent) do
			data.materials[id] -= count
		end
		data.companions[index] = evolved
		noteText = reason
		speciesId = evolved.species
		return nil
	end)
	if not saved then
		return fail(err or "Could not evolve.")
	end
	return {
		ok = true,
		name = noteText,
		species = speciesId,
		profile = DataService.snapshot(player),
	}
end

function WildCaptureService.resolve(player: Player, encounter: any)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return fail("Capture needs a player.")
	end
	if type(encounter) ~= "table" or type(encounter.action) ~= "string" then
		return fail("Unknown capture action.")
	end
	if encounter.action == "note" then
		return note(player, encounter)
	end
	if encounter.action == "tame" then
		return tame(player, encounter)
	end
	if encounter.action == "boss" then
		return boss(player, encounter)
	end
	if encounter.action == "evolve" then
		return evolve(player, encounter)
	end
	return fail("Unknown capture action.")
end

function WildCaptureService.noteShiny(player: Player, enemyId: string, roll: number?)
	return WildCaptureService.resolve(player, {
		action = "note",
		enemyId = enemyId,
		roll = roll,
	})
end

function WildCaptureService.tame(player: Player, encounter: any)
	local payload = if type(encounter) == "table" then encounter else {}
	local defeated = true
	if payload.defeated == false then
		defeated = false
	end
	return WildCaptureService.resolve(player, {
		action = "tame",
		enemyId = payload.enemyId,
		defeated = defeated,
		roll = payload.roll,
	})
end

function WildCaptureService.grantBoss(player: Player, encounter: any)
	local payload = if type(encounter) == "table" then encounter else {}
	return WildCaptureService.resolve(player, {
		action = "boss",
		bossId = payload.bossId,
		enemyId = payload.enemyId,
		roll = payload.roll,
	})
end

function WildCaptureService.evolve(player: Player, uid: string)
	return WildCaptureService.resolve(player, {
		action = "evolve",
		uid = uid,
	})
end

-- Client entry once Ghost binds the Capture remote. Rolls stay on the server.
function WildCaptureService.handle(player: Player, action: any, payload: any)
	if action == "tame" then
		local enemyId = nil
		if type(payload) == "table" then
			enemyId = payload.enemyId
		end
		return WildCaptureService.tame(player, {
			enemyId = enemyId,
			defeated = true,
		})
	end
	if action == "evolve" then
		local uid = nil
		if type(payload) == "table" then
			uid = payload.uid
		end
		if type(uid) ~= "string" then
			return fail("Pick a companion.")
		end
		return WildCaptureService.evolve(player, uid)
	end
	return fail("Unknown capture action.")
end

function WildCaptureService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return WildCaptureService
