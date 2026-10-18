--!strict

--[[
	Menu sheet for shards, the forge, and the dungeon. It stays closed until
	Menu, a Haven stall, or a chest shortcut opens it. The bag itself lives
	on the Inventory screen (the action bar and the I key).

	The panel stays short on purpose: stats, a pity line that counts up, and
	one Shard Token crack. Odds is a labeled button above the Prism Token
	buttons. Saving is a badge, not a paragraph. Studio dev grants sit in a
	collapsed section and only exist when the dev gate is on.

	Armory and Pets are the roll areas. Each one lists realms, and a realm
	above the player's ascension stays locked. The client sends the selected
	pool id.

	Shards and Craft are tabs. Rootvault sits under them: Enter, Attack, Auto
	Attack, and a Healing Tonic button. Auto Attack defaults on. The server
	still owns the rolls, the hits, and the craft. Feed spends a duplicate
	into the kept copy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MobileShell = require(script.Parent.MobileShell)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))
local BannerFit = require(Shared:WaitForChild("BannerFit"))
local Areas = require(Shared:WaitForChild("Areas"))
local Audio = require(Shared:WaitForChild("Audio"))
local Crafting = require(Shared:WaitForChild("Crafting"))
local CraftingLevel = require(Shared:WaitForChild("CraftingLevel"))
local Currencies = require(Shared:WaitForChild("Currencies"))
local Dungeons = require(Shared:WaitForChild("Dungeons"))
local InventoryStacks = require(Shared:WaitForChild("InventoryStacks"))
local LaunchGate = require(Shared:WaitForChild("LaunchGate"))
local Materials = require(Shared:WaitForChild("Materials"))
local Pools = require(Shared:WaitForChild("Pools"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local Recipes = require(Shared:WaitForChild("Recipes"))
local RollMath = require(Shared:WaitForChild("RollMath"))
local Stats = require(Shared:WaitForChild("Stats"))
local TextFit = require(Shared:WaitForChild("TextFit"))

local Ui = {}

export type Callbacks = {
	showDev: boolean,
	onCrack: () -> (),
	onPaid: () -> (),
	onBuyPrism: () -> (),
	onBuyBoost: () -> (),
	onDev: (kind: string) -> (),
	onArea: (poolId: string) -> (),
	onCraft: (recipeId: string, targetUid: string?) -> (),
	onSalvage: (uid: string) -> (),
	onBuyForge: () -> (),
	onDungeon: (action: string, dungeonId: string?) -> (),
	onTonic: () -> (),
	onAttack: () -> (),
	onAutoAttack: (enabled: boolean) -> (),
	onAutoFarm: (enabled: boolean) -> (),
	onAudio: (music: number, sfx: number, commit: boolean) -> (),
	onChests: (() -> ())?,
	onGraphics: (() -> ())?,
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
	if height < 44 then
		height = 44
	end
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
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 18,
	}, playerGui) :: ScreenGui
	MobileShell.mount(screen)

	local toast = new("TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.32, 0, 0, 12),
		Size = UDim2.new(0.46, 0, 0, 44),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = COLORS.text,
		Text = "",
		Visible = false,
		ZIndex = 30,
	}, screen) :: TextLabel
	corner(toast, 8)

	local bannerGui = new("ScreenGui", {
		Name = "ShardfallBanner",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	local banner = new("TextLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(200, 32),
		BackgroundColor3 = COLORS.gold,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextScaled = false,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = COLORS.ink,
		Text = "",
		Visible = false,
		Active = false,
		ZIndex = 20,
	}, bannerGui) :: TextLabel
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, banner)
	corner(banner, 8)
	local bannerToken = 0
	-- Nil until setProfile reads uiSettings.access.textScale. BannerFit treats that as 16px.
	local bannerScale: any = nil
	local function applyBannerFit()
		local size = bannerGui.AbsoluteSize
		local vx = size.X
		local vy = size.Y
		if vx < 200 or vy < 200 then
			vx, vy = MobileShell.view(screen)
		end
		local box = BannerFit.fit(vx, vy, bannerScale)
		banner.Position = UDim2.fromOffset(box.x, box.y)
		banner.Size = UDim2.fromOffset(box.w, box.h)
		banner.TextSize = box.textSize
	end
	applyBannerFit()
	bannerGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyBannerFit)
	local bannerCamera = workspace.CurrentCamera
	if bannerCamera ~= nil then
		bannerCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyBannerFit)
	end
	local function showBanner(text: string, kind: string, hold: boolean?)
		bannerToken += 1
		local token = bannerToken
		local shown = if type(text) == "string"
			then string.match(text, "^%s*(.-)%s*$") or ""
			else ""
		local changed = banner.Text ~= shown or banner.Visible ~= (shown ~= "")
		banner.Text = shown
		banner.Visible = shown ~= ""
		if shown == "" then
			return
		end
		local background = COLORS.gold
		local ink = COLORS.ink
		if kind == "error" then
			background = COLORS.danger
			ink = COLORS.text
		elseif kind == "ok" then
			background = COLORS.ok
		end
		banner.BackgroundColor3 = background
		banner.TextColor3 = ink
		applyBannerFit()
		if hold == true then
			if changed then
				print("[Toast] shown " .. shown)
			end
			return
		end
		if changed then
			print("[Toast] shown " .. shown)
		end
		task.delay(ShellLayout.BANNER_SECONDS, function()
			if token ~= bannerToken then
				return
			end
			banner.Visible = false
			banner.Text = ""
		end)
	end

	local panel = new("ScrollingFrame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 140),
		Size = UDim2.fromOffset(320, 480),
		BackgroundColor3 = COLORS.background,
		BorderSizePixel = 0,
		Visible = false,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Active = true,
	}, screen) :: ScrollingFrame
	corner(panel, 12)
	padding(panel, 12)
	local function fitPanel()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.menuRect(vx, vy)
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
	end
	fitPanel()
	local fitCamera = workspace.CurrentCamera
	if fitCamera ~= nil then
		fitCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
	list(panel, 8)
	new("UIStroke", {
		Color = COLORS.stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, panel)

	local header = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, ShellLayout.TITLE_ROW + ShellLayout.HIDE_ROW),
		LayoutOrder = 1,
	}, panel) :: Frame
	new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ShellLayout.TITLE_ROW),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = COLORS.gold,
		Text = "SHARDFALL",
	}, header)
	local minimize = new("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(72, 40),
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextColor3 = COLORS.text,
		Text = "Hide",
		AutoButtonColor = true,
	}, header) :: TextButton
	corner(minimize, 8)
	local restore = new("TextButton", {
		Name = "ShowPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = COLORS.button,
		BorderSizePixel = 0,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 16,
		TextColor3 = COLORS.text,
		Text = "SHARDFALL",
		AutoButtonColor = true,
		Visible = false,
	}, screen) :: TextButton
	corner(restore, 8)
	local userOpen = false
	local covered = false
	local function applyChrome()
		panel.Visible = userOpen and not covered
		restore.Visible = false
	end
	applyChrome()
	minimize.MouseButton1Click:Connect(function()
		userOpen = false
		applyChrome()
	end)
	restore.MouseButton1Click:Connect(function()
		userOpen = true
		applyChrome()
	end)

	local saveBadge = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(120, 40),
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
		LayoutOrder = 23,
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

	local page = "shards"
	local applyPage: () -> ()
	local selectedRecipe = "briar_edge"
	local selectedTarget: string? = nil
	local runState: any = { active = false }

	local tabRow = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
	}, panel) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, tabRow)
	local shardTab = makeButton(tabRow, "Shards", COLORS.gold, 1, 28)
	shardTab.Size = UDim2.new(0.5, -3, 1, 0)
	shardTab.TextSize = 14
	local craftTab = makeButton(tabRow, "Craft", COLORS.buttonDim, 2, 28)
	craftTab.Size = UDim2.new(0.5, -3, 1, 0)
	craftTab.TextSize = 14

	local dungeonBar = new("Frame", {
		Name = "Dungeon",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 250),
		LayoutOrder = 3,
	}, panel) :: Frame
	local runLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 0, 28),
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "Hub.",
	}, dungeonBar) :: TextLabel
	local dungeonActions = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 44),
		BorderSizePixel = 0,
	}, dungeonBar) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, dungeonActions)
	local enterButton = makeButton(dungeonActions, "Enter Rootvault", COLORS.button, 1, 30)
	enterButton.Size = UDim2.fromScale(0.42, 1)
	enterButton.TextSize = 13
	local attackButton = makeButton(dungeonActions, "Attack", COLORS.buttonDim, 2, 30)
	attackButton.Size = UDim2.new(0.28, -6, 1, 0)
	attackButton.TextSize = 13
	local tonicButton = makeButton(dungeonActions, "Tonic", COLORS.buttonDim, 3, 30)
	tonicButton.Size = UDim2.new(0.3, -6, 1, 0)
	tonicButton.TextSize = 13
	local leaveButton = makeButton(dungeonBar, "Leave", COLORS.buttonDim, 4, 24)
	leaveButton.Position = UDim2.fromOffset(0, 0)
	leaveButton.Size = UDim2.fromOffset(0, 0)
	leaveButton.Visible = false
	leaveButton.TextSize = 12
	local wavesButton = makeButton(dungeonBar, "Rootvault Waves", COLORS.button, 6, 26)
	wavesButton.Position = UDim2.fromOffset(0, 82)
	wavesButton.Size = UDim2.new(1, 0, 0, 44)
	wavesButton.TextSize = 13
	local waveAt = 0
	local function pressWaves()
		local now = os.clock()
		if now - waveAt < 0.4 then
			return
		end
		waveAt = now
		if runState.active == true then
			showBanner("Leave this run before starting Rootvault Waves.", "error")
			return
		end
		showBanner("Entering Rootvault Waves…", "info")
		callbacks.onDungeon("enter", "rootvault_waves")
	end
	wavesButton.MouseButton1Click:Connect(pressWaves)
	wavesButton.Activated:Connect(pressWaves)

	local function paintDungeon()
		local note = if type(runState.note) == "string"
			then runState.note
			else Dungeons.progressNote(0) or ""
		local countdown = ""
		if type(runState.countdown) == "number" and runState.countdown > 0 then
			countdown = string.format("  ·  next in %ds", runState.countdown)
		end
		if runState.active == true then
			local phaseNote = ""
			if runState.boss == true and runState.phase == 2 then
				phaseNote = "  ·  stand in the sunbeam"
			elseif runState.boss == true then
				phaseNote = "  ·  hit during the gold weak spot"
			end
			local remaining = runState.remaining or 0
			if runState.endless == true then
				runLabel.Text = string.format(
					"%s  ·  Wave %d  ·  %d left%s%s",
					tostring(runState.dungeonName or "Waves"),
					runState.wave or runState.roomIndex or 1,
					remaining,
					phaseNote,
					countdown
				)
				enterButton.Text = if runState.cleared == true then "Next wave" else "Fighting"
			else
				runLabel.Text = string.format(
					"%s  ·  %s (%d/%d)  ·  %d left%s%s",
					tostring(runState.dungeonName or "Rootvault"),
					tostring(runState.roomName or "Room"),
					runState.roomIndex or 1,
					runState.roomCount or 1,
					remaining,
					phaseNote,
					countdown
				)
				enterButton.Text = if runState.cleared == true then "Next room" else "Fighting"
			end
			enterButton.Active = runState.cleared == true
			enterButton.AutoButtonColor = runState.cleared == true
			enterButton.BackgroundColor3 = if runState.cleared == true
				then COLORS.button
				else COLORS.buttonDim
			wavesButton.Active = false
			wavesButton.AutoButtonColor = false
			wavesButton.Text = "Rootvault Waves"
			leaveButton.Visible = true
			leaveButton.Size = UDim2.fromOffset(96, 44)
			leaveButton.Position = UDim2.new(1, -96, 0, 0)
		else
			runLabel.Text = if note ~= ""
				then "Hub.  " .. note
				else "Hub. Click to attack once you are inside."
			enterButton.Text = "Enter Rootvault"
			enterButton.Active = true
			enterButton.AutoButtonColor = true
			enterButton.BackgroundColor3 = COLORS.button
			wavesButton.Active = true
			wavesButton.AutoButtonColor = true
			wavesButton.Text = "Rootvault Waves"
			leaveButton.Visible = false
		end
	end
	paintDungeon()

	enterButton.MouseButton1Click:Connect(function()
		if runState.active == true then
			if runState.cleared == true then
				callbacks.onDungeon("advance")
			end
			return
		end
		callbacks.onDungeon("enter", "rootvault")
	end)
	leaveButton.MouseButton1Click:Connect(function()
		callbacks.onDungeon("leave")
	end)
	attackButton.MouseButton1Click:Connect(function()
		callbacks.onAttack()
	end)
	tonicButton.MouseButton1Click:Connect(function()
		callbacks.onTonic()
	end)

	local autoEnabled = true
	local autoButton = makeButton(dungeonBar, "Auto Attack: On", COLORS.gold, 5, 26)
	autoButton.Position = UDim2.fromOffset(0, 132)
	autoButton.Size = UDim2.new(1, 0, 0, 44)
	autoButton.TextSize = 13
	autoButton.TextColor3 = COLORS.ink
	local function paintAuto()
		autoButton.Text = if autoEnabled then "Auto Attack: On" else "Auto Attack: Off"
		autoButton.BackgroundColor3 = if autoEnabled then COLORS.gold else COLORS.buttonDim
		autoButton.TextColor3 = if autoEnabled then COLORS.ink else COLORS.text
	end
	autoButton.MouseButton1Click:Connect(function()
		autoEnabled = not autoEnabled
		paintAuto()
		callbacks.onAutoAttack(autoEnabled)
	end)

	local farmEnabled = false
	local farmButton = makeButton(dungeonBar, "Auto Farm: Off", COLORS.buttonDim, 7, 26)
	farmButton.Position = UDim2.fromOffset(0, 182)
	farmButton.Size = UDim2.new(1, 0, 0, 44)
	farmButton.TextSize = 13
	local function paintFarm()
		farmButton.Text = if farmEnabled then "Auto Farm: On" else "Auto Farm: Off"
		farmButton.BackgroundColor3 = if farmEnabled then COLORS.gold else COLORS.buttonDim
		farmButton.TextColor3 = if farmEnabled then COLORS.ink else COLORS.text
	end
	farmButton.MouseButton1Click:Connect(function()
		farmEnabled = not farmEnabled
		paintFarm()
		callbacks.onAutoFarm(farmEnabled)
	end)

	local stats = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		-- Two wrapped lines. AutomaticSize grows past 36 when the slider does.
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.text,
		Text = "",
		TextWrapped = true,
		LayoutOrder = 4,
	}, panel) :: TextLabel

	local pityLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.muted,
		Text = RarityConfig.pityLine(0, 0),
		LayoutOrder = 5,
	}, panel) :: TextLabel

	local pityTrack = new("Frame", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 6,
	}, panel) :: Frame
	corner(pityTrack, 4)
	local pityFill = new("Frame", {
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, pityTrack) :: Frame
	corner(pityFill, 4)

	local areas = Areas.all()
	local selectedArea: any = areas[1]
	local selectedPool: any = if selectedArea ~= nil then Areas.pools(selectedArea.id)[1] else nil
	local latestProfile: any = nil

	local areaRow = new("Frame", {
		Name = "Areas",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, if #areas > 1 then 44 else 0),
		Visible = #areas > 1,
		LayoutOrder = 7,
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
			chip.Size = UDim2.fromOffset(0, 44)
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

	local function fitLegacyText()
		-- Shardfall panel text. A missing bannerScale is 1 inside TextFit.px.
		-- BaseHeight is the design row height. The walk sets that height from
		-- TextFit.px so a later scale change still fits the line.
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
				desc.TextSize = TextFit.px(base, bannerScale)
				local rowBase = desc:GetAttribute("BaseHeight")
				if type(rowBase) == "number" then
					desc.Size = UDim2.new(1, 0, 0, TextFit.px(rowBase, bannerScale))
				end
			end
		end
	end

	local function paintChips()
		for _, chip in ipairs(chips) do
			local active = selectedArea ~= nil and chip.area.id == selectedArea.id
			chip.button.BackgroundColor3 = if active then COLORS.gold else COLORS.buttonDim
			chip.button.TextColor3 = if active then COLORS.ink else COLORS.text
		end
		fitLegacyText()
	end

	local realmRow = new("Frame", {
		Name = "Realms",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 8,
	}, panel) :: Frame

	local realmNext = new("TextLabel", {
		Name = "NextRealm",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = COLORS.muted,
		Text = "",
		Visible = false,
		LayoutOrder = 9,
	}, panel) :: TextLabel
	realmNext:SetAttribute("BaseHeight", 16)

	local crack = makeButton(panel, "Crack a Shard", COLORS.gold, 10, 44)
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
		LayoutOrder = 11,
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
		LayoutOrder = 12,
	}, panel) :: TextLabel

	local actions = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 13,
	}, panel) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, actions)
	local viewOdds = makeButton(actions, "Odds", COLORS.button, 1, 30)
	viewOdds.Size = UDim2.fromScale(1, 1)
	viewOdds.TextSize = 14
	viewOdds.Font = Enum.Font.BuilderSansBold

	local oddsWrap = new("Frame", {
		Name = "Odds",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 14,
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
		viewOdds.Text = if open then "Hide odds" else "Odds"
	end
	viewOdds.MouseButton1Click:Connect(function()
		setOddsOpen(not oddsOpen)
	end)

	local paidFrame = new("Frame", {
		Name = "Paid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 15,
	}, panel) :: Frame
	list(paidFrame, 6)
	local paidNote = new("TextLabel", {
		Name = "PaidNote",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "Shard Tokens are earned. Prism Tokens are bought with Robux.",
		LayoutOrder = 1,
	}, paidFrame) :: TextLabel
	local regionLabel = new("TextLabel", {
		Name = "Region",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.danger,
		Text = "Checking purchase policy...",
		Visible = true,
		LayoutOrder = 2,
	}, paidFrame) :: TextLabel
	local prismButton = makeButton(paidFrame, "Crack (Prism Token)", COLORS.gold, 3, 32)
	prismButton.TextSize = 14
	prismButton.TextColor3 = COLORS.ink
	prismButton.Visible = false
	local buyPrism = makeButton(paidFrame, "Buy Prism Tokens", COLORS.buttonDim, 4, 30)
	buyPrism.TextSize = 13
	buyPrism.Visible = false
	local boostLabel = new("TextLabel", {
		Name = "BoostPitch",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.gold,
		Text = "",
		Visible = false,
		LayoutOrder = 5,
	}, paidFrame) :: TextLabel
	local buyBoost = makeButton(paidFrame, "Buy Luck Boost", COLORS.buttonDim, 6, 30)
	buyBoost.TextSize = 13
	buyBoost.Visible = false
	prismButton.MouseButton1Click:Connect(callbacks.onPaid)
	buyPrism.MouseButton1Click:Connect(callbacks.onBuyPrism)
	buyBoost.MouseButton1Click:Connect(callbacks.onBuyBoost)

	local loadout = new("TextLabel", {
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 78),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.BuilderSans,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = COLORS.text,
		Text = "Weapon   None\nPet   None\nArmor   None\nBonus   None",
		LayoutOrder = 16,
	}, panel) :: TextLabel
	corner(loadout, 8)
	padding(loadout, 8)

	local musicValue = Audio.DEFAULT_MUSIC
	local sfxValue = Audio.DEFAULT_SFX
	local audioBlock = new("Frame", {
		Name = "Audio",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 18,
	}, panel) :: Frame
	corner(audioBlock, 8)
	padding(audioBlock, 8)
	list(audioBlock, 6)
	local audioTitle = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "Audio",
		LayoutOrder = 1,
	}, audioBlock) :: TextLabel
	audioTitle.Name = "AudioTitle"

	local function volumeRow(
		title: string,
		order: number,
		current: () -> number,
		apply: (number, boolean) -> ()
	): (number) -> ()
		local row = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 64),
			LayoutOrder = order,
		}, audioBlock) :: Frame
		local caption = new("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Font = Enum.Font.BuilderSansMedium,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = COLORS.text,
			Text = title,
		}, row) :: TextLabel
		local track = new("TextButton", {
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = COLORS.buttonDim,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, row) :: TextButton
		corner(track, 8)
		local fill = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = COLORS.gold,
			BorderSizePixel = 0,
		}, track) :: Frame
		corner(fill, 8)
		local dragging = false
		local function paint(volume: number)
			local shown = Audio.clampVolume(volume)
			fill.Size = UDim2.fromScale(shown, 1)
			caption.Text = string.format("%s  %d%%", title, math.floor(shown * 100 + 0.5))
		end
		local function readInput(input: InputObject): number
			local width = track.AbsoluteSize.X
			if width < 1 then
				return current()
			end
			return Audio.clampVolume((input.Position.X - track.AbsolutePosition.X) / width)
		end
		local function push(input: InputObject, commit: boolean)
			local volume = readInput(input)
			paint(volume)
			apply(volume, commit)
		end
		track.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			push(input, false)
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
				return
			end
			push(input, false)
		end)
		UserInputService.InputEnded:Connect(function(input)
			if not dragging then
				return
			end
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			dragging = false
			push(input, true)
		end)
		paint(current())
		return function(volume: number)
			if dragging then
				return
			end
			paint(volume)
		end
	end

	local paintMusic = volumeRow("Music", 2, function()
		return musicValue
	end, function(volume: number, commit: boolean)
		musicValue = volume
		callbacks.onAudio(musicValue, sfxValue, commit)
	end)
	local paintSfx = volumeRow("SFX", 3, function()
		return sfxValue
	end, function(volume: number, commit: boolean)
		sfxValue = volume
		callbacks.onAudio(musicValue, sfxValue, commit)
	end)

	local inventoryNote = new("TextLabel", {
		Name = "InventoryNote",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Font = Enum.Font.BuilderSans,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "Bag, materials, and tonics are on Items, or press I.",
		LayoutOrder = 17,
	}, panel)
	local graphicsButton: TextButton? = nil
	if callbacks.onChests ~= nil then
		local chests = makeButton(panel, "Chests", COLORS.button, 21, 44)
		local openChests = callbacks.onChests
		chests.MouseButton1Click:Connect(function()
			openChests()
		end)
	end
	if callbacks.onGraphics ~= nil then
		graphicsButton = makeButton(panel, "Graphics", COLORS.buttonDim, 22, 44)
		local cycle = callbacks.onGraphics
		graphicsButton.MouseButton1Click:Connect(function()
			cycle()
		end)
	end

	local devToggle: TextButton? = nil
	local devBody: Frame? = nil
	local restrictButton: TextButton? = nil
	if callbacks.showDev then
		devToggle = makeButton(panel, "Dev", COLORS.buttonDim, 19, 28)
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
			LayoutOrder = 20,
		}, panel) :: Frame
		list(devBody, 6)
		local grantTokens = makeButton(devBody, "+5 Shard Tokens", COLORS.buttonDim, 1, 30)
		grantTokens.TextSize = 14
		grantTokens.MouseButton1Click:Connect(function()
			callbacks.onDev("tokens")
		end)
		local grantLuck = makeButton(devBody, "+25 Shard Luck", COLORS.buttonDim, 2, 30)
		grantLuck.TextSize = 14
		grantLuck.MouseButton1Click:Connect(function()
			callbacks.onDev("luck")
		end)
		local grantAscension = makeButton(devBody, "+1 Ascension", COLORS.buttonDim, 3, 30)
		grantAscension.TextSize = 14
		grantAscension.MouseButton1Click:Connect(function()
			callbacks.onDev("ascension")
		end)
		local grantMaterials = makeButton(devBody, "+ craft materials", COLORS.buttonDim, 4, 30)
		local grantChests = makeButton(devBody, "Grant chests", COLORS.buttonDim, 10, 30)
		grantChests.TextSize = 14
		grantChests.MouseButton1Click:Connect(function()
			callbacks.onDev("chests")
		end)
		local grantForge = makeButton(devBody, "Forge Boost 1h", COLORS.buttonDim, 9, 30)
		grantForge.TextSize = 14
		grantForge.MouseButton1Click:Connect(function()
			callbacks.onDev("forgeboost")
		end)
		grantMaterials.TextSize = 14
		grantMaterials.MouseButton1Click:Connect(function()
			callbacks.onDev("materials")
		end)
		local grantPrisms = makeButton(devBody, "+5 Prism Tokens", COLORS.buttonDim, 5, 30)
		grantPrisms.TextSize = 14
		grantPrisms.MouseButton1Click:Connect(function()
			callbacks.onDev("prisms")
		end)
		local grantBoost = makeButton(devBody, "Apply +25 Luck Boost", COLORS.buttonDim, 6, 30)
		grantBoost.TextSize = 14
		grantBoost.MouseButton1Click:Connect(function()
			callbacks.onDev("boost")
		end)
		local regionToggle =
			makeButton(devBody, "Simulate restricted region", COLORS.buttonDim, 7, 30)
		restrictButton = regionToggle
		regionToggle.TextSize = 14
		regionToggle.MouseButton1Click:Connect(function()
			callbacks.onDev("restrict")
		end)
		local skipBoss = makeButton(devBody, "Skip to Rootvault boss", COLORS.buttonDim, 8, 30)
		skipBoss.TextSize = 14
		skipBoss.MouseButton1Click:Connect(function()
			callbacks.onDungeon("skip")
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

	local craftPage = new("Frame", {
		Name = "Craft",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 3,
	}, panel) :: Frame
	list(craftPage, 8)
	new("TextLabel", {
		Name = "ForgeTitle",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "FORGE",
		LayoutOrder = 0,
	}, craftPage)
	local craftHint = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.gold,
		Text = "Crafting Level 1",
		LayoutOrder = 1,
	}, craftPage) :: TextLabel
	local xpTrack = new("Frame", {
		BackgroundColor3 = COLORS.buttonDim,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
		LayoutOrder = 2,
	}, craftPage) :: Frame
	corner(xpTrack, 4)
	local xpFill = new("Frame", {
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, xpTrack) :: Frame
	corner(xpFill, 4)
	local forgeNote = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.BuilderSans,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = COLORS.muted,
		Text = "",
		LayoutOrder = 3,
	}, craftPage) :: TextLabel
	local forgeBoostButton = makeButton(craftPage, "Forge Boost", COLORS.buttonDim, 4, 26)
	forgeBoostButton.TextSize = 13
	forgeBoostButton.MouseButton1Click:Connect(callbacks.onBuyForge)
	local forgeTabs = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 5,
	}, craftPage) :: Frame
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, forgeTabs)
	local forgeTab = "craft"
	local craftTabButton = makeButton(forgeTabs, "Craft", COLORS.gold, 1, 26)
	craftTabButton.Size = UDim2.new(1 / 3, -4, 1, 0)
	craftTabButton.TextSize = 13
	local salvageTabButton = makeButton(forgeTabs, "Salvage", COLORS.buttonDim, 2, 26)
	salvageTabButton.Size = UDim2.new(1 / 3, -4, 1, 0)
	salvageTabButton.TextSize = 13
	salvageTabButton.Visible = LaunchGate.on("forgeSalvage")
	local materialTabButton = makeButton(forgeTabs, "Materials", COLORS.buttonDim, 3, 26)
	materialTabButton.Size = UDim2.new(1 / 3, -4, 1, 0)
	materialTabButton.TextSize = 13
	local craftList = new("Frame", {
		Name = "Recipes",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
	}, craftPage) :: Frame
	list(craftList, 8)
	local salvageList = new("Frame", {
		Name = "Salvage",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 7,
	}, craftPage) :: Frame
	list(salvageList, 8)
	local materialList = new("Frame", {
		Name = "Materials",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 8,
	}, craftPage) :: Frame
	list(materialList, 6)

	local popup = new("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
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
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
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
	local prismTokens = 0
	local luckBoost = 0
	local profileLoaded = false
	local policyState = {
		ready = false,
		paidRolls = false,
		simulated = false,
		message = "Checking purchase policy...",
	}
	local controller = {}

	local function paintTabs()
		local shards = page == "shards"
		shardTab.BackgroundColor3 = if shards then COLORS.gold else COLORS.buttonDim
		shardTab.TextColor3 = if shards then COLORS.ink else COLORS.text
		craftTab.BackgroundColor3 = if shards then COLORS.buttonDim else COLORS.gold
		craftTab.TextColor3 = if shards then COLORS.text else COLORS.ink
	end

	applyPage = function()
		local shards = page == "shards"
		paintTabs()
		pityLabel.Visible = shards
		pityTrack.Visible = shards
		areaRow.Visible = shards and #areas > 1
		realmRow.Visible = shards
		realmNext.Visible = shards and realmNext.Text ~= ""
		crack.Visible = shards
		actions.Visible = shards
		paidFrame.Visible = shards
		oddsWrap.Visible = shards and oddsOpen
		loadout.Visible = shards
		inventoryNote.Visible = shards
		craftPage.Visible = not shards
		dungeonBar.Visible = shards
		if not shards then
			panel.CanvasPosition = Vector2.zero
		end
		tokenHint.Visible = shards and profileLoaded and tokens < 1 and not busy
	end

	shardTab.MouseButton1Click:Connect(function()
		page = "shards"
		applyPage()
	end)
	craftTab.MouseButton1Click:Connect(function()
		page = "craft"
		applyPage()
	end)

	local function paintPaid()
		local showPaid = RarityConfig.PAID_LUCK_ENABLED and policyState.paidRolls == true
		regionLabel.Visible = not showPaid
		local regionText = RarityConfig.REGION_MESSAGE
		if not RarityConfig.PAID_LUCK_ENABLED then
			regionText = RarityConfig.PAID_OFF_MESSAGE
		elseif policyState.ready ~= true and type(policyState.message) == "string" then
			regionText = policyState.message
		end
		regionLabel.Text = regionText
		prismButton.Visible = showPaid
		buyPrism.Visible = showPaid
		boostLabel.Visible = showPaid
		buyBoost.Visible = showPaid
		paidNote.Text = "Shard Tokens are earned. Prism Tokens are bought with Robux."
		boostLabel.Text = Currencies.boostPitch(luckBoost)
		buyPrism.Text = string.format(
			"Buy %d Prism · %d Robux",
			Currencies.PRISM_PACK_TOKENS,
			Currencies.PRISM_PACK_ROBUX
		)
		local prismReady = showPaid and prismTokens > 0 and not busy
		prismButton.Active = prismReady
		prismButton.AutoButtonColor = prismReady
		prismButton.Text = if busy then "Cracking..." else "Crack (Prism Token)"
		prismButton.BackgroundColor3 = if prismReady then COLORS.gold else COLORS.buttonDim
		prismButton.TextColor3 = if prismReady then COLORS.ink else COLORS.muted
		if restrictButton ~= nil then
			restrictButton.Text = if policyState.simulated == true
				then "Clear restricted region"
				else "Simulate restricted region"
		end
	end

	local function paintCrack()
		local ready = tokens > 0 and not busy
		crack.Active = ready
		crack.AutoButtonColor = ready
		crack.Text = if busy then "Cracking..." else "Crack (Shard Token)"
		crack.BackgroundColor3 = if ready then COLORS.gold else COLORS.buttonDim
		crack.TextColor3 = if ready then COLORS.ink else COLORS.muted
		if page == "shards" then
			tokenHint.Text = "Not enough Shard Tokens."
			tokenHint.Visible = profileLoaded and tokens < 1 and not busy
		end
		paintPaid()
	end

	crack.MouseButton1Click:Connect(function()
		if busy or tokens < 1 then
			return
		end
		callbacks.onCrack()
	end)

	local function playerAscension(): number
		if type(latestProfile) ~= "table" then
			return 0
		end
		local level = latestProfile.ascension
		if type(level) ~= "number" then
			return 0
		end
		return level
	end

	local function renderPity(profile: any)
		local epic = 0
		local legendary = 0
		if type(profile) == "table" then
			if type(profile.sinceEpic) == "number" then
				epic = profile.sinceEpic
			end
			if type(profile.sinceLegendary) == "number" then
				legendary = profile.sinceLegendary
			end
		end
		pityLabel.Text = RarityConfig.pityLine(epic, legendary)
		local ratio = 0
		if RarityConfig.LEGENDARY_PITY > 0 then
			ratio = math.clamp(legendary / RarityConfig.LEGENDARY_PITY, 0, 1)
		end
		pityFill.Size = UDim2.fromScale(ratio, 1)
		fitLegacyText()
	end

	local function paintRealms()
		for _, child in ipairs(realmRow:GetChildren()) do
			child:Destroy()
		end
		local pools = if selectedArea ~= nil then Areas.pools(selectedArea.id) else {}
		local unlocked = {}
		local nextPool = nil
		for _, pool in ipairs(pools) do
			if Pools.isUnlocked(pool, playerAscension()) then
				table.insert(unlocked, pool)
			elseif nextPool == nil then
				nextPool = pool
			end
		end
		if not LaunchGate.on("extraRealms") and #unlocked > 1 then
			unlocked = { unlocked[1] }
		end
		if #unlocked <= 1 then
			local label = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.BuilderSansMedium,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLORS.text,
				Text = if selectedPool ~= nil then selectedPool.name else "",
				LayoutOrder = 1,
			}, realmRow) :: TextLabel
			label.Name = "RealmName"
			label:SetAttribute("BaseHeight", 18)
		else
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}, realmRow)
			for index, pool in ipairs(unlocked) do
				local chip =
					makeButton(realmRow, pool.short or pool.name, COLORS.buttonDim, index, 24)
				chip.Size = UDim2.fromOffset(0, 44)
				chip.AutomaticSize = Enum.AutomaticSize.X
				chip.TextSize = 12
				chip.Font = Enum.Font.BuilderSansMedium
				local active = selectedPool ~= nil and selectedPool.id == pool.id
				chip.BackgroundColor3 = if active then COLORS.gold else COLORS.buttonDim
				chip.TextColor3 = if active then COLORS.ink else COLORS.text
				new("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}, chip)
				chip.MouseButton1Click:Connect(function()
					if selectedPool ~= nil and selectedPool.id == pool.id then
						return
					end
					selectedPool = pool
					paintRealms()
					if latestProfile ~= nil then
						renderPity(latestProfile)
					end
					callbacks.onArea(pool.id)
				end)
			end
		end
		if nextPool ~= nil then
			realmNext.Visible = true
			realmNext.Text =
				string.format("%s unlocks at Ascension %d", nextPool.name, nextPool.ascension)
		else
			realmNext.Visible = false
			realmNext.Text = ""
		end
		applyPage()
		fitLegacyText()
	end

	local function highestUnlocked(area: any): any
		local pick = nil
		for _, pool in ipairs(Areas.pools(area.id)) do
			if Pools.isUnlocked(pool, playerAscension()) then
				pick = pool
			end
		end
		return pick
	end

	local function selectArea(area: any, notify: boolean)
		selectedArea = area
		paintChips()
		local pool = if area ~= nil then highestUnlocked(area) else nil
		if pool ~= nil then
			selectedPool = pool
		end
		paintRealms()
		if latestProfile ~= nil then
			renderPity(latestProfile)
		end
		if notify and selectedPool ~= nil then
			callbacks.onArea(selectedPool.id)
		end
	end
	for _, chip in ipairs(chips) do
		local area = chip.area
		chip.button.MouseButton1Click:Connect(function()
			if selectedArea ~= nil and selectedArea.id == area.id then
				return
			end
			selectArea(area, true)
		end)
	end
	paintChips()
	paintRealms()

	function controller.setBusy(isBusy: boolean)
		busy = isBusy
		paintCrack()
	end

	function controller.setNotice(text: string)
		oddsNotice.Text = text
	end

	function controller.setAutoAttack(enabled: boolean)
		autoEnabled = enabled
		paintAuto()
	end

	function controller.setAutoFarm(enabled: boolean)
		farmEnabled = enabled
		paintFarm()
	end

	function controller.setGraphics(label: string)
		if graphicsButton ~= nil then
			graphicsButton.Text = "Graphics " .. label
		end
	end

	function controller.toggleMenu()
		userOpen = not userOpen
		applyChrome()
	end

	function controller.open()
		userOpen = true
		applyChrome()
	end

	function controller.close()
		userOpen = false
		applyChrome()
	end

	function controller.isOpen(): boolean
		return userOpen and not covered
	end

	function controller.setCovered(open: boolean)
		covered = open
		applyChrome()
	end

	function controller.openPanel(kind: string, areaId: string?)
		userOpen = true
		applyChrome()
		if kind == "craft" then
			page = "craft"
			applyPage()
			panel.CanvasPosition = Vector2.zero
			print("[ForgeUI] opened")
			return
		end
		page = "shards"
		if type(areaId) == "string" then
			for _, chip in ipairs(chips) do
				if chip.area.id == areaId then
					if selectedArea == nil or selectedArea.id ~= areaId then
						selectArea(chip.area, true)
					else
						applyPage()
					end
					return
				end
			end
		end
		applyPage()
	end

	local statusToken = 0
	function controller.clearStatus()
		statusToken += 1
		bannerToken += 1
		status.Visible = false
		status.Text = ""
		toast.Visible = false
		toast.Text = ""
		banner.Visible = false
		banner.Text = ""
	end

	function controller.setStatus(text: string, kind: string, hold: boolean?)
		statusToken += 1
		local token = statusToken
		status.Text = text
		status.Visible = text ~= ""
		-- One status line. The banner is centered; the old toast sat beside
		-- it and the two wraps read as one garbled line.
		toast.Text = ""
		toast.Visible = false
		showBanner(text, kind, hold)
		local color = COLORS.muted
		if kind == "error" then
			color = COLORS.danger
		elseif kind == "ok" then
			color = COLORS.ok
		end
		status.TextColor3 = color
		toast.TextColor3 = color
		if text == "" or hold == true then
			return
		end
		task.delay(ShellLayout.BANNER_SECONDS, function()
			if token ~= statusToken then
				return
			end
			status.Visible = false
			status.Text = ""
			toast.Visible = false
			toast.Text = ""
		end)
	end

	local function tonicCount(profile: any): number
		if type(profile) ~= "table" or type(profile.consumables) ~= "table" then
			return 0
		end
		local count = profile.consumables[Materials.TONIC_ID]
		if type(count) ~= "number" then
			return 0
		end
		return count
	end

	local function traitGear(profile: any): { any }
		local rows = {}
		if type(profile) ~= "table" or type(profile.inventory) ~= "table" then
			return rows
		end
		for _, item in pairs(profile.inventory) do
			if type(item) == "table" and (item.kind == "Weapon" or item.kind == "Armor") then
				local slots = Rarities.TRAIT_SLOTS[item.rarity]
				if type(slots) == "number" and slots > 0 then
					table.insert(rows, item)
				end
			end
		end
		table.sort(rows, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
		return rows
	end

	local function paintForgeTabs()
		craftTabButton.BackgroundColor3 = if forgeTab == "craft"
			then COLORS.gold
			else COLORS.buttonDim
		craftTabButton.TextColor3 = if forgeTab == "craft" then COLORS.ink else COLORS.text
		salvageTabButton.BackgroundColor3 = if forgeTab == "salvage"
			then COLORS.gold
			else COLORS.buttonDim
		salvageTabButton.TextColor3 = if forgeTab == "salvage" then COLORS.ink else COLORS.text
		materialTabButton.BackgroundColor3 = if forgeTab == "materials"
			then COLORS.gold
			else COLORS.buttonDim
		materialTabButton.TextColor3 = if forgeTab == "materials" then COLORS.ink else COLORS.text
		craftList.Visible = forgeTab == "craft"
		salvageList.Visible = forgeTab == "salvage"
		materialList.Visible = forgeTab == "materials"
	end

	local function renderCraft(profile: any)
		clearGenerated(craftList)
		clearGenerated(salvageList)
		clearGenerated(materialList)
		tonicButton.Text = string.format("Tonic %d", tonicCount(profile))
		local level = if type(profile) == "table"
				and type(profile.craftingLevel) == "number"
			then profile.craftingLevel
			else 1
		local xp = if type(profile) == "table" and type(profile.craftingXp) == "number"
			then profile.craftingXp
			else 0
		local xpNext = if type(profile) == "table"
				and type(profile.craftingXpToNext) == "number"
			then profile.craftingXpToNext
			else CraftingLevel.xpToNext(level)
		if level >= CraftingLevel.MAX then
			craftHint.Text = "Crafting Level 100"
			xpFill.Size = UDim2.fromScale(1, 1)
		else
			craftHint.Text = string.format("Crafting Level %d    %d / %d XP", level, xp, xpNext)
			local ratio = if xpNext > 0 then math.clamp(xp / xpNext, 0, 1) else 0
			xpFill.Size = UDim2.fromScale(ratio, 1)
		end
		local untilTime = if type(profile) == "table" then profile.forgeBoostUntil else 0
		forgeNote.Text = Currencies.forgeBoostPitch(untilTime, os.time())
		paintForgeTabs()
		local bag = if type(profile) == "table" then profile.materials else nil
		local gear = traitGear(profile)
		local stillThere = false
		for _, item in ipairs(gear) do
			if item.uid == selectedTarget then
				stillThere = true
			end
		end
		if not stillThere then
			selectedTarget = if gear[1] ~= nil then gear[1].uid else nil
		end

		for index, recipe in ipairs(Recipes.all()) do
			if
				not LaunchGate.on("forgeCraft")
				and type(recipe.result) == "table"
				and recipe.result.kind ~= "reroll"
			then
				continue
			end
			if
				not LaunchGate.on("forgeReroll")
				and type(recipe.result) == "table"
				and recipe.result.kind == "reroll"
			then
				continue
			end
			local card = new("Frame", {
				BackgroundColor3 = COLORS.panel,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = index,
			}, craftList) :: Frame
			corner(card, 8)
			padding(card, 8)
			list(card, 4)

			local locked = if type(profile) == "table"
				then Crafting.lockReason(profile, recipe.id)
				else "Unknown recipe."
			local titleColor = COLORS.text
			if locked ~= nil then
				titleColor = COLORS.muted
			elseif recipe.id == selectedRecipe then
				titleColor = COLORS.gold
			end
			local title = new("TextButton", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 44),
				Font = Enum.Font.BuilderSansBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = titleColor,
				Text = recipe.name,
				LayoutOrder = 1,
			}, card) :: TextButton
			title.MouseButton1Click:Connect(function()
				selectedRecipe = recipe.id
				if latestProfile ~= nil then
					renderCraft(latestProfile)
				end
			end)

			new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.BuilderSans,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = COLORS.muted,
				Text = recipe.blurb,
				LayoutOrder = 2,
			}, card)

			local costLines = {}
			local canPay = true
			local materials = if type(profile) == "table" then profile.materials else nil
			for _, materialId in ipairs(Materials.ORDER) do
				local need = recipe.costs[materialId]
				if type(need) == "number" and need > 0 then
					local have = 0
					if type(materials) == "table" and type(materials[materialId]) == "number" then
						have = materials[materialId]
					end
					if have < need then
						canPay = false
					end
					table.insert(
						costLines,
						string.format("%s  %d/%d", Materials.displayName(materialId), have, need)
					)
				end
			end
			local costs = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = if canPay then COLORS.ok else COLORS.danger,
				Text = table.concat(costLines, "\n"),
				LayoutOrder = 3,
			}, card) :: TextLabel
			costs.Name = "Costs"

			if recipe.result.kind == "reroll" then
				if #gear == 0 then
					new("TextLabel", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 16),
						Font = Enum.Font.BuilderSans,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = COLORS.muted,
						Text = "Needs a Rare or better weapon or armor piece.",
						LayoutOrder = 4,
					}, card)
				else
					for gearIndex, item in ipairs(gear) do
						local pick = makeButton(
							card,
							tostring(item.name),
							COLORS.buttonDim,
							3 + gearIndex,
							24
						)
						pick.TextSize = 12
						local chosen = item.uid == selectedTarget
						pick.BackgroundColor3 = if chosen then COLORS.gold else COLORS.buttonDim
						pick.TextColor3 = if chosen then COLORS.ink else COLORS.text
						pick.MouseButton1Click:Connect(function()
							selectedTarget = item.uid
							selectedRecipe = recipe.id
							if latestProfile ~= nil then
								renderCraft(latestProfile)
							end
						end)
					end
				end
			end

			if locked ~= nil then
				new("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = Enum.Font.BuilderSans,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = COLORS.muted,
					Text = locked,
					LayoutOrder = 4,
				}, card)
			end
			local craftButton = makeButton(
				card,
				if locked ~= nil then "Locked" else "Craft",
				if locked == nil and canPay then COLORS.button else COLORS.buttonDim,
				20,
				28
			)
			craftButton.TextSize = 14
			craftButton.Active = locked == nil
			craftButton.AutoButtonColor = locked == nil
			craftButton.TextColor3 = if locked ~= nil then COLORS.muted else COLORS.text
			craftButton.MouseButton1Click:Connect(function()
				if locked ~= nil then
					return
				end
				selectedRecipe = recipe.id
				local target = if recipe.result.kind == "reroll" then selectedTarget else nil
				callbacks.onCraft(recipe.id, target)
			end)
		end

		local salvageRows = {}
		if type(profile) == "table" and type(profile.inventory) == "table" then
			for _, item in pairs(profile.inventory) do
				if type(item) == "table" and (item.kind == "Weapon" or item.kind == "Armor") then
					local equipped = false
					if type(profile.equipped) == "table" then
						if profile.equipped.weapon == item.uid then
							equipped = true
						end
						if type(profile.equipped.armor) == "table" then
							for _, slotUid in pairs(profile.equipped.armor) do
								if slotUid == item.uid then
									equipped = true
								end
							end
						end
					end
					if not equipped and item.locked ~= true then
						table.insert(salvageRows, item)
					end
				end
			end
		end
		table.sort(salvageRows, function(a, b)
			return tostring(a.name) < tostring(b.name)
		end)
		if #salvageRows == 0 then
			new("TextLabel", {
				Name = "Notice",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = COLORS.muted,
				Text = "Unequipped weapons and armor break down here.",
				LayoutOrder = 1,
			}, salvageList)
		end
		for index, item in ipairs(salvageRows) do
			local row = new("Frame", {
				BackgroundColor3 = COLORS.panel,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = index,
			}, salvageList) :: Frame
			corner(row, 8)
			local label = new("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -88, 1, 0),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = rarityColor(tostring(item.rarity)),
				Text = string.format("%s  ·  %s", tostring(item.name), tostring(item.rarity)),
			}, row) :: TextLabel
			label.Name = "Name"
			local salvageButton = makeButton(row, "Salvage", COLORS.buttonDim, 1, 24)
			salvageButton.AnchorPoint = Vector2.new(1, 0.5)
			salvageButton.Position = UDim2.new(1, -6, 0.5, 0)
			salvageButton.Size = UDim2.fromOffset(96, 44)
			salvageButton.TextSize = 12
			salvageButton.MouseButton1Click:Connect(function()
				callbacks.onSalvage(item.uid)
			end)
		end

		local materialOrder = 0
		for _, materialId in ipairs(Materials.ORDER) do
			local definition = Materials.DEFS[materialId]
			local count = 0
			if type(bag) == "table" and type(bag[materialId]) == "number" then
				count = bag[materialId]
			end
			materialOrder += 1
			local color = definition.color
			local row = new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.BuilderSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(color[1], color[2], color[3]),
				Text = string.format(
					"%s    %d / %d    ·    %s",
					definition.name,
					count,
					definition.stack,
					definition.realm
				),
				LayoutOrder = materialOrder,
			}, materialList)
			row.Name = materialId
		end
		fitLegacyText()
	end

	local function showForgeTab(name: string)
		forgeTab = name
		if latestProfile ~= nil then
			renderCraft(latestProfile)
		else
			paintForgeTabs()
		end
	end
	craftTabButton.MouseButton1Click:Connect(function()
		showForgeTab("craft")
	end)
	salvageTabButton.MouseButton1Click:Connect(function()
		showForgeTab("salvage")
	end)
	materialTabButton.MouseButton1Click:Connect(function()
		showForgeTab("materials")
	end)

	function controller.setRun(run: any)
		if type(run) == "table" then
			runState = run
		else
			runState = { active = false }
		end
		paintDungeon()
	end

	function controller.setProfile(profile: any, saving: boolean)
		if type(profile) ~= "table" then
			stats.Text = ""
			return
		end
		latestProfile = profile
		profileLoaded = true
		paintSave(saving)
		local voucherNote = ""
		if type(profile.vouchers) == "table" then
			if (profile.vouchers.armory or 0) > 0 then
				voucherNote ..= string.format("  ·  Armory voucher %d", profile.vouchers.armory)
			end
			if (profile.vouchers.pets or 0) > 0 then
				voucherNote ..= string.format("  ·  Pets voucher %d", profile.vouchers.pets)
			end
		end
		local luckText = tostring(profile.shardLuck or 0)
		if (profile.luckBoost or 0) > 0 then
			luckText ..= string.format(" +%d", profile.luckBoost)
		end
		stats.Text = string.format(
			"Lv %d    ·    %d Shard    ·    %d Prism    ·    Luck %s\n%d/%d XP    ·    %d gold    ·    Asc %d%s",
			profile.level or 1,
			profile.shardTokens or 0,
			profile.prismTokens or 0,
			luckText,
			profile.xp or 0,
			profile.xpToNext or 100,
			profile.gold or 0,
			profile.ascension or 0,
			voucherNote
		)
		tokens = profile.shardTokens or 0
		prismTokens = profile.prismTokens or 0
		luckBoost = profile.luckBoost or 0
		paintCrack()
		renderPity(profile)
		renderCraft(profile)
		local gear = InventoryStacks.loadout(profile)
		loadout.Text = string.format(
			"Weapon   %s\nPet   %s\nArmor   %s\nBonus   %s",
			gear.weapon,
			gear.pet,
			gear.armor,
			gear.bonus
		)
		paintRealms()
		musicValue = Audio.clampVolume(profile.musicVolume)
		sfxValue = Audio.clampVolume(profile.sfxVolume)
		paintMusic(musicValue)
		paintSfx(sfxValue)
		local nextScale: any = nil
		local settings = profile.uiSettings
		if type(settings) == "table" and type(settings.access) == "table" then
			nextScale = settings.access.textScale
		end
		bannerScale = nextScale
		applyBannerFit()
		fitLegacyText()
	end

	function controller.setPolicy(policy: any)
		if type(policy) ~= "table" then
			return
		end
		policyState = policy
		paintPaid()
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
			label:SetAttribute("BaseHeight", 16)
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
			label.Name = "OddsRow"
			label:SetAttribute("BaseHeight", 16)
		end
		local areaName = if selectedPool ~= nil then selectedPool.name else "Odds"
		heading(areaName .. "  ·  totals")
		if type(odds.rarities) == "table" then
			for _, rarityRow in ipairs(odds.rarities) do
				local chanceText = RollMath.formatChance(rarityRow.chance)
				local text = if type(rarityRow.oneIn) == "number"
					then string.format(
						"%s    1 in %d    %s",
						rarityRow.rarity,
						rarityRow.oneIn,
						chanceText
					)
					else string.format("%s    %s", rarityRow.rarity, chanceText)
				row(text, rarityRow.rarity)
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
		-- applyProfile refreshes odds after setProfile, so this rebuild
		-- has to fit the new rows or they stay at the design size.
		fitLegacyText()
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
		local detail = {}
		if type(item.quality) == "number" then
			table.insert(detail, Stats.formatQuality(item.quality) .. " roll")
		end
		if type(item.stats) == "table" then
			for _, stat in ipairs(item.stats) do
				if type(stat) == "table" then
					table.insert(detail, tostring(stat.name) .. "  " .. Stats.formatValue(stat))
				end
			end
		end
		table.insert(detail, "Bonus: " .. InventoryStacks.bonusLine(item.traits))
		popupTraits.Text = table.concat(detail, "\n")
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
