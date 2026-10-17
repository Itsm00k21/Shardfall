--!strict

--[[
	Pixel size for a text-size slider.

	px(base, scale) is max(UiTheme.MIN_TEXT, floor(base * scale + 0.5)).
	The floor is 14. A usable scale is a finite number greater than 0.
	nil, a string, a boolean, NaN, infinity, 0, and a negative number
	are scale 1. A usable base is a finite number greater than 0.
	Anything else returns 14. The scale is not clamped.

	A third argument, including paid = true, does not change the size.
	Each call reads its arguments and does not write them. No clock.
	No RNG. No services. Nothing here costs Robux.
]]

local UiTheme = require("./UiTheme")

local TextFit = {}

local function usable(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if value <= 0 then
		return nil
	end
	return value
end

function TextFit.px(base: any, scale: any, _extra: any?): number
	local size = usable(base)
	if size == nil then
		return UiTheme.MIN_TEXT
	end
	local factor = usable(scale)
	if factor == nil then
		factor = 1
	end
	return math.max(UiTheme.MIN_TEXT, math.floor(size * factor + 0.5))
end

return TextFit
