--!strict

--[[
	Server entry for direct trades.

	Ghost wires this from Remotes and init.server. The handler does not
	create RemoteFunctions itself. start() loads the audit after profiles
	are already listening. A DataStore failure keeps an empty in-memory log.

	finish() is the only path that moves items. It runs while both user
	ids are locked, re-reads both profiles, and asks Trading to commit
	or roll both bags back.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local PolicyCache = require(script.Parent.PolicyCache)
local TradeAudit = require(script.Parent.TradeAudit)
local Schema = require(ReplicatedStorage.Shared.Schema)
local Trading = require(ReplicatedStorage.Shared.Trading)

local TradeService = {}

local sessions: { [string]: Trading.Session } = {}
local byUser: { [number]: string } = {}
local started = false

local serverId = if game.JobId ~= "" then game.JobId else "studio"

local function contextFor(paid: boolean): Trading.Context
	return Trading.shared(serverId, paid)
end

local function fail(message: string)
	return { ok = false, error = message }
end

local function hasReceipt(data: any): boolean
	if type(data) ~= "table" or type(data.receipts) ~= "table" then
		return false
	end
	for _, value in pairs(data.receipts) do
		if value == true then
			return true
		end
	end
	return false
end

local function cleanDays(data: any, age: number, now: number): number
	if type(data.tradeCleanSince) == "number" and data.tradeCleanSince > 0 then
		local days = math.floor((now - data.tradeCleanSince) / 86400)
		if days < 0 then
			return 0
		end
		return days
	end
	return age
end

local function actorOf(player: Player, data: any, now: number): Trading.Actor
	local age = player.AccountAge
	if type(age) ~= "number" then
		age = 0
	end
	return {
		userId = player.UserId,
		name = player.Name,
		level = if type(data.level) == "number" then data.level else 1,
		accountAgeDays = age,
		cleanHistoryDays = cleanDays(data, age, now),
		verifiedSpender = data.verifiedSpender == true or hasReceipt(data),
		patron = data.vip == true,
		verifiedTrader = data.verifiedTrader == true,
		flagged = data.tradeFlagged == true,
		tradeLocked = data.tradeLocked == true,
		recentHandoff = data.tradeHandoff == true,
		connected = nil,
	}
end

local function paidFor(player: Player): boolean
	local policy = PolicyCache.public(player)
	return policy.ready == true and policy.tradingAllowed == true
end

local function persistAudit()
	if not TradeAudit.save(Trading.auditLog()) then
		warn("[Shardfall] trade audit did not save")
	end
end

local SAVE_FAILED = "Could not save that trade. Nothing was kept."

local function sessionFor(userId: number): Trading.Session?
	local id = byUser[userId]
	if id == nil then
		return nil
	end
	return sessions[id]
end

local function forget(session: Trading.Session)
	byUser[session.left.userId] = nil
	byUser[session.right.userId] = nil
end

local function viewOf(session: Trading.Session, userId: number, look: Trading.Preview?)
	local you = Trading.side(session, userId)
	local them = if you == session.left then session.right else session.left
	if you == nil or them == nil then
		return nil
	end
	return {
		id = session.id,
		status = session.status,
		lockRemaining = Trading.lockRemaining(session, os.time()),
		warning = if look ~= nil then look.warning else nil,
		previewError = if look ~= nil and not look.ok then look.error else nil,
		leftValue = if look ~= nil then look.leftValue else 0,
		rightValue = if look ~= nil then look.rightValue else 0,
		you = {
			userId = you.userId,
			offer = you.offer,
			confirmed = you.confirmed,
			committed = you.committed,
		},
		them = {
			userId = them.userId,
			offer = them.offer,
			confirmed = them.confirmed,
			committed = them.committed,
		},
	}
end

local function withPlayers(session: Trading.Session, fn: (Player, Player, any, any) -> any)
	local leftPlayer = Players:GetPlayerByUserId(session.left.userId)
	local rightPlayer = Players:GetPlayerByUserId(session.right.userId)
	if leftPlayer == nil or rightPlayer == nil then
		return fail("That player is not here.")
	end
	local ids = { session.left.userId, session.right.userId }
	if not Trading.tryLock(ids) then
		return fail("That trade is already finishing.")
	end
	local ok, result = xpcall(function()
		return fn(leftPlayer, rightPlayer)
	end, debug.traceback)
	Trading.unlock(ids)
	if not ok then
		warn("[Shardfall] trade: " .. tostring(result))
		return fail("Could not finish that trade.")
	end
	return result
end

local function previewLive(
	session: Trading.Session,
	leftPlayer: Player,
	rightPlayer: Player
): Trading.Preview?
	local leftData = DataService.get(leftPlayer)
	local rightData = DataService.get(rightPlayer)
	if leftData == nil or rightData == nil then
		return nil
	end
	local now = os.time()
	local paid = paidFor(leftPlayer) and paidFor(rightPlayer)
	return Trading.preview(
		session,
		leftData,
		rightData,
		actorOf(leftPlayer, leftData, now),
		actorOf(rightPlayer, rightData, now),
		contextFor(paid),
		now
	)
end

local function respond(player: Player, session: Trading.Session, extra: any?)
	local otherId = if session.left.userId == player.UserId
		then session.right.userId
		else session.left.userId
	local other = Players:GetPlayerByUserId(otherId)
	local look = nil
	if other ~= nil then
		local leftPlayer = Players:GetPlayerByUserId(session.left.userId)
		local rightPlayer = Players:GetPlayerByUserId(session.right.userId)
		if leftPlayer ~= nil and rightPlayer ~= nil then
			look = previewLive(session, leftPlayer, rightPlayer)
		end
	end
	local payload = {
		ok = true,
		trade = viewOf(session, player.UserId, look),
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end
	return payload
end

function TradeService.snapshot(): { Trading.AuditEntry }
	return Trading.auditLog()
end

function TradeService.restore(entries: { Trading.AuditEntry })
	Trading.restoreAudit(entries)
end

function TradeService.review(query: any): { Trading.AuditEntry }
	return Trading.search(Trading.auditLog(), query)
end

function TradeService.rollback(tradeId: string)
	local entry = Trading.findEntry(Trading.auditLog(), tradeId)
	if entry == nil then
		return fail("No trade with that id.")
	end
	local leftPlayer = Players:GetPlayerByUserId(entry.left.userId)
	local rightPlayer = Players:GetPlayerByUserId(entry.right.userId)
	if leftPlayer == nil or rightPlayer == nil then
		return fail("Both players have to be online to reverse a trade.")
	end
	local ids = { entry.left.userId, entry.right.userId }
	if not Trading.tryLock(ids) then
		return fail("That trade is already finishing.")
	end
	local leftNow = DataService.get(leftPlayer)
	local rightNow = DataService.get(rightPlayer)
	if leftNow == nil or rightNow == nil then
		Trading.unlock(ids)
		return fail("That player is not here.")
	end
	local backupLeft = Schema.deepCopy(leftNow)
	local backupRight = Schema.deepCopy(rightNow)
	local outcome = nil
	local ok, err = DataService.mutate(leftPlayer, function(leftData)
		local rightData = DataService.get(rightPlayer)
		if rightData == nil then
			return "That player is not here."
		end
		local reversed, why = Trading.rollback(entry, leftData, rightData)
		if not reversed then
			return why or "Could not reverse that trade."
		end
		outcome = { ok = true, auditId = entry.id }
		return nil
	end)
	Trading.unlock(ids)
	if not ok then
		return fail(err or "Could not reverse that trade.")
	end
	local saved = DataService.savePair(leftPlayer, rightPlayer, backupLeft, backupRight)
	if not saved then
		entry.reversed = false
		return fail(SAVE_FAILED)
	end
	persistAudit()
	return outcome or fail("Could not reverse that trade.")
end

function TradeService.onPlayerRemoving(player: Player)
	local session = sessionFor(player.UserId)
	if session == nil or session.status ~= "open" or session.settling then
		return
	end
	Trading.cancel(session, player.UserId)
	forget(session)
end

function TradeService.start()
	if started then
		return
	end
	started = true
	local loaded, entries = pcall(function()
		return TradeAudit.load()
	end)
	if not loaded then
		warn("[Shardfall] trade audit unavailable, using an empty log: " .. tostring(entries))
		entries = {}
	end
	if type(entries) == "table" and #entries > 0 then
		Trading.restoreAudit(entries)
	end
	local connected, connectErr = pcall(function()
		Players.PlayerRemoving:Connect(function(player)
			TradeService.onPlayerRemoving(player)
		end)
	end)
	if not connected then
		warn("[Shardfall] trade could not watch leaving players: " .. tostring(connectErr))
	end
end

local function invite(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.targetUserId) ~= "number" then
		return fail("That player is not here.")
	end
	local targetId = payload.targetUserId
	if targetId % 1 ~= 0 or targetId < 1 then
		return fail("That player is not here.")
	end
	if targetId == player.UserId then
		return fail("You cannot trade with yourself.")
	end
	local target = Players:GetPlayerByUserId(targetId)
	if target == nil then
		return fail("That player is not here.")
	end
	local mine = sessionFor(player.UserId)
	if mine ~= nil and mine.status == "open" then
		return fail("You are already in a trade.")
	end
	local theirs = sessionFor(targetId)
	if theirs ~= nil and theirs.status == "open" then
		return fail("That player is already in a trade.")
	end
	local now = os.time()
	local session, err = Trading.open(Trading.nextId("trade", now), player.UserId, targetId, now)
	if session == nil then
		return fail(err or "Bad trade.")
	end
	sessions[session.id] = session
	byUser[player.UserId] = session.id
	byUser[targetId] = session.id
	return respond(player, session, nil)
end

local function offer(player: Player, payload: any)
	local session = sessionFor(player.UserId)
	if session == nil then
		return fail("You are not in this trade.")
	end
	local okSet, err = Trading.setOffer(session, player.UserId, payload, os.time())
	if not okSet then
		return fail(err or "That offer is not valid.")
	end
	return respond(player, session, nil)
end

local function confirm(player: Player)
	local session = sessionFor(player.UserId)
	if session == nil then
		return fail("You are not in this trade.")
	end
	local okSet, err = Trading.confirm(session, player.UserId, os.time())
	if not okSet then
		return fail(err or Trading.LOCK_MESSAGE)
	end
	return respond(player, session, nil)
end

local function commit(player: Player, payload: any)
	local session = sessionFor(player.UserId)
	if session == nil then
		return fail("You are not in this trade.")
	end
	local acceptWarning = type(payload) == "table" and payload.acceptWarning == true
	return withPlayers(session, function(leftPlayer, rightPlayer)
		local leftNow = DataService.get(leftPlayer)
		local rightNow = DataService.get(rightPlayer)
		if leftNow == nil or rightNow == nil then
			return fail("That player is not here.")
		end
		local backupLeft = Schema.deepCopy(leftNow)
		local backupRight = Schema.deepCopy(rightNow)
		local result = nil
		local ok, err = DataService.mutate(leftPlayer, function(leftData)
			local rightData = DataService.get(rightPlayer)
			if rightData == nil then
				return "That player is not here."
			end
			local now = os.time()
			local paid = paidFor(leftPlayer) and paidFor(rightPlayer)
			result = Trading.finish(
				session,
				player.UserId,
				leftData,
				rightData,
				actorOf(leftPlayer, leftData, now),
				actorOf(rightPlayer, rightData, now),
				contextFor(paid),
				now,
				acceptWarning
			)
			if not result.ok then
				return result.error or "Could not finish that trade."
			end
			return nil
		end)
		if not ok then
			return fail(err or "Could not finish that trade.")
		end
		if
			result ~= nil
			and result.ok == true
			and result.pending ~= true
			and result.already ~= true
		then
			local saved = DataService.savePair(leftPlayer, rightPlayer, backupLeft, backupRight)
			if not saved then
				Trading.reopen(session)
				if type(result.auditId) == "string" then
					Trading.dropEntry(Trading.auditLog(), result.auditId)
				end
				return fail(SAVE_FAILED)
			end
			persistAudit()
			forget(session)
		end
		local extra = {
			auditId = if result ~= nil then result.auditId else nil,
			pending = if result ~= nil then result.pending else nil,
			already = if result ~= nil then result.already else nil,
			warning = if result ~= nil then result.warning else nil,
			flags = if result ~= nil then result.flags else nil,
		}
		return respond(player, session, extra)
	end)
end

local function cancel(player: Player)
	local session = sessionFor(player.UserId)
	if session == nil then
		return fail("You are not in this trade.")
	end
	local okSet, err = Trading.cancel(session, player.UserId)
	if not okSet then
		return fail(err or "That trade is closed.")
	end
	forget(session)
	return { ok = true }
end

local function history(player: Player)
	local rows = Trading.search(Trading.auditLog(), { userId = player.UserId })
	local client = {}
	for _, entry in ipairs(rows) do
		table.insert(client, Trading.clientEntry(entry))
	end
	return { ok = true, history = client }
end

local function report(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.tradeId) ~= "string" then
		return fail("No trade with that id.")
	end
	local tradeId = payload.tradeId
	if #tradeId < 1 or #tradeId > 80 or string.match(tradeId, "^[%w%-]+$") == nil then
		return fail("No trade with that id.")
	end
	local okSet, err = Trading.report(Trading.auditLog(), tradeId, player.UserId)
	if not okSet then
		return fail(err or "No trade with that id.")
	end
	if not TradeAudit.save(Trading.auditLog()) then
		return fail("Could not save that report.")
	end
	return { ok = true }
end

function TradeService.handle(player: Player, action: any, payload: any)
	if action == "invite" then
		return invite(player, payload)
	end
	if action == "offer" then
		return offer(player, payload)
	end
	if action == "confirm" then
		return confirm(player)
	end
	if action == "commit" then
		return commit(player, payload)
	end
	if action == "cancel" then
		return cancel(player)
	end
	if action == "history" then
		return history(player)
	end
	if action == "report" then
		return report(player, payload)
	end
	if action == "state" then
		local session = sessionFor(player.UserId)
		if session == nil then
			return { ok = true, trade = nil }
		end
		return respond(player, session, nil)
	end
	return fail("Unknown trade action.")
end

return TradeService
