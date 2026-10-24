--!strict

--[[
	The first five minutes.

	A short cold open, then the world teaches one verb at a time. Skip drops
	the player in Haven with the same starter kit. Returning players never
	see it again.

	LaunchGate.firstSessionGuide selects the V1 guide steps (open, three
	rolls, the Gate, wave 1). Off, this module is the cold open it has
	always been. The starter kit does not change.
]]

local LaunchGate = require("./LaunchGate")
local SessionGuide = require("./SessionGuide")

local Onboarding = {}

Onboarding.STEPS = {
	{ id = "open", text = "The sky cracked. Shards fell on the wilds.", hint = "" },
	{
		id = "class",
		text = "Five pedestals. Pick the one that fits your hands.",
		hint = "Choose a class",
	},
	{ id = "swing", text = "Saplings break on the third hit.", hint = "Keep swinging" },
	{ id = "dodge", text = "A red mark means move.", hint = "Dodge" },
	{ id = "door", text = "Two doors. Look, then choose.", hint = "" },
	{ id = "haven", text = "Haven. The Forge remembers what you carry.", hint = "" },
}

-- The guide owns `open` and its own ids. A legacy step such as "class"
-- keeps the cold open even when the flag is on, so a save already past
-- the first card is not rewound.
local function guideOn(id: any): boolean
	if not LaunchGate.on("firstSessionGuide") then
		return false
	end
	if id == nil or id == "open" then
		return true
	end
	return SessionGuide.known(id)
end

local function rows(id: any)
	if guideOn(id) then
		return SessionGuide.steps()
	end
	return Onboarding.STEPS
end

-- [Ghost] Clip 7: steps that only make sense in the hub. Inside a
-- dungeon run their card and "Shardfall: Keep swinging" pill fold away
-- (there are no saplings in the Rootvault); dodge and the guide's wave
-- steps still show.
Onboarding.HUB_ONLY =
	table.freeze({ open = true, class = true, swing = true, door = true, haven = true })

function Onboarding.quietInRun(id: any): boolean
	return type(id) == "string" and Onboarding.HUB_ONLY[id] == true
end

function Onboarding.step(id: any)
	local list = rows(id)
	if type(id) ~= "string" then
		return list[1]
	end
	for _, row in ipairs(list) do
		if row.id == id then
			return row
		end
	end
	return list[1]
end

function Onboarding.next(id: string): string?
	local list = rows(id)
	for index, row in ipairs(list) do
		if row.id == id then
			local following = list[index + 1]
			if following == nil then
				return nil
			end
			return following.id
		end
	end
	return list[1].id
end

-- The starter kit is the same whether they finish or skip.
function Onboarding.starter(data: any)
	data.gold = (data.gold or 0) + 250
	data.shardKeys = (data.shardKeys or 0) + 40
	if type(data.chests) ~= "table" then
		data.chests = {}
	end
	if LaunchGate.on("chests") then
		data.chests.Rare = (data.chests.Rare or 0) + 1
		data.chests.Uncommon = (data.chests.Uncommon or 0) + 1
	end
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	data.consumables.healing_tonic = (data.consumables.healing_tonic or 0) + 3
	data.onboardDone = true
	data.onboardStep = "haven"
end

-- The goal lines under the card. profile is optional: when it already has
-- a class, "Choose a class" reads done whatever step the save is on.
-- On the cold open ("open") or an unknown step nothing is done yet.
function Onboarding.goals(
	stepId: string,
	profile: any?
): { { id: string, text: string, done: boolean } }
	local list = rows(stepId)
	local rowsOut = {}
	local known = false
	for _, row in ipairs(list) do
		if row.id == stepId then
			known = true
		end
	end
	local marking = known and stepId ~= list[1].id
	local hasClass = type(profile) == "table"
		and type(profile.classId) == "string"
		and profile.classId ~= ""
	for _, row in ipairs(list) do
		if row.id ~= "open" then
			local done = marking and row.id ~= stepId
			if row.id == stepId then
				marking = false
			end
			if row.id == "class" and hasClass then
				done = true
			end
			table.insert(rowsOut, {
				id = row.id,
				text = if row.hint ~= "" then row.hint else row.text,
				done = done,
			})
		end
	end
	return rowsOut
end

-- Short names for the collapsed intro pill ("Shardfall: Choose a class").
Onboarding.SHORT = table.freeze({
	open = "Welcome",
	class = "Choose a class",
	swing = "Keep swinging",
	dodge = "Dodge",
	door = "Pick a door",
	haven = "Haven",
})

-- How many goal lines are done, and how many there are.
function Onboarding.goalCount(goals: { { done: boolean } }): (number, number)
	local done = 0
	for _, goal in ipairs(goals) do
		if goal.done then
			done += 1
		end
	end
	return done, #goals
end

-- The pill text: the step's short name, or the first goal still to do
-- when the step's own goal is already done (a class chosen before the
-- save left the class step). The guide says "Wren:" instead of "Shardfall:".
function Onboarding.pillText(stepId: any, goals: { { id: string, done: boolean } }?): string
	local id = Onboarding.step(stepId).id
	local onGuide = guideOn(id)
	local function label(step: string): string
		if onGuide then
			local named = SessionGuide.short(step)
			if type(named) == "string" and named ~= "" then
				return named
			end
		end
		return Onboarding.SHORT[step] or "Welcome"
	end
	local short = label(id)
	if goals ~= nil then
		for _, goal in ipairs(goals) do
			if goal.id == id and goal.done then
				for _, other in ipairs(goals) do
					if not other.done then
						short = label(other.id)
						break
					end
				end
				break
			end
		end
	end
	if onGuide then
		return "Wren: " .. short
	end
	return "Shardfall: " .. short
end

return Onboarding
