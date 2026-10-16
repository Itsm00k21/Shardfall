--!strict

--[[
	Roblox backing store for the cross-server market.

	DataStores hold the listing and the seller mailbox. MemoryStore sorted
	maps are the price index, one map per category, with a TTL equal to the
	time left on the listing. MessagingService tells the seller's server to
	deliver. Calls are single attempts; MarketCross retries them.
]]

local MarketStore = {}

local LISTINGS = "ShardfallMarketListings"
local MAILBOX = "ShardfallMarketMailbox"
local MAP_PREFIX = "ShardfallMarket_"
local TOPIC = "ShardfallMarket"
local PROBE_MAP = "ShardfallMarketProbe"
local PROBE_STORE = "ShardfallMarketProbe"

local function listingsStore()
	return game:GetService("DataStoreService"):GetDataStore(LISTINGS)
end

local function mailboxStore()
	return game:GetService("DataStoreService"):GetDataStore(MAILBOX)
end

local function sortedMap(category: string)
	local name = MAP_PREFIX .. category
	return game:GetService("MemoryStoreService"):GetSortedMap(name)
end

function MarketStore.probe(): (boolean, string?)
	local ok, err = pcall(function()
		local map = game:GetService("MemoryStoreService"):GetSortedMap(PROBE_MAP)
		map:SetAsync("probe", { ok = true }, 30)
		local store = game:GetService("DataStoreService"):GetDataStore(PROBE_STORE)
		store:UpdateAsync("probe", function(current)
			return current
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

function MarketStore.open(): any
	local maps: { [string]: any } = {}
	local deps = {
		listings = {},
		mailbox = {},
		maps = {},
		bus = {},
		sleep = function(try: number)
			task.wait(try)
		end,
	}
	function deps.listings:getAsync(key: string)
		return listingsStore():GetAsync(key)
	end
	function deps.listings:updateAsync(key: string, transform: (any) -> any)
		return listingsStore():UpdateAsync(key, transform)
	end
	function deps.mailbox:getAsync(key: string)
		return mailboxStore():GetAsync(key)
	end
	function deps.mailbox:updateAsync(key: string, transform: (any) -> any)
		return mailboxStore():UpdateAsync(key, transform)
	end
	function deps.maps:map(category: string)
		local sorted = maps[category]
		if sorted == nil then
			sorted = sortedMap(category)
			maps[category] = sorted
		end
		local wrapper = {}
		function wrapper.set(_wrapper, key: string, value: any, ttl: number)
			sorted:SetAsync(key, value, ttl)
		end
		function wrapper.remove(_wrapper, key: string)
			sorted:RemoveAsync(key)
		end
		function wrapper.getRange(_wrapper, direction: string, count: number)
			local order = Enum.SortDirection.Ascending
			if direction == "Desc" then
				order = Enum.SortDirection.Descending
			end
			return sorted:GetRangeAsync(order, count)
		end
		return wrapper
	end
	function deps.bus:publish(userId: number, kind: string)
		game:GetService("MessagingService"):PublishAsync(TOPIC, {
			userId = userId,
			kind = kind,
		})
		return true
	end
	return deps
end

function MarketStore.listen(callback: (number) -> ())
	task.spawn(function()
		local ok, err = pcall(function()
			game:GetService("MessagingService"):SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and type(data.userId) == "number" then
					callback(data.userId)
				end
			end)
		end)
		if not ok then
			warn("[Shardfall] market messages are off:", err)
		end
	end)
end

return MarketStore
