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

	A reserved-server teleport saves and clears this server's lock before
	TeleportAsync runs. PlayerRemoving after that does not write the profile
	again and does not take the lock back. If the save fails, the teleport
	is cancelled and the player stays here with the lock still held.

	TeleportAsync can return and still fail. TeleportInitFailed then reclaims
	the lock when this server still has the player, and restores the loaded
	record so mutate works. If reclaim reports the lock was taken, the player
	is kicked to rejoin. Released is set before closing clears, so
	PlayerRemoving and BindToClose cannot write over a hop that already
	freed the lock. A second queue while closing is in flight does not
	teleport again.

	save() writes that profile now, including when the adapter is the
	in-memory store. savePair() writes two profiles and, if either write
	fails, puts both backups back and writes those too. Trades use it so a
	crash cannot keep one side of a swap.

	Studio with API access off can leave UpdateAsync yielded. GetProfile
	then answered "Profile is still loading." forever. A timed-out or thrown
	store read in Studio becomes an in-memory session profile and a warn.
	That profile is not written back to the DataStore.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CallBudget = require(ReplicatedStorage.Shared.CallBudget)
local ProfileLoad = require(ReplicatedStorage.Shared.ProfileLoad)
local Schema = require(ReplicatedStorage.Shared.Schema)
local SessionLock = require(ReplicatedStorage.Shared.SessionLock)
local StoreAdapter = require(script.Parent.StoreAdapter)

local DataService = {}

local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 5
local LOAD_RETRY_SECONDS = 2
local TELEPORT_SAVE_FAILED =
	"Could not save your profile, so the raid teleport was cancelled. You are still on this server."

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
	-- Set for the whole save-and-teleport yield. Autosave and PlayerRemoving
	-- must not start a second write while this is true.
	closing: boolean,
	ephemeral: boolean,
	error: string?,
	-- Bumped at the start of each mutate. A restore is valid only while
	-- this is still the generation that copied the backup.
	mutateGeneration: number,
}

type Listener = (Player, any, boolean) -> ()

type HopWatch = {
	conn: any,
	settled: boolean,
	initFailed: boolean,
	initError: string,
}

local records: { [Player]: Record } = {}
local hopWatch: { [Player]: HopWatch } = {}
local listeners: { Listener } = {}
-- Set synchronously so PlayerAdded and the existing-player loop cannot both load.
local playerStarted: { [Player]: boolean } = {}
local adapter: StoreAdapter.Adapter? = nil
local persistent = false
local started = false
-- Set before shutdown spawns releases. Autosave must not start a write
-- after this, and release must not wait on a teleport.
local shuttingDown = false

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
	local saving = persistent and record.ephemeral ~= true
	for _, listener in ipairs(listeners) do
		task.spawn(listener, player, snapshot, saving)
	end
end

function DataService.isPersistent(player: Player?): boolean
	if player ~= nil then
		local record = records[player]
		if record ~= nil and record.ephemeral == true then
			return false
		end
	end
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

function DataService.waitFor(player: Player, timeout: number): (Schema.ProfileData?, string?)
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local data = DataService.get(player)
		if data ~= nil then
			return data, nil
		end
		local record = records[player]
		if record ~= nil and record.failed then
			return nil, record.error or "Could not load your Shardfall profile. Rejoin."
		end
		task.wait(0.1)
	end
	local record = records[player]
	if record ~= nil and record.failed then
		return nil, record.error or "Could not load your Shardfall profile. Rejoin."
	end
	return nil, nil
end

function DataService.mutate(
	player: Player,
	mutator: (Schema.ProfileData) -> string?
): (boolean, string?)
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return false, "Profile is not loaded."
	end
	if record.closing then
		return false, "Profile is closing for a teleport."
	end
	record.mutateGeneration += 1
	local generation = record.mutateGeneration
	local backup = Schema.deepCopy(record.data)
	local ok, result = pcall(mutator, record.data)
	local restore = ProfileLoad.mutateShouldRestore(generation, record.mutateGeneration)
	if not ok then
		if restore then
			record.data = backup
		end
		warn("[Shardfall] Profile mutate failed:", result)
		return false, "Could not update your profile."
	end
	if result ~= nil then
		if restore then
			record.data = backup
		end
		return false, result
	end
	notify(player)
	return true, nil
