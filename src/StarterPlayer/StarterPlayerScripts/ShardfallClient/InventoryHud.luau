--!strict

--[[
	Player inventory. Opens with the HUD button or the I key.

	The grid is a view of InventoryView.query. Equip, lock, favorite, and
	salvage are callbacks the client sends to the server. The dev menu stays
	on the side panel and is not part of this screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MobileShell = require(script.Parent.MobileShell)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionDrag = require(Shared:WaitForChild("ActionDrag"))
local ActionSlots = require(Shared:WaitForChild("ActionSlots"))
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local InventoryStacks = require(Shared:WaitForChild("InventoryStacks"))
local InventoryView = require(Shared:WaitForChild("InventoryView"))
local Materials = require(Shared:WaitForChild("Materials"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local Schema = require(Shared:WaitForChild("Schema"))
local Stars = require(Shared:WaitForChild("Stars"))

local InventoryHud = {}

export type Callbacks = {
	onEquip: (uid: string) -> (),
	onUnequip: (uid: string) -> (),
	onSalvage: (uid: string) -> (),
	onBulkSalvage: (rarity: string) -> (),
	onLock: (uid: string, locked: boolean) -> (),
	onFavorite: (uid: string, favorite: boolean) -> (),
	onExpand: () -> (),
	onRemove: (uid: string) -> (),
	onFeed: (keptUid: string, feederUid: string) -> (),
	onTonic: () -> (),
	onStatus: (text: string, kind: string) -> (),
	onVisible: ((open: boolean) -> ())?,
	onOpenChest: ((tier: string, count: number) -> ())?,
	onMergeChest: ((tier: string) -> ())?,
	onBuyChest: ((tier: string) -> ())?,
	onClaimLogin: (() -> ())?,
	onBuyDust: ((templateId: string) -> ())?,
	onBuyBundle: (() -> ())?,
	onChestOptions: ((mode: string, salvage: string) -> ())?,
	onResumeChest: ((pending: any) -> ())?,
}

local COLORS = {
	background = Color3.fromRGB(16, 14, 24),
	panel = Color3.fromRGB(28, 24, 40),
	row = Color3.fromRGB(40, 34, 58),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(176, 168, 198),
	gold = Color3.fromRGB(255, 196, 64),
	ink = Color3.fromRGB(32, 22, 10),
	danger = Color3.fromRGB(230, 80, 96),
	ok = Color3.fromRGB(110, 210, 140),
	button = Color3.fromRGB(108, 78, 196),
	buttonDim = Color3.fromRGB(54, 46, 78),
}

local gradients: { UIGradient } = {}

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

local function rarityColor(rarity: string): Color3
	local r, g, b = Rarities.rgb(rarity)
	return Color3.fromRGB(r, g, b)
end

local function strokeFor(parent: Instance, rarity: string)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = rarityColor(rarity),
	}, parent) :: UIStroke
	if rarity == "Mythic" or rarity == "Secret" then
		local gradient = new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
				ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 196, 80)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 130)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 150)),
				ColorSequenceKeypoint.new(0.8, Color3.fromRGB(90, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 110, 255)),
			}),
		}, stroke) :: UIGradient
		table.insert(gradients, gradient)
	end
end

