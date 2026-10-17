--!strict

--[[
	Glass Kestrel flashes on a dodge. Pure.

	should(keyName, effect) is true only when the key is LeftShift or
	RightShift and the equipped effect is "flash". Q does not flash.
	ButtonX does not flash. "collect", "ping", nil, and any other
	effect do not flash.

	RightShift is named in this module. LeftShift matches
	Keybinds.COMBAT.dodge. This file does not require Keybinds.

	paid, a product id, Robux, cost, and skip do not flash, and they
	do not block a dodge key. Pass them as a third argument. An extra
	argument does not change the answer. Each call reads its arguments
	and does not write them. No clock. No RNG. No services. Nothing
	here costs Robux.
]]

local PetFlash = {}

local LEFT_DODGE = "LeftShift"
local RIGHT_DODGE = "RightShift"
local FLASH = "flash"

function PetFlash.should(keyName: any, effect: any, _extra: any?): boolean
	local dodge = keyName == LEFT_DODGE or keyName == RIGHT_DODGE
	if not dodge then
		return false
	end
	return effect == FLASH
end

return PetFlash
