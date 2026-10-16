--!strict

--[[
	Studio-only panel. It is not created in a live server.
	Profile jumps stay on Debug. Shard grants and the boss skip moved here
	from the old side panel. Buttons are 64px so they stay usable on touch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))

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

	local row = Instance.new("ScrollingFrame")
	row.Name = "Debug"
	row.AnchorPoint = Vector2.new(0, 0)
	row.Position = UDim2.fromOffset(16, 16)
	row.Size = UDim2.fromOffset(320, 64)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 4
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row

	local function place()
		local camera = workspace.CurrentCamera
		local vx = if camera ~= nil then camera.ViewportSize.X else 1280
		local vy = if camera ~= nil then camera.ViewportSize.Y else 720
		if vx < 1 then
			vx = 1280
		end
		if vy < 1 then
			vy = 720
		end
		local box = ShellLayout.debugRect(vx, vy)
		row.Position = UDim2.fromOffset(box.x, box.y)
		row.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end

	local function hit(name: string, text: string, callback: () -> ())
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(64, 64)
		button.BackgroundColor3 = Color3.fromRGB(64, 48, 32)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 12
		button.TextColor3 = Color3.fromRGB(255, 236, 200)
		button.TextWrapped = true
		button.Text = text
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		button.Activated:Connect(callback)
	end

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
		local action = pair[1]
		hit(action, pair[2], function()
			invoke("Debug", action)
		end)
	end

	local grants = {
		{ "tokens", "Shards" },
		{ "luck", "Luck" },
		{ "ascension", "Ascend" },
		{ "materials", "Mats" },
		{ "chests", "Chests" },
		{ "forgeboost", "Forge" },
		{ "prisms", "Prisms" },
		{ "boost", "Boost" },
		{ "restrict", "Region" },
	}
	for _, pair in ipairs(grants) do
		local kind = pair[1]
		hit("grant_" .. kind, pair[2], function()
			invoke("DevGrant", kind)
		end)
	end
	hit("skip", "Boss", function()
		invoke("Dungeon", "skip")
	end)
end

return DebugHud
