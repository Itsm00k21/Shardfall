--!strict

--[[
	Roll-tab auto and window focus.

	keep(focused, autoOn) is the auto flag after a focus event. An
	unfocused window forces it off. A focused window leaves the flag as
	the caller passed it, so focusing the window does not turn auto
	back on.

	chain(focused) is the gate in front of RollLoop.canChain. It is
	false while the window is unfocused. The rarity stop, the queued
	second press, and the alive check stay in canChain.

	A third argument, including paid = true, does not change either
	result. Each call reads its arguments and does not write them.
	No clock. No RNG. No services. Nothing here costs Robux.
]]

local RollFocus = {}

function RollFocus.keep(focused: any, autoOn: any, _extra: any): boolean
	if focused ~= true then
		return false
	end
	return autoOn == true
end

function RollFocus.chain(focused: any, _extra: any): boolean
	return focused == true
end

return RollFocus
