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
local InventoryStacks = require(Shared:WaitForChild("InventoryStacks"))
local InventoryView = require(Shared:WaitForChild("InventoryView"))
local Materials = require(Shared:WaitForChild("Materials"))
local Rarities = require(Shared:WaitForChild("Rarities"))
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

local function chip(parent: Instance, text: string, order: number): TextButton
	local button = new("TextButton", {
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextColor3 = COLORS.text,
		Text = text,
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
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		Visible = false,
	}, screen) :: Frame
	corner(root, 12)
	MobileShell.aspect(root, 0.62)
	MobileShell.limit(root, 900, 1100)
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
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.5, 1),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = "Inventory",
	}, header) :: TextLabel
	local capacity = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.35, 0),
		Size = UDim2.fromScale(0.35, 1),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = COLORS.muted,
		Text = "",
	}, header) :: TextLabel
	local expand = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -88, 0.5, 0),
		Size = UDim2.fromOffset(96, 44),
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
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, root) :: ScrollingFrame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)

	local filterBar = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
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
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 1, -152),
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

	local function narrow(): boolean
		local camera = workspace.CurrentCamera
		if camera == nil then
			return false
		end
		return camera.ViewportSize.X < 760
	end

	local function placePanes()
		local phone = narrow()
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
		color: Color3
	): TextButton
		local button = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 44),
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

	local render: () -> ()

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
		title.Text = "Inventory"

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
		end
		if not still then
			selectedId = nil
			placePanes()
		end
		if #rows == 0 then
			local empty = label(grid, InventoryView.emptyText(query.tab), 1, COLORS.muted, 14)
			empty.Name = "Notice"
			empty.Size = UDim2.fromOffset(220, 40)
		end

		clearGenerated(detail)
		local order = 1
		if narrow() and selectedId ~= nil then
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
			label(detail, "Select an item.", order, COLORS.muted, 14)
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

	local realmButton = chip(filterBar, "Realm: Any", 2)
	local slotButton = chip(filterBar, "Type: Any", 3)
	local socketButton = chip(filterBar, "Sockets: Any", 4)
	local equippedButton = chip(filterBar, "Worn: All", 5)
	local lockedButton = chip(filterBar, "Lock: All", 6)
	local sortButton = chip(filterBar, "Sort: Power", 7)

	local function paintFilters()
		realmButton.Text = "Realm: " .. (query.realm or "Any")
		slotButton.Text = "Type: " .. (query.slot or "Any")
		if query.socketsAtLeast ~= nil then
			socketButton.Text = "Sockets: 3+"
		elseif query.sockets ~= nil then
			socketButton.Text = "Sockets: " .. tostring(query.sockets)
		else
			socketButton.Text = "Sockets: Any"
		end
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
		local rarityOn = false
		for _, rarity in ipairs(Rarities.ORDER) do
			if query.rarities[rarity] == true then
				rarityOn = true
			end
		end
		for _, rarity in ipairs(Rarities.ORDER) do
			local button = filterBar:FindFirstChild("Rarity_" .. rarity)
			if button ~= nil and button:IsA("TextButton") then
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
		isOpen = open
		root.Visible = open
		openButton.Visible = false
		if open then
			render()
		end
	end

	openButton.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			setOpen(not isOpen)
		end
	end)

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

	paintFilters()
	return controller
end

return InventoryHud
