--!strict

--[[
	Haven Market Board.

	A listing reserves the goods and sinks a 5% gold fee immediately.
	The fee is not returned if the seller cancels or the listing expires.
	The sale pays the seller the full asking price. Items stay in the
	seller's bag until a buyer commits, and the buyer is re-checked
	against the live bag so a crash cannot delete the goods.

	Buy claims the listing before it moves anything. A second buy sees
	a sold listing and does not grant a second copy.
]]

local Materials = require("./Materials")
local Schema = require("./Schema")
local Trading = require("./Trading")

local MarketBoard = {}

MarketBoard.FEE_RATE = 0.05
MarketBoard.LISTING_SECONDS = 48 * 60 * 60
MarketBoard.MIN_PRICE = 1
MarketBoard.MAX_PRICE = 100000000
MarketBoard.LISTING_CAP = {
	New = 4,
	Standard = 8,
	Trusted = 20,
	Patron = 20,
}

export type Listing = {
	id: string,
	sellerUserId: number,
	sellerName: string,
	price: number,
	currency: string,
	fee: number,
	offer: Trading.Offer,
	details: { any },
	createdAt: number,
	expiresAt: number,
	status: string,
	buyerUserId: number?,
	version: number,
}

export type Board = {
	listings: { [string]: Listing },
}

export type Result = {
	ok: boolean,
	error: string?,
	listing: any?,
	listings: { any }?,
	auditId: string?,
	flags: { string }?,
}

function MarketBoard.new(): Board
	return {
		listings = {},
	}
end

function MarketBoard.fee(price: number, currency: string): number
	local goldPrice = price
	if currency == "gems" then
		goldPrice = price * Trading.GEM_GOLD
	end
	if goldPrice <= 0 then
		return 0
	end
	local amount = math.floor(goldPrice * MarketBoard.FEE_RATE)
	if amount < 1 then
		return 1
	end
	return amount
end

function MarketBoard.sweep(board: Board, now: number)
	for id, listing in pairs(board.listings) do
		if listing.status == "open" and listing.expiresAt <= now then
			listing.status = "expired"
			listing.version += 1
			Trading.release(id)
		end
	end
end

local function fail(message: string): Result
	return { ok = false, error = message }
end

local function summaryName(offer: Trading.Offer): string
	if #offer.items > 0 then
		return "Listed goods"
	end
	for id, count in pairs(offer.materials) do
		return string.format("%s x%d", Materials.displayName(id), count)
	end
	for tier, count in pairs(offer.chests) do
		return string.format("%s Chest x%d", tier, count)
	end
	return "Listing"
end

function MarketBoard.view(listing: Listing, _sellerData: any?): any
	local names = {}
	for _, row in ipairs(listing.details) do
		table.insert(
			names,
			string.format(
				"%s (%s %s)",
				tostring(row.name),
				tostring(row.rarity),
				tostring(row.kind)
			)
		)
	end
	for id, count in pairs(listing.offer.materials) do
		table.insert(
			names,
			string.format("%s x%d (%s)", Materials.displayName(id), count, Materials.rarityName(id))
		)
	end
	for tier, count in pairs(listing.offer.chests) do
		table.insert(names, string.format("%s Chest x%d", tier, count))
	end
	return {
		id = listing.id,
		sellerUserId = listing.sellerUserId,
		sellerName = listing.sellerName,
		price = listing.price,
		currency = listing.currency,
		fee = listing.fee,
		items = table.clone(listing.offer.items),
		materials = table.clone(listing.offer.materials),
		chests = table.clone(listing.offer.chests),
		createdAt = listing.createdAt,
		expiresAt = listing.expiresAt,
		status = listing.status,
		name = if #names > 0 then table.concat(names, ", ") else summaryName(listing.offer),
	}
end

function MarketBoard.line(view: any): string
	return string.format(
		"%s  %d %s  %s",
		tostring(view.name or view.id),
		view.price or 0,
		tostring(view.currency or "gold"),
		tostring(view.sellerName or "")
	)
end

local function capFor(actor: Trading.Actor): number
	local tier = Trading.tier(actor)
	return MarketBoard.LISTING_CAP[tier] or MarketBoard.LISTING_CAP.New
end