end

local function write(record: Record, releaseLock: boolean): (boolean, string)
	if record.ephemeral == true then
		return false, "unloaded"
	end
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

function DataService.save(player: Player): (boolean, string?)
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return false, "Profile is not loaded."
	end
	if record.closing then
		return false, "Profile is closing for a teleport."
	end
	if record.ephemeral then
		return true, nil
	end
	local ok, reason = write(record, false)
	if not ok then
		warn("[Shardfall] Profile save failed:", reason)
		return false, reason
	end
	notify(player)
	return true, nil
end

function DataService.replace(player: Player, data: any): boolean
	local record = records[player]
	if record == nil or not record.loaded or record.released or record.closing then
		return false
	end
	record.data = Schema.deepCopy(data)
	notify(player)
	return true
end

-- Writes both profiles. A failed write puts both backups back in memory and
-- writes those, so a store that accepted only the first profile is undone.
function DataService.savePair(
	first: Player,
	second: Player,
	firstBackup: any,
	secondBackup: any
): (boolean, string?)
	local okFirst, whyFirst = DataService.save(first)
	local okSecond, whySecond = DataService.save(second)
	if okFirst and okSecond then
		return true, nil
	end
	DataService.replace(first, firstBackup)
	DataService.replace(second, secondBackup)
	local undoFirst = DataService.save(first)
	local undoSecond = DataService.save(second)
	if not undoFirst or not undoSecond then
		warn("[Shardfall] Could not write the restored profiles back.")
	end
	return false, whyFirst or whySecond
end

-- The load that timed out may already have claimed. Clear that lock and
-- leave the stored profile in place.
local function clearOwnedLock(key: string)
	if not persistent then
		return
	end
	local ok, err = pcall(function()
		ProfileLoad.releaseOwned(currentAdapter(), key, serverId)
	end)
	if not ok then
		warn("[Shardfall] Could not release the lock after a failed load:", err)
	end
end

local function failLoad(record: Record, message: string): (boolean, string)
	record.loading = false
	record.failed = true
	record.error = message
	clearOwnedLock(record.key)
	return false, message
end

