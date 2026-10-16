--!strict

--[[
	Studio-only panel. It is not created in a live server.
	Buttons are 64px so they stay usable on a touch device in Studio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DebugHud = {}

function DebugHud.start(invoke: (string, ...any) -> any)
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallDebug"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.Parent = player:WaitForChild("PlayerGui")

	local row = Instance.new("Frame")
	row.Name = "Debug"
	row.AnchorPoint = Vector2.new(0, 0)
	row.Position = UDim2.fromOffset(16, 16)
	row.Size = UDim2.fromOffset(760, 64)
	row.BackgroundTransparency = 1
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row

	local actions = {
		{ "level", "Lv20" },
		{ "gold", "Gold" },
		{ "keys", "Keys" },
		{ "gems", "Gems" },
		{ "dust", "Dust" },
		{ "tokens", "Tokens" },
		{ "chest", "Chest" },
		{ "eggs", "Egg" },
		{ "dungeon", "Vault" },
		{ "raid", "Raid" },
		{ "phase", "Phase" },
	}
	for _, pair in ipairs(actions) do
		local hit = Instance.new("TextButton")
		hit.Name = pair[1]
		hit.Size = UDim2.fromOffset(64, 64)
		hit.BackgroundColor3 = Color3.fromRGB(64, 48, 32)
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = 12
		hit.TextColor3 = Color3.fromRGB(255, 236, 200)
		hit.TextWrapped = true
		hit.Text = pair[2]
		hit.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = hit
		local action = pair[1]
		hit.Activated:Connect(function()
			invoke("Debug", action)
		end)
	end
end

return DebugHud
