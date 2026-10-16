--!strict

--[[
	Studio-only grants. A live server does not create this gui.
	The row stays closed until the small Debug toggle is pressed, including
	in Studio. Each label is wide enough to read, and Vault appears once.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local DebugHud = {}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	if row == nil then
		return Color3.fromRGB(244, 240, 252)
	end
	return Color3.fromRGB(row[1], row[2], row[3])
end

function DebugHud.start(invoke: (string, ...any) -> any)
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallDebug"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name = "DebugToggle"
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -UiTheme.PAD, 0, UiTheme.PAD)
	toggle.Size = UDim2.fromOffset(UiTheme.labelWidth("Debug"), 32)
	toggle.BackgroundColor3 = rgb("debug")
	toggle.BackgroundTransparency = 0
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = UiTheme.MIN_TEXT
	toggle.TextColor3 = rgb("gold")
	toggle.Text = "Debug"
	toggle.Parent = screen
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	toggleCorner.Parent = toggle

	local row = Instance.new("ScrollingFrame")
	row.Name = "Debug"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -UiTheme.PAD, 0, 48)
	row.Size = UDim2.fromOffset(320, UiTheme.TAP + UiTheme.PAD * 2)
	row.BackgroundColor3 = rgb("background")
	row.BackgroundTransparency = 0
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 4
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Visible = false
	row.ClipsDescendants = true
	row.Parent = screen
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, UiTheme.PAD)
	pad.PaddingBottom = UDim.new(0, UiTheme.PAD)
	pad.PaddingLeft = UDim.new(0, UiTheme.PAD)
	pad.PaddingRight = UDim.new(0, UiTheme.PAD)
	pad.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, UiTheme.PAD)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	rowCorner.Parent = row

	local function place()
		local size = screen.AbsoluteSize
		local vx = if size.X >= 200 then size.X else 1280
		local width = math.clamp(vx - UiTheme.PAD * 2, UiTheme.TAP, 520)
		row.Size = UDim2.fromOffset(width, UiTheme.TAP + UiTheme.PAD * 2)
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	toggle.Activated:Connect(function()
		row.Visible = not row.Visible
	end)

	local function hit(name: string, text: string, callback: () -> ())
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(UiTheme.labelWidth(text), UiTheme.TAP)
		button.BackgroundColor3 = rgb("debug")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("gold")
		button.TextWrapped = false
		button.TextTruncate = Enum.TextTruncate.None
		button.Text = text
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = button
		button.Activated:Connect(callback)
	end

	-- One label each. "Vault" is the dungeon grant. Shard tokens are "Shards"
	-- so they are not a second "Tokens" button.
	local actions = {
		{ "level", "Level" },
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
		{ "materials", "Materials" },
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
