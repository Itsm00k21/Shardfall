--!strict

--[[
	Roblox UI navigation. A mouse or touch click on a HUD button can leave
	it as GuiService.SelectedObject (orange outline). While a selection is
	held, Roblox routes WASD to UI navigation, so the character stops
	moving (Kevin's Oct 21 playtest). Only a gamepad should hold a
	selection. Mouse, touch and keyboard input clear it.
]]

local UiSelection = {}

function UiSelection.isGamepad(inputTypeName: any): boolean
	return type(inputTypeName) == "string" and string.match(inputTypeName, "^Gamepad[1-8]$") ~= nil
end

-- True when a held selection should be dropped for this last input type.
function UiSelection.shouldClear(inputTypeName: any, hasSelection: boolean): boolean
	if not hasSelection then
		return false
	end
	return not UiSelection.isGamepad(inputTypeName)
end

return UiSelection
