--!strict

--[[
	Launch scope. PARKED systems stay in the tree. Their switches are off,
	so the hub, the rail, and the server remotes do not open them.
	Gold and Shards stay. Nothing here spends Robux.
]]

local LaunchGate = {}

LaunchGate.SHOW = {
	raids = false,
	trading = false,
	market = false,
	pass = false,
	petEvolution = false,
	bossPets = false,
	relicSets = false,
	forgeReroll = false,
	forgeSalvage = false,
	guilds = false,
	leaderboards = false,
	extraRealms = false,
	extraCurrencies = false,
}

local PARKED_TAB = {
	raids = "raids",
	market = "market",
	pass = "pass",
}

function LaunchGate.on(id: string): boolean
	return LaunchGate.SHOW[id] == true
end

-- Hero, bag, pets, roll, shop, and settings stay. A parked tab opens
-- only when its switch is on.
function LaunchGate.tabOpen(id: string): boolean
	local flag = PARKED_TAB[id]
	if flag == nil then
		return true
	end
	return LaunchGate.on(flag)
end

function LaunchGate.visibleTabs(tabs: { string }): { string }
	local kept = {}
	for _, id in ipairs(tabs) do
		if LaunchGate.tabOpen(id) then
			table.insert(kept, id)
		end
	end
	return kept
end

return LaunchGate
