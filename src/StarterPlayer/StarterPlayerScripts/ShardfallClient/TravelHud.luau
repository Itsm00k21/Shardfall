--!strict

--[[
	Haven quick travel. The Travel button opens a compact map of the six
	stands. Every stand is open from the start.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quality = require(Shared:WaitForChild("Quality"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))
local Travel = require(Shared:WaitForChild("Travel"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local MobileShell = require(script.Parent.MobileShell)

local TravelHud = {}

export type Callbacks = {
	onTravel: (id: string) -> (),
	onBuyPass: () -> (),
	onVisible: ((open: boolean) -> ())?,
}

local COLORS = {
	background = Color3.fromRGB(14, 16, 38),
	panel = Color3.fromRGB(24, 22, 56),
	frame = Color3.fromRGB(150, 92, 255),
	cyan = Color3.fromRGB(110, 225, 255),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(150, 146, 168),
	gold = Color3.fromRGB(255, 196, 80),
	button = Color3.fromRGB(108, 78, 196),
	locked = Color3.fromRGB(54, 52, 64),
	open = Color3.fromRGB(28, 24, 62),
	dot = Color3.fromRGB(186, 140, 255),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local MAP_W = 248
local MAP_H = 168
local MIN_X = -220
local MAX_X = 220
local MIN_Z = -40
local MAX_Z = 280

local function mapOffset(x: number, z: number): UDim2
	local u = math.clamp((x - MIN_X) / (MAX_X - MIN_X), 0, 1)
	local v = math.clamp((z - MIN_Z) / (MAX_Z - MIN_Z), 0, 1)
	return UDim2.fromOffset(10 + u * (MAP_W - 28), 10 + v * (MAP_H - 28))
end

function TravelHud.start(playerGui: PlayerGui, callbacks: Callbacks)
	local profile: any = nil
	local shownSecond = -1

	local screen = new("ScreenGui", {
		Name = "ShardfallTravel",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	}, playerGui) :: ScreenGui
	MobileShell.mount(screen)

	local openButton = new("TextButton", {
		Name = "OpenTravel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH),
		Visible = true,
		BackgroundColor3 = COLORS.open,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "",
		AutoButtonColor = true,
	}, screen) :: TextButton
	corner(openButton, 8)
	-- Portal button: sits beside the bottom of the left rail (the rail column
	-- has no room for a 7th 44px button on landscape phones).
	new("UIStroke", { Thickness = 2, Color = COLORS.frame, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openButton)
	new("ImageLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 1),
		Size = UDim2.new(1, -12, 1, -16),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = IconAssets.Travel or "",
		ZIndex = 2,
	}, openButton)
	local portalCaption = new("TextLabel", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -4, 0, UiTheme.MIN_TEXT),
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansBold,
		TextSize = UiTheme.MIN_TEXT,
		TextColor3 = COLORS.text,
		Text = "Travel",
		ZIndex = 3,
	}, openButton)
	portalCaption:SetAttribute("SkipTextScale", true)

	local root = new("ScrollingFrame", {
		Name = "TravelMap",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 140),
		Size = UDim2.fromOffset(320, 400),
		BackgroundColor3 = COLORS.background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, screen) :: ScrollingFrame
	corner(root, 12)
	new("UIStroke", { Thickness = 2, Color = COLORS.frame, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, root)
	local function place()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.travelRect(vx, vy)
		root.Position = UDim2.fromOffset(box.x, box.y)
		root.Size = UDim2.fromOffset(box.w, box.h)
		local side = HudLayout.railFit(vy, UiTheme.safeMargin(), HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, vx)
		local button = side.button
		openButton.Size = UDim2.fromOffset(button, button)
		openButton.Position = UDim2.fromOffset(side.x + side.w + side.gap + 4, side.y + side.h - button)
	end
	place()
	local placeCamera = workspace.CurrentCamera
	if placeCamera ~= nil then
		placeCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, root)

	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 0, 24),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.cyan,
		Text = "Travel",
	}, root) :: TextLabel

	local closeButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(Quality.MIN_TAP, Quality.MIN_TAP),
		BackgroundTransparency = 1,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextColor3 = COLORS.muted,
		Text = "X",
	}, root) :: TextButton

	local map = new("Frame", {
		Name = "Map",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.fromOffset(MAP_W, MAP_H),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
	}, root) :: Frame
	corner(map, 8)
	MobileShell.aspect(map, MAP_W / MAP_H)

	local list = new("Frame", {
		Name = "Destinations",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 208),
		Size = UDim2.new(1, 0, 0, 300),
	}, root) :: Frame
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local cooldown = new("TextLabel", {
		Name = "Cooldown",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 516),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = "",
	}, root) :: TextLabel

	local passButton = new("TextButton", {
		Name = "TravelPass",
		Position = UDim2.fromOffset(0, 540),
		Size = UDim2.new(1, 0, 0, Quality.MIN_TAP),
		BackgroundColor3 = COLORS.locked,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextColor3 = COLORS.text,
		Text = "Travel pass",
		AutoButtonColor = true,
	}, root) :: TextButton
	corner(passButton, 6)

	local rows: { [string]: TextButton } = {}
	local dots: { [string]: TextButton } = {}

	local function paintRow(id: string)
		local row = rows[id]
		local dot = dots[id]
		if row ~= nil then
			row.BackgroundColor3 = COLORS.open
			row.TextColor3 = COLORS.text
		end
		if dot ~= nil then
			dot.BackgroundColor3 = COLORS.gold
		end
	end

	local function refresh()
		for _, dest in ipairs(Travel.DESTINATIONS) do
			paintRow(dest.id)
		end
		local left = Travel.remaining(profile, os.time())
		if Travel.passSkipsCooldown(profile) then
			cooldown.Text = "Travel pass ready."
		elseif left > 0 then
			cooldown.Text = string.format("Cooling down (%ds).", math.ceil(left))
		else
			cooldown.Text = "Waystones ready."
		end
	end

	for index, dest in ipairs(Travel.DESTINATIONS) do
		local row = new("TextButton", {
			Name = dest.id,
			BackgroundColor3 = COLORS.open,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, Quality.MIN_TAP),
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = COLORS.text,
			Text = "    " .. dest.name,
			AutoButtonColor = true,
			LayoutOrder = index,
		}, list) :: TextButton
		corner(row, 6)
		-- Location card: purple hex edge, cyan crystal tab, and its gate tag.
		new("UIStroke", { Thickness = 1.5, Color = COLORS.frame, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
		new("Frame", {
			Name = "Crystal",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(4, 22),
			BackgroundColor3 = COLORS.cyan,
			BorderSizePixel = 0,
		}, row)
		new("TextLabel", {
			Name = "Gate",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(80, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = COLORS.cyan,
			-- Every Haven stand is open from the first session (Travel.luau).
			Text = "Open",
		}, row)
		rows[dest.id] = row
		row.MouseButton1Click:Connect(function()
			callbacks.onTravel(dest.id)
		end)

		local dot = new("TextButton", {
			Name = dest.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = mapOffset(dest.x, dest.z),
			Size = UDim2.fromOffset(12, 12),
			Active = false,
			BackgroundColor3 = COLORS.dot,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = true,
			ZIndex = 2,
		}, map) :: TextButton
		corner(dot, 7)
		dots[dest.id] = dot
		dot.MouseButton1Click:Connect(function()
			callbacks.onTravel(dest.id)
		end)

		new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(120, 14),
			Font = Enum.Font.BuilderSans,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = COLORS.text,
			Text = dest.name,
			ZIndex = 3,
		}, dot)
	end

	title.Text = "Travel"
	local function setOpen(open: boolean)
		if root.Visible == open then
			return
		end
		root.Visible = open
		if open then
			place()
			refresh()
		end
		if callbacks.onVisible ~= nil then
			callbacks.onVisible(open)
		end
	end
	local function toggle()
		setOpen(not root.Visible)
	end
	openButton.MouseButton1Click:Connect(toggle)
	closeButton.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	passButton.MouseButton1Click:Connect(function()
		callbacks.onBuyPass()
	end)

	RunService.Heartbeat:Connect(function()
		local second = os.time()
		if second == shownSecond then
			return
		end
		shownSecond = second
		if root.Visible then
			refresh()
		end
	end)

	refresh()

	return {
		setProfile = function(nextProfile: any)
			profile = nextProfile
			refresh()
		end,
		toggle = toggle,
		open = function()
			setOpen(true)
		end,
		close = function()
			setOpen(false)
		end,
		isOpen = function(): boolean
			return root.Visible
		end,
	}
end

return TravelHud