local function sessionFallback(record: Record, player: Player, why: any): (boolean, string?)
	local migrated = Schema.migrate(nil)
	warn(
		string.format(
			"[Shardfall] DataStore load failed for %s (%s). This Studio session uses a memory profile and will NOT save.",
			player.Name,
			tostring(why)
		)
	)
	if migrated == nil then
		return failLoad(record, "Could not load your Shardfall profile. Rejoin.")
	end
	clearOwnedLock(record.key)
	record.data = migrated
	record.loaded = true
	record.loading = false
	record.failed = false
	record.ephemeral = true
	record.error = nil
	print(
		string.format(
			"[Shardfall] Loaded %s (%d) via memory (not saved)",
			player.Name,
			player.UserId
		)
	)
	return true, nil
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
		closing = false,
		ephemeral = false,
		mutateGeneration = 0,
	}
	records[player] = record
	local studio = RunService:IsStudio()
	-- Per player load, not process-wide. Another player's attempt must
	-- not cancel this one. Bumping generation drops only this token.
	local generation = 0
	local function dropAttempt(token: number)
		if generation == token then
			generation += 1
		end
	end

	for attempt = 1, LOAD_ATTEMPTS do
		if record.released or player.Parent ~= Players then
			return failLoad(record, "Left before the profile loaded.")
		end

		generation += 1
		local token = generation
		local watch: ProfileLoad.Attempt = {
			token = token,
			current = function(): number
				return generation
			end,
		}
		local reason = "error"
		local callOk, outcome = CallBudget.run(CallBudget.DATASTORE_SECONDS, function()
			return ProfileLoad.open(
				currentAdapter(),
				key,
				os.time(),
				serverId,
				placeId,
				SessionLock.TIMEOUT_SECONDS,
				watch
			)
		end)

		if not callOk then
			-- CallBudget already returned. The spawned UpdateAsync can
			-- still run its transform. Drop the token before any yield
			-- so that transform cannot claim the lock or rewrite lastSeen.
			dropAttempt(token)
			reason = "error"
			warn(
				string.format(
					"[Shardfall] Load attempt %d failed for %s: %s",
					attempt,
					player.Name,
					tostring(outcome)
				)
			)
			if studio or not persistent then
				return sessionFallback(record, player, outcome)
			end
		elseif type(outcome) == "table" and outcome.session == true then
			reason = "error"
			warn(
				string.format(
					"[Shardfall] Load attempt %d failed for %s: %s",
					attempt,
					player.Name,
					tostring(outcome.error)
				)
			)
			if studio or not persistent then
				if type(outcome.data) == "table" then
					clearOwnedLock(record.key)
					record.data = outcome.data
					record.loaded = true
					record.loading = false
					record.failed = false
					record.ephemeral = true
					record.error = nil
					warn(
						string.format(
							"[Shardfall] DataStore load failed for %s (%s). This Studio session uses a memory profile and will NOT save.",
							player.Name,
							tostring(outcome.error)
						)
					)
					print(
						string.format(
							"[Shardfall] Loaded %s (%d) via memory (not saved)",
							player.Name,
							player.UserId
						)
					)
					return true, nil
				end
				return sessionFallback(record, player, outcome.error)
			end
		elseif type(outcome) == "table" and outcome.data ~= nil then
			record.data = outcome.data
			record.loaded = true
			record.loading = false
			-- Leave during the yield: the lock is already ours, and release()
			-- will have skipped the write because loaded was still false.
			-- Clear it here so the next server does not wait out the timeout.
			if record.released or player.Parent ~= Players then
				if not record.ephemeral then
					write(record, true)
				end
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
		elseif type(outcome) == "table" and type(outcome.reason) == "string" then
			reason = outcome.reason
		end

		local retryable = reason == "busy" or reason == "error"
		if retryable and attempt < LOAD_ATTEMPTS then
			task.wait(LOAD_RETRY_SECONDS)
			continue
		end

		if reason == "newer" then
			return failLoad(
				record,
				"This server is out of date for your Shardfall profile. Rejoin shortly."
			)
		end
		if reason == "corrupt" then
			return failLoad(
				record,
				"Your Shardfall profile could not be read. It was not overwritten."
			)
		end
		if reason == "busy" then
			return failLoad(
				record,
				"Your data is still open on another server. Rejoin in a moment."
			)
		end
		return failLoad(record, "Could not load your Shardfall profile. Rejoin.")
	end

	return failLoad(record, "Could not load your Shardfall profile. Rejoin.")
end

-- Released is published before closing clears. PlayerRemoving and
-- BindToClose wait on closing. If they wake early they save again and
-- either steal a freed lock or kick a hop that already succeeded.
local function settleRecord(record: Record, released: boolean, loaded: boolean)
	record.released = released
	record.loaded = loaded
	record.closing = false
end

local function disconnectHop(player: Player)
	local watch = hopWatch[player]
	if watch == nil then
		return
	end
	-- A callback already queued must not reclaim after the player leaves
	-- or after a newer hop replaces this watch.
	watch.settled = false
	hopWatch[player] = nil
	if watch.conn ~= nil then
		watch.conn:Disconnect()
		watch.conn = nil
	end
end

