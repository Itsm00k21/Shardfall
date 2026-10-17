--!strict

--[[
	The only always-on HUD. One ScreenGui, one UIScale.

	Top-left is the class portrait, a tweened HP bar, and the level.
	Top-right, under the Roblox buttons, is Shards and Raid Marks.
	A mid-left rail opens the hub. Skills sit beside the jump button.
	The bottom-left stays empty. Toasts sit top-center.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Build = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Build"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local CombatFeel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatFeel"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))
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
	onMarket: () -> (),
	onPass: () -> (),
	onSettings: () -> (),
	onAttack: () -> (),
	onDodge: () -> (),
	onSkill: (number) -> (),
	onUlt: () -> (),
	onHeavy: () -> (),
	onLayout: (string, number, number) -> (),
}

local RAIL = {
	{ id = "Hero", icon = "hero", call = "onHero" },
	{ id = "Bag", icon = "bag", call = "onBag" },
	{ id = "Pets", icon = "pets", call = "onPets" },
	{ id = "Roll", icon = "roll", call = "onRoll" },
	{ id = "Market", icon = "market", call = "onMarket" },
	{ id = "Pass", icon = "pass", call = "onPass" },
	{ id = "Settings", icon = "settings", call = "onSettings" },
}

local SKILL_ICON = {
	Attack = "attack",
	Dodge = "dodge",
	Skill1 = "skill",
	Skill2 = "skill",
	Ult = "ult",
	Heavy = "heavy",
}

