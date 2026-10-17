--!strict

--[[
	When a premade join shares the host's Story Echo fight.

	RaidService cannot load under lune. A join backfills only when a
	different player is already in a matching Heartwood pull. Otherwise
	the joiner queues alone. Practice Grove never shares. Profile
	raidEcho is not an input.
]]

local EchoParty = {}

function EchoParty.samePull(
	hostDifficulty: any,
	hostPractice: boolean,
	listingDifficulty: any
): boolean
	if hostPractice == true then
		return false
	end
	if type(hostDifficulty) ~= "string" or hostDifficulty == "" then
		return false
	end
	if type(listingDifficulty) ~= "string" then
		return false
	end
	return hostDifficulty == listingDifficulty
end

-- "backfill" shares the host fight. "queue" starts a separate run.
function EchoParty.route(
	otherHost: boolean,
	hostInFight: boolean,
	samePull: boolean
): "backfill" | "queue"
	if otherHost == true and hostInFight == true and samePull == true then
		return "backfill"
	end
	return "queue"
end

return EchoParty
