--!strict

--[[
	Tag on every ProximityPrompt the party gather host may silence.

	The host reads this tag once, then follows added and removed
	signals. It does not walk Workspace. schemaVersion stays 26.
]]

local PartyGatherPrompt = {}

PartyGatherPrompt.TAG = "PartyGatherPrompt"

function PartyGatherPrompt.tag(prompt: Instance)
	if game == nil or game.GetService == nil then
		return
	end
	game:GetService("CollectionService"):AddTag(prompt, PartyGatherPrompt.TAG)
end

return PartyGatherPrompt
