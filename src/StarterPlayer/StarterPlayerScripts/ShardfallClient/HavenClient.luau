--!strict

--[[
	Haven prompts open the panels that already exist.

	ProximityPrompt.Triggered only reaches a listener connected on that
	machine. The hold ring is drawn by the client either way, so a server
	connection never opens this panel. PromptTriggered fires for prompts
	that stream in later, and the attribute is read at trigger time.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local HavenClient = {}

export type Callbacks = {
	onPanel: (kind: string, areaId: string?) -> (),
	onSoon: (message: string) -> (),
}

function HavenClient.start(callbacks: Callbacks)
	print("[Shardfall] Haven prompts listening")
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local action = prompt:GetAttribute("HavenAction")
		print("[Shardfall] Client prompt triggered:", action)
		if type(action) ~= "string" or action == "rootvault" then
			return
		end
		if action == "armory" or action == "pets" then
			callbacks.onPanel("shards", action)
		elseif action == "craft" then
			callbacks.onPanel("craft", nil)
		elseif action == "soon" then
			local message = prompt:GetAttribute("HavenMessage")
			callbacks.onSoon(if type(message) == "string" then message else "Coming soon.")
		end
	end)
end

return HavenClient
