--!strict

--[[
	One modal stack. Tabs replace each other. Esc and the backdrop pop.
	The panel is a Frame, so the first open still receives tab clicks.
	The backdrop dim is copied off UiRouter on every open and every close.
	Debug grants live here and only while Studio is running.

	Bag, pets, roll, and hero draw cards. Market, raids, and the pass
	use an empty state. A missing class opens the class cards.

	The roll tab presents the server result. RollHype tracks the session,
	the legendary pity bar, and the full-animation build-up. The client
	does not decide the roll.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BagBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BagBoard"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ClientChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientChrome"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local HeroBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeroBoard"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local InventoryView =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryView"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))
local NotifyBadges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NotifyBadges"))
local Pools = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pools"))
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))
local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RarityConfig"))
local RollBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollBoard"))
local RollHype = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollHype"))
local RollLoop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollLoop"))
local RollMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollMath"))
local RollReveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollReveal"))
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))
local Stats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stats"))
local UiIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiIcons"))
local UiMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiMotion"))
local UiSfx = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiSfx"))
local UiRouter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiRouter"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local ClassHud = require(script.Parent.ClassHud)

local MenuHub = {}

export type Hooks = {
	invoke: (string, ...any) -> any,
	onRoll: (() -> ())?,
	onBag: () -> (),
	onMarket: () -> (),
	onDim: (boolean) -> (),
	onTab: ((string) -> ())?,
	onBadges: (({ [string]: NotifyBadges.Badge }) -> ())?,
	getPoolId: (() -> string)?,
}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	return Color3.fromRGB(row[1], row[2], row[3])
end

local function headerFont(): Enum.Font
	return Enum.Font.BuilderSansBold
end

local function bodyFont(): Enum.Font
	return Enum.Font.BuilderSans
end

