--!strict

--[[
	Checks the Gate Ring content table. A problem list is empty when the
	pad, the four slots, the caps, and the clocks match the spec.
	This does not build parts and does not read a save.
]]

local Validate = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function rgb(value: any, problems: { string }, where: string)
	if typeof(value) ~= "table" or #value ~= 3 then
		table.insert(problems, where .. " color")
		return
	end
	for index = 1, 3 do
		local channel = value[index]
		if not finite(channel) or channel < 0 or channel > 255 or math.floor(channel) ~= channel then
			table.insert(problems, where .. " color channel")
			return
		end
	end
end

local function length(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

function Validate.problems(config: any): { string }
	local problems = {}
	if typeof(config) ~= "table" then
		return { "config" }
	end
	local pad = config.pad
	local party = config.party
	local slots = config.slots
	local slot = config.slot
	local gate = config.gate
	if typeof(pad) ~= "table" or typeof(party) ~= "table" or typeof(slots) ~= "table" or typeof(slot) ~= "table" then
		table.insert(problems, "shape")
		return problems
	end
	if typeof(gate) ~= "table" or gate.id ~= "rootvault" then
		table.insert(problems, "gate")
	end
	if pad.x ~= -10 or pad.y ~= 120 or pad.z ~= 108 or pad.radius ~= 8 then
		table.insert(problems, "pad")
	end
	if not finite(pad.thickness) or pad.thickness <= 0 or pad.thickness > 2 then
		table.insert(problems, "thickness")
	end
	if not finite(pad.vertical) or pad.vertical < 6 or pad.vertical > 24 then
		table.insert(problems, "vertical")
	end
	rgb(pad.color, problems, "pad")
	if config.promptFreeRadius ~= 12 or pad.radius >= config.promptFreeRadius then
		table.insert(problems, "prompt radius")
	end
	if typeof(gate) == "table" and finite(gate.x) and finite(gate.z) and finite(pad.x) and finite(pad.z) and finite(pad.radius) then
		local dist = length(pad.x - gate.x, pad.z - gate.z)
		-- Near the mouth, and the disc does not cover the arch.
		if dist <= 0 or dist > 16 or dist < pad.radius + 2 then
			table.insert(problems, "near gate")
		end
	end
	if party.min ~= 1 or party.cap ~= 4 or party.countdown ~= 15 then
		table.insert(problems, "caps")
	end
	if
		party.lateJoinUnder ~= 5
		or party.lateJoinBump ~= 5
		or party.leaveGrace ~= 0.5
		or party.deadlineExtra ~= 10
	then
		table.insert(problems, "clock")
	end
	if party.startSweep ~= 0.4 or party.friendsOnlyDefault ~= false or party.hardLevel ~= 5 then
		table.insert(problems, "rules")
	end
	if party.hpPerExtra ~= 0.3 then
		table.insert(problems, "hp")
	end
	if slot.diameter ~= 4 or slot.height ~= 0.2 or slot.refuseSeconds ~= 0.6 then
		table.insert(problems, "disc")
	end
	rgb(slot.openColor, problems, "open")
	rgb(slot.memberColor, problems, "member")
	rgb(slot.leaderColor, problems, "leader")
	rgb(slot.refuseColor, problems, "refuse")
	rgb(slot.friendsColor, problems, "friends")
	if #slots ~= party.cap then
		table.insert(problems, "slot count")
		return problems
	end
	local expect = {
		{ -5, -4 },
		{ 5, -4 },
		{ -5, 4 },
		{ 5, 4 },
	}
	local seen: { [number]: boolean } = {}
	for index, row in ipairs(slots) do
		if typeof(row) ~= "table" or row.id ~= index or seen[row.id] then
			table.insert(problems, "slot id")
		else
			seen[row.id] = true
		end
		local want = expect[index]
		if want == nil or typeof(row) ~= "table" or row.x ~= want[1] or row.z ~= want[2] then
			table.insert(problems, "slot offset")
		elseif finite(pad.radius) then
			local dist = length(row.x, row.z)
			if dist >= pad.radius then
				table.insert(problems, "slot outside")
			end
		end
	end
	for left = 1, #slots do
		for right = left + 1, #slots do
			local a = slots[left]
			local b = slots[right]
			if typeof(a) == "table" and typeof(b) == "table" and finite(a.x) and finite(b.x) and finite(a.z) and finite(b.z) then
				local gap = length(a.x - b.x, a.z - b.z)
				if finite(slot.diameter) and gap < slot.diameter then
					table.insert(problems, "slot overlap")
				end
			end
		end
	end
	return problems
end

function Validate.ok(config: any): boolean
	return #Validate.problems(config) == 0
end

return Validate
