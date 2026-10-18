--!strict

--[[
	The only always-on HUD. One ScreenGui, one UIScale.

	Top-left is the class portrait, a tweened HP bar, and the level.
	Top-right, under the Roblox buttons, is Gold, Mastery, and Shards.
	A mid-left rail opens the hub. Skills live on the action bar.
	The bottom-left stays empty. Toasts sit top-center.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Build = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Build"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local LaunchGate = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LaunchGate"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))
local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))
local Quality = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quality"))
local ToastQueue = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ToastQueue"))
local UiIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiIcons"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local StarterGoalHud = require(script.Parent.StarterGoalHud)

local HudShell = {}

export type Callbacks = {
	onHero: () -> (),
	onBag: () -> (),
	onRoll: () -> (),
	onPets: () -> (),
	onShop: () -> (),
	onSettings: () -> (),
}

-- Length is HudLayout.RAIL_COUNT. BannerFit clears that many buttons.
local RAIL = {
	{ id = "Hero", icon = "hero", call = "onHero" },
	{ id = "Bag", icon = "bag", call = "onBag" },
	{ id = "Pets", icon = "pets", call = "onPets" },
	{ id = "Roll", icon = "roll", call = "onRoll" },
	{ id = "Shop", icon = "market", call = "onShop" },
	{ id = "Settings", icon = "settings", call = "onSettings" },
}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	return Color3.fromRGB(row[1], row[2], row[3])
end

