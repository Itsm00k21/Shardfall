--!strict

--[[
	ScreenGuis the current client creates.

	Startup destroys any existing copy before building again. A Rojo reload
	leaves ResetOnSpawn guis in PlayerGui, and a leftover LocalScript can
	still be drawing the previous panel (the one that said Pity 0/80).
]]

local ClientChrome = {}

local OWNED: { [string]: boolean } = {
	Shardfall = true,
	ShardfallActions = true,
	ShardfallBanner = true,
	ShardfallCapture = true,
	ShardfallClasses = true,
	ShardfallCombat = true,
	ShardfallDebug = true,
	ShardfallDoors = true,
	ShardfallInventory = true,
	ShardfallLoops = true,
	ShardfallMarket = true,
	ShardfallMenu = true,
	ShardfallOnboard = true,
	ShardfallPets = true,
	ShardfallRaids = true,
	ShardfallRoll = true,
	ShardfallTouch = true,
	ShardfallTravel = true,
	ShardfallHud = true,
	ShardfallHub = true,
}

function ClientChrome.shouldClear(name: string): boolean
	return OWNED[name] == true
end

-- Join draws the shell only. Combat still exists for the overhead bar and
-- hit flash, with its old corner frames hidden. The hub stays closed.
function ClientChrome.visibleAtJoin(name: string): boolean
	return name == "ShardfallHud"
end

-- Hub tabs. The letter is the PC hotkey. Settings is the gear, not a letter.
ClientChrome.TABS = {
	{ id = "hero", label = "Hero", key = "C" },
	{ id = "bag", label = "Bag", key = "B" },
	{ id = "pets", label = "Pets", key = "P" },
	{ id = "roll", label = "Roll", key = "R" },
	{ id = "raids", label = "Raids", key = "I" },
	{ id = "market", label = "Market", key = "M" },
	{ id = "pass", label = "Shard Pass", key = "" },
	{ id = "settings", label = "Settings", key = "" },
}

-- The current roll line is "Pity 0 / 50 toward Legendary". 0/80 is a leftover.
function ClientChrome.legacyReadout(text: string): boolean
	if string.find(text, "Pity 0/80", 1, true) ~= nil then
		return true
	end
	if string.find(text, "Pity 0 / 80", 1, true) ~= nil then
		return true
	end
	return false
end

return ClientChrome
