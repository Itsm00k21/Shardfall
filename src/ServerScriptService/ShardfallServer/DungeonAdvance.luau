--!strict

--[[
	One room or wave per clear.

	DungeonService cannot load under lune (it asks for game services), so
	the advance latch lives here. begin() returns before it changes the
	run when the run is resolving, the room is not cleared, or this is
	already the last room. A rejected advance leaves the run untouched.
	A room or wave that can advance drops cleared, advanceAt, and the
	door offer before RequestStreamAroundAsync. A second advance in the
	same frame sees a room that is no longer cleared, so it cannot skip
	ahead or pay the clear again.

	After the stream, live() is false when this run is no longer the
	player's run or it is already ending. The caller must not spawn.
	chooseDoor uses the same check so a door during Leave cannot pay.
]]

local DungeonAdvance = {}

local function begin(run: any): string
	if run.resolving == true then
		return "absent"
	end
	if run.cleared ~= true then
		return "uncleared"
	end
	local dungeon = run.dungeon
	-- Last room cannot advance. Returning here leaves cleared, the
	-- countdown, and the door offer exactly as they were.
	if dungeon.endless ~= true and run.roomIndex >= #dungeon.rooms then
		return "last"
	end
	run.cleared = false
	run.advanceAt = nil
	run.offer = nil
	if dungeon.endless == true then
		run.wave += 1
		return "wave"
	end
	run.roomIndex += 1
	run.placeIndex = run.roomIndex
	return "room"
end

-- True only when `run` is still the run `current` points at and it is
-- not already leaving or finishing.
function DungeonAdvance.live(current: any, run: any): boolean
	return current == run and run ~= nil and run.resolving ~= true
end

-- teleport and spawn are the service. teleport may yield. spawn runs
-- only when the same run is still live after that yield.
function DungeonAdvance.advance(
	run: any,
	current: () -> any,
	teleport: () -> (),
	spawn: (string) -> ()
): string
	if run == nil then
		return "absent"
	end
	local kind = begin(run)
	if kind == "absent" or kind == "uncleared" or kind == "last" then
		return kind
	end
	teleport()
	if not DungeonAdvance.live(current(), run) then
		return "bail"
	end
	spawn(kind)
	return "spawned"
end

return DungeonAdvance