function HudShell.start(playerGui: PlayerGui, callbacks: Callbacks)
	local player = Players.LocalPlayer
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallHud"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 30
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ShellScale"
	uiScale.Scale = 1
	uiScale.Parent = screen

	local chrome = Instance.new("CanvasGroup")
	chrome.Name = "Chrome"
	chrome.Size = UDim2.fromScale(1, 1)
	chrome.BackgroundTransparency = 1
	chrome.GroupTransparency = 0
	chrome.Parent = screen

	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.BackgroundColor3 = rgb("panel")
	portrait.BorderSizePixel = 0
	portrait.Parent = chrome
	local portraitAspect = Instance.new("UIAspectRatioConstraint")
	portraitAspect.AspectRatio = 1
	portraitAspect.Parent = portrait
	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	portraitCorner.Parent = portrait
	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Thickness = UiTheme.STROKE
	portraitStroke.Color = rgb("gold")
	portraitStroke.Parent = portrait
	local initial = Instance.new("TextLabel")
	initial.Name = "Initial"
	initial.BackgroundTransparency = 1
	initial.Size = UDim2.fromScale(1, 0.62)
	initial.Font = Enum.Font.BuilderSansBold
	initial.TextSize = 22
	initial.TextColor3 = rgb("text")
	initial.Text = "?"
	initial.ZIndex = 3
	initial.Parent = portrait
	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundTransparency = 1
	headshot.Size = UDim2.fromScale(1, 0.62)
	headshot.ScaleType = Enum.ScaleType.Crop
	headshot.ZIndex = 2
	headshot.Parent = portrait
	task.spawn(function()
		local ok, content, ready = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		if ok and ready == true and type(content) == "string" and content ~= "" then
			headshot.Image = content
			initial.Visible = false
		end
	end)
	local className = Instance.new("TextLabel")
	className.Name = "ClassName"
	className.BackgroundTransparency = 1
	className.Position = UDim2.fromScale(0, 0.58)
	className.Size = UDim2.fromScale(1, 0.4)
	className.Font = Enum.Font.BuilderSans
	className.TextSize = UiTheme.MIN_TEXT
	className.TextColor3 = rgb("text")
	className.Text = "Class"
	className.Parent = portrait

	local health = Instance.new("Frame")
	health.Name = "Health"
	health.BackgroundColor3 = rgb("panel")
	health.BackgroundTransparency = 0.08
	health.BorderSizePixel = 0
	health.Parent = chrome
	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	healthCorner.Parent = health
	local healthStroke = Instance.new("UIStroke")
	healthStroke.Thickness = UiTheme.STROKE
	healthStroke.Color = rgb("buttonDim")
	healthStroke.Parent = health
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "Level"
	levelLabel.BackgroundTransparency = 1
	levelLabel.Position = UDim2.fromOffset(8, 2)
	levelLabel.Size = UDim2.new(0.42, -8, 0, 16)
	levelLabel.Font = Enum.Font.BuilderSansBold
	levelLabel.TextSize = UiTheme.MIN_TEXT
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextColor3 = rgb("text")
	levelLabel.Text = "Lv 1"
	levelLabel.Parent = health
	local hpBack = Instance.new("Frame")
	hpBack.Name = "Track"
	hpBack.Position = UDim2.fromOffset(8, 20)
	hpBack.Size = UDim2.new(1, -16, 0, 10)
	hpBack.BackgroundColor3 = rgb("buttonDim")
	hpBack.BorderSizePixel = 0
	hpBack.Parent = health
	local hpFill = Instance.new("Frame")
	hpFill.Name = "Fill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = rgb("ok")
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	local hpText = Instance.new("TextLabel")
	hpText.Name = "Hp"
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.new(0.42, 0, 0, 2)
	hpText.Size = UDim2.new(0.58, -8, 0, 16)
	hpText.Font = Enum.Font.BuilderSansBold
	hpText.TextSize = UiTheme.MIN_TEXT
	hpText.TextXAlignment = Enum.TextXAlignment.Right
	hpText.TextColor3 = rgb("text")
	hpText.TextStrokeColor3 = rgb("ink")
	hpText.TextStrokeTransparency = 0.35
	hpText.Text = "HP  100 / 100"
	hpText.Parent = health
	local xpText = Instance.new("TextLabel")
	xpText.Name = "Xp"
	xpText.BackgroundTransparency = 1
	xpText.Position = UDim2.fromOffset(8, 32)
	xpText.Size = UDim2.new(1, -16, 0, 14)
	xpText.Font = Enum.Font.BuilderSansBold
	xpText.TextSize = UiTheme.MIN_TEXT
	xpText.TextXAlignment = Enum.TextXAlignment.Left
	xpText.TextColor3 = rgb("text")
	xpText.Text = "XP  0 / 100"
	xpText.Parent = health
	local xpBack = Instance.new("Frame")
	xpBack.Name = "XpTrack"
	xpBack.Position = UDim2.fromOffset(8, 46)
	xpBack.Size = UDim2.new(1, -16, 0, 6)
	xpBack.BackgroundColor3 = rgb("buttonDim")
	xpBack.BorderSizePixel = 0
	xpBack.Parent = health
	local xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = rgb("gold")
	xpFill.BorderSizePixel = 0
	xpFill.Parent = xpBack

	local pills = Instance.new("Frame")
	pills.Name = "Pills"
	pills.BackgroundTransparency = 1
	pills.Parent = chrome
	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.Padding = UDim.new(0, UiTheme.PAD)
	pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	pillLayout.Parent = pills
	local function pill(name: string, title: string): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.fromOffset(108, 32)
		label.BackgroundColor3 = rgb("panel")
		label.BackgroundTransparency = 0.2
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = UiTheme.MIN_TEXT
		label.TextColor3 = rgb("text")
		label.TextStrokeColor3 = rgb("ink")
		label.TextStrokeTransparency = 0
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = title
		label.Parent = pills
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE
		stroke.Color = rgb("ink")
		stroke.Parent = label
		return label
	end
	local gold = pill("Gold", "Gold 0")
	local mastery = pill("Mastery", "Mastery 0")
	mastery.Visible = LaunchGate.on("extraCurrencies")
	local shards = pill("Shards", "Shards 0")

	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.BackgroundTransparency = 1
	rail.Parent = chrome
	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.Padding = UDim.new(0, UiTheme.PAD)
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Parent = rail
	local dots: { [string]: Frame } = {}
	local railAccents: { [string]: Frame } = {}
	local railButtons: { TextButton } = {}
	for index, entry in ipairs(RAIL) do
		local button = Instance.new("TextButton")
		button.Name = entry.id
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("body")
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = rail
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE
		stroke.Color = rgb("divider")
		stroke.Parent = button
		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.Size = UDim2.new(0, UiTheme.ACCENT, 1, -10)
		accent.Position = UDim2.fromOffset(0, 5)
		accent.BackgroundColor3 = rgb("accent")
		accent.BorderSizePixel = 0
		accent.Visible = false
		accent.ZIndex = 4
		accent.Parent = button
		railAccents[entry.id] = accent
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 4)
		icon.Size = UDim2.fromOffset(20, 20)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = UiIcons.get(entry.icon)
		local red, green, blue = UiIcons.tintOf(entry.icon)
		icon.ImageColor3 = Color3.fromRGB(red, green, blue)
		icon.ZIndex = 2
		icon.Parent = button
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.BackgroundTransparency = 1
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.new(0.5, 0, 0, 27)
		caption.Size = UDim2.new(1, -4, 0, UiTheme.MIN_TEXT)
		caption.Font = Enum.Font.BuilderSansBold
		caption.TextSize = UiTheme.MIN_TEXT
		caption.TextColor3 = rgb("text")
		caption.TextTruncate = Enum.TextTruncate.AtEnd
		local menuField = string.lower(entry.id)
		local menuKey = Keybinds.MENU[menuField]
		caption.Text = entry.id
		caption.ZIndex = 3
		caption:SetAttribute("SkipTextScale", true)
		caption.Parent = button
		local tip = Instance.new("TextLabel")
		tip.Name = "Tip"
		tip.AnchorPoint = Vector2.new(0, 0.5)
		tip.Position = UDim2.new(1, 8, 0.5, 0)
		tip.Size = UDim2.fromOffset(84, 28)
		tip.BackgroundColor3 = rgb("header")
		tip.Font = Enum.Font.BuilderSans
		tip.TextSize = UiTheme.MIN_TEXT
		tip.TextColor3 = rgb("text")
		tip.Text = if type(menuKey) == "string"
			then entry.id .. "  " .. Keybinds.display(menuKey)
			else entry.id
		if type(menuKey) == "string" then
			local bind = Instance.new("TextLabel")
			bind.Name = "Bind"
			bind.AnchorPoint = Vector2.new(1, 0)
			bind.Position = UDim2.new(1, -2, 0, 1)
			bind.Size = UDim2.fromOffset(16, 12)
			bind.BackgroundTransparency = 1
			bind.Font = Enum.Font.BuilderSansBold
			bind.TextSize = 11
			bind.TextXAlignment = Enum.TextXAlignment.Right
			bind.TextColor3 = rgb("muted")
			bind.Text = Keybinds.display(menuKey)
			bind.ZIndex = 5
			bind:SetAttribute("SkipTextScale", true)
			bind.Parent = button
		end
		tip.Visible = false
		tip.ZIndex = 8
		tip.Parent = button
		local tipCorner = Instance.new("UICorner")
		tipCorner.CornerRadius = UDim.new(0, 6)
		tipCorner.Parent = tip
		button.MouseEnter:Connect(function()
			tip.Visible = true
			button.BackgroundColor3 = rgb("hover")
		end)
		button.MouseLeave:Connect(function()
			tip.Visible = false
			button.BackgroundColor3 = rgb("body")
		end)
		local pop = Instance.new("UIScale")
		pop.Name = "Press"
		pop.Parent = button
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				TweenService:Create(
					pop,
					TweenInfo.new(
						UiTheme.MOTION.pop,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{ Scale = 0.94 }
				):Play()
			end
		end)
		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				TweenService:Create(
					pop,
					TweenInfo.new(
						UiTheme.MOTION.pop,
						Enum.EasingStyle.Back,
						Enum.EasingDirection.Out
					),
					{ Scale = 1 }
				):Play()
			end
		end)
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -2, 0, 2)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = rgb("ok")
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.ZIndex = 5
		dot.Parent = button
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		dots[entry.id] = dot
		local callName = entry.call
		button.Activated:Connect(function()
			local fn = (callbacks :: any)[callName]
			if fn ~= nil then
				fn()
			end
		end)
		table.insert(railButtons, button)
	end

	local hudHidden = false

	local notices = ToastQueue.blank()
	local toastHost = Instance.new("Frame")
	toastHost.Name = "Toasts"
	toastHost.BackgroundTransparency = 1
	toastHost.Parent = chrome
	local toastLabels = {}
	for index = 1, ToastQueue.MAX do
		local toast = Instance.new("TextLabel")
		toast.Name = "Toast"
		toast.BackgroundColor3 = rgb("panel")
		toast.BackgroundTransparency = 0.08
		toast.Font = Enum.Font.BuilderSansBold
		toast.TextSize = UiTheme.MIN_TEXT
		toast.TextColor3 = rgb("text")
		toast.Text = ""
		toast.Visible = false
		toast.LayoutOrder = index
		toast.Parent = toastHost
		local toastCorner = Instance.new("UICorner")
		toastCorner.CornerRadius = UDim.new(0, 8)
		toastCorner.Parent = toast
		toastLabels[index] = toast
	end
	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.BackgroundColor3 = rgb("panel")
	prompt.Visible = false
	local promptGui = Instance.new("ScreenGui")
	promptGui.Name = "ShardfallPrompt"
	promptGui.ResetOnSpawn = false
	promptGui.DisplayOrder = 90
	promptGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	promptGui.IgnoreGuiInset = false
	promptGui.Parent = playerGui
	prompt.Parent = promptGui
	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 8)
	promptCorner.Parent = prompt
	local promptText = Instance.new("TextLabel")
	promptText.Name = "Text"
	promptText.BackgroundTransparency = 1
	promptText.Size = UDim2.new(1, -16, 0, 28)
	promptText.Position = UDim2.fromOffset(8, 4)
	promptText.Font = Enum.Font.BuilderSansBold
	promptText.TextSize = UiTheme.MIN_TEXT
	promptText.TextColor3 = rgb("text")
	promptText.TextXAlignment = Enum.TextXAlignment.Left
	promptText.Text = ""
	promptText.Parent = prompt
	local function promptButton(name: string, label: string, x: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, HudLayout.PROMPT_LABEL)
		button.Size = UDim2.fromOffset(UiTheme.TOUCH * 2, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("button")
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("text")
		button.Text = label
		button.AutoButtonColor = false
		button.Parent = prompt
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		return button
	end
	local promptYes = promptButton("Equip", "Equip", 8)
	local promptNo = promptButton("Keep", "Keep", 8 + UiTheme.TOUCH * 2 + 8)
	local function paintNotices()
		local shown = ToastQueue.visibleToasts(notices)
		for index, label in ipairs(toastLabels) do
			local row = shown[index]
			label.Visible = row ~= nil
			label.Text = if row ~= nil then row.text else ""
		end
		local current = ToastQueue.currentPrompt(notices)
		prompt.Visible = current ~= nil
		if current ~= nil then
			promptText.Text = current.text
			promptYes.Text = current.yes
			promptNo.Text = current.no
		end
	end
	-- Same remote MenuHub and the bag already call. No new remote.
	local function equipItem(uid: string)
		task.spawn(function()
			local folder = ReplicatedStorage:FindFirstChild("Remotes")
			if folder == nil then
				return
			end
			local remote = folder:FindFirstChild("EquipItem")
			if remote ~= nil and remote:IsA("RemoteFunction") then
				pcall(function()
					remote:InvokeServer(uid)
				end)
			end
		end)
	end
	local function onYes()
		local current = ToastQueue.currentPrompt(notices)
		local uid = if current ~= nil then current.uid else nil
		notices = ToastQueue.answer(notices)
		paintNotices()
		if type(uid) == "string" and uid ~= "" then
			equipItem(uid)
		end
	end
	local function onNo()
		notices = ToastQueue.answer(notices)
		paintNotices()
	end
	promptYes.Activated:Connect(onYes)
	promptNo.Activated:Connect(onNo)

	local stamp = Instance.new("TextLabel")
	stamp.Name = "BuildStamp"
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.BuilderSans
	stamp.TextSize = 12
	stamp.TextXAlignment = Enum.TextXAlignment.Left
	stamp.TextColor3 = rgb("muted")
	stamp.TextTransparency = 0.62
	stamp.Text = Build.STAMP
	stamp.ZIndex = 2
	stamp:SetAttribute("SkipTextScale", true)
	stamp.Parent = chrome

	local touchDevice = Quality.touchDevice(UserInputService.TouchEnabled, nil)

	local function view(): (number, number)
		local size = screen.AbsoluteSize
		local vx = if size.X >= 200 then size.X else 1280
		local vy = if size.Y >= 200 then size.Y else 800
		return vx, vy
	end

	local function place()
		local vx, vy = view()
		local margin = UiTheme.safeMargin()
		local face = HudLayout.portrait(margin)
		portrait.Position = UDim2.fromOffset(face.x, face.y)
		portrait.Size = UDim2.fromOffset(face.w, face.h)
		local bar = HudLayout.health(margin, vx)
		health.Position = UDim2.fromOffset(bar.x, bar.y)
		health.Size = UDim2.fromOffset(bar.w, bar.h)
		local row = HudLayout.pills(vx, margin)
		pills.Position = UDim2.fromOffset(row.x, row.y)
		pills.Size = UDim2.fromOffset(row.w, row.h)
		local vertical = row.h > row.w
		if vertical then
			pillLayout.FillDirection = Enum.FillDirection.Vertical
		else
			pillLayout.FillDirection = Enum.FillDirection.Horizontal
		end
		local gap = UiTheme.PAD
		local span = if vertical then row.h else row.w
		local each = math.max(1, math.floor((span - gap * 2) / 3))
		local labelW = if vertical then row.w else each
		local labelH = if vertical then each else math.min(32, row.h)
		gold.Size = UDim2.fromOffset(labelW, labelH)
		mastery.Size = UDim2.fromOffset(labelW, labelH)
		shards.Size = UDim2.fromOffset(labelW, labelH)
		local side = HudLayout.railFit(vy, margin, HudLayout.RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH, vx)
		rail.Position = UDim2.fromOffset(side.x, side.y)
		rail.Size = UDim2.fromOffset(side.w, side.h)
		for _, button in ipairs(railButtons) do
			button.Size = UDim2.fromOffset(side.button, side.button)
		end
		local stampBox =
			HudLayout.stamp(vy, margin, touchDevice, RunService:IsStudio(), side.x + side.w + 12)
		if stampBox == nil then
			stamp.Visible = false
		else
			stamp.Visible = true
			stamp.Position = UDim2.fromOffset(stampBox.x, stampBox.y)
			stamp.Size = UDim2.fromOffset(stampBox.w, stampBox.h)
		end
		local host = HudLayout.toastHost(vx, margin)
		toastHost.Position = UDim2.fromOffset(host.x, host.y)
		toastHost.Size = UDim2.fromOffset(host.w, host.h)
		local card = HudLayout.toast(vx, margin)
		for index, label in ipairs(toastLabels) do
			label.Position = UDim2.fromOffset(0, (index - 1) * (card.h + UiTheme.PAD))
			label.Size = UDim2.fromOffset(card.w, card.h)
		end
		local ask = HudLayout.equipPrompt(vx, margin)
		prompt.Position = UDim2.fromOffset(ask.x, ask.y)
		prompt.Size = UDim2.fromOffset(ask.w, ask.h)
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	task.defer(place)

	local shownRatio = 1
	local function setVitals(hp: number, maxHp: number)
		local safeMax = math.max(1, maxHp)
		local ratio = math.clamp(hp / safeMax, 0, 1)
		hpText.Text = string.format("HP  %d / %d", math.floor(hp + 0.5), math.floor(safeMax + 0.5))
		TweenService:Create(
			hpFill,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(ratio, 1) }
		):Play()
		shownRatio = ratio
	end

	local function watch(character: Model)
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root == nil or not root:IsA("BasePart") then
			return
		end
		local function pull()
			local hp = root:GetAttribute("ShardfallHp")
			local maxHp = root:GetAttribute("ShardfallMax")
			if type(hp) == "number" and type(maxHp) == "number" then
				setVitals(hp, maxHp)
			end
		end
		pull()
		root:GetAttributeChangedSignal("ShardfallHp"):Connect(pull)
		root:GetAttributeChangedSignal("ShardfallMax"):Connect(pull)
	end
	if player.Character ~= nil then
		task.spawn(watch, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(watch, character)
	end)

	local function showDot(id: string, on: boolean)
		local dot = dots[id]
		if dot ~= nil then
			dot.Visible = on
		end
	end

	return {
		setProfile = function(profile: any)
			local level = if type(profile) == "table" and type(profile.level) == "number"
				then profile.level
				else 1
			levelLabel.Text = string.format("Lv %d", level)
			local classId = if type(profile) == "table" then profile.classId else ""
			local classDef = Classes.get(classId)
			if classDef ~= nil then
				initial.Text = string.sub(classDef.name, 1, 1)
				className.Text = classDef.name
				local color = classDef.palette
				portrait.BackgroundColor3 = Color3.fromRGB(color[1], color[2], color[3])
			else
				initial.Text = "?"
				className.Text = "Class"
			end
			local shardCount = if type(profile) == "table" then profile.shardTokens or 0 else 0
			local goldCount = if type(profile) == "table"
					and type(profile.gold) == "number"
				then profile.gold
				else 0
			local lines = HudLayout.counters(goldCount, Progression.mastery(level), shardCount)
			gold.Text = lines[1]
			mastery.Text = lines[2]
			shards.Text = lines[3]
			local xp = if type(profile) == "table" and type(profile.xp) == "number"
				then profile.xp
				else 0
			local xpNext = if type(profile) == "table"
					and type(profile.xpToNext) == "number"
				then profile.xpToNext
				else 0
			if xpNext > 0 then
				xpText.Text = string.format("XP  %d / %d", math.floor(xp), math.floor(xpNext))
				xpFill.Size = UDim2.fromScale(math.clamp(xp / xpNext, 0, 1), 1)
			else
				xpText.Text = "XP  Max"
				xpFill.Size = UDim2.fromScale(1, 1)
			end
			showDot("Hero", classDef == nil)
			local heroButton = rail:FindFirstChild("Hero")
			if heroButton ~= nil then
				local tip = heroButton:FindFirstChild("Tip")
				if tip ~= nil and tip:IsA("TextLabel") then
					tip.Text = if classDef == nil then "Choose class" else "Hero"
				end
			end
			showDot("Bag", false)
			showDot("Roll", shardCount > 0)
			showDot("Pets", type(profile) == "table" and (profile.eggs or 0) > 0)
			showDot("Market", false)
			showDot("Pass", type(profile) == "table" and profile.dailyBossReady == true)
			showDot("Settings", false)
			local settings = if type(profile) == "table" then profile.uiSettings else nil
			local scale = 1
			local hidden = false
			if type(settings) == "table" and type(settings.hud) == "table" then
				if type(settings.hud.scale) == "number" then
					scale = settings.hud.scale
				end
				hidden = settings.hud.hidden == true
			end
			uiScale.Scale = scale
			local textScale = 1
			if type(settings) == "table" and type(settings.access) == "table" then
				if type(settings.access.textScale) == "number" then
					textScale = settings.access.textScale
				end
			end
			for _, desc in ipairs(chrome:GetDescendants()) do
				if desc:GetAttribute("SkipTextScale") == true then
					continue
				end
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					local base = desc:GetAttribute("BaseText")
					if type(base) ~= "number" then
						base = desc.TextSize
						desc:SetAttribute("BaseText", base)
					end
					desc.TextSize =
						math.max(UiTheme.MIN_TEXT, math.floor((base :: number) * textScale + 0.5))
				end
			end
			hudHidden = hidden
			place()
			if hudHidden then
				chrome.GroupTransparency = 1
			else
				chrome.GroupTransparency = 0
			end
			StarterGoalHud.applyChrome(profile.uiSettings)
		end,
		toast = function(text: string)
			if text == "" then
				return
			end
			local added = ToastQueue.pushToast(notices, text)
			local newest = added.toasts[#added.toasts]
			notices = added
			paintNotices()
			if newest ~= nil then
				local id = newest.id
				task.delay(3, function()
					notices = ToastQueue.dropToast(notices, id)
					paintNotices()
				end)
			end
		end,
		prompt = function(text: string, uid: string?)
			local seen: { [number]: boolean } = {}
			for _, row in ipairs(notices.toasts) do
				seen[row.id] = true
			end
			notices = ToastQueue.pushPrompt(notices, text, "Equip", "Keep", uid)
			paintNotices()
			for _, row in ipairs(notices.toasts) do
				if seen[row.id] ~= true then
					local id = row.id
					task.delay(3, function()
						notices = ToastQueue.dropToast(notices, id)
						paintNotices()
					end)
				end
			end
		end,
		place = place,
		ratio = function(): number
			return shownRatio
		end,
		setRail = function(id: string)
			local shown = string.upper(string.sub(id, 1, 1)) .. string.sub(id, 2)
			if id == "" then
				shown = ""
			end
			for name, accent in pairs(railAccents) do
				accent.Visible = name == shown
			end
		end,
		setBadges = function(badges: { [string]: { on: boolean, tip: string } })
			local names = { hero = "Hero", bag = "Bag", pass = "Pass" }
			for id, railName in pairs(names) do
				local badge = badges[id]
				if badge ~= nil then
					local dot = dots[railName]
					if dot ~= nil then
						dot.Visible = badge.on
					end
					local button = rail:FindFirstChild(railName)
					if button ~= nil then
						local tip = button:FindFirstChild("Tip")
						if tip ~= nil and tip:IsA("TextLabel") and badge.tip ~= "" then
							tip.Text = badge.tip
						end
					end
				end
			end
		end,
		noteDevice = function(touch: boolean)
			touchDevice = touch
			place()
		end,
	}
end

return HudShell
