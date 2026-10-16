--!strict

--[[
	Server rolls for shiny tames, boss pets, and evolution.

	DungeonService calls noteShiny when an enemy spawns, markDefeated when
	that shiny dies, grantBoss when Grandmother Gnarl falls, and clear when
	the run ends. noteShiny stores a spawned mark. markDefeated turns it
	into a defeated mark with a WildCapture.TAME_WINDOW deadline. The client
	tame spends only a defeated, unexpired mark. It cannot send the shiny
	flag, the roll, or a defeated bit. handle() ignores all three.

	A miss (no charm, or a losing roll) still spends the shiny. Marks are
	per player. Remotes, RateLimiter, and init are Ghost's. start() drops
	marks when the player leaves. setClock and setMutate let Lune drive the
	window without DataService. They do nothing once DataService is loaded.
]]

local PetEvolution: any
local WildCapture: any
local HttpService: any = nil
local Players: any = nil
local DataService: any = nil

if game ~= nil then
	HttpService = game:GetService("HttpService")
	Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	DataService = require(script.Parent.DataService)
	PetEvolution = require(ReplicatedStorage.Shared.PetEvolution)
	WildCapture = require(ReplicatedStorage.Shared.WildCapture)
else
	PetEvolution = require("../../ReplicatedStorage/Shared/PetEvolution")
	WildCapture = require("../../ReplicatedStorage/Shared/WildCapture")
end

local WildCaptureService = {}

type Mark = {
	state: "spawned" | "defeated",
	deadline: number,
}

type Mutator = (any) -> string?
type MutateFn = (any, Mutator) -> (boolean, string?)

local pending: { [any]: { [string]: Mark } } = {}
local started = false
local issued = 0
local clock: () -> number = os.clock
local mutateOverride: MutateFn? = nil

local function fail(message: string)
	return { ok = false, error = message }
end

local function isPlayer(value: any): boolean
	if typeof(value) == "Instance" then
		return (value :: any):IsA("Player")
	end
	-- Lune has no Player instances. Production always has DataService.
	if DataService ~= nil then
		return false
	end
	return type(value) == "table" and value.ClassName == "Player"
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

local function newUid(): string
	if HttpService ~= nil then
		return HttpService:GenerateGUID(false)
	end
	issued += 1
	return string.format("wild-%d", issued)
end

local function insertCompanion(data: any, pet: any)
	pet.uid = newUid()
	if type(data.companions) ~= "table" then
		data.companions = {}
	end
	table.insert(data.companions, pet)
end

local function putMark(player: any, enemyId: string, mark: Mark)
	local marked = pending[player]
	if marked == nil then
		local fresh: { [string]: Mark } = {}
		marked = fresh
		pending[player] = fresh
	end
	marked[enemyId] = mark
end

-- Spends a defeated mark that is still inside the window. Spawned and
-- expired marks stay where they are.
local function spendDefeated(player: any, enemyId: string): (Mark?, string?)
	local marked = pending[player]
	local mark = if marked ~= nil then marked[enemyId] else nil
	if mark == nil then
		return nil, "No shiny is here."
	end
	if mark.state ~= "defeated" then
		return nil, "Defeat the shiny first."
	end
	if clock() >= mark.deadline then
		return nil, "The shiny slipped away."
	end
	marked[enemyId] = nil
	if next(marked) == nil then
		pending[player] = nil
	end
	return mark, nil
end

local function mutate(player: any, mutator: Mutator): (boolean, string?)
	local override = mutateOverride
	if override ~= nil then
		return override(player, mutator)
	end
	if DataService == nil then
		return false, "Profile is not loaded."
	end
	return DataService.mutate(player, mutator)
end

local function snapshotOf(player: any): any
	if DataService == nil then
		return nil
	end
	return DataService.snapshot(player)
end

local function note(player: any, encounter: any)
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
		putMark(player, enemyId, { state = "spawned", deadline = 0 })
	end
	return { ok = true, shiny = shiny, enemyId = enemyId }
end

local function tame(player: any, encounter: any)
	local enemyId = key(encounter.enemyId)
	if enemyId == nil then
		return fail("Nothing to capture.")
	end
	local spent, blocked = spendDefeated(player, enemyId)
	if spent == nil then
		return fail(blocked or "No shiny is here.")
	end
	local captureRoll = unitRoll(encounter.roll)
	if captureRoll == nil then
		captureRoll = math.random()
	end
	local caughtName = ""
	local caughtSpecies = ""
	local saved, err = mutate(player, function(data)
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
		putMark(player, enemyId, spent)
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
		profile = snapshotOf(player),
	}
end

local function boss(player: any, encounter: any)
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
	local saved, err = mutate(player, function(data)
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
		profile = snapshotOf(player),
	}
end

local function evolve(player: any, encounter: any)
	local uid = uidOf(encounter.uid)
	if uid == nil then
		return fail("Pick a companion.")
	end
	local noteText = ""
	local speciesId = ""
	local saved, err = mutate(player, function(data)
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
		profile = snapshotOf(player),
	}
end

function WildCaptureService.resolve(player: Player, encounter: any)
	if not isPlayer(player) then
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

function WildCaptureService.markDefeated(player: Player, enemyId: string)
	if not isPlayer(player) then
		return fail("Capture needs a player.")
	end
	local id = key(enemyId)
	if id == nil or WildCapture.ENEMIES[id] == nil then
		return fail("That creature cannot be tamed.")
	end
	local marked = pending[player]
	local mark = if marked ~= nil then marked[id] else nil
	if mark == nil or mark.state ~= "spawned" then
		return fail("No shiny is here.")
	end
	mark.state = "defeated"
	mark.deadline = clock() + WildCapture.TAME_WINDOW
	return { ok = true, enemyId = id }
end

function WildCaptureService.tame(player: Player, encounter: any)
	local payload = if type(encounter) == "table" then encounter else {}
	return WildCaptureService.resolve(player, {
		action = "tame",
		enemyId = payload.enemyId,
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

function WildCaptureService.clear(player: Player)
	if not isPlayer(player) then
		return
	end
	pending[player] = nil
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

function WildCaptureService.setClock(fn: (() -> number)?)
	if DataService ~= nil then
		return
	end
	if fn == nil then
		clock = os.clock
	else
		clock = fn
	end
end

function WildCaptureService.setMutate(fn: MutateFn?)
	if DataService ~= nil then
		return
	end
	mutateOverride = fn
end

function WildCaptureService.start()
	if started then
		return
	end
	started = true
	if Players == nil then
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return WildCaptureService
