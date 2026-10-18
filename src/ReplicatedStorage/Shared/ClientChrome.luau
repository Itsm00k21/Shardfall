--!strict

--[[
	ScreenGuis the current client creates.

	Startup destroys any existing copy before building again. A Rojo reload
	leaves ResetOnSpawn guis in PlayerGui, and a leftover LocalScript can
	still be drawing the previous panel (the one that said Pity 0/80).
]]

local Keybinds = require("./Keybinds")

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
	ShardfallLoading = true,
	ShardfallMarket = true,
	ShardfallMenu = true,
	ShardfallOnboard = true,
	ShardfallPets = true,
	ShardfallPrompt = true,
	ShardfallPetAura = true,
	ShardfallRaids = true,
	ShardfallRail = true,
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
	return name == "ShardfallHud" or name == "ShardfallActions"
end

-- Hub tabs. The letter is the PC hotkey. Settings is the gear, not a letter.
ClientChrome.TABS = {
	{ id = "hero", label = "Hero", key = Keybinds.MENU.hero },
	{ id = "bag", label = "Bag", key = Keybinds.MENU.bag },
	{ id = "pets", label = "Pets", key = Keybinds.MENU.pets },
	{ id = "roll", label = "Roll", key = Keybinds.MENU.roll },
	{ id = "raids", label = "Raids", key = Keybinds.MENU.raids },
	{ id = "market", label = "Market", key = Keybinds.MENU.market },
	{ id = "pass", label = "Shard Pass", key = "" },
	{ id = "settings", label = "Settings", key = "" },
}

-- The live pity line is "Epic n/100 · Legendary n/1000".
-- "Pity 0/80" and "Pity n/50 toward Legendary" are leftovers.
function ClientChrome.legacyReadout(text: string): boolean
	if string.find(text, "Pity 0/80", 1, true) ~= nil then
		return true
	end
	if string.find(text, "Pity 0 / 80", 1, true) ~= nil then
		return true
	end
	if string.find(text, "Pity 0/50", 1, true) ~= nil then
		return true
	end
	if string.find(text, "/ 50 toward Legendary", 1, true) ~= nil then
		return true
	end
	if string.find(text, "/50 toward Legendary", 1, true) ~= nil then
		return true
	end
	-- An older rail (Inv, Shop, Guilds) is not the hub. HudShell and
	-- MenuHub use Hero, Bag, Pets, Roll, Raids, and Market.
	if string.find(text, "Guilds", 1, true) ~= nil then
		return true
	end
	if string.find(text, "Inv ", 1, true) ~= nil and string.find(text, "Shop", 1, true) ~= nil then
		return true
	end
	return false
end

return ClientChrome
