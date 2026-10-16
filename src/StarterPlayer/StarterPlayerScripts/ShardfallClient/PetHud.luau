--!strict

--[[
	Hatchery button. Care and fusion ids are on the profile companions.
]]

local Players = game:GetService("Players")

local MobileShell = require(script.Parent.MobileShell)

local PetHud = {}
local player = Players.LocalPlayer
local label: TextButton? = nil

function PetHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallPets"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 11
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)
	local button = Instance.new("TextButton")
	button.Name = "Hatch"
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromOffset(16, 60)
	button.Size = UDim2.fromOffset(96, 64)
	button.BackgroundColor3 = Color3.fromRGB(120, 186, 96)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 13
	button.TextWrapped = true
	button.TextColor3 = Color3.fromRGB(16, 14, 24)
	button.Text = "Hatch"
	button.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	label = button
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
	note.Text = string.format("Hatch\n%d  %d", count, profile.eggs or 0)
end

return PetHud