function MenuHub.start(playerGui: PlayerGui, hooks: Hooks)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallHub"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 80
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Enabled = false
	screen.Parent = playerGui
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "HubScale"
	uiScale.Scale = 1
	uiScale.Parent = screen

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1 - UiTheme.BACKDROP
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Modal = false
	backdrop.Active = true
	backdrop.ZIndex = 1
	backdrop.Parent = screen

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = rgb("shadow")
	shadow.BackgroundTransparency = UiTheme.SHADOW
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 2
	shadow.Visible = false
	shadow.Parent = screen
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	shadowCorner.Parent = shadow

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = rgb("body")
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 3
	panel.Parent = screen
	local openScale = Instance.new("UIScale")
	openScale.Name = "OpenScale"
	openScale.Scale = 1
	openScale.Parent = panel
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = UiTheme.STROKE
	panelStroke.Color = rgb("divider")
	panelStroke.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(rgb("header"), rgb("body"))
	gradient.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, UiTheme.HEADER)
	header.BackgroundColor3 = rgb("header")
	header.BackgroundTransparency = 0.08
	header.BorderSizePixel = 0
	header.ZIndex = 4
	header.Parent = panel
	local headerRule = Instance.new("Frame")
	headerRule.Name = "Divider"
	headerRule.AnchorPoint = Vector2.new(0, 1)
	headerRule.Position = UDim2.fromScale(0, 1)
	headerRule.Size = UDim2.new(1, 0, 0, 1)
	headerRule.BackgroundColor3 = rgb("divider")
	headerRule.BorderSizePixel = 0
	headerRule.Parent = header

	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollBarThickness = 4
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.CanvasSize = UDim2.new()
	tabs.ZIndex = 4
	tabs.Parent = panel
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Vertical
	tabList.Padding = UDim.new(0, UiTheme.PAD)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.ZIndex = 4
	body.Parent = panel
	local tabScale = Instance.new("UIScale")
	tabScale.Name = "TabScale"
	tabScale.Scale = 1
	tabScale.Parent = body

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(148, 8)
	title.Size = UDim2.new(1, -220, 0, 32)
	title.Font = headerFont()
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = rgb("text")
	title.Text = "Menu"
	title.ZIndex = 5
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -8, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	closeButton.BackgroundColor3 = rgb("body")
	closeButton.Font = headerFont()
	closeButton.TextSize = UiTheme.MIN_TEXT
	closeButton.TextColor3 = rgb("text")
	closeButton.Text = "X"
	closeButton.ZIndex = 5
	closeButton.Parent = header
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = UiTheme.STROKE
	closeStroke.Color = rgb("divider")
	closeStroke.Parent = closeButton

	local classModal = Instance.new("Frame")
	classModal.Name = "ClassPick"
	classModal.Size = UDim2.fromScale(1, 1)
	classModal.BackgroundTransparency = 1
	classModal.Visible = false
	classModal.Active = false
	classModal.ZIndex = 8
	classModal.Parent = screen
	local classPanel = Instance.new("Frame")
	classPanel.Name = "Card"
	classPanel.BackgroundColor3 = rgb("body")
	classPanel.BorderSizePixel = 0
	classPanel.ZIndex = 9
	classPanel.Parent = classModal
	local classCorner = Instance.new("UICorner")
	classCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	classCorner.Parent = classPanel
	local classStroke = Instance.new("UIStroke")
	classStroke.Thickness = UiTheme.STROKE_BOLD
	classStroke.Color = rgb("accent")
	classStroke.Parent = classPanel
	local classGradient = Instance.new("UIGradient")
	classGradient.Rotation = 90
	classGradient.Color = ColorSequence.new(rgb("header"), rgb("body"))
	classGradient.Parent = classPanel
	local classHeader = Instance.new("TextLabel")
	classHeader.Name = "Title"
	classHeader.BackgroundTransparency = 1
	classHeader.Position = UDim2.fromOffset(16, 8)
	classHeader.Size = UDim2.new(1, -80, 0, 32)
	classHeader.Font = headerFont()
	classHeader.TextSize = 20
	classHeader.TextXAlignment = Enum.TextXAlignment.Left
	classHeader.TextColor3 = rgb("text")
	classHeader.Text = "Choose a class"
	classHeader.ZIndex = 10
	classHeader.Parent = classPanel
	local classClose = Instance.new("TextButton")
	classClose.Name = "Close"
	classClose.AnchorPoint = Vector2.new(1, 0)
	classClose.Position = UDim2.new(1, -8, 0, 8)
	classClose.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	classClose.BackgroundColor3 = rgb("header")
	classClose.Font = headerFont()
	classClose.TextSize = UiTheme.MIN_TEXT
	classClose.TextColor3 = rgb("text")
	classClose.Text = "X"
	classClose.ZIndex = 10
	classClose.Parent = classPanel
	local classCloseCorner = Instance.new("UICorner")
	classCloseCorner.CornerRadius = UDim.new(0, 8)
	classCloseCorner.Parent = classClose
	local classList = Instance.new("ScrollingFrame")
	classList.Name = "Cards"
	classList.Position = UDim2.fromOffset(12, 56)
	classList.Size = UDim2.new(1, -24, 1, -68)
	classList.BackgroundTransparency = 1
	classList.BorderSizePixel = 0
	classList.ScrollBarThickness = 6
	classList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	classList.CanvasSize = UDim2.new()
	classList.ZIndex = 10
	classList.Parent = classPanel
	local classGrid = Instance.new("UIGridLayout")
	classGrid.SortOrder = Enum.SortOrder.LayoutOrder
	classGrid.Parent = classList

	local profile: any = nil
	local draft = Settings.default()
	local route = UiRouter.initial()
	local apply: (UiRouter.State) -> ()
	local pages: { [string]: Frame } = {}
	local capturing: string? = nil
	local bindNote: string? = nil
	local classDismissed = false
	local detailOpen = false
	local selectedUid: string? = nil
	local autoOn = false
	local quickOn = false
	local infoOpen = false
	local bagFilter = BagBoard.defaultFilter()
	local seen = NotifyBadges.blank()
	local salvageRarity = "Rare"
	local salvageArmed = false
	local stopAt = "Off"
	local loop = RollLoop.idle()
	local holdingRoll = false
	local rollBusy = false
	local playerAlive = true
	local openedHype = RollHype.fresh(nil)
	local hype: RollHype.Session = if openedHype.ok
		then openedHype.state
		else {
			rolls = 0,
			streak = 0,
			best = nil,
			personalBest = false,
			allTime = nil,
		}
	local bestPull: any = nil
	local slideHistory = false
	local revealToken = 0
	local lastCrack = 0
	local pityTween: Tween? = nil
	local serverSince: number? = nil
	local serverEpic: number? = nil
	local lastMissed = false
	local lastLanded: string? = nil
	local toastToken = 0
	local sessionRolls: { any } = {}
	local sessionTemplates: { string } = {}
	local activeReveal: {
		started: number,
		duration: number,
		rarity: string,
		tier: number?,
		flashed: boolean,
		nextTick: number,
		slots: { UiRouter.ReelSlot }?,
	}? =
		nil
	local paintReelIdle: (string) -> () = function(_caption: string) end
	local showMilestone: (string) -> () = function(_text: string) end
	local tabDots: { [string]: Frame } = {}
	local restColor: { [GuiButton]: Color3 } = {}
	local tabButtons: { [string]: TextButton } = {}
	local tabAccents: { [string]: Frame } = {}
	local tabCaptions: { [string]: TextLabel } = {}
	local openTween: Tween? = nil
	local worldBlocked = false
	local controls: any = nil

	local function sink(): Enum.ContextActionResult
		return Enum.ContextActionResult.Sink
	end

	local function playerControls(): any
		if controls ~= nil then
			return controls
		end
		local localPlayer = Players.LocalPlayer
		if localPlayer == nil then
			return nil
		end
		local scripts = localPlayer:FindFirstChild("PlayerScripts")
		if scripts == nil then
			return nil
		end
		local moduleScript = scripts:FindFirstChild("PlayerModule")
		if moduleScript == nil or not moduleScript:IsA("ModuleScript") then
			return nil
		end
		local ok, module = pcall(require, moduleScript)
		if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then
			return nil
		end
		local fetchedOk, fetched = pcall(function()
			return module:GetControls()
		end)
		if fetchedOk then
			controls = fetched
		end
		return controls
	end

	-- Modal on the backdrop stops the mouse from steering the camera.
	-- The sink stops movement, sprint, and combat. Tab letters stay free.
	local function bindSinkKeys()
		ContextActionService:UnbindAction("ShardfallMenuSink")
		local codes = {}
		for _, name in ipairs(Keybinds.sinkNames()) do
			local code = (Enum.KeyCode :: any)[name]
			if code ~= nil then
				table.insert(codes, code)
			end
		end
		ContextActionService:BindActionAtPriority(
			"ShardfallMenuSink",
			sink,
			false,
			Enum.ContextActionPriority.High.Value,
			table.unpack(codes)
		)
	end

	local function setWorldInput(blocked: boolean)
		if blocked == worldBlocked then
			return
		end
		worldBlocked = blocked
		if blocked then
			bindSinkKeys()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		else
			ContextActionService:UnbindAction("ShardfallMenuSink")
		end
		local pad = playerControls()
		if type(pad) == "table" then
			if blocked and type(pad.Disable) == "function" then
				pcall(function()
					pad:Disable()
				end)
			elseif type(pad.Enable) == "function" then
				pcall(function()
					pad:Enable()
				end)
			end
		end
	end

	local function view(): (number, number)
		local size = screen.AbsoluteSize
		return if size.X >= 200 then size.X else 1280, if size.Y >= 200 then size.Y else 800
	end

	local fitRoll: () -> () = function() end

	local function place()
		local vx, vy = view()
		local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
		shadow.Position = UDim2.fromOffset(box.x + 4, box.y + 6)
		shadow.Size = UDim2.fromOffset(box.w, box.h)
		local column = HudLayout.tabColumn(box.w, box.h)
		tabs.Position = UDim2.fromOffset(column.x, UiTheme.HEADER)
		tabs.Size = UDim2.fromOffset(column.w, math.max(44, box.h - UiTheme.HEADER - 8))
		local inner = HudLayout.hubBody(box.w, box.h)
		body.Position = UDim2.fromOffset(inner.x, inner.y)
		body.Size = UDim2.fromOffset(inner.w, inner.h)
		title.Position = UDim2.fromOffset(inner.x, 8)
		title.Size = UDim2.fromOffset(math.max(44, inner.w - 8), 32)
		classPanel.Position = UDim2.fromOffset(box.x + inner.x, box.y + inner.y)
		classPanel.Size = UDim2.fromOffset(inner.w, inner.h)
		local grid = HudLayout.cardGrid(math.max(44, inner.w - 8), inner.h, 4)
		classGrid.CellSize = UDim2.fromOffset(grid.cellW, grid.cellH)
		classGrid.CellPadding = UDim2.fromOffset(grid.gap, grid.gap)
		fitRoll()
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	local shownId = ""

	local function playUi(action: string)
		local volume = UiSfx.volume(draft.audio.master, draft.audio.ui)
		if volume <= 0 then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "UiSfx"
		sound.SoundId = UiSfx.clip(action)
		sound.Volume = volume
		sound.Parent = screen
		sound:Play()
		task.delay(1.5, function()
			sound:Destroy()
		end)
	end

	local function motion(button: GuiButton)
		local pop = Instance.new("UIScale")
		pop.Name = "Press"
		pop.Parent = button
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = rgb("hover")
		end)
		button.MouseLeave:Connect(function()
			local rest = restColor[button]
			button.BackgroundColor3 = if rest ~= nil then rest else rgb("body")
		end)
		local function pressed(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		button.InputBegan:Connect(function(input)
			if pressed(input) then
				button.BackgroundColor3 = rgb("press")
				playUi("press")
				local length = UiMotion.press(UiMotion.reduced(draft))
				if length <= 0 then
					pop.Scale = 0.96
				else
					TweenService:Create(
						pop,
						TweenInfo.new(length, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 0.96 }
					):Play()
				end
			end
		end)
		button.InputEnded:Connect(function(input)
			if pressed(input) then
				local rest = restColor[button]
				button.BackgroundColor3 = if rest ~= nil then rest else rgb("body")
				local length = UiMotion.press(UiMotion.reduced(draft))
				if length <= 0 then
					pop.Scale = 1
				else
					TweenService:Create(
						pop,
						TweenInfo.new(length, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
			end
		end)
	end

	local function setRest(button: GuiButton, color: Color3)
		restColor[button] = color
		button.BackgroundColor3 = color
	end

	motion(closeButton)
	setRest(closeButton, rgb("body"))
	motion(classClose)
	setRest(classClose, rgb("header"))

	local function iconOn(parent: Instance, name: string, px: number, py: number, size: number)
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.BackgroundTransparency = 1
		image.Position = UDim2.fromOffset(px, py)
		image.Size = UDim2.fromOffset(size, size)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = UiIcons.get(name)
		local red, green, blue = UiIcons.tintOf(name)
		image.ImageColor3 = Color3.fromRGB(red, green, blue)
		image.ZIndex = 6
		image.Parent = parent
		return image
	end

	local function page(id: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = id
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.Parent = body
		pages[id] = frame
		return frame
	end

	local function scroll(host: Frame): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.Size = UDim2.fromScale(1, 1)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Parent = host
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, UiTheme.GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, UiTheme.PAD)
		pad.PaddingBottom = UDim.new(0, UiTheme.PAD)
		pad.PaddingLeft = UDim.new(0, UiTheme.PAD)
		pad.PaddingRight = UDim.new(0, UiTheme.PAD)
		pad.Parent = list
		return list
	end

	local function clear(host: Instance)
		for _, child in ipairs(host:GetChildren()) do
			if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then
				continue
			end
			child:Destroy()
		end
	end

	local function applyGrid(host: ScrollingFrame, count: number)
		local layout = host:FindFirstChildOfClass("UIGridLayout")
		if layout == nil then
			return
		end
		local width = host.AbsoluteSize.X
		local height = host.AbsoluteSize.Y
		if width < 44 then
			local vx, vy = view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			width = inner.w
			height = inner.h
		end
		local spec = HudLayout.cardGrid(math.max(44, width - 16), math.max(44, height), count)
		layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
		layout.CellPadding = UDim2.fromOffset(spec.gap, spec.gap)
	end

	local hero = scroll(page("hero"))
	local bag = scroll(page("bag"))
	local sets = scroll(page("sets"))
	local pets = scroll(page("pets"))
	local rollPage = page("roll")
	local roll = scroll(rollPage)
	roll.Size = UDim2.new(1, 0, 1, -88)

	local rollButton = Instance.new("TextButton")
	rollButton.Name = "Roll"
	rollButton.AnchorPoint = Vector2.new(0, 1)
	rollButton.Position = UDim2.new(0, UiTheme.PAD, 1, -UiTheme.PAD)
	rollButton.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 72)
	rollButton.BackgroundColor3 = rgb("button")
	rollButton.Font = headerFont()
	rollButton.TextSize = 28
	rollButton.TextColor3 = rgb("text")
	rollButton.Text = "Roll"
	rollButton.AutoButtonColor = false
	rollButton.ZIndex = 6
	rollButton.Parent = rollPage
	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	rollCorner.Parent = rollButton
	local rollStroke = Instance.new("UIStroke")
	rollStroke.Thickness = UiTheme.STROKE_BOLD
	rollStroke.Color = rgb("accent")
	rollStroke.Parent = rollButton
	local pulseScale = Instance.new("UIScale")
	pulseScale.Name = "Pulse"
	pulseScale.Parent = rollButton
	local pressScale = Instance.new("UIScale")
	pressScale.Name = "Press"
	pressScale.Parent = rollButton
	local pulseTween: Tween? = nil

	local function setPulse(on: boolean)
		if pulseTween ~= nil then
			pulseTween:Cancel()
			pulseTween = nil
		end
		if not on or UiMotion.reduced(draft) then
			pulseScale.Scale = 1
			return
		end
		pulseScale.Scale = 1
		local tween = TweenService:Create(
			pulseScale,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.06 }
		)
		pulseTween = tween
		tween:Play()
	end

	local function stopRollChain()
		revealToken += 1
		holdingRoll = false
		activeReveal = nil
		loop = RollLoop.idle()
		rollBusy = false
		setPulse(true)
		paintReelIdle("Roll")
	end

	local revealCard = Instance.new("Frame")
	revealCard.Name = "Reveal"
	revealCard.AnchorPoint = Vector2.new(0.5, 1)
	revealCard.Position = UDim2.new(0.5, 0, 1, -96)
	revealCard.Size = UDim2.new(1, -24, 0, 112)
	revealCard.BackgroundColor3 = rgb("header")
	revealCard.BorderSizePixel = 0
	revealCard.ClipsDescendants = true
	revealCard.Visible = false
	revealCard.ZIndex = 8
	revealCard.Parent = rollPage
	local revealCorner = Instance.new("UICorner")
	revealCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	revealCorner.Parent = revealCard
	local revealStroke = Instance.new("UIStroke")
	revealStroke.Thickness = UiTheme.STROKE
	revealStroke.Color = rgb("accent")
	revealStroke.Parent = revealCard
	local revealScale = Instance.new("UIScale")
	revealScale.Name = "Card"
	revealScale.Parent = revealCard
	local revealTitle = Instance.new("TextLabel")
	revealTitle.Name = "Name"
	revealTitle.BackgroundTransparency = 1
	revealTitle.Position = UDim2.fromOffset(12, 8)
	revealTitle.Size = UDim2.new(1, -120, 0, 32)
	revealTitle.Font = headerFont()
	revealTitle.TextSize = 22
	revealTitle.TextXAlignment = Enum.TextXAlignment.Left
	revealTitle.TextColor3 = rgb("text")
	revealTitle.Text = ""
	revealTitle.ZIndex = 9
	revealTitle.Parent = revealCard
	local revealRarity = Instance.new("TextLabel")
	revealRarity.Name = "Rarity"
	revealRarity.BackgroundTransparency = 1
	revealRarity.Position = UDim2.fromOffset(12, 40)
	revealRarity.Size = UDim2.new(1, -120, 0, 24)
	revealRarity.Font = bodyFont()
	revealRarity.TextSize = UiTheme.MIN_TEXT
	revealRarity.TextXAlignment = Enum.TextXAlignment.Left
	revealRarity.TextColor3 = rgb("text")
	revealRarity.Text = ""
	revealRarity.ZIndex = 9
	revealRarity.Parent = revealCard
	local revealNew = Instance.new("TextLabel")
	revealNew.Name = "New"
	revealNew.AnchorPoint = Vector2.new(1, 0)
	revealNew.Position = UDim2.new(1, -8, 0, 8)
	revealNew.Size = UDim2.fromOffset(72, 28)
	revealNew.BackgroundColor3 = rgb("accent")
	revealNew.Font = headerFont()
	revealNew.TextSize = UiTheme.MIN_TEXT
	revealNew.TextColor3 = rgb("ink")
	revealNew.Text = "NEW!"
	revealNew.Visible = false
	revealNew.ZIndex = 9
	revealNew.Parent = revealCard
	local newCorner = Instance.new("UICorner")
	newCorner.CornerRadius = UDim.new(0, 8)
	newCorner.Parent = revealNew
	local revealBest = Instance.new("TextLabel")
	revealBest.Name = "PersonalBest"
	revealBest.AnchorPoint = Vector2.new(1, 0)
	revealBest.Position = UDim2.new(1, -8, 0, 40)
	revealBest.Size = UDim2.fromOffset(120, 28)
	revealBest.BackgroundColor3 = rgb("gold")
	revealBest.Font = headerFont()
	revealBest.TextSize = UiTheme.MIN_TEXT
	revealBest.TextColor3 = rgb("ink")
	revealBest.Text = ""
	revealBest.Visible = false
	revealBest.ZIndex = 9
	revealBest.Parent = revealCard
	local bestCorner = Instance.new("UICorner")
	bestCorner.CornerRadius = UDim.new(0, 8)
	bestCorner.Parent = revealBest
	local revealFly = Instance.new("TextLabel")
	revealFly.Name = "Drip"
	revealFly.BackgroundTransparency = 1
	revealFly.Position = UDim2.fromOffset(12, 72)
	revealFly.Size = UDim2.fromOffset(80, 28)
	revealFly.Font = headerFont()
	revealFly.TextSize = 20
	revealFly.TextXAlignment = Enum.TextXAlignment.Left
	revealFly.TextColor3 = rgb("ok")
	revealFly.Text = "+1"
	revealFly.ZIndex = 9
	revealFly.Parent = revealCard
	local revealEquip = Instance.new("TextButton")
	revealEquip.Name = "Equip"
	revealEquip.AnchorPoint = Vector2.new(1, 1)
	revealEquip.Position = UDim2.new(1, -8, 1, -8)
	revealEquip.Size = UDim2.fromOffset(120, UiTheme.TOUCH)
	revealEquip.BackgroundColor3 = rgb("ok")
	revealEquip.Font = headerFont()
	revealEquip.TextSize = UiTheme.MIN_TEXT
	revealEquip.TextColor3 = rgb("ink")
	revealEquip.Text = "▲ Equip"
	revealEquip.AutoButtonColor = false
	revealEquip.Visible = false
	revealEquip.ZIndex = 9
	revealEquip.Parent = revealCard
	local revealEquipCorner = Instance.new("UICorner")
	revealEquipCorner.CornerRadius = UDim.new(0, 8)
	revealEquipCorner.Parent = revealEquip
	local flashCover = Instance.new("Frame")
	flashCover.Name = "Flash"
	flashCover.Size = UDim2.fromScale(1, 1)
	flashCover.BackgroundColor3 = Color3.new(1, 1, 1)
	flashCover.BackgroundTransparency = 1
	flashCover.BorderSizePixel = 0
	flashCover.Active = false
	flashCover.ZIndex = 12
	flashCover.Parent = rollPage

	local reelHost = Instance.new("Frame")
	reelHost.Name = "Reel"
	reelHost.Position = UDim2.fromOffset(UiTheme.PAD, UiTheme.PAD)
	reelHost.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 68)
	reelHost.BackgroundColor3 = rgb("header")
	reelHost.BorderSizePixel = 0
	reelHost.ClipsDescendants = true
	reelHost.ZIndex = 6
	reelHost.Parent = rollPage
	local reelCorner = Instance.new("UICorner")
	reelCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	reelCorner.Parent = reelHost
	local reelStroke = Instance.new("UIStroke")
	reelStroke.Name = "Glow"
	reelStroke.Thickness = UiTheme.STROKE_BOLD
	reelStroke.Color = rgb("accent")
	reelStroke.Parent = reelHost
	local reelStreak = Instance.new("TextLabel")
	reelStreak.Name = "Streak"
	reelStreak.BackgroundTransparency = 1
	reelStreak.Position = UDim2.fromOffset(8, 2)
	reelStreak.Size = UDim2.new(1, -16, 0, 18)
	reelStreak.Font = headerFont()
	reelStreak.TextSize = UiTheme.MIN_TEXT
	reelStreak.TextXAlignment = Enum.TextXAlignment.Left
	reelStreak.TextColor3 = rgb("gold")
	reelStreak.Text = "Streak  0"
	reelStreak.ZIndex = 7
	reelStreak.Parent = reelHost
	local function reelWindow(name: string, xScale: number, widthScale: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.new(xScale, 4, 0, 22)
		label.Size = UDim2.new(widthScale, -8, 1, -28)
		label.BackgroundColor3 = rgb("body")
		label.Font = headerFont()
		label.TextSize = UiTheme.MIN_TEXT
		label.TextColor3 = rgb("text")
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = "—"
		label.ZIndex = 7
		label.Parent = reelHost
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		return label
	end
	local reelLeft = reelWindow("Left", 0, 0.28)
	local reelCenter = reelWindow("Center", 0.28, 0.44)
	local reelRight = reelWindow("Right", 0.72, 0.28)
	reelCenter.Text = "Roll"
	local reelMilestone = Instance.new("TextLabel")
	reelMilestone.Name = "Milestone"
	reelMilestone.Size = UDim2.fromScale(1, 1)
	reelMilestone.BackgroundColor3 = rgb("gold")
	reelMilestone.Font = headerFont()
	reelMilestone.TextSize = 20
	reelMilestone.TextColor3 = rgb("ink")
	reelMilestone.Text = ""
	reelMilestone.Visible = false
	reelMilestone.Active = false
	reelMilestone.ZIndex = 9
	reelMilestone.Parent = reelHost
	local milestoneCorner = Instance.new("UICorner")
	milestoneCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	milestoneCorner.Parent = reelMilestone

	local function rarityColor3(name: string): Color3
		local row = Rarities.COLOR[name]
		if type(row) ~= "table" then
			local red, green, blue = UiTheme.rarityColor("Common")
			return Color3.fromRGB(red, green, blue)
		end
		return Color3.fromRGB(row[1], row[2], row[3])
	end

	local function paintWindow(label: TextLabel, slotName: string, rarity: string, focus: boolean)
		label.Text = slotName
		label.TextColor3 = if focus then rgb("ink") else rgb("text")
		label.BackgroundColor3 = if focus then rarityColor3(rarity) else rgb("body")
	end

	local function paintReel(slots: { UiRouter.ReelSlot }?, index: number)
		local function at(slotIndex: number): (string, string)
			if slots == nil or slotIndex < 1 or slotIndex > #slots then
				return "—", "Common"
			end
			local row = slots[slotIndex]
			return row.name, row.rarity
		end
		local leftName, leftRarity = at(index - 1)
		local midName, midRarity = at(index)
		local rightName, rightRarity = at(index + 1)
		paintWindow(reelLeft, leftName, leftRarity, false)
		paintWindow(reelCenter, midName, midRarity, slots ~= nil)
		paintWindow(reelRight, rightName, rightRarity, false)
		if slots ~= nil then
			reelStroke.Color = rarityColor3(midRarity)
		end
	end

	paintReelIdle = function(caption: string)
		reelStreak.Text = UiRouter.streakText(hype.streak, lastMissed)
		reelStreak.TextColor3 = rgb(UiRouter.streakTone(hype.streak, lastMissed))
		paintWindow(reelLeft, "—", "Common", false)
		paintWindow(reelCenter, caption, "Common", false)
		paintWindow(reelRight, "—", "Common", false)
		reelCenter.TextColor3 = rgb("text")
		reelCenter.BackgroundColor3 = rgb("body")
		reelStroke.Color = if hype.streak >= 5 then rgb("gold") else rgb("accent")
	end

	showMilestone = function(text: string)
		toastToken += 1
		local token = toastToken
		reelMilestone.Text = text
		reelMilestone.Visible = true
		playUi("toast")
		task.delay(1.8, function()
			if token == toastToken then
				reelMilestone.Visible = false
			end
		end)
	end

	local function flashPersonalBest(rarity: string)
		revealBest.Text = rarity
		revealBest.Visible = true
		revealBest.BackgroundColor3 = rarityColor3(rarity)
		flashCover.BackgroundColor3 = rarityColor3(rarity)
		if UiMotion.reduced(draft) or draft.camera.flash == "reduced" then
			flashCover.BackgroundTransparency = 1
			return
		end
		flashCover.BackgroundTransparency = 0.45
		TweenService:Create(
			flashCover,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		):Play()
	end

	fitRoll = function()
		local height = rollPage.AbsoluteSize.Y
		if height < 80 then
			local vx, vy = view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			height = inner.h
		end
		local chrome = UiRouter.rollChrome(height)
		reelHost.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, chrome.reel)
		local compact = chrome.reel < 52
		reelStreak.Visible = not compact
		local windowTop = if compact then 4 else 22
		local windowTrim = if compact then 8 else 28
		local function placeWindow(label: TextLabel)
			label.Position = UDim2.new(label.Position.X.Scale, 4, 0, windowTop)
			label.Size = UDim2.new(label.Size.X.Scale, -8, 1, -windowTrim)
		end
		placeWindow(reelLeft)
		placeWindow(reelCenter)
		placeWindow(reelRight)
		rollButton.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, chrome.button)
		local buttonText = if chrome.button < 56 then 20 else 28
		rollButton.TextSize = buttonText
		rollButton:SetAttribute("BaseText", buttonText)
		local listTop = chrome.reel + UiTheme.PAD
		roll.Position = UDim2.fromOffset(0, listTop)
		roll.Size = UDim2.new(1, 0, 1, -(listTop + chrome.button + UiTheme.PAD))
		revealCard.Size = UDim2.new(1, -24, 0, chrome.card)
		revealCard.Position = UDim2.new(0.5, 0, 1, -(chrome.button + UiTheme.PAD + 4))
		if chrome.card < 88 then
			revealFly.Visible = false
			revealEquip.Size = UDim2.fromOffset(88, 36)
		else
			revealFly.Visible = true
			revealEquip.Size = UDim2.fromOffset(120, UiTheme.TOUCH)
		end
	end
	fitRoll()
	paintReelIdle("Roll")
	setPulse(true)
	local raids = scroll(page("raids"))
	local market = scroll(page("market"))
	local pass = scroll(page("pass"))
	local settingsPage = scroll(page("settings"))

	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.Size = UDim2.fromScale(1, 1)
	detail.BackgroundColor3 = rgb("body")
	detail.BackgroundTransparency = 0.02
	detail.BorderSizePixel = 0
	detail.Visible = false
	detail.ZIndex = 7
	detail.Parent = body
	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	detailCorner.Parent = detail
	local detailStroke = Instance.new("UIStroke")
	detailStroke.Thickness = UiTheme.STROKE
	detailStroke.Color = rgb("divider")
	detailStroke.Parent = detail
	local detailList = Instance.new("ScrollingFrame")
	detailList.Name = "Compare"
	detailList.Position = UDim2.fromOffset(0, 52)
	detailList.Size = UDim2.new(1, 0, 1, -52)
	detailList.BackgroundTransparency = 1
	detailList.BorderSizePixel = 0
	detailList.ScrollBarThickness = 6
	detailList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailList.CanvasSize = UDim2.new()
	detailList.ZIndex = 8
	detailList.Parent = detail
	local detailLayout = Instance.new("UIListLayout")
	detailLayout.Padding = UDim.new(0, UiTheme.PAD)
	detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailLayout.Parent = detailList
	local detailPad = Instance.new("UIPadding")
	detailPad.PaddingLeft = UDim.new(0, UiTheme.GAP)
	detailPad.PaddingRight = UDim.new(0, UiTheme.GAP)
	detailPad.Parent = detailList
	local detailBack = Instance.new("TextButton")
	detailBack.Name = "Back"
	detailBack.Position = UDim2.fromOffset(8, 4)
	detailBack.Size = UDim2.fromOffset(88, UiTheme.TOUCH)
	detailBack.BackgroundColor3 = rgb("header")
	detailBack.Font = headerFont()
	detailBack.TextSize = UiTheme.MIN_TEXT
	detailBack.TextColor3 = rgb("text")
	detailBack.Text = "Back"
	detailBack.ZIndex = 8
	detailBack.Parent = detail
	local detailBackCorner = Instance.new("UICorner")
	detailBackCorner.CornerRadius = UDim.new(0, 8)
	detailBackCorner.Parent = detailBack
	motion(detailBack)
	setRest(detailBack, rgb("header"))

	local function save()
		task.spawn(function()
			pcall(hooks.invoke, "SetSettings", draft)
		end)
	end

	local function paintTabs(current: string)
		for id, button in pairs(tabButtons) do
			local on = id == current
			setRest(button, if on then rgb("header") else rgb("body"))
			local accent = tabAccents[id]
			if accent ~= nil then
				accent.Visible = on
			end
		end
	end

	local noteView: (string) -> ()

	local function show(id: string)
		for pageId, frame in pairs(pages) do
			frame.Visible = pageId == id
		end
		local label = id
		for _, tab in ipairs(ClientChrome.TABS) do
			if tab.id == id then
				label = tab.label
			end
		end
		if id == "sets" then
			label = "Bag  /  Sets"
		end
		title.Text = label
		paintTabs(if id == "sets" then "bag" else id)
		if id ~= "bag" then
			detailOpen = false
		end
		if id ~= "roll" then
			holdingRoll = false
		end
		detail.Visible = id == "bag" and detailOpen
		if hooks.onTab ~= nil then
			hooks.onTab(if id == "sets" then "bag" else id)
		end
		if shownId ~= "" and shownId ~= id then
			playUi("tab")
			local length = UiMotion.panel(UiMotion.reduced(draft))
			if length <= 0 then
				tabScale.Scale = 1
			else
				tabScale.Scale = 0.98
				TweenService:Create(
					tabScale,
					TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end
		local leftRoll = shownId == "roll" and id ~= "roll"
		shownId = id
		noteView(id)
		if leftRoll then
			stopRollChain()
		end
	end

	local function publishBadges()
		seen = NotifyBadges.prepare(seen, profile)
		local badges = NotifyBadges.evaluate(profile, seen)
		for id, dot in pairs(tabDots) do
			local badge = badges[id]
			dot.Visible = badge ~= nil and badge.on == true
		end
		if hooks.onBadges ~= nil then
			hooks.onBadges(badges)
		end
	end

	function noteView(id: string)
		seen = NotifyBadges.view(seen, id, profile)
		publishBadges()
	end

	local function classMissing(): boolean
		if type(profile) ~= "table" then
			return false
		end
		return Classes.get(profile.classId) == nil
	end

	local function pageFor(state: UiRouter.State): string
		local top = UiRouter.top(state)
		if top == "sets" then
			return "sets"
		end
		if top == "class" then
			return state.stack[1] or "hero"
		end
		return top
	end

	local function paintHints()
		for id, caption in pairs(tabCaptions) do
			local label = id
			for _, tab in ipairs(ClientChrome.TABS) do
				if tab.id == id then
					label = tab.label
				end
			end
			local key = draft.controls.hotkeys[id]
			if type(key) == "string" and key ~= "" then
				caption.Text = label .. "  " .. key
			else
				caption.Text = label
			end
		end
	end

	local function row(parent: Instance, text: string, order: number, fn: (() -> ())?): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("header")
		button.BorderSizePixel = 0
		button.Font = bodyFont()
		button.TextSize = UiTheme.MIN_TEXT
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = rgb("text")
		button.Text = "  " .. text
		button.LayoutOrder = order
		button.AutoButtonColor = false
		button.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE
		stroke.Color = rgb("divider")
		stroke.Parent = button
		setRest(button, rgb("header"))
		motion(button)
		if fn ~= nil then
			button.Activated:Connect(fn)
		end
		return button
	end

	local function line(parent: Instance, text: string, order: number, color: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Font = bodyFont()
		label.TextSize = UiTheme.MIN_TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = parent
		return label
	end

	local function divider(parent: Instance, order: number)
		local rule = Instance.new("Frame")
		rule.Name = "Divider"
		rule.Size = UDim2.new(1, 0, 0, 1)
		rule.BackgroundColor3 = rgb("divider")
		rule.BorderSizePixel = 0
		rule.LayoutOrder = order
		rule.Parent = parent
	end

	local function findItem(uid: string): any
		if type(profile) ~= "table" then
			return nil
		end
		if type(profile.inventory) == "table" then
			local item = profile.inventory[uid]
			if type(item) == "table" then
				return item
			end
		end
		if type(profile.pets) == "table" then
			local pet = profile.pets[uid]
			if type(pet) == "table" then
				return pet
			end
		end
		return nil
	end

	local function statMap(item: any): { [string]: number }
		local map: { [string]: number } = {}
		if type(item) ~= "table" or type(item.stats) ~= "table" then
			return map
		end
		for _, stat in ipairs(item.stats) do
			if
				type(stat) == "table"
				and type(stat.id) == "string"
				and type(stat.value) == "number"
			then
				map[stat.id] = stat.value
			end
		end
		return map
	end

	local function formatStat(id: string, value: number): string
		local definition = Stats.DEFS[id]
		local name = if definition ~= nil then definition.name else id
		if definition ~= nil and definition.unit == "percent" then
			return string.format("%s  %.1f%%", name, value * 100)
		end
		if definition ~= nil and definition.decimals > 0 then
			return string.format("%s  %." .. tostring(definition.decimals) .. "f", name, value)
		end
		return string.format("%s  %d", name, math.floor(value + 0.5))
	end

	local function equipUid(uid: string)
		task.spawn(function()
			pcall(hooks.invoke, "EquipItem", uid)
		end)
	end

	local function paintDetail(item: any)
		clear(detailList)
		if type(item) ~= "table" then
			detail.Visible = false
			detailOpen = false
			return
		end
		local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
		local red, green, blue = UiTheme.rarityColor(rarity)
		line(detailList, tostring(item.name or "Item"), 1, rgb("text"))
		line(detailList, rarity, 2, Color3.fromRGB(red, green, blue))
		divider(detailList, 3)
		local other = InventoryView.counterpart(profile, item)
		local same = other ~= nil and other.uid == item.uid
		if other == nil then
			line(detailList, "Nothing equipped to compare.", 4, rgb("muted"))
		elseif same then
			line(detailList, "Equipped.", 4, rgb("ok"))
		else
			line(
				detailList,
				"Compared with " .. tostring(other.name or "equipped"),
				4,
				rgb("muted")
			)
		end
		local mine = statMap(item)
		local theirs = if other ~= nil and not same then statMap(other) else {}
		local ids = {}
		local marked: { [string]: boolean } = {}
		for id in pairs(mine) do
			marked[id] = true
			table.insert(ids, id)
		end
		for id in pairs(theirs) do
			if marked[id] ~= true then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		local order = 10
		for _, id in ipairs(ids) do
			local value = mine[id] or 0
			local text = formatStat(id, value)
			local color = rgb("text")
			if other ~= nil and not same then
				local delta = value - (theirs[id] or 0)
				local tone = UiTheme.compareTone(delta)
				if tone == "gain" then
					color = rgb("ok")
					text = text .. "  +"
				elseif tone == "loss" then
					color = rgb("loss")
					text = text .. "  -"
				end
			end
			line(detailList, text, order, color)
			order += 1
		end
		local power = InventoryView.powerOf(item)
		local powerText = string.format("Power  %d", power)
		local powerColor = rgb("text")
		if other ~= nil and not same then
			local delta = power - InventoryView.powerOf(other)
			local tone = UiTheme.compareTone(delta)
			if tone == "gain" then
				powerColor = rgb("ok")
				powerText = powerText .. "  +"
			elseif tone == "loss" then
				powerColor = rgb("loss")
				powerText = powerText .. "  -"
			end
		end
		line(detailList, powerText, 80, powerColor)
		if type(item.uid) == "string" then
			local uid = item.uid
			row(detailList, if same then "Equipped" else "Equip", 90, function()
				if not same then
					equipUid(uid)
				end
			end)
		end
		detail.Visible = true
		detailOpen = true
	end

	local function openItem(uid: string)
		selectedUid = uid
		local item = findItem(uid)
		if item == nil then
			return
		end
		pages.bag.Visible = true
		paintDetail(item)
	end

	local function itemCard(
		parent: Instance,
		item: any,
		order: number,
		iconName: string
	): TextButton
		local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
		local red, green, blue = UiTheme.rarityColor(rarity)
		local card = Instance.new("TextButton")
		card.Name = "Card"
		card.BackgroundColor3 = rgb("body")
		card.BorderSizePixel = 0
		card.Text = ""
		card.AutoButtonColor = false
		card.LayoutOrder = order
		card.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = Color3.fromRGB(red, green, blue)
		stroke.Parent = card
		local wash = Instance.new("UIGradient")
		wash.Rotation = 90
		wash.Color = ColorSequence.new(Color3.fromRGB(red, green, blue), rgb("body"))
		wash.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 0.05),
		})
		wash.Parent = card
		setRest(card, rgb("body"))
		motion(card)
		iconOn(card, iconName, 8, 8, 36)
		local pip = Instance.new("Frame")
		pip.Name = "Pip"
		pip.Position = UDim2.fromOffset(50, 16)
		pip.Size = UDim2.fromOffset(12, 12)
		pip.BackgroundColor3 = Color3.fromRGB(red, green, blue)
		pip.BorderSizePixel = 0
		pip.Parent = card
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(1, 0)
		pipCorner.Parent = pip
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(8, 48)
		name.Size = UDim2.new(1, -16, 0, 36)
		name.Font = bodyFont()
		name.TextSize = UiTheme.MIN_TEXT
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextWrapped = true
		name.TextColor3 = rgb("text")
		name.Text = tostring(item.name or "Item")
		name.Parent = card
		if BagBoard.isNew(item, seen.bagAt) then
			local badge = Instance.new("TextLabel")
			badge.Name = "New"
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, -8, 0, 8)
			badge.Size = UDim2.fromOffset(44, 22)
			badge.BackgroundColor3 = rgb("accent")
			badge.Font = headerFont()
			badge.TextSize = UiTheme.MIN_TEXT
			badge.TextColor3 = rgb("ink")
			badge.Text = "NEW"
			badge.ZIndex = 7
			badge.Parent = card
			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, 6)
			badgeCorner.Parent = badge
		end
		local tip = Instance.new("TextLabel")
		tip.Name = "Tip"
		tip.BackgroundColor3 = rgb("header")
		tip.BackgroundTransparency = 0.05
		tip.Position = UDim2.fromOffset(8, 86)
		tip.Size = UDim2.new(1, -16, 0, 32)
		tip.Font = bodyFont()
		tip.TextSize = UiTheme.MIN_TEXT
		tip.TextWrapped = true
		tip.TextXAlignment = Enum.TextXAlignment.Left
		tip.TextColor3 = rgb("text")
		tip.Text = BagBoard.summary(profile, item)
		tip.Visible = selectedUid ~= nil and selectedUid == item.uid
		tip.ZIndex = 7
		tip.Parent = card
		card.MouseEnter:Connect(function()
			tip.Visible = true
		end)
		card.MouseLeave:Connect(function()
			tip.Visible = selectedUid ~= nil and selectedUid == item.uid
		end)
		local uid = item.uid
		if type(uid) == "string" then
			local itemUid = uid
			card.Activated:Connect(function()
				openItem(itemUid)
			end)
			local equip = Instance.new("TextButton")
			equip.Name = "Equip"
			equip.AnchorPoint = Vector2.new(0, 1)
			equip.Position = UDim2.new(0, 8, 1, -8)
			equip.Size = UDim2.new(1, -16, 0, UiTheme.TOUCH)
			equip.BackgroundColor3 = rgb("header")
			equip.Font = headerFont()
			equip.TextSize = UiTheme.MIN_TEXT
			equip.TextColor3 = rgb("text")
			equip.Text = "Equip"
			equip.AutoButtonColor = false
			equip.ZIndex = 7
			equip.Parent = card
			local equipCorner = Instance.new("UICorner")
			equipCorner.CornerRadius = UDim.new(0, 8)
			equipCorner.Parent = equip
			setRest(equip, rgb("header"))
			motion(equip)
			equip.Activated:Connect(function()
				equipUid(itemUid)
			end)
			local lock = Instance.new("TextButton")
			lock.Name = "Lock"
			lock.AnchorPoint = Vector2.new(1, 1)
			lock.Position = UDim2.new(1, -8, 1, -56)
			lock.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
			lock.BackgroundColor3 = rgb("header")
			lock.Font = headerFont()
			lock.TextSize = UiTheme.MIN_TEXT
			lock.TextColor3 = rgb("text")
			lock.Text = if item.locked == true then "Locked" else "Lock"
			lock.AutoButtonColor = false
			lock.ZIndex = 7
			lock.Parent = card
			local lockCorner = Instance.new("UICorner")
			lockCorner.CornerRadius = UDim.new(0, 8)
			lockCorner.Parent = lock
			setRest(lock, rgb("header"))
			motion(lock)
			local locked = item.locked == true
			lock.Activated:Connect(function()
				task.spawn(function()
					pcall(hooks.invoke, "SetItemLock", itemUid, not locked)
				end)
			end)
		end
		return card
	end

	local function emptyState(
		parent: Instance,
		iconName: string,
		copy: string,
		cta: string,
		fn: () -> ()
	)
		local block = Instance.new("Frame")
		block.Name = "Empty"
		block.BackgroundColor3 = rgb("header")
		block.BackgroundTransparency = 0.15
		block.Size = UDim2.new(1, 0, 0, 180)
		block.BorderSizePixel = 0
		block.LayoutOrder = 1
		block.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = block
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE
		stroke.Color = rgb("divider")
		stroke.Parent = block
		iconOn(block, iconName, 16, 16, 36)
		local copyLabel = Instance.new("TextLabel")
		copyLabel.BackgroundTransparency = 1
		copyLabel.Position = UDim2.fromOffset(16, 60)
		copyLabel.Size = UDim2.new(1, -32, 0, 28)
		copyLabel.Font = bodyFont()
		copyLabel.TextSize = UiTheme.MIN_TEXT
		copyLabel.TextXAlignment = Enum.TextXAlignment.Left
		copyLabel.TextColor3 = rgb("muted")
		copyLabel.Text = copy
		copyLabel.Parent = block
		local button = Instance.new("TextButton")
		button.Name = "Cta"
		button.Position = UDim2.fromOffset(16, 104)
		button.Size = UDim2.new(1, -32, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("button")
		button.Font = headerFont()
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("text")
		button.Text = cta
		button.AutoButtonColor = false
		button.Parent = block
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8)
		buttonCorner.Parent = button
		setRest(button, rgb("button"))
		motion(button)
		button.Activated:Connect(fn)
	end

	local function bagItems(): { any }
		local list = {}
		if type(profile) == "table" and type(profile.inventory) == "table" then
			for _, item in pairs(profile.inventory) do
				if type(item) == "table" and type(item.name) == "string" then
					table.insert(list, item)
				end
			end
		end
		table.sort(list, function(a, b)
			return InventoryView.powerOf(a) > InventoryView.powerOf(b)
		end)
		return list
	end

	local function companions(): { any }
		local list = {}
		if type(profile) ~= "table" or type(profile.companions) ~= "table" then
			return list
		end
		for _, companion in ipairs(profile.companions) do
			if type(companion) == "table" then
				table.insert(list, companion)
			end
		end
		if #list == 0 then
			for _, companion in pairs(profile.companions) do
				if type(companion) == "table" then
					table.insert(list, companion)
				end
			end
		end
		return list
	end

	local function paintClassCards()
		clear(classList)
		local roster = Classes.all()
		applyGrid(classList, #roster)
		for index, entry in ipairs(roster) do
			local card = Instance.new("Frame")
			card.Name = entry.id
			card.BackgroundColor3 = rgb("body")
			card.BorderSizePixel = 0
			card.LayoutOrder = index
			card.ZIndex = 10
			card.Parent = classList
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
			corner.Parent = card
			local tone = entry.palette
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = UiTheme.STROKE_BOLD
			stroke.Color = Color3.fromRGB(tone[1], tone[2], tone[3])
			stroke.Parent = card
			local wash = Instance.new("UIGradient")
			wash.Rotation = 90
			wash.Color = ColorSequence.new(Color3.fromRGB(tone[1], tone[2], tone[3]), rgb("body"))
			wash.Parent = card
			iconOn(card, "class", 8, 8, 28)
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(40, 8)
			name.Size = UDim2.new(1, -48, 0, 20)
			name.Font = headerFont()
			name.TextSize = UiTheme.MIN_TEXT
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = rgb("text")
			name.Text = entry.name
			name.ZIndex = 11
			name.Parent = card
			local role = Instance.new("TextLabel")
			role.BackgroundTransparency = 1
			role.Position = UDim2.fromOffset(8, 40)
			role.Size = UDim2.new(1, -16, 0, 36)
			role.Font = bodyFont()
			role.TextSize = UiTheme.MIN_TEXT
			role.TextXAlignment = Enum.TextXAlignment.Left
			role.TextYAlignment = Enum.TextYAlignment.Top
			role.TextWrapped = true
			role.TextColor3 = rgb("muted")
			role.Text = entry.role .. "  ·  " .. entry.passiveNote
			role.ZIndex = 11
			role.Parent = card
			local choose = Instance.new("TextButton")
			choose.Name = "Choose"
			choose.AnchorPoint = Vector2.new(0, 1)
			choose.Position = UDim2.new(0, 8, 1, -8)
			choose.Size = UDim2.new(1, -16, 0, UiTheme.TOUCH)
			choose.BackgroundColor3 = rgb("button")
			choose.Font = headerFont()
			choose.TextSize = UiTheme.MIN_TEXT
			choose.TextColor3 = rgb("text")
			choose.Text = "Choose"
			choose.AutoButtonColor = false
			choose.ZIndex = 11
			choose.Parent = card
			local chooseCorner = Instance.new("UICorner")
			chooseCorner.CornerRadius = UDim.new(0, 8)
			chooseCorner.Parent = choose
			setRest(choose, rgb("button"))
			motion(choose)
			local classId = entry.id
			choose.Activated:Connect(function()
				classDismissed = true
				if UiRouter.top(route) == "class" then
					apply(UiRouter.pop(route))
				else
					classModal.Visible = false
				end
				task.spawn(function()
					pcall(hooks.invoke, "SetClass", classId)
				end)
			end)
		end
	end

	local function showClassPrompt(force: boolean)
		if not classMissing() or ClassHud.holdsChoice() then
			if not classMissing() and UiRouter.top(route) == "class" then
				classDismissed = false
				apply(UiRouter.pop(route))
			end
			return
		end
		if not force and classDismissed then
			return
		end
		if route.open and UiRouter.top(route) == "class" then
			paintClassCards()
			return
		end
		classDismissed = false
		paintClassCards()
		local nextState = route
		if not nextState.open then
			nextState = UiRouter.open(nextState, "hero")
		end
		apply(UiRouter.push(nextState, "class"))
	end

	local function paintHero()
		clear(hero)
		local level = if type(profile) == "table" then profile.level or 1 else 1
		local classId = if type(profile) == "table" then profile.classId else ""
		local classDef = Classes.get(classId)
		local sheet = Instance.new("Frame")
		sheet.Name = "Stats"
		sheet.BackgroundColor3 = rgb("header")
		sheet.BackgroundTransparency = 0.2
		sheet.Size = UDim2.fromScale(1, 0)
		sheet.AutomaticSize = Enum.AutomaticSize.Y
		sheet.BorderSizePixel = 0
		sheet.LayoutOrder = 1
		sheet.Parent = hero
		local sheetCorner = Instance.new("UICorner")
		sheetCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		sheetCorner.Parent = sheet
		local sheetStroke = Instance.new("UIStroke")
		sheetStroke.Thickness = UiTheme.STROKE
		sheetStroke.Color = rgb("divider")
		sheetStroke.Parent = sheet
		local sheetList = Instance.new("UIListLayout")
		sheetList.Padding = UDim.new(0, 2)
		sheetList.SortOrder = Enum.SortOrder.LayoutOrder
		sheetList.Parent = sheet
		local sheetPad = Instance.new("UIPadding")
		sheetPad.PaddingTop = UDim.new(0, UiTheme.PAD)
		sheetPad.PaddingBottom = UDim.new(0, UiTheme.PAD)
		sheetPad.PaddingLeft = UDim.new(0, UiTheme.GAP)
		sheetPad.PaddingRight = UDim.new(0, UiTheme.GAP)
		sheetPad.Parent = sheet
		line(sheet, "Stat sheet", 1, rgb("gold"))
		divider(sheet, 2)
		local offense, vitality, goldFind = CombatMath.loadout(profile)
		line(sheet, string.format("Level  %d", level), 3, rgb("text"))
		line(sheet, string.format("Damage  %d", math.floor(offense.damage + 0.5)), 4, rgb("text"))
		line(sheet, string.format("Attack speed  %.2f", offense.attackSpeed), 5, rgb("text"))
		line(sheet, string.format("Crit  %.0f%%", offense.critChance * 100), 6, rgb("text"))
		line(sheet, string.format("Crit damage  %.2f", offense.critDamage), 7, rgb("text"))
		line(sheet, string.format("HP  %d", vitality.maxHealth), 8, rgb("text"))
		line(sheet, string.format("Defense  %d", vitality.defense), 9, rgb("text"))
		line(sheet, string.format("Gold find  %.0f%%", goldFind * 100), 10, rgb("text"))
		line(sheet, string.format("Power  %d", HeroBoard.power(profile)), 11, rgb("gold"))
		local barOrder = 12
		for _, bar in ipairs(HeroBoard.bars(profile)) do
			local host = Instance.new("Frame")
			host.Name = bar.id
			host.BackgroundColor3 = rgb("body")
			host.Size = UDim2.new(1, 0, 0, 22)
			host.BorderSizePixel = 0
			host.LayoutOrder = barOrder
			host.Parent = sheet
			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.fromScale(bar.fill, 1)
			fill.BackgroundColor3 = rgb("accent")
			fill.BorderSizePixel = 0
			fill.Parent = host
			local caption = Instance.new("TextLabel")
			caption.BackgroundTransparency = 1
			caption.Size = UDim2.fromScale(1, 1)
			caption.Font = bodyFont()
			caption.TextSize = UiTheme.MIN_TEXT
			caption.TextXAlignment = Enum.TextXAlignment.Left
			caption.TextColor3 = rgb("text")
			caption.Text = "  " .. bar.label
			caption.ZIndex = 2
			caption.Parent = host
			barOrder += 1
		end
		local viewport = Instance.new("ViewportFrame")
		viewport.Name = "Avatar"
		viewport.BackgroundColor3 = rgb("header")
		viewport.Size = UDim2.new(1, 0, 0, 180)
		viewport.LayoutOrder = 0
		viewport.Parent = hero
		local world = Instance.new("WorldModel")
		world.Name = "World"
		world.Parent = viewport
		local camera = Instance.new("Camera")
		camera.CFrame = CFrame.new(Vector3.new(0, 2, -6), Vector3.new(0, 2, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			local character = if localPlayer ~= nil then localPlayer.Character else nil
			local humanoid = if character ~= nil
				then character:FindFirstChildOfClass("Humanoid")
				else nil
			if humanoid == nil then
				return
			end
			local described, description = pcall(function()
				return humanoid:GetAppliedDescription()
			end)
			if not described or description == nil then
				return
			end
			local built, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(
					description,
					Enum.HumanoidRigType.R15
				)
			end)
			if built and model ~= nil and viewport.Parent ~= nil then
				model.Parent = world
			end
		end)

		local classCard = Instance.new("Frame")
		classCard.Name = "ClassCard"
		classCard.BackgroundColor3 = rgb("body")
		classCard.Size = UDim2.new(1, 0, 0, 120)
		classCard.BorderSizePixel = 0
		classCard.LayoutOrder = 2
		classCard.Parent = hero
		local classCardCorner = Instance.new("UICorner")
		classCardCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		classCardCorner.Parent = classCard
		local classCardStroke = Instance.new("UIStroke")
		classCardStroke.Thickness = UiTheme.STROKE_BOLD
		classCardStroke.Color = rgb("accent")
		classCardStroke.Parent = classCard
		iconOn(classCard, "class", 12, 12, 32)
		local classTitle = Instance.new("TextLabel")
		classTitle.BackgroundTransparency = 1
		classTitle.Position = UDim2.fromOffset(52, 12)
		classTitle.Size = UDim2.new(1, -64, 0, 22)
		classTitle.Font = headerFont()
		classTitle.TextSize = UiTheme.MIN_TEXT
		classTitle.TextXAlignment = Enum.TextXAlignment.Left
		classTitle.TextColor3 = rgb("text")
		classTitle.Text = if classDef ~= nil then classDef.name else "No class"
		classTitle.Parent = classCard
		local classNote = Instance.new("TextLabel")
		classNote.BackgroundTransparency = 1
		classNote.Position = UDim2.fromOffset(12, 48)
		classNote.Size = UDim2.new(1, -24, 0, 22)
		classNote.Font = bodyFont()
		classNote.TextSize = UiTheme.MIN_TEXT
		classNote.TextXAlignment = Enum.TextXAlignment.Left
		classNote.TextColor3 = rgb("muted")
		classNote.Text = if classDef ~= nil
			then classDef.role .. "  ·  " .. classDef.passiveNote
			else "Choose a class to take a kit."
		classNote.Parent = classCard
		if classDef == nil then
			local choose = Instance.new("TextButton")
			choose.Name = "ChooseClass"
			choose.Position = UDim2.fromOffset(12, 74)
			choose.Size = UDim2.new(1, -24, 0, UiTheme.TOUCH)
			choose.BackgroundColor3 = rgb("button")
			choose.Font = headerFont()
			choose.TextSize = UiTheme.MIN_TEXT
			choose.TextColor3 = rgb("text")
			choose.Text = "Choose class"
			choose.AutoButtonColor = false
			choose.Parent = classCard
			local chooseCorner = Instance.new("UICorner")
			chooseCorner.CornerRadius = UDim.new(0, 8)
			chooseCorner.Parent = choose
			setRest(choose, rgb("button"))
			motion(choose)
			choose.Activated:Connect(function()
				showClassPrompt(true)
			end)
			classCard.Size = UDim2.new(1, 0, 0, 128)
		end

		line(hero, "Skills", 3, rgb("gold"))
		divider(hero, 4)
		if classDef ~= nil then
			for index, skill in ipairs(classDef.skills) do
				line(
					hero,
					string.format("%s  %ds  %s", skill.name, skill.cooldown, skill.note),
					10 + index,
					rgb("text")
				)
			end
			line(
				hero,
				string.format(
					"%s  %ds  %s",
					classDef.ultimate.name,
					classDef.ultimate.cooldown,
					classDef.ultimate.note
				),
				20,
				rgb("gold")
			)
		else
			line(hero, "No skills until a class is chosen.", 10, rgb("muted"))
		end
		row(hero, "Change class", 30, function()
			showClassPrompt(true)
		end)
	end

	local function cardHost(
		parent: Instance,
		measure: ScrollingFrame,
		count: number,
		order: number
	): Frame
		local host = Instance.new("Frame")
		host.Name = "Cards"
		host.BackgroundTransparency = 1
		host.LayoutOrder = order
		host.Parent = parent
		local layout = Instance.new("UIGridLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = host
		local width = measure.AbsoluteSize.X
		local height = measure.AbsoluteSize.Y
		if width < 44 then
			local vx, vy = view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			width = inner.w
			height = inner.h
		end
		local spec = HudLayout.cardGrid(math.max(44, width - 16), math.max(44, height), count)
		layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
		layout.CellPadding = UDim2.fromOffset(spec.gap, spec.gap)
		local rows = spec.rows
		host.Size = UDim2.new(1, 0, 0, rows * spec.cellH + math.max(0, rows - 1) * spec.gap)
		return host
	end

	local function nextSalvage(current: string): string
		local following = BagBoard.nextRarity(current)
		if following == "All" then
			return "Common"
		end
		return following
	end

	local function paintBag()
		clear(bag)
		local items = bagItems()
		local shown = BagBoard.rows(items, bagFilter, seen.bagAt)
		local bar = Instance.new("Frame")
		bar.Name = "Filters"
		bar.BackgroundTransparency = 1
		bar.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		bar.LayoutOrder = 1
		bar.Parent = bag
		local barLayout = Instance.new("UIListLayout")
		barLayout.FillDirection = Enum.FillDirection.Horizontal
		barLayout.Padding = UDim.new(0, UiTheme.PAD)
		barLayout.Parent = bar
		local function chip(label: string, fn: () -> ())
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(0.25, -6, 1, 0)
			button.BackgroundColor3 = rgb("header")
			button.Font = headerFont()
			button.TextSize = UiTheme.MIN_TEXT
			button.TextColor3 = rgb("text")
			button.Text = label
			button.AutoButtonColor = false
			button.Parent = bar
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button
			setRest(button, rgb("header"))
			motion(button)
			button.Activated:Connect(fn)
		end
		local function refreshBag()
			paintBag()
			show("bag")
		end
		chip("Rarity  " .. bagFilter.rarity, function()
			bagFilter.rarity = BagBoard.nextRarity(bagFilter.rarity)
			refreshBag()
		end)
		chip("Type  " .. bagFilter.kind, function()
			bagFilter.kind = BagBoard.nextKind(bagFilter.kind, BagBoard.kinds(items))
			refreshBag()
		end)
		chip(if bagFilter.onlyNew then "New  On" else "New", function()
			bagFilter.onlyNew = not bagFilter.onlyNew
			refreshBag()
		end)
		chip("Sort  " .. bagFilter.sort, function()
			bagFilter.sort = BagBoard.nextSort(bagFilter.sort)
			refreshBag()
		end)
		row(bag, "Sets", 2, function()
			apply(UiRouter.push(route, "sets"))
		end)
		row(bag, "Open full bag", 3, function()
			hooks.onBag()
		end)
		if salvageArmed then
			line(bag, BagBoard.confirm(salvageRarity), 4, rgb("loss"))
			row(bag, "Confirm salvage", 5, function()
				local rarity = salvageRarity
				salvageArmed = false
				task.spawn(function()
					pcall(hooks.invoke, "BulkSalvage", rarity)
				end)
				refreshBag()
			end)
			row(bag, "Cancel", 6, function()
				salvageArmed = false
				refreshBag()
			end)
			row(bag, "Use  " .. nextSalvage(salvageRarity), 7, function()
				salvageRarity = nextSalvage(salvageRarity)
				refreshBag()
			end)
		else
			row(bag, "Salvage  " .. salvageRarity, 4, function()
				salvageArmed = true
				refreshBag()
			end)
		end
		if #shown == 0 then
			emptyState(bag, "bag", "The bag is empty.", "Open full bag", function()
				hooks.onBag()
			end)
			local empty = bag:FindFirstChild("Empty")
			if empty ~= nil and empty:IsA("GuiObject") then
				empty.LayoutOrder = 9
			end
		else
			local host = cardHost(bag, bag, #shown, 8)
			for index, item in ipairs(shown) do
				itemCard(host, item, index, "item")
			end
		end
		row(sets, "Relic sets equip from the bag. Pieces stay raid drops.", 1, nil)
		if detailOpen and selectedUid ~= nil then
			local item = findItem(selectedUid)
			if item ~= nil then
				paintDetail(item)
			else
				detailOpen = false
				detail.Visible = false
			end
		end
	end

	local function paintPets()
		clear(pets)
		local slots = { nil, nil, nil }
		local filled = 0
		if
			type(profile) == "table"
			and type(profile.equipped) == "table"
			and type(profile.equipped.pet) == "string"
			and type(profile.pets) == "table"
		then
			local pet = profile.pets[profile.equipped.pet]
			if type(pet) == "table" then
				slots[1] = pet
				filled += 1
			end
		end
		local following = companions()
		for index, companion in ipairs(following) do
			if index > 2 then
				break
			end
			slots[index + 1] = companion
			filled += 1
		end
		line(pets, string.format("Equipped  %d/3", filled), 1, rgb("gold"))
		for index = 1, 3 do
			local slot = slots[index]
			local slotName = if type(slot) == "table" then tostring(slot.name or "Pet") else "Empty"
			row(pets, string.format("Slot %d  %s", index, slotName), index + 1, nil)
		end
		divider(pets, 6)
		local cards = {}
		if type(profile) == "table" and type(profile.pets) == "table" then
			for _, pet in pairs(profile.pets) do
				if type(pet) == "table" and type(pet.name) == "string" then
					table.insert(cards, pet)
				end
			end
		end
		for _, companion in ipairs(following) do
			table.insert(cards, {
				name = companion.name or "Companion",
				rarity = companion.rarity or "Common",
			})
		end
		if #cards == 0 then
			emptyState(pets, "pets", "No companions yet.", "Open pets", function() end)
		else
			local host = cardHost(pets, pets, #cards, 7)
			for index, pet in ipairs(cards) do
				itemCard(host, pet, index, "pet")
			end
		end
	end

	local beginRoll: () -> ()
	local finishReveal: () -> ()

	local function paintRoll()
		clear(roll)
		if pityTween ~= nil then
			pityTween:Cancel()
			pityTween = nil
		end
		setPulse(loop.phase == "idle" and not rollBusy)

		local toggles = Instance.new("Frame")
		toggles.Name = "Toggles"
		toggles.BackgroundTransparency = 1
		toggles.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		toggles.LayoutOrder = 2
		toggles.Parent = roll
		local toggleLayout = Instance.new("UIListLayout")
		toggleLayout.FillDirection = Enum.FillDirection.Horizontal
		toggleLayout.Padding = UDim.new(0, UiTheme.PAD)
		toggleLayout.Parent = toggles
		local function toggle(name: string, text: string, on: boolean, fn: () -> ())
			local button = Instance.new("TextButton")
			button.Name = name
			button.Size = UDim2.new(0.25, -6, 1, 0)
			button.BackgroundColor3 = if on then rgb("button") else rgb("header")
			button.Font = headerFont()
			button.TextSize = UiTheme.MIN_TEXT
			button.TextColor3 = rgb("text")
			button.Text = text
			button.AutoButtonColor = false
			button.Parent = toggles
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button
			setRest(button, if on then rgb("button") else rgb("header"))
			motion(button)
			button.Activated:Connect(fn)
		end
		toggle("Auto", if autoOn then "Auto On" else "Auto", autoOn, function()
			autoOn = not autoOn
			draft.rolls.autoConfirm = autoOn
			save()
			if autoOn and loop.phase == "idle" and not rollBusy then
				loop = RollLoop.press(loop)
				beginRoll()
			end
			paintRoll()
			show("roll")
		end)
		toggle(
			"Stop",
			if stopAt == "Off" then "Stop  Off" else "Stop at  " .. stopAt,
			stopAt ~= "Off",
			function()
				stopAt = RollBoard.nextStop(stopAt)
				paintRoll()
				show("roll")
			end
		)
		toggle("Quick", if quickOn then "Quick On" else "Quick", quickOn, function()
			quickOn = not quickOn
			paintRoll()
			show("roll")
		end)
		toggle("Info", "Info", infoOpen, function()
			infoOpen = not infoOpen
			paintRoll()
			show("roll")
		end)

		local junkRow = Instance.new("Frame")
		junkRow.Name = "Junk"
		junkRow.BackgroundTransparency = 1
		junkRow.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		junkRow.LayoutOrder = 3
		junkRow.Parent = roll
		local junkLayout = Instance.new("UIListLayout")
		junkLayout.FillDirection = Enum.FillDirection.Horizontal
		junkLayout.Padding = UDim.new(0, UiTheme.PAD)
		junkLayout.Parent = junkRow
		local function junkButton(name: string, text: string, fn: () -> ())
			local button = Instance.new("TextButton")
			button.Name = name
			button.Size = UDim2.new(0.5, -4, 1, 0)
			button.BackgroundColor3 = rgb("header")
			button.Font = headerFont()
			button.TextSize = UiTheme.MIN_TEXT
			button.TextColor3 = rgb("text")
			button.Text = text
			button.AutoButtonColor = false
			button.Parent = junkRow
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button
			setRest(button, rgb("header"))
			motion(button)
			button.Activated:Connect(fn)
		end
		junkButton("JunkMode", "Junk  " .. draft.rolls.autoJunk, function()
			local order = { "ask", "keep", "salvage" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.autoJunk then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.autoJunk = nextId
			save()
			paintRoll()
			show("roll")
		end)
		junkButton("JunkBelow", "Below  " .. draft.rolls.junkBelow, function()
			local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.junkBelow then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.junkBelow = nextId
			save()
			paintRoll()
			show("roll")
		end)

		local sinceEpic = if serverEpic ~= nil
			then serverEpic
			elseif type(profile) == "table" then profile.sinceEpic or 0
			else 0
		local pityResult = if serverSince ~= nil
			then { pity = { sinceLegendary = serverSince } }
			else nil
		local sinceLegendary, pityGoal = UiRouter.legendaryPity(profile, pityResult)
		local pityMeter = RollHype.pity(sinceLegendary, pityGoal)
		reelStreak.Text = UiRouter.streakText(hype.streak, lastMissed)
		reelStreak.TextColor3 = rgb(UiRouter.streakTone(hype.streak, lastMissed))
		line(
			roll,
			UiRouter.streakText(hype.streak, lastMissed),
			4,
			rgb(UiRouter.streakTone(hype.streak, lastMissed))
		)
		line(roll, string.format("Rolls  %d", hype.rolls), 5, rgb("text"))
		line(roll, string.format("Next Epic in %d", RollLoop.nextEpic(sinceEpic)), 6, rgb("text"))
		local bestText = "Best pull  —"
		if type(bestPull) == "table" then
			bestText = string.format(
				"Best pull  %s  %s",
				tostring(bestPull.name or "Item"),
				tostring(bestPull.rarity or "")
			)
		end
		line(roll, bestText, 7, rgb("accent"))
		line(
			roll,
			RollLoop.indexText(
				RollLoop.discoveries(profile, sessionTemplates),
				RollLoop.indexTotal()
			),
			8,
			rgb("text")
		)

		if infoOpen then
			local luck = 0
			local boost = 0
			local rolls = 0
			if type(profile) == "table" then
				luck = profile.shardLuck or 0
				boost = profile.luckBoost or 0
				rolls = profile.shardRolls or 0
			end
			local info = Instance.new("Frame")
			info.Name = "Odds"
			info.BackgroundColor3 = rgb("header")
			info.BackgroundTransparency = 0.1
			info.Size = UDim2.fromScale(1, 0)
			info.AutomaticSize = Enum.AutomaticSize.Y
			info.BorderSizePixel = 0
			info.LayoutOrder = 9
			info.Parent = roll
			local infoCorner = Instance.new("UICorner")
			infoCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
			infoCorner.Parent = info
			local infoList = Instance.new("UIListLayout")
			infoList.Padding = UDim.new(0, 2)
			infoList.SortOrder = Enum.SortOrder.LayoutOrder
			infoList.Parent = info
			local infoPad = Instance.new("UIPadding")
			infoPad.PaddingTop = UDim.new(0, UiTheme.PAD)
			infoPad.PaddingBottom = UDim.new(0, UiTheme.PAD)
			infoPad.PaddingLeft = UDim.new(0, UiTheme.GAP)
			infoPad.PaddingRight = UDim.new(0, UiTheme.GAP)
			infoPad.Parent = info
			line(info, string.format("Luck  %d", luck + boost), 1, rgb("gold"))
			line(info, RarityConfig.bonusLabel(rolls), 2, rgb("text"))
			local legendaryCount = if type(sinceLegendary) == "number" then sinceLegendary else 0
			line(info, RarityConfig.pityLine(sinceEpic, legendaryCount), 3, rgb("text"))
			local pool = Pools.get("verdant_armory")
			if pool ~= nil then
				local rolled, odds = pcall(RollMath.odds, pool, luck, {
					luckBoost = boost,
					rollsSinceLegendary = UiRouter.oddsSince(legendaryCount),
				})
				if rolled and type(odds) == "table" then
					local order = 4
					if type(odds.rarities) == "table" then
						for _, rarity in ipairs(odds.rarities) do
							line(
								info,
								string.format("%s  %.1f%%", rarity.rarity, rarity.chance * 100),
								order,
								rgb("text")
							)
							order += 1
						end
					end
				end
			end
		end

		local function meter(
			name: string,
			caption: string,
			fill: number,
			order: number,
			flash: boolean
		)
			local host = Instance.new("Frame")
			host.Name = name
			host.BackgroundColor3 = rgb("header")
			host.Size = UDim2.new(1, 0, 0, 28)
			host.BorderSizePixel = 0
			host.LayoutOrder = order
			host.Parent = roll
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = host
			local bar = Instance.new("Frame")
			bar.Name = "Fill"
			bar.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
			bar.BackgroundColor3 = if flash then rgb("gold") else rgb("accent")
			bar.BorderSizePixel = 0
			bar.Parent = host
			local barCorner = Instance.new("UICorner")
			barCorner.CornerRadius = UDim.new(0, 6)
			barCorner.Parent = bar
			if flash and not UiMotion.reduced(draft) then
				local tween = TweenService:Create(
					bar,
					TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ BackgroundTransparency = 0.45 }
				)
				pityTween = tween
				tween:Play()
			end
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = bodyFont()
			label.TextSize = UiTheme.MIN_TEXT
			label.TextColor3 = rgb("text")
			label.Text = caption
			label.ZIndex = 2
			label.Parent = host
		end
		if pityMeter.ok == true and type(pityMeter.goal) == "number" then
			local shown = math.floor(pityMeter.counter)
			local goal = math.floor(pityMeter.goal)
			local reset = false
			if shown == 0 and lastLanded ~= nil then
				reset = Rarities.isLegendaryOrBetter(lastLanded)
			end
			local caption = if reset
				then string.format("Legendary reset  %d / %d", shown, goal)
				else string.format("Legendary  %d / %d", shown, goal)
			meter("LegendaryPity", caption, pityMeter.fill, 10, reset)
		else
			meter("LegendaryPity", "Legendary pity", 0, 10, false)
		end
		local luck = if type(profile) == "table" then profile.shardLuck or 0 else 0
		local boost = if type(profile) == "table" then profile.luckBoost or 0 else 0
		line(roll, "Odds", 11, rgb("gold"))
		local oddsSince =
			UiRouter.oddsSince(if type(sinceLegendary) == "number" then sinceLegendary else 0)
		local odds = RollBoard.oddsLines(Pools.get("verdant_armory"), luck, boost, oddsSince)
		if #odds == 0 then
			line(roll, "Odds are unavailable.", 12, rgb("muted"))
		else
			for index, text in ipairs(odds) do
				line(roll, text, 12 + index, rgb("text"))
			end
		end

		local recent = if #sessionRolls > 0
			then sessionRolls
			else RollBoard.history(bagItems(), RollBoard.HISTORY)
		local celebrate = recent[1]
		if type(celebrate) == "table" then
			local rarity = if type(celebrate.rarity) == "string" then celebrate.rarity else "Common"
			local banner = Instance.new("TextLabel")
			banner.Name = "Celebration"
			banner.BackgroundTransparency = 1
			banner.Size = UDim2.new(1, 0, 0, 36)
			banner.Font = headerFont()
			banner.TextSize = 20
			banner.TextColor3 = rgb("accent")
			banner.Text = tostring(celebrate.name or "Item") .. "  " .. rarity
			banner.LayoutOrder = 30
			banner.Parent = roll
			local scale = Instance.new("UIScale")
			scale.Scale = RollBoard.celebrationScale(rarity)
			scale.Parent = banner
		end
		line(roll, "Last 10", 31, rgb("gold"))
		divider(roll, 32)
		if #recent == 0 then
			line(roll, "No rolls yet.", 33, rgb("muted"))
		else
			local strip = Instance.new("Frame")
			strip.Name = "History"
			strip.BackgroundTransparency = 1
			strip.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
			strip.LayoutOrder = 33
			strip.Parent = roll
			local stripLayout = Instance.new("UIListLayout")
			stripLayout.FillDirection = Enum.FillDirection.Horizontal
			stripLayout.Padding = UDim.new(0, 4)
			stripLayout.Parent = strip
			for index, item in ipairs(recent) do
				local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
				local red, green, blue = UiTheme.rarityColor(rarity)
				local chip = Instance.new("TextLabel")
				chip.Name = "Result"
				chip.Size = UDim2.fromOffset(72, UiTheme.TOUCH)
				chip.BackgroundColor3 = Color3.fromRGB(red, green, blue)
				chip.Font = bodyFont()
				chip.TextSize = UiTheme.MIN_TEXT
				chip.TextColor3 = rgb("ink")
				chip.Text = tostring(item.name or rarity)
				chip.TextTruncate = Enum.TextTruncate.AtEnd
				chip.LayoutOrder = index
				chip.Parent = strip
				local chipCorner = Instance.new("UICorner")
				chipCorner.CornerRadius = UDim.new(0, 8)
				chipCorner.Parent = chip
				if index == 1 and slideHistory then
					local chipScale = Instance.new("UIScale")
					chipScale.Parent = chip
					if UiMotion.reduced(draft) then
						chipScale.Scale = 1
					else
						chipScale.Scale = 0.6
						TweenService:Create(
							chipScale,
							TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{ Scale = 1 }
						):Play()
					end
				end
			end
		end
		slideHistory = false
	end

	local activeItem: any = nil
	local activeNew = false
	local activeUpgrade = false

	local function tokenCount(): number
		if type(profile) == "table" and type(profile.shardTokens) == "number" then
			return profile.shardTokens
		end
		return 0
	end

	local function hapticTick()
		pcall(function()
			local haptic = game:GetService("HapticService")
			haptic:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.2)
			task.delay(0.05, function()
				haptic:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end)
	end

	local function cameraTick()
		if draft.camera.shake ~= true or UiMotion.reduced(draft) then
			return
		end
		local localPlayer = Players.LocalPlayer
		local character = if localPlayer ~= nil then localPlayer.Character else nil
		if character == nil then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			return
		end
		local before = humanoid.CameraOffset
		humanoid.CameraOffset = before + Vector3.new(0.12, 0, 0)
		task.delay(0.05, function()
			if humanoid.Parent ~= nil then
				humanoid.CameraOffset = before
			end
		end)
	end

	local function squash()
		local length = UiMotion.press(UiMotion.reduced(draft))
		if length <= 0 then
			pressScale.Scale = 0.92
			task.delay(0.05, function()
				pressScale.Scale = 1
			end)
			return
		end
		local down = TweenService:Create(
			pressScale,
			TweenInfo.new(length * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0.92 }
		)
		down.Completed:Connect(function()
			TweenService:Create(
				pressScale,
				TweenInfo.new(length, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)
		down:Play()
	end

	local function paintResult(
		item: any,
		record: RollReveal.Record,
		isNew: boolean,
		upgrade: boolean
	)
		revealCard.Visible = true
		revealTitle.Text = record.name
		revealRarity.Text = record.rarity
		local color = rarityColor3(record.rarity)
		revealRarity.TextColor3 = color
		revealStroke.Color = color
		revealNew.Visible = isNew
		revealBest.Visible = false
		local drip = RollLoop.drip()
		revealFly.Text = drip.text
		revealFly.TextTransparency = 0
		revealFly.Position = UDim2.fromOffset(12, 72)
		if not UiMotion.reduced(draft) then
			TweenService:Create(
				revealFly,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = UDim2.fromOffset(12, 36),
					TextTransparency = 1,
				}
			):Play()
		end
		local junk =
			RollLoop.resolve(record.rarity, draft.rolls.junkBelow, draft.rolls.autoJunk, upgrade)
		revealEquip.Visible = junk == "equip"
		if type(item.uid) == "string" then
			revealEquip:SetAttribute("Uid", item.uid)
		end
		if junk == "salvage" and type(item.uid) == "string" then
			task.spawn(function()
				pcall(hooks.invoke, "Salvage", item.uid)
			end)
		end
	end

	local function chainAllowed(queued: boolean): boolean
		local pending = if type(activeItem) == "table" then activeItem.uid else nil
		local rarity = "Common"
		if type(activeItem) == "table" and type(activeItem.rarity) == "string" then
			rarity = activeItem.rarity
		end
		return RollLoop.canChain({
			open = route.open,
			onRoll = shownId == "roll",
			alive = playerAlive,
			queued = queued,
			holding = holdingRoll,
			auto = autoOn,
			tokens = tokenCount(),
			bagFull = RollLoop.bagFull(profile, pending),
			rarity = rarity,
			stopAt = stopAt,
			isNew = activeNew,
			isUpgrade = activeUpgrade,
		})
	end

	finishReveal = function()
		activeReveal = nil
		local finished = RollLoop.finish(loop)
		if chainAllowed(finished.phase == "revealing") then
			loop = { phase = "revealing", queued = false }
			beginRoll()
			return
		end
		loop = RollLoop.idle()
		setPulse(true)
	end

	beginRoll = function()
		if rollBusy then
			return
		end
		rollBusy = true
		setPulse(false)
		revealToken += 1
		local generation = revealToken
		task.spawn(function()
			local waitFor = RarityConfig.COOLDOWN - (os.clock() - lastCrack)
			if lastCrack > 0 and waitFor > 0 then
				task.wait(waitFor)
			end
			if generation ~= revealToken then
				rollBusy = false
				return
			end
			local poolId = "verdant_armory"
			if hooks.getPoolId ~= nil then
				local picked = hooks.getPoolId()
				if type(picked) == "string" and picked ~= "" then
					poolId = picked
				end
			end
			local ok, result = pcall(hooks.invoke, "RollShard", poolId, false)
			if generation ~= revealToken then
				rollBusy = false
				return
			end
			rollBusy = false
			local record = if ok then RollReveal.capture(result) else nil
			if record == nil or type(result) ~= "table" or type(result.item) ~= "table" then
				local missed = RollHype.note(hype, { landed = false })
				if missed.ok == true then
					hype = missed.state
				end
				lastMissed = true
				loop = RollLoop.idle()
				activeReveal = nil
				revealBest.Visible = false
				reelMilestone.Visible = false
				setPulse(true)
				paintReelIdle("Miss")
				paintRoll()
				return
			end
			lastCrack = os.clock()
			local paid = result.currency == "prism" or result.paid == true
			local noted = RollHype.note(hype, {
				rarity = record.rarity,
				landed = true,
				paid = paid,
			})
			if noted.ok ~= true or noted.rarity == nil then
				loop = RollLoop.idle()
				activeReveal = nil
				revealCard.Visible = false
				revealBest.Visible = false
				setPulse(true)
				paintReelIdle("Roll")
				paintRoll()
				return
			end
			hype = noted.state
			lastMissed = false
			lastLanded = noted.rarity
			local item = result.item
			local card = UiRouter.rollCard(noted, item)
			if card == nil then
				loop = RollLoop.idle()
				activeReveal = nil
				revealCard.Visible = false
				setPulse(true)
				paintReelIdle("Roll")
				paintRoll()
				return
			end
			local owned = RollLoop.ownedTemplates(
				profile,
				if type(item.uid) == "string" then item.uid else nil
			)
			activeNew = RollLoop.isNew(item.templateId, owned)
			activeUpgrade = RollLoop.isUpgrade(profile, item)
			activeItem = item
			bestPull = RollLoop.best(bestPull, item)
			if type(item.templateId) == "string" then
				table.insert(sessionTemplates, item.templateId)
			end
			table.insert(sessionRolls, 1, item)
			while #sessionRolls > RollBoard.HISTORY do
				table.remove(sessionRolls)
			end
			slideHistory = true
			if type(result.pity) == "table" then
				if type(result.pity.sinceEpic) == "number" then
					serverEpic = result.pity.sinceEpic
				end
				if type(result.pity.sinceLegendary) == "number" then
					serverSince = result.pity.sinceLegendary
				end
			end
			local reduced = UiMotion.reduced(draft)
			local quick = result.quick == true or quickOn
			local pace = RollHype.tempo(noted.rarity, paid)
			local duration = UiRouter.rollBuildUp(draft, noted.rarity, quick, reduced, {
				ok = pace.ok,
				buildUp = pace.buildUp,
				rarity = pace.rarity,
				tier = pace.tier,
			})
			if duration == nil then
				loop = RollLoop.idle()
				activeReveal = nil
				revealCard.Visible = false
				setPulse(true)
				paintReelIdle("Roll")
				paintRoll()
				return
			end
			local shownRecord: RollReveal.Record = {
				id = record.id,
				name = card.name,
				rarity = card.rarity,
			}
			local pool = Pools.get(poolId)
			local seed = if type(result.fillerSeed) == "number" then result.fillerSeed else 1
			local raw = if pool ~= nil
				then RollReveal.strip(seed, pool, shownRecord)
				else { shownRecord }
			local slots = UiRouter.honestSlots(raw, card.name, card.rarity)
			paintResult(item, shownRecord, activeNew, activeUpgrade)
			local callout, personal = UiRouter.rollShout(noted)
			if personal ~= nil then
				flashPersonalBest(personal)
			end
			if callout ~= nil then
				showMilestone(callout)
			else
				reelMilestone.Visible = false
			end
			paintRoll()
			local color = rarityColor3(card.rarity)
			local pop = UiRouter.rollPop(pace.tier, reduced)
			if duration <= 0 then
				paintReel(slots, #slots)
				revealCard.BackgroundColor3 = color
				revealScale.Scale = if reduced then 1 else pop
				if not reduced then
					TweenService:Create(
						revealScale,
						TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
				if RollLoop.flash(card.rarity, reduced, draft.camera.flash == "reduced") then
					flashCover.BackgroundColor3 = color
					flashCover.BackgroundTransparency = 0.45
					TweenService
						:Create(flashCover, TweenInfo.new(0.08), { BackgroundTransparency = 1 })
						:Play()
				end
				if RollLoop.stinger(card.rarity, reduced) then
					playUi("stinger")
				elseif not reduced and (pace.tier or 0) >= 3 then
					playUi("confirm")
				end
				finishReveal()
				return
			end
			revealCard.BackgroundColor3 = rgb("header")
			paintReel(slots, 1)
			activeReveal = {
				started = os.clock(),
				duration = duration,
				rarity = card.rarity,
				tier = pace.tier,
				flashed = false,
				nextTick = os.clock(),
				slots = slots,
			}
		end)
	end

	local function pointerDown(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end

	local function pressRoll()
		playUi("click")
		squash()
		hapticTick()
		cameraTick()
		local previous = loop.phase
		loop = RollLoop.press(loop)
		if previous ~= "revealing" then
			beginRoll()
		end
	end

	rollButton.MouseEnter:Connect(function()
		rollButton.BackgroundColor3 = rgb("hover")
	end)
	rollButton.MouseLeave:Connect(function()
		rollButton.BackgroundColor3 = rgb("button")
	end)
	rollButton.InputBegan:Connect(function(input)
		if pointerDown(input) then
			holdingRoll = true
			rollButton.BackgroundColor3 = rgb("press")
			pressRoll()
		end
	end)
	rollButton.InputEnded:Connect(function(input)
		if pointerDown(input) then
			holdingRoll = false
			rollButton.BackgroundColor3 = rgb("button")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if pointerDown(input) then
			holdingRoll = false
		end
	end)
	revealEquip.Activated:Connect(function()
		local uid = revealEquip:GetAttribute("Uid")
		if type(uid) ~= "string" or uid == "" then
			return
		end
		task.spawn(function()
			pcall(hooks.invoke, "EquipItem", uid)
		end)
	end)
	RunService.Heartbeat:Connect(function()
		local active = activeReveal
		if active == nil then
			return
		end
		local elapsed = os.clock() - active.started
		local reduced = UiMotion.reduced(draft)
		local tint = RollLoop.tint(elapsed, active.duration, active.rarity)
		local color = rarityColor3(active.rarity)
		local progress = if active.duration <= 0
			then 1
			else RollReveal.spinProgress(elapsed, active.duration)
		if active.slots ~= nil then
			paintReel(active.slots, UiRouter.reelCenter(#active.slots, progress))
		end
		if active.rarity == "Secret" and not reduced then
			reelStroke.Color = Color3.fromHSV((os.clock() * 0.35) % 1, 0.45, 1)
		end
		if tint ~= nil or elapsed >= active.duration then
			revealCard.BackgroundColor3 = color
			revealStroke.Color = color
			revealStroke.Thickness = if tint ~= nil then 3 else UiTheme.STROKE
		else
			revealCard.BackgroundColor3 = rgb("header")
			revealStroke.Thickness = UiTheme.STROKE
		end
		local morph = RollReveal.morph(elapsed, active.duration)
		local pop = UiRouter.rollPop(active.tier, reduced)
		if morph ~= nil and not reduced then
			revealScale.Scale = RollReveal.morphScale(morph) * pop
		elseif RollLoop.slowmo(elapsed, active.duration, active.rarity, reduced) then
			revealScale.Scale = 1.08
		else
			revealScale.Scale = 1
		end
		if not reduced and active.duration > 0 and os.clock() >= active.nextTick then
			playUi("click")
			active.nextTick = os.clock() + math.clamp(0.05 + (1 - progress) * 0.16, 0.05, 0.2)
		end
		if
			not active.flashed
			and RollLoop.slowmo(elapsed, active.duration, active.rarity, reduced)
			and RollLoop.flash(active.rarity, reduced, draft.camera.flash == "reduced")
		then
			active.flashed = true
			flashCover.BackgroundColor3 = color
			flashCover.BackgroundTransparency = 0.45
			TweenService:Create(
				flashCover,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
			if RollLoop.stinger(active.rarity, reduced) then
				playUi("stinger")
			end
		end
		if elapsed >= active.duration then
			finishReveal()
		end
	end)

	local function applyTextScale()
		local textScale = 1
		if type(draft.access.textScale) == "number" then
			textScale = draft.access.textScale
		end
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
				desc.TextSize =
					math.max(UiTheme.MIN_TEXT, math.floor((base :: number) * textScale + 0.5))
			end
		end
	end

	local function paint()
		paintHints()
		paintHero()
		paintBag()
		paintPets()
		paintRoll()
		clear(raids)
		clear(market)
		clear(pass)
		clear(settingsPage)
		local marks = if type(profile) == "table" then profile.raidMarks or 0 else 0
		emptyState(raids, "raids", "No raid is forming.", "Open finder", function()
			line(raids, string.format("Marks  %d", marks), 2, rgb("gold"))
		end)
		emptyState(market, "market", "Nothing is listed yet.", "Open board", function()
			hooks.onMarket()
		end)
		local tier = if type(profile) == "table" then profile.passTier or 0 else 0
		emptyState(
			pass,
			"pass",
			string.format("The Shard Pass is quiet. Tier %s.", tostring(tier)),
			"Check daily",
			function() end
		)

		local function cycle(label: string, order: number, step: () -> ())
			row(settingsPage, label, order, function()
				step()
				save()
				paint()
				show("settings")
			end)
		end
		cycle("Graphics  " .. draft.graphics.quality, 1, function()
			local order = { "auto", "low", "med", "high" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.graphics.quality then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.graphics.quality = nextId
		end)
		cycle(string.format("VFX  %d%%", math.floor(draft.graphics.vfx * 100 + 0.5)), 2, function()
			draft.graphics.vfx = (math.floor(draft.graphics.vfx * 4 + 1) % 5) / 4
		end)
		cycle("Shadows  " .. (if draft.graphics.shadows then "On" else "Off"), 3, function()
			draft.graphics.shadows = not draft.graphics.shadows
		end)
		cycle(string.format("FPS cap  %d", draft.graphics.fpsCap), 4, function()
			draft.graphics.fpsCap = if draft.graphics.fpsCap == 30
				then 60
				elseif draft.graphics.fpsCap == 60 then 120
				else 30
		end)
		cycle("Roll animation  " .. draft.rolls.animation, 10, function()
			local order = { "full", "short", "instant" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.animation then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.animation = nextId
		end)
		cycle("Skip cutscene at  " .. draft.rolls.skipAt, 11, function()
			local order = { "off", "rare", "epic", "legendary", "mythic" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.skipAt then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.skipAt = nextId
		end)
		cycle(
			"Auto-roll confirm  " .. (if draft.rolls.autoConfirm then "On" else "Off"),
			12,
			function()
				draft.rolls.autoConfirm = not draft.rolls.autoConfirm
				autoOn = draft.rolls.autoConfirm
			end
		)
		cycle("Junk  " .. draft.rolls.autoJunk, 13, function()
			local order = { "ask", "keep", "salvage" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.autoJunk then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.autoJunk = nextId
		end)
		cycle("Below  " .. draft.rolls.junkBelow, 14, function()
			local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.rolls.junkBelow then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.rolls.junkBelow = nextId
		end)
		cycle("Camera shake  " .. (if draft.camera.shake then "On" else "Off"), 20, function()
			draft.camera.shake = not draft.camera.shake
		end)
		cycle("Screen flash  " .. draft.camera.flash, 21, function()
			draft.camera.flash = if draft.camera.flash == "normal" then "reduced" else "normal"
		end)
		cycle(string.format("Sensitivity  %.1f", draft.camera.sensitivity), 22, function()
			draft.camera.sensitivity = math.clamp(draft.camera.sensitivity + 0.2, 0.4, 2)
			if draft.camera.sensitivity >= 2 then
				draft.camera.sensitivity = 0.4
			end
		end)
		cycle(string.format("FOV  %d", math.floor(draft.camera.fov + 0.5)), 23, function()
			draft.camera.fov = if draft.camera.fov >= 90 then 50 else draft.camera.fov + 10
		end)
		cycle(
			string.format("Master  %d%%", math.floor(draft.audio.master * 100 + 0.5)),
			30,
			function()
				draft.audio.master = (math.floor(draft.audio.master * 4 + 1) % 5) / 4
			end
		)
		cycle(
			string.format("Music  %d%%", math.floor(draft.audio.music * 100 + 0.5)),
			31,
			function()
				draft.audio.music = (math.floor(draft.audio.music * 4 + 1) % 5) / 4
			end
		)
		cycle(string.format("SFX  %d%%", math.floor(draft.audio.sfx * 100 + 0.5)), 32, function()
			draft.audio.sfx = (math.floor(draft.audio.sfx * 4 + 1) % 5) / 4
		end)
		cycle(
			string.format("UI audio  %d%%", math.floor(draft.audio.ui * 100 + 0.5)),
			33,
			function()
				draft.audio.ui = (math.floor(draft.audio.ui * 4 + 1) % 5) / 4
			end
		)
		cycle("Hide HUD  " .. (if draft.hud.hidden then "On" else "Off"), 40, function()
			draft.hud.hidden = not draft.hud.hidden
		end)
		cycle(
			string.format("UI scale  %d%%", math.floor(draft.hud.scale * 100 + 0.5)),
			41,
			function()
				local nextScale = draft.hud.scale + 0.05
				if nextScale > 1.25 then
					nextScale = 0.9
				end
				draft.hud.scale = nextScale
				uiScale.Scale = nextScale
			end
		)
		cycle(
			"Damage numbers  " .. (if draft.hud.damageNumbers then "On" else "Off"),
			42,
			function()
				draft.hud.damageNumbers = not draft.hud.damageNumbers
			end
		)
		cycle("Other players' VFX  " .. (if draft.hud.otherVfx then "On" else "Off"), 43, function()
			draft.hud.otherVfx = not draft.hud.otherVfx
		end)
		cycle("Nameplates  " .. (if draft.hud.nameplates then "On" else "Off"), 44, function()
			draft.hud.nameplates = not draft.hud.nameplates
		end)
		local keys = draft.controls.hotkeys
		local keyOrder = 50
		for _, field in ipairs(Keybinds.MENU_ORDER) do
			local fieldName = field
			local label = string.format("Hotkey %s  %s", fieldName, keys[fieldName])
			if capturing == fieldName then
				label = label .. "  press a key"
			end
			cycle(label, keyOrder, function()
				capturing = fieldName
				bindNote = nil
			end)
			keyOrder += 1
		end
		if bindNote ~= nil then
			cycle(bindNote, keyOrder, function() end)
		end
		cycle(
			string.format(
				"Mobile button size  %d%%",
				math.floor(draft.controls.mobileScale * 100 + 0.5)
			),
			60,
			function()
				local nextScale = draft.controls.mobileScale + 0.05
				if nextScale > 1.25 then
					nextScale = 0.9
				end
				draft.controls.mobileScale = nextScale
			end
		)
		cycle("Layout edit  " .. (if draft.controls.layoutEdit then "On" else "Off"), 61, function()
			draft.controls.layoutEdit = not draft.controls.layoutEdit
		end)
		cycle("Trades  " .. draft.social.trades, 70, function()
			local order = { "everyone", "friends", "off" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.social.trades then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.social.trades = nextId
		end)
		cycle("Raid invites  " .. (if draft.social.raidInvites then "On" else "Off"), 71, function()
			draft.social.raidInvites = not draft.social.raidInvites
		end)
		cycle("Chat filter  " .. draft.social.chatFilter, 72, function()
			local order = { "default", "strict", "off" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == draft.social.chatFilter then
					nextId = order[(index % #order) + 1]
				end
			end
			draft.social.chatFilter = nextId
		end)
		cycle(
			"Colorblind pips  " .. (if draft.access.colorblind then "On" else "Off"),
			80,
			function()
				draft.access.colorblind = not draft.access.colorblind
			end
		)
		cycle(
			string.format("Text size  %d%%", math.floor(draft.access.textScale * 100 + 0.5)),
			81,
			function()
				draft.access.textScale = if draft.access.textScale >= 1.4
					then 1
					else draft.access.textScale + 0.1
			end
		)
		cycle(
			"Hold instead of tap  " .. (if draft.access.holdToTap then "On" else "Off"),
			82,
			function()
				draft.access.holdToTap = not draft.access.holdToTap
			end
		)
		if RunService:IsStudio() then
			local actions = {
				"level",
				"gold",
				"keys",
				"gems",
				"dust",
				"tokens",
				"chest",
				"eggs",
				"dungeon",
				"raid",
				"phase",
			}
			for index, action in ipairs(actions) do
				local name = action
				row(settingsPage, "Debug  " .. name, 100 + index, function()
					task.spawn(function()
						pcall(hooks.invoke, "Debug", name)
					end)
				end)
			end
			local grants = {
				{ "tokens", "Shards" },
				{ "luck", "Luck" },
				{ "ascension", "Ascend" },
				{ "materials", "Materials" },
				{ "chests", "Chests" },
				{ "forgeboost", "Forge" },
				{ "prisms", "Prisms" },
				{ "boost", "Boost" },
				{ "restrict", "Region" },
			}
			for index, pair in ipairs(grants) do
				local kind = pair[1]
				row(settingsPage, "Grant  " .. pair[2], 120 + index, function()
					task.spawn(function()
						pcall(hooks.invoke, "DevGrant", kind)
					end)
				end)
			end
			row(settingsPage, "Debug  Boss", 140, function()
				task.spawn(function()
					pcall(hooks.invoke, "Dungeon", "skip")
				end)
			end)
		end
		applyTextScale()
	end

	local function playOpenMotion(fromClosed: boolean)
		if openTween ~= nil then
			openTween:Cancel()
			openTween = nil
		end
		if not fromClosed then
			openScale.Scale = 1
			return
		end
		playUi("open")
		local length = UiMotion.panel(UiMotion.reduced(draft))
		if length <= 0 then
			openScale.Scale = 1
			return
		end
		openScale.Scale = 0.96
		local tween = TweenService:Create(
			openScale,
			TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		openTween = tween
		tween:Play()
	end

	function apply(state: UiRouter.State)
		local wasOpen = route.open
		if UiRouter.top(route) == "class" and UiRouter.top(state) ~= "class" then
			classDismissed = true
		end
		route = state
		backdrop.BackgroundTransparency = 1 - state.dim
		backdrop.Modal = state.open
		setWorldInput(state.open)
		screen.Enabled = state.open
		shadow.Visible = state.open
		panel.Visible = state.open
		classModal.Visible = state.open and UiRouter.top(state) == "class"
		if state.open then
			place()
			show(pageFor(state))
			playOpenMotion(not wasOpen)
		else
			stopRollChain()
			if wasOpen then
				playUi("close")
			end
			playOpenMotion(false)
		end
		hooks.onDim(state.open)
	end

	local function close()
		apply(UiRouter.close(route))
	end

	local function handoffRoll()
		apply(UiRouter.rollHandoff(route))
	end

	local function pop()
		if not route.open then
			return
		end
		apply(UiRouter.pop(route))
	end

	local function follow(nextState: UiRouter.State)
		if nextState.generation == route.generation then
			return
		end
		local prompt = nextState.open
			and nextState.tab == "hero"
			and UiRouter.top(nextState) == "hero"
			and not (route.open and route.tab == "hero" and UiRouter.top(route) == "hero")
		apply(nextState)
		if prompt then
			showClassPrompt(true)
		end
	end

	local function open(id: string)
		paint()
		follow(UiRouter.open(route, id))
	end

	local function toggle(id: string)
		local nextState = UiRouter.toggle(route, id)
		if nextState.open then
			paint()
		end
		follow(nextState)
	end

	for index, tab in ipairs(ClientChrome.TABS) do
		local button = Instance.new("TextButton")
		button.Name = tab.id
		button.LayoutOrder = if tab.id == "settings" then 100 else index
		button.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("body")
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = tabs
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.Size = UDim2.new(0, UiTheme.ACCENT, 1, -12)
		accent.Position = UDim2.fromOffset(0, 6)
		accent.BackgroundColor3 = rgb("accent")
		accent.BorderSizePixel = 0
		accent.Visible = false
		accent.ZIndex = 6
		accent.Parent = button
		iconOn(button, tab.id, 10, 11, 22)
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.BackgroundTransparency = 1
		caption.Position = UDim2.fromOffset(36, 0)
		caption.Size = UDim2.new(1, -40, 1, 0)
		caption.Font = headerFont()
		caption.TextSize = UiTheme.MIN_TEXT
		caption.TextXAlignment = Enum.TextXAlignment.Left
		caption.TextColor3 = rgb("text")
		caption.Text = tab.label
		caption.ZIndex = 6
		caption.Parent = button
		setRest(button, rgb("body"))
		motion(button)
		local tabId = tab.id
		button.Activated:Connect(function()
			paint()
			follow(UiRouter.switch(route, tabId))
		end)
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -8, 0, 8)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = rgb("accent")
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.ZIndex = 7
		dot.Parent = button
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		tabButtons[tab.id] = button
		tabAccents[tab.id] = accent
		tabCaptions[tab.id] = caption
		tabDots[tab.id] = dot
	end
	paintHints()

	backdrop.Activated:Connect(pop)
	closeButton.Activated:Connect(pop)
	classClose.Activated:Connect(function()
		classDismissed = true
		pop()
	end)
	detailBack.Activated:Connect(function()
		detailOpen = false
		detail.Visible = false
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if capturing ~= nil and input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode.Name
			if string.match(key, "^%a$") ~= nil or #key == 1 then
				local letter = string.upper(string.sub(key, 1, 1))
				if string.match(letter, "^%a$") ~= nil then
					local nextKeys, warning =
						Keybinds.assign(draft.controls.hotkeys, capturing, letter)
					if warning ~= nil then
						bindNote = warning
					else
						draft.controls.hotkeys = nextKeys
						bindNote = nil
						if route.open then
							bindSinkKeys()
						end
						save()
					end
					capturing = nil
					paint()
					show("settings")
				end
			end
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if route.open then
				pop()
			end
			return
		end
		if route.open and input.KeyCode == Enum.KeyCode.ButtonL1 then
			follow(UiRouter.shoulder(route, -1))
			return
		end
		if route.open and input.KeyCode == Enum.KeyCode.ButtonR1 then
			follow(UiRouter.shoulder(route, 1))
			return
		end
		if route.open then
			local nextState = UiRouter.key(route, input.KeyCode.Name, draft.controls.hotkeys)
			if nextState.generation ~= route.generation then
				follow(nextState)
			end
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local nextState = UiRouter.key(route, input.KeyCode.Name, draft.controls.hotkeys)
		if nextState.open then
			paint()
		end
		follow(nextState)
	end)

	-- Combat pins Humanoid.Health to MaxHealth, so Died never fires on a
	-- dungeon down. The chain follows ShardfallHp and a defeat / down
	-- CombatFx. A body that loads at 0 Health is not that down, and a Died
	-- from a character that is no longer ours must not latch the new life.
	local localPlayer = Players.LocalPlayer
	local holdDown = false

	local function aliveCharacter(): Model?
		if localPlayer == nil then
			return nil
		end
		return localPlayer.Character
	end

	local function stillHere(character: Model): boolean
		return aliveCharacter() == character
	end

	local function readCombatHp(character: Model): number?
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return nil
		end
		local hp = root:GetAttribute("ShardfallHp")
		if type(hp) ~= "number" or hp ~= hp or hp == math.huge then
			return nil
		end
		return hp
	end

	local function markDown(character: Model)
		if not stillHere(character) then
			return
		end
		holdDown = true
		playerAlive = false
		stopRollChain()
	end

	local function noteCombatHp(character: Model)
		if not stillHere(character) then
			return
		end
		local hp = readCombatHp(character)
		if hp == nil then
			return
		end
		if hp <= 0 then
			markDown(character)
			return
		end
		if not holdDown then
			playerAlive = true
		end
	end

	local function bindHumanoid(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			local waited = character:WaitForChild("Humanoid", 8)
			if waited ~= nil and waited:IsA("Humanoid") then
				humanoid = waited
			end
		end
		if humanoid == nil or not humanoid:IsA("Humanoid") or not stillHere(character) then
			return
		end
		local sawPositive = humanoid.Health > 0
		humanoid.HealthChanged:Connect(function(health: number)
			if health > 0 then
				sawPositive = true
			end
		end)
		humanoid.Died:Connect(function()
			if not stillHere(character) or not sawPositive then
				return
			end
			markDown(character)
		end)
	end

	local function bindCombatHp(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			local waited = character:WaitForChild("HumanoidRootPart", 8)
			if waited ~= nil and waited:IsA("BasePart") then
				root = waited
			end
		end
		if root == nil or not root:IsA("BasePart") or not stillHere(character) then
			return
		end
		noteCombatHp(character)
		root:GetAttributeChangedSignal("ShardfallHp"):Connect(function()
			noteCombatHp(character)
		end)
	end

	local function bindLife(character: Model)
		task.spawn(bindHumanoid, character)
		task.spawn(bindCombatHp, character)
	end

	local function watchCombatFx()
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if folder == nil then
			local waited = ReplicatedStorage:WaitForChild("Remotes", 30)
			if waited ~= nil then
				folder = waited
			end
		end
		if folder == nil then
			return
		end
		local remote = folder:FindFirstChild("CombatFx")
		if remote == nil then
			local waited = folder:WaitForChild("CombatFx", 30)
			if waited ~= nil then
				remote = waited
			end
		end
		if remote == nil or not remote:IsA("RemoteEvent") then
			return
		end
		remote.OnClientEvent:Connect(function(payload: any)
			if type(payload) ~= "table" then
				return
			end
			local character = aliveCharacter()
			if character == nil then
				return
			end
			local kind = payload.kind
			if kind == "defeat" or kind == "down" then
				markDown(character)
				return
			end
			if kind ~= "hp" then
				return
			end
			local hp = payload.hp
			if type(hp) ~= "number" or hp ~= hp or hp == math.huge then
				return
			end
			if hp <= 0 then
				markDown(character)
			elseif not holdDown then
				playerAlive = true
			end
		end)
	end

	-- The roll Heartbeat is already connected. This one runs after it, so a
	-- down this frame fails the chain check before the hold clears.
	RunService.Heartbeat:Connect(function()
		if not holdDown then
			return
		end
		if rollBusy or activeReveal ~= nil or loop.phase ~= "idle" then
			playerAlive = false
			return
		end
		holdDown = false
		local character = aliveCharacter()
		if character == nil then
			playerAlive = true
			return
		end
		local hp = readCombatHp(character)
		playerAlive = hp == nil or hp > 0
	end)

	if localPlayer ~= nil then
		localPlayer.CharacterAdded:Connect(function(character)
			holdDown = false
			playerAlive = true
			task.spawn(bindLife, character)
		end)
		if localPlayer.Character ~= nil then
			task.spawn(bindLife, localPlayer.Character)
		end
		task.spawn(watchCombatFx)
	end

	paint()

	return {
		open = open,
		close = close,
		toggle = toggle,
		handoffRoll = handoffRoll,
		isOpen = function(): boolean
			return route.open
		end,
		current = function(): string
			return pageFor(route)
		end,
		root = function(): string
			return route.stack[1] or route.tab
		end,
		hasModal = function(): boolean
			return #route.stack > 1
		end,
		promptClass = function(force: boolean?)
			showClassPrompt(force == true)
		end,
		setProfile = function(nextProfile: any)
			profile = nextProfile
			serverSince = nil
			serverEpic = nil
			if type(nextProfile) == "table" and type(nextProfile.uiSettings) == "table" then
				draft = Settings.normalize(nextProfile.uiSettings)
				uiScale.Scale = draft.hud.scale
				autoOn = draft.rolls.autoConfirm == true
				paintHints()
			end
			if route.open then
				paint()
				show(pageFor(route))
			else
				publishBadges()
			end
			applyTextScale()
			showClassPrompt(false)
		end,
	}
end

return MenuHub
