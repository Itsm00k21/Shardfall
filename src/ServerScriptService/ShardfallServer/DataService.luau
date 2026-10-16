--!strict

--[[
	Loads one profile per player and keeps it saved.

	Read SessionLock.luau for the rules. This file only applies them inside
	UpdateAsync and keeps the in-memory copy the rest of the game mutates.

	Autosave is every AUTOSAVE_SECONDS (60). A crash can lose up to one
	interval. That is the same tradeoff ProfileStore makes (its default is
	300 seconds, to spend fewer DataStore requests). ProfileStore is the
	version to switch to when you need gifting or fast handoff between
	servers: https://madstudioroblox.github.io/ProfileStore/
	Callers use DataService.mutate / snapshot / release, so the swap stays
	local to this module.

	Mutations change memory immediately and ride the next autosave, plus a
	final save when the player leaves. mutate() copies the profile first and
	restores it if the callback returns an error string or throws, so a
	rejected roll cannot eat a token.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Schema)
local SessionLock = require(ReplicatedStorage.Shared.SessionLock)
local StoreAdapter = require(script.Parent.StoreAdapter)

local DataService = {}

local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 5
local LOAD_RETRY_SECONDS = 2

-- Studio play sessions often have an empty JobId. A GUID still makes two
-- Studio servers look like different owners to the lock.
local serverId = if game.JobId ~= ""
	then game.JobId
	else "studio-" .. HttpService:GenerateGUID(false)
local placeId = game.PlaceId

type Record = {
	key: string,
	data: Schema.ProfileData,
	loaded: boolean,
	loading: boolean,
	failed: boolean,
	released: boolean,
}

type Listener = (Player, any, boolean) -> ()

local records: { [Player]: Record } = {}
local listeners: { Listener } = {}
-- Set synchronously so PlayerAdded and the existing-player loop cannot both load.
local playerStarted: { [Player]: boolean } = {}
local adapter: StoreAdapter.Adapter? = nil
local persistent = false
local started = false

local function currentAdapter(): StoreAdapter.Adapter
	local current = adapter
	assert(current ~= nil, "DataService.start was not called")
	return current
end

local function notify(player: Player)
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return
	end
	local snapshot = Schema.snapshot(record.data)
	for _, listener in ipairs(listeners) do
		task.spawn(listener, player, snapshot, persistent)
	end
end

function DataService.isPersistent(): boolean
	return persistent
end

function DataService.onChanged(listener: Listener)
	table.insert(listeners, listener)
end

function DataService.snapshot(player: Player)
	local record = records[player]
	if record == nil or not record.loaded then
		return nil
	end
	return Schema.snapshot(record.data)
end

function DataService.get(player: Player): Schema.ProfileData?
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return nil
	end
	return record.data
end

function DataService.waitFor(player: Player, timeout: number): Schema.ProfileData?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local data = DataService.get(player)
		if data ~= nil then
			return data
		end
		local record = records[player]
		if record ~= nil and record.failed then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.mutate(
	player: Player,
	mutator: (Schema.ProfileData) -> string?
): (boolean, string?)
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return false, "Profile is not loaded."
	end
	local backup = Schema.deepCopy(record.data)
	local ok, result = pcall(mutator, record.data)
	if not ok then
		record.data = backup
		warn("[Shardfall] Profile mutate failed:", result)
		return false, "Could not update your profile."
	end
	if result ~= nil then
		record.data = backup
		return false, result
	end
	notify(player)
	return true, nil
end

local function write(record: Record, releaseLock: boolean): (boolean, string)
	local outcome = "unwritten"
	local store = currentAdapter()
	local callOk, callErr = pcall(function()
		store:updateAsync(record.key, function(document)
			local saved, reason = SessionLock.trySave(
				if type(document) == "table" then document else nil,
				os.time(),
				serverId,
				placeId,
				SessionLock.TIMEOUT_SECONDS,
				Schema.deepCopy(record.data),
				releaseLock
			)
			outcome = reason
			return saved
		end)
	end)
	if not callOk then
		return false, "error:" .. tostring(callErr)
	end
	if outcome ~= "saved" then
		return false, outcome
	end
	return true, "saved"
end

local function load(player: Player): (boolean, string?)
	if records[player] ~= nil then
		return false, "Profile is already loading."
	end

	local key = "Player_" .. tostring(player.UserId)
	local record: Record = {
		key = key,
		data = Schema.template(),
		loaded = false,
		loading = true,
		failed = false,
		released = false,
	}
	records[player] = record

	for attempt = 1, LOAD_ATTEMPTS do
		if record.released or player.Parent ~= Players then
			record.failed = true
			record.loading = false
			return false, "Left before the profile loaded."
		end

		local claimedData: Schema.ProfileData? = nil
		local reason = "error"
		local callOk, callErr = pcall(function()
			currentAdapter():updateAsync(key, function(document)
				local source = nil
				if type(document) == "table" then
					source = Schema.deepCopy(document.Data)
				end
				local migrated, migrateErr = Schema.migrate(source)
				if migrated ~= nil then
					local Progression =
						require(game:GetService("ReplicatedStorage").Shared.Progression)
					Progression.applyReturn(migrated, os.time())
				end
				if migrated == nil then
					reason = migrateErr or "corrupt"
					claimedData = nil
					return nil
				end
				local written, claimReason = SessionLock.tryClaim(
					if type(document) == "table" then document else nil,
					os.time(),
					serverId,
					placeId,
					SessionLock.TIMEOUT_SECONDS,
					Schema.deepCopy(migrated)
				)
				reason = claimReason
				if written == nil then
					claimedData = nil
					return nil
				end
				claimedData = migrated
				return written
			end)
		end)

		if not callOk then
			reason = "error"
			warn(
				string.format(
					"[Shardfall] Load attempt %d failed for %s: %s",
					attempt,
					player.Name,
					tostring(callErr)
				)
			)
		end

		if claimedData ~= nil then
			record.data = claimedData
			record.loaded = true
			record.loading = false
			-- Leave during the yield: the lock is already ours, and release()
			-- will have skipped the write because loaded was still false.
			-- Clear it here so the next server does not wait out the timeout.
			if record.released or player.Parent ~= Players then
				write(record, true)
				records[player] = nil
				return false, "Left before the profile loaded."
			end
			print(
				string.format(
					"[Shardfall] Loaded %s (%d) via %s",
					player.Name,
					player.UserId,
					if persistent then "DataStore" else "memory (not saved)"
				)
			)
			return true, nil
		end

		local retryable = reason == "busy" or reason == "error"
		if retryable and attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_SECONDS)
			continue
		end

		record.loading = false
		record.failed = true
		if reason == "newer" then
			return false, "This server is out of date for your Shardfall profile. Rejoin shortly."
		end
		if reason == "corrupt" then
			return false, "Your Shardfall profile could not be read. It was not overwritten."
		end
		if reason == "busy" then
			return false, "Your data is still open on another server. Rejoin in a moment."
		end
		return false, "Could not load your Shardfall profile. Rejoin."
	end

	record.failed = true
	record.loading = false
	return false, "Could not load your Shardfall profile. Rejoin."