-- The hop already cleared the lock. Take it back when we still can, then
-- follow ProfileLoad.failedHop. closing stays set across the yield so a
-- leave or a shutdown waits instead of writing the freed document.
local function recoverFailedHop(player: Player, record: Record): string
	local again = ProfileLoad.reclaim(
		currentAdapter(),
		record.key,
		os.time(),
		serverId,
		placeId,
		SessionLock.TIMEOUT_SECONDS,
		record.data
	)
	local stillHere = player.Parent == Players and records[player] == record
	local action = ProfileLoad.failedHop(stillHere, again.ok == true)
	disconnectHop(player)
	if action == "restore" then
		settleRecord(record, false, true)
		notify(player)
		return "retry-here"
	end
	if action == "release" then
		-- PlayerRemoving is waiting on closing and writes the clear.
		settleRecord(record, false, true)
		return "closed"
	end
	if action == "kick" then
		settleRecord(record, true, false)
		warn(
			"[Shardfall] Teleport failed and the profile lock moved for",
			player.Name,
			again.reason,
			again.error
		)
		if player.Parent == Players then
			player:Kick(ProfileLoad.HOP_REJOIN)
		end
		return "closed"
	end
	settleRecord(record, true, false)
	return "closed"
end

-- Connect before TeleportAsync so a failure during the yield is visible.
-- TeleportInitFailed can also arrive after we have already reported success.
local function armHop(player: Player, record: Record): HopWatch
	disconnectHop(player)
	local watch: HopWatch = {
		conn = nil,
		settled = false,
		initFailed = false,
		initError = "TeleportInitFailed",
	}
	hopWatch[player] = watch
	local TeleportService = game:GetService("TeleportService")
	watch.conn = TeleportService.TeleportInitFailed:Connect(function(who, _result, message)
		if who ~= player then
			return
		end
		watch.initFailed = true
		if type(message) == "string" and message ~= "" then
			watch.initError = message
		end
		if watch.settled ~= true then
			return
		end
		watch.settled = false
		if player.Parent ~= Players or records[player] ~= record or record.closing then
			return
		end
		-- Ephemeral sessions never cleared a DataStore lock. Reclaim would
		-- write this memory profile over a real save.
		if record.ephemeral or record.released ~= true then
			return
		end
		record.closing = true
		task.spawn(function()
			recoverFailedHop(player, record)
		end)
	end)
	return watch
end

-- Connect before TeleportAsync so a failure during the yield is visible,
-- then yield once after it returns. TeleportInitFailed can also arrive
-- after we have already reported success; that path reclaims below.
local function beginHopWatch(player: Player, record: Record, teleport: () -> ()): () -> ()
	local watch = armHop(player, record)
	return function()
		teleport()
		task.wait()
		if watch.initFailed then
			error(watch.initError)
		end
	end
end

function DataService.release(player: Player)
	disconnectHop(player)
	local record = records[player]
	if record == nil then
		return
	end
	-- A teleport handoff is already the final write. Wait it out, then drop
	-- the record without saving again. A second write would either replay
	-- stale memory or, if it claimed, take the lock back from the raid server.
	while record.closing do
		-- Shutdown's budget belongs to the final release, not a teleport wait.
		if shuttingDown then
			break
		end
		task.wait(0.05)
	end
	if record.released then
		playerStarted[player] = false
		records[player] = nil
		return
	end
	local wasLoaded = record.loaded
	local ephemeral = record.ephemeral == true
	record.released = true
	playerStarted[player] = false
	record.loaded = false
	if ProfileLoad.maySave(wasLoaded, ephemeral) then
		local ok, reason = write(record, true)
		if not ok then
			warn("[Shardfall] Final save failed for", player.Name, reason)
		end
	end
	records[player] = nil
end

-- "teleported" means the lock is clear and PlayerRemoving must not write.
-- "kept" means the save failed and the player is still locked here.
-- "retry-here" means the hop failed and the lock was claimed back.
-- "closed" means the hop failed and another server already holds the profile.
-- "closing" means a hop is already in flight. No second teleport.
function DataService.teleportHold(player: Player): string?
	local record = records[player]
	if record ~= nil and record.closing then
		return ProfileLoad.TELEPORT_ALREADY
	end
	local watch = hopWatch[player]
	if watch ~= nil and watch.settled == true then
		return ProfileLoad.TELEPORT_ALREADY
	end
	return nil
end

