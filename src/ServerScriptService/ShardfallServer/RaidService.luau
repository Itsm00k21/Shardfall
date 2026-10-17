--!strict

--[[
	Heartwood queue, premade board, and Practice Grove.

	A reserved server is attempted outside Studio. If that teleport cannot
	start, the same raid runs here as a solo test so Kevin can play it.

	Arriving on a reserved server starts the raid here. Queueing again from
	receive would reserve another server and hop in a loop. A second queue
	while the first hop is still saving does not reserve or teleport.

	The plaza board is the in-memory listings array. RaidPremade accepts or
	refuses a row. A join takes a seat and does not start Raid Finder.
	A full party does not launch on the last join. The host starts a ready
	check, and Story or Normal launches only after every seated member is
	ready. Outside Studio that launch reserves one server and teleports the
	seated party together. A failed or partial teleport puts them back on
	the board seats. A hop that leaves this server does not drop those
	seats: the reserved server may still send the party home if the pull
	never starts. Studio still enters on this server. Hard and
	Shardbreaker never enter from that path. The host id, the member list,
	and the ready flags come from this server.
	A seated player can leave that seat while they are still connected.
	A leave or a disconnect during the check cancels it. A hop in flight
	does not count as that leave.
	RaidPost and RaidJoin keep the rate limits already on those remotes.
	RaidReady and RaidLeave use the same limit. PlayerRemoving is a
	disconnect, not that leave. Nothing on this path spends Robux.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local PracticeLoot = require(ReplicatedStorage.Shared.PracticeLoot)
local ProfileLoad = require(ReplicatedStorage.Shared.ProfileLoad)
local Raids = require(ReplicatedStorage.Shared.Raids)
local RaidPremade = require(ReplicatedStorage.Shared.RaidPremade)
local RaidPremadeHop = require(ReplicatedStorage.Shared.RaidPremadeHop)
local DataService = require(script.Parent.DataService)
local EchoParty = require(script.Parent.EchoParty)
local RaidReady = require(script.Parent.RaidReady)

local RaidService = {}

local listings: { any } = {}
local ranks: { { name: string, seconds: number } } = {}
local nextId = 0
-- Set while a premade hop is in flight so PlayerRemoving does not free the seat.
local hopHold: { [number]: boolean } = {}
local forming = false

type Arrival = {
	bucket: any,
	players: { [number]: Player },
	started: boolean,
	generation: number,
}

local arrivals: { [string]: Arrival } = {}

-- Active rows only. Expired and closed rows are removed, not evicted.
local BOARD_CAP = 20
-- RaidPremade has no title cap. The filtered string stays on the wrapper.
local TITLE_MAX = 48

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
	practice: boolean,
	partyPlayers: number?
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
	local count = 1
	if
		type(partyPlayers) == "number"
		and partyPlayers >= 1
		and partyPlayers <= 8
		and partyPlayers == math.floor(partyPlayers)
	then
		count = partyPlayers
	end
	local tuneOk, tuned = pcall(DungeonService.tuneRaid, player, {
		practice = practice,
		players = count,
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

local function startQueue(
	player: Player,
	difficulty: any,
	role: any,
	allowHop: boolean,
	partyPlayers: number?,
	partyHealer: boolean?
)
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
	if partyHealer ~= nil then
		healer = partyHealer == true
	end
	-- A reserved server (private id, owner 0) launches in place.
	-- A queue click there must not reserve another server or teleport.
	local canHop = ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	if allowHop and canHop then
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
				-- ShardfallLoading is already the teleport gui. Studio does not hop.
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
	local started = launch(player, row.id, healer, 1, 1, false, partyPlayers)
	if started.ok ~= true then
		return started
	end
	if started.note == nil then
		started.note = "Solo test. No reserved server here. Damage is softened without a healer."
	end
	started.leaderboard = RaidService.leaderboard()
	return started
end

local function trim(text: string): string
	local trimmed = string.gsub(text, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return trimmed
end

local function wholeId(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value <= 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

-- Nil is 0 once T-038 adds raidClears. A corrupt stored count is unusable.
local function usableClears(value: any): (number?, string?)
	if value == nil then
		return 0, nil
	end
	if
		type(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value < RaidPremade.CONFIG.minClears
		or value ~= math.floor(value)
	then
		return nil, RaidPremade.ERRORS.clears
	end
	return value, nil
end

local function normalizeRole(role: any): string?
	if role == nil then
		return "flex"
	end
	if type(role) ~= "string" then
		return nil
	end
	local name = string.lower(trim(role))
	if RaidPremade.ROLES[name] == true then
		return name
	end
	return nil
end

local function acceptRole(profile: any, role: any): (string?, string?)
	local name = normalizeRole(role)
	if name == nil then
		return nil, RaidPremade.ERRORS.role
	end
	local allowed, why = Raids.roleOk(profile.classId, name)
	if not allowed then
		return nil, why
	end
	return name, nil
end

local function premadeGate(profile: any, difficulty: any): string?
	local story = Raids.DIFFICULTIES.story
	local need = if story ~= nil then story.level else 15
	local level = profile.level
	if type(level) ~= "number" or level < need then
		return string.format("Level %d opens The Heartwood.", need)
	end
	if difficulty == "story" or profile.raidStory == true then
		return nil
	end
	if difficulty == "normal" then
		return "Clear Story once before Normal."
	end
	return "Clear Story once before that difficulty."
end

local function boardBlock(player: Player): string?
	local hold = DataService.teleportHold(player)
	if hold ~= nil then
		return hold
	end
	if dungeon().isInRun(player) then
		return "Leave your current run before using the premade board."
	end
	return nil
end

local function listingActive(row: any, now: number): boolean
	local state = RaidPremade.status(row.listing, now)
	return state.ok == true and state.active == true
end

local function sweep(now: number)
	local index = 1
	while index <= #listings do
		if listingActive(listings[index], now) then
			index += 1
		else
			table.remove(listings, index)
		end
	end
end

local function normalizedBoard(): { any }
	local rows = {}
	for index, row in ipairs(listings) do
		rows[index] = row.listing
	end
	return rows
end

local function seatedRow(userId: number, now: number): any?
	for _, row in ipairs(listings) do
		if listingActive(row, now) then
			local members = row.listing.members
			if type(members) == "table" then
				for _, member in ipairs(members) do
					if type(member) == "table" and member.userId == userId then
						return row
					end
				end
			end
		end
	end
	return nil
end

local function findListing(id: number): (any?, number?)
	for index, row in ipairs(listings) do
		if row.id == id then
			return row, index
		end
	end
	return nil, nil
end

local function departUser(userId: number)
	if hopHold[userId] == true then
		return
	end
	local now = os.time()
	local index = 1
	while index <= #listings do
		local row = listings[index]
		local result = RaidPremade.depart(row.listing, userId, now)
		if result.ok == true and result.listing ~= nil then
			row.listing = result.listing
			-- A leave or disconnect during the check cancels it. The next
			-- full party starts over. This does not launch.
			if row.ready ~= nil or row.pulling == true then
				row.ready = nil
				row.readyToken = (row.readyToken or 0) + 1
			end
		end
		index += 1
	end
	sweep(now)
end

local function recallLine(player: Player)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		return
	end
	local remote = remotes:FindFirstChild("CombatFx")
	if remote ~= nil and remote:IsA("RemoteEvent") then
		-- The kind is enough. The client paints the seated failure line.
		-- This payload does not name a player.
		remote:FireClient(player, { kind = "premadeRecall" })
	end
end

local function sendHome(row: Arrival, except: Player?)
	local home = row.bucket.homeJobId
	if type(home) ~= "string" or home == "" then
		return
	end
	-- The plaza kept the seats. The token is the one this server packed.
	-- The payload does not name a player. The arriving server uses the
	-- player who actually landed.
	-- Release the lock before the return hop. The callback runs only
	-- after that save clears it. A failed save stays here. One profile
	-- at a time, so a missing save does not hold the rest of the party.
	local recall = {
		raid = "heartwood",
		premadeRecall = true,
		token = row.bucket.token,
	}
	local TeleportService = game:GetService("TeleportService")
	for _, person in pairs(row.players) do
		if person ~= except and person.Parent == Players then
			DataService.releaseForTeleport(person, function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, home, person, nil, recall)
			end)
		end
	end
end

local function forgetArrival(player: Player)
	for token, row in pairs(arrivals) do
		if row.started == true or row.players[player.UserId] == nil then
			continue
		end
		row.players[player.UserId] = nil
		local nextBucket, state = RaidPremadeHop.drop(row.bucket, player.UserId)
		row.generation += 1
		arrivals[token] = nil
		if nextBucket ~= nil and state ~= "empty" then
			sendHome(row, player)
		end
	end
end

-- Disconnect path. DungeonService.PlayerRemoving should call this too.
-- A second call is safe. This is not the seated leave button.
function RaidService.memberLeft(player: Player)
	departUser(player.UserId)
end

Players.PlayerRemoving:Connect(function(leaving: Player)
	forgetArrival(leaving)
	-- hopHold makes depart a no-op, so a hop that has not started keeps
	-- the seat. Clear the hold after that check. A later leave can depart.
	departUser(leaving.UserId)
	hopHold[leaving.UserId] = nil
end)

-- Deliberate seat leave while this player is still connected.
-- departUser calls RaidPremade.depart. PlayerRemoving does not call this.
-- It does not launch a raid and it does not read a client user id.
function RaidService.leave(player: Player)
	local userId = player.UserId
	local now = os.time()
	sweep(now)
	local seat = seatedRow(userId, now)
	if seat == nil then
		return reject("You are not seated on a premade listing.")
	end
	local leftId = seat.id
	departUser(userId)
	if seatedRow(userId, os.time()) ~= nil then
		return reject("Could not leave that listing.")
	end
	return {
		ok = true,
		id = leftId,
		board = RaidService.board(),
		note = "Left the premade listing.",
	}
end

local function clientPost(tag: any, difficulty: any): any
	if type(tag) == "table" then
		return tag
	end
	return {
		tags = tag,
		difficulty = difficulty,
	}
end

local function partyShape(payload: any): (any, any)
	local partySize = payload.partySize
	local slots = payload.slots
	if type(slots) == "table" then
		local copied = {}
		local limit = RaidPremade.CONFIG.maxParty + 1
		for index, entry in ipairs(slots) do
			if index > limit then
				break
			end
			copied[index] = entry
		end
		if partySize == nil then
			partySize = #copied
		end
		return partySize, copied
	end
	if slots ~= nil then
		return partySize, slots
	end
	if partySize == nil then
		partySize = RaidPremade.CONFIG.minParty
	end
	local size = partySize
	local maxParty = RaidPremade.CONFIG.maxParty
	if
		type(size) == "number"
		and size == size
		and size ~= math.huge
		and size == math.floor(size)
		and size >= 1
		and size <= maxParty
	then
		local filled = {}
		for index = 1, size do
			filled[index] = "flex"
		end
		return size, filled
	end
	return partySize, nil
end

-- Server stamps the host, the clock, and the only member. Client members are ignored.
local function buildDraft(
	player: Player,
	payload: any,
	role: string,
	now: number
): { [string]: any }
	local partySize, slots = partyShape(payload)
	local tags = payload.tags
	if tags == nil then
		tags = payload.tag
	end
	local draft: { [string]: any } = {
		hostUserId = player.UserId,
		difficulty = payload.difficulty,
		tags = tags,
		requiredClears = payload.requiredClears,
		gearScore = payload.gearScore,
		partySize = partySize,
		slots = slots,
		createdAt = now,
		members = {
			{ userId = player.UserId, role = role },
		},
	}
	if payload.guided ~= nil then
		draft.guided = payload.guided
	end
	return draft
end

local function filterTitle(player: Player, title: any): (string?, string?)
	if title == nil then
		return "", nil
	end
	if type(title) ~= "string" then
		return nil, "That title is unusable."
	end
	if #title > TITLE_MAX then
		return nil, "That title is too long."
	end
	local trimmed = trim(title)
	if trimmed == "" then
		return "", nil
	end
	if string.find(trimmed, "%c") ~= nil then
		return nil, "That title is unusable."
	end
	local filteredOk, filtered = pcall(function()
		local result = TextService:FilterStringAsync(trimmed, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not filteredOk then
		-- TextService often errors in Studio. The trimmed title is only for
		-- that local test. A published server still refuses, so other players
		-- never receive an unfiltered title.
		if RunService:IsStudio() then
			return trimmed, nil
		end
		return nil, "Could not filter that title."
	end
	if type(filtered) ~= "string" or filtered == "" then
		return nil, "Could not filter that title."
	end
	if #filtered > TITLE_MAX then
		return nil, "That title is too long."
	end
	return filtered, nil
end

local function copyStrings(source: any): { string }
	local copy = {}
	if type(source) ~= "table" then
		return copy
	end
	for index, value in ipairs(source) do
		if type(value) == "string" then
			copy[index] = value
		end
	end
	return copy
end

function RaidService.queue(player: Player, difficulty: any, role: any)
	local now = os.time()
	sweep(now)
	if seatedRow(player.UserId, now) ~= nil then
		return reject("Leave your premade listing before using Raid Finder.")
	end
	-- The plaza still hops. A reserved server passes false and launches here.
	local allowHop = ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	return startQueue(player, difficulty, role, allowHop)
end

function RaidService.board()
	local now = os.time()
	sweep(now)
	local copy = {}
	for _, row in ipairs(listings) do
		local state = RaidPremade.status(row.listing, now)
		if state.ok == true and state.active == true then
			local listing = row.listing
			local tags = copyStrings(listing.tags)
			table.insert(copy, {
				id = row.id,
				host = row.hostName,
				title = row.title,
				tag = tags[1],
				tags = tags,
				difficulty = listing.difficulty,
				requiredClears = listing.requiredClears,
				partySize = listing.partySize,
				openCount = state.openCount,
				full = state.full,
				slots = copyStrings(listing.slots),
			})
		end
	end
	return copy
end

function RaidService.post(player: Player, tag: any, difficulty: any)
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local blocked = boardBlock(player)
	if blocked ~= nil then
		return reject(blocked)
	end
	local role, roleError = acceptRole(profile, if type(tag) == "table" then tag.role else nil)
	if role == nil then
		return reject(roleError or RaidPremade.ERRORS.role)
	end
	local have, clearsError = usableClears((profile :: any).raidClears)
	if have == nil then
		return reject(clearsError or RaidPremade.ERRORS.clears)
	end
	local postedAt = os.time()
	sweep(postedAt)
	if seatedRow(player.UserId, postedAt) ~= nil then
		return reject("Leave your listing before posting another.")
	end
	if #listings >= BOARD_CAP then
		return reject("The premade board is full.")
	end
	local payload = clientPost(tag, difficulty)
	local draft = buildDraft(player, payload, role, postedAt)
	local opened = RaidPremade.open(normalizedBoard(), draft, postedAt)
	if opened.ok ~= true or opened.listing == nil then
		return reject(opened.error or RaidPremade.ERRORS.listing)
	end
	if have < opened.listing.requiredClears then
		return reject(RaidPremade.ERRORS.short)
	end
	local gate = premadeGate(profile, opened.listing.difficulty)
	if gate ~= nil then
		return reject(gate)
	end
	local title, titleError = filterTitle(player, payload.title)
	if title == nil then
		return reject(titleError or "Could not filter that title.")
	end
	-- FilterStringAsync yields. A second post can land before this one stores.
	local now = os.time()
	if now < postedAt then
		now = postedAt
	end
	sweep(now)
	if seatedRow(player.UserId, now) ~= nil then
		return reject("Leave your listing before posting another.")
	end
	if #listings >= BOARD_CAP then
		return reject("The premade board is full.")
	end
	opened = RaidPremade.open(normalizedBoard(), draft, now)
	if opened.ok ~= true or opened.listing == nil then
		return reject(opened.error or RaidPremade.ERRORS.listing)
	end
	if have < opened.listing.requiredClears then
		return reject(RaidPremade.ERRORS.short)
	end
	nextId += 1
	local id = nextId
	table.insert(listings, {
		id = id,
		title = title,
		hostName = player.Name,
		listing = opened.listing,
	})
	return {
		ok = true,
		id = id,
		board = RaidService.board(),
		note = "Listed on the premade board.",
	}
end

function RaidService.join(player: Player, listingId: any)
	local rawId = listingId
	local rawRole = nil
	if type(listingId) == "table" then
		rawId = listingId.id
		if rawId == nil then
			rawId = listingId.listingId
		end
		rawRole = listingId.role
	end
	local id = wholeId(rawId)
	if id == nil then
		return reject("That listing is gone.")
	end
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local blocked = boardBlock(player)
	if blocked ~= nil then
		return reject(blocked)
	end
	local _, clearsError = usableClears((profile :: any).raidClears)
	if clearsError ~= nil then
		return reject(clearsError)
	end
	local role, roleError = acceptRole(profile, rawRole)
	if role == nil then
		return reject(roleError or RaidPremade.ERRORS.role)
	end
	local now = os.time()
	local found, foundAt = findListing(id)
	if found == nil or found.listing == nil then
		return reject("That listing is gone.")
	end
	local seat = seatedRow(player.UserId, now)
	if seat ~= nil then
		if seat == found then
			return reject(RaidPremade.ERRORS.duplicate)
		end
		return reject("Leave your listing before joining another.")
	end
	local gate = RaidPremade.join(found.listing, {
		userId = player.UserId,
		role = role,
		clears = (profile :: any).raidClears,
	}, now)
	if gate.allowed ~= true or gate.listing == nil then
		local state = RaidPremade.status(found.listing, now)
		if foundAt ~= nil and (state.ok ~= true or state.active ~= true) then
			table.remove(listings, foundAt)
		end
		return reject(gate.error or RaidPremade.ERRORS.listing)
	end
	local levelError = premadeGate(profile, gate.listing.difficulty)
	if levelError ~= nil then
		return reject(levelError)
	end
	found.listing = gate.listing
	-- The last seat only fills the row. Launch waits for the ready check.
	local state = RaidPremade.status(found.listing, now)
	local full = state.ok == true and state.full == true and state.active == true
	return {
		ok = true,
		id = found.id,
		board = RaidService.board(),
		note = if full
			then "Party is full. The host starts the ready check."
			else "Seated on the premade board.",
	}
end

local function partyHealer(listing: any): boolean
	local members = listing.members
	if type(members) ~= "table" then
		return false
	end
	for _, member in ipairs(members) do
		if type(member) == "table" then
			if member.role == "healer" then
				return true
			end
			if member.role == "flex" and type(member.userId) == "number" then
				local person = Players:GetPlayerByUserId(member.userId)
				if person ~= nil then
					local profile = DataService.get(person)
					if profile ~= nil and profile.classId == "tidecaller" then
						return true
					end
				end
			end
		end
	end
	return false
end

local function hopPremade(
	row: any,
	token: number,
	seated: { Player },
	difficulty: string,
	stillGoing: () -> boolean
): any
	local function stop(dropCheck: boolean, message: string)
		for _, person in ipairs(seated) do
			hopHold[person.UserId] = nil
		end
		if dropCheck and row.readyToken == token then
			row.ready = nil
			row.readyToken = token + 1
		end
		row.pulling = false
		return reject(message)
	end

	if not stillGoing() then
		return stop(true, "The ready check was cancelled.")
	end
	local DungeonService = dungeon()
	for _, person in ipairs(seated) do
		if DungeonService.isInRun(person) then
			return stop(false, RaidPremadeHop.ERRORS.run)
		end
		if DataService.teleportHold(person) ~= nil then
			return stop(false, RaidPremadeHop.ERRORS.hold)
		end
		if DataService.get(person) == nil then
			return stop(false, RaidPremadeHop.ERRORS.save)
		end
	end
	local tries, gate = RaidPremadeHop.spend(row.hopTries)
	if tries == nil or gate ~= "go" then
		return stop(true, RaidPremadeHop.ERRORS.capped)
	end
	row.hopTries = tries
	if not stillGoing() then
		return stop(true, "The ready check was cancelled.")
	end
	local listing = row.listing
	if type(listing) ~= "table" or type(listing.members) ~= "table" then
		return stop(true, "The ready check was cancelled.")
	end
	local members = {}
	for _, member in ipairs(listing.members) do
		if type(member) == "table" then
			table.insert(members, { userId = member.userId, role = member.role })
		end
	end
	local home = game.JobId
	local packed = RaidPremadeHop.pack({
		difficulty = difficulty,
		members = members,
		token = game:GetService("HttpService"):GenerateGUID(false),
		homeJobId = home,
		healer = partyHealer(listing),
	})
	if packed == nil or home == "" then
		return stop(true, RaidPremadeHop.ERRORS.server)
	end
	for _, person in ipairs(seated) do
		hopHold[person.UserId] = true
	end
	local code = reservedCode()
	if code == nil or not stillGoing() then
		local message = if code == nil
			then RaidPremadeHop.ERRORS.server
			else "The ready check was cancelled."
		return stop(true, message)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData(packed)
	local TeleportService = game:GetService("TeleportService")
	local callOk, status, away = pcall(DataService.releasePartyForTeleport, seated, function()
		-- ShardfallLoading is already the teleport gui. Studio does not hop.
		TeleportService:TeleportAsync(game.PlaceId, seated, options)
	end)
	if not callOk or status ~= "teleported" then
		if type(away) == "table" then
			for _, person in ipairs(away) do
				pcall(function()
					TeleportService:TeleportToPlaceInstance(game.PlaceId, home, person)
				end)
			end
		end
		local message = RaidPremadeHop.ERRORS.seated
		if status == "kept" then
			message = RaidPremadeHop.ERRORS.save
		elseif status == "closing" then
			message = RaidPremadeHop.ERRORS.hold
		end
		return stop(true, message)
	end
	-- TeleportAsync returned. The pull has not started on the reserved
	-- server. Keep every seat. hopHold stays set so the disconnect that
	-- follows this teleport does not depart them. Do not mark launched:
	-- a recall has to be able to ready again. Departing here is what
	-- left a recalled party with no seats.
	row.hopping = true
	row.hopToken = packed.token
	row.pulling = false
	row.ready = nil
	row.readyToken = token + 1
	local held = table.clone(seated)
	task.delay(RaidPremadeHop.CONFIG.waitSeconds, function()
		for _, person in ipairs(held) do
			if person.Parent == Players then
				hopHold[person.UserId] = nil
			end
		end
	end)
	return {
		ok = true,
		id = row.id,
		board = RaidService.board(),
		note = "Reserved server. The party is flying in.",
	}
end

-- Story and Normal only. Hard and Shardbreaker return before enter, and
-- this path does not call Raids.difficulty. The listing host is the anchor.
-- Outside Studio the ready party reserves one server and teleports together.
-- Studio enters here. The hop helper does not open a finder queue.
local function launchPremade(row: any): any
	local listing = row.listing
	local difficulty = if type(listing) == "table" then listing.difficulty else nil
	if difficulty ~= "story" and difficulty ~= "normal" then
		return {
			ok = true,
			id = row.id,
			board = RaidService.board(),
			note = "Party is ready. Hard and Shardbreaker stay closed.",
		}
	end
	if row.launched == true then
		return {
			ok = true,
			id = row.id,
			board = RaidService.board(),
			note = "The party already launched.",
		}
	end
	if row.pulling == true then
		return reject("The party is already launching.")
	end

	local token = if type(row.readyToken) == "number" then row.readyToken else 0
	row.readyToken = token
	row.pulling = true
	local created: { Player } = {}

	local function unwind(dropCheck: boolean)
		if dropCheck and row.readyToken == token then
			row.ready = nil
			row.readyToken = token + 1
		end
		row.pulling = false
		local DungeonService = dungeon()
		for index = #created, 1, -1 do
			pcall(DungeonService.leave, created[index])
		end
	end

	local function stillGoing(): boolean
		if row.pulling ~= true or row.ready == nil or row.readyToken ~= token then
			return false
		end
		if type(row.listing) ~= "table" then
			return false
		end
		local now = os.time()
		if not listingActive(row, now) then
			return false
		end
		local state = RaidPremade.status(row.listing, now)
		if state.ok ~= true or state.full ~= true or state.active ~= true then
			return false
		end
		local vote = RaidReady.vote(
			row.ready,
			row.listing.hostUserId,
			row.listing.hostUserId,
			row.listing.members,
			true
		)
		return vote.ok == true and vote.complete == true
	end

	local function hostPlayer(): Player?
		if type(row.listing) ~= "table" or type(row.listing.hostUserId) ~= "number" then
			return nil
		end
		return Players:GetPlayerByUserId(row.listing.hostUserId)
	end

	local function partyNow(): { Player }?
		if type(row.listing) ~= "table" or type(row.listing.members) ~= "table" then
			return nil
		end
		local seated = {}
		for _, member in ipairs(row.listing.members) do
			if type(member) ~= "table" or type(member.userId) ~= "number" then
				return nil
			end
			local person = Players:GetPlayerByUserId(member.userId)
			if person == nil then
				return nil
			end
			table.insert(seated, person)
		end
		if #seated == 0 then
			return nil
		end
		return seated
	end

	if not stillGoing() then
		unwind(true)
		return reject("The ready check was cancelled.")
	end
	local host = hostPlayer()
	local seated = partyNow()
	if host == nil or seated == nil then
		unwind(true)
		return reject("The host left the ready check.")
	end

	if not RunService:IsStudio() then
		return hopPremade(row, token, seated, difficulty, stillGoing)
	end

	local DungeonService = dungeon()
	local hostParty = DungeonService.echoParty(host)
	local same = EchoParty.samePull(
		if hostParty ~= nil then hostParty.difficulty else nil,
		if hostParty ~= nil then hostParty.practice else false,
		difficulty
	)
	if hostParty ~= nil and same ~= true then
		unwind(false)
		return reject("Leave your current run before the ready check.")
	end
	local route = EchoParty.route(true, hostParty ~= nil, same)
	if route ~= "backfill" and DungeonService.isInRun(host) then
		unwind(false)
		return reject("Leave your current run before the ready check.")
	end

	local healer = partyHealer(row.listing)
	local partyCount = #seated
	local tune = {
		practice = false,
		players = partyCount,
		healer = healer,
		wing = 1,
		phase = 1,
	}

	local function cancelled(): any
		unwind(true)
		return reject("The ready check was cancelled.")
	end

	if route ~= "backfill" then
		local enterOk, entered = pcall(DungeonService.enter, host, "heartwood", difficulty, false)
		if not enterOk then
			table.insert(created, host)
			unwind(false)
			error(entered)
		end
		if type(entered) == "table" and entered.ok == true then
			table.insert(created, host)
		end
		if not stillGoing() then
			return cancelled()
		end
		if type(entered) ~= "table" or entered.ok ~= true then
			unwind(false)
			return if type(entered) == "table"
				then entered
				else reject("The Heartwood did not open.")
		end
		local tuneOk, tuned = pcall(DungeonService.tuneRaid, host, tune)
		if not tuneOk then
			unwind(false)
			error(tuned)
		end
		if not stillGoing() then
			return cancelled()
		end
		if type(tuned) ~= "table" or tuned.ok ~= true then
			unwind(false)
			return if type(tuned) == "table" then tuned else reject("The Heartwood did not open.")
		end
	end

	local flying = partyNow()
	local anchor = hostPlayer()
	if flying == nil or anchor ~= host then
		return cancelled()
	end
	for _, person in ipairs(flying) do
		if person ~= host then
			if not stillGoing() then
				return cancelled()
			end
			if DungeonService.isInRun(person) then
				local party = DungeonService.echoParty(person)
				local memberSame = party ~= nil
					and EchoParty.samePull(party.difficulty, party.practice, difficulty)
				if memberSame ~= true then
					unwind(false)
					return reject("Leave your current run before the ready check.")
				end
			else
				local enterOk, entered =
					pcall(DungeonService.enter, person, "heartwood", difficulty, false)
				if not enterOk then
					table.insert(created, person)
					unwind(false)
					error(entered)
				end
				if type(entered) == "table" and entered.ok == true then
					table.insert(created, person)
				end
				if not stillGoing() then
					return cancelled()
				end
				if type(entered) ~= "table" or entered.ok ~= true then
					unwind(false)
					return if type(entered) == "table"
						then entered
						else reject("The Heartwood did not open.")
				end
				local tuneOk, tuned = pcall(DungeonService.tuneRaid, person, tune)
				if not tuneOk then
					unwind(false)
					error(tuned)
				end
				if not stillGoing() then
					return cancelled()
				end
				if type(tuned) ~= "table" or tuned.ok ~= true then
					unwind(false)
					return if type(tuned) == "table"
						then tuned
						else reject("The Heartwood did not open.")
				end
			end
			local fillOk, filled = pcall(DungeonService.backfill, person, host)
			if not fillOk then
				unwind(false)
				error(filled)
			end
			if not stillGoing() then
				return cancelled()
			end
			if type(filled) ~= "table" or filled.ok ~= true then
				unwind(false)
				return if type(filled) == "table" then filled else reject("No raid party is up.")
			end
		end
	end

	if not stillGoing() or hostPlayer() ~= host then
		return cancelled()
	end
	row.pulling = false
	row.ready = nil
	row.launched = true
	row.readyToken = token + 1
	return {
		ok = true,
		id = row.id,
		board = RaidService.board(),
		note = "Premade party launched.",
	}
end

function RaidService.ready(player: Player)
	local now = os.time()
	sweep(now)
	local seat = seatedRow(player.UserId, now)
	if seat == nil or type(seat.listing) ~= "table" then
		return reject("You are not seated on a premade listing.")
	end
	if seat.launched == true then
		return {
			ok = true,
			id = seat.id,
			board = RaidService.board(),
			note = "The party already launched.",
		}
	end
	if seat.hopping == true or seat.pulling == true then
		return reject("The party is already launching.")
	end
	local state = RaidPremade.status(seat.listing, now)
	local full = state.ok == true and state.full == true and state.active == true
	if full ~= true then
		seat.ready = nil
		return reject("Fill the party before the ready check.")
	end
	local vote = RaidReady.vote(
		seat.ready,
		player.UserId,
		seat.listing.hostUserId,
		seat.listing.members,
		full
	)
	if vote.ok ~= true or vote.check == nil then
		return reject(vote.error or "The ready check was refused.")
	end
	seat.ready = vote.check
	if vote.complete ~= true then
		local note = if vote.started == true
			then "Ready check started."
			else string.format("Ready %d/%d.", vote.readyCount, vote.partySize)
		return {
			ok = true,
			id = seat.id,
			board = RaidService.board(),
			note = note,
		}
	end
	return launchPremade(seat)
end

function RaidService.practice(player: Player, wing: any, phase: any)
	local profile = DataService.get(player)
	if profile == nil then
		return reject("Profile is still loading.")
	end
	local now = os.time()
	sweep(now)
	if seatedRow(player.UserId, now) ~= nil then
		return reject("Leave your premade listing before Practice Grove.")
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
	local payload = if ok and type(join) == "table" then join.TeleportData else nil
	if type(payload) ~= "table" then
		-- No teleport data. A follow-in on a reserved Heartwood server joins
		-- the pull already running here. The host id comes from this server.
		local onReserved =
			not ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
		if onReserved then
			local DungeonService = dungeon()
			local storyHost = DungeonService.echoHost(player, "story")
			local normalHost = DungeonService.echoHost(player, "normal")
			if storyHost ~= nil and normalHost == nil then
				startQueue(player, "story", "flex", false)
			elseif normalHost ~= nil and storyHost == nil then
				startQueue(player, "normal", "flex", false)
			end
		end
		return
	end
	if payload.raid ~= "heartwood" then
		return
	end
	-- Reserved servers report a private id and owner 0. Launch here.
	local reserved = not ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	if payload.premadeRecall == true then
		if reserved then
			return
		end
		-- A forged id is ignored. The player argument is the one who landed.
		local named = false
		for _, key in ipairs({ "userId", "UserId", "host", "hostUserId", "playerId", "PlayerId" }) do
			if payload[key] ~= nil then
				named = true
				break
			end
		end
		if named or type(payload.token) ~= "string" then
			return
		end
		-- The hop never started. The listing was kept on this server.
		-- Drop the in-flight flag so the same seats can ready again.
		local now = os.time()
		local seat = seatedRow(player.UserId, now)
		if seat ~= nil and seat.launched ~= true and seat.hopToken == payload.token then
			seat.hopping = nil
			seat.pulling = false
			seat.hopToken = nil
			-- They left before the ready remote could show the failure.
			-- The same seated line meets them when they land.
			recallLine(player)
		end
		return
	end
	-- launch joins a matching in-progress pull on this server. The host is
	-- that pull, not this payload. Queueing would ReserveServer and hop again.
	if payload.premade == true then
		if not reserved then
			return
		end
		local partyToken = payload.token
		local existing = if type(partyToken) == "string" then arrivals[partyToken] else nil
		local bucket, state = RaidPremadeHop.admit(
			if existing ~= nil then existing.bucket else nil,
			player.UserId,
			payload
		)
		if bucket == nil or state == "refuse" then
			return
		end
		local row = existing
		if row == nil then
			row = {
				bucket = bucket,
				players = {},
				started = false,
				generation = 0,
			}
			arrivals[bucket.token] = row
			local generation = row.generation
			local waited = bucket.token
			task.delay(RaidPremadeHop.CONFIG.waitSeconds, function()
				local current = arrivals[waited]
				if
					current == nil
					or current.started == true
					or current.generation ~= generation
				then
					return
				end
				-- The pull never started. Send them home onto the seats
				-- the plaza kept. Do not start the raid from this timeout.
				arrivals[waited] = nil
				sendHome(current, nil)
			end)
		end
		row.bucket = bucket
		row.players[player.UserId] = player
		if state ~= "ready" or row.started == true then
			return
		end
		local party = {}
		for _, id in ipairs(RaidPremadeHop.ids(bucket)) do
			local person = row.players[id]
			if person == nil or person.Parent ~= Players then
				row.generation += 1
				arrivals[bucket.token] = nil
				sendHome(row, nil)
				return
			end
			table.insert(party, person)
		end
		row.started = true
		local entered = {}
		local failed = false
		for _, person in ipairs(party) do
			while forming do
				task.wait()
			end
			forming = true
			local role = RaidPremadeHop.roleFor(bucket.roles, person.UserId)
			local callOk, result = pcall(
				startQueue,
				person,
				bucket.difficulty,
				role,
				false,
				bucket.partySize,
				bucket.healer
			)
			forming = false
			if not callOk or type(result) ~= "table" or result.ok ~= true then
				failed = true
				warn("[Shardfall] Premade arrival failed", person.UserId, result)
				break
			end
			table.insert(entered, person)
		end
		if failed then
			local DungeonService = dungeon()
			for _, person in ipairs(entered) do
				pcall(DungeonService.leave, person)
			end
			arrivals[bucket.token] = nil
			sendHome(row, nil)
		end
		return
	end
	local allowHop = ProfileLoad.hopOnArrival(game.PrivateServerId, game.PrivateServerOwnerId)
	startQueue(player, payload.difficulty, payload.role or "flex", allowHop)
end

return RaidService