local function readPrice(raw: any): (number?, string?, string?)
	if type(raw) ~= "table" then
		return nil, nil, "Set a price."
	end
	local currency = raw.currency
	if currency ~= "gold" and currency ~= "gems" then
		return nil, nil, "Set a price."
	end
	local price = tonumber(raw.price)
	if price == nil or price ~= price then
		return nil, nil, "Set a price."
	end
	price = math.floor(price)
	if price < MarketBoard.MIN_PRICE or price > MarketBoard.MAX_PRICE then
		return nil, nil, "Set a price."
	end
	return price, currency, nil
end

local function moveOffer(from: any, to: any, offer: Trading.Offer): string?
	for _, uid in ipairs(offer.items) do
		local item, err = Trading.takeItem(from, uid)
		if item == nil then
			return err
		end
		local giveErr = Trading.giveItem(to, item)
		if giveErr ~= nil then
			Trading.giveItem(from, item)
			return giveErr
		end
	end
	for id, count in pairs(offer.materials) do
		local takeErr = Trading.takeMaterial(from, id, count)
		if takeErr ~= nil then
			return takeErr
		end
		local giveErr = Trading.giveMaterial(to, id, count)
		if giveErr ~= nil then
			Trading.giveMaterial(from, id, count)
			return giveErr
		end
	end
	for tier, count in pairs(offer.chests) do
		local takeErr = Trading.takeChest(from, tier, count)
		if takeErr ~= nil then
			return takeErr
		end
		local giveErr = Trading.giveChest(to, tier, count)
		if giveErr ~= nil then
			Trading.giveChest(from, tier, count)
			return giveErr
		end
	end
	return nil
end

local function offerLines(
	data: any,
	offer: Trading.Offer,
	fromId: number,
	toId: number
): { Trading.AuditLine }
	local lines: { Trading.AuditLine } = {}
	for _, uid in ipairs(offer.items) do
		local item = Schema.findItem(data, uid)
		local templateId = uid
		local name = "Item"
		local rarity = ""
		local itemKind = ""
		local value = 0
		if type(item) == "table" then
			if type(item.templateId) == "string" and item.templateId ~= "" then
				templateId = item.templateId
			end
			name = tostring(item.name or "Item")
			rarity = tostring(item.rarity or "")
			itemKind = tostring(item.kind or "")
			value = Trading.estimateItem(item)
		end
		table.insert(lines, {
			kind = "item",
			id = templateId,
			uid = uid,
			count = 1,
			name = name,
			rarity = rarity,
			itemKind = itemKind,
			fromUserId = fromId,
			toUserId = toId,
			value = value,
			tax = 0,
		})
	end
	for id, count in pairs(offer.materials) do
		table.insert(lines, {
			kind = "material",
			id = id,
			uid = "",
			count = count,
			name = Materials.displayName(id),
			rarity = Materials.rarityName(id),
			itemKind = "Material",
			fromUserId = fromId,
			toUserId = toId,
			value = Trading.estimateMaterial(id, count),
			tax = 0,
		})
	end
	for tier, count in pairs(offer.chests) do
		table.insert(lines, {
			kind = "chest",
			id = tier,
			uid = "",
			count = count,
			name = tier .. " Chest",
			rarity = tier,
			itemKind = "Chest",
			fromUserId = fromId,
			toUserId = toId,
			value = Trading.estimateChest(tier, count),
			tax = 0,
		})
	end
	return lines
end

