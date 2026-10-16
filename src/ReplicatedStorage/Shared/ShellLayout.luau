--!strict

--[[
	Desktop vs phone layout, and the sizes that keep panels on screen.

	A keyboard means desktop, even when the window is short or a trackpad
	also reports touch. Phone layout is touch with no keyboard. Panels are
	sized to the viewport. UIScale stays at 1 or above so a 44px target
	does not shrink on a short window.
]]

local ShellLayout = {}

-- Zone names are stud-sized, so they shrink with distance, and they drop
-- off before the next island's label stacks on top of them. 70 studs is
-- inside one island, short of the bridge to the next one.
ShellLayout.ZONE_MAX_DISTANCE = 70
ShellLayout.ZONE_WIDTH_STUDS = 12
ShellLayout.ZONE_HEIGHT_STUDS = 2.4

-- Title uses the whole header row. Hide sits on the row under it.
ShellLayout.TITLE_ROW = 36
ShellLayout.HIDE_ROW = 44

-- Gold status line. Long enough to read, short enough that a closed panel
-- does not leave the last hint on screen.
ShellLayout.BANNER_SECONDS = 3.5

export type Box = {
	w: number,
	h: number,
}

function ShellLayout.mobile(touchEnabled: boolean, keyboardEnabled: boolean): boolean
	return touchEnabled == true and keyboardEnabled ~= true
end

function ShellLayout.inventory(viewportX: number, viewportY: number, mobile: boolean): Box
	local margin = if mobile then 8 else 16
	local maxW = math.max(0, viewportX - margin * 2)
	local maxH = math.max(0, viewportY - margin * 2)
	local w = math.min(if mobile then maxW else 960, maxW)
	local h = math.min(if mobile then maxH else 680, maxH)
	return { w = w, h = h }
end

function ShellLayout.sidePanel(viewportX: number, viewportY: number): Box
	local margin = 12
	local thumb = 68
	local maxW = math.max(0, viewportX - margin * 2)
	local maxH = math.max(0, viewportY - margin - thumb)
	local w = math.min(360, math.floor(viewportX * 0.36))
	if w > maxW then
		w = maxW
	end
	local h = maxH
	if h > viewportY - margin * 2 then
		h = math.max(0, viewportY - margin * 2)
	end
	return { w = w, h = h }
end

function ShellLayout.thumbSize(viewportX: number): Box
	local gaps = 8 * 5 + 24
	local slot = math.floor((viewportX - gaps) / 7)
	local w = math.clamp(slot, 72, 96)
	return { w = w, h = 56 }
end

ShellLayout.THUMBS = {
	{ id = "Menu", label = "Menu" },
	{ id = "Inventory", label = "Items" },
	{ id = "Travel", label = "Travel" },
	{ id = "Graphics", label = "Med" },
	{ id = "AutoFarm", label = "Farm" },
	{ id = "Tonic", label = "Tonic" },
	{ id = "Attack", label = "Attack" },
}

function ShellLayout.labelFits(label: string, width: number): boolean
	return #label * 8 + 10 <= width
end

function ShellLayout.zoneVisible(distance: number): boolean
	if type(distance) ~= "number" or distance ~= distance then
		return false
	end
	return distance >= 0 and distance <= ShellLayout.ZONE_MAX_DISTANCE
end

-- 1 beside the camera, about a third of that at the cutoff, 0 past it.
function ShellLayout.zoneScale(distance: number): number
	if not ShellLayout.zoneVisible(distance) then
		return 0
	end
	local span = ShellLayout.ZONE_MAX_DISTANCE
	if span <= 0 then
		return 1
	end
	local along = math.clamp(distance / span, 0, 1)
	return 1 - along * 0.65
end

return ShellLayout
