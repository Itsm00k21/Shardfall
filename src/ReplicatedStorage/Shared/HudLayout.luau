--!strict

--[[
	Rects for the always-on shell. Coordinates are inside the safe GUI,
	so CoreUISafeInsets are already applied by the ScreenGui.
]]

local HudLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function HudLayout.portrait(margin: number): Rect
	return rect(margin, margin, 56, 56)
end

function HudLayout.health(margin: number): Rect
	local portrait = HudLayout.portrait(margin)
	return rect(portrait.x + portrait.w + 8, margin, 220, 56)
end

function HudLayout.pills(viewportX: number, margin: number): Rect
	local width = 196
	return rect(math.max(margin, viewportX - margin - width), margin + 36, width, 36)
end

function HudLayout.rail(viewportY: number, margin: number, count: number, button: number): Rect
	local gap = 8
	local height = count * button + math.max(0, count - 1) * gap
	local y = math.max(margin + 72, math.floor((viewportY - height) / 2))
	return rect(margin, y, button, height)
end

function HudLayout.toast(viewportX: number, margin: number): Rect
	local width = math.min(420, math.max(160, viewportX - 240))
	local x = math.floor((viewportX - width) / 2)
	return rect(x, margin + 64, width, 36)
end

-- Skills sit to the left and above the jump button. The jump rect is in
-- the same space as the HUD (subtract the ScreenGui AbsolutePosition).
function HudLayout.skills(
	viewportX: number,
	viewportY: number,
	jumpX: number,
	jumpY: number,
	jumpW: number,
	button: number
): { Rect }
	local gap = 8
	local clusterX = jumpX - button - gap
	if jumpW > 0 then
		clusterX = jumpX - button - gap
	end
	local clusterY = jumpY
	if clusterX < 8 then
		clusterX = math.max(8, viewportX - button * 2 - gap - 16)
		clusterY = math.max(8, viewportY - button * 3 - 24)
	end
	local slots = {}
	-- Two columns on the left of jump, then a row above it.
	table.insert(slots, rect(clusterX, clusterY, button, button))
	table.insert(slots, rect(clusterX, clusterY - button - gap, button, button))
	table.insert(slots, rect(clusterX - button - gap, clusterY, button, button))
	table.insert(slots, rect(clusterX - button - gap, clusterY - button - gap, button, button))
	table.insert(slots, rect(clusterX, clusterY - (button + gap) * 2, button, button))
	return slots
end

function HudLayout.hub(viewportX: number, viewportY: number, margin: number): Rect
	local w = math.floor(math.clamp(viewportX * 0.72, 280, 860))
	local h = math.floor(math.clamp(viewportY * 0.78, 220, 640))
	local x = math.floor((viewportX - w) / 2)
	local y = math.max(margin, math.floor((viewportY - h) / 2))
	if y + h > viewportY - margin then
		h = math.max(160, viewportY - margin - y)
	end
	return rect(x, y, w, h)
end

function HudLayout.bottomLeftEmpty(viewportX: number, viewportY: number): Rect
	return rect(0, viewportY - 96, math.floor(viewportX * 0.28), 96)
end

return HudLayout
