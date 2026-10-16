--!strict

--[[
	Bottom action bar. Attack, dodge, skills, tonic, inventory, travel, and
	the menu. Every target is at least 60px. Graphics and auto farm live on
	the menu sheet, not on this row.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))

local ThumbBar = {}

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
		Size = UDim2.fromOffset(72, ShellLayout.ACTION_H),
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

function ThumbBar.start(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = new("ScreenGui", {
		Name = "ShardfallTouch",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 30,
	}, playerGui) :: ScreenGui

	local row = new("Frame", {
		Name = "ThumbRow",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(88, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, ShellLayout.ACTION_H),
	}, screen) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, ShellLayout.ACTION_GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
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
		local camera = workspace.CurrentCamera
		local vx = if camera ~= nil then camera.ViewportSize.X else 1280
		local vy = if camera ~= nil then camera.ViewportSize.Y else 720
		if vx < 1 then
			vx = 1280
		end
		if vy < 1 then
			vy = 720
		end
		local bar = ShellLayout.actionBar(vx, vy)
		local slot = ShellLayout.thumbSize(vx)
		row.Position = UDim2.fromOffset(bar.x, bar.y)
		row.Size = UDim2.fromOffset(bar.w, bar.h)
		for _, widget in ipairs(slots) do
			widget.Size = UDim2.fromOffset(slot.w, slot.h)
		end
	end
	applyWidth()
	local widthCamera = workspace.CurrentCamera
	if widthCamera ~= nil then
		widthCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyWidth)
	end

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

return ThumbBar
