--!strict

--[[
	Who may use the dev tools (Debug, DevGrant, Dungeon "skip").

	Kevin's call, Oct 22 2026: dev tools stay, but only for Kevin. Team
	Test runs in Studio, so a Studio check alone let every tester grant
	themselves tokens and luck.

	A caller passes only when all of these hold:
	  * the server (or client) is running in Studio, and
	  * the user id is in OWNER_IDS, or
	  * the place is owned by a user (not a group) and the caller is that
	    user (game.CreatorId), or
	  * the place is unpublished (CreatorId 0). An unpublished place cannot
	    host a Team Test, so only the local Studio session can be in it.

	The servers check this in DebugService.run, RollService.devGrant and
	DungeonService.skipToBoss. The client only hides the rows.

	Pure apart from DevAccess.player, which reads game and RunService at
	call time so the rules load in Lune tests.
]]

local DevAccess = {}

-- TODO(Kevin): add your Roblox user id here (roblox.com/users/<id>/profile)
-- so dev tools also work if the place moves to a group. No id was found
-- in the repo on Oct 22 2026; until then the place creator check covers a
-- user-owned place.
DevAccess.OWNER_IDS = table.freeze({} :: { number })

DevAccess.DENIED = "Dev tools are for the game owner only."

local function isUserId(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value >= 1
		and math.floor(value) == value
end

function DevAccess.allowed(userId: any, isStudio: any, creatorId: any, creatorIsUser: any): boolean
	if isStudio ~= true then
		return false
	end
	if not isUserId(userId) then
		return false
	end
	for _, ownerId in ipairs(DevAccess.OWNER_IDS) do
		if ownerId == userId then
			return true
		end
	end
	if creatorId == 0 then
		return true
	end
	return creatorIsUser == true and isUserId(creatorId) and creatorId == userId
end

-- Live check for a Player. Reads game state at call time.
function DevAccess.player(player: any): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	local isStudio = game:GetService("RunService"):IsStudio()
	return DevAccess.allowed(
		player.UserId,
		isStudio,
		game.CreatorId,
		game.CreatorType == Enum.CreatorType.User
	)
end

return table.freeze(DevAccess)
