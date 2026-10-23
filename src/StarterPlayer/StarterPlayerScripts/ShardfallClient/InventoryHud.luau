--!strict

--[[
	Player inventory. Opens with the HUD button or the I key.

	The grid is a view of InventoryView.query. Equip, lock, favorite, and
	salvage are callbacks the client sends to the server. The dev menu stays
	on the side panel and is not part of this screen.

	While the server says a shard can go in, an open socket glows. This
	panel does not send seen.

	[Ghost] Phase 3: this is the one inventory. A centered modal right of
	the left rail and under the HP card (InventoryLayout.modal), with a
	header (title, capacity, Equip Best, Close; "+ Slots" only for
	DevAccess owners), one tabs row, ONE filter row (Search plus Rarity,
	Type and Sort dropdowns), the thin GearBar action bar, a 4-6 column
	grid and a right detail panel that is never empty while the tab has
	items (it starts on the equipped weapon).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MobileShell = require(script.Parent.MobileShell)
local GearBar = require(script.Parent.GearBar)
local GearDetail = require(script.Parent:WaitForChild("GearDetail"))
local Dropdown = require(script.Parent:WaitForChild("Dropdown"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionDrag = require(Shared:WaitForChild("ActionDrag"))
local ActionSlots = require(Shared:WaitForChild("ActionSlots"))
local CodexCues = require(Shared:WaitForChild("CodexCues"))
local DevAccess = require(Shared:WaitForChild("DevAccess"))
local InventoryLayout = require(Shared:WaitForChild("InventoryLayout"))
local GearHooks = require(Shared:WaitForChild("GearHooks"))
local HubStyle = require(Shared:WaitForChild("HubStyle"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local InventoryStacks = require(Shared:WaitForChild("InventoryStacks"))
local InventoryView = require(Shared:WaitForChild("InventoryView"))
local LaunchGate = require(Shared:WaitForChild("LaunchGate"))
local Materials = require(Shared:WaitForChild("Materials"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local Schema = require(Shared:WaitForChild("Schema"))
local Stars = require(Shared:WaitForChild("Stars"))
local TextFit = require(Shared:WaitForChild("TextFit"))

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
	-- GearSalvage(action, payload). Returns the answer after the profile
	-- in it is applied. Only used while gearSalvage is on.
	onGear: ((action: string, payload: any) -> any)?,
	-- [Ghost] Gear detail panel. UpgradeGear(uid) and the Shard Core
	-- remotes (GetShardCore / FeedShardCore). Each returns the answer.
	onUpgrade: ((uid: string) -> any)?,
	onCore: ((action: string, uid: string) -> any)?,
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
	if Rarities.isRainbow(rarity) then
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

-- The card fill: the row color with 18% of the rarity color.
local function tintedRow(rarity: string): Color3
	local r, g, b = Rarities.rgb(rarity)
	local function mix(base: number, top: number): number
		return math.floor(base + (top - base) * 0.18 + 0.5)
	end
	return Color3.fromRGB(mix(40, r), mix(34, g), mix(58, b))
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
		-- Above the left rail (85) so the rail does not cover the title.
		-- Prompts (90) and toasts (100) stay on top.
		DisplayOrder = 86,
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
	new("UIStroke", {
		Name = "Edge",
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1.5,
		Color = Color3.fromRGB(92, 80, 128),
	}, root)
	-- Studio only: PreviewPhone (bool) and PreviewView (Vector2) on the
	-- ScreenGui let a screenshot show the phone layout on a desktop.
	local function previewAttr(name: string): any
		if not RunService:IsStudio() then
			return nil
		end
		return screen:GetAttribute(name)
	end
	local function phoneLayout(): boolean
		local forced = previewAttr("PreviewPhone")
		if type(forced) == "boolean" then
			return forced
		end
		return ShellLayout.mobile(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	end
	local function railRight(): number
		local rail = playerGui:FindFirstChild("ShardfallRail")
		local frame = if rail ~= nil then rail:FindFirstChild("Rail") else nil
		if frame ~= nil and frame:IsA("GuiObject") and frame.Visible and frame.AbsoluteSize.X > 0 then
			return frame.AbsolutePosition.X + frame.AbsoluteSize.X
		end
		return 80
	end
	local placeChrome: (() -> ())? = nil
	local function fitRoot()
		local vx, vy = MobileShell.view(screen)
		local view = previewAttr("PreviewView")
		if typeof(view) == "Vector2" then
			vx, vy = view.X, view.Y
		end
		local phone = phoneLayout()
		local pet = ShellLayout.petRect()
		local box = InventoryLayout.modal(vx, vy, {
			phone = phone,
			railRight = railRight(),
			top = pet.y + pet.h + 8,
		})
		root.Position = UDim2.fromOffset(box.x, box.y)
		root.Size = UDim2.fromOffset(box.w, box.h)
		local place = placeChrome
		if place ~= nil then
			place()
		end
	end
	fitRoot()
	local fitCamera = workspace.CurrentCamera
	if fitCamera ~= nil then
		fitCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitRoot)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRoot)

	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
	}, root) :: Frame
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 4),
	}, header)
	local title = new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 100, 1, 0),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = COLORS.text,
		Text = "Inventory",
	}, header) :: TextLabel
	local capacity = new("TextLabel", {
		Name = "Capacity",
		BackgroundTransparency = 1,
		Visible = true,
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(0, 64, 1, 0),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = "",
	}, header) :: TextLabel
	-- Equip Best moved here from the small Bag.
	local equipBest = new("TextButton", {
		Name = "EquipBest",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(104, 36),
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextColor3 = COLORS.ink,
		Text = "Equip Best",
	}, header) :: TextButton
	corner(equipBest, 6)
	-- "+ Slots" is a dev tool: only DevAccess owners see it.
	local devOwner = false
	pcall(function()
		devOwner = DevAccess.player(Players.LocalPlayer) == true
	end)
	local expand = new("TextButton", {
		Name = "Expand",
		Visible = devOwner,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -92, 0.5, 0),
		Size = UDim2.fromOffset(72, 36),
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 13,
		TextColor3 = COLORS.text,
		Text = "+ Slots",
	}, header) :: TextButton
	corner(expand, 6)
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(72, 36),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextColor3 = COLORS.text,
		Text = "Close",
	}, header) :: TextButton
	corner(close, 6)

	-- One tabs row and one filter row. Neither scrolls sideways: widths
	-- are fitted in placeChrome.
	local tabBar = new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
	}, root) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)

	local filterBar = new("Frame", {
		Name = "Filters",
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}, root) :: Frame
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
		Size = UDim2.fromOffset(200, 36),
		Font = Enum.Font.BuilderSans,
		TextSize = 15,
		PlaceholderText = "Search",
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderColor3 = COLORS.muted,
		TextColor3 = COLORS.text,
		Text = "",
		ClearTextOnFocus = false,
		LayoutOrder = 1,
	}, filterBar) :: TextBox
	corner(search, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }, search)
	local actionsFrame = new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		ZIndex = 2,
	}, root) :: Frame

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 164),
		Size = UDim2.new(1, 0, 1, -164),
		BackgroundTransparency = 1,
	}, root) :: Frame
	-- Full-bag salvage (#388). Built only while gearSalvage is on.
	local gear: any = nil
	local placeGear: (() -> ())? = nil
	local fitTabs: (() -> ())? = nil
	local fitFilters: (() -> ())? = nil
	placeChrome = function()
		local phone = phoneLayout()
		local chrome = InventoryLayout.chrome(root.Size.X.Offset, root.Size.Y.Offset, phone, gear ~= nil)
		local rowH = chrome.rowH
		header.Position = UDim2.fromOffset(chrome.header.x, chrome.header.y)
		header.Size = UDim2.fromOffset(chrome.header.w, chrome.header.h)
		-- Header buttons, right to left: Close, Equip Best, + Slots (dev).
		-- A phone header is about 370 wide: the buttons shrink so they
		-- stop short of the title and the capacity count.
		local closeW = if phone then 56 else 72
		close.Size = UDim2.fromOffset(closeW, rowH)
		close.Position = UDim2.fromScale(1, 0.5)
		local right = closeW + 6
		local bestW = if phone then 52 else 104
		equipBest.Text = if phone then "Best" else "Equip Best"
		equipBest.Size = UDim2.fromOffset(bestW, rowH)
		equipBest.Position = UDim2.new(1, -right, 0.5, 0)
		right += bestW + 6
		if expand.Visible then
			local expandW = if phone then 56 else 72
			expand.Text = if phone then "+Slots" else "+ Slots"
			expand.Size = UDim2.fromOffset(expandW, rowH)
			expand.Position = UDim2.new(1, -right, 0.5, 0)
			right += expandW + 6
		end
		if chrome.compact then
			-- Short window: the tabs share the header row.
			local left = chrome.header.x + 12 + 100 + 64 + 8
			local stop = chrome.header.x + chrome.header.w - 4 - right - 4
			tabBar.Position = UDim2.fromOffset(left, chrome.header.y)
			tabBar.Size = UDim2.fromOffset(math.max(0, stop - left), rowH)
		else
			tabBar.Position = UDim2.fromOffset(chrome.tabs.x, chrome.tabs.y)
			tabBar.Size = UDim2.fromOffset(chrome.tabs.w, chrome.tabs.h)
		end
		filterBar.Position = UDim2.fromOffset(chrome.filters.x, chrome.filters.y)
		filterBar.Size = UDim2.fromOffset(chrome.filters.w, chrome.filters.h)
		actionsFrame.Position = UDim2.fromOffset(chrome.actions.x, chrome.actions.y)
		actionsFrame.Size = UDim2.fromOffset(chrome.actions.w, chrome.actions.h)
		actionsFrame.Visible = chrome.actions.h > 0
		body.Position = UDim2.fromOffset(chrome.body.x, chrome.body.y)
		body.Size = UDim2.fromOffset(chrome.body.w, chrome.body.h)
		local tabsFit = fitTabs
		if tabsFit ~= nil then
			tabsFit()
		end
		local filtersFit = fitFilters
		if filtersFit ~= nil then
			filtersFit()
		end
		local place = placeGear
		if place ~= nil then
			place()
		end
	end
	fitRoot()

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
	-- Top room so the first row's rarity border is not clipped by the scroller.
	new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 8) }, grid)

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
	local socketCue = false
	local isOpen = false
	local coreOpen = true
	local pendingRarity: string? = nil
	local pendingFeed: { string }? = nil
	local tabButtons: { [string]: TextButton } = {}

	local function placePanes()
		local phone = phoneLayout()
		local showDetail = selectedId ~= nil
		-- The action bar (GearBar row) has its own strip above the body;
		-- the salvage bar sits under the grid while Select is on.
		local foot = if gear ~= nil and gear.selecting() then GearBar.BAR_H + 6 else 0
		local bodyW = body.Size.X.Offset
		local detailW = InventoryLayout.detailW(bodyW, phone)
		if phone then
			grid.Visible = not showDetail
			detail.Visible = showDetail
			grid.Position = UDim2.fromOffset(0, 0)
			grid.Size = UDim2.new(1, 0, 1, -foot)
			detail.Position = UDim2.fromOffset(0, 0)
			detail.Size = UDim2.new(1, 0, 1, -foot)
		else
			grid.Visible = true
			detail.Visible = true
			grid.Position = UDim2.fromOffset(0, 0)
			grid.Size = UDim2.new(1, -(detailW + 12), 1, -foot)
			detail.Position = UDim2.new(1, -detailW, 0, 0)
			detail.Size = UDim2.new(0, detailW, 1, 0)
		end
		if gear ~= nil then
			gear.setCompact(phone)
			gear.row.Position = UDim2.fromOffset(0, 0)
			gear.row.Size = UDim2.fromScale(1, 1)
			gear.bar.Position = UDim2.new(0, 0, 1, -GearBar.BAR_H)
			gear.bar.Size = UDim2.new(1, if phone then 0 else -(detailW + 12), 0, GearBar.BAR_H)
		end
		local cells = InventoryLayout.grid(
			if phone then bodyW else bodyW - detailW - 12,
			phone,
			body.Size.Y.Offset - foot
		)
		gridLayout.CellSize = UDim2.fromOffset(cells.cellW, cells.cellH)
		gridLayout.CellPadding = UDim2.fromOffset(cells.gap, cells.gap)
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
		if LaunchGate.on("extraCurrencies") then
			label(detail, string.format("Shard Dust  %d", dust), order, COLORS.gold, 14)
			order += 1
		end
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
		if LaunchGate.on("extraCurrencies") then
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

	-- Access text scale. BaseText keeps the size the label was built at.
	local bagScale: any = 1

	local function fitBagText()
		for _, desc in ipairs(screen:GetDescendants()) do
			if desc:GetAttribute("SkipTextScale") == true then
				continue
			end
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				local base = desc:GetAttribute("BaseText")
				if type(base) ~= "number" then
					base = desc.TextSize
					desc:SetAttribute("BaseText", base)
				end
				desc.TextSize = TextFit.px(base, bagScale)
			end
		end
	end

	local render: () -> ()
	local paintFilters: () -> ()

	local onGear = callbacks.onGear
	if LaunchGate.on("gearSalvage") and onGear ~= nil then
		gear = GearBar.mount(body, {
			invoke = function(action: string, payload: any): any
				return onGear(action, payload)
			end,
			getProfile = function(): any
				return latest
			end,
			onChanged = function()
				if isOpen then
					render()
				end
			end,
			onStatus = function(text: string, kind: string)
				callbacks.onStatus(text, kind)
			end,
			getTab = function(): string?
				return query.tab
			end,
			host = root,
		})
		gear.row.Parent = actionsFrame
		placeGear = placePanes
		placePanes()
	end

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
		if gear ~= nil then
			gear.refresh()
		end
		local profile = latest
		if type(profile) ~= "table" then
			capacity.Text = ""
			fitBagText()
			return
		end
		local used = Schema.countItems(profile)
		local cap = if type(profile.inventoryCap) == "number"
			then profile.inventoryCap
			else Schema.inventoryCap(profile)
		capacity.Text = string.format("%d / %d", used, cap)
		capacity.TextColor3 = if used >= cap then COLORS.danger else COLORS.muted
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
		-- The detail panel is never empty while the tab has items: keep
		-- the pick if it is still here, else the equipped weapon, else
		-- anything worn, else the first card. A phone keeps the grid.
		local present = false
		for _, row in ipairs(rows) do
			if row.id == selectedId then
				present = true
			end
		end
		if not present then
			selectedId = nil
			if not phoneLayout() and #rows > 0 then
				local pick = rows[1]
				local worn = nil
				for _, row in ipairs(rows) do
					if row.equipped and row.kind == "Weapon" then
						pick = row
						worn = nil
						break
					elseif row.equipped and worn == nil then
						worn = row
					end
				end
				if worn ~= nil and not pick.equipped then
					pick = worn
				end
				selectedId = pick.id
			end
		end
		clearGenerated(grid)
		local still = false
		for index, row in ipairs(rows) do
			if row.id == selectedId then
				still = true
			end
			local cellW = gridLayout.CellSize.X.Offset
			local cellH = gridLayout.CellSize.Y.Offset
			local inner = InventoryLayout.card(cellW, cellH)
			local tint = rarityColor(row.rarity)
			local card = new("TextButton", {
				Name = row.id,
				BackgroundColor3 = tintedRow(row.rarity),
				BorderSizePixel = 0,
				Font = Enum.Font.BuilderSansBold,
				TextSize = 13,
				Text = "",
				AutoButtonColor = true,
				LayoutOrder = index,
				ClipsDescendants = true,
			}, grid) :: TextButton
			corner(card, 10)
			strokeFor(card, row.rarity)
			-- Centered icon: the item art, or a glyph when there is none.
			local artId = IconAssets[HubStyle.itemArt(row.item)]
			local art: GuiObject
			if type(artId) == "string" then
				art = new("ImageLabel", {
					Name = "Art",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(inner.art.x, inner.art.y),
					Size = UDim2.fromOffset(inner.art.w, inner.art.h),
					ScaleType = Enum.ScaleType.Fit,
					Image = artId,
				}, card) :: ImageLabel
			else
				art = new("TextLabel", {
					Name = "Art",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(inner.art.x, inner.art.y),
					Size = UDim2.fromOffset(inner.art.w, inner.art.h),
					Font = Enum.Font.BuilderSansBold,
					TextSize = math.max(16, math.floor(inner.art.h * 0.6)),
					TextColor3 = tint,
					Text = GearDetail.glyph(row.kind),
				}, card) :: TextLabel
				art:SetAttribute("SkipTextScale", true)
			end
			local nameLabel = new("TextLabel", {
				Name = "Name",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inner.name.x, inner.name.y),
				Size = UDim2.fromOffset(inner.name.w, inner.name.h),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 13,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextColor3 = tint,
				Text = row.name,
			}, card) :: TextLabel
			-- +level and stars on one line (gear); a count for stacks.
			local levelText = if type(row.item) == "table" and (row.kind == "Weapon" or row.kind == "Armor")
				then GearHooks.levelLine(row.item)
				else ""
			if levelText == "" and row.count > 1 then
				levelText = "x" .. tostring(row.count)
			end
			new("TextLabel", {
				Name = "Level",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inner.level.x, inner.level.y),
				Size = UDim2.fromOffset(inner.level.w, inner.level.h),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = COLORS.gold,
				Text = levelText,
			}, card)
			if row.equipped then
				local badge = new("TextLabel", {
					Name = "EquipBadge",
					Position = UDim2.fromOffset(inner.badge.x, inner.badge.y),
					Size = UDim2.fromOffset(inner.badge.w, inner.badge.h),
					BackgroundColor3 = COLORS.gold,
					BorderSizePixel = 0,
					Font = Enum.Font.BuilderSansBold,
					TextSize = 13,
					TextColor3 = COLORS.ink,
					Text = "E",
					ZIndex = 3,
				}, card) :: TextLabel
				corner(badge, 10)
			end
			if row.id == selectedId then
				local focus = new("Frame", {
					Name = "Focus",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -4, 1, -4),
				}, card)
				corner(focus, 9)
				new("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = 2,
					Color = COLORS.text,
				}, focus)
			end
			if socketCue and row.sockets >= 1 then
				new("UIStroke", {
					Name = "SocketGlow",
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = 3,
					Color = Color3.fromRGB(
						CodexCues.COLOR.socket[1],
						CodexCues.COLOR.socket[2],
						CodexCues.COLOR.socket[3]
					),
				}, card)
			end
			local marks = {}
			if row.locked and gear == nil then
				table.insert(marks, "Locked")
			end
			if row.favorite then
				table.insert(marks, "Fav")
			end
			local footer = (new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inner.marks.x, inner.marks.y),
				Size = UDim2.fromOffset(inner.marks.w, inner.marks.h),
				Font = Enum.Font.BuilderSans,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = COLORS.muted,
				Text = table.concat(marks, " · "),
			}, card) :: any) :: TextLabel
			footer.Name = "Marks"
			local picked = row.id
			local isGear = row.kind == "Weapon" or row.kind == "Armor"
			if gear ~= nil and isGear then
				-- Padlock: a gold closed lock while locked. Unlocked shows
				-- nothing, or a faint lock on hover. Same call as the
				-- detail pane.
				local lockedNow = row.locked == true
				local padlock = new("TextButton", {
					Name = "Padlock",
					Position = UDim2.fromOffset(inner.lock.x, inner.lock.y),
					Size = UDim2.fromOffset(inner.lock.w, inner.lock.h),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Font = Enum.Font.BuilderSansBold,
					TextSize = 15,
					TextColor3 = if lockedNow then COLORS.gold else COLORS.muted,
					TextTransparency = if lockedNow then 0 else 0.55,
					Text = "🔒",
					Visible = lockedNow,
					ZIndex = 3,
				}, card) :: TextButton
				padlock:SetAttribute("Locked", lockedNow)
				if not lockedNow then
					card.MouseEnter:Connect(function()
						padlock.Visible = true
					end)
					card.MouseLeave:Connect(function()
						padlock.Visible = false
					end)
					padlock.MouseEnter:Connect(function()
						padlock.Visible = true
					end)
				end
				padlock.MouseButton1Click:Connect(function()
					callbacks.onLock(picked, not lockedNow)
				end)
			end
			if gear ~= nil and gear.selecting() then
				-- Select mode: dim what cannot be picked and say why.
				local why = if isGear then gear.blockFor(picked) else "Not gear"
				if why ~= nil then
					card.BackgroundTransparency = 0.6
					nameLabel.TextTransparency = 0.55
					if art:IsA("ImageLabel") then
						art.ImageTransparency = 0.6
					elseif art:IsA("TextLabel") then
						art.TextTransparency = 0.6
					end
					footer.Text = why
				elseif gear.isSelected(picked) then
					card.BackgroundColor3 = Color3.fromRGB(92, 64, 34)
					new("UIStroke", {
						Name = "Picked",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 3,
						Color = COLORS.gold,
					}, card)
					footer.Text = "✓ Selected"
					footer.TextColor3 = COLORS.gold
				end
			end
			card.MouseButton1Click:Connect(function()
				if gear ~= nil and gear.selecting() then
					if not isGear then
						callbacks.onStatus("Only weapons and armor can be salvaged.", "error")
						return
					end
					local ok, why = gear.toggle(picked)
					if not ok and why ~= nil then
						callbacks.onStatus(string.format("Can't select: %s.", why), "error")
					end
					-- The detail panel follows the tap (desktop).
					if not phoneLayout() then
						selectedId = picked
					end
					render()
					return
				end
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
			fitBagText()
			return
		end
		-- [Ghost] Weapons and armor use the shared gear panel (icon, stats
		-- against the worn item, EQUIP / UPGRADE, padlock, Shard Core).
		-- Favorite, Salvage, Drop and Feed stay below it.
		local gearPanel = gear ~= nil
			and (selected.kind == "Weapon" or selected.kind == "Armor")
			and type(selected.item) == "table"
		if gearPanel then
			local gearItem = table.clone(selected.item)
			if type(gearItem.uid) ~= "string" then
				gearItem.uid = selected.id
			end
			local gearUid = gearItem.uid
			local built = GearDetail.build(detail, {
				profile = profile,
				item = gearItem,
				order = order,
				powerOf = InventoryView.powerOf,
				onEquip = function()
					callbacks.onEquip(gearUid)
				end,
				onUpgrade = function()
					local onUpgrade = callbacks.onUpgrade
					if onUpgrade == nil then
						callbacks.onStatus("Upgrade at the Forge.", "error")
						return
					end
					task.spawn(onUpgrade, gearUid)
				end,
				onLock = function(locked: boolean)
					callbacks.onLock(gearUid, locked)
				end,
				core = if callbacks.onCore ~= nil
					then {
						open = coreOpen,
						onToggle = function(open: boolean)
							coreOpen = open
						end,
						invoke = function(action: string, itemId: string): any
							local onCore = callbacks.onCore
							if onCore == nil then
								return { ok = false, error = "Shard Core is not available." }
							end
							local ok, answer = pcall(onCore, action, itemId)
							if not ok then
								return { ok = false, error = tostring(answer) }
							end
							return answer
						end,
						onFed = function(answer: any, fedUid: string)
							-- The feed answer carries the view, not the
							-- profile: mirror the two fields it changed.
							if type(latest) == "table" and type(answer) == "table" then
								if type(answer.essence) == "number" then
									latest.gearEssence = answer.essence
								end
								if type(answer.level) == "number" then
									if type(latest.shardCores) ~= "table" then
										latest.shardCores = {}
									end
									latest.shardCores[fedUid] = answer.level
								end
							end
							if isOpen then
								render()
							end
						end,
						onStatus = function(text: string, kind: string)
							callbacks.onStatus(text, kind)
						end,
					}
					else nil,
			})
			order = built.nextOrder
		end
		if not gearPanel then
			local name = label(detail, selected.name, order, rarityColor(selected.rarity), 18)
			name.Font = Enum.Font.BuilderSansBold
			order += 1
			if Rarities.isRainbow(selected.rarity) then
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
				local socketColor = COLORS.text
				if socketCue and selected.sockets >= 1 then
					socketColor = Color3.fromRGB(
						CodexCues.COLOR.socket[1],
						CodexCues.COLOR.socket[2],
						CodexCues.COLOR.socket[3]
					)
				end
				label(detail, string.format("Sockets  %d", selected.sockets), order, socketColor, 14)
				order += 1
			end
		end
		local item = selected.item
		if type(item) == "table" then
			if not gearPanel then
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
			end
			local canWear = selected.kind == "Weapon"
				or selected.kind == "Armor"
				or selected.kind == "Pet"
				or selected.kind == "Accessory"
			-- The gear panel has EQUIP; keep Unequip here for worn gear.
			if canWear and (not gearPanel or selected.equipped) then
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
			if not gearPanel then
				local lockButton = actionButton(
					detail,
					if gear ~= nil
						then (if selected.locked then "🔒 Unlock" else "🔓 Lock")
						elseif selected.locked then "Unlock"
						else "Lock",
					order,
					COLORS.buttonDim
				)
				order += 1
				lockButton.MouseButton1Click:Connect(function()
					callbacks.onLock(uid, not selected.locked)
				end)
			end
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
			if
				LaunchGate.on("forgeSalvage")
				and (selected.kind == "Weapon" or selected.kind == "Armor")
			then
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
			if LaunchGate.on("stars") and feeder ~= nil and type(feeder.uid) == "string" and (item.stars or 0) < Stars.MAX then
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

		if LaunchGate.on("forgeSalvage") and (query.tab == "weapons" or query.tab == "armor") then
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
		fitBagText()
	end

	for index, tab in ipairs(InventoryView.TABS) do
		local labelText = string.upper(string.sub(tab, 1, 1)) .. string.sub(tab, 2)
		local button = chip(tabBar, labelText, index)
		button.Name = "Tab_" .. tab
		button.Size = UDim2.fromOffset(120, 36)
		button.AutomaticSize = Enum.AutomaticSize.None
		tabButtons[tab] = button
		button.Visible = tab ~= "chests" or LaunchGate.on("chests")
		button.MouseButton1Click:Connect(function()
			if tab == "chests" and not LaunchGate.on("chests") then
				return
			end
			query.tab = tab
			query.slot = nil
			selectedId = nil
			if gear ~= nil then
				gear.closePopups()
			end
			render()
		end)
	end

	-- Tabs share the row evenly; short words when a tab gets narrow.
	local SHORT_TAB: { [string]: string } = { accessories = "Acc.", materials = "Mats" }
	fitTabs = function()
		local rowH = tabBar.Size.Y.Offset
		local shown: { string } = {}
		for _, tab in ipairs(InventoryView.TABS) do
			local button = tabButtons[tab]
			if button ~= nil and button.Visible then
				table.insert(shown, tab)
			end
		end
		local count = math.max(1, #shown)
		local w = math.min(120, math.floor((tabBar.Size.X.Offset - 6 * (count - 1)) / count))
		for _, tab in ipairs(shown) do
			local button = tabButtons[tab]
			button.Size = UDim2.fromOffset(math.max(40, w), rowH)
			local full = string.upper(string.sub(tab, 1, 1)) .. string.sub(tab, 2)
			button.Text = if w < 84 and SHORT_TAB[tab] ~= nil then SHORT_TAB[tab] else full
		end
	end

	-- ONE filter row: Search plus Rarity, Type and Sort dropdowns. The
	-- lists open on the modal root so the row never clips them.
	local function titleCase(text: string): string
		return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
	end
	local rarityOptions: { any } = { { value = nil, text = "All" } }
	for _, rarity in ipairs(Rarities.ORDER) do
		table.insert(rarityOptions, { value = rarity, text = rarity })
	end
	local function onlyRarity(): string?
		for _, rarity in ipairs(Rarities.ORDER) do
			if query.rarities[rarity] == true then
				return rarity
			end
		end
		return nil
	end
	local rarityPick = Dropdown.new(filterBar, {
		name = "RarityFilter",
		prefix = "Rarity",
		options = rarityOptions,
		value = nil,
		host = root,
		width = 150,
		height = 36,
		order = 2,
		colors = { button = COLORS.buttonDim, panel = COLORS.panel, text = COLORS.text, gold = COLORS.gold, ink = COLORS.ink },
		onChange = function(value: any)
			table.clear(query.rarities)
			if type(value) == "string" then
				query.rarities[value] = true
			end
			render()
		end,
	})
	local typePick = Dropdown.new(filterBar, {
		name = "TypeFilter",
		prefix = "Type",
		options = { { value = nil, text = "All" } },
		value = nil,
		host = root,
		width = 150,
		height = 36,
		order = 3,
		colors = { button = COLORS.buttonDim, panel = COLORS.panel, text = COLORS.text, gold = COLORS.gold, ink = COLORS.ink },
		onChange = function(value: any)
			query.slot = if type(value) == "string" then value else nil
			render()
		end,
	})
	local sortOptions: { any } = {}
	for _, name in ipairs(InventoryView.SORTS) do
		table.insert(sortOptions, { value = name, text = titleCase(name) })
	end
	local sortPick = Dropdown.new(filterBar, {
		name = "SortFilter",
		prefix = "Sort",
		options = sortOptions,
		value = query.sort,
		host = root,
		width = 150,
		height = 36,
		order = 4,
		colors = { button = COLORS.buttonDim, panel = COLORS.panel, text = COLORS.text, gold = COLORS.gold, ink = COLORS.ink },
		onChange = function(value: any)
			if type(value) == "string" then
				query.sort = value
			end
			render()
		end,
	})
	local filterPicks = { rarityPick, typePick, sortPick }
	local typeTab: string? = nil

	fitFilters = function()
		local rowH = filterBar.Size.Y.Offset
		local fw = filterBar.Size.X.Offset
		local shown = {}
		for _, pick in ipairs(filterPicks) do
			if pick.button.Visible then
				table.insert(shown, pick)
			end
		end
		local count = #shown
		local dropW = 0
		if count > 0 then
			dropW = math.clamp(math.floor((fw - 6 * count) / (count + 1.4)), 96, 180)
		end
		local searchW = math.min(340, fw - count * (dropW + 6))
		if searchW < 110 and count > 0 then
			searchW = 110
			dropW = math.floor((fw - searchW - 6 * count) / count)
		end
		search.Size = UDim2.fromOffset(searchW, rowH)
		for _, pick in ipairs(shown) do
			pick.setWidth(dropW, rowH)
		end
	end

	paintFilters = function()
		local flags = InventoryView.activeFilters(query.tab)
		-- The old realm, socket, worn and lock chips are gone; those query
		-- fields stay at "all".
		query.realm = nil
		query.sockets = nil
		query.socketsAtLeast = nil
		query.equipped = "all"
		query.locked = "all"
		if not flags.slot then
			query.slot = nil
		end
		if not flags.rarity then
			table.clear(query.rarities)
		end
		rarityPick.button.Visible = flags.rarity
		typePick.button.Visible = flags.slot
		sortPick.button.Visible = flags.sort
		if typeTab ~= query.tab then
			typeTab = query.tab
			local options: { any } = { { value = nil, text = "All" } }
			for _, slot in ipairs(InventoryView.slotChoices(query.tab)) do
				table.insert(options, { value = slot, text = InventoryView.slotLabel(slot) })
			end
			typePick.setOptions(options)
		end
		rarityPick.set(onlyRarity())
		typePick.set(query.slot)
		sortPick.set(query.sort)
		local fit = fitFilters
		if fit ~= nil then
			fit()
		end
	end

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
	expand.MouseButton1Click:Connect(function()
		if devOwner then
			callbacks.onExpand()
		end
	end)
	-- Equip Best (moved here from the small Bag): the same picks the Bag
	-- used, one equip call each.
	equipBest.MouseButton1Click:Connect(function()
		local uids = HubStyle.bestGear(latest)
		if #uids == 0 then
			callbacks.onStatus("Your best gear is already equipped.", "info")
			return
		end
		for _, uid in ipairs(uids) do
			callbacks.onEquip(uid)
		end
	end)

	local function setOpen(open: boolean)
		if isOpen == open then
			root.Visible = open
			openButton.Visible = false
			return
		end
		isOpen = open
		root.Visible = open
		openButton.Visible = false
		if not open and gear ~= nil then
			gear.closePopups()
		end
		Dropdown.closeAll(root)
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
		if socketCue then
			local pulse = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 6))
			for _, child in ipairs(grid:GetChildren()) do
				local glow = child:FindFirstChild("SocketGlow")
				if glow ~= nil and glow:IsA("UIStroke") then
					glow.Transparency = pulse
				end
			end
		end
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
		bagScale = 1
		if type(profile) == "table" then
			local settings = profile.uiSettings
			if type(settings) == "table" then
				local access = settings.access
				if type(access) == "table" and access.textScale ~= nil then
					bagScale = access.textScale
				end
			end
		end
		if isOpen then
			render()
		end
		fitBagText()
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
		if tab == "chests" and not LaunchGate.on("chests") then
			return
		end
		query.tab = tab
		paintFilters()
		if isOpen then
			render()
			return
		end
		setOpen(true)
	end

	paintFilters()
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Remotes", 15)
		if folder == nil then
			return
		end
		local remote = folder:WaitForChild("CombatFx", 15)
		if remote == nil or not remote:IsA("RemoteEvent") then
			return
		end
		remote.OnClientEvent:Connect(function(payload)
			local cue = CodexCues.accept(payload)
			if cue.ok ~= true then
				return
			end
			local nextCue = cue.shards == true
			if nextCue == socketCue then
				return
			end
			socketCue = nextCue
			if isOpen then
				render()
			end
		end)
	end)
	return controller
end

return InventoryHud
