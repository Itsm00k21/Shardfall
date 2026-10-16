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

	local row = new("Frame", {
		Name = "ThumbRow",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 56),
	}, screen) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

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

	local menu = button(row, "Menu", "Menu", dim, width)
	menu.LayoutOrder = 1
	local inventory = button(row, "Inventory", "Items", purple, width)
	inventory.LayoutOrder = 2
	local travel = button(row, "Travel", "Travel", purple, width)
	travel.LayoutOrder = 3
	local graphics = button(row, "Graphics", "Med", dim, width)
	graphics.LayoutOrder = 4
	local farm = button(row, "AutoFarm", "Farm", dim, width)
	farm.LayoutOrder = 5
	local tonic = button(row, "Tonic", "Tonic", dim, width)
	tonic.LayoutOrder = 6
	local attack = button(row, "Attack", "Attack", gold, width)
	attack.LayoutOrder = 7
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
			graphics.Text = label
		end,
		setFarm = function(enabled: boolean)
			farmOn = enabled
			farm.BackgroundColor3 = if farmOn then gold else dim
			farm.TextColor3 = if farmOn then ink else Color3.fromRGB(240, 236, 248)
		end,
	}
end

return ThumbBar