function DataService.releaseForTeleport(player: Player, teleport: () -> ()): (string, string?)
	local record = records[player]
	if record == nil or not record.loaded or record.released then
		return "kept", TELEPORT_SAVE_FAILED
	end
	if record.closing then
		return "closing", ProfileLoad.TELEPORT_ALREADY
	end
	local watched = beginHopWatch(player, record, teleport)
	if record.ephemeral then
		record.closing = true
		local callOk, callErr = pcall(watched)
		local watch = hopWatch[player]
		local failed = (not callOk) or (watch ~= nil and watch.initFailed == true)
		if not failed and watch ~= nil then
			watch.settled = true
			settleRecord(record, false, true)
			return "teleported", nil
		end
		disconnectHop(player)
		settleRecord(record, false, true)
		warn("[Shardfall] Teleport failed for", player.Name, callErr)
		return "retry-here", nil
	end
	record.closing = true
	local callOk, outcome: any = pcall(function()
		return ProfileLoad.handoff(
			currentAdapter(),
			record.key,
			os.time(),
			serverId,
			placeId,
			SessionLock.TIMEOUT_SECONDS,
			record.data,
			watched
		)
	end)
	local watch = hopWatch[player]
	local initFailed = watch ~= nil and watch.initFailed == true
	if not callOk or type(outcome) ~= "table" then
		disconnectHop(player)
		settleRecord(record, false, true)
		warn("[Shardfall] Teleport save failed for", player.Name, outcome)
		return "kept", TELEPORT_SAVE_FAILED
	end
	local handoff = outcome :: ProfileLoad.Handoff
	if handoff.teleported == true and initFailed then
		-- TeleportAsync returned and the failure was already flagged. The
		-- lock is clear; handoff did not reclaim because teleport did not throw.
		local status = recoverFailedHop(player, record)
		if status == "retry-here" then
			return "retry-here", nil
		end
		return "closed", ProfileLoad.HOP_REJOIN
	end
	if handoff.teleported == true then
		if watch ~= nil then
			watch.settled = true
		end
		settleRecord(record, true, false)
		return "teleported", nil
	end
	disconnectHop(player)
	if handoff.reason == "teleport" then
		settleRecord(record, false, true)
		warn("[Shardfall] Teleport failed for", player.Name, handoff.error)
		return "retry-here", nil
	end
	if handoff.reason == "stolen" then
		settleRecord(record, true, false)
		warn(
			"[Shardfall] Teleport failed and the profile lock moved for",
			player.Name,
			handoff.error
		)
		if player.Parent == Players then
			player:Kick(ProfileLoad.HOP_REJOIN)
		end
		return "closed", ProfileLoad.HOP_REJOIN
	end
	settleRecord(record, false, true)
	warn("[Shardfall] Teleport save failed for", player.Name, handoff.reason, handoff.error)
	return "kept", TELEPORT_SAVE_FAILED
end

