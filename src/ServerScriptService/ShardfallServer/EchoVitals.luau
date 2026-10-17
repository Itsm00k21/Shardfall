--!strict

--[[
	Accept a Story Echo scale result.

	CombatService asks the raid for the scaled heal or max HP. A missing
	or unusable result keeps the unbuffed number. Max HP stays at least 1.
	The HP bar only displays the number publish already sends.
]]

local EchoVitals = {}

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	if value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function EchoVitals.maxHp(base: any, scaled: any): number
	local safeBase = finite(base)
	local safeScaled = finite(scaled)
	local chosen = if safeScaled ~= nil then safeScaled else safeBase
	if chosen == nil or chosen < 1 then
		if safeBase ~= nil and safeBase >= 1 then
			return math.floor(safeBase)
		end
		return 1
	end
	return math.floor(chosen)
end

function EchoVitals.heal(base: any, scaled: any): number
	local safeScaled = finite(scaled)
	if safeScaled == nil then
		local safeBase = finite(base)
		if safeBase == nil or safeBase <= 0 then
			return 0
		end
		return safeBase
	end
	if safeScaled <= 0 then
		return 0
	end
	return safeScaled
end

return EchoVitals
