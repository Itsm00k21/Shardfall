--!strict

--[[
	Thumb buttons along the bottom edge. Every action here is also on a
	panel button, and none of them depend on a keyboard or a hover.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local MobileShell = require(script.Parent.MobileShell)

local ThumbBar = {}

export type Callbacks = {
	onMenu: () -> (),
	onInventory: () -> (),
	onTravel: () -> (),
	onAttack: () -> (),
	onTonic: () -> (),
	onAutoFarm: () -> (),
	onGraphics: () -> (),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function button(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	width: number
): TextButton
	local widget = new("TextButton", {
		Name = name,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, 56),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color3.fromRGB(240, 236, 248),
		Text = text,
		AutoButtonColor = true,
	}, parent) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, widget)
	return widget
end

function ThumbBar.start(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = new("ScreenGui", {
		Name = "ShardfallTouch",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
	}, playerGui) :: ScreenGui
	MobileShell.mount(screen)

	local left = new("Frame", {
		Name = "LeftThumb",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 56),
	}, screen) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, left)

	local right = new("Frame", {
		Name = "RightThumb",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 56),
	}, screen) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, right)

	local ink = Color3.fromRGB(32, 22, 10)
	local purple = Color3.fromRGB(108, 78, 196)
	local dim = Color3.fromRGB(54, 46, 78)
	local gold = Color3.fromRGB(255, 196, 64)

	local function thumbWidth(): number
		local camera = workspace.CurrentCamera
		local vx = if camera ~= nil then camera.ViewportSize.X else 1280
		if vx < 1 then
			vx = 1280
		end
		return ShellLayout.thumbSize(vx).w
	end
	local width = thumbWidth()

	local menu = button(left, "Menu", "≡\nMenu", dim, width)
	menu.LayoutOrder = 1
	local inventory = button(left, "Inventory", "▣\nItems", purple, width)
	inventory.LayoutOrder = 2
	local travel = button(left, "Travel", "→\nTravel", purple, width)
	travel.LayoutOrder = 3

	local graphics = button(right, "Graphics", "◆\nMed", dim, width)
	graphics.LayoutOrder = 1
	local farm = button(right, "AutoFarm", "↻\nFarm", dim, width)
	farm.LayoutOrder = 2
	local tonic = button(right, "Tonic", "+\nTonic", dim, width)
	tonic.LayoutOrder = 3
	local attack = button(right, "Attack", "×\nAttack", gold, width)
	attack.LayoutOrder = 4
	attack.TextColor3 = ink

	local function applyWidth()
		local nextWidth = thumbWidth()
		for _, widget in ipairs({ menu, inventory, travel, graphics, farm, tonic, attack }) do
			widget.Size = UDim2.fromOffset(nextWidth, 56)
		end
	end
	local widthCamera = workspace.CurrentCamera
	if widthCamera ~= nil then
		widthCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyWidth)
	end

	menu.MouseButton1Click:Connect(callbacks.onMenu)
	inventory.MouseButton1Click:Connect(callbacks.onInventory)
	travel.MouseButton1Click:Connect(callbacks.onTravel)
	attack.MouseButton1Click:Connect(callbacks.onAttack)
	tonic.MouseButton1Click:Connect(callbacks.onTonic)
	farm.MouseButton1Click:Connect(callbacks.onAutoFarm)
	graphics.MouseButton1Click:Connect(callbacks.onGraphics)

	local farmOn = false
	return {
		setGraphics = function(label: string)
			graphics.Text = "◆\n" .. label
		end,
		setFarm = function(enabled: boolean)
			farmOn = enabled
			farm.BackgroundColor3 = if farmOn then gold else dim
			farm.TextColor3 = if farmOn then ink else Color3.fromRGB(240, 236, 248)
		end,
	}
end

return ThumbBar
