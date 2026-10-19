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
	-- Hotbar skill art by role (batch 7).
	SkillAttack = "rbxassetid://92863817891102",
	SkillHeavy = "rbxassetid://124061473120636",
	SkillDodge = "rbxassetid://109683826876277",
	SkillSpell = "rbxassetid://70429026066280",
	SkillUlt = "rbxassetid://105106458529178",
	-- Action bar frames (purple hex style).
	HexSlot = "rbxassetid://113386067760930",
	HexSlotGlow = "rbxassetid://138707130263385",
	HexButton = "rbxassetid://120968264740024",
	EventBanner = "rbxassetid://92031233226706",
	-- Hub tabs parked behind launch flags, and their empty states (batch 7).
	TabRaids = "rbxassetid://91914133075036",
	TabMarket = "rbxassetid://92350744248602",
	TabPass = "rbxassetid://82029671467441",
	-- Class crests for the class picker and Hero class card (batch 8).
	ClassWarden = "rbxassetid://84480573554280",
	ClassTidecaller = "rbxassetid://71642045376579",
	ClassForgeborn = "rbxassetid://109739537920971",
	ClassFrostblade = "rbxassetid://121545835326350",
	ClassVoidcaster = "rbxassetid://109064272249374",
}

return table.freeze(IconAssets)
