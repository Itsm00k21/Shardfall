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
}

function ClientChrome.shouldClear(name: string): boolean
	return OWNED[name] == true
end

-- Join draws the combat HUD (HP and currency), the action bar, and the
-- Studio debug toggle. Every other owned gui stays hidden until a button.
function ClientChrome.visibleAtJoin(name: string): boolean
	return name == "ShardfallCombat" or name == "ShardfallActions" or name == "ShardfallDebug"
end

-- One menu. Each entry opens that sheet and closes the others.
ClientChrome.MENU = { "Codes", "Daily", "Pass", "Settings", "Roll", "Craft", "Bossrush" }

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
