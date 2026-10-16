--!strict

--[[
	Heartwood buttons. Each target is 64px.
	Story queue, Normal queue, a premade post, Practice Grove, and the vendor.
]]

local Players = game:GetService("Players")

local RaidHud = {}
local player = Players.LocalPlayer
local statusLabel: TextLabel? = nil

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
end

function RaidHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallRaids"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 13
	screen.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.Name = "Raid"
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 16, 1, -330)
	row.Size = UDim2.fromOffset(360, 64)
	row.BackgroundTransparency = 1
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 16, 1, -398)
	note.Size = UDim2.fromOffset(340, 36)
	note.Font = Enum.Font.BuilderSans
	note.TextSize = 14
	note.TextColor3 = Color3.fromRGB(240, 236, 248)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextWrapped = true
	note.Text = "Heartwood"
	note.Parent = screen
	statusLabel = note

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
end

return RaidHud
