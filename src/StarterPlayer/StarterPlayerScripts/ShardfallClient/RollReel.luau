--!strict

--[[
	Sol's RNG style shard reel.

	The server already picked the shard. This screen only plays the seed it
	was given: a pooled column of names, a landing flash, and the rarity's
	reveal. Quick Roll skips the reel. Mythic still plays, and can be skipped
	after one second. Auto Roll stops when the app loses focus.

	The cutscene uses a Scriptable camera and restores it. It never anchors
	the character.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MobileShell = require(script.Parent.MobileShell)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared:WaitForChild("Audio"))
local ChestConfig = require(Shared:WaitForChild("ChestConfig"))
local Pools = require(Shared:WaitForChild("Pools"))
local ShellLayout = require(Shared:WaitForChild("ShellLayout"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local RollReel = {}

export type Hooks = {
	invoke: (string, ...any) -> any,
	remoteError: (boolean, any, string) -> string?,
	getPoolId: () -> string,
	applyResult: (any) -> (),
	setStatus: (string, string) -> (),
	setBusy: (boolean) -> (),
	onEquip: (string) -> (),
	tier: () -> string,
}

local ROW = 32
local TAP = RarityConfig.MIN_TAP

local function color3(rarity: string): Color3
	local red, green, blue = RarityConfig.color(rarity)
	red, green, blue = UiTheme.lift(red, green, blue)
	return Color3.fromRGB(red, green, blue)
end

local function worldStroke(parent: Instance)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = UiTheme.STROKE
	stroke.Color = Color3.fromRGB(16, 14, 24)
	stroke.Parent = parent
end

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function playSound(soundId: string, volume: number)
	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = volume
		local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
		if sfx ~= nil and sfx:IsA("SoundGroup") then
			sound.SoundGroup = sfx
		end
		sound.Parent = workspace
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 2)
	end)
	if not ok then
		return
	end
end

function RollReel.mount(playerGui: PlayerGui, hooks: Hooks)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShardfallRoll"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	MobileShell.mount(gui)

	local profile: any = nil
	local policy: any = nil
	local tier = "med"
	local auto = false
	local quickWanted = false
	local shakeOn = true
	local seenShake: boolean? = nil
	local focused = true
	local busy = false
	local cooling = false
	local generation = 0

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.Active = false
	flash.ZIndex = 4
	flash.Parent = gui

	local odds = Instance.new("Frame")
	odds.Name = "Odds"
	odds.AnchorPoint = Vector2.new(0, 0)
	local function placeOdds()
		local box = ShellLayout.oddsRect()
		odds.Position = UDim2.fromOffset(box.x, box.y)
		odds.Size = UDim2.fromOffset(box.w, box.h)
	end
	placeOdds()
	local oddsCamera = workspace.CurrentCamera
	if oddsCamera ~= nil then
		oddsCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeOdds)
	end
	odds.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
	odds.BackgroundTransparency = 0
	odds.BorderSizePixel = 0
	odds.Visible = false
	odds.ClipsDescendants = true
	odds.Parent = gui
	corner(odds, 10)
	local oddsLayout = Instance.new("UIListLayout")
	oddsLayout.Padding = UDim.new(0, 2)
	oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	oddsLayout.Parent = odds
	local oddsPad = Instance.new("UIPadding")
	oddsPad.PaddingTop = UDim.new(0, UiTheme.PAD)
	oddsPad.PaddingLeft = UDim.new(0, UiTheme.PAD)
	oddsPad.PaddingRight = UDim.new(0, UiTheme.PAD)
	oddsPad.PaddingBottom = UDim.new(0, UiTheme.PAD)
	oddsPad.Parent = odds

	local oddsTitle = Instance.new("TextLabel")
	oddsTitle.BackgroundTransparency = 1
	oddsTitle.Size = UDim2.new(1, 0, 0, 18)
	oddsTitle.Font = Enum.Font.BuilderSansBold
	oddsTitle.TextSize = 14
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.TextColor3 = Color3.fromRGB(236, 232, 214)
	oddsTitle.Text = "Odds"
	oddsTitle.LayoutOrder = 0
	oddsTitle.Parent = odds

	local oddsRows = {}
	for index, rarity in ipairs(Rarities.ORDER) do
		local label = Instance.new("TextLabel")
		label.Name = rarity
		label.BackgroundColor3 = Color3.fromRGB(18, 16, 28)
		label.BackgroundTransparency = 0
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Font = Enum.Font.BuilderSans
		label.TextSize = UiTheme.MIN_TEXT
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextWrapped = false
		label.TextColor3 = color3(rarity)
		label.Text = rarity
		worldStroke(label)
		label.LayoutOrder = index
		label.Visible = false
		label.Parent = odds
		oddsRows[rarity] = label
	end

	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.AnchorPoint = Vector2.new(0.5, 1)
	reel.Position = UDim2.new(0.5, 0, 1, -312)
	reel.Size = UDim2.fromOffset(280, ROW)
	reel.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	reel.BorderSizePixel = 0
	reel.ClipsDescendants = true
	reel.Visible = false
	reel.Parent = gui
	corner(reel, 8)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Names"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, RarityConfig.REEL_SLOTS * ROW)
	scroll.ScrollBarThickness = 0
	scroll.ScrollingEnabled = false
	scroll.Parent = reel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local slots = {}
	for index = 1, RarityConfig.REEL_SLOTS do
		local label = Instance.new("TextLabel")
		label.Name = "Slot" .. tostring(index)
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, ROW)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 18
		label.TextColor3 = Color3.fromRGB(220, 220, 226)
		label.Text = ""
		label.LayoutOrder = index
		label.Parent = scroll
		slots[index] = label
	end

	local function makeToggle(name: string, text: string, order: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, (order - 2) * 116, 1, -240)
		button.Size = UDim2.fromOffset(108, TAP)
		button.BackgroundColor3 = Color3.fromRGB(42, 38, 58)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(236, 232, 244)
		button.Text = text
		button.AutoButtonColor = true
		button.Visible = false
		button.Parent = gui
		corner(button, 10)
		return button
	end

	local autoButton = makeToggle("AutoRoll", "Auto", 1)
	local quickButton = makeToggle("QuickRoll", "Quick", 2)
	local shakeButton = makeToggle("Shake", "Shake", 3)

	local rollButton = Instance.new("TextButton")
	rollButton.Name = "Roll"
	rollButton.AnchorPoint = Vector2.new(0.5, 1)
	rollButton.Position = UDim2.new(0.5, 0, 1, -168)
	rollButton.Size = UDim2.fromOffset(240, TAP)
	rollButton.BackgroundColor3 = Color3.fromRGB(214, 168, 72)
	rollButton.BorderSizePixel = 0
	rollButton.Font = Enum.Font.BuilderSansBold
	rollButton.TextSize = 22
	rollButton.TextColor3 = Color3.fromRGB(28, 22, 16)
	rollButton.Text = "Roll"
	rollButton.AutoButtonColor = true
	rollButton.Visible = false
	rollButton.Parent = gui
	corner(rollButton, 12)

	local luckLabel = Instance.new("TextLabel")
	luckLabel.Name = "Luck"
	luckLabel.AnchorPoint = Vector2.new(0.5, 1)
	luckLabel.Position = UDim2.new(0.5, 0, 1, -148)
	luckLabel.Size = UDim2.fromOffset(280, 18)
	luckLabel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	luckLabel.BackgroundTransparency = 0
	luckLabel.Font = Enum.Font.BuilderSansMedium
	luckLabel.TextSize = UiTheme.MIN_TEXT
	luckLabel.TextColor3 = Color3.fromRGB(255, 220, 150)
	luckLabel.Text = ""
	luckLabel.Visible = false
	luckLabel.Parent = gui
	worldStroke(luckLabel)

	local pityLabel = Instance.new("TextLabel")
	pityLabel.Name = "Pity"
	pityLabel.AnchorPoint = Vector2.new(0.5, 1)
	pityLabel.Position = UDim2.new(0.5, 0, 1, -128)
	pityLabel.Size = UDim2.fromOffset(320, 16)
	pityLabel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	pityLabel.BackgroundTransparency = 0
	pityLabel.Font = Enum.Font.BuilderSans
	pityLabel.TextSize = UiTheme.MIN_TEXT
	pityLabel.TextColor3 = Color3.fromRGB(220, 214, 236)
	pityLabel.Text = ""
	pityLabel.Visible = false
	pityLabel.Parent = gui
	worldStroke(pityLabel)

	local card = Instance.new("Frame")
	card.Name = "Result"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(320, 210)
	card.BackgroundColor3 = Color3.fromRGB(22, 18, 32)
	card.BorderSizePixel = 0
	card.Visible = false
	card.ZIndex = 6
	card.Parent = gui
	corner(card, 12)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	local cardRarity = Instance.new("TextLabel")
	cardRarity.BackgroundTransparency = 1
	cardRarity.Position = UDim2.fromOffset(16, 14)
	cardRarity.Size = UDim2.new(1, -32, 0, 22)
	cardRarity.Font = Enum.Font.BuilderSansBold
	cardRarity.TextSize = 14
	cardRarity.TextXAlignment = Enum.TextXAlignment.Left
	cardRarity.Text = ""
	cardRarity.ZIndex = 7
	cardRarity.Parent = card

	local cardName = Instance.new("TextLabel")
	cardName.BackgroundTransparency = 1
	cardName.Position = UDim2.fromOffset(16, 40)
	cardName.Size = UDim2.new(1, -32, 0, 36)
	cardName.Font = Enum.Font.BuilderSansBold
	cardName.TextSize = 22
	cardName.TextXAlignment = Enum.TextXAlignment.Left
	cardName.TextWrapped = true
	cardName.TextColor3 = Color3.fromRGB(244, 240, 250)
	cardName.Text = ""
	cardName.ZIndex = 7
	cardName.Parent = card

	local function cardButton(name: string, text: string, x: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 132)
		button.Size = UDim2.fromOffset(136, TAP)
		button.BackgroundColor3 = Color3.fromRGB(214, 168, 72)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 18
		button.TextColor3 = Color3.fromRGB(28, 22, 16)
		button.Text = text
		button.ZIndex = 7
		button.Parent = card
		corner(button, 10)
		return button
	end

	local equipButton = cardButton("Equip", "Equip", 16)
	local keepButton = cardButton("Keep", "Keep", 164)
	keepButton.BackgroundColor3 = Color3.fromRGB(54, 48, 72)
	keepButton.TextColor3 = Color3.fromRGB(236, 232, 244)

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "Skip"
	skipButton.AnchorPoint = Vector2.new(1, 0)
	skipButton.Position = UDim2.new(1, -16, 0, 72)
	skipButton.Size = UDim2.fromOffset(120, TAP)
	skipButton.BackgroundColor3 = Color3.fromRGB(244, 244, 248)
	skipButton.BorderSizePixel = 0
	skipButton.Font = Enum.Font.BuilderSansBold
	skipButton.TextSize = 18
	skipButton.TextColor3 = Color3.fromRGB(20, 20, 24)
	skipButton.Text = "Skip"
	skipButton.Visible = false
	skipButton.ZIndex = 8
	skipButton.Parent = gui
	corner(skipButton, 10)

	local chestFrame = Instance.new("Frame")
	chestFrame.Name = "Chest"
	chestFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	chestFrame.Position = UDim2.fromScale(0.5, 0.4)
	chestFrame.Size = UDim2.fromOffset(140, 100)
	chestFrame.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
	chestFrame.BorderSizePixel = 0
	chestFrame.Visible = false
	chestFrame.ZIndex = 6
	chestFrame.Parent = gui
	corner(chestFrame, 12)
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.Size = UDim2.new(1, 0, 0, 28)
	lid.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
	lid.BorderSizePixel = 0
	lid.ZIndex = 7
	lid.Parent = chestFrame
	corner(lid, 8)

	local manyFrame = Instance.new("Frame")
	manyFrame.Name = "ChestGrid"
	manyFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	manyFrame.Position = UDim2.fromScale(0.5, 0.55)
	manyFrame.Size = UDim2.fromOffset(420, 220)
	manyFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	manyFrame.BackgroundTransparency = 0.08
	manyFrame.BorderSizePixel = 0
	manyFrame.Visible = false
	manyFrame.ZIndex = 7
	manyFrame.Parent = gui
	corner(manyFrame, 10)
	local manyScroll = Instance.new("ScrollingFrame")
	manyScroll.Name = "Cells"
	manyScroll.BackgroundTransparency = 1
	manyScroll.BorderSizePixel = 0
	manyScroll.Size = UDim2.fromScale(1, 1)
	manyScroll.CanvasSize = UDim2.fromOffset(0, 0)
	manyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	manyScroll.ScrollBarThickness = 4
	manyScroll.Parent = manyFrame
	local manyPad = Instance.new("UIPadding")
	manyPad.PaddingTop = UDim.new(0, 8)
	manyPad.PaddingLeft = UDim.new(0, 8)
	manyPad.PaddingRight = UDim.new(0, 8)
	manyPad.Parent = manyScroll
	local manyGrid = Instance.new("UIGridLayout")
	manyGrid.CellSize = UDim2.fromOffset(128, 44)
	manyGrid.CellPadding = UDim2.fromOffset(6, 6)
	manyGrid.SortOrder = Enum.SortOrder.LayoutOrder
	manyGrid.Parent = manyScroll

	local choice = Instance.new("Frame")
	choice.Name = "MythicChoice"
	choice.AnchorPoint = Vector2.new(0.5, 0.5)
	choice.Position = UDim2.fromScale(0.5, 0.58)
	choice.Size = UDim2.fromOffset(320, 230)
	choice.BackgroundTransparency = 1
	choice.Visible = false
	choice.ZIndex = 9
	choice.Parent = gui
	local choiceList = Instance.new("UIListLayout")
	choiceList.Padding = UDim.new(0, 8)
	choiceList.SortOrder = Enum.SortOrder.LayoutOrder
	choiceList.Parent = choice
	local choiceButtons = {}
	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Card" .. tostring(index)
		button.Size = UDim2.new(1, 0, 0, TAP)
		button.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(240, 236, 248)
		button.Text = ""
		button.AutoButtonColor = true
		button.LayoutOrder = index
		button.ZIndex = 9
		button.Parent = choice
		corner(button, 10)
		choiceButtons[index] = button
	end
	local choosing = false
	local shownSeed: number? = nil

	local skipToken = { skipped = false }

	local function quickDenial(): string?
		local ready = type(policy) == "table" and policy.ready == true and policy.paidRolls == true
		local entitled = RarityConfig.quickEntitled(profile, os.time())
		return RarityConfig.quickDenial(ready, RarityConfig.PAID_LUCK_ENABLED, entitled)
	end

	local function paint()
		local rolls = if type(profile) == "table" then profile.shardRolls or 0 else 0
		local sinceEpic = if type(profile) == "table" then profile.sinceEpic or 0 else 0
		local sinceLegendary = if type(profile) == "table" then profile.sinceLegendary or 0 else 0
		luckLabel.Text = string.format("Rolls %d   %s", rolls, RarityConfig.bonusLabel(rolls))
		pityLabel.Text = RarityConfig.pityLine(sinceEpic, sinceLegendary)
		if type(profile) == "table" then
			local saved = profile.shake ~= false
			if seenShake ~= saved then
				seenShake = saved
				shakeOn = saved
			end
		end
		local denied = quickDenial()
		if denied ~= nil then
			quickWanted = false
		end
		autoButton.Text = if auto then "Auto On" else "Auto"
		autoButton.BackgroundColor3 = if auto
			then Color3.fromRGB(214, 168, 72)
			else Color3.fromRGB(42, 38, 58)
		autoButton.TextColor3 = if auto
			then Color3.fromRGB(28, 22, 16)
			else Color3.fromRGB(236, 232, 244)
		quickButton.Text = if quickWanted then "Quick On" else "Quick"
		quickButton.BackgroundColor3 = if denied ~= nil
			then Color3.fromRGB(36, 34, 44)
			elseif quickWanted then Color3.fromRGB(96, 168, 214)
			else Color3.fromRGB(42, 38, 58)
		shakeButton.Text = if shakeOn then "Shake On" else "Shake"
		shakeButton.BackgroundColor3 = if shakeOn
			then Color3.fromRGB(168, 112, 196)
			else Color3.fromRGB(42, 38, 58)
		local ready = not busy and not cooling
		rollButton.Active = ready
		rollButton.AutoButtonColor = ready
		rollButton.Text = if busy then "Rolling..." elseif cooling then "..." else "Roll"
		rollButton.BackgroundColor3 = if ready
			then Color3.fromRGB(214, 168, 72)
			else Color3.fromRGB(92, 78, 48)

		local pool = Pools.get(hooks.getPoolId())
		local luck = RarityConfig.luckFromProfile(profile)
		local disclosed = if pool ~= nil then RarityConfig.disclose(pool, luck) else nil
		oddsTitle.Text = if disclosed ~= nil
			then string.format("Odds  x%.2f", disclosed.luck)
			else "Odds"
		for _, label in pairs(oddsRows) do
			label.Visible = false
		end
		if disclosed ~= nil then
			for _, row in ipairs(disclosed.rarities) do
				local label = oddsRows[row.rarity]
				if label ~= nil then
					label.Visible = true
					label.Text = RarityConfig.formatLine(row)
				end
			end
		end
	end

	local function windowOpen(): boolean
		if not focused then
			return false
		end
		local ok, value = pcall(function()
			return UserInputService.WindowFocused
		end)
		if ok and value == false then
			return false
		end
		return true
	end

	local function restoreCamera(
		camera: Camera,
		previousType: Enum.CameraType,
		previousCFrame: CFrame,
		previousSubject: Instance?
	)
		camera.CameraType = previousType
		camera.CFrame = previousCFrame
		if previousSubject ~= nil then
			camera.CameraSubject = previousSubject
		end
	end

	local function revealPart(rarity: string, at: CFrame): Part
		local part = Instance.new("Part")
		part.Name = "RollReveal"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Size = Vector3.new(2.2, 2.2, 2.2)
		part.Material = Enum.Material.Glass
		part.Color = color3(rarity)
		part.CFrame = at
		local cap = RarityConfig.particleCap(tier, rarity)
		if cap > 0 then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = cap
			emitter.Lifetime = NumberRange.new(0.35, 0.8)
			emitter.Speed = NumberRange.new(1, 5)
			emitter.SpreadAngle = Vector2.new(40, 40)
			emitter.LightEmission = 0.4
			emitter.Color = ColorSequence.new(color3(rarity))
			emitter.Parent = part
		end
		part.Parent = workspace
		return part
	end

	local function shake(seconds: number)
		if not shakeOn or seconds <= 0 then
			return
		end
		local character = player.Character
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid == nil then
			return
		end
		local started = os.clock()
		while os.clock() - started < seconds do
			if skipToken.skipped then
				break
			end
			humanoid.CameraOffset =
				Vector3.new((math.random() - 0.5) * 0.45, (math.random() - 0.5) * 0.3, 0)
			RunService.RenderStepped:Wait()
		end
		humanoid.CameraOffset = Vector3.new()
	end

	local function spinShard(rarity: string, seconds: number, whiteout: boolean)
		local camera = workspace.CurrentCamera
		if camera == nil then
			task.wait(seconds)
			return
		end
		local previousType = camera.CameraType
		local previousCFrame = camera.CFrame
		local previousSubject = camera.CameraSubject
		camera.CameraType = Enum.CameraType.Scriptable
		local part = revealPart(rarity, previousCFrame * CFrame.new(0, 0, -6))
		local started = os.clock()
		while os.clock() - started < seconds do
			if skipToken.skipped then
				break
			end
			local elapsed = os.clock() - started
			camera.CFrame = previousCFrame
			part.CFrame = previousCFrame * CFrame.new(0, 0, -6) * CFrame.Angles(0, elapsed * 4, 0)
			if whiteout and elapsed < 0.18 then
				flash.BackgroundColor3 = Color3.new(1, 1, 1)
				flash.BackgroundTransparency = 0.15
			end
			RunService.RenderStepped:Wait()
		end
		part:Destroy()
		flash.BackgroundTransparency = 1
		restoreCamera(camera, previousType, previousCFrame, previousSubject)
	end

	local function showSkipAfter(seconds: number, token: number)
		task.delay(seconds, function()
			if token == generation and not skipToken.skipped then
				skipButton.Visible = true
			end
		end)
	end

	local function spinReel(names: { any }, seconds: number)
		reel.Visible = true
		scroll.CanvasPosition = Vector2.zero
		for index, slot in ipairs(slots) do
			local row = names[index]
			if row == nil then
				slot.Text = ""
			else
				slot.Text = tostring(row.name)
				slot.TextColor3 = color3(tostring(row.rarity))
			end
		end
		local goal = Vector2.new(0, math.max(0, #names - 1) * ROW)
		local tween = TweenService:Create(
			scroll,
			TweenInfo.new(seconds, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			{ CanvasPosition = goal }
		)
		tween:Play()
		tween.Completed:Wait()
		scroll.CanvasPosition = goal
	end

	local function flashColor(rarity: string, seconds: number)
		flash.BackgroundColor3 = color3(rarity)
		flash.BackgroundTransparency = 0.45
		local tween = TweenService:Create(
			flash,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
	end

	local function showCard(result: any, autoDismiss: boolean)
		local item = result.item
		if type(item) ~= "table" then
			return
		end
		generation += 1
		local token = generation
		local rarity = tostring(item.rarity)
		cardRarity.Text = string.upper(rarity)
		cardRarity.TextColor3 = color3(rarity)
		cardName.Text = tostring(item.name)
		cardStroke.Color = color3(rarity)
		card.Visible = true
		equipButton:SetAttribute("Uid", item.uid)
		if autoDismiss then
			task.delay(RarityConfig.AUTO_DISMISS, function()
				if token == generation then
					card.Visible = false
				end
			end)
		end
	end

	local function play(result: any)
		local item = result.item
		local rarity = if type(item) == "table"
			then tostring(item.rarity)
			else tostring(result.rarity)
		local name = if type(item) == "table" then tostring(item.name) else "a shard"
		local quick = result.quick == true
		local plan = RarityConfig.reveal(rarity, quick)
		print(string.format("[Roll] landed %s %s", rarity, name))
		skipToken = { skipped = false }
		skipButton.Visible = false
		chestFrame.Visible = false
		manyFrame.Visible = false
		choice.Visible = false
		generation += 1
		local token = generation
		if plan.bounce > 0 then
			playSound("rbxasset://sounds/switch.wav", 0.35)
		end
		if plan.toastOnly then
			hooks.setStatus(string.format("%s (%s)", name, rarity), "ok")
			return
		end
		if plan.skipAfter > 0 then
			showSkipAfter(plan.skipAfter, token)
		end
		local pool = Pools.get(hooks.getPoolId())
		if plan.reel and pool ~= nil then
			local names = RarityConfig.reel(
				tonumber(result.fillerSeed) or 1,
				pool,
				tonumber(result.luck) or 1,
				name,
				rarity
			)
			spinReel(names, plan.reelSeconds)
		elseif plan.stall and pool ~= nil then
			local names = RarityConfig.reel(
				tonumber(result.fillerSeed) or 1,
				pool,
				tonumber(result.luck) or 1,
				name,
				rarity
			)
			spinReel(names, 0.8)
			local stalled = os.clock()
			while os.clock() - stalled < 0.7 and not skipToken.skipped do
				RunService.RenderStepped:Wait()
			end
		end
		local ladder = Audio.cue(rarity)
		if ladder ~= nil then
			playSound(ladder, 0.6)
		elseif rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
			playSound("rbxasset://sounds/electronicpingshort.wav", 0.5)
		end
		flashColor(rarity, plan.landSeconds)
		if plan.shake > 0 then
			shake(plan.shake)
		end
		if plan.cutscene > 0 then
			spinShard(rarity, plan.cutscene, plan.stall == true)
		elseif plan.quickPop then
			task.wait(RarityConfig.QUICK_POP)
		end
		reel.Visible = false
		skipButton.Visible = false
		showCard(result, auto)
		hooks.setStatus("Received " .. name .. ".", "ok")
	end

	local function request(paid: boolean)
		if busy or cooling then
			return
		end
		if not windowOpen() then
			auto = false
			paint()
			return
		end
		busy = true
		hooks.setBusy(true)
		paint()
		hooks.setStatus("Rolling...", "info")
		task.spawn(function()
			local skip = quickWanted and quickDenial() == nil
			local ok, result = pcall(function()
				local remoteName = if paid then "RollPaid" else "RollShard"
				return hooks.invoke(remoteName, hooks.getPoolId(), skip)
			end)
			local message = hooks.remoteError(ok, result, "Roll failed.")
			if message ~= nil then
				hooks.setStatus(message, "error")
				busy = false
				auto = false
				hooks.setBusy(false)
				paint()
				return
			end
			hooks.applyResult(result)
			local played, playErr = pcall(play, result)
			if not played then
				warn("[Roll] " .. tostring(playErr))
			end
			busy = false
			hooks.setBusy(false)
			local wasQuick = type(result) == "table" and (result :: any).quick == true
			cooling = true
			paint()
			task.wait(RarityConfig.cooldown(wasQuick))
			cooling = false
			paint()
			if auto and windowOpen() then
				task.spawn(request, paid)
			elseif not windowOpen() then
				auto = false
				paint()
			end
		end)
	end

	rollButton.MouseButton1Click:Connect(function()
		request(false)
	end)
	autoButton.MouseButton1Click:Connect(function()
		auto = not auto
		if auto and not busy and not cooling then
			request(false)
		end
		paint()
	end)
	quickButton.MouseButton1Click:Connect(function()
		local denied = quickDenial()
		if denied ~= nil then
			quickWanted = false
			hooks.setStatus(denied, "error")
			paint()
			return
		end
		quickWanted = not quickWanted
		paint()
	end)
	shakeButton.MouseButton1Click:Connect(function()
		shakeOn = not shakeOn
		paint()
		task.spawn(function()
			pcall(function()
				hooks.invoke("SetShake", shakeOn)
			end)
		end)
	end)
	skipButton.MouseButton1Click:Connect(function()
		skipToken.skipped = true
		skipButton.Visible = false
	end)
	equipButton.MouseButton1Click:Connect(function()
		local uid = equipButton:GetAttribute("Uid")
		card.Visible = false
		generation += 1
		if type(uid) == "string" and uid ~= "" then
			hooks.onEquip(uid)
		end
	end)
	keepButton.MouseButton1Click:Connect(function()
		card.Visible = false
		generation += 1
	end)

	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
		auto = false
		paint()
	end)
	UserInputService.WindowFocused:Connect(function()
		focused = true
	end)

	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes == nil then
			remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
		end
		if remotes == nil then
			return
		end
		local remote = remotes:WaitForChild("RollAnnounce", 15)
		if remote ~= nil and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(function(payload)
				if type(payload) == "table" and type(payload.text) == "string" then
					hooks.setStatus(payload.text, "ok")
				end
			end)
		end
	end)

	local function waitSkippable(seconds: number)
		local started = os.clock()
		while os.clock() - started < seconds do
			if skipToken.skipped then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end

	local function clearGrid()
		for _, child in ipairs(manyScroll:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
	end

	local function fillGrid(results: { any })
		clearGrid()
		for index, row in ipairs(results) do
			local cell = Instance.new("TextLabel")
			cell.BackgroundColor3 = Color3.fromRGB(32, 28, 46)
			cell.BorderSizePixel = 0
			cell.Font = Enum.Font.BuilderSansBold
			cell.TextSize = 13
			cell.TextWrapped = true
			cell.TextColor3 = color3(tostring(row.rarity))
			cell.Text = tostring(row.name)
			cell.LayoutOrder = index
			cell.Parent = manyScroll
			corner(cell, 6)
		end
		manyFrame.Visible = true
	end

	local function describeDrop(row: any)
		local name = tostring(row.name or "Shard")
		if row.kind == "item" then
			showCard({
				item = {
					rarity = tostring(row.rarity),
					name = name,
					uid = row.uid,
				},
			}, false)
			hooks.setStatus("Received " .. name .. ".", "ok")
			return
		end
		if row.kind == "star" then
			hooks.setStatus(
				string.format("%s is now %s stars.", name, tostring(row.stars or "")),
				"ok"
			)
			return
		end
		local dust = tonumber(row.dust) or 0
		hooks.setStatus(string.format("Duplicate %s became %d Shard Dust.", name, dust), "ok")
	end

	local function playOne(chestTier: string, row: any, luck: number)
		local rarity = tostring(row.rarity or "Common")
		local name = tostring(row.name or "Shard")
		chestFrame.BackgroundColor3 = color3(chestTier)
		lid.BackgroundColor3 = color3(chestTier)
		chestFrame.Visible = true
		chestFrame.Position = UDim2.fromScale(0.5, 0.5)
		lid.Position = UDim2.fromOffset(0, 0)
		local bounce = TweenService:Create(
			chestFrame,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.38) }
		)
		bounce:Play()
		bounce.Completed:Wait()
		local pop = TweenService:Create(lid, TweenInfo.new(0.18), {
			Position = UDim2.fromOffset(0, -16),
		})
		pop:Play()
		playSound("rbxasset://sounds/switch.wav", 0.4)
		if
			chestTier == "Rare"
			or chestTier == "Epic"
			or chestTier == "Legendary"
			or chestTier == "Mythic"
		then
			flashColor(chestTier, 0.35)
		end
		if chestTier == "Rare" and not skipToken.skipped then
			shake(0.3)
		end
		if chestTier == "Epic" then
			playSound("rbxasset://sounds/switch.wav", 0.55)
		end
		if
			rarity == "Legendary"
			or rarity == "Mythic"
			or chestTier == "Legendary"
			or chestTier == "Mythic"
		then
			showSkipAfter(1, generation)
		end
		local reelSeconds = ChestConfig.REEL_SECONDS[chestTier] or 0
		local pool = Pools.get(hooks.getPoolId())
		if reelSeconds > 0 and pool ~= nil and not skipToken.skipped then
			local names = RarityConfig.reel(tonumber(row.fillerSeed) or 1, pool, luck, name, rarity)
			spinReel(names, reelSeconds)
		end
		if chestTier == "Epic" and not skipToken.skipped then
			spinShard(rarity, 0.45, false)
		end
		if (chestTier == "Legendary" or rarity == "Legendary") and not skipToken.skipped then
			flash.BackgroundColor3 = Color3.new(0, 0, 0)
			flash.BackgroundTransparency = 0.4
			spinShard(rarity, 2, false)
			flash.BackgroundTransparency = 1
		end
		if (chestTier == "Mythic" or rarity == "Mythic") and not skipToken.skipped then
			flashColor("Mythic", 0.4)
			spinShard(rarity, 1.2, true)
		end
		reel.Visible = false
		chestFrame.Visible = false
		lid.Position = UDim2.fromOffset(0, 0)
		skipButton.Visible = false
		describeDrop(row)
	end

	local function finishChest()
		busy = false
		choosing = false
		hooks.setBusy(false)
		gui.DisplayOrder = 40
		chestFrame.Visible = false
		manyFrame.Visible = false
		reel.Visible = false
		skipButton.Visible = false
		lid.Position = UDim2.fromOffset(0, 0)
	end

	local function playChest(payload: any)
		if type(payload) ~= "table" then
			return
		end
		local pending = payload.pending
		local seed = if type(pending) == "table" then tonumber(pending.fillerSeed) else nil
		if busy then
			if choice.Visible and seed ~= nil and seed == shownSeed then
				gui.DisplayOrder = 40
			else
				hooks.setStatus("A chest is already opening.", "info")
			end
			return
		end
		busy = true
		hooks.setBusy(true)
		gui.DisplayOrder = 40
		generation += 1
		skipToken = { skipped = false }
		skipButton.Visible = false
		card.Visible = false
		choice.Visible = false
		local played, playErr = pcall(function()
			if type(pending) == "table" then
				shownSeed = seed
				chestFrame.BackgroundColor3 = color3("Mythic")
				lid.BackgroundColor3 = color3("Mythic")
				chestFrame.Visible = true
				flashColor("Mythic", 0.5)
				showSkipAfter(1, generation)
				waitSkippable(ChestConfig.OPEN_SECONDS.Mythic or 4)
				chestFrame.Visible = false
				skipButton.Visible = false
				local options = pending.options
				for index, button in ipairs(choiceButtons) do
					local option = if type(options) == "table" then options[index] else nil
					if type(option) == "table" then
						button.Text = tostring(option.name)
						button.TextColor3 = color3(tostring(option.rarity))
						button.Visible = true
						button:SetAttribute("Index", index)
					else
						button.Visible = false
					end
				end
				choice.Visible = true
				return
			end
			local chestTier = tostring(payload.tier or "Common")
			local results = payload.results
			if type(results) ~= "table" then
				results = {}
			end
			local luck = tonumber(payload.luck) or 1
			local best = tonumber(payload.bestIndex) or 1
			if best < 1 or best > #results then
				best = 1
			end
			if #results > 1 then
				fillGrid(results)
				local bestRow = results[best]
				local rarity = if type(bestRow) == "table"
					then tostring(bestRow.rarity)
					else "Common"
				local full = type(bestRow) == "table"
					and ChestConfig.playFullReveal(chestTier, rarity, true)
				if not full then
					task.wait(0.25)
					manyFrame.Visible = false
					hooks.setStatus(string.format("Opened %d chests.", #results), "ok")
					return
				end
				playOne(chestTier, bestRow, luck)
				manyFrame.Visible = false
				return
			end
			local row = results[1]
			if type(row) == "table" then
				playOne(chestTier, row, luck)
			else
				hooks.setStatus("Opened a chest.", "ok")
			end
		end)
		if not played then
			warn("[Chest] " .. tostring(playErr))
			choice.Visible = false
			shownSeed = nil
			finishChest()
			return
		end
		if type(pending) == "table" and choice.Visible then
			return
		end
		finishChest()
	end

	for _, button in ipairs(choiceButtons) do
		button.MouseButton1Click:Connect(function()
			if not choice.Visible or choosing then
				return
			end
			local index = button:GetAttribute("Index")
			if type(index) ~= "number" then
				return
			end
			choosing = true
			task.spawn(function()
				local ok, result = pcall(function()
					return hooks.invoke("ChooseChest", index)
				end)
				local message = hooks.remoteError(ok, result, "Could not choose that card.")
				choosing = false
				if message ~= nil then
					hooks.setStatus(message, "error")
					return
				end
				hooks.applyResult(result)
				choice.Visible = false
				shownSeed = nil
				local chest = if type(result) == "table" then (result :: any).chest else nil
				if
					type(chest) == "table"
					and type(chest.results) == "table"
					and chest.results[1] ~= nil
				then
					local granted, grantErr =
						pcall(playOne, "Mythic", chest.results[1], tonumber(chest.luck) or 1)
					if not granted then
						warn("[Chest] " .. tostring(grantErr))
					end
				end
				finishChest()
			end)
		end)
	end

	print(string.format("[Roll] reel ready slots=%d", RarityConfig.REEL_SLOTS))
	paint()

	local function setOpen(open: boolean)
		if not open then
			auto = false
		end
		odds.Visible = open
		autoButton.Visible = open
		quickButton.Visible = open
		shakeButton.Visible = open
		rollButton.Visible = open
		luckLabel.Visible = open
		pityLabel.Visible = open
		if open then
			paint()
		end
	end
	setOpen(false)

	return {
		request = request,
		playChest = playChest,
		setOpen = setOpen,
		setProfile = function(nextProfile: any)
			profile = nextProfile
			paint()
		end,
		setPolicy = function(nextPolicy: any)
			policy = nextPolicy
			paint()
		end,
		setTier = function(nextTier: string)
			tier = nextTier
		end,
	}
end

return RollReel
