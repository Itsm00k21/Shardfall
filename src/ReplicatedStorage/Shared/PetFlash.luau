--!strict

--[[
	Glass Kestrel flashes on a dodge. Pure.

	should(keyName, effect) is true only when the key is LeftShift,
	RightShift, or ButtonY and the equipped effect is "flash". Q does
	not flash. ButtonX is heavy, so it does not flash. "collect",
	"ping", nil, and any other effect do not flash.

	chip(control, effect) is true only when the control is the on-screen
	"Dodge" button and the equipped effect is "flash". A key name is not
	a chip. LeftShift, RightShift, Q, ButtonX, and Interact do not chip.
	The Shift path stays on should.

	RightShift is named in this module. LeftShift matches
	Keybinds.COMBAT.dodge. This file does not require Keybinds.

	bump(generation) returns the next token. A finite number returns
	that number plus 1. nil, a string, a boolean, NaN, and infinity
	return 1. This module does not keep the last token. PetAura.start
	keeps the counter.

	holds(generation, token) is true only when both are finite numbers
	and they are equal. A newer bump means the older token does not
	hold. nil, a string, a boolean, NaN, and infinity do not hold.

	paid, a product id, Robux, cost, and skip do not flash, and they
	do not block a dodge key or the on-screen chip. They do not change
	the token and they do not change a hold. Pass them as an extra
	argument. Each call
	reads its arguments and does not write them. No clock. No RNG.
	No services. Nothing here costs Robux.
]]

local PetFlash = {}

local LEFT_DODGE = "LeftShift"
local RIGHT_DODGE = "RightShift"
local PAD_DODGE = "ButtonY"
local CHIP = "Dodge"
local FLASH = "flash"

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function PetFlash.should(keyName: any, effect: any, _extra: any?): boolean
	local dodge = keyName == LEFT_DODGE or keyName == RIGHT_DODGE or keyName == PAD_DODGE
	if not dodge then
		return false
	end
	return effect == FLASH
end

function PetFlash.chip(control: any, effect: any, _extra: any?): boolean
	if control ~= CHIP then
		return false
	end
	return effect == FLASH
end

function PetFlash.bump(generation: any, _extra: any?): number
	local current = finite(generation)
	if current == nil then
		return 1
	end
	return current + 1
end

function PetFlash.holds(generation: any, token: any, _extra: any?): boolean
	local live = finite(generation)
	local remembered = finite(token)
	if live == nil or remembered == nil then
		return false
	end
	return live == remembered
end

return PetFlash
