--!strict

--[[
	Haven prompts open the panels that already exist.

	Armory and Pets switch the shard tab. Forge opens Craft. Anything marked
	soon only writes its message. The Verdant arch is handled on the server.
	StreamingEnabled can add the prompt after this script starts, so new
	descendants are bound too.
]]

local HavenClient = {}

export type Callbacks = {
	onPanel: (kind: string, areaId: string?) -> (),
	onSoon: (message: string) -> (),
}

function HavenClient.start(callbacks: Callbacks)
	local function bind(prompt: ProximityPrompt)
		if prompt:GetAttribute("HavenBound") == true then
			return
		end
		local action = prompt:GetAttribute("HavenAction")
		if type(action) ~= "string" or action == "rootvault" then
			return
		end
		prompt:SetAttribute("HavenBound", true)
		prompt.Triggered:Connect(function()
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

	local function consider(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			bind(instance)
		end
	end

	workspace.DescendantAdded:Connect(consider)
	for _, descendant in ipairs(workspace:GetDescendants()) do
		consider(descendant)
	end
end

return HavenClient
