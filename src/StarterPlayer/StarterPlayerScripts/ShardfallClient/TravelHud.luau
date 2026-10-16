--!strict

--[[
	Haven quick travel. The Travel button opens a compact map of the six
	stands. Every stand is open from the start.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quality = require(Shared:WaitForChild("Quality"))
local Travel = require(Shared:WaitForChild("Travel"))
local MobileShell = require(script.Parent.MobileShell)

local TravelHud = {}

export type Callbacks = {
	onTravel: (id: string) -> (),
	onBuyPass: () -> (),
}

local COLORS = {
	background = Color3.fromRGB(16, 14, 24),
	panel = Color3.fromRGB(28, 24, 40),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(150, 146, 168),
	gold = Color3.fromRGB(255, 196, 80),
	button = Color3.fromRGB(108, 78, 196),
	locked = Color3.fromRGB(54, 52, 64),
	open = Color3.fromRGB(72, 52, 120),
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
	}, playerGui) :: ScreenGui
	MobileShell.mount(screen)

	local openButton = new("TextButton", {
		Name = "OpenTravel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 104),
		Size = UDim2.fromOffset(132, Quality.MIN_TAP),
		Visible = false,
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "Travel",
		AutoButtonColor = true,
	}, screen) :: TextButton
	corner(openButton, 8)

	local root = new("Frame", {
		Name = "TravelMap",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -88),
		Size = UDim2.fromOffset(320, 620),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		Visible = false,
	}, screen) :: Frame
	corner(root, 12)
	MobileShell.aspect(root, 0.52)
	MobileShell.limit(root, 400, 680)
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
		TextColor3 = COLORS.text,
		Text = "Travel",
	}, root) :: TextLabel

	local closeButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
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
		TextSize = 13,
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
		TextSize = 13,
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
			Text = "  " .. dest.name,
			AutoButtonColor = true,
			LayoutOrder = index,
		}, list) :: TextButton
		corner(row, 4)
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
	local function toggle()
		root.Visible = not root.Visible
		if root.Visible then
			refresh()
		end
	end
	openButton.MouseButton1Click:Connect(toggle)
	closeButton.MouseButton1Click:Connect(function()
		root.Visible = false
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
	}
end

return TravelHud
