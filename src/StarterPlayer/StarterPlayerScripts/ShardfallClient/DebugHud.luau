--!strict

--[[
	Owner-only Dev Tools panel (Kevin, Oct 22: "maybe it should have its
	own expandable menu"). A live server does not create this gui, and in
	Studio only DevAccess owners get it. Settings keeps player settings.

	A small "Dev" button sits right-aligned under the Gold / Mastery /
	Shards pills (DevTools.layout). It opens a side panel with collapsible
	sections from DevTools.SECTIONS. The panel is not modal and binds no
	input, so the player can still walk with it open.

	Every press toasts the server's one line ("+1000 Gold (now 1547).",
	"The chest system is off ...", the DevAccess refusal) and prints the
	same line in Output with the [Dev] prefix. Buttons for a system that
	is switched off in LaunchGate are hidden and listed in the footer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DevAccess = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DevAccess"))
local DevTools = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DevTools"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local DebugHud = {}

export type Hooks = {
	toast: ((string) -> ())?,
	apply: ((any) -> ())?,
}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	if row == nil then
		return Color3.fromRGB(244, 240, 252)
	end
	return Color3.fromRGB(row[1], row[2], row[3])
end

local function corner(parent: Instance)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, UiTheme.CORNER)
	item.Parent = parent
end

local function padding(parent: Instance, amount: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, amount)
	pad.PaddingBottom = UDim.new(0, amount)
	pad.PaddingLeft = UDim.new(0, amount)
	pad.PaddingRight = UDim.new(0, amount)
	pad.Parent = parent
end

function DebugHud.start(invoke: (string, ...any) -> any, hooks: Hooks?)
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	-- Owner only (Oct 22). The server refuses everyone else anyway.
	if not DevAccess.player(player) then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallDebug"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 20
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local margin = UiTheme.safeMargin()

	local toggle = Instance.new("TextButton")
	toggle.Name = "DevToggle"
	toggle.AutoButtonColor = true
	toggle.BackgroundColor3 = rgb("debug")
	toggle.BackgroundTransparency = 0
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = UiTheme.MIN_TEXT
	toggle.TextColor3 = rgb("gold")
	toggle.Text = DevTools.BUTTON_TEXT
	toggle.Parent = screen
	corner(toggle)
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = rgb("gold")
	toggleStroke.Thickness = UiTheme.STROKE
	toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleStroke.Parent = toggle

	local panel = Instance.new("Frame")
	panel.Name = "DevPanel"
	panel.BackgroundColor3 = rgb("background")
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.Parent = screen
	corner(panel)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = rgb("debug")
	panelStroke.Thickness = UiTheme.STROKE_BOLD
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = rgb("debug")
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
	header.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(UiTheme.PAD, 0)
	title.Size = UDim2.new(1, -(UiTheme.TOUCH + UiTheme.PAD * 2), 1, 0)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = UiTheme.MIN_TEXT + 2
	title.TextColor3 = rgb("gold")
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = DevTools.TITLE
	title.Parent = header
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.BuilderSansBold
	close.TextSize = UiTheme.MIN_TEXT + 4
	close.TextColor3 = rgb("text")
	close.Text = "X"
	close.Parent = header

	local body = Instance.new("ScrollingFrame")
	body.Name = "Sections"
	body.Position = UDim2.fromOffset(0, UiTheme.TOUCH)
	body.Size = UDim2.new(1, 0, 1, -UiTheme.TOUCH)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	padding(body, UiTheme.PAD)
	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.FillDirection = Enum.FillDirection.Vertical
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, UiTheme.PAD)
	bodyLayout.Parent = body

	local function report(ok: boolean, text: string)
		local line = DevTools.outputLine(ok, text)
		if ok then
			print(line)
		else
			warn(line)
		end
		if hooks ~= nil and hooks.toast ~= nil then
			pcall(hooks.toast, text)
		end
	end

	local function press(item: DevTools.Entry, button: TextButton)
		if button:GetAttribute("Busy") == true then
			return
		end
		button:SetAttribute("Busy", true)
		button.Text = item.label .. " ..."
		task.spawn(function()
			local called, result = pcall(invoke, item.remote, item.arg)
			local ok, text = DevTools.resultText(item.label, called, result)
			report(ok, text)
			if ok and hooks ~= nil and hooks.apply ~= nil then
				pcall(hooks.apply, result)
			end
			button.BackgroundColor3 = if ok then rgb("claim") else rgb("close")
			button.Text = item.label
			task.delay(0.6, function()
				button.BackgroundColor3 = rgb("debug")
				button:SetAttribute("Busy", false)
			end)
		end)
	end

	for index, section in ipairs(DevTools.SECTIONS) do
		local shown = {}
		for _, item in ipairs(section.entries) do
			if DevTools.visible(item) then
				table.insert(shown, item)
			end
		end
		if #shown == 0 then
			continue
		end
		local group = Instance.new("Frame")
		group.Name = "Section_" .. section.id
		group.BackgroundTransparency = 1
		group.Size = UDim2.fromScale(1, 0)
		group.AutomaticSize = Enum.AutomaticSize.Y
		group.LayoutOrder = index
		group.Parent = body
		local groupLayout = Instance.new("UIListLayout")
		groupLayout.FillDirection = Enum.FillDirection.Vertical
		groupLayout.SortOrder = Enum.SortOrder.LayoutOrder
		groupLayout.Padding = UDim.new(0, UiTheme.PAD / 2)
		groupLayout.Parent = group

		local head = Instance.new("TextButton")
		head.Name = "Header"
		head.LayoutOrder = 1
		head.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH - 8)
		head.BackgroundColor3 = rgb("panel")
		head.BorderSizePixel = 0
		head.Font = Enum.Font.BuilderSansBold
		head.TextSize = UiTheme.MIN_TEXT
		head.TextColor3 = rgb("gold")
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Parent = group
		corner(head)
		local headPad = Instance.new("UIPadding")
		headPad.PaddingLeft = UDim.new(0, UiTheme.PAD)
		headPad.Parent = head

		local grid = Instance.new("Frame")
		grid.Name = "Buttons"
		grid.LayoutOrder = 2
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.fromScale(1, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = group
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.FillDirection = Enum.FillDirection.Horizontal
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.CellPadding = UDim2.fromOffset(UiTheme.PAD / 2, UiTheme.PAD / 2)
		gridLayout.CellSize = UDim2.new(0.5, -UiTheme.PAD / 4, 0, UiTheme.TOUCH)
		gridLayout.Parent = grid

		local function paintHead()
			head.Text = string.format("%s  %s (%d)", if grid.Visible then "-" else "+", section.title, #shown)
		end
		head.Activated:Connect(function()
			grid.Visible = not grid.Visible
			paintHead()
		end)
		paintHead()

		for order, item in ipairs(shown) do
			local button = Instance.new("TextButton")
			button.Name = item.id
			button.LayoutOrder = order
			button.BackgroundColor3 = rgb("debug")
			button.BorderSizePixel = 0
			button.Font = Enum.Font.BuilderSansBold
			button.TextSize = UiTheme.MIN_TEXT
			button.TextColor3 = rgb("gold")
			button.TextWrapped = true
			button.Text = item.label
			button.Parent = grid
			corner(button)
			button.Activated:Connect(function()
				press(item, button)
			end)
		end
	end

	local hidden = DevTools.hiddenLabels()
	if #hidden > 0 then
		local footer = Instance.new("TextLabel")
		footer.Name = "Hidden"
		footer.LayoutOrder = #DevTools.SECTIONS + 1
		footer.BackgroundTransparency = 1
		footer.Size = UDim2.fromScale(1, 0)
		footer.AutomaticSize = Enum.AutomaticSize.Y
		footer.Font = Enum.Font.BuilderSans
		footer.TextSize = UiTheme.MIN_TEXT
		footer.TextColor3 = rgb("muted")
		footer.TextWrapped = true
		footer.TextXAlignment = Enum.TextXAlignment.Left
		footer.Text = "Hidden while their system is off (LaunchGate): " .. table.concat(hidden, ", ") .. "."
		footer.Parent = body
	end

	local function place()
		local size = screen.AbsoluteSize
		local button, frame = DevTools.layout(size.X, size.Y, margin)
		toggle.Position = UDim2.fromOffset(button.x, button.y)
		toggle.Size = UDim2.fromOffset(button.w, button.h)
		panel.Position = UDim2.fromOffset(frame.x, frame.y)
		panel.Size = UDim2.fromOffset(frame.w, frame.h)
	end

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
end

return DebugHud