local SKILL_BIND = {
	Attack = Keybinds.display(Keybinds.COMBAT.attack),
	Dodge = Keybinds.display(Keybinds.COMBAT.dodge),
	Skill1 = Keybinds.display(Keybinds.COMBAT.skill1),
	Skill2 = Keybinds.display(Keybinds.COMBAT.skill2),
	Ult = Keybinds.display(Keybinds.COMBAT.ult),
	Heavy = Keybinds.display(Keybinds.COMBAT.heavy),
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
	initial.Parent = portrait
	local className = Instance.new("TextLabel")
	className.Name = "ClassName"
	className.BackgroundTransparency = 1
	className.Position = UDim2.fromScale(0, 0.58)
	className.Size = UDim2.fromScale(1, 0.4)
	className.Font = Enum.Font.BuilderSans
	className.TextSize = UiTheme.MIN_TEXT
	className.TextColor3 = rgb("muted")
	className.Text = "Class"
	className.Parent = portrait

	local health = Instance.new("Frame")
	health.Name = "Health"
	health.BackgroundColor3 = rgb("panel")
	health.BackgroundTransparency = 0.15
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
	levelLabel.Position = UDim2.fromOffset(8, 4)
	levelLabel.Size = UDim2.new(1, -16, 0, 18)
	levelLabel.Font = Enum.Font.BuilderSansBold
	levelLabel.TextSize = UiTheme.MIN_TEXT
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextColor3 = rgb("text")
	levelLabel.Text = "Lv 1"
	levelLabel.Parent = health
	local hpBack = Instance.new("Frame")
	hpBack.Name = "Track"
	hpBack.Position = UDim2.fromOffset(8, 28)
	hpBack.Size = UDim2.new(1, -16, 0, 12)
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
	hpText.Position = UDim2.fromOffset(8, 40)
	hpText.Size = UDim2.new(1, -16, 0, 14)
	hpText.Font = Enum.Font.BuilderSans
	hpText.TextSize = UiTheme.MIN_TEXT
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.TextColor3 = rgb("text")
	hpText.Text = "HP  100 / 100"
	hpText.Parent = health

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
		label.Size = UDim2.fromOffset(94, 32)
		label.BackgroundColor3 = rgb("panel")
		label.BackgroundTransparency = 0.12
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = UiTheme.MIN_TEXT
		label.TextColor3 = rgb("gold")
		label.Text = title
		label.Parent = pills
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 94 / 32
		aspect.Parent = label
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE
		stroke.Color = rgb("gold")
		stroke.Parent = label
		return label
	end
	local shards = pill("Shards", "Shards 0")
	local marks = pill("Marks", "Marks 0")

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
		icon.Size = UDim2.fromOffset(22, 22)
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
		caption.AnchorPoint = Vector2.new(0.5, 1)
		caption.Position = UDim2.new(0.5, 0, 1, -1)
		caption.Size = UDim2.new(1, -2, 0, 14)
		caption.Font = Enum.Font.BuilderSans
		caption.TextSize = 11
		caption.TextColor3 = rgb("muted")
		local menuField = string.lower(entry.id)
		local menuKey = Keybinds.MENU[menuField]
		caption.Text = if entry.id == "Settings" then "Gear" else entry.id
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

	local skills = Instance.new("Frame")
	skills.Name = "Skills"
	skills.BackgroundTransparency = 1
	skills.Size = UDim2.fromScale(1, 1)
	skills.Parent = chrome
	local skillButtons = {}
	local layoutEdit = false
	local buttonScale = 1
	local savedLayout: { [string]: { number } } = {}
	local hudHidden = false
	local function skillButton(name: string, fire: () -> ())
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("body")
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.ClipsDescendants = true
		button.Parent = skills
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = rgb("accent")
		stroke.Parent = button
		local iconName = SKILL_ICON[name] or "skill"
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.45)
		icon.Size = UDim2.fromOffset(22, 22)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = UiIcons.get(iconName)
		local red, green, blue = UiIcons.tintOf(iconName)
		icon.ImageColor3 = Color3.fromRGB(red, green, blue)
		icon.ZIndex = 2
		icon.Parent = button
		local bind = Instance.new("TextLabel")
		bind.Name = "Bind"
		bind.AnchorPoint = Vector2.new(1, 1)
		bind.Position = UDim2.new(1, -2, 1, -2)
		bind.Size = UDim2.fromOffset(28, 14)
		bind.BackgroundTransparency = 1
		bind.Font = Enum.Font.BuilderSansBold
		bind.TextSize = 11
		bind.TextXAlignment = Enum.TextXAlignment.Right
		bind.TextColor3 = rgb("text")
		bind.Text = SKILL_BIND[name] or ""
		bind.ZIndex = 5
		bind:SetAttribute("SkipTextScale", true)
		bind.Parent = button
		local pop = Instance.new("UIScale")
		pop.Name = "Press"
		pop.Parent = button
		local radial = Instance.new("Frame")
		radial.Name = "Radial"
		radial.Size = UDim2.fromScale(1, 1)
		radial.BackgroundColor3 = Color3.new(0, 0, 0)
		radial.BackgroundTransparency = 0.35
		radial.BorderSizePixel = 0
		radial.Active = false
		radial.Visible = false
		radial.ZIndex = 4
		radial.Parent = button
		local radialCorner = Instance.new("UICorner")
		radialCorner.CornerRadius = UDim.new(1, 0)
		radialCorner.Parent = radial
		local sweep = Instance.new("UIGradient")
		sweep.Name = "Sweep"
		sweep.Rotation = 0
		sweep.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweep.Parent = radial
		local function pressed(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		button.InputEnded:Connect(function(input)
			if pressed(input) then
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
		button.Activated:Connect(function()
			if layoutEdit then
				return
			end
			fire()
		end)
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				if not layoutEdit then
					TweenService:Create(
						pop,
						TweenInfo.new(
							UiTheme.MOTION.pop,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out
						),
						{ Scale = CombatFeel.PRESS }
					):Play()
				end
			end
			if not layoutEdit then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local start = Vector2.new(input.Position.X, input.Position.Y)
			local originX = button.Position.X.Offset
			local originY = button.Position.Y.Offset
			local moveConn: RBXScriptConnection? = nil
			local endConn: RBXScriptConnection? = nil
			moveConn = UserInputService.InputChanged:Connect(function(changed)
				if
					changed.UserInputType ~= input.UserInputType
					and changed.UserInputType ~= Enum.UserInputType.MouseMovement
				then
					return
				end
				button.Position = UDim2.fromOffset(
					originX + changed.Position.X - start.X,
					originY + changed.Position.Y - start.Y
				)
			end)
			endConn = UserInputService.InputEnded:Connect(function(ended)
				if ended.UserInputType ~= input.UserInputType then
					return
				end
				if moveConn ~= nil then
					moveConn:Disconnect()
				end
				if endConn ~= nil then
					endConn:Disconnect()
				end
				callbacks.onLayout(name, button.Position.X.Offset, button.Position.Y.Offset)
			end)
		end)
		table.insert(skillButtons, button)
	end
	skillButton("Attack", callbacks.onAttack)
	skillButton("Dodge", callbacks.onDodge)
	skillButton("Skill1", function()
		callbacks.onSkill(1)
	end)
	skillButton("Skill2", function()
		callbacks.onSkill(2)
	end)
	skillButton("Ult", callbacks.onUlt)
	skillButton("Heavy", callbacks.onHeavy)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, button in ipairs(skillButtons) do
			local untilAt = button:GetAttribute("CooldownUntil")
			local total = button:GetAttribute("CooldownTotal")
			local cover = button:FindFirstChild("Radial")
			if
				cover ~= nil
				and cover:IsA("Frame")
				and type(untilAt) == "number"
				and type(total) == "number"
			then
				local remaining = untilAt - now
				local amount = CombatFeel.cooldownCover(total - remaining, total)
				local sweep = cover:FindFirstChild("Sweep")
				if sweep ~= nil and sweep:IsA("UIGradient") then
					sweep.Rotation = amount * 360
				end
				cover.Visible = amount > 0.02
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or layoutEdit then
			return
		end
		local keyName = input.KeyCode.Name
		if keyName == Keybinds.COMBAT.attack then
			callbacks.onAttack()
		elseif keyName == Keybinds.COMBAT.skill1 then
			callbacks.onSkill(1)
		elseif keyName == Keybinds.COMBAT.skill2 then
			callbacks.onSkill(2)
		elseif keyName == Keybinds.COMBAT.ult then
			callbacks.onUlt()
		end
	end)

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
	prompt.Parent = chrome
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
		button.Position = UDim2.fromOffset(x, 36)
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

	local function jumpRect(): (number, number, number)
		local touch = playerGui:FindFirstChild("TouchGui")
		local jump = if touch ~= nil then touch:FindFirstChild("JumpButton", true) else nil
		if jump ~= nil and jump:IsA("GuiObject") then
			local origin = screen.AbsolutePosition
			local pos = jump.AbsolutePosition
			return pos.X - origin.X, pos.Y - origin.Y, math.max(UiTheme.TOUCH, jump.AbsoluteSize.X)
		end
		local vx, vy = view()
		return vx - 88, vy - 88, 70
	end

	local function place()
		local vx, vy = view()
		local margin = UiTheme.safeMargin()
		local face = HudLayout.portrait(margin)
		portrait.Position = UDim2.fromOffset(face.x, face.y)
		portrait.Size = UDim2.fromOffset(face.w, face.h)
		local bar = HudLayout.health(margin)
		health.Position = UDim2.fromOffset(bar.x, bar.y)
		health.Size = UDim2.fromOffset(bar.w, bar.h)
		local row = HudLayout.pills(vx, margin)
		pills.Position = UDim2.fromOffset(row.x, row.y)
		pills.Size = UDim2.fromOffset(row.w, row.h)
		local side = HudLayout.railFit(vy, margin, #RAIL, UiTheme.TAP, UiTheme.TOUCH)
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
		local note = HudLayout.toast(vx, margin)
		toastHost.Position = UDim2.fromOffset(note.x, note.y)
		toastHost.Size =
			UDim2.fromOffset(note.w, note.h * ToastQueue.MAX + 8 * (ToastQueue.MAX - 1))
		for index, label in ipairs(toastLabels) do
			label.Position = UDim2.fromOffset(0, (index - 1) * (note.h + 8))
			label.Size = UDim2.fromOffset(note.w, note.h)
		end
		prompt.Position = UDim2.fromOffset(note.x, note.y + toastHost.Size.Y.Offset + 8)
		prompt.Size = UDim2.fromOffset(note.w, 36 + UiTheme.TOUCH + 8)
		local jx, jy, jw = jumpRect()
		local size = math.floor(UiTheme.TOUCH * buttonScale + 0.5)
		local slots = HudLayout.skills(vx, vy, jx, jy, jw, size)
		for index, button in ipairs(skillButtons) do
			button.Size = UDim2.fromOffset(size, size)
			local custom = savedLayout[button.Name]
			if custom ~= nil then
				button.Position = UDim2.fromOffset(custom[1], custom[2])
			else
				local slot = slots[index]
				if slot ~= nil then
					button.Position = UDim2.fromOffset(slot.x, slot.y)
				end
			end
		end
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
			local markCount = if type(profile) == "table" then profile.raidMarks or 0 else 0
			shards.Text = string.format("Shards %d", shardCount)
			marks.Text = string.format("Marks %d", markCount)
			dots.Hero.Visible = classDef == nil
			local heroButton = rail:FindFirstChild("Hero")
			if heroButton ~= nil then
				local tip = heroButton:FindFirstChild("Tip")
				if tip ~= nil and tip:IsA("TextLabel") then
					tip.Text = if classDef == nil then "Choose class" else "Hero"
				end
			end
			dots.Bag.Visible = false
			dots.Roll.Visible = shardCount > 0
			dots.Pets.Visible = type(profile) == "table" and (profile.eggs or 0) > 0
			dots.Market.Visible = false
			dots.Pass.Visible = type(profile) == "table" and profile.dailyBossReady == true
			dots.Settings.Visible = false
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
			buttonScale = 1
			layoutEdit = false
			savedLayout = {}
			local textScale = 1
			if type(settings) == "table" and type(settings.controls) == "table" then
				if type(settings.controls.mobileScale) == "number" then
					buttonScale = settings.controls.mobileScale
				end
				layoutEdit = settings.controls.layoutEdit == true
				if type(settings.controls.layout) == "table" then
					local nextLayout: { [string]: { number } } = {}
					for name, pair in pairs(settings.controls.layout) do
						if
							type(name) == "string"
							and type(pair) == "table"
							and type(pair[1]) == "number"
							and type(pair[2]) == "number"
						then
							nextLayout[name] = { pair[1], pair[2] }
						end
					end
					savedLayout = nextLayout
				end
			end
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
