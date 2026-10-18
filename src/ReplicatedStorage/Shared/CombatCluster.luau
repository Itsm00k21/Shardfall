--!strict

--[[
	Round combat cluster at the bottom-right of the screen.

	Attack is the large button. Dodge and jump are smaller. Heavy is a
	smaller phone button and stays hidden on desktop through HeavyChip.

	A third argument, including paid = true, does not move a rect.
	A short landscape phone is still a phone: height under 500 uses the
	2x4 bar, same as a narrow portrait. The fourth argument forces that
	bar when the device is touch even if the window is wide.
	Nothing here costs Robux.
]]

local ActionSlots = require("./ActionSlots")

local CombatCluster = {}

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
}

local function axis(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	if value < 200 or value > 10000 then
		return fallback
	end
	return math.floor(value)
end

local function overlaps(rect: Rect, bar: ActionSlots.Place): boolean
	return ActionSlots.overlaps(rect, { x = bar.x, y = bar.y, w = bar.w, h = bar.h })
end

function CombatCluster.place(
	width: any,
	height: any,
	_extra: any?,
	phone: boolean?
): { attack: Rect, dodge: Rect, jump: Rect, heavy: Rect }
	local w = axis(width, 1280)
	local h = axis(height, 720)
	local margin = 16
	local gap = 8
	local attackSize = if w < 700 then 64 else 72
	local small = if w < 700 then 44 else 48
	-- Width under 700 is portrait. Height under 500 is a landscape phone.
	-- Touch on a wider window passes phone = true from the action bar.
	local mobile = phone == true or w < 700 or h < 500
	local bar = ActionSlots.placement(w, h, mobile)
	local attack: Rect = {
		x = w - margin - attackSize,
		y = h - margin - attackSize,
		w = attackSize,
		h = attackSize,
	}
	if overlaps(attack, bar) then
		attack.y = bar.y + bar.h + gap
		if attack.y + attack.h > h - margin then
			attack.y = math.max(margin, h - margin - attack.h)
		end
		if overlaps(attack, bar) then
			attack.x = math.max(margin, bar.x - gap - attack.w)
		end
	end
	local dodge: Rect = {
		x = attack.x - gap - small,
		y = attack.y + attack.h - small,
		w = small,
		h = small,
	}
	if dodge.x < margin then
		dodge.x = margin
	end
	if overlaps(dodge, bar) then
		dodge.y = math.max(margin, attack.y - gap - small)
	end
	local jump: Rect = {
		x = attack.x + attack.w - small,
		y = attack.y - gap - small,
		w = small,
		h = small,
	}
	if jump.y < margin then
		jump.y = margin
	end
	if overlaps(jump, bar) then
		jump.x = math.max(margin, dodge.x - gap - small)
		jump.y = dodge.y
	end
	local heavy: Rect = {
		x = dodge.x,
		y = dodge.y - gap - small,
		w = small,
		h = small,
	}
	if heavy.y < margin or overlaps(heavy, bar) then
		heavy.x = math.max(margin, jump.x - gap - small)
		heavy.y = jump.y
	end
	return {
		attack = attack,
		dodge = dodge,
		jump = jump,
		heavy = heavy,
	}
end

return CombatCluster
