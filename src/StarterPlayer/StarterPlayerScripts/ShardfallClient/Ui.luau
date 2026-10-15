--!strict

--[[
	Test harness UI. Not the real game HUD.

	Built with Instance.new so there is no UI framework to learn yet. The
	panel is a scrolling column: currencies, pity, the disclosed odds, the
	Crack a Shard button, and the inventory. A roll opens a rarity-colored
	popup in the middle of the screen.

	The client displays results. It does not decide them. Every button calls
	back into init.client.luau, which asks the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pools = require(Shared:WaitForChild("Pools"))
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
}

local COLORS = {
	background = Color3.fromRGB(16, 14, 24),
	panel = Color3.fromRGB(28, 24, 40),
	row = Color3.fromRGB(40, 34, 58),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(176, 168, 198),
	gold = Color3.fromRGB(255, 196, 64),
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

local function clearRows(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIPadding") then
			continue
		end
		child:Destroy()
	end
end

local function traitLine(item: any): string
	local traits = item.traits
	if type(traits) ~= "table" or #traits == 0 then
		return item.kind
	end
	local parts = {}
	for _, trait in ipairs(traits) do
		table.insert(parts, string.format("%s %s", trait.name, trait.display))
	end
	return table.concat(parts, "  ·  ")
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
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 360, 1, -32),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Active = true,
	}, screen) :: ScrollingFrame
	corner(panel, 12)
	padding(panel, 14)
	list(panel, 8)

	local function sectionLabel(text: string, size: number, color: Color3, order: number): TextLabel
		return new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, size + 6),
			Font = Enum.Font.BuilderSansBold,
			TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Text = text,
			LayoutOrder = order,
		}, panel) :: TextLabel
	end

	sectionLabel("SHARDFALL", 22, COLORS.gold, 1)

	local banner = new("TextLabel", {
		BackgroundColor3 = COLORS.panel,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.BuilderSans,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "Not saving. Publish the place and enable Studio API access (see the README).",
		Visible = false,
		LayoutOrder = 2,
	}, panel) :: TextLabel
	corner(banner, 6)
	padding(banner, 6)

	local stats = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.BuilderSans,
		TextSize = 15,
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
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = "Pity",
		LayoutOrder = 4,
	}, panel) :: TextLabel

	local pityTrack = new("Frame", {
		BackgroundColor3 = COLORS.panel,
		Size = UDim2.new(1, 0, 0, 12),
		BorderSizePixel = 0,
		LayoutOrder = 5,
	}, panel) :: Frame
	corner(pityTrack, 6)
	local pityFill = new("Frame", {
		BackgroundColor3 = COLORS.gold,
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
	}, pityTrack) :: Frame
	corner(pityFill, 6)

	local notice = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.gold,
		Text = "Loading odds...",
		LayoutOrder = 6,
	}, panel) :: TextLabel

	local raritySummary = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = "",
		LayoutOrder = 7,
	}, panel) :: TextLabel

	local oddsList = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 8,
	}, panel) :: Frame
	list(oddsList, 2)

	local function button(
		text: string,
		color: Color3,
		order: number,
		callback: () -> ()
	): TextButton
		local widget = new("TextButton", {
			BackgroundColor3 = color,
			Size = UDim2.new(1, 0, 0, 36),
			Font = Enum.Font.BuilderSansBold,
			TextSize = 16,
			TextColor3 = COLORS.text,
			Text = text,
			AutoButtonColor = true,
			LayoutOrder = order,
		}, panel) :: TextButton
		corner(widget, 8)
		widget.MouseButton1Click:Connect(callback)
		return widget
	end

	local crack = button("Crack a Shard", COLORS.button, 9, callbacks.onCrack)
	local paid = button("Paid roll (stub)", COLORS.buttonDim, 10, callbacks.onPaid)
	paid.Font = Enum.Font.BuilderSansMedium
	paid.TextSize = 14

	local devTokens: TextButton? = nil
	local devLuck: TextButton? = nil
	if callbacks.showDev then
		devTokens = button("Dev: +5 tokens", COLORS.buttonDim, 11, function()
			callbacks.onDev("tokens")
		end)
		devLuck = button("Dev: +25 Shard Luck", COLORS.buttonDim, 12, function()
			callbacks.onDev("luck")
		end)
		if devTokens ~= nil then
			devTokens.TextSize = 14
		end
		if devLuck ~= nil then
			devLuck.TextSize = 14
		end
	end

	local status = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "",
		LayoutOrder = 13,
	}, panel) :: TextLabel

	sectionLabel("Inventory", 16, COLORS.text, 14).Name = "InventoryHeader"

	local inventory = new("Frame", {
		Name = "Inventory",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 15,
	}, panel) :: Frame
	list(inventory, 6)

	local popup = new("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 210),
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
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "",
		LayoutOrder = 1,
	}, popup) :: TextLabel
	local popupName = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Text = "",
		LayoutOrder = 2,
	}, popup) :: TextLabel
	local popupTraits = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		Font = Enum.Font.BuilderSans,
		TextSize = 15,
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
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "",
		LayoutOrder = 4,
	}, popup) :: TextLabel
	local dismiss = new("TextButton", {
		BackgroundColor3 = COLORS.button,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 15,
		TextColor3 = COLORS.text,
		Text = "Dismiss",
		LayoutOrder = 5,
	}, popup) :: TextButton
	corner(dismiss, 8)

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
	local controller = {}

	local function renderInventory(profile: any)
		clearRows(inventory)
		local rows = {}
		local function collect(bag: any, equippedUid: any)
			if type(bag) ~= "table" then
				return
			end
			for _, item in pairs(bag) do
				table.insert(rows, {
					item = item,
					equipped = item.uid ~= nil and item.uid == equippedUid,
				})
			end
		end
		local equipped = if type(profile.equipped) == "table" then profile.equipped else {}
		collect(profile.inventory, equipped.weapon)
		collect(profile.pets, equipped.pet)
		table.sort(rows, function(a, b)
			local left = Rarities.INDEX[a.item.rarity] or 0
			local right = Rarities.INDEX[b.item.rarity] or 0
			if left ~= right then
				return left > right
			end
			return tostring(a.item.name) < tostring(b.item.name)
		end)

		if #rows == 0 then
			local empty = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.BuilderSans,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLORS.muted,
				Text = "Nothing yet. Crack a shard.",
			}, inventory) :: TextLabel
			empty.LayoutOrder = 1
			return
		end

		for index, row in ipairs(rows) do
			local item = row.item
			local card = new("Frame", {
				BackgroundColor3 = COLORS.row,
				Size = UDim2.new(1, 0, 0, 64),
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, inventory) :: Frame
			corner(card, 8)

			local name = new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 6),
				Size = UDim2.new(1, -150, 0, 20),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = if row.equipped then "Equipped  " .. item.name else item.name,
			}, card) :: TextLabel
			paintRarity(name, item.rarity)

			new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 28),
				Size = UDim2.new(1, -20, 0, 28),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				TextColor3 = COLORS.muted,
				Text = traitLine(item),
			}, card)

			local uid = item.uid
			local canEquip = item.kind == "Weapon" or item.kind == "Pet"
			if canEquip then
				local action = new("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(72, 22),
					BackgroundColor3 = COLORS.button,
					Font = Enum.Font.BuilderSansBold,
					TextSize = 13,
					TextColor3 = COLORS.text,
					Text = if row.equipped then "Unequip" else "Equip",
				}, card) :: TextButton
				corner(action, 6)
				action.MouseButton1Click:Connect(function()
					if type(uid) ~= "string" then
						return
					end
					if row.equipped then
						callbacks.onUnequip(uid)
					else
						callbacks.onEquip(uid)
					end
				end)
			end

			if not row.equipped then
				local drop = new("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, if canEquip then 34 else 8),
					Size = UDim2.fromOffset(72, 22),
					BackgroundColor3 = COLORS.buttonDim,
					Font = Enum.Font.BuilderSans,
					TextSize = 13,
					TextColor3 = COLORS.danger,
					Text = "Drop",
				}, card) :: TextButton
				corner(drop, 6)
				drop.MouseButton1Click:Connect(function()
					if type(uid) == "string" then
						callbacks.onRemove(uid)
					end
				end)
			end
		end
	end

	function controller.setBusy(isBusy: boolean)
		busy = isBusy
		crack.Active = not isBusy
		crack.AutoButtonColor = not isBusy
		crack.Text = if isBusy then "Cracking..." else "Crack a Shard"
		crack.BackgroundColor3 = if isBusy then COLORS.buttonDim else COLORS.button
	end

	function controller.setStatus(text: string, kind: string)
		status.Text = text
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
		banner.Visible = not saving
		stats.Text = string.format(
			"Lv %d    %d / %d XP    Ascension %d\n%d tokens    %d gold    Shard Luck %d",
			profile.level or 1,
			profile.xp or 0,
			profile.xpToNext or 100,
			profile.ascension or 0,
			profile.shardTokens or 0,
			profile.gold or 0,
			profile.shardLuck or 0
		)

		local pool = Pools.get(Pools.STARTER_ID)
		local goal = if pool ~= nil then pool.pityLegendaryAt else 50
		local current = 0
		if
			type(profile.pity) == "table"
			and pool ~= nil
			and type(profile.pity[pool.id]) == "table"
		then
			current = profile.pity[pool.id].rollsSinceLegendary or 0
		end
		pityLabel.Text = string.format("Legendary pity  %d / %d", current, goal)
		local ratio = 0
		if goal > 0 then
			ratio = math.clamp(current / goal, 0, 1)
		end
		pityFill.Size = UDim2.fromScale(ratio, 1)
		renderInventory(profile)

		if not busy then
			local tokens = profile.shardTokens or 0
			crack.Text = if tokens > 0 then "Crack a Shard" else "Crack a Shard (no tokens)"
			crack.BackgroundColor3 = if tokens > 0 then COLORS.button else COLORS.buttonDim
		end
	end

	function controller.setOdds(odds: any)
		clearRows(oddsList)
		if type(odds) ~= "table" then
			notice.Text = "Odds unavailable."
			return
		end
		notice.Text = tostring(odds.notice or "")
		local parts = {}
		if type(odds.rarities) == "table" then
			for _, row in ipairs(odds.rarities) do
				table.insert(
					parts,
					string.format("%s %s", row.rarity, RollMath.formatChance(row.chance))
				)
			end
		end
		raritySummary.Text = table.concat(parts, "    ")
		if type(odds.entries) ~= "table" then
			return
		end
		for index, entry in ipairs(odds.entries) do
			local row = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = string.format(
					"%s    %s    %s",
					RollMath.formatChance(entry.chance),
					entry.rarity,
					entry.name
				),
				LayoutOrder = index,
			}, oddsList) :: TextLabel
			paintRarity(row, entry.rarity)
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
		popupTraits.Text = traitLine(item)
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
