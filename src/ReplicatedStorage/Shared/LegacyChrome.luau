--!strict

--[[
	ScreenGuis that may live in PlayerGui.

	This repo creates only the Shardfall* guis in ClientChrome. A Mac
	playtest at d16001b still showed a drop-rate panel, stacked Craft /
	Tools 2 / Auto Attack / Enter Bossrush buttons, a stat-point box, a
	Pass panel, and an "Abil..." hover. Those labels are not in this repo.
	They are baked into the place file's StarterGui (Rojo keeps unknown
	instances). The join sweep destroys any PlayerGui ScreenGui that is
	not ours and not a Roblox control.

	Kevin deletes these from the place if a copy is also sitting in
	StarterGui and a script inside it respawns the gui after the sweep:
	  Gold x0.00, Tools 2, Stat points, Stardust's Grace, Luck Aura,
	  Auto Parry, and the Abil hover.
]]

local ClientChrome = require("./ClientChrome")

local LegacyChrome = {}

local ROBLOX: { [string]: boolean } = {
	TouchGui = true,
	BubbleChat = true,
	Chat = true,
	Freecam = true,
	ExperienceChat = true,
	Captions = true,
	PlayerList = true,
}

-- Labels a repo-wide search does not create. Listed so the place can be cleaned.
LegacyChrome.ABSENT = {
	"Gold x0.00",
	"Tools 2",
	"Stat points",
	"Stardust's Grace",
	"Luck Aura",
	"Auto Parry",
}

function LegacyChrome.allowed(name: string): boolean
	if ROBLOX[name] == true then
		return true
	end
	return ClientChrome.shouldClear(name)
end

-- A PlayerGui ScreenGui that has a twin in StarterGui is a place-file copy.
-- This client never parents a gui to StarterGui (Rojo does not map it), so
-- even an owned name there is legacy. Roblox controls stay.
function LegacyChrome.isPlaceCopy(name: string, inStarterGui: boolean): boolean
	return inStarterGui and ROBLOX[name] ~= true
end

function LegacyChrome.shouldDestroy(name: string): boolean
	return not LegacyChrome.allowed(name)
end

return LegacyChrome
