--!strict

--[[
	Shared chrome numbers. Clients turn the RGB rows into Color3.

	Padding is at least 8. Text over the world is at least 14. Buttons
	share one corner and one minimum tap size.
]]

local UiTheme = {}

UiTheme.PAD = 8
-- Space between cards and rows. The three steps are 8, 12, and 16.
UiTheme.GAP = 12
-- Past device safe insets. 8px still left the debug toggle's right edge flat
-- against the viewport, so the control sits further in.
UiTheme.EDGE = 16
UiTheme.MIN_TEXT = 14
UiTheme.CORNER = 10
UiTheme.TAP = 64
UiTheme.TOUCH = 44
UiTheme.STROKE = 1
UiTheme.STROKE_BOLD = 2
UiTheme.HEADER = 48
UiTheme.ACCENT = 3
-- Drop shadow sits behind a panel. 0 is opaque, 1 is invisible.
UiTheme.SHADOW = 0.55
UiTheme.HEADER_FONT = "BuilderSansBold"
UiTheme.BODY_FONT = "BuilderSans"
UiTheme.BACKDROP = 0.5
UiTheme.MOTION = {
	open = 0.26,
	panel = 0.15,
	stagger = 0.1,
	pop = 0.12,
}

-- Five read-on-dark rarity colors. Mythic reuses the legendary color so
-- the palette stays at five; the tier name is still "Mythic".
UiTheme.RARITY = {
	Common = { 198, 196, 206 },
	Uncommon = { 96, 196, 120 },
	Rare = { 96, 168, 232 },
	Epic = { 186, 120, 232 },
	Legendary = { 255, 196, 72 },
}
UiTheme.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

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
	-- Layered chrome. Panels are a dark body plus a header, not one purple fill.
	header = { 42, 36, 58 },
	body = { 18, 16, 28 },
	shadow = { 0, 0, 0 },
	divider = { 78, 70, 102 },
	loss = { 220, 92, 96 },
	hover = { 64, 56, 92 },
	press = { 36, 30, 54 },
	accent = { 255, 206, 96 },
}
UiTheme.RGB = rgbRows

function UiTheme.labelWidth(text: string): number
	return math.max(UiTheme.TAP, #text * 8 + 20)
end

function UiTheme.safeMargin(): number
	return math.max(8, UiTheme.EDGE)
end

-- Positive is a gain, negative is a loss, zero is unchanged.
function UiTheme.compareTone(delta: number): string
	if type(delta) ~= "number" or delta ~= delta then
		return "same"
	end
	if delta > 0 then
		return "gain"
	end
	if delta < 0 then
		return "loss"
	end
	return "same"
end

function UiTheme.rarityColor(name: string): (number, number, number)
	local row = UiTheme.RARITY[name]
	if name == "Mythic" or row == nil then
		row = if name == "Mythic" then UiTheme.RARITY.Legendary else UiTheme.RARITY.Common
	end
	return row[1], row[2], row[3]
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
