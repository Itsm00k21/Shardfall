--!strict

--[[
	The only menu. Codes, daily, pass, settings, roll, craft, and bossrush
	live here. It starts closed. Opening it is the one modal; each entry
	hands off to that sheet and this panel closes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientChrome"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local MobileShell = require(script.Parent.MobileShell)

local MenuHud = {}

export type Callbacks = {
	onCodes: () -> (),
	onDaily: () -> (),
	onPass: () -> (),
	onSettings: () -> (),
	onRoll: () -> (),
	onCraft: () -> (),
	onBossrush: () -> (),
}

local HANDLERS: { [string]: string } = {
	Codes = "onCodes",
	Daily = "onDaily",
	Pass = "onPass",
	Settings = "onSettings",
	Roll = "onRoll",
	Craft = "onCraft",
	Bossrush = "onBossrush",
}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	if row == nil then
		return Color3.fromRGB(244, 240, 252)
	end
	return Color3.fromRGB(row[1], row[2], row[3])
end

function MenuHud.start(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallMenu"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 58
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Menu"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.BackgroundColor3 = rgb("panel")
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	corner.Parent = panel

	local function place()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.menuSheet(vx, vy)
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(UiTheme.PAD, 4)
	title.Size = UDim2.new(1, -96, 0, 40)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextColor3 = rgb("text")
	title.Text = "Menu"
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -UiTheme.PAD, 0, UiTheme.PAD)
	closeButton.Size = UDim2.fromOffset(72, 36)
	closeButton.BackgroundColor3 = rgb("buttonDim")
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.BuilderSansBold
	closeButton.TextSize = UiTheme.MIN_TEXT
	closeButton.TextColor3 = rgb("text")
	closeButton.Text = "Close"
	closeButton.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromOffset(UiTheme.PAD, 44)
	note.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 36)
	note.Font = Enum.Font.BuilderSans
	note.TextSize = UiTheme.MIN_TEXT
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Center
	note.TextColor3 = rgb("muted")
	note.Text = ""
	note.Visible = false
	note.Parent = panel

	local body = Instance.new("ScrollingFrame")
	body.Name = "Entries"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, 84)
	body.Size = UDim2.new(1, 0, 1, -92)
	body.ScrollBarThickness = 6
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, UiTheme.PAD)
	pad.PaddingRight = UDim.new(0, UiTheme.PAD)
	pad.PaddingBottom = UDim.new(0, UiTheme.PAD)
	pad.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, UiTheme.PAD)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body

	local function press(label: string)
		local key = HANDLERS[label]
		local handler = if key ~= nil then (callbacks :: any)[key] else nil
		if handler ~= nil then
			handler()
		end
	end

	for index, label in ipairs(ClientChrome.MENU) do
		local button = Instance.new("TextButton")
		button.Name = label
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, UiTheme.TAP)
		button.BackgroundColor3 = rgb("button")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextXAlignment = Enum.TextXAlignment.Center
		button.TextYAlignment = Enum.TextYAlignment.Center
		button.TextColor3 = rgb("text")
		button.Text = label
		button.Parent = body
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		buttonCorner.Parent = button
		button.Activated:Connect(function()
			press(label)
		end)
	end

	closeButton.Activated:Connect(function()
		panel.Visible = false
		note.Visible = false
		note.Text = ""
	end)

	return {
		open = function()
			note.Text = ""
			note.Visible = false
			panel.Visible = true
		end,
		close = function()
			panel.Visible = false
			note.Visible = false
			note.Text = ""
		end,
		isOpen = function(): boolean
			return panel.Visible
		end,
		setNote = function(text: string)
			note.Text = text
			note.Visible = text ~= ""
			panel.Visible = true
		end,
	}
end

return MenuHud
