--!strict

--[[
	Wrapped height for a Pets-tab ability line.

	box(text, width, scale) uses TextFit.px(14, scale). A bad width is
	160. The returned width stays inside the given width. Height is at
	least that pixel size. lines times chars covers the text.

	A fourth argument, including paid = true, does not change the box.
	Each call reads its arguments and does not write them. No clock.
	No RNG. No services other than TextFit. Nothing here costs Robux.
]]

local TextFit = require("./TextFit")

local PetLine = {}

local BASE = 14
local CHAR = 0.62
local FALLBACK_W = 160

export type Box = {
	w: number,
	h: number,
	px: number,
	lines: number,
	chars: number,
}

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function PetLine.box(text: any, width: any, scale: any, _extra: any?): Box
	local px = TextFit.px(BASE, scale)
	local span = finite(width)
	if span == nil or span <= 0 then
		span = FALLBACK_W
	end
	local chars = math.max(1, math.floor(span / (px * CHAR)))
	local body = if type(text) == "string" then text else ""
	local lines = 1
	if #body > 0 then
		lines = math.max(1, math.ceil(#body / chars))
	end
	return {
		w = span,
		h = lines * px,
		px = px,
		lines = lines,
		chars = chars,
	}
end

return PetLine
