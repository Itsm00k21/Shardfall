--!strict

--[[
	In-memory stand-in for a DataStore.

	updateAsync matches DataStoreService: return nil from the transform to
	leave the key unchanged. DataService uses this when the place is
	unpublished or Studio API access is off. The tests use the same object
	so a roll in that mode is exercised without Roblox.
]]

local MemoryStore = {}

export type Store = {
	persistent: boolean,
	updateAsync: (self: Store, key: string, transform: (any) -> any) -> any,
}

function MemoryStore.new(): Store
	local stored: { [string]: any } = {}
	local store = {} :: Store
	function store:updateAsync(key: string, transform: (any) -> any)
		local current = stored[key]
		local updated = transform(current)
		if updated == nil then
			return current
		end
		stored[key] = updated
		return updated
	end
	store.persistent = false
	return store
end

return MemoryStore
