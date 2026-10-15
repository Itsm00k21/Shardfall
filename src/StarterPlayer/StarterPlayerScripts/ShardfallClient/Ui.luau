--!strict

--[[
	Test harness UI. Not the real game HUD.

	The panel stays short on purpose: stats, a pity line that counts up, one
	Crack button, and the inventory. Odds are behind View odds so the
	disclosure stays one click away without covering the panel. Saving is a
	badge, not a paragraph. Studio dev grants sit in a collapsed section.

	Roll areas come from Areas.all(). One area hides the picker. Two or more
	show it above Crack. The client sends that area's pool id.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared:WaitForChild("Areas"))
local InventoryStacks = require(Shared:WaitForChild("InventoryStacks"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local RollMath = require(Shared:WaitForChild("RollMath"))

local Ui = {}

export type Callbacks = {
	showDev: boolean,
	onCrack: () -> (),
	onPaid: () -> (),
	onEquip: (uid: string) -> (),
	onUnequip: (uid: string) -> (),
	onRemove: (uid: string) -> (),
	onDev: (kind: string) -> (),
	onArea: (poolId: string) -> (),
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
	stroke = Color3.fromRGB(64, 54, 92),
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

local function padding(parent: Instance, px: number)
	new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	}, parent)
end

local function list(parent: Instance, gap: number): UIListLayout
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	}, parent) :: UIListLayout
end

local function rarityColor(rarity: string): Color3
	local r, g, b = Rarities.rgb(rarity)
	return Color3.fromRGB(r, g, b)
end

local function paintRarity(label: TextLabel, rarity: string)
	label.TextColor3 = rarityColor(rarity)
	if not Rarities.isRainbow(rarity) then
		return
	end
	local gradient = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 196, 80)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 130)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 150)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 110, 255)),
		}),
	}, label) :: UIGradient
	table.insert(gradients, gradient)
end

local function clearGenerated(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if
			child:IsA("UIListLayout")
			or child:IsA("UIPadding")
			or child:IsA("UICorner")
			or child.Name == "Notice"
		then
			continue
		end
		child:Destroy()
	end
end

local function makeButton(
	parent: Instance,
	text: string,
	color: Color3,
	order: number,
	height: number
): TextButton
	local widget = new("TextButton", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextColor3 = COLORS.text,
		Text = text,
		AutoButtonColor = true,
		LayoutOrder = order,
	}, parent) :: TextButton
	corner(widget, 8)
	return widget
end

