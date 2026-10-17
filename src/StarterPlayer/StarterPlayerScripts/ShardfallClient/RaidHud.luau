--!strict

--[[
	Heartwood buttons. Each target is 64px.
	Story queue, Normal queue, a premade post, Practice Grove, the vendor,
	a premade leave, and the premade ready check. Leave drops the seat
	while the player is connected. Ready asks the server to score the
	seated party. The client does not send a host, a member list, or
	anyone else's ready flag.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobileShell = require(script.Parent.MobileShell)

local RaidHud = {}
local player = Players.LocalPlayer
local statusLabel: TextLabel? = nil
local rowRef: Frame? = nil
local toggleRef: TextButton? = nil
local chipRef: TextLabel? = nil
local listener: ((boolean) -> ())? = nil

local function showEcho(label: any)
	local chip = chipRef
	if chip == nil then
		return
	end
	if type(label) ~= "string" or label == "" then
		chip.Text = ""
		chip.Visible = false
		return
	end
	chip.Text = label
	chip.Visible = true
end

function RaidHud.showEcho(label: any)
	showEcho(label)
end

function RaidHud.setListener(fn: (boolean) -> ())
	listener = fn
end

function RaidHud.close()
	if rowRef ~= nil then
		rowRef.Visible = false
	end
	if statusLabel ~= nil then
		statusLabel.Visible = false
	end
end

function RaidHud.isOpen(): boolean
	return rowRef ~= nil and rowRef.Visible
end

local function show(result: any)
	if statusLabel == nil or type(result) ~= "table" then
		return
	end
	if type(result.error) == "string" then
		statusLabel.Text = result.error
	elseif type(result.note) == "string" then
		statusLabel.Text = result.note
	end
end

function RaidHud.setProfile(profile: any)
	if statusLabel == nil or type(profile) ~= "table" then
		return
	end
	local marks = profile.raidMarks or 0
	local best = profile.raidBest or 0
	local line = string.format("Marks %d", marks)
	if profile.raidStory == true then
		line ..= "  Story clear"
	end
	if best > 0 then
		line ..= string.format("  Normal %ds", best)
	end
	if statusLabel.Text == "Heartwood" or string.sub(statusLabel.Text, 1, 5) == "Marks" then
		statusLabel.Text = line
	end
	if toggleRef ~= nil then
		toggleRef.Text = "Raid"
	end
end

function RaidHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallRaids"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 13
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local toggle = Instance.new("TextButton")
	toggle.Name = "RaidToggle"
	toggle.AnchorPoint = Vector2.new(0, 0)
	toggle.Position = UDim2.fromOffset(120, 60)
	toggle.Size = UDim2.fromOffset(96, 64)
	toggle.BackgroundColor3 = Color3.fromRGB(140, 96, 64)
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = 13
	toggle.TextWrapped = true
	toggle.TextColor3 = Color3.fromRGB(16, 14, 24)
	toggle.Text = "Raid"
	toggle.Visible = false
	toggle.Parent = screen
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggleRef = toggle

	local chip = Instance.new("TextLabel")
	chip.Name = "EchoChip"
	chip.AnchorPoint = Vector2.new(0, 0)
	chip.Position = UDim2.fromOffset(248, 16)
	chip.Size = UDim2.fromOffset(128, 28)
	chip.BackgroundColor3 = Color3.fromRGB(120, 186, 96)
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.BuilderSansBold
	chip.TextSize = 14
	chip.TextColor3 = Color3.fromRGB(16, 14, 24)
	chip.Text = ""
	chip.Visible = false
	chip.Parent = screen
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 12)
	chipCorner.Parent = chip
	chipRef = chip

	local row = Instance.new("Frame")
	row.Name = "Raid"
	row.AnchorPoint = Vector2.new(0, 0)
	row.Position = UDim2.fromOffset(120, 132)
	row.Size = UDim2.fromOffset(420, 134)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = screen
	rowRef = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Wraps = true
	layout.Parent = row

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.AnchorPoint = Vector2.new(0, 0)
	note.Position = UDim2.fromOffset(120, 272)
	note.Size = UDim2.fromOffset(420, 32)
	note.Font = Enum.Font.BuilderSans
	note.TextSize = 13
	note.TextColor3 = Color3.fromRGB(240, 236, 248)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextWrapped = true
	note.Text = "Heartwood"
	note.Visible = false
	note.Parent = screen
	statusLabel = note

	toggle.Activated:Connect(function()
		local opening = not row.Visible
		if listener ~= nil then
			listener(opening)
		end
		row.Visible = opening
		note.Visible = opening
	end)

	local function button(name: string, text: string, color: Color3, callback: () -> ())
		local hit = Instance.new("TextButton")
		hit.Name = name
		hit.Size = UDim2.fromOffset(64, 64)
		hit.BackgroundColor3 = color
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = 12
		hit.TextColor3 = Color3.fromRGB(16, 14, 24)
		hit.TextWrapped = true
		hit.Text = text
		hit.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = hit
		hit.Activated:Connect(callback)
	end

	button("Story", "Story", Color3.fromRGB(120, 186, 96), function()
		show(invoke("RaidQueue", "story", "flex"))
	end)
	button("Normal", "Normal", Color3.fromRGB(214, 176, 92), function()
		show(invoke("RaidQueue", "normal", "flex"))
	end)
	button("Board", "Board", Color3.fromRGB(140, 160, 210), function()
		show(invoke("RaidPost", "Learning", "story"))
	end)
	button("Practice", "Practice", Color3.fromRGB(186, 140, 96), function()
		show(invoke("RaidPractice", 1, 1))
	end)
	button("Marks", "Marks", Color3.fromRGB(186, 96, 120), function()
		show(invoke("RaidBuy", "rare_chest"))
	end)
	button("Leave", "Leave", Color3.fromRGB(110, 118, 140), function()
		show(invoke("RaidLeave"))
	end)
	button("Ready", "Ready", Color3.fromRGB(96, 168, 140), function()
		show(invoke("RaidReady"))
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local fx = remotes:WaitForChild("CombatFx")
	if fx:IsA("RemoteEvent") then
		fx.OnClientEvent:Connect(function(payload: any)
			if type(payload) ~= "table" then
				return
			end
			if payload.kind == "victory" or payload.kind == "defeat" then
				showEcho(nil)
				return
			end
			if payload.kind ~= "run" then
				return
			end
			local run = payload.run
			if type(run) ~= "table" or run.active ~= true then
				showEcho(nil)
				return
			end
			showEcho(run.echoLabel)
		end)
	end
end

return RaidHud
