--!strict

--[[
	Haven prompts open the panels that already exist.

	ProximityPrompt.Triggered only reaches a listener connected on that
	machine. The server also fires HavenPrompt, because a prompt that
	prints on both sides can still leave the panel on the wrong tab.

	While the server says the Forge ask is up, an arrow points at the
	Forge. This client does not send seen.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodexCues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CodexCues"))

local HavenClient = {}

export type Callbacks = {
	onPanel: (kind: string, areaId: string?) -> (),
	onSoon: (message: string) -> (),
	onTravel: (() -> ())?,
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
	-- The server owns the Story queue, Waves, and Practice. The echo carries the note.
	if name == "heartwood" or name == "waves" or name == "practice" then
		if type(message) == "string" and message ~= "" then
			callbacks.onSoon(message)
		end
		return
	end
	if name == "armory" or name == "pets" then
		callbacks.onPanel("shards", name)
	elseif name == "craft" then
		callbacks.onPanel("craft", nil)
	elseif name == "market" then
		callbacks.onPanel("market", nil)
	elseif name == "travel" then
		if callbacks.onTravel ~= nil then
			callbacks.onTravel()
		end
	elseif name == "soon" then
		callbacks.onSoon(if type(message) == "string" then message else "Coming soon.")
	end
end

local function forgePart(): BasePart?
	local found = workspace:FindFirstChild("Forge", true)
	if found == nil then
		return nil
	end
	if found:IsA("BasePart") then
		return found
	end
	if found:IsA("Model") then
		if found.PrimaryPart ~= nil then
			return found.PrimaryPart
		end
		local part = found:FindFirstChildWhichIsA("BasePart", true)
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

function HavenClient.start(callbacks: Callbacks)
	print("[Shardfall] Haven prompts listening")
	local crafting = false
	local arrow: Beam? = nil
	local fromAtt: Attachment? = nil
	local toAtt: Attachment? = nil
	local mark: BillboardGui? = nil

	local function clearArrow()
		if arrow ~= nil then
			arrow:Destroy()
			arrow = nil
		end
		if fromAtt ~= nil then
			fromAtt:Destroy()
			fromAtt = nil
		end
		if toAtt ~= nil then
			toAtt:Destroy()
			toAtt = nil
		end
		if mark ~= nil then
			mark:Destroy()
			mark = nil
		end
	end

	local function showArrow()
		clearArrow()
		if not crafting then
			return
		end
		local forge = forgePart()
		local character = Players.LocalPlayer.Character
		local hrp = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if forge == nil or hrp == nil or not hrp:IsA("BasePart") then
			return
		end
		local source = Instance.new("Attachment")
		source.Name = "ForgeArrowFrom"
		source.Parent = hrp
		local target = Instance.new("Attachment")
		target.Name = "ForgeArrowTo"
		target.Parent = forge
		local beam = Instance.new("Beam")
		beam.Name = "ForgeArrow"
		beam.Attachment0 = source
		beam.Attachment1 = target
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Width0 = 0.35
		beam.Width1 = 1.1
		beam.Color = ColorSequence.new(Color3.fromRGB(
			CodexCues.COLOR.arrow[1],
			CodexCues.COLOR.arrow[2],
			CodexCues.COLOR.arrow[3]
		))
		beam.Transparency = NumberSequence.new(0.05)
		beam.Parent = hrp
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ForgeArrow"
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.StudsOffset = Vector3.new(0, 8, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = forge
		local disc = Instance.new("Frame")
		disc.Size = UDim2.fromScale(1, 1)
		disc.BackgroundColor3 = Color3.fromRGB(
			CodexCues.COLOR.iconInk[1],
			CodexCues.COLOR.iconInk[2],
			CodexCues.COLOR.iconInk[3]
		)
		disc.BorderSizePixel = 0
		disc.Parent = billboard
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc
		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Font = Enum.Font.BuilderSansBold
		glyph.TextSize = 22
		glyph.TextColor3 = Color3.fromRGB(
			CodexCues.COLOR.dodge[1],
			CodexCues.COLOR.dodge[2],
			CodexCues.COLOR.dodge[3]
		)
		glyph.Text = "→"
		glyph.Parent = disc
		fromAtt = source
		toAtt = target
		arrow = beam
		mark = billboard
	end

	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		if not crafting then
			return
		end
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 8)
			if Players.LocalPlayer.Character ~= character then
				return
			end
			if root == nil or not root:IsA("BasePart") then
				clearArrow()
				return
			end
			showArrow()
		end)
	end)
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
		-- These queue on the server. Consuming the key here would drop the note.
		if action == "heartwood" or action == "waves" or action == "practice" then
			return
		end
		open(action, prompt.ObjectText, prompt:GetAttribute("HavenMessage"))
	end)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	end
	if remotes == nil then
		warn("[Shardfall] Remotes are not available")
		return
	end
	local remote = remotes:FindFirstChild("HavenPrompt")
	if remote == nil then
		remote = remotes:WaitForChild("HavenPrompt", 15)
	end
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(action, message)
			print("[Shardfall] Server asked the client to open:", action)
			open(action, nil, message)
		end)
	end
	local fx = remotes:FindFirstChild("CombatFx")
	if fx == nil then
		local waited = remotes:WaitForChild("CombatFx", 15)
		if waited ~= nil then
			fx = waited
		end
	end
	if fx ~= nil and fx:IsA("RemoteEvent") then
		fx.OnClientEvent:Connect(function(payload)
			local cue = CodexCues.accept(payload)
			if cue.ok ~= true then
				return
			end
			local nextCue = cue.crafting == true
			if nextCue == crafting and (not nextCue or arrow ~= nil) then
				return
			end
			crafting = nextCue
			showArrow()
		end)
	end
end

return HavenClient
