--!strict
--[[
	Painted rail icons, uploaded through the Studio MCP on 2026-10-18.
	Keyed by the rail entry id in HudShell; the Hex* frames dress ActionBar. A missing entry falls back to
	the UiIcons glyph, so the rail never shows a blank button.
]]

local IconAssets: { [string]: string } = {
	Hero = "rbxassetid://88727631345595",
	Bag = "rbxassetid://108229364185654",
	Pets = "rbxassetid://112313878839272",
	Roll = "rbxassetid://87702529872973",
	Shop = "rbxassetid://133793955425261",
	Settings = "rbxassetid://71449180287649",
	Travel = "rbxassetid://127191414778578",
	Gold = "rbxassetid://114051544747464",
	Shards = "rbxassetid://132524313343787",
	-- Bag pill and item-card category art (crystal-glass style, 2026-10-18 batch 6).
	ItemWeapon = "rbxassetid://130645589830545",
	ItemArmor = "rbxassetid://95811175040993",
	ItemRelic = "rbxassetid://119274506194028",
	ItemAccessory = "rbxassetid://100999400794230",
	ItemConsumable = "rbxassetid://79399086531671",
	ItemMisc = "rbxassetid://96247818299080",
	-- Action bar frames (purple hex style).
	HexSlot = "rbxassetid://113386067760930",
	HexSlotGlow = "rbxassetid://138707130263385",
	HexButton = "rbxassetid://120968264740024",
	EventBanner = "rbxassetid://92031233226706",
}

return table.freeze(IconAssets)
