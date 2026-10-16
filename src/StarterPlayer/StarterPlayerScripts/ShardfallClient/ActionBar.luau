--!strict

--[[
	The only always-on action row. Attack, dodge, skills, tonic, items,
	travel, and menu. Each target is at least 64px and labeled. Graphics
	and auto farm stay on the menu sheet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local MobileShell = require(script.Parent.MobileShell)

local ActionBar = {}

export type Callbacks = {
	onMenu: () -> (),
	onInventory: () -> (),
	onTravel: () -> (),
	onAttack: () -> (),
	onDodge: () -> (),
	onSkills: () -> (),
	onTonic: () -> (),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function button(parent: Instance, name: string, text: string, color: Color3): TextButton
	local widget = new("TextButton", {
		Name = name,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(64, 64),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color3.fromRGB(240, 236, 248),
		Text = text,
		AutoButtonColor = true,
	}, parent) :: TextButton
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, widget)
	return widget
end

function ActionBar.start(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = new("ScreenGui", {
		Name = "ShardfallActions",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 60,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		IgnoreGuiInset = false,
	}, playerGui) :: ScreenGui

	local row = new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -ShellLayout.BAR_MARGIN),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, ShellLayout.ACTION_H + ShellLayout.BAR_PAD * 2),
	}, screen) :: Frame
	new("UIPadding", {
		PaddingTop = UDim.new(0, ShellLayout.BAR_PAD),
		PaddingBottom = UDim.new(0, ShellLayout.BAR_PAD),
		PaddingLeft = UDim.new(0, ShellLayout.BAR_PAD),
		PaddingRight = UDim.new(0, ShellLayout.BAR_PAD),
	}, row)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, ShellLayout.ACTION_GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	local ink = Color3.fromRGB(32, 22, 10)
	local purple = Color3.fromRGB(108, 78, 196)
	local dim = Color3.fromRGB(54, 46, 78)
	local gold = Color3.fromRGB(255, 196, 64)
	local green = Color3.fromRGB(120, 210, 170)

	local attack = button(row, "Attack", "Attack", gold)
	attack.LayoutOrder = 1
	attack.TextColor3 = ink
	local dodge = button(row, "Dodge", "Dodge", green)
	dodge.LayoutOrder = 2
	dodge.TextColor3 = ink
	local skills = button(row, "Skills", "Skills", purple)
	skills.LayoutOrder = 3
	local tonic = button(row, "Tonic", "Tonic", dim)
	tonic.LayoutOrder = 4
	local inventory = button(row, "Inventory", "Items", purple)
	inventory.LayoutOrder = 5
	local travel = button(row, "Travel", "Travel", purple)
	travel.LayoutOrder = 6
	local menu = button(row, "Menu", "Menu", dim)
	menu.LayoutOrder = 7

	local slots = { attack, dodge, skills, tonic, inventory, travel, menu }

	local function applyWidth()
		local vx, _vy = MobileShell.view(screen)
		local slot = ShellLayout.thumbSize(vx)
		local width = math.max(64, slot.w)
		local height = math.max(64, slot.h)
		local gaps = ShellLayout.ACTION_GAP * (ShellLayout.SLOT_COUNT - 1)
		local barW = ShellLayout.SLOT_COUNT * width + gaps + ShellLayout.BAR_PAD * 2
		row.Size = UDim2.fromOffset(barW, height + ShellLayout.BAR_PAD * 2)
		for _, widget in ipairs(slots) do
			widget.Size = UDim2.fromOffset(width, height)
		end
	end
	applyWidth()
	local widthCamera = workspace.CurrentCamera
	if widthCamera ~= nil then
		widthCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyWidth)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyWidth)

	attack.MouseButton1Click:Connect(callbacks.onAttack)
	dodge.MouseButton1Click:Connect(callbacks.onDodge)
	skills.MouseButton1Click:Connect(callbacks.onSkills)
	tonic.MouseButton1Click:Connect(callbacks.onTonic)
	inventory.MouseButton1Click:Connect(callbacks.onInventory)
	travel.MouseButton1Click:Connect(callbacks.onTravel)
	menu.MouseButton1Click:Connect(callbacks.onMenu)

	return {
		setDodge = function(charges: number)
			dodge.Text = "Dodge\n" .. tostring(charges)
		end,
	}
end

return ActionBar
