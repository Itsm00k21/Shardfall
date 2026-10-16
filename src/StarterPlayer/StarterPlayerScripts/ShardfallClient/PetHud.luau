--!strict

--[[
	Hatchery button. Care and fusion ids are on the profile companions.
]]

local Players = game:GetService("Players")

local PetHud = {}
local player = Players.LocalPlayer
local label: TextLabel? = nil

function PetHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallPets"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 11
	screen.Parent = player:WaitForChild("PlayerGui")
	local button = Instance.new("TextButton")
	button.Name = "Hatch"
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new(0, 16, 1, -250)
	button.Size = UDim2.fromOffset(96, 64)
	button.BackgroundColor3 = Color3.fromRGB(120, 186, 96)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(16, 14, 24)
	button.Text = "Hatch"
	button.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromOffset(0, -22)
	note.Size = UDim2.new(1, 0, 0, 20)
	note.Font = Enum.Font.BuilderSans
	note.TextSize = 13
	note.TextColor3 = Color3.fromRGB(240, 236, 248)
	note.Text = ""
	note.Parent = button
	label = note
	button.MouseButton1Click:Connect(function()
		task.spawn(function()
			pcall(invoke, "HatchPet")
		end)
	end)
end

function PetHud.setProfile(profile: any)
	local note = label
	if note == nil or type(profile) ~= "table" then
		return
	end
	local count = if type(profile.companions) == "table" then #profile.companions else 0
	note.Text = string.format("%d pets  %d eggs", count, profile.eggs or 0)
end

return PetHud
