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

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local CombatFeel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatFeel"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local HudShell = {}

export type Callbacks = {
	onMenu: () -> (),
	onRoll: () -> (),
	onPets: () -> (),
	onMarket: () -> (),
	onPass: () -> (),
	onSettings: () -> (),
	onAttack: () -> (),
	onDodge: () -> (),
	onSkill: (number) -> (),
	onUlt: () -> (),
	onLayout: (string, number, number) -> (),
}

local RAIL = {
	{ id = "Menu", call = "onMenu" },
	{ id = "Roll", call = "onRoll" },
	{ id = "Pets", call = "onPets" },
	{ id = "Market", call = "onMarket" },
	{ id = "Pass", call = "onPass" },
	{ id = "Settings", call = "onSettings" },
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
	for index, entry in ipairs(RAIL) do
		local button = Instance.new("TextButton")
		button.Name = entry.id
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TAP)
		button.BackgroundColor3 = rgb("button")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("text")
		button.Text = if entry.id == "Settings" then "Gear" else entry.id
		button.Parent = rail
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = button
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 6)
		icon.Size = UDim2.fromOffset(22, 22)
		icon.BackgroundColor3 = rgb("gold")
		icon.BorderSizePixel = 0
		icon.Parent = button
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(1, 0)
		iconCorner.Parent = icon
		local glyph = Instance.new("TextLabel")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Font = Enum.Font.BuilderSansBold
		glyph.TextSize = UiTheme.MIN_TEXT
		glyph.TextColor3 = rgb("ink")
		glyph.Text = string.sub(entry.id, 1, 1)
		glyph.Parent = icon
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -2, 0, 2)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = rgb("ok")
		dot.BorderSizePixel = 0
		dot.Visible = false
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
	local hubOpen = false
	local function skillButton(name: string, text: string, fire: () -> ())
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("buttonDim")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("text")
		button.Text = text
		button.Parent = skills
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = button
		local pop = Instance.new("UIScale")
		pop.Name = "Press"
		pop.Parent = button
		local radial = Instance.new("Frame")
		radial.Name = "Radial"
		radial.AnchorPoint = Vector2.new(0, 1)
		radial.Position = UDim2.fromScale(0, 1)
		radial.Size = UDim2.fromScale(1, 0)
		radial.BackgroundColor3 = Color3.new(0, 0, 0)
		radial.BackgroundTransparency = 0.4
		radial.BorderSizePixel = 0
		radial.Active = false
		radial.Visible = false
		radial.ZIndex = 3
		radial.Parent = button
		local radialCorner = Instance.new("UICorner")
		radialCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		radialCorner.Parent = radial
		local function pressed(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		button.InputEnded:Connect(function(input)
			if pressed(input) then
				pop.Scale = 1
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
					pop.Scale = CombatFeel.PRESS
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
	skillButton("Attack", "Atk", callbacks.onAttack)
	skillButton("Dodge", "Dodge", callbacks.onDodge)
	skillButton("Skill1", "1", function()
		callbacks.onSkill(1)
	end)
	skillButton("Skill2", "2", function()
		callbacks.onSkill(2)
	end)
	skillButton("Ult", "Ult", callbacks.onUlt)
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
				cover.Size = UDim2.fromScale(1, amount)
				cover.Visible = amount > 0.02
			end
		end
	end)

	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.BackgroundColor3 = rgb("panel")
	toast.BackgroundTransparency = 0.08
	toast.Font = Enum.Font.BuilderSansBold
	toast.TextSize = UiTheme.MIN_TEXT
	toast.TextColor3 = rgb("text")
	toast.Text = ""
	toast.Visible = false
	toast.Parent = chrome
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

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
		local side = HudLayout.rail(vy, margin, #RAIL, UiTheme.TAP)
		rail.Position = UDim2.fromOffset(side.x, side.y)
		rail.Size = UDim2.fromOffset(side.w, side.h)
		local note = HudLayout.toast(vx, margin)
		toast.Position = UDim2.fromOffset(note.x, note.y)
		toast.Size = UDim2.fromOffset(note.w, note.h)
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
			dots.Roll.Visible = shardCount > 0
			dots.Pets.Visible = type(profile) == "table" and (profile.eggs or 0) > 0
			dots.Pass.Visible = type(profile) == "table" and profile.dailyBossReady == true
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
			elseif hubOpen then
				chrome.GroupTransparency = 0.45
			else
				chrome.GroupTransparency = 0
			end
		end,
		toast = function(text: string)
			toast.Text = text
			toast.Visible = text ~= ""
		end,
		setDimmed = function(open: boolean)
			hubOpen = open
			if hudHidden then
				chrome.GroupTransparency = 1
				return
			end
			local goal = if open then 0.45 else 0
			TweenService:Create(
				chrome,
				TweenInfo.new(UiTheme.MOTION.open, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ GroupTransparency = goal }
			):Play()
		end,
		place = place,
		ratio = function(): number
			return shownRatio
		end,
	}
end

return HudShell