-- Save every seated profile, then call teleport once. A thrown teleport or
-- any TeleportInitFailed rolls the whole party back. Players still here are
-- reclaimed. Players who already left stay released so the other server can
-- load them, and the caller sends those players home.
function DataService.releasePartyForTeleport(
	players: { Player },
	teleport: () -> ()
): (string, { Player })
	local empty: { Player } = {}
	if type(players) ~= "table" or #players == 0 then
		return "kept", empty
	end
	local seen: { [Player]: boolean } = {}
	local ephemeral = false
	local mixed = false
	for _, player in ipairs(players) do
		if typeof(player) ~= "Instance" or seen[player] == true then
			return "kept", empty
		end
		seen[player] = true
		local record = records[player]
		if record == nil or not record.loaded or record.released then
			return "kept", empty
		end
		if record.closing then
			return "closing", empty
		end
		if record.ephemeral then
			ephemeral = true
		end
	end
	for _, player in ipairs(players) do
		local record = records[player]
		if record ~= nil and record.ephemeral ~= ephemeral then
			mixed = true
		end
	end
	if mixed then
		return "kept", empty
	end
	for _, player in ipairs(players) do
		local record = records[player]
		if record ~= nil then
			record.closing = true
		end
	end
	if not ephemeral then
		local released: { Player } = {}
		for _, player in ipairs(players) do
			local record = records[player]
			if record == nil then
				for _, waiting in ipairs(players) do
					local waitingRecord = records[waiting]
					if waitingRecord ~= nil and waitingRecord.closing then
						settleRecord(waitingRecord, false, true)
					end
				end
				return "kept", empty
			end
			local result = ProfileLoad.release(
				currentAdapter(),
				record.key,
				os.time(),
				serverId,
				placeId,
				SessionLock.TIMEOUT_SECONDS,
				record.data
			)
			if not result.ok then
				for _, done in ipairs(released) do
					local doneRecord = records[done]
					if doneRecord ~= nil then
						-- Same as a failed solo hop. A stolen reclaim must
						-- not mark the profile loaded: mutate would take
						-- loot, and the next autosave would see lost.
						recoverFailedHop(done, doneRecord)
					end
				end
				for _, waiting in ipairs(players) do
					local waitingRecord = records[waiting]
					if waitingRecord ~= nil and waitingRecord.closing then
						settleRecord(waitingRecord, false, true)
					end
				end
				warn("[Shardfall] Party teleport save failed for", player.Name, result.reason)
				return "kept", empty
			end
			table.insert(released, player)
		end
	end
	local watches: { [Player]: HopWatch } = {}
	for _, player in ipairs(players) do
		local record = records[player]
		if record ~= nil then
			watches[player] = armHop(player, record)
		end
	end
	local callOk, callErr = pcall(teleport)
	task.wait()
	local results = {}
	for index, player in ipairs(players) do
		local watch = watches[player]
		local failed = (not callOk) or (watch ~= nil and watch.initFailed == true)
		results[index] = if failed then "fail" else "ok"
	end
	local failedAny = not callOk
	for _, result in ipairs(results) do
		if result ~= "ok" then
			failedAny = true
		end
	end
	if failedAny then
		local away: { Player } = {}
		for _, player in ipairs(players) do
			local record = records[player]
			if record == nil then
				continue
			end
			if player.Parent == Players then
				if ephemeral then
					disconnectHop(player)
					settleRecord(record, false, true)
				else
					recoverFailedHop(player, record)
				end
			else
				local watch = watches[player]
				if watch ~= nil then
					watch.settled = true
				end
				if ephemeral then
					settleRecord(record, false, true)
				else
					settleRecord(record, true, false)
				end
				table.insert(away, player)
			end
		end
		warn("[Shardfall] Party teleport failed", callErr)
		return "rolled-back", away
	end
	for _, player in ipairs(players) do
		local record = records[player]
		local watch = watches[player]
		if watch ~= nil then
			watch.settled = true
		end
		if record ~= nil then
			if ephemeral then
				settleRecord(record, false, true)
			else
				settleRecord(record, true, false)
			end
		end
	end
	return "teleported", empty
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
		if shuttingDown then
			return
		end
		local snapshot = {}
		for player, record in pairs(records) do
			table.insert(snapshot, { player = player, record = record })
		end
		for _, entry in ipairs(snapshot) do
			if shuttingDown then
				break
			end
			local player = entry.player
			local record = entry.record
			if
				ProfileLoad.maySave(record.loaded, record.ephemeral)
				and not record.released
				and not record.closing
				and player.Parent == Players
			then
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
		shuttingDown = true
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				local ok, err = pcall(DataService.release, player)
				if not ok then
					warn("[Shardfall] Shutdown save failed for", player.Name, err)
				end
				pending -= 1
			end)
		end
		-- Wait out in-flight writes until the engine's shutdown budget.
		-- Returning at 25 seconds used to drop a slow UpdateAsync and leave
		-- that player's lock held.
		local shutdownAt = os.clock()
		while ProfileLoad.shutdownStillWaiting(pending, os.clock() - shutdownAt) do
			task.wait(0.1)
		end
	end)

	task.spawn(autosave)
end

return DataService
