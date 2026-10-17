--!strict

--[[
	Shared Story Echo boss clear.

	One echoFight covers every member, and each member has their own boss
	copy. Stacks reset only when every member still able to swing has
	cleared that room. A downed member is left out of the list, so they
	cannot stall the reset. Someone who left is left out the same way.
	A living member who jumped to another wing with tuneRaid is left out
	of the room they left. The jump writes no kill mark.

	DungeonService cannot load under lune. This module only answers the
	question. It does not grant loot, reset stacks, or touch players.
]]

local EchoBossClear = {}

export type Seat = {
	cleared: boolean,
	retrying: boolean,
}

-- True when this member has cleared `killedRoom`.
-- The live rig wins while they are still on that room, so a mark from
-- before a respawn does not count. A later room counts only with a mark
-- from that earlier kill. Jumping ahead with tuneRaid does not write one.
function EchoBossClear.seatCleared(
	killedRoom: number,
	roomIndex: number,
	bossDown: boolean,
	marked: boolean,
	retrying: boolean
): boolean
	if retrying == true then
		return false
	end
	if type(killedRoom) ~= "number" or killedRoom ~= killedRoom or killedRoom < 1 then
		return false
	end
	if type(roomIndex) ~= "number" or roomIndex ~= roomIndex then
		return false
	end
	if roomIndex < killedRoom then
		return false
	end
	if roomIndex == killedRoom then
		return bossDown == true
	end
	return marked == true
end

-- Every seat has cleared, and nobody is inside a wipe retry.
-- An empty list is not a clear: the killer is always a seat when the
-- call is real, and an empty list must not reset the party.
function EchoBossClear.ready(seats: { Seat }): boolean
	if #seats < 1 then
		return false
	end
	for _, seat in ipairs(seats) do
		if seat.retrying == true or seat.cleared ~= true then
			return false
		end
	end
	return true
end

-- True when this member must not take a seat for `killedRoom`.
-- `seatCleared` stays false for an unmarked jump. That answer is "not a
-- clear". This answer is "do not hold the reset". A mark still seats
-- them. A jump onto the room being checked still seats them.
function EchoBossClear.leftWing(
	killedRoom: number,
	roomIndex: number,
	marked: boolean,
	jumped: boolean
): boolean
	if jumped ~= true or marked == true then
		return false
	end
	if type(killedRoom) ~= "number" or killedRoom ~= killedRoom or killedRoom < 1 then
		return false
	end
	if type(roomIndex) ~= "number" or roomIndex ~= roomIndex then
		return false
	end
	return roomIndex ~= killedRoom
end

-- HP after a max shrink. `before` is the HP from before the refresh.
-- A standing player who would land on 0 stays at 1. Someone already at
-- 0 stays down so a held member is not stood back up here.
function EchoBossClear.floorHp(before: number, after: number): number
	if type(before) ~= "number" or before ~= before or before <= 0 then
		return after
	end
	if type(after) ~= "number" or after ~= after or after <= 0 then
		return 1
	end
	return after
end

return EchoBossClear
