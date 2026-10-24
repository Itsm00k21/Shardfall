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
	forgeCraft = false,
	guilds = false,
	leaderboards = false,
	extraRealms = false,
	extraCurrencies = false,
	chests = false,
	paid = false,
	-- Phase 0.1 (roadmap salvage map PARK list). Off-plan for V1.
	classes = false, -- class picker, Change class, SetClass/PickTalent
	travel = false, -- Quick Travel portal prompt, Travel panel, Travel remote
	grove = false, -- Training Grove dummy and its loop
	codex = false, -- codex pages and nameplate titles
	wildCapture = false, -- wild capture prompt
	stars = false, -- duplicate merge (Feed duplicate, FeedItem)
	goldShop = false, -- gold shop (BuyGoldShop)
	events = false, -- top event banner
	traits = false, -- weapon/armor/pet traits on new rolls
	doors = false, -- old Rootvault room doors
	mireoak = false, -- Mireoak boss waves (Gnarl takes those waves)
	waveArena = false, -- V1 wave arena (declared; read by the arena module later)
	rollMenuExtras = false, -- [Ghost] old roll-page Junk/Below row, second Streak/Rolls lines, plain "Odds" rows
	loadingTips = false, -- join/teleport tips overlay (LoadingHud); a branded loading screen is Phase S
	petCare = false, -- pet/feed a companion for free XP (PetCare). Parked for a future pets update (Oct 22)
	equip = false, -- Phase 2 equip remotes (EquipSlot / UnequipSlot / GetEquip)
	gearLevels = false, -- auto-feed an exact duplicate into stars (off until Kevin decides)
	upgradeScale = false, -- gold forge upgrades multiply stats at read time
	shardCore = false, -- Shard Core feeder (GetShardCore / FeedShardCore). Spends gearEssence.
	gearSalvage = false, -- salvage gear into Essence (Stage B). Off until Kevin flips it.
	oneInventory = false, -- [Ghost] Bag rail button and B key open the full Inventory; the small Bag is retired.
	extraTiers = false, -- Mythic/Secret rolling (Phase 5). Owned items of those tiers still load and show
	luckMilestone = false, -- every-10th-roll x2 luck boost and its "x2 Luck in N" meter. Parked Oct 22; shardRolls still counts
}

-- World prompt action to the switch that keeps it from being built.
local PARKED_PROMPT: { [string]: string } = {
	travel = "travel",
	grove = "grove",
	market = "market",
	craft = "forgeCraft",
	heartwood = "raids",
	practice = "raids",
}

-- Dungeon id to the switch that keeps the Dungeon remote from entering it.
-- The Haven prompt and RaidService already check raids; this closes the
-- direct Dungeon("enter", "heartwood") call.
local PARKED_DUNGEON: { [string]: string } = {
	heartwood = "raids",
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

-- A dungeon id the Dungeon remote may enter. Unknown ids pass here and
-- DungeonService.enter refuses them.
function LaunchGate.dungeonOpen(id: any): boolean
	if type(id) ~= "string" then
		return true
	end
	local flag = PARKED_DUNGEON[id]
	if flag == nil then
		return true
	end
	return LaunchGate.on(flag)
end

-- A Haven prompt is only built when its switch is on.
function LaunchGate.promptOpen(action: string): boolean
	local flag = PARKED_PROMPT[action]
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