local function clearGenerated(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if
			child:IsA("UIListLayout")
			or child:IsA("UIPadding")
			or child:IsA("UIGridLayout")
			or child:IsA("UICorner")
		then
			continue
		end
		child:Destroy()
	end
end

local function chipWidth(text: string): number
	return math.max(88, #text * 8 + 20)
end

local function chip(parent: Instance, text: string, order: number): TextButton
	local button = new("TextButton", {
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(chipWidth(text), 44),
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextColor3 = COLORS.text,
		Text = text,
		TextTruncate = Enum.TextTruncate.None,
		AutoButtonColor = true,
		LayoutOrder = order,
	}, parent) :: TextButton
	corner(button, 6)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, button)
	return button
end

function InventoryHud.start(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = new("ScreenGui", {
		Name = "ShardfallInventory",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
	}, playerGui) :: ScreenGui
	MobileShell.mount(screen)

	local openButton = new("TextButton", {
		Name = "OpenInventory",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.fromOffset(132, 44),
		Visible = false,
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "Inventory",
		AutoButtonColor = true,
	}, screen) :: TextButton
	corner(openButton, 8)

	local root = new("Frame", {
		Name = "Inventory",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 132),
		Size = UDim2.fromOffset(480, 400),
		BackgroundColor3 = COLORS.background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
	}, screen) :: Frame
	corner(root, 12)
	local function phoneLayout(): boolean
		return ShellLayout.mobile(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	end
	local function fitRoot()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.inventory(vx, vy, phoneLayout())
		local pet = ShellLayout.petRect()
		root.Position = UDim2.fromOffset(16, pet.y + pet.h + 8)
		root.Size = UDim2.fromOffset(box.w, box.h)
	end
	fitRoot()
	local fitCamera = workspace.CurrentCamera
	if fitCamera ~= nil then
		fitCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitRoot)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRoot)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, root)

	local header = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
	}, root) :: Frame
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -196, 1, 0),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = COLORS.text,
		Text = "Inventory",
	}, header) :: TextLabel
	local capacity = new("TextLabel", {
		BackgroundTransparency = 1,
		Visible = false,
		Size = UDim2.fromOffset(0, 0),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextColor3 = COLORS.muted,
		Text = "",
	}, header) :: TextLabel
	local expand = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -92, 0.5, 0),
		Size = UDim2.fromOffset(88, 44),
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		TextColor3 = COLORS.text,
		Text = "+ Slots",
	}, header) :: TextButton
	corner(expand, 6)
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(88, 44),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextColor3 = COLORS.text,
		Text = "Close",
	}, header) :: TextButton
	corner(close, 6)

	local tabBar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingEnabled = true,
		CanvasSize = UDim2.fromOffset(720, 44),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ClipsDescendants = true,
	}, root) :: ScrollingFrame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)

	local filterBar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingEnabled = true,
		CanvasSize = UDim2.fromOffset(1400, 44),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ClipsDescendants = true,
	}, root) :: ScrollingFrame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, filterBar)

	local search = new("TextBox", {
		Name = "Search",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(160, 44),
		Font = Enum.Font.BuilderSans,
		TextSize = 16,
		PlaceholderText = "Search",
		PlaceholderColor3 = COLORS.muted,
		TextColor3 = COLORS.text,
		Text = "",
		ClearTextOnFocus = false,
		LayoutOrder = 1,
	}, filterBar) :: TextBox
	corner(search, 6)

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 164),
		Size = UDim2.new(1, 0, 1, -164),
		BackgroundTransparency = 1,
	}, root) :: Frame

	local grid = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body) :: ScrollingFrame
	local gridLayout = new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(8, 8),
		CellSize = UDim2.fromOffset(112, 128),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid) :: UIGridLayout
	new("UIPadding", { PaddingBottom = UDim.new(0, 8) }, grid)

	local detail = new("ScrollingFrame", {
		Name = "Detail",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, body) :: ScrollingFrame
	corner(detail, 10)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, detail)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, detail)

	local confirm = new("Frame", {
		Name = "Confirm",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, root) :: Frame
	corner(confirm, 12)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}, confirm)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, confirm)
	local confirmText = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.text,
		Text = "",
		ZIndex = 6,
		LayoutOrder = 1,
	}, confirm) :: TextLabel
	local confirmYes = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.danger,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "Confirm",
		ZIndex = 6,
		LayoutOrder = 2,
	}, confirm) :: TextButton
	corner(confirmYes, 8)
	local confirmNo = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "Cancel",
		ZIndex = 6,
		LayoutOrder = 3,
	}, confirm) :: TextButton
	corner(confirmNo, 8)

	local query = InventoryView.defaultQuery()
	local selectedId: string? = nil
	local latest: any = nil
	local isOpen = false
	local pendingRarity: string? = nil
	local pendingFeed: { string }? = nil
	local tabButtons: { [string]: TextButton } = {}

	local function placePanes()
		local phone = phoneLayout()
		local showDetail = selectedId ~= nil
		if phone then
			grid.Visible = not showDetail
			detail.Visible = showDetail
			grid.Position = UDim2.fromOffset(0, 0)
			grid.Size = UDim2.fromScale(1, 1)
			detail.Position = UDim2.fromOffset(0, 0)
			detail.Size = UDim2.fromScale(1, 1)
		else
			grid.Visible = true
			detail.Visible = true
			grid.Position = UDim2.fromOffset(0, 0)
			grid.Size = UDim2.new(1, -312, 1, 0)
			detail.Position = UDim2.new(1, -300, 0, 0)
			detail.Size = UDim2.new(0, 300, 1, 0)
		end
		gridLayout.CellSize = if phone
			then UDim2.fromOffset(100, 120)
			else UDim2.fromOffset(112, 128)
	end

	local function label(parent: Instance, text: string, order: number, color: Color3, size: number)
		local widget = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Enum.Font.BuilderSans,
			TextSize = size,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = color,
			Text = text,
			LayoutOrder = order,
		}, parent) :: TextLabel
		return widget
	end

	local function actionButton(
		parent: Instance,
		text: string,
		order: number,
		color: Color3,
		height: number?
	): TextButton
		local button = new("TextButton", {
			Size = UDim2.new(1, 0, 0, if height ~= nil then height else 44),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 14,
			TextColor3 = COLORS.text,
			Text = text,
			LayoutOrder = order,
			AutoButtonColor = true,
		}, parent) :: TextButton
		corner(button, 8)
		return button
	end

	local function chestActions(startOrder: number): number
		local profile = latest
		if type(profile) ~= "table" then
			return startOrder
		end
		local order = startOrder
		local keys = if type(profile.shardKeys) == "number" then profile.shardKeys else 0
		local dust = if type(profile.shardDust) == "number" then profile.shardDust else 0
		label(detail, string.format("Shard Keys  %d", keys), order, COLORS.gold, 14)
		order += 1
		label(detail, string.format("Shard Dust  %d", dust), order, COLORS.gold, 14)
		order += 1
		label(detail, ChestConfig.pityLine(profile), order, COLORS.muted, 13)
		order += 1
		local streak = if type(profile.loginStreak) == "number" then profile.loginStreak else 0
		label(detail, string.format("Login streak  %d", streak), order, COLORS.muted, 13)
		order += 1
		if type(profile.pendingChest) == "table" and callbacks.onResumeChest ~= nil then
			local choose = actionButton(detail, "Choose Mythic card", order, COLORS.gold, 60)
			order += 1
			choose.TextColor3 = COLORS.ink
			local pending = profile.pendingChest
			choose.MouseButton1Click:Connect(function()
				if callbacks.onResumeChest ~= nil then
					callbacks.onResumeChest(pending)
				end
			end)
		end
		if callbacks.onClaimLogin ~= nil then
			local login = actionButton(detail, "Daily login", order, COLORS.button, 60)
			order += 1
			login.MouseButton1Click:Connect(callbacks.onClaimLogin)
		end
		local mode = if profile.chestDuplicates == "star" then "star" else "dust"
		local salvage = if type(profile.chestSalvageBelow) == "string"
			then profile.chestSalvageBelow
			else ""
		if callbacks.onChestOptions ~= nil then
			local modeButton = actionButton(
				detail,
				if mode == "star" then "Duplicates: +1 star" else "Duplicates: Shard Dust",
				order,
				COLORS.buttonDim,
				60
			)
			order += 1
			modeButton.MouseButton1Click:Connect(function()
				if callbacks.onChestOptions == nil then
					return
				end
				local nextMode = if mode == "star" then "dust" else "star"
				callbacks.onChestOptions(nextMode, salvage)
			end)
			local salvageLabel = if salvage == ""
				then "Auto-salvage: off"
				else "Auto-salvage at " .. salvage
			local salvageButton = actionButton(detail, salvageLabel, order, COLORS.buttonDim, 60)
			order += 1
			salvageButton.MouseButton1Click:Connect(function()
				if callbacks.onChestOptions == nil then
					return
				end
				local steps = { "", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
				local index = 1
				for stepIndex, step in ipairs(steps) do
					if step == salvage then
						index = stepIndex
					end
				end
				callbacks.onChestOptions(mode, steps[(index % #steps) + 1])
			end)
		end
		label(detail, "Dust shop", order, COLORS.muted, 13)
		order += 1
		if callbacks.onBuyDust ~= nil then
			for _, row in ipairs(ChestConfig.dustCatalog(profile)) do
				local buy = actionButton(
					detail,
					string.format("%s  ·  %d dust", tostring(row.name), row.cost),
					order,
					COLORS.buttonDim,
					60
				)
				order += 1
				local templateId = row.templateId
				buy.MouseButton1Click:Connect(function()
					if callbacks.onBuyDust ~= nil and type(templateId) == "string" then
						callbacks.onBuyDust(templateId)
					end
				end)
			end
		end
		label(detail, "Paid bundle. Odds are listed before any purchase.", order, COLORS.muted, 13)
		order += 1
		label(
			detail,
			"1 Rare Chest and 1 Epic Chest. Legendary and Mythic chests are not sold.",
			order,
			COLORS.text,
			13
		)
		order += 1
		for _, tierName in ipairs({ "Rare", "Epic" }) do
			label(detail, tierName .. " Chest", order, rarityColor(tierName), 13)
			order += 1
			for _, line in ipairs(ChestConfig.oddsLines(tierName, 1)) do
				label(detail, line, order, COLORS.muted, 12)
				order += 1
			end
		end
		if callbacks.onBuyBundle ~= nil then
			local bundle =
				actionButton(detail, "Request Rare and Epic bundle", order, COLORS.buttonDim, 60)
			order += 1
			bundle.MouseButton1Click:Connect(callbacks.onBuyBundle)
		end
		return order
	end

	local render: () -> ()
	local paintFilters: () -> ()

	local function hideConfirm()
		confirm.Visible = false
		pendingRarity = nil
		pendingFeed = nil
	end

	local function showBulk(rarity: string)
		pendingRarity = rarity
		pendingFeed = nil
		confirmText.Text = string.format(
			"Salvage every %s weapon and armor piece that is not locked or equipped?",
			rarity
		)
		confirmYes.Text = "Salvage"
		confirm.Visible = true
	end

	render = function()
		paintFilters()
		placePanes()
		local profile = latest
		if type(profile) ~= "table" then
			capacity.Text = ""
			return
		end
		local used = Schema.countItems(profile)
		local cap = if type(profile.inventoryCap) == "number"
			then profile.inventoryCap
			else Schema.inventoryCap(profile)
		capacity.Text = string.format("%d / %d", used, cap)
		title.Text = string.format("Inventory   %d / %d", used, cap)

		for _, tab in ipairs(InventoryView.TABS) do
			local button = tabButtons[tab]
			if button ~= nil then
				local active = query.tab == tab
				button.BackgroundColor3 = if active then COLORS.gold else COLORS.buttonDim
				button.TextColor3 = if active then COLORS.ink else COLORS.text
			end
		end

		query.now = os.time()
		local rows = InventoryView.query(profile, query)
		clearGenerated(grid)
		local still = false
		for index, row in ipairs(rows) do
			if row.id == selectedId then
				still = true
			end
			local card = new("TextButton", {
				Name = row.id,
				BackgroundColor3 = COLORS.row,
				BorderSizePixel = 0,
				Font = Enum.Font.BuilderSansBold,
				TextSize = 13,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = rarityColor(row.rarity),
				Text = row.name,
				AutoButtonColor = true,
				LayoutOrder = index,
			}, grid) :: TextButton
			corner(card, 8)
			strokeFor(card, row.rarity)
			new("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 22),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}, card)
			local marks = {}
			if row.equipped then
				table.insert(marks, "Equipped")
			end
			if row.locked then
				table.insert(marks, "Locked")
			end
			if row.favorite then
				table.insert(marks, "Fav")
			end
			if row.count > 1 then
				table.insert(marks, "x" .. tostring(row.count))
			end
			local footer = new("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 8, 1, -6),
				Size = UDim2.new(1, -16, 0, 16),
				Font = Enum.Font.BuilderSans,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = COLORS.muted,
				Text = table.concat(marks, " · "),
			}, card)
			footer.Name = "Marks"
			local picked = row.id
			card.MouseButton1Click:Connect(function()
				selectedId = picked
				render()
			end)
			card.InputBegan:Connect(function(input)
				if
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				then
					return
				end
				local payload = ActionSlots.fromRow(row)
				if payload ~= nil then
					ActionDrag.begin(payload)
				end
			end)
		end
		if not still then
			selectedId = nil
			placePanes()
		end
		if #rows == 0 then
			local empty = label(grid, "No items yet", 1, COLORS.text, 16)
			empty.Name = "Notice"
			empty.Size = UDim2.fromOffset(240, 24)
			local hint = label(grid, InventoryView.emptyText(query.tab), 2, COLORS.muted, 14)
			hint.Name = "Hint"
			hint.Size = UDim2.fromOffset(240, 48)
		end

		clearGenerated(detail)
		local order = 1
		if phoneLayout() and selectedId ~= nil then
			local back = actionButton(detail, "Back", order, COLORS.buttonDim)
			order += 1
			back.MouseButton1Click:Connect(function()
				selectedId = nil
				render()
			end)
		end
		local selected = nil
		for _, row in ipairs(rows) do
			if row.id == selectedId then
				selected = row
			end
		end
		if selected == nil then
			if query.tab == "chests" then
				label(detail, "Select a chest.", order, COLORS.muted, 14)
				chestActions(order + 1)
			else
				label(detail, "Select an item.", order, COLORS.muted, 14)
			end
			return
		end
		local name = label(detail, selected.name, order, rarityColor(selected.rarity), 18)
		name.Font = Enum.Font.BuilderSansBold
		order += 1
		if selected.rarity == "Mythic" or selected.rarity == "Secret" then
			local gradient = new("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 130)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 160, 255)),
				}),
			}, name) :: UIGradient
			table.insert(gradients, gradient)
		end
		label(
			detail,
			string.format("%s  ·  %s", selected.rarity, selected.kind),
			order,
			COLORS.muted,
			13
		)
		order += 1
		if selected.realm ~= "" then
			label(detail, selected.realm, order, COLORS.muted, 13)
			order += 1
		end
		if selected.slot ~= nil then
			label(detail, "Type  " .. selected.slot, order, COLORS.text, 14)
			order += 1
		end
		if
			selected.kind == "Weapon"
			or selected.kind == "Armor"
			or selected.kind == "Accessory"
			or selected.kind == "Pet"
		then
			label(detail, string.format("Sockets  %d", selected.sockets), order, COLORS.text, 14)
			order += 1
		end
		local item = selected.item
		if type(item) == "table" then
			for _, line in ipairs(InventoryView.statLines(item)) do
				label(detail, line, order, COLORS.text, 14)
				order += 1
			end
			if type(item.quality) == "number" then
				label(
					detail,
					"Roll quality  " .. string.format("%d%%", math.floor(item.quality * 100 + 0.5)),
					order,
					COLORS.gold,
					13
				)
				order += 1
			end
			local other = InventoryView.counterpart(profile, item)
			if other ~= nil then
				label(detail, "Compared with " .. tostring(other.name), order, COLORS.gold, 13)
				order += 1
				for _, line in ipairs(InventoryView.compare(item, other)) do
					local delta = if line.delta ~= "" then "  (" .. line.delta .. ")" else ""
					label(
						detail,
						string.format("%s  %s vs %s%s", line.name, line.yours, line.theirs, delta),
						order,
						COLORS.text,
						13
					)
					order += 1
				end
			elseif selected.equipped then
				label(detail, "This is equipped.", order, COLORS.ok, 13)
				order += 1
			end
			local canWear = selected.kind == "Weapon"
				or selected.kind == "Armor"
				or selected.kind == "Pet"
				or selected.kind == "Accessory"
			if canWear then
				local wear = actionButton(
					detail,
					if selected.equipped then "Unequip" else "Equip",
					order,
					COLORS.button
				)
				order += 1
				local uid = selected.id
				wear.MouseButton1Click:Connect(function()
					if selected.equipped then
						callbacks.onUnequip(uid)
					else
						callbacks.onEquip(uid)
					end
				end)
			end
			local uid = selected.id
			local lockButton = actionButton(
				detail,
				if selected.locked then "Unlock" else "Lock",
				order,
				COLORS.buttonDim
			)
			order += 1
			lockButton.MouseButton1Click:Connect(function()
				callbacks.onLock(uid, not selected.locked)
			end)
			local favButton = actionButton(
				detail,
				if selected.favorite then "Unfavorite" else "Favorite",
				order,
				COLORS.buttonDim
			)
			order += 1
			favButton.MouseButton1Click:Connect(function()
				callbacks.onFavorite(uid, not selected.favorite)
			end)
			if selected.kind == "Weapon" or selected.kind == "Armor" then
				local block = InventoryView.salvageBlock(profile, item)
				local salvage = actionButton(
					detail,
					if block ~= nil then block else "Salvage",
					order,
					if block ~= nil then COLORS.buttonDim else COLORS.danger
				)
				order += 1
				salvage.Active = block == nil
				salvage.AutoButtonColor = block == nil
				salvage.MouseButton1Click:Connect(function()
					if InventoryView.salvageBlock(profile, item) ~= nil then
						return
					end
					callbacks.onSalvage(uid)
				end)
			end
			if not selected.equipped then
				local drop = actionButton(detail, "Drop", order, COLORS.buttonDim)
				order += 1
				drop.TextColor3 = if selected.locked then COLORS.muted else COLORS.danger
				drop.Active = not selected.locked
				drop.AutoButtonColor = not selected.locked
				drop.MouseButton1Click:Connect(function()
					if selected.locked then
						callbacks.onStatus("That item is locked.", "error")
						return
					end
					callbacks.onRemove(uid)
				end)
			end
			local feeder = InventoryStacks.bestFeeder(profile, uid)
			if feeder ~= nil and type(feeder.uid) == "string" and (item.stars or 0) < Stars.MAX then
				local feed = actionButton(detail, "Feed duplicate", order, COLORS.gold)
				order += 1
				feed.TextColor3 = COLORS.ink
				local feederUid = feeder.uid
				feed.MouseButton1Click:Connect(function()
					local preview = Stars.advance(item.stars, item.starProgress, feeder.quality)
					if preview == nil then
						callbacks.onStatus("That item is already at five stars.", "error")
						return
					end
					local equippedFeeder = false
					if type(profile.equipped) == "table" then
						equippedFeeder = profile.equipped.weapon == feederUid
							or profile.equipped.pet == feederUid
					end
					pendingFeed = { uid, feederUid }
					pendingRarity = nil
					confirmText.Text = Stars.confirmText(item, feeder, preview, equippedFeeder)
					confirmYes.Text = "Feed"
					confirmYes.BackgroundColor3 = COLORS.gold
					confirmYes.TextColor3 = COLORS.ink
					confirm.Visible = true
				end)
			end
		elseif selected.kind == "Chest" then
			local tier = selected.rarity
			label(detail, string.format("Owned  %d", selected.count), order, COLORS.text, 14)
			order += 1
			local floorName = ChestConfig.FLOOR[tier]
			if type(floorName) == "string" then
				label(detail, "Floor  " .. floorName .. "+", order, COLORS.muted, 13)
				order += 1
			end
			local luck = RarityConfig.luckFromProfile(profile)
			for _, line in ipairs(ChestConfig.oddsLines(tier, luck)) do
				label(detail, line, order, COLORS.muted, 12)
				order += 1
			end
			if callbacks.onOpenChest ~= nil and selected.count > 0 then
				local open = actionButton(detail, "Open", order, COLORS.button, 60)
				order += 1
				open.MouseButton1Click:Connect(function()
					if callbacks.onOpenChest ~= nil then
						callbacks.onOpenChest(tier, 1)
					end
				end)
			end
			if callbacks.onOpenChest ~= nil and selected.count > 1 and tier ~= "Mythic" then
				local manyCount = math.min(selected.count, ChestConfig.OPEN_MANY_MAX)
				local openMany = actionButton(
					detail,
					string.format("Open %d", manyCount),
					order,
					COLORS.button,
					60
				)
				order += 1
				openMany.MouseButton1Click:Connect(function()
					if callbacks.onOpenChest ~= nil then
						callbacks.onOpenChest(tier, manyCount)
					end
				end)
			end
			local rule = ChestConfig.MERGE[tier]
			if type(rule) == "table" and callbacks.onMergeChest ~= nil then
				local owned = if type(profile.materials) == "table" then profile.materials else {}
				local bits = {}
				if type(rule.materials) == "table" then
					for id, count in pairs(rule.materials) do
						local have = if type(owned[id]) == "number" then owned[id] else 0
						table.insert(
							bits,
							string.format("%d %s (have %d)", count, Materials.displayName(id), have)
						)
					end
				end
				label(
					detail,
					string.format(
						"Merge %d into a %s Chest. %s",
						ChestConfig.MERGE_COUNT,
						tostring(rule.next),
						table.concat(bits, ", ")
					),
					order,
					COLORS.text,
					13
				)
				order += 1
				local merge = actionButton(detail, "Merge 5", order, COLORS.gold, 60)
				order += 1
				merge.TextColor3 = COLORS.ink
				merge.MouseButton1Click:Connect(function()
					if callbacks.onMergeChest ~= nil then
						callbacks.onMergeChest(tier)
					end
				end)
			end
			local price = ChestConfig.KEY_SHOP[tier]
			if type(price) == "number" and callbacks.onBuyChest ~= nil then
				local buy = actionButton(
					detail,
					string.format("Buy with %d Shard Keys", price),
					order,
					COLORS.buttonDim,
					60
				)
				order += 1
				buy.MouseButton1Click:Connect(function()
					if callbacks.onBuyChest ~= nil then
						callbacks.onBuyChest(tier)
					end
				end)
			end
			chestActions(order)
		elseif selected.kind == "Consumable" then
			label(detail, string.format("Owned  %d", selected.count), order, COLORS.text, 14)
			order += 1
			local drink = actionButton(detail, "Drink", order, COLORS.button)
			drink.MouseButton1Click:Connect(callbacks.onTonic)
		elseif selected.kind == "Material" or selected.kind == "Scroll" then
			label(detail, string.format("Owned  %d", selected.count), order, COLORS.text, 14)
		elseif selected.kind == "Boost" then
			label(detail, "Active", order, COLORS.ok, 14)
		end

		if query.tab == "weapons" or query.tab == "armor" then
			label(detail, "Bulk salvage", 80, COLORS.muted, 13)
			local bulkOrder = 81
			for _, rarity in ipairs(Rarities.ORDER) do
				if rarity ~= "Secret" then
					local bulk =
						actionButton(detail, "Salvage " .. rarity, bulkOrder, COLORS.buttonDim)
					bulkOrder += 1
					local picked = rarity
					bulk.MouseButton1Click:Connect(function()
						confirmYes.BackgroundColor3 = COLORS.danger
						confirmYes.TextColor3 = COLORS.text
						showBulk(picked)
					end)
				end
			end
		end
	end

	for index, tab in ipairs(InventoryView.TABS) do
		local labelText = string.upper(string.sub(tab, 1, 1)) .. string.sub(tab, 2)
		local button = chip(tabBar, labelText, index)
		button.Size = UDim2.fromOffset(120, 44)
		button.AutomaticSize = Enum.AutomaticSize.None
		tabButtons[tab] = button
		button.MouseButton1Click:Connect(function()
			query.tab = tab
			query.slot = nil
			selectedId = nil
			render()
		end)
	end

	local function cycle(list: { string }, current: string?): string?
		local index = 0
		for i, value in ipairs(list) do
			if value == current then
				index = i
			end
		end
		local nextIndex = index + 1
		if nextIndex > #list then
			return nil
		end
		return list[nextIndex]
	end

	local realmButton = chip(filterBar, "All realms", 2)
	local slotButton = chip(filterBar, "All types", 3)
	local socketButton = chip(filterBar, "All sockets", 4)
	local equippedButton = chip(filterBar, "Worn: All", 5)
	local lockedButton = chip(filterBar, "Lock: All", 6)
	local sortButton = chip(filterBar, "Sort: Power", 7)

	paintFilters = function()
		local flags = InventoryView.activeFilters(query.tab)
		if not flags.realm then
			query.realm = nil
		end
		if not flags.slot then
			query.slot = nil
		end
		if not flags.sockets then
			query.sockets = nil
			query.socketsAtLeast = nil
		end
		if not flags.worn then
			query.equipped = "all"
		end
		if not flags.locked then
			query.locked = "all"
		end
		if not flags.rarity then
			table.clear(query.rarities)
		end
		realmButton.Visible = flags.realm
		slotButton.Visible = flags.slot
		socketButton.Visible = flags.sockets
		equippedButton.Visible = flags.worn
		lockedButton.Visible = flags.locked
		sortButton.Visible = flags.sort
		realmButton.Text = InventoryView.realmLabel(query.realm)
		slotButton.Text = InventoryView.slotLabel(query.slot)
		socketButton.Text = InventoryView.socketLabel(query.sockets, query.socketsAtLeast)
		realmButton.Size = UDim2.fromOffset(chipWidth(realmButton.Text), 44)
		slotButton.Size = UDim2.fromOffset(chipWidth(slotButton.Text), 44)
		socketButton.Size = UDim2.fromOffset(chipWidth(socketButton.Text), 44)
		equippedButton.Text = "Worn: "
			.. string.upper(string.sub(query.equipped, 1, 1))
			.. string.sub(query.equipped, 2)
		lockedButton.Text = "Lock: "
			.. string.upper(string.sub(query.locked, 1, 1))
			.. string.sub(query.locked, 2)
		local sortName = if query.sort == "power"
			then "Power"
			elseif query.sort == "rarity" then "Rarity"
			elseif query.sort == "newest" then "Newest"
			else "Name"
		sortButton.Text = "Sort: " .. sortName
		sortButton.Size = UDim2.fromOffset(chipWidth(sortButton.Text), 44)
		equippedButton.Size = UDim2.fromOffset(chipWidth(equippedButton.Text), 44)
		lockedButton.Size = UDim2.fromOffset(chipWidth(lockedButton.Text), 44)
		local rarityOn = false
		for _, rarity in ipairs(Rarities.ORDER) do
			if query.rarities[rarity] == true then
				rarityOn = true
			end
		end
		for _, rarity in ipairs(Rarities.ORDER) do
			local button = filterBar:FindFirstChild("Rarity_" .. rarity)
			if button ~= nil and button:IsA("TextButton") then
				button.Visible = flags.rarity
				button.Size = UDim2.fromOffset(chipWidth(button.Text), 44)
				local on = query.rarities[rarity] == true
				button.BackgroundColor3 = if on then rarityColor(rarity) else COLORS.buttonDim
				button.TextColor3 = if on
						and rarity ~= "Legendary"
						and rarity ~= "Secret"
					then COLORS.ink
					else COLORS.text
			end
		end
		if not rarityOn then
			for _, rarity in ipairs(Rarities.ORDER) do
				local button = filterBar:FindFirstChild("Rarity_" .. rarity)
				if button ~= nil and button:IsA("TextButton") then
					button.BackgroundColor3 = COLORS.buttonDim
					button.TextColor3 = COLORS.text
				end
			end
		end
	end

	for index, rarity in ipairs(Rarities.ORDER) do
		local button = chip(filterBar, rarity, 10 + index)
		button.Name = "Rarity_" .. rarity
		button.MouseButton1Click:Connect(function()
			query.rarities[rarity] = not (query.rarities[rarity] == true)
			if query.rarities[rarity] ~= true then
				query.rarities[rarity] = nil
			end
			paintFilters()
			render()
		end)
	end

	realmButton.MouseButton1Click:Connect(function()
		query.realm = cycle(Materials.REALMS, query.realm)
		paintFilters()
		render()
	end)
	slotButton.MouseButton1Click:Connect(function()
		query.slot = cycle(InventoryView.slotChoices(query.tab), query.slot)
		paintFilters()
		render()
	end)
	socketButton.MouseButton1Click:Connect(function()
		if query.sockets == nil and query.socketsAtLeast == nil then
			query.sockets = 0
		elseif query.sockets == 0 then
			query.sockets = 1
		elseif query.sockets == 1 then
			query.sockets = 2
		elseif query.sockets == 2 then
			query.sockets = nil
			query.socketsAtLeast = 3
		else
			query.sockets = nil
			query.socketsAtLeast = nil
		end
		paintFilters()
		render()
	end)
	equippedButton.MouseButton1Click:Connect(function()
		if query.equipped == "all" then
			query.equipped = "equipped"
		elseif query.equipped == "equipped" then
			query.equipped = "unequipped"
		else
			query.equipped = "all"
		end
		paintFilters()
		render()
	end)
	lockedButton.MouseButton1Click:Connect(function()
		if query.locked == "all" then
			query.locked = "locked"
		elseif query.locked == "locked" then
			query.locked = "unlocked"
		else
			query.locked = "all"
		end
		paintFilters()
		render()
	end)
	sortButton.MouseButton1Click:Connect(function()
		local sorts = InventoryView.SORTS
		local index = 1
		for i, name in ipairs(sorts) do
			if name == query.sort then
				index = i
			end
		end
		query.sort = sorts[(index % #sorts) + 1]
		paintFilters()
		render()
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query.search = search.Text
		if isOpen then
			render()
		end
	end)

	confirmNo.MouseButton1Click:Connect(hideConfirm)
	confirmYes.MouseButton1Click:Connect(function()
		local rarity = pendingRarity
		local feed = pendingFeed
		hideConfirm()
		if rarity ~= nil then
			callbacks.onBulkSalvage(rarity)
		elseif feed ~= nil then
			callbacks.onFeed(feed[1], feed[2])
		end
	end)
	expand.MouseButton1Click:Connect(callbacks.onExpand)

	local function setOpen(open: boolean)
		if isOpen == open then
			root.Visible = open
			openButton.Visible = false
			return
		end
		isOpen = open
		root.Visible = open
		openButton.Visible = false
		fitRoot()
		if open then
			render()
		end
		if callbacks.onVisible ~= nil then
			callbacks.onVisible(open)
		end
	end

	openButton.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	-- I opens the Raids tab. The old inventory panel does not take that key.
	RunService.RenderStepped:Connect(function()
		local rotation = (os.clock() * 48) % 360
		for index = #gradients, 1, -1 do
			local gradient = gradients[index]
			if gradient.Parent == nil then
				table.remove(gradients, index)
			else
				gradient.Rotation = rotation
			end
		end
	end)

	local controller = {}

	function controller.setProfile(profile: any)
		latest = profile
		if isOpen then
			render()
		end
	end

	function controller.toggle()
		setOpen(not isOpen)
	end

	function controller.open()
		setOpen(true)
	end

	function controller.close()
		setOpen(false)
	end

	function controller.isOpen(): boolean
		return isOpen
	end

	function controller.openTab(tab: string)
		query.tab = tab
		paintFilters()
		if isOpen then
			render()
			return
		end
		setOpen(true)
	end

	paintFilters()
	return controller
end

return InventoryHud
