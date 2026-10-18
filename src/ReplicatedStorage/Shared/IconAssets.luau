--!strict
--[[
	Painted rail icons, uploaded through the Studio MCP on 2026-10-18.
	Keyed by the rail entry id in HudShell. A missing entry falls back to
	the UiIcons glyph, so the rail never shows a blank button.
]]

local IconAssets: { [string]: string } = {
	Hero = "rbxassetid://88727631345595",
	Bag = "rbxassetid://108229364185654",
	Pets = "rbxassetid://112313878839272",
	Roll = "rbxassetid://87702529872973",
	Shop = "rbxassetid://133793955425261",
	Settings = "rbxassetid://71449180287649",
}

return table.freeze(IconAssets)
