--!strict

--[[
	How long a panel, a tab, and a press take.

	UiTheme.MOTION.open stays 0.26. The panel open the menu uses is
	MOTION.panel (0.15). Reduced flash skips the tween and still allows
	the sound.
]]

local UiTheme = require("./UiTheme")

local UiMotion = {}

function UiMotion.reduced(settings: any): boolean
	if type(settings) ~= "table" or type(settings.camera) ~= "table" then
		return false
	end
	return settings.camera.flash == "reduced"
end

function UiMotion.panel(reduced: boolean): number
	if reduced then
		return 0
	end
	return UiTheme.MOTION.panel
end

function UiMotion.press(reduced: boolean): number
	if reduced then
		return 0
	end
	return UiTheme.MOTION.pop
end

return UiMotion
