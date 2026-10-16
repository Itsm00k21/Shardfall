--!strict

--[[
	Server entry for the Haven Market Board.

	Ghost wires handle() from the Market remote and calls start() before
	DataService.start(). Listings live in memory until a persistence hook
	loads them. exportBoard() / importBoard() are that hook.

	The listing fee and the sale both go through DataService.mutate. Buy
	claims the listing inside the lock so a second buyer cannot take a
	second copy.

	When MARKET_XSERVER_ENABLED is on and MemoryStore plus DataStores answer,
	listings are escrowed off the seller and paid out through a mailbox.
	Otherwise this server keeps the in-memory board.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local MarketStore = require(script.Parent.MarketStore)
local TradeAudit = require(script.Parent.TradeAudit)
local MarketBoard = require(ReplicatedStorage.Shared.MarketBoard)
local MarketCross = require(ReplicatedStorage.Shared.MarketCross)
local PolicyCache = require(script.Parent.PolicyCache)
local Schema = require(ReplicatedStorage.Shared.Schema)
local Trading = require(ReplicatedStorage.Shared.Trading)

local MarketService = {}

local board = MarketBoard.new()
local started = false
local crossDeps: any = nil
local delivering: { [Player]: boolean } = {}
local deliverAgain: { [Player]: boolean } = {}
local seenJoin: { [Player]: boolean } = {}

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

local function actorOf(player: Player, data: any, now: number): Trading.Actor
	local age = player.AccountAge
	if type(age) ~= "number" then
		age = 0
	end
	local clean = age
	if type(data.tradeCleanSince) == "number" and data.tradeCleanSince > 0 then
		clean = math.floor((now - data.tradeCleanSince) / 86400)
		if clean < 0 then
			clean = 0
		end
	end
	return {
		userId = player.UserId,
		name = player.Name,
		level = if type(data.level) == "number" then data.level else 1,
		accountAgeDays = age,
		cleanHistoryDays = clean,
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

local SAVE_FAILED = "Could not save that trade. Nothing was kept."

local function persistAudit()
	if not TradeAudit.save(Trading.auditLog()) then
		warn("[Shardfall] trade audit did not save")
	end
end

local function usingCross(): boolean
	return MarketCross.MARKET_XSERVER_ENABLED == true and crossDeps ~= nil
end

local function crossContext(player: Player?): Trading.Context
	if player == nil then
		return Trading.shared(serverId, true)
	end
	return contextFor(paidFor(player))
end

local function listingId(payload: any): string?
	if type(payload) ~= "table" or type(payload.listingId) ~= "string" then
		return nil
	end
	local id = payload.listingId
	if #id < 1 or #id > 80 or string.match(id, "^[%w%-]+$") == nil then
		return nil
	end
	return id
end

function MarketService.exportBoard(): MarketBoard.Board
	return board
end

function MarketService.importBoard(nextBoard: MarketBoard.Board)
	board = nextBoard
end

function MarketService.audit(): { Trading.AuditEntry }
	return Trading.auditLog()
end

function MarketService.deliver(player: Player)
	if not usingCross() then
		delivering[player] = nil
		return
	end
	if delivering[player] then
		deliverAgain[player] = true
		return
	end
	delivering[player] = true
	local applied = nil
	local ok, err = DataService.mutate(player, function(data)
		local settled, why =
			MarketCross.settle(crossDeps, data, player.UserId, crossContext(player), os.time())
		if settled == nil then
			return why or "Could not deliver market goods."
		end
		applied = settled.applied
		return nil
	end)
	if not ok then
		warn("[Shardfall] market deliver:", err)
		delivering[player] = nil
		return
	end
	if type(applied) == "table" and #applied > 0 then
		local saved = DataService.save(player)
		if not saved then
			warn("[Shardfall] market payout save failed")
			delivering[player] = nil
			return
		end
		if not MarketCross.ack(crossDeps, player.UserId, applied) then
			warn("[Shardfall] market mailbox ack failed")
		end
		persistAudit()
	end
	delivering[player] = nil
	if deliverAgain[player] then
		deliverAgain[player] = nil
		MarketService.deliver(player)
	end
end

function MarketService.onPlayerRemoving(player: Player)
	delivering[player] = nil
	deliverAgain[player] = nil
	seenJoin[player] = nil
	if usingCross() then
		return
	end
	local now = os.time()
	local data = DataService.get(player)
	local actor = if data ~= nil
		then actorOf(player, data, now)
		else {
			userId = player.UserId,
			name = player.Name,
			level = 1,
			accountAgeDays = 0,
			cleanHistoryDays = 0,
			verifiedSpender = false,
			patron = false,
			verifiedTrader = false,
			flagged = false,
			tradeLocked = false,
			recentHandoff = false,
			connected = nil,
		}
	local openIds = {}
	for id, listing in pairs(board.listings) do
		if listing.sellerUserId == player.UserId and listing.status == "open" then
			table.insert(openIds, id)
		end
	end
	for _, id in ipairs(openIds) do
		MarketBoard.cancel(board, actor, id, now)
	end
end

function MarketService.start()
	if started then
		return
	end
	started = true
	if MarketCross.MARKET_XSERVER_ENABLED == true then
		local ready, why = MarketStore.probe()
		if ready then
			crossDeps = MarketStore.open()
			MarketStore.listen(function(userId)
				local player = Players:GetPlayerByUserId(userId)
				if player ~= nil then
					MarketService.deliver(player)
				end
			end)
		else
			warn("[Shardfall] cross-server market is off this server:", why)
		end
	end
	DataService.onChanged(function(player)
		if not usingCross() or seenJoin[player] then
			return
		end
		seenJoin[player] = true
		task.spawn(function()
			MarketService.deliver(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		MarketService.onPlayerRemoving(player)
	end)
end

local function browse(player: Player, payload: any)
	if usingCross() then
		return {
			ok = true,
			listings = MarketCross.browse(crossDeps, payload, crossContext(player), os.time()),
		}
	end
	return {
		ok = true,
		listings = MarketBoard.browse(board, payload, os.time()),
	}
end

local function list(player: Player, payload: any)
	if not Trading.tryLock({ player.UserId }) then
		return fail("That trade is already finishing.")
	end
	local result = nil
	local ok, err = DataService.mutate(player, function(data)
		local now = os.time()
		if usingCross() then
			result = MarketCross.list(
				crossDeps,
				data,
				actorOf(player, data, now),
				payload,
				crossContext(player),
				now
			)
		else
			result = MarketBoard.list(
				board,
				data,
				actorOf(player, data, now),
				payload,
				contextFor(paidFor(player)),
				now
			)
		end
		if not result.ok then
			return result.error or "Could not list that."
		end
		return nil
	end)
	Trading.unlock({ player.UserId })
	if not ok then
		return fail(err or "Could not list that.")
	end
	if usingCross() then
		local saved = DataService.save(player)
		if not saved then
			saved = DataService.save(player)
		end
		if not saved then
			warn("[Shardfall] listed goods are escrowed but the profile save failed")
		end
		persistAudit()
	end
	return result or fail("Could not list that.")
end

local function buyCross(player: Player, id: string)
	if not Trading.tryLock({ player.UserId }) then
		return fail("That trade is already finishing.")
	end
	local buyerNow = DataService.get(player)
	if buyerNow == nil then
		Trading.unlock({ player.UserId })
		return fail("Profile is still loading.")
	end
	local backup = Schema.deepCopy(buyerNow)
	local result = nil
	local ok, err = DataService.mutate(player, function(buyerData)
		local now = os.time()
		result = MarketCross.reserveBuy(
			crossDeps,
			id,
			buyerData,
			actorOf(player, buyerData, now),
			crossContext(player),
			now
		)
		if not result.ok then
			return result.error or "Could not buy that."
		end
		return nil
	end)
	if not ok then
		if result ~= nil and result.claimed == true then
			MarketCross.releaseClaim(crossDeps, id, player.UserId, os.time())
		end
		Trading.unlock({ player.UserId })
		return fail(err or "Could not buy that.")
	end
	local saved = DataService.save(player)
	if not saved then
		DataService.replace(player, backup)
		DataService.save(player)
		MarketCross.releaseClaim(crossDeps, id, player.UserId, os.time())
		Trading.unlock({ player.UserId })
		return fail(SAVE_FAILED)
	end
	local committed = MarketCross.commitSale(
		crossDeps,
		result.record,
		actorOf(player, DataService.get(player) or buyerNow, os.time()),
		crossContext(player),
		os.time()
	)
	if committed.payoutPending == true then
		MarketCross.flushPayout(crossDeps, committed.record or result.record, os.time())
	end
	Trading.unlock({ player.UserId })
	persistAudit()
	return committed
end

local function buy(player: Player, payload: any)
	local id = listingId(payload)
	if id == nil then
		return fail("That listing is gone.")
	end
	if usingCross() then
		return buyCross(player, id)
	end
	local listing = board.listings[id]
	if listing == nil or listing.status ~= "open" then
		return fail("That listing is gone.")
	end
	local seller = Players:GetPlayerByUserId(listing.sellerUserId)
	if seller == nil then
		return fail("The seller is not here.")
	end
	local ids = { player.UserId, seller.UserId }
	if not Trading.tryLock(ids) then
		return fail("That trade is already finishing.")
	end
	local buyerNow = DataService.get(player)
	local sellerNow = DataService.get(seller)
	if buyerNow == nil or sellerNow == nil then
		Trading.unlock(ids)
		return fail("The seller is not here.")
	end
	local backupBuyer = Schema.deepCopy(buyerNow)
	local backupSeller = Schema.deepCopy(sellerNow)
	local result = nil
	local ok, err = DataService.mutate(player, function(buyerData)
		local sellerData = DataService.get(seller)
		if sellerData == nil then
			return "The seller is not here."
		end
		local now = os.time()
		local paid = paidFor(player) and paidFor(seller)
		result = MarketBoard.buy(
			board,
			id,
			buyerData,
			actorOf(player, buyerData, now),
			sellerData,
			actorOf(seller, sellerData, now),
			contextFor(paid),
			now
		)
		if not result.ok then
			return result.error or "Could not buy that."
		end
		return nil
	end)
	Trading.unlock(ids)
	if not ok then
		return fail(err or "Could not buy that.")
	end
	if result ~= nil and result.ok == true then
		local saved = DataService.savePair(player, seller, backupBuyer, backupSeller)
		if not saved then
			local sold = board.listings[id]
			if sold ~= nil then
				sold.status = "open"
				sold.buyerUserId = nil
				sold.version += 1
				local reserved, reserveErr = Trading.reserve(sold.id, sold.sellerUserId, sold.offer)
				if not reserved then
					warn("[Shardfall] market hold was not restored:", reserveErr)
				end
			end
			if type(result.auditId) == "string" then
				Trading.dropEntry(Trading.auditLog(), result.auditId)
			end
			return fail(SAVE_FAILED)
		end
		persistAudit()
	end
	return result or fail("Could not buy that.")
end

local function cancel(player: Player, payload: any)
	local id = listingId(payload)
	if id == nil then
		return fail("That listing is gone.")
	end
	local data = DataService.get(player)
	if data == nil then
		return fail("Profile is still loading.")
	end
	if not Trading.tryLock({ player.UserId }) then
		return fail("That trade is already finishing.")
	end
	local now = os.time()
	if usingCross() then
		local result =
			MarketCross.cancel(crossDeps, actorOf(player, data, now), id, crossContext(player), now)
		Trading.unlock({ player.UserId })
		persistAudit()
		MarketService.deliver(player)
		return result
	end
	local result = MarketBoard.cancel(board, actorOf(player, data, now), id, now)
	Trading.unlock({ player.UserId })
	return result
end

function MarketService.handle(player: Player, action: any, payload: any)
	if action == "browse" then
		return browse(player, payload)
	end
	if action == "list" then
		return list(player, payload)
	end
	if action == "buy" then
		return buy(player, payload)
	end
	if action == "cancel" then
		return cancel(player, payload)
	end
	if action == "mine" then
		if usingCross() then
			return {
				ok = true,
				listings = MarketCross.mine(
					crossDeps,
					player.UserId,
					crossContext(player),
					os.time()
				),
			}
		end
		return {
			ok = true,
			listings = MarketBoard.mine(board, player.UserId, os.time()),
		}
	end
	return fail("Unknown market action.")
end

return MarketService
