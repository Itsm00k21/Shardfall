--!strict

--[[
	The 180-day trade log, off the player profile.

	One DataStore key holds the entries Trading already keeps in memory.
	Studio without API access falls back to MemoryStore. Callers pass the
	log in; this module does not require Trading.

	Tests bind() a MemoryStore before load or save, so this file never
	touches DataStoreService unless a server calls it unbound.
]]

local TradeAudit = {}

local STORE_NAME = "ShardfallTradeAudit"
local KEY = "log"

local adapter: any = nil
local schemaModule: any = nil
local memoryModule: any = nil
local budgetModule: any = nil

function TradeAudit.bind(nextAdapter: any)
	adapter = nextAdapter
end

local function schema(): any
	if schemaModule ~= nil then
		return schemaModule
	end
	local ok, result = pcall(require, "../../ReplicatedStorage/Shared/Schema")
	if ok then
		schemaModule = result
		return result
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	schemaModule = require(ReplicatedStorage.Shared.Schema)
	return schemaModule
end

local function memoryStore(): any
	if memoryModule ~= nil then
		return memoryModule
	end
	local ok, result = pcall(require, "../../ReplicatedStorage/Shared/MemoryStore")
	if ok then
		memoryModule = result
		return result
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	memoryModule = require(ReplicatedStorage.Shared.MemoryStore)
	return memoryModule
end

local function budget(): any
	if budgetModule ~= nil then
		return budgetModule
	end
	local ok, result = pcall(require, "../../ReplicatedStorage/Shared/CallBudget")
	if ok then
		budgetModule = result
		return result
	end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	budgetModule = require(ReplicatedStorage.Shared.CallBudget)
	return budgetModule
end

local function openStore(): any
	local DataStoreService = game:GetService("DataStoreService")
	local limits = budget()
	local probed, probeErr = limits.run(limits.DATASTORE_SECONDS, function()
		local probe = DataStoreService:GetDataStore(STORE_NAME)
		probe:UpdateAsync("__shardfall_trade_probe", function(document)
			return document
		end)
		return true
	end)
	if probed then
		local store = DataStoreService:GetDataStore(STORE_NAME)
		local real = {
			persistent = true,
		}
		function real:updateAsync(key: string, transform: (any) -> any)
			return store:UpdateAsync(key, transform)
		end
		return real
	end
	warn("[Shardfall] trade audit is in memory for this server:", probeErr)
	return memoryStore().new()
end

local function current(): any
	if adapter ~= nil then
		return adapter
	end
	local opened, store = pcall(openStore)
	if not opened or store == nil then
		warn("[Shardfall] trade audit unavailable, using an empty log: " .. tostring(store))
		store = memoryStore().new()
	end
	adapter = store
	return store
end

function TradeAudit.load(): { any }
	local entries: { any } = {}
	local store = current()
	local function read()
		store:updateAsync(KEY, function(document)
			if type(document) == "table" and type(document.entries) == "table" then
				entries = schema().deepCopy(document.entries)
			end
			return nil
		end)
		return true
	end
	-- Memory (tests, and Studio after the probe fails) returns immediately.
	-- A live DataStore read is budgeted so a hung UpdateAsync cannot stall startup.
	local ok, err
	if store.persistent == true then
		local limits = budget()
		ok, err = limits.run(limits.DATASTORE_SECONDS, read)
	else
		ok, err = pcall(read)
	end
	if not ok then
		warn("[Shardfall] trade audit load failed:", err)
		return {}
	end
	return entries
end

function TradeAudit.save(entries: { any }): boolean
	local copy = schema().deepCopy(entries)
	local ok, err = pcall(function()
		current():updateAsync(KEY, function()
			return { entries = copy }
		end)
	end)
	if not ok then
		warn("[Shardfall] trade audit save failed:", err)
		return false
	end
	return true
end

return TradeAudit
