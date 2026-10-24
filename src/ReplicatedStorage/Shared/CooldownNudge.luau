--!strict

--[[
	Cooldown nudge (Kevin's Oct 19 clip): mashing a cooling skill stacked
	plain grey "On cooldown" boxes, and the ultimate printed "Ultimate is
	still filling." top centre. Those now show as one small purple-hex chip
	over the slot itself (the slot already runs its cooldown sweep), and a
	repeat inside DEBOUNCE only refreshes the same chip.
]]

local CooldownNudge = {}

CooldownNudge.DEBOUNCE = 0.6
CooldownNudge.SHOW_SECONDS = 0.9
CooldownNudge.WIDTH = 132
CooldownNudge.HEIGHT = 26
CooldownNudge.TEXT = table.freeze({
	cooldown = "Ready in %.1fs",
	cooldownBare = "On cooldown",
	charging = "Ultimate charging",
})

-- "cooldown", "charging", or nil when the message is a real error.
function CooldownNudge.kind(message: any): string?
	if type(message) ~= "string" then
		return nil
	end
	if message == "On cooldown" or string.find(message, "cooling", 1, true) ~= nil then
		return "cooldown"
	end
	if string.find(message, "still filling", 1, true) ~= nil or string.find(message, "Ultimate charging", 1, true) ~= nil then
		return "charging"
	end
	return nil
end

function CooldownNudge.text(kind: string, secondsLeft: number?): string
	if kind == "charging" then
		return CooldownNudge.TEXT.charging
	end
	if type(secondsLeft) == "number" and secondsLeft == secondsLeft and secondsLeft > 0.05 then
		return string.format(CooldownNudge.TEXT.cooldown, math.max(0.1, secondsLeft))
	end
	return CooldownNudge.TEXT.cooldownBare
end

-- One chip at a time: a new slot always shows; the same slot again inside
-- DEBOUNCE only refreshes text (no flash, no new popup).
function CooldownNudge.fresh(lastIndex: number?, lastAt: number?, index: number, now: number): boolean
	if lastIndex ~= index or type(lastAt) ~= "number" then
		return true
	end
	return now - lastAt >= CooldownNudge.DEBOUNCE
end

return table.freeze(CooldownNudge)
