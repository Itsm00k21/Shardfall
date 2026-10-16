--!strict

--[[
	Daily board. Buttons stay at least 64px so a thumb can hit them.
	Premium stays a refusal until the pass is published.
]]

local Players = game:GetService("Players")

local LoopHud = {}
local player = Players.LocalPlayer
local label: TextLabel? = nil

local function questLine(quest): string
	if type(quest) ~= "table" then
		return ""
	end
	local mark = if quest.done == true then "x" else " "
	return string.format(
		"[%s] %s %d/%d",
		mark,
		tostring(quest.text or quest.id or "Quest"),
		quest.progress or 0,
		quest.goal or 1
	)
end

function LoopHud.setProfile(profile: any)
	if label == nil or type(profile) ~= "table" then
		return
	end
	local lines = {}
	table.insert(lines, string.format("Pass tier %s", tostring(profile.passTier or 0)))
	if type(profile.dailies) == "table" then
		for _, quest in ipairs(profile.dailies) do
			table.insert(lines, questLine(quest))
		end
	end
	if type(profile.weekly) == "table" then
		for _, quest in ipairs(profile.weekly) do
			table.insert(lines, questLine(quest))
		end
	end
	local best = profile.nightmareBest or 0
	if best > 0 then
		table.insert(lines, string.format("Nightmare best %ds", best))
	end
	local ready = if profile.dailyBossReady == true
		then "Daily Gnarl is up"
		else "Daily Gnarl is down"
	table.insert(lines, ready)
	label.Text = table.concat(lines, "\n")
end

function LoopHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallLoops"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 12
	screen.Parent = player:WaitForChild("PlayerGui")

	local note = Instance.new("TextLabel")
	note.Name = "Board"
	note.AnchorPoint = Vector2.new(1, 0)
	note.Position = UDim2.new(1, -16, 0, 72)
	note.Size = UDim2.fromOffset(280, 150)
	note.BackgroundTransparency = 0.35
	note.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	note.BorderSizePixel = 0
	note.Font = Enum.Font.BuilderSans
	note.TextSize = 14
	note.TextColor3 = Color3.fromRGB(240, 236, 248)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.TextWrapped = true
	note.Text = "Dailies"
	note.Parent = screen
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = note
	label = note

	local row = Instance.new("Frame")
	row.Name = "Actions"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -16, 0, 228)
	row.Size = UDim2.fromOffset(280, 64)
	row.BackgroundTransparency = 1
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local function button(name: string, text: string, color: Color3, callback: () -> ())
		local hit = Instance.new("TextButton")
		hit.Name = name
		hit.Size = UDim2.fromOffset(64, 64)
		hit.BackgroundColor3 = color
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = 13
		hit.TextColor3 = Color3.fromRGB(16, 14, 24)
		hit.TextWrapped = true
		hit.Text = text
		hit.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = hit
		hit.Activated:Connect(callback)
	end

	button("Reroll", "Reroll", Color3.fromRGB(214, 176, 92), function()
		invoke("RerollDaily", 1)
	end)
	button("Daily", "Daily", Color3.fromRGB(186, 96, 86), function()
		invoke("StartDailyBoss")
	end)
	button("Claim", "Claim", Color3.fromRGB(120, 186, 96), function()
		invoke("ClaimPass")
	end)
	button("Pass", "Pass", Color3.fromRGB(140, 140, 168), function()
		invoke("PremiumPass")
	end)

	task.defer(function()
		invoke("Loops")
	end)
end

return LoopHud
