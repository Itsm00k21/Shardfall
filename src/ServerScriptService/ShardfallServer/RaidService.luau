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
	RaidPost and RaidJoin keep the rate limits already on those remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local PracticeLoot = require(ReplicatedStorage.Shared.PracticeLoot)
local ProfileLoad = require(ReplicatedStorage.Shared.ProfileLoad)
local Raids = require(ReplicatedStorage.Shared.Raids)
local RaidPremade = require(ReplicatedStorage.Shared.RaidPremade)
local DataService = require(script.Parent.DataService)
local EchoParty = require(script.Parent.EchoParty)

local RaidService = {}

local listings: { any } = {}
local ranks: { { name: string, seconds: number } } = {}
local nextId = 0

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
	local now = os.time()
	local index = 1
	while index <= #listings do
		local row = listings[index]
		local result = RaidPremade.depart(row.listing, userId, now)
		if result.ok == true and result.listing ~= nil then
			row.listing = result.listing
		end
		index += 1
	end
	sweep(now)
end

-- DungeonService.PlayerRemoving should call this. Disconnect calls it too.
function RaidService.memberLeft(player: Player)
	departUser(player.UserId)
end

Players.PlayerRemoving:Connect(function(leaving: Player)
	departUser(leaving.UserId)
end)

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
	if not filteredOk or type(filtered) ~= "string" or filtered == "" then
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
	return startQueue(player, difficulty, role, true)
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
	local state = RaidPremade.status(found.listing, now)
	local full = state.ok == true
		and state.full == true
		and state.expired ~= true
		and state.closed ~= true
	local difficulty = found.listing.difficulty
	if full and (difficulty == "story" or difficulty == "normal") then
		local DungeonService = dungeon()
		local host = nil
		local hostUserId = found.listing.hostUserId
		if type(hostUserId) == "number" then
			host = Players:GetPlayerByUserId(hostUserId)
		end
		local hostParty = if host ~= nil then DungeonService.echoParty(host) else nil
		local route = EchoParty.route(
			host ~= nil and host ~= player,
			hostParty ~= nil,
			EchoParty.samePull(
				if hostParty ~= nil then hostParty.difficulty else nil,
				if hostParty ~= nil then hostParty.practice else false,
				difficulty
			)
		)
		if route == "backfill" and host ~= nil then
			local created = false
			if not DungeonService.isInRun(player) then
				local entered = DungeonService.enter(player, "heartwood", difficulty, false)
				if entered.ok ~= true then
					return {
						ok = true,
						id = found.id,
						board = RaidService.board(),
						note = "Seated on the premade board.",
					}
				end
				created = true
			end
			local filled = DungeonService.backfill(player, host)
			if filled.ok == true then
				filled.note = "Premade listing. Joined the pull."
				return filled
			end
			if created then
				DungeonService.leave(player)
			end
		end
	end
	return {
		ok = true,
		id = found.id,
		board = RaidService.board(),
		note = if full
			then "Party is full. Ready check comes later."
			else "Seated on the premade board.",
	}
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