function MarketBoard.list(
	board: Board,
	seller: any,
	actor: Trading.Actor,
	raw: any,
	context: Trading.Context,
	now: number
): Result
	MarketBoard.sweep(board, now)
	local price, currency, priceErr = readPrice(raw)
	if price == nil or currency == nil then
		return fail(priceErr or "Set a price.")
	end
	local offer, offerErr = Trading.normalize({
		gold = 0,
		gems = 0,
		items = raw.items,
		materials = raw.materials,
		chests = raw.chests,
	})
	if offer == nil then
		return fail(offerErr or "That offer is not valid.")
	end
	if Trading.offerEmpty(offer) then
		return fail("Add something to the listing.")
	end
	if currency == "gems" then
		local allowed, why = Trading.canTradeGems(actor, context.paidTradingAllowed)
		if not allowed then
			return fail(why or "Gem trades are turned off.")
		end
	end
	if Trading.holdCountFor(actor.userId) >= capFor(actor) then
		return fail("Too many listings.")
	end
	local value, why = Trading.inspect(seller, actor, offer, now, context, nil)
	if value == nil then
		return fail(why or "That item cannot be traded.")
	end
	local fee = MarketBoard.fee(price, currency)
	Trading.prepare(seller)
	if (seller.gold or 0) < fee then
		return fail("Not enough gold for the listing fee.")
	end
	local listingId = Trading.nextId("list", now)
	local snap = Trading.capture(seller)
	local feeErr = Trading.takeMoney(seller, "gold", fee, "market_fee")
	if feeErr ~= nil then
		Trading.restore(seller, snap)
		return fail(feeErr)
	end
	local reserved, reserveErr = Trading.reserve(listingId, actor.userId, offer)
	if not reserved then
		Trading.restore(seller, snap)
		return fail(reserveErr or "That item is listed on the Market Board.")
	end
	Trading.addSpent(seller, actor.userId, context, now, value)
	local details = {}
	for _, uid in ipairs(offer.items) do
		local item = Schema.findItem(seller, uid)
		if type(item) == "table" then
			table.insert(details, {
				uid = uid,
				name = tostring(item.name or "Item"),
				rarity = tostring(item.rarity or ""),
				kind = tostring(item.kind or ""),
				templateId = tostring(item.templateId or ""),
				tooltip = Trading.tooltip(item),
			})
		end
	end
	local listing: Listing = {
		id = listingId,
		sellerUserId = actor.userId,
		sellerName = actor.name,
		price = price,
		currency = currency,
		fee = fee,
		offer = offer,
		details = details,
		createdAt = now,
		expiresAt = now + MarketBoard.LISTING_SECONDS,
		status = "open",
		buyerUserId = nil,
		version = 1,
	}
	board.listings[listingId] = listing
	return {
		ok = true,
		listing = MarketBoard.view(listing, seller),
	}
end

function MarketBoard.cancel(
	board: Board,
	actor: Trading.Actor,
	listingId: string,
	now: number
): Result
	MarketBoard.sweep(board, now)
	local listing = board.listings[listingId]
	if listing == nil or listing.status ~= "open" then
		return fail("That listing is gone.")
	end
	if listing.sellerUserId ~= actor.userId then
		return fail("That listing is not yours.")
	end
	listing.status = "cancelled"
	listing.version += 1
	Trading.release(listingId)
	return { ok = true, listing = MarketBoard.view(listing, nil) }
end

local function matches(listing: Listing, filter: any): boolean
	if type(filter) ~= "table" then
		return true
	end
	if filter.currency ~= nil and listing.currency ~= filter.currency then
		return false
	end
	if filter.sellerUserId ~= nil and listing.sellerUserId ~= filter.sellerUserId then
		return false
	end
	if filter.kind == nil and filter.rarity == nil and filter.search == nil then
		return true
	end
	local hay = string.lower(MarketBoard.view(listing, nil).name)
	if
		filter.search ~= nil
		and string.find(hay, string.lower(tostring(filter.search)), 1, true) == nil
	then
		return false
	end
	if
		filter.kind ~= nil
		and string.find(hay, string.lower(tostring(filter.kind)), 1, true) == nil
	then
		return false
	end
	if
		filter.rarity ~= nil
		and string.find(hay, string.lower(tostring(filter.rarity)), 1, true) == nil
	then
		return false
	end
	return true
end

function MarketBoard.browse(board: Board, filter: any, now: number): { any }
	MarketBoard.sweep(board, now)
	local rows = {}
	for _, listing in pairs(board.listings) do
		if listing.status == "open" and matches(listing, filter) then
			table.insert(rows, listing)
		end
	end
	table.sort(rows, function(a, b)
		if a.createdAt == b.createdAt then
			return a.id > b.id
		end
		return a.createdAt > b.createdAt
	end)
	local views = {}
	for _, listing in ipairs(rows) do
		table.insert(views, MarketBoard.view(listing, nil))
	end
	return views
end

function MarketBoard.mine(board: Board, userId: number, now: number): { any }
	return MarketBoard.browse(board, { sellerUserId = userId }, now)
end

local function priceValue(listing: Listing): number
	if listing.currency == "gems" then
		return listing.price * Trading.GEM_GOLD
	end
	return listing.price
