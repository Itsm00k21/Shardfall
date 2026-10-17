--!strict

--[[
	Every icon the HUD and the hub draw.

	These are Roblox built-in textures used as stand-ins. Replace any value
	in `asset` with a real image and the buttons pick it up. Tints keep two
	icons readable when they still share a placeholder image.
]]

local UiIcons = {}

UiIcons.asset = {
	hero = "rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png",
	bag = "rbxasset://textures/ui/Settings/MenuBarIcons/RecordTab.png",
	pets = "rbxasset://textures/ui/Settings/MenuBarIcons/LeaveTab.png",
	roll = "rbxasset://textures/ui/Settings/MenuBarIcons/SwitchTab.png",
	raids = "rbxasset://textures/ui/Settings/MenuBarIcons/LeaveTab.png",
	market = "rbxasset://textures/ui/InspectMenu/ico_favorite.png",
	pass = "rbxasset://textures/ui/TopBar/iconBase.png",
	settings = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png",
	attack = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png",
	dodge = "rbxasset://textures/ui/Settings/MenuBarIcons/SwitchTab.png",
	skill = "rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png",
	ult = "rbxasset://textures/ui/TopBar/iconBase.png",
	item = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	pet = "rbxasset://textures/ui/GuiImagePlaceholder.png",
	info = "rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png",
	class = "rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png",
	empty = "rbxasset://textures/ui/GuiImagePlaceholder.png",
}

-- ImageColor3 multipliers, 0-255. Kevin can ignore these once the art is final.
UiIcons.tint = {
	hero = { 255, 214, 140 },
	bag = { 186, 214, 255 },
	pets = { 160, 230, 170 },
	roll = { 220, 180, 255 },
	raids = { 255, 170, 140 },
	market = { 255, 214, 120 },
	pass = { 170, 210, 255 },
	settings = { 210, 206, 224 },
	attack = { 255, 196, 160 },
	dodge = { 160, 220, 255 },
	skill = { 190, 255, 190 },
	ult = { 255, 220, 120 },
	item = { 220, 214, 240 },
	pet = { 170, 230, 180 },
	info = { 200, 220, 255 },
	class = { 255, 214, 150 },
	empty = { 180, 174, 200 },
}

function UiIcons.get(name: string): string
	local id = UiIcons.asset[name]
	if type(id) == "string" and id ~= "" then
		return id
	end
	return UiIcons.asset.empty
end

function UiIcons.tintOf(name: string): (number, number, number)
	local row = UiIcons.tint[name]
	if row == nil then
		row = UiIcons.tint.empty
	end
	return row[1], row[2], row[3]
end

return UiIcons
