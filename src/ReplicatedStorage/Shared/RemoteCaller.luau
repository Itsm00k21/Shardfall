--!strict

--[[
	Who is allowed to invoke a Shardfall remote.

	Roblox Instances are not strings from type(). type(player) is "userdata".
	typeof(player) is "Instance". A check written with type() rejects every
	real player, the handler never runs, and nothing is printed. Callers must
	pass typeof(player), then IsA("Player").
]]

local RemoteCaller = {}

function RemoteCaller.accept(reportedType: string, isPlayer: boolean): (boolean, string)
	if reportedType == "Instance" and isPlayer then
		return true, ""
	end
	return false,
		string.format(
			'Request rejected: caller typeof is %q (isPlayer=%s). Player checks must use typeof, not type — type(player) is "userdata".',
			reportedType,
			tostring(isPlayer)
		)
end

return RemoteCaller
