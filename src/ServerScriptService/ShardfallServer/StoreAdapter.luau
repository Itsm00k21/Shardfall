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

local StoreAdapter = {}

local DATASTORE_NAME = "ShardfallPlayer_v1"
local PROBE_STORE = "ShardfallProbe"
local MAX_ATTEMPTS = 3

export type Adapter = {
	persistent: boolean,
	updateAsync: (self: Adapter, key: string, transform: (any) -> any) -> any,
}

local function memoryAdapter(): Adapter
	local stored: { [string]: any } = {}
	local adapter = {} :: Adapter
	function adapter:updateAsync(key: string, transform: (any) -> any)
		local current = stored[key]
		local updated = transform(current)
		if updated == nil then
			return current
		end
		stored[key] = updated
		return updated
	end
	adapter.persistent = false
	return adapter
end

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
	local ok, err = pcall(function()
		local probe = DataStoreService:GetDataStore(PROBE_STORE)
		probe:UpdateAsync("__shardfall_probe", function(current)
			return current
		end)
	end)
	if ok then
		return dataStoreAdapter(), nil
	end
	return memoryAdapter(), tostring(err)
end

return StoreAdapter
