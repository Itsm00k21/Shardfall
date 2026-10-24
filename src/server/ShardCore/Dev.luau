--!strict

--[[
	Dev Tools grant for Essence. Adds to profile.gearEssence only.
	Items, equipped gear, gold, and core levels stay as they are.
	Not a product. The DebugService hook checks LaunchGate.shardCore.
]]

local Dev = {}

function Dev.grant(profile: any, config: any): (boolean, string)
	if type(profile) ~= "table" or type(config) ~= "table" then
		return false, "Profile is not loaded."
	end
	local amount = config.DEV_GRANT
	if type(amount) ~= "number" or amount ~= amount or amount < 1 or amount >= math.huge then
		amount = 100
	end
	amount = math.floor(amount)
	local current = 0
	if type(config.essenceOf) == "function" then
		current = config.essenceOf(profile)
	end
	if type(current) ~= "number" or current ~= current or current < 0 then
		current = 0
	end
	local cap = config.WALLET_CAP
	if type(cap) ~= "number" or cap < 1 then
		cap = 1000000000
	end
	if current >= cap then
		return false, "Essence is already at the cap."
	end
	local nextAmount = current + amount
	if nextAmount > cap then
		nextAmount = cap
	end
	profile.gearEssence = nextAmount
	return true, string.format("+%d Essence (now %d).", nextAmount - current, nextAmount)
end

return Dev
