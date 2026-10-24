--!strict

--[[
	T4 Gate Ring, the party gather spot in front of Rootvault.

	Content only. LaunchGate.parties (default false) is the switch.
	With the switch off, nothing is built and the solo pad stays as it is.

	The pad centre is (-18, 100) on Haven.FLOOR_Y. That keeps the disc
	clear of the Rootvault pier and the mouth strip. The x=0 lane from
	spawn to the mouth keeps a margin of at least the pad radius plus 3.
	Four slots stand on that disc. Party state is memory only.
	schemaVersion stays 26. Nothing here is paid.
]]

local PartyGather = {}

-- Mouth this ring stands clear of. The pad is west of the arch, off the
-- x=0 walk from spawn (0, 30) to the mouth.
PartyGather.gate = table.freeze({
	id = "rootvault",
	x = 0,
	z = 108,
})

PartyGather.pad = table.freeze({
	x = -18,
	y = 120,
	z = 100,
	-- Whole disc is the touch zone. Diameter 16.
	radius = 8,
	thickness = 0.4,
	-- Standing HumanoidRootPart is a few studs above the floor. A body
	-- higher than this is not "on the pad".
	vertical = 12,
	color = table.freeze({ 96, 96, 104 }),
})

-- Offsets from the pad center. Slot 1 is the near-left disc (first joiner).
-- Centers land at (-23, 96), (-13, 96), (-23, 104), (-13, 104).
PartyGather.slots = table.freeze({
	table.freeze({ id = 1, x = -5, z = -4 }),
	table.freeze({ id = 2, x = 5, z = -4 }),
	table.freeze({ id = 3, x = -5, z = 4 }),
	table.freeze({ id = 4, x = 5, z = 4 }),
})

PartyGather.slot = table.freeze({
	diameter = 4,
	height = 0.2,
	refuseSeconds = 0.6,
	openColor = table.freeze({ 176, 168, 198 }),
	memberColor = table.freeze({ 120, 210, 255 }),
	leaderColor = table.freeze({ 255, 196, 64 }),
	refuseColor = table.freeze({ 230, 80, 96 }),
	friendsColor = table.freeze({ 54, 46, 78 }),
})

-- No ProximityPrompt is built inside this radius of the pad center.
PartyGather.promptFreeRadius = 12

-- Arch clearance. The lane is the spawn-to-mouth line (x = gate.x).
-- The centre stays at least pad.radius + laneExtra off that line.
-- Piers are the 2.5-stud pillars at local X ±5.25. The mouth strip is
-- the 8-wide, 0.6-deep glow centered on the gate. Bearing 0, so local
-- X is world X.
PartyGather.clearance = table.freeze({
	laneExtra = 3,
	pierHalf = 1.25,
	pierLocalX = table.freeze({ -5.25, 5.25 }),
	mouthHalfX = 4,
	mouthHalfZ = 0.3,
})

PartyGather.party = table.freeze({
	min = 1,
	cap = 4,
	countdown = 15,
	-- First join records a hard stop at countdown + deadlineExtra.
	-- Late bumps may move the clock toward that stop, not past it.
	deadlineExtra = 10,
	-- A join with less than lateJoinUnder seconds left bumps the clock
	-- to lateJoinBump. Once per joiner. The clock does not restart.
	lateJoinUnder = 5,
	lateJoinBump = 5,
	leaveGrace = 0.5,
	startSweep = 0.4,
	-- Provisional (Kevin Q2, still open): off, and only the leader's friends.
	friendsOnlyDefault = false,
	hardLevel = 5,
	-- M16 readout ×(1 + 0.3 × (n − 1)). Stored on the party. Not applied
	-- to enemy HP here (that switch is separate and is not this slice).
	hpPerExtra = 0.3,
})

return table.freeze(PartyGather)