end

function DataService.release(player: Player)
	local record = records[player]
	if record == nil or record.released then
		return
	end
	record.released = true
	playerStarted[player] = false
	local wasLoaded = record.loaded
	record.loaded = false
	if wasLoaded then
		local ok, reason = write(record, true)
		if not ok and reason ~= "missing" then
			warn("[Shardfall] Final save failed for", player.Name, reason)
		end
	end
	records[player] = nil
end

local function onPlayer(player: Player)
	-- PlayerAdded can race the "players already here" loop in Studio.
	-- The flag is set before the spawn, because the record itself is created
	-- later, inside the spawned load.
	if playerStarted[player] then
		return
	end
	playerStarted[player] = true
	task.spawn(function()
		local ok, err = load(player)
		if not ok then
			if player.Parent == Players then
				player:Kick(err or "Could not load your Shardfall profile.")
			end
			return
		end
		if player.Parent ~= Players then
			DataService.release(player)
			return
		end
		notify(player)
	end)
end

local function autosave()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		local snapshot = {}
		for player, record in pairs(records) do
			table.insert(snapshot, { player = player, record = record })
		end
		for _, entry in ipairs(snapshot) do
			local player = entry.player
			local record = entry.record
			if record.loaded and not record.released and player.Parent == Players then
				local ok, reason = write(record, false)
				if not ok and reason == "lost" then
					record.loaded = false
					warn("[Shardfall] Lost the session lock for", player.Name)
					if player.Parent == Players then
						player:Kick(
							"Your Shardfall session moved to another server. Rejoin to keep playing."
						)
					end
				elseif not ok then
					warn("[Shardfall] Autosave failed for", player.Name, reason)
				end
			end
		end
	end
end

function DataService.start()
	if started then
		return
	end
	started = true

	local connected, probeErr = StoreAdapter.connect()
	adapter = connected
	persistent = connected.persistent
	if not persistent then
		warn("[Shardfall] DataStores are unavailable (" .. tostring(probeErr) .. ").")
		warn("[Shardfall] This session keeps profiles in memory and will NOT save.")
		warn(
			"[Shardfall] To save: publish the place, then Game Settings → Security → Enable Studio Access to API Services, then press Play again."
		)
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	task.spawn(autosave)
end

return DataService
