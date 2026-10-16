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

local function current(): any
	if adapter ~= nil then
		return adapter
	end
	local DataStoreService = game:GetService("DataStoreService")
	local probed, probeErr = pcall(function()
		local probe = DataStoreService:GetDataStore(STORE_NAME)
		probe:UpdateAsync("__shardfall_trade_probe", function(document)
			return document
		end)
	end)
	if probed then
		local store = DataStoreService:GetDataStore(STORE_NAME)
		local real = {
			persistent = true,
		}
		function real:updateAsync(key: string, transform: (any) -> any)
			return store:UpdateAsync(key, transform)
		end
		adapter = real
		return real
	end
	local memory = memoryStore().new()
	adapter = memory
	warn("[Shardfall] trade audit is in memory for this server:", probeErr)
	return memory
end

function TradeAudit.load(): { any }
	local entries: { any } = {}
	local ok, err = pcall(function()
		current():updateAsync(KEY, function(document)
			if type(document) == "table" and type(document.entries) == "table" then
				entries = schema().deepCopy(document.entries)
			end
			return nil
		end)
	end)
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
