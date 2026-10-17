--!strict

--[[
	Story Echo retry window.

	DungeonService cannot load under lune (it asks for game services), so
	the re-entry rule lives here. A hit while the guard is up does not
	wipe and does not start another retry. One down, one stack.

	The service still has to clear shots and despawn the old room before
	RequestStreamAroundAsync. beforeYield() is that order.
]]

local EchoRetry = {}

function EchoRetry.beforeYield(): { string }
	return { "guard", "clearShots", "despawn" }
end

function EchoRetry.blocked(retrying: boolean): boolean
	return retrying == true
end

-- "ignore" skips the wipe and the retry. "retry" is a Story wipe retry.
-- "down" is any other down (defeat, partial, practice).
function EchoRetry.decision(retrying: boolean, storyWipe: boolean): "ignore" | "retry" | "down"
	if retrying == true then
		return "ignore"
	end
	if storyWipe == true then
		return "retry"
	end
	return "down"
end

return EchoRetry
