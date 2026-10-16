--!strict

--[[
	Shared chrome numbers. Clients turn the RGB rows into Color3.

	Padding is at least 8. Text over the world is at least 14. Buttons
	share one corner and one minimum tap size.
]]

local UiTheme = {}

UiTheme.PAD = 8
-- Past device safe insets. 8px still left the debug toggle's right edge flat
-- against the viewport, so the control sits further in.
UiTheme.EDGE = 16
UiTheme.MIN_TEXT = 14
UiTheme.CORNER = 10
UiTheme.TAP = 64
UiTheme.STROKE = 1

local rgbRows: { [string]: { number } } = {
	background = { 16, 14, 24 },
	panel = { 28, 24, 40 },
	text = { 244, 240, 252 },
	muted = { 198, 192, 214 },
	gold = { 255, 206, 96 },
	ink = { 24, 18, 12 },
	button = { 108, 78, 196 },
	buttonDim = { 54, 46, 78 },
	debug = { 72, 52, 36 },
	ok = { 120, 210, 150 },
}
UiTheme.RGB = rgbRows

function UiTheme.labelWidth(text: string): number
	return math.max(UiTheme.TAP, #text * 8 + 20)
end

function UiTheme.safeMargin(): number
	return math.max(8, UiTheme.EDGE)
end

-- Dark rarity colors (Mythic red) disappear on the dark odds panel.
-- Lift until the relative luminance can be read on that background.
local function luminance(red: number, green: number, blue: number): number
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue
end

function UiTheme.lift(red: number, green: number, blue: number): (number, number, number)
	local rf = red / 255
	local gf = green / 255
	local bf = blue / 255
	local luma = luminance(rf, gf, bf)
	if luma >= 0.62 then
		return red, green, blue
	end
	-- Aim above the floor so byte rounding still clears it.
	local toward = (0.7 - luma) / math.max(1 - luma, 0.01)
	local function channel(value: number): number
		local mixed = value + (1 - value) * toward
		return math.floor(math.clamp(mixed, 0, 1) * 255 + 0.5)
	end
	return channel(rf), channel(gf), channel(bf)
end

return UiTheme
