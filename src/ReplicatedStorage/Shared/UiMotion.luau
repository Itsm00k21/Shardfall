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

-- [Ghost] Clip 7 (Kevin: "it's not smooth"): the hub opens with a
-- scale and fade of 0.18 s (Quart Out) and closes in MOTION.panel (0.15 s)
-- before it hides. Both are 0 under reduced flash.
UiMotion.HUB_OPEN = 0.18
UiMotion.HUB_OPEN_SCALE = 0.94
UiMotion.HUB_CLOSE_SCALE = 0.96

function UiMotion.hubOpen(reduced: boolean): number
	if reduced then
		return 0
	end
	return UiMotion.HUB_OPEN
end

function UiMotion.hubClose(reduced: boolean): number
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
