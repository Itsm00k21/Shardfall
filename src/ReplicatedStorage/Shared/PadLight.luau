--!strict

--[[
	Gamepad light attack while the menu is closed.

	fire(keyName, menuOpen) is true only for ButtonR1 when the menu is
	not open. ButtonX stays heavy. ButtonY stays dodge. The D-pad, LB,
	mouse, touch, and the keyboard heavy key are not this button.
	A third argument, including paid = true, does not fire and does not
	block a real press.

	Each call reads its arguments and does not write them. No clock.
	No RNG. No services. Nothing here costs Robux.
]]

local PadLight = {}

PadLight.KEY = "ButtonR1"

function PadLight.fire(keyName: any, menuOpen: any, _extra: any): boolean
	if menuOpen == true then
		return false
	end
	return keyName == PadLight.KEY
end

return PadLight
