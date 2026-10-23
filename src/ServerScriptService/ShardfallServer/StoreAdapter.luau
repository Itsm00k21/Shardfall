--!strict

--[[
	The thing DataService writes through.

	A real DataStore when Studio API access works, otherwise a table in this
	server's memory. Both speak updateAsync(key, transform):

	  transform(old) -> new value to store
	  transform(old) -> nil means "do not change the key" (same as DataStore)

	The probe uses UpdateAsync, not GetAsync, because the Security setting
	blocks writes specifically. An unpublished place fails the probe too —
	DataStores belong to a published universe.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CallBudget = require(ReplicatedStorage.Shared.CallBudget)
local MemoryStore = require(ReplicatedStorage.Shared.MemoryStore)

local StoreAdapter = {}

-- [ECHO hook] Studio uses the memory store unless this is turned on.
-- A published server ignores it and still probes the live DataStore.
-- Off by default so an API-on Studio session does not write live keys.
StoreAdapter.STUDIO_LIVE = false

local DATASTORE_NAME = "ShardfallPlayer_v1"
local PROBE_STORE = "ShardfallProbe"
local MAX_ATTEMPTS = 3

export type Adapter = {
	persistent: boolean,
	updateAsync: (self: Adapter, key: string, transform: (any) -> any) -> any,
}

local function withRetries(callback: () -> any): any
	local lastError = nil
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return result
		end
		lastError = result
		if attempt < MAX_ATTEMPTS then
			task.wait(attempt)
		end
	end
	error(tostring(lastError), 0)
end

local function dataStoreAdapter(): Adapter
	local store = DataStoreService:GetDataStore(DATASTORE_NAME)
	local adapter = {} :: Adapter
	function adapter:updateAsync(key: string, transform: (any) -> any)
		return withRetries(function()
			return store:UpdateAsync(key, transform)
		end)
	end
	adapter.persistent = true
	return adapter
end

function StoreAdapter.connect(): (Adapter, string?)
	-- [ECHO hook]
	if RunService:IsStudio() and StoreAdapter.STUDIO_LIVE ~= true then
		local memory = MemoryStore.new() :: Adapter
		return memory, "Studio memory store (StoreAdapter.STUDIO_LIVE is off)"
	end
	-- The probe has to finish. Studio with API access off can leave
	-- UpdateAsync yielded, and DataService.start used to wait there forever.
	local ok, err = CallBudget.run(CallBudget.DATASTORE_SECONDS, function()
		local probe = DataStoreService:GetDataStore(PROBE_STORE)
		probe:UpdateAsync("__shardfall_probe", function(current)
			return current
		end)
		return true
	end)
	if ok then
		return dataStoreAdapter(), nil
	end
	local memory = MemoryStore.new() :: Adapter
	return memory, tostring(err)
end

return StoreAdapter
