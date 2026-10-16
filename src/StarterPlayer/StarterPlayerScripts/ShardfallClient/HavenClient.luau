--!strict

--[[
	Haven prompts open the panels that already exist.

	ProximityPrompt.Triggered only reaches a listener connected on that
	machine. The server also fires HavenPrompt, because a prompt that
	prints on both sides can still leave the panel on the wrong tab.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HavenClient = {}

export type Callbacks = {
	onPanel: (kind: string, areaId: string?) -> (),
	onSoon: (message: string) -> (),
}

local function dispatch(callbacks: Callbacks, action: any, objectText: any, message: any)
	local name = ""
	if type(action) == "string" then
		name = string.lower(action)
	end
	if name == "" and type(objectText) == "string" then
		local lower = string.lower(objectText)
		if string.find(lower, "craft", 1, true) ~= nil then
			name = "craft"
		end
	end
	if name == "" or name == "rootvault" then
		return
	end
	if name == "armory" or name == "pets" then
		callbacks.onPanel("shards", name)
	elseif name == "craft" then
		callbacks.onPanel("craft", nil)
	elseif name == "market" then
		callbacks.onPanel("market", nil)
	elseif name == "soon" then
		callbacks.onSoon(if type(message) == "string" then message else "Coming soon.")
	end
end

function HavenClient.start(callbacks: Callbacks)
	print("[Shardfall] Haven prompts listening")
	local recent = ""
	local recentAt = 0
	local function open(action: any, objectText: any, message: any)
		local now = os.clock()
		-- The server echoes HavenPrompt about a second after the client
		-- prompt, and the echo has no ObjectText. Key on the action so that
		-- echo does not open the menu again and dismiss the class picker.
		local key = tostring(action)
		if key == recent and now - recentAt < 2 then
			return
		end
		recent = key
		recentAt = now
		dispatch(callbacks, action, objectText, message)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local action = prompt:GetAttribute("HavenAction")
		print("[Shardfall] Client prompt triggered:", action)
		open(action, prompt.ObjectText, prompt:GetAttribute("HavenMessage"))
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("HavenPrompt")
	if remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(action)
			print("[Shardfall] Server asked the client to open:", action)
			open(action, nil, nil)
		end)
	end
end

return HavenClient