function Ui.mount(playerGui: PlayerGui, callbacks: Callbacks)
	local screen = new("ScreenGui", {
		Name = "Shardfall",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	}, playerGui) :: ScreenGui

	local panel = new("ScrollingFrame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, 320, 1, -24),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Active = true,
	}, screen) :: ScrollingFrame
	corner(panel, 12)
	padding(panel, 12)
	list(panel, 8)
	new("UIStroke", {
		Color = COLORS.stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, panel)

	local header = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
	}, panel) :: Frame
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -84, 1, 0),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "SHARDFALL",
	}, header)

	local saveBadge = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(76, 20),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 12,
		TextColor3 = COLORS.gold,
		Text = "Not saved",
		AutoButtonColor = true,
		Visible = false,
	}, header) :: TextButton
	corner(saveBadge, 6)

	local saveNote = new("TextLabel", {
		Name = "SaveNote",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "Not saving yet. Publish the place and enable Studio API access.",
		Visible = false,
		LayoutOrder = 2,
	}, panel) :: TextLabel

	local saveOpen = false
	local function paintSave(saving: boolean)
		saveBadge.Visible = not saving
		saveNote.Visible = not saving and saveOpen
	end
	saveBadge.MouseButton1Click:Connect(function()
		saveOpen = not saveOpen
		saveNote.Visible = saveBadge.Visible and saveOpen
	end)

	local stats = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.text,
		Text = "Loading profile...",
		TextWrapped = true,
		LayoutOrder = 3,
	}, panel) :: TextLabel

	local pityLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = RollMath.pityText(0, 50),
		LayoutOrder = 4,
	}, panel) :: TextLabel

	local pityTrack = new("Frame", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 5,
	}, panel) :: Frame
	corner(pityTrack, 4)
	local pityFill = new("Frame", {
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, pityTrack) :: Frame
	corner(pityFill, 4)

	local areas = Areas.all()
	local selected: any = areas[1]
	local latestProfile: any = nil

	local areaRow = new("Frame", {
		Name = "Areas",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, if #areas > 1 then 28 else 0),
		Visible = #areas > 1,
		LayoutOrder = 6,
	}, panel) :: Frame
	local chips: { { button: TextButton, area: any } } = {}
	if #areas > 1 then
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, areaRow)
		for index, area in ipairs(areas) do
			local chip = makeButton(areaRow, area.name, COLORS.buttonDim, index, 26)
			chip.Size = UDim2.fromOffset(0, 26)
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.TextSize = 13
			chip.Font = Enum.Font.BuilderSansMedium
			new("UIPadding", {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}, chip)
			table.insert(chips, { button = chip, area = area })
		end
	end

	local function paintChips()
		for _, chip in ipairs(chips) do
			local active = selected ~= nil and chip.area.id == selected.id
			chip.button.BackgroundColor3 = if active then COLORS.gold else COLORS.buttonDim
			chip.button.TextColor3 = if active then COLORS.ink else COLORS.text
		end
	end

	local crack = makeButton(panel, "Crack a Shard", COLORS.gold, 7, 44)
	crack.TextColor3 = COLORS.ink
	crack.TextSize = 18

	-- In the layout, directly under the button. Not a cursor tooltip, so it
	-- cannot sit on top of the pointer or cover Crack a Shard.
	local tokenHint = new("TextLabel", {
		Name = "TokenHint",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.danger,
		Text = "Not enough tokens.",
		Visible = false,
		LayoutOrder = 8,
	}, panel) :: TextLabel

	local status = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSans,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "",
		Visible = false,
		LayoutOrder = 9,
	}, panel) :: TextLabel

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 10,
	}, panel) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, actions)
	local viewOdds = makeButton(actions, "View odds", COLORS.buttonDim, 1, 30)
	viewOdds.Size = UDim2.new(0.5, -3, 1, 0)
	viewOdds.TextSize = 14
	viewOdds.Font = Enum.Font.BuilderSansMedium
	local paid = makeButton(actions, "Paid roll", COLORS.buttonDim, 2, 30)
	paid.Size = UDim2.new(0.5, -3, 1, 0)
	paid.TextSize = 14
	paid.Font = Enum.Font.BuilderSansMedium

	local oddsWrap = new("Frame", {
		Name = "Odds",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 11,
	}, panel) :: Frame
	corner(oddsWrap, 8)
	padding(oddsWrap, 8)
	list(oddsWrap, 2)
	local oddsNotice = new("TextLabel", {
		Name = "Notice",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.gold,
		Text = "",
		LayoutOrder = 0,
	}, oddsWrap) :: TextLabel

	local oddsOpen = false
	local function setOddsOpen(open: boolean)
		oddsOpen = open
		oddsWrap.Visible = open
		viewOdds.Text = if open then "Hide odds" else "View odds"
	end
	viewOdds.MouseButton1Click:Connect(function()
		setOddsOpen(not oddsOpen)
	end)
	paid.MouseButton1Click:Connect(callbacks.onPaid)

	local loadout = new("TextLabel", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 62),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = COLORS.text,
		Text = "Weapon   None\nPet   None\nBonus   None",
		LayoutOrder = 12,
	}, panel) :: TextLabel
	corner(loadout, 8)
	padding(loadout, 8)

	new("TextLabel", {
		Name = "InventoryHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = "Inventory",
		LayoutOrder = 13,
	}, panel)

	local inventory = new("Frame", {
		Name = "Inventory",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 14,
	}, panel) :: Frame
	list(inventory, 6)

	local devToggle: TextButton? = nil
	local devBody: Frame? = nil
	if callbacks.showDev then
		devToggle = makeButton(panel, "Dev", COLORS.buttonDim, 15, 28)
		devToggle.TextSize = 13
		devToggle.Font = Enum.Font.BuilderSansMedium
		devToggle.TextXAlignment = Enum.TextXAlignment.Left
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}, devToggle)
		devBody = new("Frame", {
			Name = "DevBody",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
			LayoutOrder = 16,
		}, panel) :: Frame
		list(devBody, 6)
		local grantTokens = makeButton(devBody, "+5 tokens", COLORS.buttonDim, 1, 30)
		grantTokens.TextSize = 14
		grantTokens.MouseButton1Click:Connect(function()
			callbacks.onDev("tokens")
		end)
		local grantLuck = makeButton(devBody, "+25 Shard Luck", COLORS.buttonDim, 2, 30)
		grantLuck.TextSize = 14
		grantLuck.MouseButton1Click:Connect(function()
			callbacks.onDev("luck")
		end)
		local devOpen = false
		devToggle.MouseButton1Click:Connect(function()
			devOpen = not devOpen
			if devBody ~= nil then
				devBody.Visible = devOpen
			end
			if devToggle ~= nil then
				devToggle.Text = if devOpen then "Hide dev" else "Dev"
			end
		end)
	end

	local popup = new("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 200),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		Visible = false,
	}, screen) :: Frame
	corner(popup, 12)
	local popupStroke = new("UIStroke", {
		Color = COLORS.gold,
		Thickness = 2,
	}, popup) :: UIStroke
	padding(popup, 16)
	list(popup, 6)

	local popupRarity = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "",
		LayoutOrder = 1,
	}, popup) :: TextLabel
	local popupName = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = "",
		LayoutOrder = 2,
	}, popup) :: TextLabel
	local popupTraits = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "",
		LayoutOrder = 3,
	}, popup) :: TextLabel
	local popupPity = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "",
		LayoutOrder = 4,
	}, popup) :: TextLabel
	local dismiss = makeButton(popup, "Dismiss", COLORS.button, 5, 30)
	dismiss.TextSize = 14

	local popupGeneration = 0
	local function hidePopup()
		popup.Visible = false
		local old = popupRarity:FindFirstChildOfClass("UIGradient")
		if old ~= nil then
			old:Destroy()
		end
	end
	dismiss.MouseButton1Click:Connect(hidePopup)

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

	local busy = false
	local tokens = 0
	local profileLoaded = false
	local controller = {}

	local function paintCrack()
		local ready = tokens > 0 and not busy
		crack.Active = ready
		crack.AutoButtonColor = ready
		crack.Text = if busy then "Cracking..." else "Crack a Shard"
		crack.BackgroundColor3 = if ready then COLORS.gold else COLORS.buttonDim
		crack.TextColor3 = if ready then COLORS.ink else COLORS.muted
		tokenHint.Visible = profileLoaded and tokens < 1 and not busy
	end

	crack.MouseButton1Click:Connect(function()
		if busy or tokens < 1 then
			return
		end
		callbacks.onCrack()
	end)

	local function renderPity(profile: any)
		local goal = 50
		local current = 0
		if selected ~= nil then
			goal = selected.pityLegendaryAt or 50
			if type(profile.pity) == "table" and type(profile.pity[selected.poolId]) == "table" then
				current = profile.pity[selected.poolId].rollsSinceLegendary or 0
			end
		end
		pityLabel.Text = RollMath.pityText(current, goal)
		local ratio = 0
		if goal > 0 then
			ratio = math.clamp(current / goal, 0, 1)
		end
		pityFill.Size = UDim2.fromScale(ratio, 1)
	end

	local function selectArea(area: any, notify: boolean)
		selected = area
		paintChips()
		if latestProfile ~= nil then
			renderPity(latestProfile)
		end
		if notify and area ~= nil then
			callbacks.onArea(area.poolId)
		end
	end
	for _, chip in ipairs(chips) do
		local area = chip.area
		chip.button.MouseButton1Click:Connect(function()
			if selected ~= nil and selected.id == area.id then
				return
			end
			selectArea(area, true)
		end)
	end
	paintChips()

	local function renderInventory(profile: any)
		clearGenerated(inventory)
		local rows = {}
		local function collect(bag: any, equippedUid: any)
			if type(bag) ~= "table" then
				return
			end
			for _, item in pairs(bag) do
				if type(item) == "table" then
					table.insert(rows, {
						item = item,
						equipped = type(item.uid) == "string" and item.uid == equippedUid,
					})
				end
			end
		end
		local equipped = if type(profile.equipped) == "table" then profile.equipped else {}
		collect(profile.inventory, equipped.weapon)
		collect(profile.pets, equipped.pet)

		local stacks = InventoryStacks.group(rows)
		if #stacks == 0 then
			local empty = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.BuilderSans,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLORS.muted,
				Text = "Nothing yet. Crack a shard.",
				LayoutOrder = 1,
			}, inventory) :: TextLabel
			empty.Name = "Empty"
			return
		end

		for index, stack in ipairs(stacks) do
			local card = new("Frame", {
				BackgroundColor3 = COLORS.row,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 52),
				ClipsDescendants = true,
				LayoutOrder = index,
			}, inventory) :: Frame
			corner(card, 8)
			new("Frame", {
				BackgroundColor3 = rarityColor(stack.rarity),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 4, 1, 0),
			}, card)

			local title = if stack.count > 1
				then string.format("%s x%d", stack.name, stack.count)
				else stack.name
			local name = new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -92, 0, 18),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = title,
			}, card) :: TextLabel
			paintRarity(name, stack.rarity)

			local state = if stack.equipped then "Equipped · " else ""
			new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 26),
				Size = UDim2.new(1, -92, 0, 20),
				Font = Enum.Font.BuilderSans,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = COLORS.muted,
				Text = string.format(
					"%s%s · Bonus: %s",
					state,
					stack.kind,
					InventoryStacks.bonusLine(stack.traits)
				),
			}, card)

			local uid = stack.uids[1]
			local canEquip = stack.kind == "Weapon" or stack.kind == "Pet"
			if canEquip and type(uid) == "string" then
				local action = makeButton(
					card,
					if stack.equipped then "Unequip" else "Equip",
					COLORS.button,
					1,
					20
				)
				action.AnchorPoint = Vector2.new(1, 0)
				action.Position = UDim2.new(1, -8, 0, 6)
				action.Size = UDim2.fromOffset(68, 20)
				action.TextSize = 12
				action.MouseButton1Click:Connect(function()
					if stack.equipped then
						callbacks.onUnequip(uid)
					else
						callbacks.onEquip(uid)
					end
				end)
			end
			if not stack.equipped and type(uid) == "string" then
				local drop = makeButton(
					card,
					if stack.count > 1 then "Drop 1" else "Drop",
					COLORS.buttonDim,
					2,
					20
				)
				drop.AnchorPoint = Vector2.new(1, 0)
				drop.Position = UDim2.new(1, -8, 0, if canEquip then 28 else 16)
				drop.Size = UDim2.fromOffset(68, 20)
				drop.TextSize = 12
				drop.TextColor3 = COLORS.danger
				drop.MouseButton1Click:Connect(function()
					callbacks.onRemove(uid)
				end)
			end
		end
	end

	function controller.setBusy(isBusy: boolean)
		busy = isBusy
		paintCrack()
	end

	function controller.setNotice(text: string)
		oddsNotice.Text = text
	end

	function controller.setStatus(text: string, kind: string)
		status.Text = text
		status.Visible = text ~= ""
		if kind == "error" then
			status.TextColor3 = COLORS.danger
		elseif kind == "ok" then
			status.TextColor3 = COLORS.ok
		else
			status.TextColor3 = COLORS.muted
		end
	end

	function controller.setProfile(profile: any, saving: boolean)
		if type(profile) ~= "table" then
			stats.Text = "Loading profile..."
			return
		end
		latestProfile = profile
		profileLoaded = true
		paintSave(saving)
		stats.Text = string.format(
			"Lv %d    ·    %d tokens    ·    Luck %d\n%d/%d XP    ·    %d gold    ·    Asc %d",
			profile.level or 1,
			profile.shardTokens or 0,
			profile.shardLuck or 0,
			profile.xp or 0,
			profile.xpToNext or 100,
			profile.gold or 0,
			profile.ascension or 0
		)
		tokens = profile.shardTokens or 0
		paintCrack()
		renderPity(profile)
		local gear = InventoryStacks.loadout(profile)
		loadout.Text =
			string.format("Weapon   %s\nPet   %s\nBonus   %s", gear.weapon, gear.pet, gear.bonus)
		renderInventory(profile)
	end

	function controller.setOdds(odds: any)
		clearGenerated(oddsWrap)
		if type(odds) ~= "table" then
			oddsNotice.Text = "Odds unavailable."
			return
		end
		oddsNotice.Text = tostring(odds.notice or "")
		local order = 1
		local function heading(text: string)
			order += 1
			local label = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLORS.muted,
				Text = text,
				LayoutOrder = order,
			}, oddsWrap) :: TextLabel
			label.Name = "Heading"
		end
		local function row(text: string, rarity: string)
			order += 1
			local label = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = text,
				LayoutOrder = order,
			}, oddsWrap) :: TextLabel
			-- Solid rarity color. A moving rainbow made Secret read as blank
			-- in a recording; the word stays in the string either way.
			label.TextColor3 = rarityColor(rarity)
		end
		local areaName = if selected ~= nil then selected.name else "Odds"
		heading(areaName .. "  ·  totals")
		if type(odds.rarities) == "table" then
			for _, rarityRow in ipairs(odds.rarities) do
				row(
					string.format(
						"%s    %s",
						rarityRow.rarity,
						RollMath.formatChance(rarityRow.chance)
					),
					rarityRow.rarity
				)
			end
		end
		heading("Each drop")
		if type(odds.entries) == "table" then
			for _, entry in ipairs(odds.entries) do
				row(
					string.format(
						"%s    %s    %s",
						RollMath.formatChance(entry.chance),
						entry.rarity,
						entry.name
					),
					entry.rarity
				)
			end
		end
	end

	function controller.showRoll(result: any)
		local item = result.item
		if type(item) ~= "table" then
			return
		end
		popupGeneration += 1
		local generation = popupGeneration
		local old = popupRarity:FindFirstChildOfClass("UIGradient")
		if old ~= nil then
			old:Destroy()
		end
		popupRarity.Text = string.upper(tostring(item.rarity))
		popupRarity.TextColor3 = rarityColor(item.rarity)
		paintRarity(popupRarity, item.rarity)
		popupName.Text = tostring(item.name)
		popupTraits.Text = "Bonus: " .. InventoryStacks.bonusLine(item.traits)
		popupPity.Text = if result.pityTriggered then "Pity guaranteed this drop." else ""
		popupStroke.Color = rarityColor(item.rarity)
		if Rarities.isRainbow(item.rarity) then
			popupStroke.Color = Color3.fromRGB(255, 255, 255)
		end
		popup.Visible = true
		task.delay(4.5, function()
			if generation == popupGeneration then
				hidePopup()
			end
		end)
	end

	controller.setBusy(false)
	return controller
end

return Ui