end

function MarketBoard.buy(
	board: Board,
	listingId: string,
	buyer: any,
	buyerActor: Trading.Actor,
	seller: any,
	sellerActor: Trading.Actor,
	context: Trading.Context,
	now: number
): Result
	MarketBoard.sweep(board, now)
	local listing = board.listings[listingId]
	if listing == nil or listing.status ~= "open" then
		return fail("That listing is gone.")
	end
	if listing.sellerUserId == buyerActor.userId then
		return fail("You cannot buy your own listing.")
	end
	if sellerActor.userId ~= listing.sellerUserId then
		return fail("The seller is not here.")
	end
	if listing.currency == "gems" then
		local buyerGems, buyerWhy = Trading.canTradeGems(buyerActor, context.paidTradingAllowed)
		if not buyerGems then
			return fail(buyerWhy or "Gem trades are turned off.")
		end
		local sellerGems, sellerWhy = Trading.canTradeGems(sellerActor, context.paidTradingAllowed)
		if not sellerGems then
			return fail(sellerWhy or "Gem trades are turned off.")
		end
	end
	local blocked = if buyerActor.tradeLocked == true or buyerActor.flagged == true
		then "This account cannot trade."
		else nil
	if blocked ~= nil then
		return fail(blocked)
	end
	local goodsValue, goodsErr =
		Trading.inspect(seller, sellerActor, listing.offer, now, context, listing.id, false)
	if goodsValue == nil then
		return fail(goodsErr or "That listing is gone.")
	end
	Trading.prepare(buyer)
	local paying = listing.price
	local have = if listing.currency == "gems" then buyer.gems or 0 else buyer.gold or 0
	if have < paying then
		if listing.currency == "gems" then
			return fail("Not enough gems.")
		end
		return fail("Not enough gold.")
	end
	local cost = priceValue(listing)
	if cost > Trading.tradeCap(buyerActor) then
		return fail("That trade is over today's limit.")
	end
	local already = Trading.spentToday(buyer, buyerActor.userId, context, now)
	if already + cost > Trading.dailyCap(buyerActor) then
		return fail("That trade is over today's limit.")
	end
	Trading.prepare(buyer)
	if Schema.countItems(buyer) + #listing.offer.items > Schema.inventoryCap(buyer) then
		return fail("Inventory is full.")
	end

	listing.status = "sold"
	listing.version += 1
	listing.buyerUserId = buyerActor.userId

	local lines = offerLines(seller, listing.offer, sellerActor.userId, buyerActor.userId)
	table.insert(lines, {
		kind = listing.currency,
		id = listing.currency,
		uid = "",
		count = listing.price,
		name = if listing.currency == "gems" then "Gems" else "Gold",
		rarity = "",
		itemKind = "Currency",
		fromUserId = buyerActor.userId,
		toUserId = sellerActor.userId,
		value = cost,
		tax = 0,
	})

	local snapBuyer = Trading.capture(buyer)
	local snapSeller = Trading.capture(seller)
	local moved, reason = xpcall(function()
		local moveErr = moveOffer(seller, buyer, listing.offer)
		if moveErr == nil then
			moveErr = Trading.takeMoney(buyer, listing.currency, listing.price, "market_buy")
		end
		if moveErr == nil then
			moveErr = Trading.giveMoney(seller, listing.currency, listing.price, "market_sale")
		end
		return moveErr
	end, debug.traceback)
	if not moved or reason ~= nil then
		Trading.restore(buyer, snapBuyer)
		Trading.restore(seller, snapSeller)
		listing.status = "open"
		listing.buyerUserId = nil
		listing.version += 1
		if not moved then
			return fail("Could not buy that.")
		end
		return fail(reason :: string)
	end

	Trading.release(listing.id)
	local sellerValue = goodsValue or 0
	local entry = Trading.recordMarket(
		context,
		sellerActor,
		buyerActor,
		lines,
		sellerValue,
		cost,
		now,
		listing.id,
		nil
	)
	Trading.addSpent(buyer, buyerActor.userId, context, now, cost)
	return {
		ok = true,
		auditId = entry.id,
		flags = entry.flags,
		listing = MarketBoard.view(listing, nil),
	}
end

return MarketBoard
