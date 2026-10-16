--!strict

--[[
	The first five minutes.

	A short cold open, then the world teaches one verb at a time. Skip drops
	the player in Haven with the same starter kit. Returning players never
	see it again.
]]

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

function Onboarding.step(id: any)
	if type(id) ~= "string" then
		return Onboarding.STEPS[1]
	end
	for _, row in ipairs(Onboarding.STEPS) do
		if row.id == id then
			return row
		end
	end
	return Onboarding.STEPS[1]
end

function Onboarding.next(id: string): string?
	for index, row in ipairs(Onboarding.STEPS) do
		if row.id == id then
			local following = Onboarding.STEPS[index + 1]
			if following == nil then
				return nil
			end
			return following.id
		end
	end
	return Onboarding.STEPS[1].id
end

-- The starter kit is the same whether they finish or skip.
function Onboarding.starter(data: any)
	data.gold = (data.gold or 0) + 250
	data.shardKeys = (data.shardKeys or 0) + 40
	if type(data.chests) ~= "table" then
		data.chests = {}
	end
	data.chests.Rare = (data.chests.Rare or 0) + 1
	data.chests.Uncommon = (data.chests.Uncommon or 0) + 1
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	data.consumables.healing_tonic = (data.consumables.healing_tonic or 0) + 3
	data.onboardDone = true
	data.onboardStep = "haven"
end

function Onboarding.goals(stepId: string): { { id: string, text: string, done: boolean } }
	local rows = {}
	local marking = true
	for _, row in ipairs(Onboarding.STEPS) do
		if row.id ~= "open" then
			local done = marking and row.id ~= stepId
			if row.id == stepId then
				marking = false
			end
			table.insert(rows, {
				id = row.id,
				text = if row.hint ~= "" then row.hint else row.text,
				done = done,
			})
		end
	end
	return rows
end

return Onboarding
