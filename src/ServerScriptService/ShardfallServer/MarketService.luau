--!strict

--[[
	Server entry for the Haven Market Board.

	Ghost wires handle() from the Market remote. start() runs after profiles
	are listening. Listings stay in memory when DataStores are unavailable,
	so a missing API does not stop the board from opening.

	The listing fee and the sale both go through DataService.mutate. Buy
	claims the listing inside the lock so a second buyer cannot take a
	second copy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local TradeAudit = require(script.Parent.TradeAudit)
local MarketBoard = require(ReplicatedStorage.Shared.MarketBoard)
local PolicyCache = require(script.Parent.PolicyCache)
local Schema = require(ReplicatedStorage.Shared.Schema)
local Trading = require(ReplicatedStorage.Shared.Trading)

local MarketService = {}

local board = MarketBoard.new()
local started = false

local serverId = if game.JobId ~= "" then game.JobId else "studio"

local function contextFor(paid: boolean): Trading.Context
	return Trading.shared(serverId, paid)
end

local function fail(message: string)
	return { ok = false, error = message }
end

local function hasReceipt(data: any): boolean
	return Trading.verifiedFromReceipts(data)
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
		verifiedSpender = hasReceipt(data),
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

function MarketService.onPlayerRemoving(player: Player)
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
	local connected, connectErr = pcall(function()
		Players.PlayerRemoving:Connect(function(player)
			MarketService.onPlayerRemoving(player)
		end)
	end)
	if not connected then
		warn("[Shardfall] market could not watch leaving players: " .. tostring(connectErr))
	end
end

local function browse(payload: any)
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
		result = MarketBoard.list(
			board,
			data,
			actorOf(player, data, now),
			payload,
			contextFor(paidFor(player)),
			now
		)
		if not result.ok then
			return result.error or "Could not list that."
		end
		return nil
	end)
	Trading.unlock({ player.UserId })
	if not ok then
		return fail(err or "Could not list that.")
	end
	return result or fail("Could not list that.")
end

local function buy(player: Player, payload: any)
	local id = listingId(payload)
	if id == nil then
		return fail("That listing is gone.")
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
	local result = MarketBoard.cancel(board, actorOf(player, data, os.time()), id, os.time())
	Trading.unlock({ player.UserId })
	return result
end

function MarketService.handle(player: Player, action: any, payload: any)
	if not LaunchGate.on("market") then
		return { ok = false, error = "That is closed." }
	end
	if action == "browse" then
		return browse(payload)
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
		return {
			ok = true,
			listings = MarketBoard.mine(board, player.UserId, os.time()),
		}
	end
	return fail("Unknown market action.")
end

return MarketService
