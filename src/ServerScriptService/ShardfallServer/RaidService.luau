--!strict

--[[
	Heartwood queue, premade board, and Practice Grove.

	A reserved server is attempted outside Studio. If that teleport cannot
	start, the same raid runs here as a solo test so Kevin can play it.

	Arriving on a reserved server starts the raid here. Queueing again from
	receive would reserve another server and hop in a loop. A second queue
	while the first hop is still saving does not reserve or teleport.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PracticeLoot = require(ReplicatedStorage.Shared.PracticeLoot)
local ProfileLoad = require(ReplicatedStorage.Shared.ProfileLoad)
local Raids = require(ReplicatedStorage.Shared.Raids)
local DataService = require(script.Parent.DataService)
local EchoParty = require(script.Parent.EchoParty)

local RaidService = {}

local listings: { any } = {}
local ranks: { { name: string, seconds: number } } = {}
local nextId = 0

local function reject(message: string)
	return { ok = false, error = message }
end

local function dungeon()
	return require(script.Parent.DungeonService)
end

function RaidService.leaderboard()
	local copy = {}
	for index, row in ipairs(ranks) do
		copy[index] = { name = row.name, seconds = row.seconds }
	end
	return copy
end

function RaidService.recordTime(name: string, seconds: number)
	if seconds < 1 then
		return
	end
	table.insert(ranks, { name = name, seconds = seconds })
	table.sort(ranks, function(a, b)
		return a.seconds < b.seconds
	end)
	while #ranks > 10 do
		table.remove(ranks)
	end
end

local function reservedCode(): string?
	if RunService:IsStudio() then
		return nil
	end
	local ok, code = pcall(function()
		return game:GetService("TeleportService"):ReserveServer(game.PlaceId)
	end)
	if ok and type(code) == "string" and code ~= "" then
		return code
	end
	return nil
end

local function launch(
	player: Player,
	difficulty: string,
	healer: boolean,
	wing: number,
	phase: number,
	practice: boolean
)
	local DungeonService = dungeon()
	-- Reserved server only. Studio and a failed hop stay a fresh fight.
	-- Practice Grove never shares, and a different difficulty stays separate.
	local share = practice ~= true
		and not ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	-- A previous launch that threw must not leave this player unhostable.
	DungeonService.holdEchoJoin(player, false)
	local held = false
	if share and DungeonService.echoHost(player, difficulty) ~= nil then
		-- Hold before enter. enter yields in RequestStreamAroundAsync, and
		-- the fresh fight must not become someone else's host during that wait.
		DungeonService.holdEchoJoin(player, true)
		held = true
	end
	local function clearHold()
		if held then
			DungeonService.holdEchoJoin(player, false)
		end
	end
	local enterOk, entered = pcall(DungeonService.enter, player, "heartwood", difficulty, practice)
	if not enterOk then
		clearHold()
		error(entered)
	end
	if entered.ok ~= true then
		clearHold()
		return entered
	end
	-- tuneRaid runs on the fresh fight. Backfill after that so setPractice
	-- cannot flip the host's fight.
	local tuneOk, tuned = pcall(DungeonService.tuneRaid, player, {
		practice = practice,
		players = 1,
		healer = healer,
		wing = wing,
		phase = phase,
	})
	if not tuneOk then
		clearHold()
		error(tuned)
	end
	if tuned.ok ~= true then
		clearHold()
		return tuned
	end
	if not share then
		return tuned
	end
	-- Host is whoever is already in this pull. Teleport data does not name them.
	local host = DungeonService.echoHost(player, difficulty)
	if host == nil then
		clearHold()
		return tuned
	end
	local filled = DungeonService.backfill(player, host)
	clearHold()
	if filled.ok ~= true then
		return tuned
	end
	filled.note = "Joined the pull."
	return filled
end

local function startQueue(player: Player, difficulty: any, role: any, allowHop: boolean)
	local row = Raids.difficulty(difficulty)
	if row == nil then
		return reject("Pick Story or Normal.")
	end
	-- Before ReserveServer. A second click while the first hop is saving
	-- must not reserve another instance or call TeleportAsync again.
	local hold = DataService.teleportHold(player)
	if hold ~= nil then
		return reject(hold)
	end
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local allowed, why = Raids.roleOk(profile.classId, role)
	if not allowed then
		return reject(why)
	end
	if (profile.level or 1) < row.level then
		return reject(string.format("Level %d opens The Heartwood.", row.level))
	end
	if row.id == "normal" and profile.raidStory ~= true then
		return reject("Clear Story once before Normal.")
	end
	local healer = role == "healer" or (role == "flex" and profile.classId == "tidecaller")
	if allowHop then
		local code = reservedCode()
		if code ~= nil then
			-- Save and clear the lock before the hop. A failed save stays on this
			-- server; a failed hop reclaims the lock and falls through to the
			-- local raid below.
			local hopped, hopWhy = DataService.releaseForTeleport(player, function()
				local TeleportService = game:GetService("TeleportService")
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = code
				options:SetTeleportData({
					raid = "heartwood",
					difficulty = row.id,
					role = role,
				})
				TeleportService:TeleportAsync(game.PlaceId, { player }, options)
			end)
			if hopped == "teleported" then
				return { ok = true, note = "Reserved server. Flying in." }
			end
			if hopped == "closing" then
				return reject(hopWhy or ProfileLoad.TELEPORT_ALREADY)
			end
			if hopped == "kept" or hopped == "closed" then
				return reject(
					hopWhy
						or "Could not save your profile, so the raid teleport was cancelled. You are still on this server."
				)
			end
		end
	end
	local started = launch(player, row.id, healer, 1, 1, false)
	if started.ok ~= true then
		return started
	end
	if started.note == nil then
		started.note = "Solo test. No reserved server here. Damage is softened without a healer."
	end
	started.leaderboard = RaidService.leaderboard()
	return started
end

function RaidService.queue(player: Player, difficulty: any, role: any)
	return startQueue(player, difficulty, role, true)
end

function RaidService.board()
	local copy = {}
	for _, row in ipairs(listings) do
		table.insert(copy, {
			id = row.id,
			host = row.host,
			tag = row.tag,
			difficulty = row.difficulty,
		})
	end
	return copy
end

function RaidService.post(player: Player, tag: any, difficulty: any)
	if not Raids.tagOk(tag) or Raids.difficulty(difficulty) == nil then
		return reject("Pick a tag and Story or Normal.")
	end
	nextId += 1
	local id = nextId
	table.insert(listings, {
		id = id,
		host = player.Name,
		userId = player.UserId,
		tag = tag,
		difficulty = difficulty,
	})
	while #listings > 20 do
		table.remove(listings, 1)
	end
	return { ok = true, id = id, board = RaidService.board() }
end

function RaidService.join(player: Player, listingId: any)
	local found = nil
	for _, row in ipairs(listings) do
		if row.id == listingId then
			found = row
		end
	end
	if found == nil then
		return reject("That listing is gone.")
	end
	local DungeonService = dungeon()
	local host = nil
	if type(found.userId) == "number" then
		host = Players:GetPlayerByUserId(found.userId)
	end
	local hostParty = if host ~= nil then DungeonService.echoParty(host) else nil
	local route = EchoParty.route(
		host ~= nil and host ~= player,
		hostParty ~= nil,
		EchoParty.samePull(
			if hostParty ~= nil then hostParty.difficulty else nil,
			if hostParty ~= nil then hostParty.practice else false,
			found.difficulty
		)
	)
	if route == "backfill" and host ~= nil then
		local created = false
		if not DungeonService.isInRun(player) then
			local entered = DungeonService.enter(player, "heartwood", found.difficulty, false)
			if entered.ok ~= true then
				return entered
			end
			created = true
		end
		local filled = DungeonService.backfill(player, host)
		if filled.ok == true then
			filled.note = string.format("%s listing. Joined the pull.", found.tag)
			return filled
		end
		if created then
			DungeonService.leave(player)
		end
		return filled
	end
	local started = RaidService.queue(player, found.difficulty, "flex")
	if started.ok == true then
		started.note = string.format("%s listing. %s", found.tag, started.note or "Joined.")
	end
	return started
end

function RaidService.practice(player: Player, wing: any, phase: any)
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local allowed, why = PracticeLoot.levelGate(profile.level)
	if not allowed then
		return reject(why or "Level 15 opens The Heartwood.")
	end
	local room = PracticeLoot.wing(wing, #Raids.WINGS)
	-- phase is accepted so an old client payload still type-checks, then dropped.
	local step = PracticeLoot.openedPhase(phase, nil)
	local started = launch(player, "story", false, room, step, true)
	if started.ok ~= true then
		return started
	end
	started.note = "Practice Grove. No loot."
	return started
end

function RaidService.buy(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return reject("Pick a vendor item.")
	end
	local ok, err = DataService.mutate(player, function(data)
		local bought, reason = Raids.buy(data, itemId)
		if not bought then
			return reason
		end
		return nil
	end)
	if not ok then
		return reject(err or "Could not buy that.")
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function RaidService.receive(player: Player)
	if RunService:IsStudio() then
		return
	end
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(join) ~= "table" or type(join.TeleportData) ~= "table" then
		return
	end
	local payload = join.TeleportData
	if payload.raid ~= "heartwood" then
		return
	end
	-- Reserved servers report a private id and owner 0. Launch here.
	-- launch joins a matching in-progress pull on this server. The host is
	-- that pull, not this payload. Queueing would ReserveServer and hop again.
	local allowHop = ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	startQueue(player, payload.difficulty, payload.role or "flex", allowHop)
end

return RaidService
