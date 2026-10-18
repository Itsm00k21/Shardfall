--!strict

--[[
	One modal stack. Tabs replace each other. Esc and the backdrop pop.
	The panel is a Frame, so the first open still receives tab clicks.
	The backdrop dim is copied off UiRouter on every open and every close.
	Debug grants live here and only while Studio is running.

	Bag, pets, roll, and hero draw cards. Market, raids, and the pass
	use an empty state. A missing class opens the class cards.

	The roll tab presents the server result. RollHype tracks the session,
	the Epic and Legendary pity bars, and the full-animation build-up.
	A close call is one beat beside the card. The client does not decide
	the roll, and it does not advance pity.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ActionDrag = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ActionDrag"))
local ActionSlots = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ActionSlots"))
local BagBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BagBoard"))
local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ClientChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientChrome"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local CrackCard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrackCard"))
local CrackReveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CrackReveal"))
local HeroBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeroBoard"))
local HeroView = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeroView"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local InventoryView =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryView"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))
local NotifyBadges = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NotifyBadges"))
local PetRoster = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PetRoster"))
local Pools = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pools"))
local Rarities = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rarities"))
local RarityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RarityConfig"))
local RollBoard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollBoard"))
local RollFocus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollFocus"))
local RollHype = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollHype"))
local RollLoop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollLoop"))
local RollRefuse = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollRefuse"))
local RollReveal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollReveal"))
local RollSpot = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RollSpot"))
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
	onClassSheet: (() -> ())?,
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
	-- Widgets, session fields, and painters live on tables so this function
	-- stays under Roblox's 200-local register cap.
	local hubState: { [string]: any } = {}
	local hubFn: { [string]: any } = {}
	hubState.screen = Instance.new("ScreenGui")
	hubState.screen.Name = "ShardfallHub"
	hubState.screen.ResetOnSpawn = false
	hubState.screen.DisplayOrder = 80
	hubState.screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	hubState.screen.IgnoreGuiInset = false
	hubState.screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hubState.screen.Enabled = false
	hubState.screen.Parent = playerGui
	hubState.uiScale = Instance.new("UIScale")
	hubState.uiScale.Name = "HubScale"
	hubState.uiScale.Scale = 1
	hubState.uiScale.Parent = hubState.screen

	hubState.backdrop = Instance.new("TextButton")
	hubState.backdrop.Name = "Backdrop"
	hubState.backdrop.Size = UDim2.fromScale(1, 1)
	hubState.backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	hubState.backdrop.BackgroundTransparency = 1 - UiTheme.BACKDROP
	hubState.backdrop.Text = ""
	hubState.backdrop.AutoButtonColor = false
	hubState.backdrop.Modal = false
	hubState.backdrop.Active = true
	hubState.backdrop.ZIndex = 1
	hubState.backdrop.Parent = hubState.screen

	hubState.shadow = Instance.new("Frame")
	hubState.shadow.Name = "Shadow"
	hubState.shadow.BackgroundColor3 = rgb("shadow")
	hubState.shadow.BackgroundTransparency = UiTheme.SHADOW
	hubState.shadow.BorderSizePixel = 0
	hubState.shadow.ZIndex = 2
	hubState.shadow.Visible = false
	hubState.shadow.Parent = hubState.screen
	hubState.shadowCorner = Instance.new("UICorner")
	hubState.shadowCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.shadowCorner.Parent = hubState.shadow

	hubState.panel = Instance.new("Frame")
	hubState.panel.Name = "Panel"
	hubState.panel.BackgroundColor3 = rgb("body")
	hubState.panel.BackgroundTransparency = 0
	hubState.panel.BorderSizePixel = 0
	hubState.panel.ClipsDescendants = true
	hubState.panel.Visible = false
	hubState.panel.ZIndex = 3
	hubState.panel.Parent = hubState.screen
	hubState.openScale = Instance.new("UIScale")
	hubState.openScale.Name = "OpenScale"
	hubState.openScale.Scale = 1
	hubState.openScale.Parent = hubState.panel
	hubState.panelCorner = Instance.new("UICorner")
	hubState.panelCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.panelCorner.Parent = hubState.panel
	hubState.panelStroke = Instance.new("UIStroke")
	hubState.panelStroke.Thickness = UiTheme.STROKE
	hubState.panelStroke.Color = rgb("divider")
	hubState.panelStroke.Parent = hubState.panel
	hubState.gradient = Instance.new("UIGradient")
	hubState.gradient.Rotation = 90
	hubState.gradient.Color = ColorSequence.new(rgb("header"), rgb("body"))
	hubState.gradient.Parent = hubState.panel

	hubState.header = Instance.new("Frame")
	hubState.header.Name = "Header"
	hubState.header.Size = UDim2.new(1, 0, 0, UiTheme.HEADER + UiTheme.PAD)
	hubState.header.BackgroundColor3 = rgb("header")
	hubState.header.BackgroundTransparency = 0
	hubState.header.BorderSizePixel = 0
	hubState.header.ZIndex = 4
	hubState.header.Parent = hubState.panel
	hubState.headerRule = Instance.new("Frame")
	hubState.headerRule.Name = "Divider"
	hubState.headerRule.AnchorPoint = Vector2.new(0, 1)
	hubState.headerRule.Position = UDim2.fromScale(0, 1)
	hubState.headerRule.Size = UDim2.new(1, 0, 0, 1)
	hubState.headerRule.BackgroundColor3 = rgb("divider")
	hubState.headerRule.BorderSizePixel = 0
	hubState.headerRule.Parent = hubState.header

	hubState.tabs = Instance.new("ScrollingFrame")
	hubState.tabs.Name = "Tabs"
	hubState.tabs.BackgroundTransparency = 1
	hubState.tabs.BorderSizePixel = 0
	hubState.tabs.ScrollBarThickness = 4
	hubState.tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hubState.tabs.CanvasSize = UDim2.new()
	hubState.tabs.ZIndex = 4
	hubState.tabs.Parent = hubState.panel
	hubState.tabList = Instance.new("UIListLayout")
	hubState.tabList.FillDirection = Enum.FillDirection.Vertical
	hubState.tabList.Padding = UDim.new(0, UiTheme.PAD)
	hubState.tabList.SortOrder = Enum.SortOrder.LayoutOrder
	hubState.tabList.Parent = hubState.tabs

	hubState.body = Instance.new("Frame")
	hubState.body.Name = "Body"
	hubState.body.BackgroundTransparency = 1
	hubState.body.ZIndex = 4
	hubState.body.Parent = hubState.panel
	hubState.tabScale = Instance.new("UIScale")
	hubState.tabScale.Name = "TabScale"
	hubState.tabScale.Scale = 1
	hubState.tabScale.Parent = hubState.body

	hubState.title = Instance.new("TextLabel")
	hubState.title.Name = "Title"
	hubState.title.BackgroundTransparency = 1
	hubState.title.Position = UDim2.fromOffset(148, 8)
	hubState.title.Size = UDim2.new(1, -220, 0, 32)
	hubState.title.Font = headerFont()
	hubState.title.TextSize = 20
	hubState.title.TextXAlignment = Enum.TextXAlignment.Left
	hubState.title.TextColor3 = rgb("text")
	hubState.title.Text = "Menu"
	hubState.title.ZIndex = 5
	hubState.title.Parent = hubState.header

	hubState.closeButton = Instance.new("TextButton")
	hubState.closeButton.Name = "Close"
	hubState.closeButton.AnchorPoint = Vector2.new(1, 0)
	hubState.closeButton.Position = UDim2.new(1, -8, 0, 8)
	hubState.closeButton.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	hubState.closeButton.BackgroundColor3 = rgb("body")
	hubState.closeButton.Font = headerFont()
	hubState.closeButton.TextSize = UiTheme.MIN_TEXT
	hubState.closeButton.TextColor3 = rgb("text")
	hubState.closeButton.Text = "X"
	hubState.closeButton.ZIndex = 5
	hubState.closeButton.Parent = hubState.header
	hubState.closeCorner = Instance.new("UICorner")
	hubState.closeCorner.CornerRadius = UDim.new(0, 8)
	hubState.closeCorner.Parent = hubState.closeButton
	hubState.closeStroke = Instance.new("UIStroke")
	hubState.closeStroke.Thickness = UiTheme.STROKE
	hubState.closeStroke.Color = rgb("divider")
	hubState.closeStroke.Parent = hubState.closeButton

	hubState.classModal = Instance.new("Frame")
	hubState.classModal.Name = "ClassPick"
	hubState.classModal.Size = UDim2.fromScale(1, 1)
	hubState.classModal.BackgroundTransparency = 1
	hubState.classModal.Visible = false
	hubState.classModal.Active = false
	hubState.classModal.ZIndex = 8
	hubState.classModal.Parent = hubState.screen
	hubState.classPanel = Instance.new("Frame")
	hubState.classPanel.Name = "Card"
	hubState.classPanel.BackgroundColor3 = rgb("body")
	hubState.classPanel.BorderSizePixel = 0
	hubState.classPanel.ZIndex = 9
	hubState.classPanel.Parent = hubState.classModal
	hubState.classCorner = Instance.new("UICorner")
	hubState.classCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.classCorner.Parent = hubState.classPanel
	hubState.classStroke = Instance.new("UIStroke")
	hubState.classStroke.Thickness = UiTheme.STROKE_BOLD
	hubState.classStroke.Color = rgb("accent")
	hubState.classStroke.Parent = hubState.classPanel
	hubState.classGradient = Instance.new("UIGradient")
	hubState.classGradient.Rotation = 90
	hubState.classGradient.Color = ColorSequence.new(rgb("header"), rgb("body"))
	hubState.classGradient.Parent = hubState.classPanel
	hubState.classHeader = Instance.new("TextLabel")
	hubState.classHeader.Name = "Title"
	hubState.classHeader.BackgroundTransparency = 1
	hubState.classHeader.Position = UDim2.fromOffset(16, 8)
	hubState.classHeader.Size = UDim2.new(1, -80, 0, 32)
	hubState.classHeader.Font = headerFont()
	hubState.classHeader.TextSize = 20
	hubState.classHeader.TextXAlignment = Enum.TextXAlignment.Left
	hubState.classHeader.TextColor3 = rgb("text")
	hubState.classHeader.Text = "Choose a class"
	hubState.classHeader.ZIndex = 10
	hubState.classHeader.Parent = hubState.classPanel
	hubState.classClose = Instance.new("TextButton")
	hubState.classClose.Name = "Close"
	hubState.classClose.AnchorPoint = Vector2.new(1, 0)
	hubState.classClose.Position = UDim2.new(1, -8, 0, 8)
	hubState.classClose.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	hubState.classClose.BackgroundColor3 = rgb("header")
	hubState.classClose.Font = headerFont()
	hubState.classClose.TextSize = UiTheme.MIN_TEXT
	hubState.classClose.TextColor3 = rgb("text")
	hubState.classClose.Text = "X"
	hubState.classClose.ZIndex = 10
	hubState.classClose.Parent = hubState.classPanel
	hubState.classCloseCorner = Instance.new("UICorner")
	hubState.classCloseCorner.CornerRadius = UDim.new(0, 8)
	hubState.classCloseCorner.Parent = hubState.classClose
	hubState.classList = Instance.new("ScrollingFrame")
	hubState.classList.Name = "Cards"
	hubState.classList.Position = UDim2.fromOffset(12, 56)
	hubState.classList.Size = UDim2.new(1, -24, 1, -68)
	hubState.classList.BackgroundTransparency = 1
	hubState.classList.BorderSizePixel = 0
	hubState.classList.ScrollBarThickness = 6
	hubState.classList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hubState.classList.CanvasSize = UDim2.new()
	hubState.classList.ZIndex = 10
	hubState.classList.Parent = hubState.classPanel
	hubState.classGrid = Instance.new("UIGridLayout")
	hubState.classGrid.SortOrder = Enum.SortOrder.LayoutOrder
	hubState.classGrid.Parent = hubState.classList

	hubState.profile = nil
	hubState.draft = Settings.default()
	hubState.route = UiRouter.initial()

	hubState.pages = {}
	hubState.capturing = nil
	hubState.bindNote = nil
	hubState.classDismissed = false
	hubState.detailOpen = false
	hubState.selectedUid = nil
	hubState.autoOn = false
	hubState.focusCut = false
	hubState.windowFocused = true
	pcall(function()
		if UserInputService.WindowFocused == false then
			hubState.windowFocused = false
		end
	end)
	hubState.quickOn = false
	hubState.infoOpen = false
	hubState.rollKind = "gear"
	hubState.pendingCount = 1
	hubState.replayResult = nil
	hubState.batchLeft = {}
	hubState.summaryItems = {}
	hubState.batching = false
	hubState.pendingFace = nil
	hubState.crackNamed = false
	hubState.crackSounded = false
	hubState.bagFilter = BagBoard.defaultFilter()
	hubState.seen = NotifyBadges.blank()
	hubState.salvageRarity = "Rare"
	hubState.salvageArmed = false
	hubState.stopAt = "Off"
	hubState.loop = RollLoop.idle()
	hubState.holdingRoll = false
	hubState.rollBusy = false
	hubState.playerAlive = true
	hubState.openedHype = RollHype.fresh(nil)
	hubState.hype = if hubState.openedHype.ok
		then hubState.openedHype.state
		else {
			rolls = 0,
			streak = 0,
			best = nil,
			personalBest = false,
			allTime = nil,
		}
	hubState.bestPull = nil
	hubState.slideHistory = false
	hubState.revealToken = 0
	hubState.lastCrack = 0
	hubState.pityTweens = {}
	hubState.epicFillShown = 0
	hubState.legendaryFillShown = 0
	hubState.epicFlashRoll = -1
	hubState.legendaryFlashRoll = -1
	hubState.serverSince = nil
	hubState.serverEpic = nil
	hubState.lastMissed = false
	hubState.lastLanded = nil
	hubState.toastToken = 0
	hubState.sessionRolls = {}
	hubState.sessionTemplates = {}
	hubState.activeReveal = nil
	-- A newer roll bumps this and cancels the previous card tweens so a
	-- late spin cannot paint the older name over the newer result.
	hubState.cardGeneration = 0
	hubState.cardTweens = {}

	function hubFn.bumpCardGeneration()
		hubState.cardGeneration += 1
		local pending = hubState.cardTweens
		hubState.cardTweens = {}
		for _, tween in ipairs(pending) do
			tween:Cancel()
		end
		hubState.activeReveal = nil
	end

	function hubFn.playCardTween(tween: Tween)
		table.insert(hubState.cardTweens, tween)
		tween:Play()
	end
	hubFn.paintReelIdle = function(_caption: string) end
	hubFn.showMilestone = function(_text: string) end
	hubFn.hideCloseBeat = function() end
	hubFn.showCloseBeat = function(_rarity: string) end
	hubState.tabDots = {}
	hubState.restColor = {}
	hubState.tabButtons = {}
	hubState.tabAccents = {}
	hubState.tabCaptions = {}
	hubState.openTween = nil
	hubState.worldBlocked = false
	hubState.controls = nil

	function hubFn.sink(): Enum.ContextActionResult
		return Enum.ContextActionResult.Sink
	end

	function hubFn.playerControls(): any
		if hubState.controls ~= nil then
			return hubState.controls
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
			hubState.controls = fetched
		end
		return hubState.controls
	end

	-- Modal on the backdrop stops the mouse from steering the camera.
	-- The sink stops movement, sprint, and combat. Tab letters stay free.
	function hubFn.bindSinkKeys()
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
			hubFn.sink,
			false,
			Enum.ContextActionPriority.High.Value,
			table.unpack(codes)
		)
	end

	function hubFn.setWorldInput(blocked: boolean)
		if blocked == hubState.worldBlocked then
			return
		end
		hubState.worldBlocked = blocked
		if blocked then
			hubFn.bindSinkKeys()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		else
			ContextActionService:UnbindAction("ShardfallMenuSink")
		end
		local pad = hubFn.playerControls()
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

	function hubFn.view(): (number, number)
		local size = hubState.screen.AbsoluteSize
		return if size.X >= 200 then size.X else 1280, if size.Y >= 200 then size.Y else 800
	end

	hubFn.fitRoll = function() end

	function hubFn.place()
		local vx, vy = hubFn.view()
		local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
		hubState.panel.Position = UDim2.fromOffset(box.x, box.y)
		hubState.panel.Size = UDim2.fromOffset(box.w, box.h)
		hubState.shadow.Position = UDim2.fromOffset(box.x + 4, box.y + 6)
		hubState.shadow.Size = UDim2.fromOffset(box.w, box.h)
		local column = HudLayout.tabColumn(box.w, box.h)
		local headerH = UiTheme.HEADER + UiTheme.PAD
		hubState.tabs.Position = UDim2.fromOffset(column.x, headerH)
		hubState.tabs.Size = UDim2.fromOffset(column.w, math.max(44, box.h - headerH - 8))
		local inner = HudLayout.hubBody(box.w, box.h)
		hubState.body.Position = UDim2.fromOffset(inner.x, inner.y)
		hubState.body.Size = UDim2.fromOffset(inner.w, inner.h)
		hubState.title.Position = UDim2.fromOffset(inner.x, 8)
		hubState.title.Size = UDim2.fromOffset(math.max(44, inner.w - 8), 32)
		hubState.classPanel.Position = UDim2.fromOffset(box.x + inner.x, box.y + inner.y)
		hubState.classPanel.Size = UDim2.fromOffset(inner.w, inner.h)
		local grid = HudLayout.cardGrid(math.max(44, inner.w - 8), inner.h, 4)
		hubState.classGrid.CellSize = UDim2.fromOffset(grid.cellW, grid.cellH)
		hubState.classGrid.CellPadding = UDim2.fromOffset(grid.gap, grid.gap)
		hubFn.fitRoll()
	end
	hubFn.place()
	hubState.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(hubFn.place)

	hubState.shownId = ""

	function hubFn.playUi(action: string)
		local volume = UiSfx.volume(hubState.draft.audio.master, hubState.draft.audio.ui)
		if volume <= 0 then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "UiSfx"
		sound.SoundId = UiSfx.clip(action)
		sound.Volume = volume
		sound.Parent = hubState.screen
		sound:Play()
		task.delay(1.5, function()
			sound:Destroy()
		end)
	end

	function hubFn.motion(button: GuiButton)
		local pop = Instance.new("UIScale")
		pop.Name = "Press"
		pop.Parent = button
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = rgb("hover")
		end)
		button.MouseLeave:Connect(function()
			local rest = hubState.restColor[button]
			button.BackgroundColor3 = if rest ~= nil then rest else rgb("body")
		end)
		local function pressed(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		button.InputBegan:Connect(function(input)
			if pressed(input) then
				button.BackgroundColor3 = rgb("press")
				hubFn.playUi("press")
				local length = UiMotion.press(UiMotion.reduced(hubState.draft))
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
				local rest = hubState.restColor[button]
				button.BackgroundColor3 = if rest ~= nil then rest else rgb("body")
				local length = UiMotion.press(UiMotion.reduced(hubState.draft))
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

	function hubFn.setRest(button: GuiButton, color: Color3)
		hubState.restColor[button] = color
		button.BackgroundColor3 = color
	end

	hubFn.motion(hubState.closeButton)
	hubFn.setRest(hubState.closeButton, rgb("body"))
	hubFn.motion(hubState.classClose)
	hubFn.setRest(hubState.classClose, rgb("header"))

	function hubFn.iconOn(parent: Instance, name: string, px: number, py: number, size: number)
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

	function hubFn.page(id: string): Frame
		local frame = Instance.new("Frame")
		frame.Name = id
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		frame.Parent = hubState.body
		hubState.pages[id] = frame
		return frame
	end

	function hubFn.scroll(host: Frame): ScrollingFrame
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

	function hubFn.clear(host: Instance)
		for _, child in ipairs(host:GetChildren()) do
			if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") then
				continue
			end
			child:Destroy()
		end
	end

	function hubFn.applyGrid(host: ScrollingFrame, count: number)
		local layout = host:FindFirstChildOfClass("UIGridLayout")
		if layout == nil then
			return
		end
		local width = host.AbsoluteSize.X
		local height = host.AbsoluteSize.Y
		if width < 44 then
			local vx, vy = hubFn.view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			width = inner.w
			height = inner.h
		end
		local spec = HudLayout.cardGrid(math.max(44, width - 16), math.max(44, height), count)
		layout.CellSize = UDim2.fromOffset(spec.cellW, spec.cellH)
		layout.CellPadding = UDim2.fromOffset(spec.gap, spec.gap)
	end

	hubState.hero = hubFn.scroll(hubFn.page("hero"))
	hubState.bag = hubFn.scroll(hubFn.page("bag"))
	hubState.sets = hubFn.scroll(hubFn.page("sets"))
	hubState.pets = hubFn.scroll(hubFn.page("pets"))
	hubState.rollPage = hubFn.page("roll")
	hubState.roll = hubFn.scroll(hubState.rollPage)
	hubState.roll.Size = UDim2.new(1, 0, 1, -88)

	hubState.rollButton = Instance.new("TextButton")
	hubState.rollButton.Name = "Roll"
	hubState.rollButton.AnchorPoint = Vector2.new(0, 1)
	hubState.rollButton.Position = UDim2.new(0, UiTheme.PAD, 1, -UiTheme.PAD)
	hubState.rollButton.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 72)
	hubState.rollButton.BackgroundColor3 = rgb("button")
	hubState.rollButton.Font = headerFont()
	hubState.rollButton.TextSize = 28
	hubState.rollButton.TextColor3 = rgb("text")
	hubState.rollButton.Text = "Roll"
	hubState.rollButton.AutoButtonColor = false
	hubState.rollButton.ZIndex = 6
	hubState.rollButton.Parent = hubState.rollPage
	hubState.rollCorner = Instance.new("UICorner")
	hubState.rollCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.rollCorner.Parent = hubState.rollButton
	hubState.rollStroke = Instance.new("UIStroke")
	hubState.rollStroke.Thickness = UiTheme.STROKE_BOLD
	hubState.rollStroke.Color = rgb("accent")
	hubState.rollStroke.Parent = hubState.rollButton
	hubState.pulseScale = Instance.new("UIScale")
	hubState.pulseScale.Name = "Pulse"
	hubState.pulseScale.Parent = hubState.rollButton
	hubState.pressScale = Instance.new("UIScale")
	hubState.pressScale.Name = "Press"
	hubState.pressScale.Parent = hubState.rollButton
	hubState.pulseTween = nil

	function hubFn.setPulse(on: boolean)
		if hubState.pulseTween ~= nil then
			hubState.pulseTween:Cancel()
			hubState.pulseTween = nil
		end
		if not on or UiMotion.reduced(hubState.draft) then
			hubState.pulseScale.Scale = 1
			return
		end
		hubState.pulseScale.Scale = 1
		local tween = TweenService:Create(
			hubState.pulseScale,
			TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.06 }
		)
		hubState.pulseTween = tween
		tween:Play()
	end

	hubFn.restShard = function() end

	function hubFn.stopRollChain()
		hubState.revealToken += 1
		hubState.holdingRoll = false
		hubState.activeReveal = nil
		hubState.replayResult = nil
		hubState.batchLeft = {}
		hubState.batching = false
		hubState.pendingCount = 1
		hubState.pendingFace = nil
		hubState.crackNamed = false
		hubState.crackSounded = false
		hubState.loop = RollLoop.idle()
		hubState.rollBusy = false
		hubFn.setPulse(true)
		hubFn.hideCloseBeat()
		hubFn.restShard()
		hubFn.paintReelIdle("Roll")
	end

	hubState.revealCard = Instance.new("Frame")
	hubState.revealCard.Name = "Reveal"
	hubState.revealCard.AnchorPoint = Vector2.new(0.5, 1)
	hubState.revealCard.Position = UDim2.new(0.5, 0, 1, -96)
	hubState.revealCard.Size = UDim2.new(1, -24, 0, 112)
	hubState.revealCard.BackgroundColor3 = rgb("header")
	hubState.revealCard.BorderSizePixel = 0
	hubState.revealCard.ClipsDescendants = true
	hubState.revealCard.Visible = false
	hubState.revealCard.ZIndex = 8
	hubState.revealCard.Parent = hubState.rollPage
	hubState.revealCorner = Instance.new("UICorner")
	hubState.revealCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.revealCorner.Parent = hubState.revealCard
	hubState.revealStroke = Instance.new("UIStroke")
	hubState.revealStroke.Thickness = UiTheme.STROKE
	hubState.revealStroke.Color = rgb("accent")
	hubState.revealStroke.Parent = hubState.revealCard
	hubState.revealScale = Instance.new("UIScale")
	hubState.revealScale.Name = "Card"
	hubState.revealScale.Parent = hubState.revealCard
	hubState.revealTitle = Instance.new("TextLabel")
	hubState.revealTitle.Name = "Name"
	hubState.revealTitle.BackgroundTransparency = 1
	hubState.revealTitle.Position = UDim2.fromOffset(12, 8)
	hubState.revealTitle.Size = UDim2.new(1, -120, 0, 32)
	hubState.revealTitle.Font = headerFont()
	hubState.revealTitle.TextSize = 22
	hubState.revealTitle.TextXAlignment = Enum.TextXAlignment.Left
	hubState.revealTitle.TextColor3 = rgb("text")
	hubState.revealTitle.Text = ""
	hubState.revealTitle.ZIndex = 9
	hubState.revealTitle.Parent = hubState.revealCard
	hubState.revealRarity = Instance.new("TextLabel")
	hubState.revealRarity.Name = "Rarity"
	hubState.revealRarity.BackgroundTransparency = 1
	hubState.revealRarity.Position = UDim2.fromOffset(12, 40)
	hubState.revealRarity.Size = UDim2.new(1, -120, 0, 24)
	hubState.revealRarity.Font = bodyFont()
	hubState.revealRarity.TextSize = UiTheme.MIN_TEXT
	hubState.revealRarity.TextXAlignment = Enum.TextXAlignment.Left
	hubState.revealRarity.TextColor3 = rgb("text")
	hubState.revealRarity.Text = ""
	hubState.revealRarity.ZIndex = 9
	hubState.revealRarity.Parent = hubState.revealCard
	hubState.revealNew = Instance.new("TextLabel")
	hubState.revealNew.Name = "New"
	hubState.revealNew.AnchorPoint = Vector2.new(1, 0)
	hubState.revealNew.Position = UDim2.new(1, -8, 0, 8)
	hubState.revealNew.Size = UDim2.fromOffset(72, 28)
	hubState.revealNew.BackgroundColor3 = rgb("accent")
	hubState.revealNew.Font = headerFont()
	hubState.revealNew.TextSize = UiTheme.MIN_TEXT
	hubState.revealNew.TextColor3 = rgb("ink")
	hubState.revealNew.Text = "NEW!"
	hubState.revealNew.Visible = false
	hubState.revealNew.ZIndex = 9
	hubState.revealNew.Parent = hubState.revealCard
	hubState.newCorner = Instance.new("UICorner")
	hubState.newCorner.CornerRadius = UDim.new(0, 8)
	hubState.newCorner.Parent = hubState.revealNew
	hubState.revealBest = Instance.new("TextLabel")
	hubState.revealBest.Name = "PersonalBest"
	hubState.revealBest.AnchorPoint = Vector2.new(1, 0)
	hubState.revealBest.Position = UDim2.new(1, -8, 0, 40)
	hubState.revealBest.Size = UDim2.fromOffset(120, 28)
	hubState.revealBest.BackgroundColor3 = rgb("gold")
	hubState.revealBest.Font = headerFont()
	hubState.revealBest.TextSize = UiTheme.MIN_TEXT
	hubState.revealBest.TextColor3 = rgb("ink")
	hubState.revealBest.Text = ""
	hubState.revealBest.Visible = false
	hubState.revealBest.ZIndex = 9
	hubState.revealBest.Parent = hubState.revealCard
	hubState.bestCorner = Instance.new("UICorner")
	hubState.bestCorner.CornerRadius = UDim.new(0, 8)
	hubState.bestCorner.Parent = hubState.revealBest
	hubState.revealFly = Instance.new("TextLabel")
	hubState.revealFly.Name = "Drip"
	hubState.revealFly.BackgroundTransparency = 1
	hubState.revealFly.Position = UDim2.fromOffset(12, 72)
	hubState.revealFly.Size = UDim2.fromOffset(80, 28)
	hubState.revealFly.Font = headerFont()
	hubState.revealFly.TextSize = 20
	hubState.revealFly.TextXAlignment = Enum.TextXAlignment.Left
	hubState.revealFly.TextColor3 = rgb("ok")
	hubState.revealFly.Text = "+1"
	hubState.revealFly.ZIndex = 9
	hubState.revealFly.Parent = hubState.revealCard
	hubState.revealEquip = Instance.new("TextButton")
	hubState.revealEquip.Name = "Equip"
	hubState.revealEquip.AnchorPoint = Vector2.new(1, 1)
	hubState.revealEquip.Position = UDim2.new(1, -8, 1, -8)
	hubState.revealEquip.Size = UDim2.fromOffset(120, UiTheme.TOUCH)
	hubState.revealEquip.BackgroundColor3 = rgb("ok")
	hubState.revealEquip.Font = headerFont()
	hubState.revealEquip.TextSize = UiTheme.MIN_TEXT
	hubState.revealEquip.TextColor3 = rgb("ink")
	hubState.revealEquip.Text = "▲ Equip"
	hubState.revealEquip.AutoButtonColor = false
	hubState.revealEquip.Visible = false
	hubState.revealEquip.ZIndex = 9
	hubState.revealEquip.Parent = hubState.revealCard
	hubState.revealEquipCorner = Instance.new("UICorner")
	hubState.revealEquipCorner.CornerRadius = UDim.new(0, 8)
	hubState.revealEquipCorner.Parent = hubState.revealEquip
	hubState.flashCover = Instance.new("Frame")
	hubState.flashCover.Name = "Flash"
	hubState.flashCover.Size = UDim2.fromScale(1, 1)
	hubState.flashCover.BackgroundColor3 = Color3.new(1, 1, 1)
	hubState.flashCover.BackgroundTransparency = 1
	hubState.flashCover.BorderSizePixel = 0
	hubState.flashCover.Active = false
	hubState.flashCover.ZIndex = 12
	hubState.flashCover.Parent = hubState.rollPage

	-- Same card clear a miss uses. Leaving the tab and every other
	-- beginRoll hide go through here so the previous name cannot stay.
	function hubFn.blankReveal()
		local face = RollReveal.face(nil)
		hubFn.bumpCardGeneration()
		hubState.activeReveal = nil
		hubState.revealCard.Visible = face.visible
		hubState.revealTitle.Text = face.name
		hubState.revealRarity.Text = face.rarity
		hubState.revealNew.Visible = false
		hubState.revealEquip.Visible = false
		hubState.revealBest.Visible = false
		hubState.revealEquip:SetAttribute("Uid", "")
		hubState.revealFly.TextTransparency = 1
		hubState.revealScale.Scale = 1
		hubState.revealCard.BackgroundColor3 = rgb("header")
		hubState.revealStroke.Color = rgb("accent")
		hubState.revealStroke.Thickness = UiTheme.STROKE
		hubState.flashCover.BackgroundTransparency = 1
	end

	hubState.closeBeat = Instance.new("TextLabel")
	hubState.closeBeat.Name = "CloseCall"
	hubState.closeBeat.AnchorPoint = Vector2.new(1, 1)
	hubState.closeBeat.Position = UDim2.fromOffset(0, 0)
	hubState.closeBeat.Size = UDim2.fromOffset(108, 28)
	hubState.closeBeat.BackgroundColor3 = rgb("header")
	hubState.closeBeat.Font = headerFont()
	hubState.closeBeat.TextSize = UiTheme.MIN_TEXT
	hubState.closeBeat.TextColor3 = rgb("text")
	hubState.closeBeat.Text = UiRouter.CLOSE_BEAT
	hubState.closeBeat.Visible = false
	hubState.closeBeat.Active = false
	hubState.closeBeat.ZIndex = 10
	hubState.closeBeat.Parent = hubState.rollPage
	hubState.beatCorner = Instance.new("UICorner")
	hubState.beatCorner.CornerRadius = UDim.new(0, 8)
	hubState.beatCorner.Parent = hubState.closeBeat
	hubState.beatStroke = Instance.new("UIStroke")
	hubState.beatStroke.Thickness = UiTheme.STROKE
	hubState.beatStroke.Color = rgb("accent")
	hubState.beatStroke.Parent = hubState.closeBeat
	hubState.closeScale = Instance.new("UIScale")
	hubState.closeScale.Name = "Beat"
	hubState.closeScale.Parent = hubState.closeBeat
	hubState.closeToken = 0
	hubState.closeTween = nil

	hubState.wallet = Instance.new("Frame")
	hubState.wallet.Name = "Wallet"
	hubState.wallet.Position = UDim2.fromOffset(UiTheme.PAD, UiTheme.PAD)
	hubState.wallet.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 28)
	hubState.wallet.BackgroundColor3 = rgb("header")
	hubState.wallet.BackgroundTransparency = 0
	hubState.wallet.BorderSizePixel = 0
	hubState.wallet.ZIndex = 6
	hubState.wallet.Parent = hubState.rollPage
	hubState.walletCorner = Instance.new("UICorner")
	hubState.walletCorner.CornerRadius = UDim.new(0, 8)
	hubState.walletCorner.Parent = hubState.wallet
	hubState.walletTokens = Instance.new("TextLabel")
	hubState.walletTokens.Name = "ShardTokens"
	hubState.walletTokens.BackgroundTransparency = 1
	hubState.walletTokens.Position = UDim2.fromOffset(10, 0)
	hubState.walletTokens.Size = UDim2.new(0.5, -12, 1, 0)
	hubState.walletTokens.Font = headerFont()
	hubState.walletTokens.TextSize = UiTheme.MIN_TEXT
	hubState.walletTokens.TextXAlignment = Enum.TextXAlignment.Left
	hubState.walletTokens.TextColor3 = rgb("text")
	hubState.walletTokens.Text = "Shard Tokens  0"
	hubState.walletTokens.ZIndex = 7
	hubState.walletTokens.Parent = hubState.wallet
	hubState.walletGold = Instance.new("TextLabel")
	hubState.walletGold.Name = "Gold"
	hubState.walletGold.BackgroundTransparency = 1
	hubState.walletGold.Position = UDim2.fromScale(0.5, 0)
	hubState.walletGold.Size = UDim2.new(0.5, -10, 1, 0)
	hubState.walletGold.Font = headerFont()
	hubState.walletGold.TextSize = UiTheme.MIN_TEXT
	hubState.walletGold.TextXAlignment = Enum.TextXAlignment.Right
	hubState.walletGold.TextColor3 = rgb("gold")
	hubState.walletGold.Text = "Gold  0"
	hubState.walletGold.ZIndex = 7
	hubState.walletGold.Parent = hubState.wallet

	hubState.reelHost = Instance.new("Frame")
	hubState.reelHost.Name = "Reel"
	hubState.reelHost.Position = UDim2.fromOffset(UiTheme.PAD, UiTheme.PAD + 32)
	hubState.reelHost.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, 68)
	hubState.reelHost.BackgroundColor3 = rgb("header")
	hubState.reelHost.BackgroundTransparency = 0
	hubState.reelHost.BorderSizePixel = 0
	hubState.reelHost.ClipsDescendants = true
	hubState.reelHost.ZIndex = 6
	hubState.reelHost.Parent = hubState.rollPage
	hubState.reelCorner = Instance.new("UICorner")
	hubState.reelCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.reelCorner.Parent = hubState.reelHost
	hubState.reelStroke = Instance.new("UIStroke")
	hubState.reelStroke.Name = "Glow"
	hubState.reelStroke.Thickness = UiTheme.STROKE_BOLD
	hubState.reelStroke.Color = rgb("accent")
	hubState.reelStroke.Parent = hubState.reelHost
	hubState.reelStreak = Instance.new("TextLabel")
	hubState.reelStreak.Name = "Streak"
	hubState.reelStreak.BackgroundTransparency = 1
	hubState.reelStreak.Position = UDim2.fromOffset(8, 2)
	hubState.reelStreak.Size = UDim2.new(1, -16, 0, 18)
	hubState.reelStreak.Font = headerFont()
	hubState.reelStreak.TextSize = UiTheme.MIN_TEXT
	hubState.reelStreak.TextXAlignment = Enum.TextXAlignment.Left
	hubState.reelStreak.TextColor3 = rgb("gold")
	hubState.reelStreak.Text = "Streak  0"
	hubState.reelStreak.ZIndex = 7
	hubState.reelStreak.Parent = hubState.reelHost
	function hubFn.reelWindow(name: string, xScale: number, widthScale: number): TextLabel
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
		label.Parent = hubState.reelHost
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		return label
	end
	hubState.reelLeft = hubFn.reelWindow("Left", 0, 0.28)
	hubState.reelCenter = hubFn.reelWindow("Center", 0.28, 0.44)
	hubState.reelRight = hubFn.reelWindow("Right", 0.72, 0.28)
	hubState.reelCenter.Text = "Roll"
	hubState.reelMilestone = Instance.new("TextLabel")
	hubState.reelMilestone.Name = "Milestone"
	hubState.reelMilestone.Size = UDim2.fromScale(1, 1)
	hubState.reelMilestone.BackgroundColor3 = rgb("gold")
	hubState.reelMilestone.Font = headerFont()
	hubState.reelMilestone.TextSize = 20
	hubState.reelMilestone.TextColor3 = rgb("ink")
	hubState.reelMilestone.Text = ""
	hubState.reelMilestone.Visible = false
	hubState.reelMilestone.Active = false
	hubState.reelMilestone.ZIndex = 9
	hubState.reelMilestone.Parent = hubState.reelHost
	hubState.milestoneCorner = Instance.new("UICorner")
	hubState.milestoneCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.milestoneCorner.Parent = hubState.reelMilestone
	hubState.shardStone = Instance.new("Frame")
	hubState.shardStone.Name = "Shard"
	hubState.shardStone.AnchorPoint = Vector2.new(0.5, 0.5)
	hubState.stoneY = 0.62
	hubState.cardRoom = 112
	hubState.shardStone.Position = UDim2.fromScale(0.5, hubState.stoneY)
	hubState.shardStone.Size = UDim2.fromOffset(28, 36)
	hubState.shardStone.BackgroundColor3 = Color3.fromRGB(198, 206, 214)
	hubState.shardStone.BackgroundTransparency = 0
	hubState.shardStone.BorderSizePixel = 0
	hubState.shardStone.ZIndex = 8
	hubState.shardStone.Parent = hubState.reelHost
	hubState.shardCorner = Instance.new("UICorner")
	hubState.shardCorner.CornerRadius = UDim.new(0, 6)
	hubState.shardCorner.Parent = hubState.shardStone
	hubState.crackLine = Instance.new("Frame")
	hubState.crackLine.Name = "Crack"
	hubState.crackLine.AnchorPoint = Vector2.new(0.5, 0)
	hubState.crackLine.Position = UDim2.fromScale(0.5, 0.12)
	hubState.crackLine.Size = UDim2.fromOffset(2, 0)
	hubState.crackLine.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
	hubState.crackLine.BorderSizePixel = 0
	hubState.crackLine.ZIndex = 9
	hubState.crackLine.Parent = hubState.shardStone
	hubState.stoneRest = Color3.fromRGB(198, 206, 214)
	hubFn.restShard = function()
		hubState.shardStone.Position = UDim2.fromScale(0.5, hubState.stoneY)
		hubState.shardStone.BackgroundColor3 = hubState.stoneRest
		hubState.crackLine.Size = UDim2.fromOffset(2, 0)
		hubState.reelHost.BackgroundColor3 = rgb("header")
	end

	function hubFn.rarityColor3(name: string): Color3
		local row = Rarities.COLOR[name]
		if type(row) ~= "table" then
			local red, green, blue = UiTheme.rarityColor("Common")
			return Color3.fromRGB(red, green, blue)
		end
		return Color3.fromRGB(row[1], row[2], row[3])
	end

	hubFn.hideCloseBeat = function()
		hubState.closeToken += 1
		if hubState.closeTween ~= nil then
			hubState.closeTween:Cancel()
			hubState.closeTween = nil
		end
		hubState.closeBeat.Visible = false
		hubState.closeScale.Scale = 1
	end

	hubFn.showCloseBeat = function(rarity: string)
		hubState.closeToken += 1
		local token = hubState.closeToken
		if hubState.closeTween ~= nil then
			hubState.closeTween:Cancel()
			hubState.closeTween = nil
		end
		local color = hubFn.rarityColor3(rarity)
		hubState.closeBeat.Text = UiRouter.CLOSE_BEAT
		hubState.closeBeat.TextColor3 = color
		hubState.beatStroke.Color = color
		hubState.closeBeat.Visible = true
		if UiMotion.reduced(hubState.draft) then
			hubState.closeScale.Scale = 1
		else
			hubState.closeScale.Scale = 0.84
			local tween = TweenService:Create(
				hubState.closeScale,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
			hubState.closeTween = tween
			tween:Play()
		end
		hubFn.playUi("press")
		task.delay(1.15, function()
			if token ~= hubState.closeToken then
				return
			end
			hubState.closeBeat.Visible = false
			hubState.closeScale.Scale = 1
		end)
	end

	function hubFn.paintWindow(label: TextLabel, slotName: string, rarity: string, focus: boolean)
		label.Text = slotName
		label.TextColor3 = if focus then rgb("ink") else rgb("text")
		label.BackgroundColor3 = if focus then hubFn.rarityColor3(rarity) else rgb("body")
	end

	-- A server reason is a sentence. Give it the whole reel so a phone still
	-- shows the words. A spin puts the three windows back.
	function hubFn.placeReelWindows(wide: boolean)
		if wide then
			hubState.reelLeft.Visible = false
			hubState.reelRight.Visible = false
			hubState.reelCenter.Position =
				UDim2.new(0, 4, hubState.reelCenter.Position.Y.Scale, hubState.reelCenter.Position.Y.Offset)
			hubState.reelCenter.Size = UDim2.new(1, -8, hubState.reelCenter.Size.Y.Scale, hubState.reelCenter.Size.Y.Offset)
			return
		end
		hubState.reelLeft.Visible = true
		hubState.reelRight.Visible = true
		hubState.reelLeft.Position = UDim2.new(0, 4, hubState.reelLeft.Position.Y.Scale, hubState.reelLeft.Position.Y.Offset)
		hubState.reelLeft.Size = UDim2.new(0.28, -8, hubState.reelLeft.Size.Y.Scale, hubState.reelLeft.Size.Y.Offset)
		hubState.reelCenter.Position =
			UDim2.new(0.28, 4, hubState.reelCenter.Position.Y.Scale, hubState.reelCenter.Position.Y.Offset)
		hubState.reelCenter.Size = UDim2.new(0.44, -8, hubState.reelCenter.Size.Y.Scale, hubState.reelCenter.Size.Y.Offset)
		hubState.reelRight.Position =
			UDim2.new(0.72, 4, hubState.reelRight.Position.Y.Scale, hubState.reelRight.Position.Y.Offset)
		hubState.reelRight.Size = UDim2.new(0.28, -8, hubState.reelRight.Size.Y.Scale, hubState.reelRight.Size.Y.Offset)
	end

	function hubFn.paintReel(slots: { UiRouter.ReelSlot }?, index: number)
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
		hubFn.placeReelWindows(false)
		hubFn.paintWindow(hubState.reelLeft, leftName, leftRarity, false)
		hubFn.paintWindow(hubState.reelCenter, midName, midRarity, slots ~= nil)
		hubFn.paintWindow(hubState.reelRight, rightName, rightRarity, false)
		if slots ~= nil then
			hubState.reelStroke.Color = hubFn.rarityColor3(midRarity)
		end
	end

	hubFn.paintReelIdle = function(caption: string)
		hubState.reelStreak.Text = UiRouter.streakText(hubState.hype.streak, hubState.lastMissed)
		hubState.reelStreak.TextColor3 = rgb(UiRouter.streakTone(hubState.hype.streak, hubState.lastMissed))
		local wide = caption ~= "Roll" and caption ~= "Miss"
		hubFn.placeReelWindows(wide)
		hubFn.paintWindow(hubState.reelLeft, "—", "Common", false)
		hubFn.paintWindow(hubState.reelCenter, caption, "Common", false)
		hubFn.paintWindow(hubState.reelRight, "—", "Common", false)
		hubState.reelCenter.TextColor3 = rgb("text")
		hubState.reelCenter.BackgroundColor3 = rgb("body")
		hubState.reelStroke.Color = if hubState.hype.streak >= 5 then rgb("gold") else rgb("accent")
	end

	hubFn.showMilestone = function(text: string)
		hubState.toastToken += 1
		local token = hubState.toastToken
		hubState.reelMilestone.Text = text
		hubState.reelMilestone.Visible = true
		hubFn.playUi("toast")
		task.delay(1.8, function()
			if token == hubState.toastToken then
				hubState.reelMilestone.Visible = false
			end
		end)
	end

	function hubFn.flashPersonalBest(rarity: string)
		hubState.revealBest.Text = rarity
		hubState.revealBest.Visible = true
		hubState.revealBest.BackgroundColor3 = hubFn.rarityColor3(rarity)
		hubState.flashCover.BackgroundColor3 = hubFn.rarityColor3(rarity)
		if UiMotion.reduced(hubState.draft) or hubState.draft.camera.flash == "reduced" then
			hubState.flashCover.BackgroundTransparency = 1
			return
		end
		hubState.flashCover.BackgroundTransparency = 0.45
		hubFn.playCardTween(
			TweenService:Create(
				hubState.flashCover,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			)
		)
	end

	hubFn.fitRoll = function()
		local height = hubState.rollPage.AbsoluteSize.Y
		if height < 80 then
			local vx, vy = hubFn.view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			height = inner.h
		end
		local kindH = UiTheme.TOUCH
		local kindRow = hubState.roll:FindFirstChild("ShardKind")
		if kindRow ~= nil and kindRow:IsA("GuiObject") and kindRow.Size.Y.Offset >= UiTheme.TOUCH then
			kindH = kindRow.Size.Y.Offset
		end
		local layout = CrackCard.layout(height, kindH)
		local stage = layout.reel.h
		hubState.reelHost.Position = UDim2.fromOffset(UiTheme.PAD, layout.reel.y)
		hubState.reelHost.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, stage)
		hubState.reelStreak.Visible = not layout.compact
		local windowTop = if layout.compact then 4 else 22
		local windowTrim = if layout.compact then 8 else 28
		local function placeWindow(label: TextLabel)
			label.Position = UDim2.new(label.Position.X.Scale, 4, 0, windowTop)
			label.Size = UDim2.new(label.Size.X.Scale, -8, 1, -windowTrim)
		end
		placeWindow(hubState.reelLeft)
		placeWindow(hubState.reelCenter)
		placeWindow(hubState.reelRight)
		hubState.stoneY = layout.stone.y
		hubState.shardStone.Size = UDim2.fromOffset(layout.stone.w, layout.stone.h)
		hubState.shardStone.Position = UDim2.fromScale(0.5, hubState.stoneY)
		hubState.rollButton.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, layout.button)
		local buttonText = if layout.button < 56 then 20 else 28
		hubState.rollButton.TextSize = buttonText
		hubState.rollButton:SetAttribute("BaseText", buttonText)
		hubState.roll.Position = UDim2.fromOffset(0, layout.listTop)
		hubState.roll.Size = UDim2.new(1, 0, 1, -(layout.listTop + layout.button + UiTheme.PAD))
		hubState.cardRoom = layout.card.h
		hubState.revealCard.Size = UDim2.new(1, -24, 0, layout.card.h)
		hubState.revealCard.Position = UDim2.new(0.5, 0, 0, layout.card.y + layout.card.h)
		hubState.revealCard.AnchorPoint = Vector2.new(0.5, 1)
		hubState.revealTitle.Position = UDim2.fromOffset(12, layout.name.y)
		hubState.revealTitle.Size = UDim2.new(1, -120, 0, layout.name.h)
		hubState.revealRarity.Visible = layout.rarity.visible
		hubState.revealRarity.Position = UDim2.fromOffset(12, layout.rarity.y)
		hubState.revealRarity.Size = UDim2.new(1, -120, 0, layout.rarity.h)
		local aboveCard = height - layout.card.y + 6
		hubState.closeBeat.Position = UDim2.new(1, -12, 1, -aboveCard)
		hubState.revealFly.Visible = layout.fly
		if not layout.showEquip then
			hubState.revealEquip.Visible = false
		end
		hubState.revealEquip.Size = UDim2.fromOffset(if layout.card.h >= 88 then 120 else 88, layout.equipH)
	end
	hubFn.fitRoll()
	hubFn.paintReelIdle("Roll")
	hubFn.setPulse(true)
	hubState.raids = hubFn.scroll(hubFn.page("raids"))
	hubState.market = hubFn.scroll(hubFn.page("market"))
	hubState.pass = hubFn.scroll(hubFn.page("pass"))
	hubState.settingsPage = hubFn.scroll(hubFn.page("settings"))

	hubState.detail = Instance.new("Frame")
	hubState.detail.Name = "Detail"
	hubState.detail.Size = UDim2.fromScale(1, 1)
	hubState.detail.BackgroundColor3 = rgb("body")
	hubState.detail.BackgroundTransparency = 0.02
	hubState.detail.BorderSizePixel = 0
	hubState.detail.Visible = false
	hubState.detail.ZIndex = 7
	hubState.detail.Parent = hubState.body
	hubState.detailCorner = Instance.new("UICorner")
	hubState.detailCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	hubState.detailCorner.Parent = hubState.detail
	hubState.detailStroke = Instance.new("UIStroke")
	hubState.detailStroke.Thickness = UiTheme.STROKE
	hubState.detailStroke.Color = rgb("divider")
	hubState.detailStroke.Parent = hubState.detail
	hubState.detailList = Instance.new("ScrollingFrame")
	hubState.detailList.Name = "Compare"
	hubState.detailList.Position = UDim2.fromOffset(0, 52)
	hubState.detailList.Size = UDim2.new(1, 0, 1, -52)
	hubState.detailList.BackgroundTransparency = 1
	hubState.detailList.BorderSizePixel = 0
	hubState.detailList.ScrollBarThickness = 6
	hubState.detailList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hubState.detailList.CanvasSize = UDim2.new()
	hubState.detailList.ZIndex = 8
	hubState.detailList.Parent = hubState.detail
	hubState.detailLayout = Instance.new("UIListLayout")
	hubState.detailLayout.Padding = UDim.new(0, UiTheme.PAD)
	hubState.detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hubState.detailLayout.Parent = hubState.detailList
	hubState.detailPad = Instance.new("UIPadding")
	hubState.detailPad.PaddingLeft = UDim.new(0, UiTheme.GAP)
	hubState.detailPad.PaddingRight = UDim.new(0, UiTheme.GAP)
	hubState.detailPad.Parent = hubState.detailList
	hubState.detailBack = Instance.new("TextButton")
	hubState.detailBack.Name = "Back"
	hubState.detailBack.Position = UDim2.fromOffset(8, 4)
	hubState.detailBack.Size = UDim2.fromOffset(88, UiTheme.TOUCH)
	hubState.detailBack.BackgroundColor3 = rgb("header")
	hubState.detailBack.Font = headerFont()
	hubState.detailBack.TextSize = UiTheme.MIN_TEXT
	hubState.detailBack.TextColor3 = rgb("text")
	hubState.detailBack.Text = "Back"
	hubState.detailBack.ZIndex = 8
	hubState.detailBack.Parent = hubState.detail
	hubState.detailBackCorner = Instance.new("UICorner")
	hubState.detailBackCorner.CornerRadius = UDim.new(0, 8)
	hubState.detailBackCorner.Parent = hubState.detailBack
	hubFn.motion(hubState.detailBack)
	hubFn.setRest(hubState.detailBack, rgb("header"))

	function hubFn.save()
		task.spawn(function()
			pcall(hooks.invoke, "SetSettings", hubState.draft)
		end)
	end

	function hubFn.paintTabs(current: string)
		for id, button in pairs(hubState.tabButtons) do
			local on = id == current
			hubFn.setRest(button, if on then rgb("header") else rgb("body"))
			local accent = hubState.tabAccents[id]
			if accent ~= nil then
				accent.Visible = on
			end
		end
	end



	function hubFn.show(id: string)
		for pageId, frame in pairs(hubState.pages) do
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
		hubState.title.Text = label
		hubFn.paintTabs(if id == "sets" then "bag" else id)
		if id ~= "bag" then
			hubState.detailOpen = false
		end
		if id ~= "roll" then
			hubState.holdingRoll = false
		end
		hubState.detail.Visible = id == "bag" and hubState.detailOpen
		if hooks.onTab ~= nil then
			hooks.onTab(if id == "sets" then "bag" else id)
		end
		if hubState.shownId ~= "" and hubState.shownId ~= id then
			hubFn.playUi("tab")
			local length = UiMotion.panel(UiMotion.reduced(hubState.draft))
			if length <= 0 then
				hubState.tabScale.Scale = 1
			else
				hubState.tabScale.Scale = 0.98
				TweenService:Create(
					hubState.tabScale,
					TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end
		local leftRoll = hubState.shownId == "roll" and id ~= "roll"
		hubState.shownId = id
		hubFn.noteView(id)
		if leftRoll then
			hubFn.stopRollChain()
			hubFn.blankReveal()
		end
	end

	function hubFn.publishBadges()
		hubState.seen = NotifyBadges.prepare(hubState.seen, hubState.profile)
		local badges = NotifyBadges.evaluate(hubState.profile, hubState.seen)
		for id, dot in pairs(hubState.tabDots) do
			local badge = badges[id]
			dot.Visible = badge ~= nil and badge.on == true
		end
		if hooks.onBadges ~= nil then
			hooks.onBadges(badges)
		end
	end

	function hubFn.noteView(id: string)
		hubState.seen = NotifyBadges.view(hubState.seen, id, hubState.profile)
		hubFn.publishBadges()
	end

	function hubFn.classMissing(): boolean
		if type(hubState.profile) ~= "table" then
			return false
		end
		return Classes.get(hubState.profile.classId) == nil
	end

	function hubFn.pageFor(state: UiRouter.State): string
		local top = UiRouter.top(state)
		if top == "sets" then
			return "sets"
		end
		if top == "class" then
			return state.stack[1] or "hero"
		end
		return top
	end

	function hubFn.paintHints()
		for id, caption in pairs(hubState.tabCaptions) do
			local label = id
			for _, tab in ipairs(ClientChrome.TABS) do
				if tab.id == id then
					label = tab.label
				end
			end
			local key = hubState.draft.controls.hotkeys[id]
			if type(key) == "string" and key ~= "" then
				caption.Text = label .. "  " .. key
			else
				caption.Text = label
			end
		end
	end

	function hubFn.row(parent: Instance, text: string, order: number, fn: (() -> ())?): TextButton
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
		hubFn.setRest(button, rgb("header"))
		hubFn.motion(button)
		if fn ~= nil then
			button.Activated:Connect(fn)
		end
		return button
	end

	function hubFn.line(parent: Instance, text: string, order: number, color: Color3)
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

	function hubFn.divider(parent: Instance, order: number)
		local rule = Instance.new("Frame")
		rule.Name = "Divider"
		rule.Size = UDim2.new(1, 0, 0, 1)
		rule.BackgroundColor3 = rgb("divider")
		rule.BorderSizePixel = 0
		rule.LayoutOrder = order
		rule.Parent = parent
	end

	function hubFn.findItem(uid: string): any
		if type(hubState.profile) ~= "table" then
			return nil
		end
		if type(hubState.profile.inventory) == "table" then
			local item = hubState.profile.inventory[uid]
			if type(item) == "table" then
				return item
			end
		end
		if type(hubState.profile.pets) == "table" then
			local pet = hubState.profile.pets[uid]
			if type(pet) == "table" then
				return pet
			end
		end
		return nil
	end

	function hubFn.statMap(item: any): { [string]: number }
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

	function hubFn.formatStat(id: string, value: number): string
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

	function hubFn.equipUid(uid: string)
		task.spawn(function()
			pcall(hooks.invoke, "EquipItem", uid)
		end)
	end

	function hubFn.paintDetail(item: any)
		hubFn.clear(hubState.detailList)
		if type(item) ~= "table" then
			hubState.detail.Visible = false
			hubState.detailOpen = false
			return
		end
		local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
		local red, green, blue = UiTheme.rarityColor(rarity)
		hubFn.line(hubState.detailList, tostring(item.name or "Item"), 1, rgb("text"))
		hubFn.line(hubState.detailList, rarity, 2, Color3.fromRGB(red, green, blue))
		hubFn.divider(hubState.detailList, 3)
		local other = InventoryView.counterpart(hubState.profile, item)
		local same = other ~= nil and other.uid == item.uid
		if other == nil then
			hubFn.line(hubState.detailList, "Nothing equipped to compare.", 4, rgb("muted"))
		elseif same then
			hubFn.line(hubState.detailList, "Equipped.", 4, rgb("ok"))
		else
			hubFn.line(
				hubState.detailList,
				"Compared with " .. tostring(other.name or "equipped"),
				4,
				rgb("muted")
			)
		end
		local mine = hubFn.statMap(item)
		local theirs = if other ~= nil and not same then hubFn.statMap(other) else {}
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
			local text = hubFn.formatStat(id, value)
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
			hubFn.line(hubState.detailList, text, order, color)
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
		hubFn.line(hubState.detailList, powerText, 80, powerColor)
		if type(item.uid) == "string" then
			local uid = item.uid
			hubFn.row(hubState.detailList, if same then "Equipped" else "Equip", 90, function()
				if not same then
					hubFn.equipUid(uid)
				end
			end)
		end
		hubState.detail.Visible = true
		hubState.detailOpen = true
	end

	function hubFn.openItem(uid: string)
		hubState.selectedUid = uid
		local item = hubFn.findItem(uid)
		if item == nil then
			return
		end
		hubState.pages.bag.Visible = true
		hubFn.paintDetail(item)
	end

	function hubFn.itemCard(
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
		hubFn.setRest(card, rgb("body"))
		hubFn.motion(card)
		hubFn.iconOn(card, iconName, 8, 8, 36)
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
		if BagBoard.isNew(item, hubState.seen.bagAt) then
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
		tip.Text = BagBoard.summary(hubState.profile, item)
		tip.Visible = hubState.selectedUid ~= nil and hubState.selectedUid == item.uid
		tip.ZIndex = 7
		tip.Parent = card
		card.MouseEnter:Connect(function()
			tip.Visible = true
		end)
		card.MouseLeave:Connect(function()
			tip.Visible = hubState.selectedUid ~= nil and hubState.selectedUid == item.uid
		end)
		card.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local payload = ActionSlots.fromRow(item)
			if payload ~= nil then
				ActionDrag.begin(payload)
			end
		end)
		local uid = item.uid
		if type(uid) == "string" then
			local itemUid = uid
			card.Activated:Connect(function()
				hubFn.openItem(itemUid)
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
			hubFn.setRest(equip, rgb("header"))
			hubFn.motion(equip)
			equip.Activated:Connect(function()
				hubFn.equipUid(itemUid)
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
			hubFn.setRest(lock, rgb("header"))
			hubFn.motion(lock)
			local locked = item.locked == true
			lock.Activated:Connect(function()
				task.spawn(function()
					pcall(hooks.invoke, "SetItemLock", itemUid, not locked)
				end)
			end)
		end
		return card
	end

	function hubFn.emptyState(
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
		hubFn.iconOn(block, iconName, 16, 16, 36)
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
		hubFn.setRest(button, rgb("button"))
		hubFn.motion(button)
		button.Activated:Connect(fn)
	end

	function hubFn.bagItems(): { any }
		local list = {}
		if type(hubState.profile) == "table" and type(hubState.profile.inventory) == "table" then
			for _, item in pairs(hubState.profile.inventory) do
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

	function hubFn.companions(): { any }
		local list = {}
		if type(hubState.profile) ~= "table" or type(hubState.profile.companions) ~= "table" then
			return list
		end
		for _, companion in ipairs(hubState.profile.companions) do
			if type(companion) == "table" then
				table.insert(list, companion)
			end
		end
		if #list == 0 then
			for _, companion in pairs(hubState.profile.companions) do
				if type(companion) == "table" then
					table.insert(list, companion)
				end
			end
		end
		return list
	end

	function hubFn.paintClassCards()
		hubFn.clear(hubState.classList)
		local roster = Classes.all()
		hubFn.applyGrid(hubState.classList, #roster)
		for index, entry in ipairs(roster) do
			local card = Instance.new("Frame")
			card.Name = entry.id
			card.BackgroundColor3 = rgb("body")
			card.BorderSizePixel = 0
			card.LayoutOrder = index
			card.ZIndex = 10
			card.Parent = hubState.classList
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
			hubFn.iconOn(card, "class", 8, 8, 28)
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
			hubFn.setRest(choose, rgb("button"))
			hubFn.motion(choose)
			local classId = entry.id
			choose.Activated:Connect(function()
				hubState.classDismissed = true
				if UiRouter.top(hubState.route) == "class" then
					hubFn.apply(UiRouter.pop(hubState.route))
				else
					hubState.classModal.Visible = false
				end
				task.spawn(function()
					pcall(hooks.invoke, "SetClass", classId)
				end)
			end)
		end
	end

	function hubFn.showClassPrompt(force: boolean)
		if not hubFn.classMissing() or ClassHud.holdsChoice() then
			if not hubFn.classMissing() and UiRouter.top(hubState.route) == "class" then
				hubState.classDismissed = false
				hubFn.apply(UiRouter.pop(hubState.route))
			end
			return
		end
		if not force and hubState.classDismissed then
			return
		end
		if hubState.route.open and UiRouter.top(hubState.route) == "class" then
			hubFn.paintClassCards()
			return
		end
		hubState.classDismissed = false
		hubFn.paintClassCards()
		local nextState = hubState.route
		if not nextState.open then
			nextState = UiRouter.open(nextState, "hero")
		end
		hubFn.apply(UiRouter.push(nextState, "class"))
	end

	function hubFn.paintHero()
		hubFn.clear(hubState.hero)
		local level = if type(hubState.profile) == "table" then hubState.profile.level or 1 else 1
		local classId = if type(hubState.profile) == "table" then hubState.profile.classId else ""
		local classDef = Classes.get(classId)
		local sheet = Instance.new("Frame")
		sheet.Name = "Stats"
		sheet.BackgroundColor3 = rgb("header")
		sheet.BackgroundTransparency = 0.08
		sheet.Size = UDim2.fromScale(1, 0)
		sheet.AutomaticSize = Enum.AutomaticSize.Y
		sheet.BorderSizePixel = 0
		sheet.LayoutOrder = 1
		sheet.Parent = hubState.hero
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
		hubFn.line(sheet, "Stat sheet", 1, rgb("gold"))
		hubFn.divider(sheet, 2)
		local offense, vitality, goldFind = CombatMath.loadout(hubState.profile)
		hubFn.line(sheet, string.format("Level  %d", level), 3, rgb("text"))
		hubFn.line(sheet, string.format("Damage  %d", math.floor(offense.damage + 0.5)), 4, rgb("text"))
		hubFn.line(sheet, string.format("Attack speed  %.2f", offense.attackSpeed), 5, rgb("text"))
		hubFn.line(sheet, string.format("Crit  %.0f%%", offense.critChance * 100), 6, rgb("text"))
		hubFn.line(sheet, string.format("Crit damage  %.2f", offense.critDamage), 7, rgb("text"))
		hubFn.line(sheet, string.format("HP  %d", vitality.maxHealth), 8, rgb("text"))
		hubFn.line(sheet, string.format("Defense  %d", vitality.defense), 9, rgb("text"))
		hubFn.line(sheet, string.format("Gold find  %.0f%%", goldFind * 100), 10, rgb("text"))
		hubFn.line(sheet, string.format("Power  %d", HeroBoard.power(hubState.profile)), 11, rgb("gold"))
		local barOrder = 12
		for _, bar in ipairs(HeroBoard.bars(hubState.profile)) do
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
		viewport.Parent = hubState.hero
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
			local rigName = HeroView.rig(humanoid.RigType.Name)
			local rigType = if rigName == "R6"
				then Enum.HumanoidRigType.R6
				else Enum.HumanoidRigType.R15
			local built, model = pcall(function()
				return Players:CreateHumanoidModelFromDescription(description, rigType)
			end)
			local action = HeroView.place(built, model ~= nil, viewport.Parent ~= nil)
			if action == "parent" then
				model.Parent = world
			elseif action == "destroy" then
				model:Destroy()
			end
		end)

		local classCard = Instance.new("Frame")
		classCard.Name = "ClassCard"
		classCard.BackgroundColor3 = rgb("body")
		classCard.Size = UDim2.new(1, 0, 0, 120)
		classCard.BorderSizePixel = 0
		classCard.LayoutOrder = 2
		classCard.Parent = hubState.hero
		local classCardCorner = Instance.new("UICorner")
		classCardCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		classCardCorner.Parent = classCard
		local classCardStroke = Instance.new("UIStroke")
		classCardStroke.Thickness = UiTheme.STROKE_BOLD
		classCardStroke.Color = rgb("accent")
		classCardStroke.Parent = classCard
		hubFn.iconOn(classCard, "class", 12, 12, 32)
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
			hubFn.setRest(choose, rgb("button"))
			hubFn.motion(choose)
			choose.Activated:Connect(function()
				hubFn.showClassPrompt(true)
			end)
			classCard.Size = UDim2.new(1, 0, 0, 128)
		end

		hubFn.line(hubState.hero, "Skills", 3, rgb("gold"))
		hubFn.divider(hubState.hero, 4)
		hubFn.line(hubState.hero, "Drag a skill onto the bar.", 5, rgb("muted"))
		if classDef ~= nil then
			for index, skill in ipairs(classDef.skills) do
				local skillId = skill.id
				local button = hubFn.row(hubState.hero, Classes.skillLine(skill), 10 + index, nil)
				button.InputBegan:Connect(function(input)
					if
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					then
						ActionDrag.begin({ kind = "skill", id = skillId })
					end
				end)
			end
			local ultId = classDef.ultimate.id
			local ultButton = hubFn.row(hubState.hero, Classes.skillLine(classDef.ultimate), 20, nil)
			ultButton.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					ActionDrag.begin({ kind = "skill", id = ultId })
				end
			end)
		else
			hubFn.line(hubState.hero, "No skills until a class is chosen.", 10, rgb("muted"))
		end
		hubFn.row(hubState.hero, "Change class", 30, function()
			if hubFn.classMissing() or hooks.onClassSheet == nil then
				hubFn.showClassPrompt(true)
			else
				hooks.onClassSheet()
			end
		end)
	end

	function hubFn.cardHost(
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
			local vx, vy = hubFn.view()
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

	function hubFn.nextSalvage(current: string): string
		local following = BagBoard.nextRarity(current)
		if following == "All" then
			return "Common"
		end
		return following
	end

	function hubFn.paintBag()
		hubFn.clear(hubState.bag)
		local items = hubFn.bagItems()
		local shown = BagBoard.rows(items, hubState.bagFilter, hubState.seen.bagAt)
		local bar = Instance.new("Frame")
		bar.Name = "Filters"
		bar.BackgroundTransparency = 1
		bar.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		bar.LayoutOrder = 1
		bar.Parent = hubState.bag
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
			hubFn.setRest(button, rgb("header"))
			hubFn.motion(button)
			button.Activated:Connect(fn)
		end
		local function refreshBag()
			hubFn.paintBag()
			hubFn.show("bag")
		end
		chip("Rarity  " .. hubState.bagFilter.rarity, function()
			hubState.bagFilter.rarity = BagBoard.nextRarity(hubState.bagFilter.rarity)
			refreshBag()
		end)
		chip("Type  " .. hubState.bagFilter.kind, function()
			hubState.bagFilter.kind = BagBoard.nextKind(hubState.bagFilter.kind, BagBoard.kinds(items))
			refreshBag()
		end)
		chip(if hubState.bagFilter.onlyNew then "New  On" else "New", function()
			hubState.bagFilter.onlyNew = not hubState.bagFilter.onlyNew
			refreshBag()
		end)
		chip("Sort  " .. hubState.bagFilter.sort, function()
			hubState.bagFilter.sort = BagBoard.nextSort(hubState.bagFilter.sort)
			refreshBag()
		end)
		hubFn.row(hubState.bag, "Sets", 2, function()
			hubFn.apply(UiRouter.push(hubState.route, "sets"))
		end)
		hubFn.row(hubState.bag, "Open full bag", 3, function()
			hooks.onBag()
		end)
		if hubState.salvageArmed then
			hubFn.line(hubState.bag, BagBoard.confirm(hubState.salvageRarity), 4, rgb("loss"))
			hubFn.row(hubState.bag, "Confirm salvage", 5, function()
				local rarity = hubState.salvageRarity
				hubState.salvageArmed = false
				task.spawn(function()
					pcall(hooks.invoke, "BulkSalvage", rarity)
				end)
				refreshBag()
			end)
			hubFn.row(hubState.bag, "Cancel", 6, function()
				hubState.salvageArmed = false
				refreshBag()
			end)
			hubFn.row(hubState.bag, "Use  " .. hubFn.nextSalvage(hubState.salvageRarity), 7, function()
				hubState.salvageRarity = hubFn.nextSalvage(hubState.salvageRarity)
				refreshBag()
			end)
		else
			hubFn.row(hubState.bag, "Salvage  " .. hubState.salvageRarity, 4, function()
				hubState.salvageArmed = true
				refreshBag()
			end)
		end
		if #shown == 0 then
			hubFn.emptyState(hubState.bag, "bag", "The bag is empty.", "Open full bag", function()
				hooks.onBag()
			end)
			local empty = hubState.bag:FindFirstChild("Empty")
			if empty ~= nil and empty:IsA("GuiObject") then
				empty.LayoutOrder = 9
			end
		else
			local host = hubFn.cardHost(hubState.bag, hubState.bag, #shown, 8)
			for index, item in ipairs(shown) do
				hubFn.itemCard(host, item, index, "item")
			end
		end
		hubFn.row(hubState.sets, "Relic sets equip from the bag. Pieces stay raid drops.", 1, nil)
		if hubState.detailOpen and hubState.selectedUid ~= nil then
			local item = hubFn.findItem(hubState.selectedUid)
			if item ~= nil then
				hubFn.paintDetail(item)
			else
				hubState.detailOpen = false
				hubState.detail.Visible = false
			end
		end
	end

	function hubFn.paintPets()
		hubFn.clear(hubState.pets)
		local slots = { nil, nil, nil }
		local filled = 0
		if
			type(hubState.profile) == "table"
			and type(hubState.profile.equipped) == "table"
			and type(hubState.profile.equipped.pet) == "string"
			and type(hubState.profile.pets) == "table"
		then
			local pet = hubState.profile.pets[hubState.profile.equipped.pet]
			if type(pet) == "table" then
				slots[1] = pet
				filled += 1
			end
		end
		local following = hubFn.companions()
		for index, companion in ipairs(following) do
			if index > 2 then
				break
			end
			slots[index + 1] = companion
			filled += 1
		end
		hubFn.line(hubState.pets, string.format("Equipped  %d/3", filled), 1, rgb("gold"))
		for index = 1, 3 do
			local slot = slots[index]
			local slotName = if type(slot) == "table" then tostring(slot.name or "Pet") else "Empty"
			hubFn.row(hubState.pets, string.format("Slot %d  %s", index, slotName), index + 1, nil)
		end
		hubFn.divider(hubState.pets, 6)
		local cards = {}
		if type(hubState.profile) == "table" and type(hubState.profile.pets) == "table" then
			for _, pet in pairs(hubState.profile.pets) do
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
			hubFn.emptyState(hubState.pets, "pets", "No companions yet.", "Open pets", function() end)
		else
			local host = hubFn.cardHost(hubState.pets, hubState.pets, #cards, 7)
			for index, pet in ipairs(cards) do
				hubFn.itemCard(host, pet, index, "pet")
			end
		end
		hubFn.row(hubState.pets, "Crack a Pet Shard", 20, function()
			hubState.rollKind = "pets"
			hubFn.show("roll")
		end)
		for index, companion in ipairs(PetRoster.STARTER) do
			hubFn.line(hubState.pets, companion.name .. "  " .. companion.ability, 20 + index, rgb("text"))
		end
	end

	function hubFn.rollPoolId(): string
		if hubState.rollKind == "pets" then
			local ascension = 0
			if type(hubState.profile) == "table" and type(hubState.profile.ascension) == "number" then
				ascension = hubState.profile.ascension
			end
			local picked = "verdant_pets"
			for _, pool in ipairs(Pools.forArea("pets")) do
				if Pools.isUnlocked(pool, ascension) then
					picked = pool.id
				end
			end
			return picked
		end
		local poolId = "verdant_armory"
		if hooks.getPoolId ~= nil then
			local picked = hooks.getPoolId()
			if type(picked) == "string" and picked ~= "" then
				poolId = picked
			end
		end
		return poolId
	end




	function hubFn.rollRowWidth(): number
		local pageW = 0
		if hubState.roll ~= nil then
			pageW = hubState.roll.AbsoluteSize.X
		end
		if pageW < 80 then
			local vx, vy = hubFn.view()
			local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
			local inner = HudLayout.hubBody(box.w, box.h)
			pageW = inner.w
		end
		return math.max(44, pageW - UiTheme.PAD * 2)
	end

	function hubFn.paintRoll()
		hubFn.clear(hubState.roll)
		for _, tween in ipairs(hubState.pityTweens) do
			tween:Cancel()
		end
		hubState.pityTweens = {}
		hubFn.setPulse(hubState.loop.phase == "idle" and not hubState.rollBusy)
		local tokens = 0
		local goldHeld = 0
		if type(hubState.profile) == "table" then
			if type(hubState.profile.shardTokens) == "number" then
				tokens = hubState.profile.shardTokens
			end
			if type(hubState.profile.gold) == "number" then
				goldHeld = hubState.profile.gold
			end
		end
		hubState.walletTokens.Text = string.format("Shard Tokens  %d", tokens)
		hubState.walletGold.Text = string.format("Gold  %d", goldHeld)
		hubState.rollButton.Text = if hubState.rollKind == "pets" then "Crack Pet" else "Crack"

		local band = RollSpot.place(hubFn.rollRowWidth())
		local kindRow = Instance.new("Frame")
		kindRow.Name = "ShardKind"
		kindRow.BackgroundTransparency = 1
		kindRow.Size = UDim2.fromOffset(band.w, band.h)
		kindRow.LayoutOrder = 1
		kindRow.Parent = hubState.roll
		local function kindOn(id: string): boolean
			if id == "PetShards" then
				return hubState.rollKind == "pets"
			end
			if id == "TimesTen" then
				return hubState.pendingCount > 1 or hubState.batching
			end
			return hubState.rollKind == "gear"
		end
		local function kindPress(id: string)
			if id == "PetShards" then
				hubState.rollKind = "pets"
				hubState.summaryItems = {}
				hubFn.paintRoll()
				hubFn.show("roll")
				return
			end
			if id == "TimesTen" then
				if hubState.rollBusy then
					return
				end
				hubState.pendingCount = 10
				hubState.summaryItems = {}
				hubState.batchLeft = {}
				hubState.loop = RollLoop.press(hubState.loop)
				hubFn.beginRoll()
				return
			end
			hubState.rollKind = "gear"
			hubState.summaryItems = {}
			hubFn.paintRoll()
			hubFn.show("roll")
		end
		for _, spot in ipairs(band.buttons) do
			local button = Instance.new("TextButton")
			local chosen = kindOn(spot.id)
			button.Name = spot.id
			button.Position = UDim2.fromOffset(spot.x, spot.y)
			button.Size = UDim2.fromOffset(spot.w, spot.h)
			button.BackgroundColor3 = if chosen then rgb("button") else rgb("header")
			button.BackgroundTransparency = 0
			button.Font = headerFont()
			button.TextSize = UiTheme.MIN_TEXT
			button.TextColor3 = rgb("text")
			button.Text = spot.label
			button.TextTruncate = Enum.TextTruncate.AtEnd
			button.AutoButtonColor = false
			button.Parent = kindRow
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = button
			hubFn.setRest(button, if chosen then rgb("button") else rgb("header"))
			hubFn.motion(button)
			local spotId = spot.id
			button.Activated:Connect(function()
				kindPress(spotId)
			end)
		end

		local toggles = Instance.new("Frame")
		toggles.Name = "Toggles"
		toggles.BackgroundTransparency = 1
		toggles.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		toggles.LayoutOrder = 2
		toggles.Parent = hubState.roll
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
			hubFn.setRest(button, if on then rgb("button") else rgb("header"))
			hubFn.motion(button)
			button.Activated:Connect(fn)
		end
		toggle("Auto", if hubState.autoOn then "Auto On" else "Auto", hubState.autoOn, function()
			hubState.focusCut = false
			hubState.autoOn = RollFocus.keep(hubState.windowFocused, not hubState.autoOn)
			hubState.draft.rolls.autoConfirm = hubState.autoOn
			hubFn.save()
			if hubState.autoOn and hubState.loop.phase == "idle" and not hubState.rollBusy then
				hubState.loop = RollLoop.press(hubState.loop)
				hubFn.beginRoll()
			end
			hubFn.paintRoll()
			hubFn.show("roll")
		end)
		toggle(
			"Stop",
			if hubState.stopAt == "Off" then "Stop  Off" else "Stop at  " .. hubState.stopAt,
			hubState.stopAt ~= "Off",
			function()
				hubState.stopAt = RollBoard.nextStop(hubState.stopAt)
				hubFn.paintRoll()
				hubFn.show("roll")
			end
		)
		toggle("Quick", if hubState.quickOn then "Quick On" else "Quick", hubState.quickOn, function()
			hubState.quickOn = not hubState.quickOn
			hubFn.paintRoll()
			hubFn.show("roll")
		end)
		toggle("Info", "Info", hubState.infoOpen, function()
			hubState.infoOpen = not hubState.infoOpen
			hubFn.paintRoll()
			hubFn.show("roll")
		end)

		local junkRow = Instance.new("Frame")
		junkRow.Name = "Junk"
		junkRow.BackgroundTransparency = 1
		junkRow.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		junkRow.LayoutOrder = 3
		junkRow.Parent = hubState.roll
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
			hubFn.setRest(button, rgb("header"))
			hubFn.motion(button)
			button.Activated:Connect(fn)
		end
		junkButton("JunkMode", "Junk  " .. hubState.draft.rolls.autoJunk, function()
			local order = { "ask", "keep", "salvage" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.autoJunk then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.autoJunk = nextId
			hubFn.save()
			hubFn.paintRoll()
			hubFn.show("roll")
		end)
		junkButton("JunkBelow", "Below  " .. hubState.draft.rolls.junkBelow, function()
			local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.junkBelow then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.junkBelow = nextId
			hubFn.save()
			hubFn.paintRoll()
			hubFn.show("roll")
		end)

		local sinceEpic = if hubState.serverEpic ~= nil
			then hubState.serverEpic
			elseif type(hubState.profile) == "table" then hubState.profile.sinceEpic or 0
			else 0
		local pityResult = if hubState.serverSince ~= nil
			then { pity = { sinceLegendary = hubState.serverSince } }
			else nil
		local sinceLegendary, pityGoal = UiRouter.legendaryPity(hubState.profile, pityResult)
		local epicMeter = RollHype.pity(sinceEpic, RarityConfig.EPIC_PITY)
		local pityMeter = RollHype.pity(sinceLegendary, pityGoal)
		hubState.reelStreak.Text = UiRouter.streakText(hubState.hype.streak, hubState.lastMissed)
		hubState.reelStreak.TextColor3 = rgb(UiRouter.streakTone(hubState.hype.streak, hubState.lastMissed))
		hubFn.line(
			hubState.roll,
			UiRouter.streakText(hubState.hype.streak, hubState.lastMissed),
			6,
			rgb(UiRouter.streakTone(hubState.hype.streak, hubState.lastMissed))
		)
		hubFn.line(hubState.roll, string.format("Rolls  %d", hubState.hype.rolls), 7, rgb("text"))
		local bestText = "Best pull  —"
		if type(hubState.bestPull) == "table" then
			bestText = string.format(
				"Best pull  %s  %s",
				tostring(hubState.bestPull.name or "Item"),
				tostring(hubState.bestPull.rarity or "")
			)
		end
		hubFn.line(hubState.roll, bestText, 8, rgb("accent"))
		hubFn.line(
			hubState.roll,
			RollLoop.indexText(
				RollLoop.discoveries(hubState.profile, hubState.sessionTemplates),
				RollLoop.indexTotal()
			),
			9,
			rgb("text")
		)

		if hubState.infoOpen then
			local luck = 0
			local boost = 0
			local rolls = 0
			if type(hubState.profile) == "table" then
				luck = hubState.profile.shardLuck or 0
				boost = hubState.profile.luckBoost or 0
				rolls = hubState.profile.shardRolls or 0
			end
			local info = Instance.new("Frame")
			info.Name = "Odds"
			info.BackgroundColor3 = rgb("header")
			info.BackgroundTransparency = 0
			info.Size = UDim2.fromScale(1, 0)
			info.AutomaticSize = Enum.AutomaticSize.Y
			info.BorderSizePixel = 0
			info.LayoutOrder = 9
			info.Parent = hubState.roll
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
			hubFn.line(info, string.format("Luck  %d", luck + boost), 1, rgb("gold"))
			hubFn.line(info, RarityConfig.bonusLabel(rolls), 2, rgb("text"))
			local legendaryCount = if type(sinceLegendary) == "number" then sinceLegendary else 0
			hubFn.line(info, RarityConfig.pityLine(sinceEpic, legendaryCount), 3, rgb("text"))
			local infoPool = if hubState.rollKind == "pets"
				then Pools.get(hubFn.rollPoolId())
				else Pools.get("verdant_armory")
			local infoOdds =
				RollBoard.oddsLines(infoPool, hubState.profile, 0, UiRouter.oddsSince(legendaryCount))
			for index, text in ipairs(infoOdds) do
				hubFn.line(info, text, 3 + index, rgb("text"))
			end
		end

		local function playPity(tween: Tween)
			table.insert(hubState.pityTweens, tween)
			tween:Play()
		end
		-- Full-width rows. A phone hub is too narrow for two counters
		-- side by side, and 14px text stays on one line.
		local function meter(
			name: string,
			caption: string,
			fill: number,
			order: number,
			fromFill: number,
			gold: boolean,
			animate: string
		)
			local host = Instance.new("Frame")
			host.Name = name
			host.BackgroundColor3 = rgb("header")
			host.Size = UDim2.new(1, 0, 0, 36)
			host.BorderSizePixel = 0
			host.ClipsDescendants = true
			host.LayoutOrder = order
			host.Parent = hubState.roll
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = host
			local from = math.clamp(fromFill, 0, 1)
			local target = math.clamp(fill, 0, 1)
			local bar = Instance.new("Frame")
			bar.Name = "Fill"
			bar.Size = UDim2.fromScale(from, 1)
			bar.BackgroundColor3 = if gold then rgb("gold") else rgb("accent")
			bar.BorderSizePixel = 0
			bar.Parent = host
			local barCorner = Instance.new("UICorner")
			barCorner.CornerRadius = UDim.new(0, 6)
			barCorner.Parent = bar
			local reduced = UiMotion.reduced(hubState.draft)
			if not reduced and math.abs(target - from) > 0.001 then
				playPity(
					TweenService:Create(
						bar,
						TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Size = UDim2.fromScale(target, 1) }
					)
				)
			else
				bar.Size = UDim2.fromScale(target, 1)
			end
			if animate == "flash" and not reduced then
				bar.BackgroundTransparency = 0.55
				playPity(
					TweenService:Create(
						bar,
						TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 0 }
					)
				)
			elseif animate == "pulse" and not reduced then
				playPity(
					TweenService:Create(
						bar,
						TweenInfo.new(
							0.7,
							Enum.EasingStyle.Sine,
							Enum.EasingDirection.InOut,
							-1,
							true
						),
						{ BackgroundTransparency = 0.35 }
					)
				)
			end
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromOffset(8, 0)
			label.Size = UDim2.new(1, -16, 1, 0)
			label.Font = bodyFont()
			label.TextSize = UiTheme.MIN_TEXT
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextTruncate = Enum.TextTruncate.AtEnd
			label.TextColor3 = rgb("text")
			label.TextStrokeColor3 = rgb("ink")
			label.TextStrokeTransparency = 0.4
			label.Text = caption
			label.ZIndex = 2
			label.Parent = host
		end
		local function pityCaption(label: string, meterRow: RollHype.Meter, reset: boolean): string
			if meterRow.ok ~= true or type(meterRow.goal) ~= "number" then
				return label .. " pity"
			end
			local shown = math.floor(meterRow.counter)
			local goal = math.floor(meterRow.goal)
			if reset then
				return string.format("%s reset  %d / %d", label, shown, goal)
			end
			return string.format("%s  %d / %d", label, shown, goal)
		end
		local function armPayoff(shownRoll: number, on: boolean): (boolean, number)
			if not on then
				return false, shownRoll
			end
			if shownRoll == hubState.hype.rolls then
				return false, shownRoll
			end
			return true, hubState.hype.rolls
		end
		local function paintPity(
			name: string,
			label: string,
			meterRow: RollHype.Meter,
			floor: string,
			order: number,
			fromFill: number,
			shownRoll: number
		): (number, number)
			local fill = 0
			local reset = false
			local pulse = false
			if meterRow.ok == true and type(meterRow.goal) == "number" then
				fill = meterRow.fill
				reset = RollBoard.payoff(meterRow.counter, hubState.lastLanded, floor)
				pulse = RollBoard.pulse(meterRow.fill) and not reset
			end
			local flash, nextSeen = armPayoff(shownRoll, reset)
			local animate = if flash then "flash" elseif pulse then "pulse" else "none"
			meter(name, pityCaption(label, meterRow, reset), fill, order, fromFill, reset, animate)
			return fill, nextSeen
		end
		local nextEpicFill, nextEpicSeen =
			paintPity("EpicPity", "Epic", epicMeter, "Epic", 4, hubState.epicFillShown, hubState.epicFlashRoll)
		hubState.epicFillShown = nextEpicFill
		hubState.epicFlashRoll = nextEpicSeen
		local nextLegendaryFill, nextLegendarySeen = paintPity(
			"LegendaryPity",
			"Legendary",
			pityMeter,
			"Legendary",
			5,
			hubState.legendaryFillShown,
			hubState.legendaryFlashRoll
		)
		hubState.legendaryFillShown = nextLegendaryFill
		hubState.legendaryFlashRoll = nextLegendarySeen
		hubFn.line(hubState.roll, "Odds", 12, rgb("gold"))
		local oddsSince =
			UiRouter.oddsSince(if type(sinceLegendary) == "number" then sinceLegendary else 0)
		local odds = RollBoard.oddsLines(Pools.get("verdant_armory"), hubState.profile, 0, oddsSince)
		if hubState.rollKind == "pets" then
			odds = RollBoard.oddsLines(Pools.get(hubFn.rollPoolId()), hubState.profile, 0, oddsSince)
		end
		if #odds == 0 then
			hubFn.line(hubState.roll, "Odds are unavailable.", 13, rgb("muted"))
		else
			for index, text in ipairs(odds) do
				hubFn.line(hubState.roll, text, 13 + index, rgb("text"))
			end
		end

		local recent = if #hubState.sessionRolls > 0
			then hubState.sessionRolls
			else RollBoard.history(hubFn.bagItems(), RollBoard.HISTORY)
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
			banner.Parent = hubState.roll
			local scale = Instance.new("UIScale")
			scale.Scale = RollBoard.celebrationScale(rarity)
			scale.Parent = banner
		end
		hubFn.line(hubState.roll, "Last 10", 31, rgb("gold"))
		hubFn.divider(hubState.roll, 32)
		if #hubState.summaryItems > 0 then
			hubFn.line(hubState.roll, "Cracked", 40, rgb("gold"))
			for index, item in ipairs(hubState.summaryItems) do
				local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
				hubFn.line(
					hubState.roll,
					string.format("%s  %s", tostring(item.name or "Shard"), rarity),
					40 + index,
					hubFn.rarityColor3(rarity)
				)
			end
		end
		if #recent == 0 then
			hubFn.line(hubState.roll, "No rolls yet.", 33, rgb("muted"))
		else
			local strip = Instance.new("Frame")
			strip.Name = "History"
			strip.BackgroundTransparency = 1
			strip.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
			strip.LayoutOrder = 33
			strip.Parent = hubState.roll
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
				if index == 1 and hubState.slideHistory then
					local chipScale = Instance.new("UIScale")
					chipScale.Parent = chip
					if UiMotion.reduced(hubState.draft) then
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
		hubState.slideHistory = false
		hubFn.fitRoll()
	end

	hubState.activeItem = nil
	hubState.activeNew = false
	hubState.activeUpgrade = false

	function hubFn.tokenCount(): number
		if type(hubState.profile) == "table" and type(hubState.profile.shardTokens) == "number" then
			return hubState.profile.shardTokens
		end
		return 0
	end

	function hubFn.hapticTick()
		pcall(function()
			local haptic = game:GetService("HapticService")
			haptic:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.2)
			task.delay(0.05, function()
				haptic:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
			end)
		end)
	end

	function hubFn.cameraTick()
		if hubState.draft.camera.shake ~= true or UiMotion.reduced(hubState.draft) then
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

	function hubFn.squash()
		local length = UiMotion.press(UiMotion.reduced(hubState.draft))
		if length <= 0 then
			hubState.pressScale.Scale = 0.92
			task.delay(0.05, function()
				hubState.pressScale.Scale = 1
			end)
			return
		end
		local down = TweenService:Create(
			hubState.pressScale,
			TweenInfo.new(length * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0.92 }
		)
		down.Completed:Connect(function()
			TweenService:Create(
				hubState.pressScale,
				TweenInfo.new(length, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)
		down:Play()
	end

	function hubFn.paintResult(
		item: any,
		record: RollReveal.Record,
		isNew: boolean,
		upgrade: boolean
	)
		hubState.revealCard.Visible = true
		hubState.revealTitle.Text = record.name
		hubState.revealRarity.Text = record.rarity
		local color = hubFn.rarityColor3(record.rarity)
		hubState.revealRarity.TextColor3 = color
		hubState.revealStroke.Color = color
		hubState.revealNew.Visible = isNew
		hubState.revealBest.Visible = false
		local drip = RollLoop.drip()
		hubState.revealFly.Text = drip.text
		hubState.revealFly.TextTransparency = 0
		hubState.revealFly.Position = UDim2.fromOffset(12, 72)
		if not UiMotion.reduced(hubState.draft) then
			hubFn.playCardTween(
				TweenService:Create(
					hubState.revealFly,
					TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Position = UDim2.fromOffset(12, 36),
						TextTransparency = 1,
					}
				)
			)
		end
		local junk =
			RollLoop.resolve(record.rarity, hubState.draft.rolls.junkBelow, hubState.draft.rolls.autoJunk, upgrade)
		hubState.revealEquip.Visible = junk == "equip" and hubState.cardRoom >= 72
		if type(item.uid) == "string" then
			hubState.revealEquip:SetAttribute("Uid", item.uid)
		end
		if junk == "salvage" and type(item.uid) == "string" then
			task.spawn(function()
				pcall(hooks.invoke, "Salvage", item.uid)
			end)
		end
	end

	function hubFn.chainAllowed(queued: boolean): boolean
		if RollFocus.chain(hubState.windowFocused) ~= true then
			return false
		end
		local pending = if type(hubState.activeItem) == "table" then hubState.activeItem.uid else nil
		local rarity = "Common"
		if type(hubState.activeItem) == "table" and type(hubState.activeItem.rarity) == "string" then
			rarity = hubState.activeItem.rarity
		end
		return RollLoop.canChain({
			open = hubState.route.open,
			onRoll = hubState.shownId == "roll",
			alive = hubState.playerAlive,
			queued = queued,
			holding = hubState.holdingRoll,
			auto = hubState.autoOn,
			tokens = hubFn.tokenCount(),
			bagFull = RollLoop.bagFull(hubState.profile, pending),
			rarity = rarity,
			stopAt = hubState.stopAt,
			isNew = hubState.activeNew,
			isUpgrade = hubState.activeUpgrade,
		})
	end

	function hubFn.stageReveal()
		hubState.revealCard.Visible = true
		hubState.revealTitle.Text = ""
		hubState.revealRarity.Text = ""
		hubState.revealNew.Visible = false
		hubState.revealBest.Visible = false
		hubState.revealEquip.Visible = false
		hubState.revealCard.BackgroundColor3 = rgb("header")
		hubState.revealStroke.Color = rgb("accent")
		hubFn.restShard()
	end

	function hubFn.crackMode(rarity: string, quick: boolean): string
		if UiMotion.reduced(hubState.draft) then
			return "reduced"
		end
		local skips = false
		local skipOk, skipped = pcall(Settings.skipsCutscene, hubState.draft, rarity)
		if skipOk and skipped == true then
			skips = true
		end
		if skips then
			return "skip"
		end
		if quick then
			return "quick"
		end
		return "full"
	end

	hubFn.finishReveal = function()
		hubState.activeReveal = nil
		hubFn.restShard()
		if #hubState.batchLeft > 0 then
			local nextCrack = table.remove(hubState.batchLeft, 1)
			hubState.replayResult = {
				ok = true,
				item = nextCrack.item,
				rarity = nextCrack.rarity,
				fillerSeed = nextCrack.fillerSeed,
				pity = nextCrack.pity,
				quick = true,
				currency = "shard",
			}
			hubState.rollBusy = false
			hubState.loop = { phase = "revealing", queued = false }
			hubFn.beginRoll()
			return
		end
		if hubState.batching then
			hubState.batching = false
			hubState.pendingCount = 1
			hubState.loop = RollLoop.idle()
			hubFn.setPulse(true)
			hubFn.paintRoll()
			return
		end
		local finished = RollLoop.finish(hubState.loop)
		if hubFn.chainAllowed(finished.phase == "revealing") then
			hubState.loop = { phase = "revealing", queued = false }
			hubFn.beginRoll()
			return
		end
		hubState.loop = RollLoop.idle()
		hubFn.setPulse(true)
	end

	hubFn.beginRoll = function()
		if hubState.rollBusy then
			return
		end
		hubState.rollBusy = true
		hubFn.setPulse(false)
		hubState.revealToken += 1
		hubFn.bumpCardGeneration()
		-- Cancel leaves a flash or drip where it was. Snap them off so the
		-- previous roll cannot sit on top of this one.
		hubState.flashCover.BackgroundTransparency = 1
		hubState.revealScale.Scale = 1
		hubState.revealFly.TextTransparency = 1
		local generation = hubState.revealToken
		task.spawn(function()
			local replay = hubState.replayResult
			hubState.replayResult = nil
			local ok = false
			local result: any = nil
			local poolId = hubFn.rollPoolId()
			if replay ~= nil then
				ok = true
				result = replay
			else
				local waitFor = RarityConfig.COOLDOWN - (os.clock() - hubState.lastCrack)
				if hubState.lastCrack > 0 and waitFor > 0 then
					task.wait(waitFor)
				end
				if generation ~= hubState.revealToken then
					hubState.rollBusy = false
					return
				end
				if RollFocus.chain(hubState.windowFocused) ~= true then
					hubState.rollBusy = false
					hubState.loop = RollLoop.idle()
					hubFn.setPulse(true)
					return
				end
				if hubState.pendingCount > 1 then
					local count = hubState.pendingCount
					hubState.pendingCount = 1
					local batchOk, batch = pcall(hooks.invoke, "RollShards", poolId, count)
					if generation ~= hubState.revealToken then
						hubState.rollBusy = false
						return
					end
					if
						batchOk
						and type(batch) == "table"
						and type(batch.items) == "table"
						and #batch.items > 0
					then
						hubState.batching = true
						hubState.summaryItems = {}
						hubState.batchLeft = {}
						for index = 2, #batch.items do
							table.insert(hubState.batchLeft, batch.items[index])
						end
						local first = batch.items[1]
						result = {
							ok = true,
							item = first.item,
							rarity = first.rarity,
							fillerSeed = first.fillerSeed,
							pity = first.pity,
							quick = true,
							currency = batch.currency,
						}
						ok = true
					else
						hubState.batching = false
						ok = batchOk
						result = batch
					end
				else
					ok, result = pcall(hooks.invoke, "RollShard", poolId, false)
				end
			end
			if generation ~= hubState.revealToken then
				hubState.rollBusy = false
				return
			end
			hubState.rollBusy = false
			local record = if ok then RollReveal.capture(result) else nil
			local paid = type(result) == "table"
				and (result.currency == "prism" or result.paid == true)
			local function closeFor(rarity: string?, landed: boolean): UiRouter.CloseCall
				return UiRouter.closeCall({
					stopAt = hubState.stopAt,
					rarity = rarity,
					landed = landed,
					paid = paid,
					profile = hubState.profile,
					result = result,
				})
			end
			local function applyClose(call: UiRouter.CloseCall)
				if call.nearMiss == true and type(call.rarity) == "string" then
					hubFn.showCloseBeat(call.rarity)
				else
					hubFn.hideCloseBeat()
				end
			end
			-- A refusal did not land and did not miss. Leave the streak.
			local kind = RollRefuse.classify(ok, result)
			if kind ~= "land" or record == nil then
				local caption = "Roll"
				if kind == "refuse" then
					hubFn.hideCloseBeat()
					caption = RollReveal.reelCaption(result)
					if type(result) == "string" and string.find(result, "\n", 1, true) == nil then
						local trimmed = string.match(result, "^%s*(.-)%s*$")
						if trimmed ~= nil and trimmed ~= "" then
							caption = result
						end
					end
				elseif kind == "miss" then
					local missed = RollHype.note(hubState.hype, { landed = false })
					local close = closeFor(nil, false)
					if missed.ok == true then
						hubState.hype = missed.state
					end
					hubState.lastMissed = true
					applyClose(close)
				else
					-- Unusable land. Do not note a miss.
					hubFn.hideCloseBeat()
				end
				hubState.loop = RollLoop.idle()
				hubFn.blankReveal()
				hubState.reelMilestone.Visible = false
				hubFn.setPulse(true)
				if kind == "miss" then
					hubFn.paintReelIdle(RollReveal.reelCaption(result))
				else
					hubFn.paintReelIdle(caption)
				end
				hubFn.paintRoll()
				return
			end
			hubState.lastCrack = os.clock()
			local noted = RollHype.note(hubState.hype, {
				rarity = record.rarity,
				landed = true,
				paid = paid,
			})
			local close = closeFor(record.rarity, true)
			if noted.ok ~= true or noted.rarity == nil then
				hubState.loop = RollLoop.idle()
				hubFn.blankReveal()
				hubFn.setPulse(true)
				hubFn.hideCloseBeat()
				hubFn.paintReelIdle("Roll")
				hubFn.paintRoll()
				return
			end
			hubState.hype = noted.state
			hubState.lastMissed = false
			hubState.lastLanded = noted.rarity
			local item = result.item
			local card = UiRouter.rollCard(noted, item)
			if card == nil then
				hubState.loop = RollLoop.idle()
				hubFn.blankReveal()
				hubFn.setPulse(true)
				hubFn.hideCloseBeat()
				hubFn.paintReelIdle("Roll")
				hubFn.paintRoll()
				return
			end
			local owned = RollLoop.ownedTemplates(
				hubState.profile,
				if type(item.uid) == "string" then item.uid else nil
			)
			hubState.activeNew = RollLoop.isNew(item.templateId, owned)
			hubState.activeUpgrade = RollLoop.isUpgrade(hubState.profile, item)
			hubState.activeItem = item
			hubState.bestPull = RollLoop.best(hubState.bestPull, item)
			if type(item.templateId) == "string" then
				table.insert(hubState.sessionTemplates, item.templateId)
			end
			table.insert(hubState.sessionRolls, 1, item)
			while #hubState.sessionRolls > RollBoard.HISTORY do
				table.remove(hubState.sessionRolls)
			end
			hubState.slideHistory = true
			if type(result.pity) == "table" then
				if type(result.pity.sinceEpic) == "number" then
					hubState.serverEpic = result.pity.sinceEpic
				end
				if type(result.pity.sinceLegendary) == "number" then
					hubState.serverSince = result.pity.sinceLegendary
				end
			end
			local reduced = UiMotion.reduced(hubState.draft)
			local quick = result.quick == true or hubState.quickOn
			local pace = RollHype.tempo(noted.rarity, paid)
			local duration = UiRouter.rollBuildUp(hubState.draft, noted.rarity, quick, reduced, {
				ok = pace.ok,
				buildUp = pace.buildUp,
				rarity = pace.rarity,
				tier = pace.tier,
			})
			if duration == nil then
				hubState.loop = RollLoop.idle()
				hubFn.blankReveal()
				hubFn.setPulse(true)
				hubFn.hideCloseBeat()
				hubFn.paintReelIdle("Roll")
				hubFn.paintRoll()
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
			hubState.pendingFace = {
				item = item,
				record = shownRecord,
				isNew = hubState.activeNew,
				upgrade = hubState.activeUpgrade,
			}
			if hubState.batching then
				table.insert(hubState.summaryItems, item)
			end
			hubState.crackNamed = false
			hubState.crackSounded = false
			hubFn.stageReveal()
			local callout, personal = UiRouter.rollShout(noted)
			if personal ~= nil then
				hubFn.flashPersonalBest(personal)
			end
			if callout ~= nil then
				hubFn.showMilestone(callout)
			else
				hubState.reelMilestone.Visible = false
			end
			hubFn.paintRoll()
			applyClose(close)
			local color = hubFn.rarityColor3(card.rarity)
			local pop = UiRouter.rollPop(pace.tier, reduced)
			local plan = CrackReveal.plan(card.rarity, hubFn.crackMode(card.rarity, quick or hubState.batching))
			duration = plan.seconds
			if duration <= 0 then
				hubFn.paintReel(slots, #slots)
				hubState.revealCard.BackgroundColor3 = color
				hubState.revealScale.Scale = if reduced then 1 else pop
				if not reduced then
					hubFn.playCardTween(
						TweenService:Create(
							hubState.revealScale,
							TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ Scale = 1 }
						)
					)
				end
				if RollLoop.flash(card.rarity, reduced, hubState.draft.camera.flash == "reduced") then
					hubState.flashCover.BackgroundColor3 = color
					hubState.flashCover.BackgroundTransparency = 0.45
					hubFn.playCardTween(
						TweenService:Create(
							hubState.flashCover,
							TweenInfo.new(0.08),
							{ BackgroundTransparency = 1 }
						)
					)
				end
				if RollLoop.stinger(card.rarity, reduced) then
					hubFn.playUi("stinger")
				elseif not reduced and (pace.tier or 0) >= 3 then
					hubFn.playUi("confirm")
				end
				hubFn.finishReveal()
				return
			end
			hubState.revealCard.BackgroundColor3 = rgb("header")
			hubFn.paintReelIdle("Shard")
			hubState.activeReveal = {
				started = os.clock(),
				duration = duration,
				rarity = card.rarity,
				tier = pace.tier,
				flashed = false,
				nextTick = os.clock(),
				slots = slots,
				generation = hubState.cardGeneration,
				plan = plan,
			}
		end)
	end

	function hubFn.pointerDown(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
	end

	function hubFn.pressRoll()
		hubFn.playUi("click")
		hubFn.squash()
		hubFn.hapticTick()
		hubFn.cameraTick()
		local previous = hubState.loop.phase
		hubState.loop = RollLoop.press(hubState.loop)
		if previous ~= "revealing" then
			hubFn.beginRoll()
		end
	end

	hubState.rollButton.MouseEnter:Connect(function()
		hubState.rollButton.BackgroundColor3 = rgb("hover")
	end)
	hubState.rollButton.MouseLeave:Connect(function()
		hubState.rollButton.BackgroundColor3 = rgb("button")
	end)
	hubState.rollButton.InputBegan:Connect(function(input)
		if hubFn.pointerDown(input) then
			hubState.holdingRoll = true
			hubState.rollButton.BackgroundColor3 = rgb("press")
			hubFn.pressRoll()
		end
	end)
	hubState.rollButton.InputEnded:Connect(function(input)
		if hubFn.pointerDown(input) then
			hubState.holdingRoll = false
			hubState.rollButton.BackgroundColor3 = rgb("button")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if hubFn.pointerDown(input) then
			hubState.holdingRoll = false
		end
	end)
	hubState.revealEquip.Activated:Connect(function()
		local uid = hubState.revealEquip:GetAttribute("Uid")
		if type(uid) ~= "string" or uid == "" then
			return
		end
		task.spawn(function()
			pcall(hooks.invoke, "EquipItem", uid)
		end)
	end)
	RunService.Heartbeat:Connect(function()
		local active = hubState.activeReveal
		if active == nil or active.generation ~= hubState.cardGeneration then
			return
		end
		local elapsed = os.clock() - active.started
		if active.plan ~= nil then
			local sample = CrackReveal.sample(active.plan, elapsed)
			local color = hubFn.rarityColor3(active.rarity)
			local shake = sample.shake
			local offset = 0
			if shake > 0 then
				offset = math.sin(os.clock() * 46) * (2 + shake * 7)
			end
			hubState.shardStone.Position = UDim2.new(0.5, offset, hubState.stoneY, 0)
			hubState.crackLine.Size = UDim2.new(0, 2 + math.floor(sample.crack * 8), sample.crack * 0.76, 0)
			if sample.burst > 0 then
				hubState.shardStone.BackgroundColor3 = color
				hubState.reelHost.BackgroundColor3 = color:Lerp(rgb("header"), 1 - sample.burst)
				hubState.reelStroke.Color = color
				hubState.reelStroke.Thickness = 2 + sample.glow * 5
				hubState.reelCenter.Text = active.rarity
				hubState.reelCenter.BackgroundColor3 = color
				hubState.reelCenter.TextColor3 = rgb("ink")
			elseif sample.tension then
				hubState.reelStroke.Color = color
				hubState.reelStroke.Thickness = 5
				hubState.reelCenter.Text = "..."
				hubState.reelCenter.BackgroundColor3 = rgb("body")
				hubState.reelCenter.TextColor3 = rgb("text")
			elseif sample.glow > 0 then
				hubState.reelStroke.Color = color
				hubState.reelStroke.Thickness = 2 + sample.glow * 3
				hubState.reelCenter.Text = "Shard"
			else
				hubState.reelCenter.Text = "Shard"
				hubState.reelCenter.BackgroundColor3 = rgb("body")
				hubState.reelCenter.TextColor3 = rgb("text")
			end
			if sample.flash then
				hubState.flashCover.BackgroundColor3 = color
				hubState.flashCover.BackgroundTransparency = 0.42
			elseif sample.burst >= 0.4 then
				hubState.flashCover.BackgroundTransparency = 1
			end
			if sample.sound ~= nil and not hubState.crackSounded then
				hubState.crackSounded = true
				hubFn.playUi(sample.sound)
			end
			if sample.showName and not hubState.crackNamed and type(hubState.pendingFace) == "table" then
				hubState.crackNamed = true
				hubFn.paintResult(hubState.pendingFace.item, hubState.pendingFace.record, hubState.pendingFace.isNew, hubState.pendingFace.upgrade)
			end
			if elapsed >= active.duration then
				if not hubState.crackNamed and type(hubState.pendingFace) == "table" then
					hubState.crackNamed = true
					hubFn.paintResult(
						hubState.pendingFace.item,
						hubState.pendingFace.record,
						hubState.pendingFace.isNew,
						hubState.pendingFace.upgrade
					)
				end
				hubFn.finishReveal()
			end
			return
		end
		local reduced = UiMotion.reduced(hubState.draft)
		local tint = RollLoop.tint(elapsed, active.duration, active.rarity)
		local color = hubFn.rarityColor3(active.rarity)
		local progress = if active.duration <= 0
			then 1
			else RollReveal.spinProgress(elapsed, active.duration)
		if active.slots ~= nil then
			hubFn.paintReel(active.slots, UiRouter.reelCenter(#active.slots, progress))
		end
		if active.rarity == "Secret" and not reduced then
			hubState.reelStroke.Color = Color3.fromHSV((os.clock() * 0.35) % 1, 0.45, 1)
		end
		if tint ~= nil or elapsed >= active.duration then
			hubState.revealCard.BackgroundColor3 = color
			hubState.revealStroke.Color = color
			hubState.revealStroke.Thickness = if tint ~= nil then 3 else UiTheme.STROKE
		else
			hubState.revealCard.BackgroundColor3 = rgb("header")
			hubState.revealStroke.Thickness = UiTheme.STROKE
		end
		local morph = RollReveal.morph(elapsed, active.duration)
		local pop = UiRouter.rollPop(active.tier, reduced)
		if morph ~= nil and not reduced then
			hubState.revealScale.Scale = RollReveal.morphScale(morph) * pop
		elseif RollLoop.slowmo(elapsed, active.duration, active.rarity, reduced) then
			hubState.revealScale.Scale = 1.08
		else
			hubState.revealScale.Scale = 1
		end
		if not reduced and active.duration > 0 and os.clock() >= active.nextTick then
			hubFn.playUi("click")
			active.nextTick = os.clock() + math.clamp(0.05 + (1 - progress) * 0.16, 0.05, 0.2)
		end
		if
			not active.flashed
			and RollLoop.slowmo(elapsed, active.duration, active.rarity, reduced)
			and RollLoop.flash(active.rarity, reduced, hubState.draft.camera.flash == "reduced")
		then
			active.flashed = true
			hubState.flashCover.BackgroundColor3 = color
			hubState.flashCover.BackgroundTransparency = 0.45
			hubFn.playCardTween(
				TweenService:Create(
					hubState.flashCover,
					TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				)
			)
			if RollLoop.stinger(active.rarity, reduced) then
				hubFn.playUi("stinger")
			end
		end
		if elapsed >= active.duration then
			hubFn.finishReveal()
		end
	end)

	function hubFn.applyTextScale()
		local textScale = 1
		if type(hubState.draft.access.textScale) == "number" then
			textScale = hubState.draft.access.textScale
		end
		for _, desc in ipairs(hubState.screen:GetDescendants()) do
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

	function hubFn.paint()
		hubFn.paintHints()
		hubFn.paintHero()
		hubFn.paintBag()
		hubFn.paintPets()
		hubFn.paintRoll()
		hubFn.clear(hubState.raids)
		hubFn.clear(hubState.market)
		hubFn.clear(hubState.pass)
		hubFn.clear(hubState.settingsPage)
		local marks = if type(hubState.profile) == "table" then hubState.profile.raidMarks or 0 else 0
		hubFn.emptyState(hubState.raids, "raids", "No raid is forming.", "Open finder", function()
			hubFn.line(hubState.raids, string.format("Marks  %d", marks), 2, rgb("gold"))
		end)
		hubFn.emptyState(hubState.market, "market", "Nothing is listed yet.", "Open board", function()
			hooks.onMarket()
		end)
		local tier = if type(hubState.profile) == "table" then hubState.profile.passTier or 0 else 0
		hubFn.emptyState(
			hubState.pass,
			"pass",
			string.format("The Shard Pass is quiet. Tier %s.", tostring(tier)),
			"Check daily",
			function() end
		)

		local function cycle(label: string, order: number, step: () -> ())
			hubFn.row(hubState.settingsPage, label, order, function()
				step()
				hubFn.save()
				hubFn.paint()
				hubFn.show("settings")
			end)
		end
		cycle("Graphics  " .. hubState.draft.graphics.quality, 1, function()
			local order = { "auto", "low", "med", "high" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.graphics.quality then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.graphics.quality = nextId
		end)
		cycle(string.format("VFX  %d%%", math.floor(hubState.draft.graphics.vfx * 100 + 0.5)), 2, function()
			hubState.draft.graphics.vfx = (math.floor(hubState.draft.graphics.vfx * 4 + 1) % 5) / 4
		end)
		cycle("Shadows  " .. (if hubState.draft.graphics.shadows then "On" else "Off"), 3, function()
			hubState.draft.graphics.shadows = not hubState.draft.graphics.shadows
		end)
		cycle(string.format("FPS cap  %d", hubState.draft.graphics.fpsCap), 4, function()
			hubState.draft.graphics.fpsCap = if hubState.draft.graphics.fpsCap == 30
				then 60
				elseif hubState.draft.graphics.fpsCap == 60 then 120
				else 30
		end)
		cycle("Roll animation  " .. hubState.draft.rolls.animation, 10, function()
			local order = { "full", "short", "instant" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.animation then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.animation = nextId
		end)
		cycle("Skip cutscene at  " .. hubState.draft.rolls.skipAt, 11, function()
			local order = { "off", "rare", "epic", "legendary", "mythic" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.skipAt then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.skipAt = nextId
		end)
		cycle(
			"Auto-roll confirm  " .. (if hubState.draft.rolls.autoConfirm then "On" else "Off"),
			12,
			function()
				hubState.draft.rolls.autoConfirm = not hubState.draft.rolls.autoConfirm
				hubState.focusCut = false
				hubState.autoOn = RollFocus.keep(
					hubState.windowFocused,
					hubState.draft.rolls.autoConfirm
				)
			end
		)
		cycle("Junk  " .. hubState.draft.rolls.autoJunk, 13, function()
			local order = { "ask", "keep", "salvage" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.autoJunk then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.autoJunk = nextId
		end)
		cycle("Below  " .. hubState.draft.rolls.junkBelow, 14, function()
			local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.rolls.junkBelow then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.rolls.junkBelow = nextId
		end)
		cycle("Camera shake  " .. (if hubState.draft.camera.shake then "On" else "Off"), 20, function()
			hubState.draft.camera.shake = not hubState.draft.camera.shake
		end)
		cycle("Screen flash  " .. hubState.draft.camera.flash, 21, function()
			hubState.draft.camera.flash = if hubState.draft.camera.flash == "normal" then "reduced" else "normal"
		end)
		cycle(string.format("Sensitivity  %.1f", hubState.draft.camera.sensitivity), 22, function()
			hubState.draft.camera.sensitivity = math.clamp(hubState.draft.camera.sensitivity + 0.2, 0.4, 2)
			if hubState.draft.camera.sensitivity >= 2 then
				hubState.draft.camera.sensitivity = 0.4
			end
		end)
		cycle(string.format("FOV  %d", math.floor(hubState.draft.camera.fov + 0.5)), 23, function()
			hubState.draft.camera.fov = if hubState.draft.camera.fov >= 90 then 50 else hubState.draft.camera.fov + 10
		end)
		cycle(
			string.format("Master  %d%%", math.floor(hubState.draft.audio.master * 100 + 0.5)),
			30,
			function()
				hubState.draft.audio.master = (math.floor(hubState.draft.audio.master * 4 + 1) % 5) / 4
			end
		)
		cycle(
			string.format("Music  %d%%", math.floor(hubState.draft.audio.music * 100 + 0.5)),
			31,
			function()
				hubState.draft.audio.music = (math.floor(hubState.draft.audio.music * 4 + 1) % 5) / 4
			end
		)
		cycle(string.format("SFX  %d%%", math.floor(hubState.draft.audio.sfx * 100 + 0.5)), 32, function()
			hubState.draft.audio.sfx = (math.floor(hubState.draft.audio.sfx * 4 + 1) % 5) / 4
		end)
		cycle(
			string.format("UI audio  %d%%", math.floor(hubState.draft.audio.ui * 100 + 0.5)),
			33,
			function()
				hubState.draft.audio.ui = (math.floor(hubState.draft.audio.ui * 4 + 1) % 5) / 4
			end
		)
		cycle("Hide HUD  " .. (if hubState.draft.hud.hidden then "On" else "Off"), 40, function()
			hubState.draft.hud.hidden = not hubState.draft.hud.hidden
		end)
		cycle(
			string.format("UI scale  %d%%", math.floor(hubState.draft.hud.scale * 100 + 0.5)),
			41,
			function()
				local nextScale = hubState.draft.hud.scale + 0.05
				if nextScale > 1.25 then
					nextScale = 0.9
				end
				hubState.draft.hud.scale = nextScale
				hubState.uiScale.Scale = nextScale
			end
		)
		cycle(
			"Damage numbers  " .. (if hubState.draft.hud.damageNumbers then "On" else "Off"),
			42,
			function()
				hubState.draft.hud.damageNumbers = not hubState.draft.hud.damageNumbers
			end
		)
		cycle("Other players' VFX  " .. (if hubState.draft.hud.otherVfx then "On" else "Off"), 43, function()
			hubState.draft.hud.otherVfx = not hubState.draft.hud.otherVfx
		end)
		cycle("Nameplates  " .. (if hubState.draft.hud.nameplates then "On" else "Off"), 44, function()
			hubState.draft.hud.nameplates = not hubState.draft.hud.nameplates
		end)
		local keys = hubState.draft.controls.hotkeys
		local keyOrder = 50
		for _, field in ipairs(Keybinds.MENU_ORDER) do
			local fieldName = field
			local label = string.format("Hotkey %s  %s", fieldName, keys[fieldName])
			if hubState.capturing == fieldName then
				label = label .. "  press a key"
			end
			cycle(label, keyOrder, function()
				hubState.capturing = fieldName
				hubState.bindNote = nil
			end)
			keyOrder += 1
		end
		if hubState.bindNote ~= nil then
			cycle(hubState.bindNote, keyOrder, function() end)
		end
		cycle(
			string.format(
				"Mobile button size  %d%%",
				math.floor(hubState.draft.controls.mobileScale * 100 + 0.5)
			),
			60,
			function()
				local nextScale = hubState.draft.controls.mobileScale + 0.05
				if nextScale > 1.25 then
					nextScale = 0.9
				end
				hubState.draft.controls.mobileScale = nextScale
			end
		)
		cycle("Layout edit  " .. (if hubState.draft.controls.layoutEdit then "On" else "Off"), 61, function()
			hubState.draft.controls.layoutEdit = not hubState.draft.controls.layoutEdit
		end)
		cycle("Trades  " .. hubState.draft.social.trades, 70, function()
			local order = { "everyone", "friends", "off" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.social.trades then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.social.trades = nextId
		end)
		cycle("Raid invites  " .. (if hubState.draft.social.raidInvites then "On" else "Off"), 71, function()
			hubState.draft.social.raidInvites = not hubState.draft.social.raidInvites
		end)
		cycle("Chat filter  " .. hubState.draft.social.chatFilter, 72, function()
			local order = { "default", "strict", "off" }
			local nextId = order[1]
			for index, id in ipairs(order) do
				if id == hubState.draft.social.chatFilter then
					nextId = order[(index % #order) + 1]
				end
			end
			hubState.draft.social.chatFilter = nextId
		end)
		cycle(
			"Colorblind pips  " .. (if hubState.draft.access.colorblind then "On" else "Off"),
			80,
			function()
				hubState.draft.access.colorblind = not hubState.draft.access.colorblind
			end
		)
		cycle(
			string.format("Text size  %d%%", math.floor(hubState.draft.access.textScale * 100 + 0.5)),
			81,
			function()
				hubState.draft.access.textScale = if hubState.draft.access.textScale >= 1.4
					then 1
					else hubState.draft.access.textScale + 0.1
			end
		)
		cycle(
			"Hold instead of tap  " .. (if hubState.draft.access.holdToTap then "On" else "Off"),
			82,
			function()
				hubState.draft.access.holdToTap = not hubState.draft.access.holdToTap
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
				hubFn.row(hubState.settingsPage, "Debug  " .. name, 100 + index, function()
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
				hubFn.row(hubState.settingsPage, "Grant  " .. pair[2], 120 + index, function()
					task.spawn(function()
						pcall(hooks.invoke, "DevGrant", kind)
					end)
				end)
			end
			hubFn.row(hubState.settingsPage, "Debug  Boss", 140, function()
				task.spawn(function()
					pcall(hooks.invoke, "Dungeon", "skip")
				end)
			end)
		end
		hubFn.applyTextScale()
	end

	function hubFn.playOpenMotion(fromClosed: boolean)
		if hubState.openTween ~= nil then
			hubState.openTween:Cancel()
			hubState.openTween = nil
		end
		if not fromClosed then
			hubState.openScale.Scale = 1
			return
		end
		hubFn.playUi("open")
		local length = UiMotion.panel(UiMotion.reduced(hubState.draft))
		if length <= 0 then
			hubState.openScale.Scale = 1
			return
		end
		hubState.openScale.Scale = 0.96
		local tween = TweenService:Create(
			hubState.openScale,
			TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		hubState.openTween = tween
		tween:Play()
	end

	function hubFn.apply(state: UiRouter.State)
		local wasOpen = hubState.route.open
		if UiRouter.top(hubState.route) == "class" and UiRouter.top(state) ~= "class" then
			hubState.classDismissed = true
		end
		hubState.route = state
		hubState.backdrop.BackgroundTransparency = 1 - state.dim
		hubState.backdrop.Modal = state.open
		hubFn.setWorldInput(state.open)
		hubState.screen.Enabled = state.open
		hubState.shadow.Visible = state.open
		hubState.panel.Visible = state.open
		hubState.classModal.Visible = state.open and UiRouter.top(state) == "class"
		if state.open then
			hubFn.place()
			hubFn.show(hubFn.pageFor(state))
			hubFn.playOpenMotion(not wasOpen)
		else
			hubFn.stopRollChain()
			if wasOpen then
				hubFn.playUi("close")
			end
			hubFn.playOpenMotion(false)
		end
		hooks.onDim(state.open)
	end

	function hubFn.close()
		hubFn.apply(UiRouter.close(hubState.route))
	end

	function hubFn.handoffRoll()
		hubFn.apply(UiRouter.rollHandoff(hubState.route))
	end

	function hubFn.pop()
		if not hubState.route.open then
			return
		end
		hubFn.apply(UiRouter.pop(hubState.route))
	end

	function hubFn.follow(nextState: UiRouter.State)
		if nextState.generation == hubState.route.generation then
			return
		end
		local prompt = nextState.open
			and nextState.tab == "hero"
			and UiRouter.top(nextState) == "hero"
			and not (hubState.route.open and hubState.route.tab == "hero" and UiRouter.top(hubState.route) == "hero")
		hubFn.apply(nextState)
		if prompt then
			hubFn.showClassPrompt(true)
		end
	end

	function hubFn.open(id: string)
		hubFn.paint()
		hubFn.follow(UiRouter.open(hubState.route, id))
	end

	function hubFn.toggle(id: string)
		local nextState = UiRouter.toggle(hubState.route, id)
		if nextState.open then
			hubFn.paint()
		end
		hubFn.follow(nextState)
	end

	for index, tab in ipairs(ClientChrome.TABS) do
		local button = Instance.new("TextButton")
		button.Name = tab.id
		button.LayoutOrder = if tab.id == "settings" then 100 else index
		button.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("body")
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = hubState.tabs
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
		hubFn.iconOn(button, tab.id, 10, 11, 22)
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
		hubFn.setRest(button, rgb("body"))
		hubFn.motion(button)
		local tabId = tab.id
		button.Activated:Connect(function()
			hubFn.paint()
			hubFn.follow(UiRouter.switch(hubState.route, tabId))
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
		hubState.tabButtons[tab.id] = button
		hubState.tabAccents[tab.id] = accent
		hubState.tabCaptions[tab.id] = caption
		hubState.tabDots[tab.id] = dot
	end
	hubFn.paintHints()

	hubState.backdrop.Activated:Connect(hubFn.pop)
	hubState.closeButton.Activated:Connect(hubFn.pop)
	hubState.classClose.Activated:Connect(function()
		hubState.classDismissed = true
		hubFn.pop()
	end)
	hubState.detailBack.Activated:Connect(function()
		hubState.detailOpen = false
		hubState.detail.Visible = false
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		hubState.windowFocused = false
		hubState.focusCut = true
		hubState.holdingRoll = false
		hubState.autoOn = RollFocus.keep(false, hubState.autoOn)
		if hubState.shownId == "roll" then
			hubFn.paintRoll()
		end
	end)
	UserInputService.WindowFocused:Connect(function()
		hubState.windowFocused = true
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if hubState.capturing ~= nil and input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode.Name
			if string.match(key, "^%a$") ~= nil or #key == 1 then
				local letter = string.upper(string.sub(key, 1, 1))
				if string.match(letter, "^%a$") ~= nil then
					local nextKeys, warning =
						Keybinds.assign(hubState.draft.controls.hotkeys, hubState.capturing, letter)
					if warning ~= nil then
						hubState.bindNote = warning
					else
						hubState.draft.controls.hotkeys = nextKeys
						hubState.bindNote = nil
						if hubState.route.open then
							hubFn.bindSinkKeys()
						end
						hubFn.save()
					end
					hubState.capturing = nil
					hubFn.paint()
					hubFn.show("settings")
				end
			end
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if hubState.route.open then
				hubFn.pop()
			end
			return
		end
		if hubState.route.open and input.KeyCode == Enum.KeyCode.ButtonL1 then
			hubFn.follow(UiRouter.shoulder(hubState.route, -1))
			return
		end
		if hubState.route.open and input.KeyCode == Enum.KeyCode.ButtonR1 then
			hubFn.follow(UiRouter.shoulder(hubState.route, 1))
			return
		end
		if hubState.route.open then
			local nextState = UiRouter.key(hubState.route, input.KeyCode.Name, hubState.draft.controls.hotkeys)
			if nextState.generation ~= hubState.route.generation then
				hubFn.follow(nextState)
			end
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local nextState = UiRouter.key(hubState.route, input.KeyCode.Name, hubState.draft.controls.hotkeys)
		if nextState.open then
			hubFn.paint()
		end
		hubFn.follow(nextState)
	end)

	-- Combat pins Humanoid.Health to MaxHealth, so Died never fires on a
	-- dungeon down. The chain follows ShardfallHp and a defeat / down
	-- CombatFx. A body that loads at 0 Health is not that down, and a Died
	-- from a character that is no longer ours must not latch the new life.
	hubState.localPlayer = Players.LocalPlayer
	hubState.holdDown = false

	function hubFn.aliveCharacter(): Model?
		if hubState.localPlayer == nil then
			return nil
		end
		return hubState.localPlayer.Character
	end

	function hubFn.stillHere(character: Model): boolean
		return hubFn.aliveCharacter() == character
	end

	function hubFn.readCombatHp(character: Model): number?
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

	function hubFn.markDown(character: Model)
		if not hubFn.stillHere(character) then
			return
		end
		hubState.holdDown = true
		hubState.playerAlive = false
		hubFn.stopRollChain()
	end

	function hubFn.noteCombatHp(character: Model)
		if not hubFn.stillHere(character) then
			return
		end
		local hp = hubFn.readCombatHp(character)
		if hp == nil then
			return
		end
		if hp <= 0 then
			hubFn.markDown(character)
			return
		end
		if not hubState.holdDown then
			hubState.playerAlive = true
		end
	end

	function hubFn.bindHumanoid(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			local waited = character:WaitForChild("Humanoid", 8)
			if waited ~= nil and waited:IsA("Humanoid") then
				humanoid = waited
			end
		end
		if humanoid == nil or not humanoid:IsA("Humanoid") or not hubFn.stillHere(character) then
			return
		end
		local sawPositive = humanoid.Health > 0
		humanoid.HealthChanged:Connect(function(health: number)
			if health > 0 then
				sawPositive = true
			end
		end)
		humanoid.Died:Connect(function()
			if not hubFn.stillHere(character) or not sawPositive then
				return
			end
			hubFn.markDown(character)
		end)
	end

	function hubFn.bindCombatHp(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil then
			local waited = character:WaitForChild("HumanoidRootPart", 8)
			if waited ~= nil and waited:IsA("BasePart") then
				root = waited
			end
		end
		if root == nil or not root:IsA("BasePart") or not hubFn.stillHere(character) then
			return
		end
		hubFn.noteCombatHp(character)
		root:GetAttributeChangedSignal("ShardfallHp"):Connect(function()
			hubFn.noteCombatHp(character)
		end)
	end

	function hubFn.bindLife(character: Model)
		task.spawn(hubFn.bindHumanoid, character)
		task.spawn(hubFn.bindCombatHp, character)
	end

	function hubFn.watchCombatFx()
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
			local character = hubFn.aliveCharacter()
			if character == nil then
				return
			end
			local kind = payload.kind
			if kind == "defeat" or kind == "down" then
				hubFn.markDown(character)
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
				hubFn.markDown(character)
			elseif not hubState.holdDown then
				hubState.playerAlive = true
			end
		end)
	end

	-- The roll Heartbeat is already connected. This one runs after it, so a
	-- down this frame fails the chain check before the hold clears.
	RunService.Heartbeat:Connect(function()
		if not hubState.holdDown then
			return
		end
		if hubState.rollBusy or hubState.activeReveal ~= nil or hubState.loop.phase ~= "idle" then
			hubState.playerAlive = false
			return
		end
		hubState.holdDown = false
		local character = hubFn.aliveCharacter()
		if character == nil then
			hubState.playerAlive = true
			return
		end
		local hp = hubFn.readCombatHp(character)
		hubState.playerAlive = hp == nil or hp > 0
	end)

	if hubState.localPlayer ~= nil then
		hubState.localPlayer.CharacterAdded:Connect(function(character)
			hubState.holdDown = false
			hubState.playerAlive = true
			task.spawn(hubFn.bindLife, character)
		end)
		if hubState.localPlayer.Character ~= nil then
			task.spawn(hubFn.bindLife, hubState.localPlayer.Character)
		end
		task.spawn(hubFn.watchCombatFx)
	end

	hubFn.paint()

	return {
		open = hubFn.open,
		close = hubFn.close,
		toggle = hubFn.toggle,
		handoffRoll = hubFn.handoffRoll,
		isOpen = function(): boolean
			return hubState.route.open
		end,
		current = function(): string
			return hubFn.pageFor(hubState.route)
		end,
		root = function(): string
			return hubState.route.stack[1] or hubState.route.tab
		end,
		hasModal = function(): boolean
			return #hubState.route.stack > 1
		end,
		promptClass = function(force: boolean?)
			hubFn.showClassPrompt(force == true)
		end,
		setProfile = function(nextProfile: any)
			hubState.profile = nextProfile
			hubState.serverSince = nil
			hubState.serverEpic = nil
			if type(nextProfile) == "table" and type(nextProfile.uiSettings) == "table" then
				hubState.draft = Settings.normalize(nextProfile.uiSettings)
				hubState.uiScale.Scale = hubState.draft.hud.scale
				if hubState.focusCut == true then
					hubState.autoOn = false
				else
					hubState.autoOn = RollFocus.keep(
						hubState.windowFocused,
						hubState.draft.rolls.autoConfirm == true
					)
				end
				hubFn.paintHints()
			end
			if hubState.route.open then
				hubFn.paint()
				hubFn.show(hubFn.pageFor(hubState.route))
			else
				hubFn.publishBadges()
			end
			hubFn.applyTextScale()
			hubFn.showClassPrompt(false)
		end,
	}
end

return MenuHub
