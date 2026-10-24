--!strict

--[[
	Bottom action bar. Eight square slots on keys 1-8.

	A click, a tap, or the key asks the server to use that slot. Shift
	dodges, and ButtonY dodges on a gamepad. ButtonR1 light-attacks
	while the menu is closed and still changes tabs while it is open.
	F is the interact prompt
	and only shows while a prompt is up. On a phone, Heavy sits above
	Dodge and plays the heavy slash. The Dodge chip shows Y while a
	gamepad was the last input.
	On a gamepad the D-pad uses slots 1-4, and holding LB uses slots 5-8.
	The corner shows that glyph while a gamepad was the last input, and
	the key number otherwise. Both paths call useSlot.

	The old cluster used the settings gear, the help-tab question mark, and
	an empty icon, and it dropped the key when the engine had already
	handled it. These slots bind above that and show the skill glyph.

	A Codex snapshot on CombatFx glows skill slots and pulses Dodge.
	The server named that moment. This bar does not send seen. The hint
	is CodexCues.HINT ("Dodge!") and nothing after it.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionDrag = require(Shared:WaitForChild("ActionDrag"))
local ActionSlots = require(Shared:WaitForChild("ActionSlots"))
local CodexCues = require(Shared:WaitForChild("CodexCues"))
local CombatCluster = require(Shared:WaitForChild("CombatCluster"))
local HeavyChip = require(Shared:WaitForChild("HeavyChip"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))
local PadLight = require(Shared:WaitForChild("PadLight"))
local SkillTip = require(Shared:WaitForChild("SkillTip"))
local CooldownNudge = require(Shared:WaitForChild("CooldownNudge"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local ActionBar = {}

export type Callbacks = {
	invoke: (string, ...any) -> any,
	menuOpen: () -> boolean,
	onDodge: () -> (),
	onDodgeChip: (() -> ())?,
	onLight: () -> (),
	onHeavy: () -> (),
	onSkill: () -> (),
	onToast: (string) -> (),
	onResult: (any) -> (),
	onRoll: (() -> ())?,
	mobile: () -> boolean,
}

local function rgb(row: { number }): Color3
	return Color3.fromRGB(row[1], row[2], row[3])
end

local function theme(name: string): Color3
	local row = UiTheme.RGB[name]
	return Color3.fromRGB(row[1], row[2], row[3])
end

-- Seconds a slot press waits on UseActionSlot before it says so.
local INVOKE_WAIT = 4
-- Shown when a slot key or click lands while the hub menu is open.
ActionBar.MENU_OPEN_TEXT = "Close the menu to use skills."
local MENU_OPEN_TEXT = ActionBar.MENU_OPEN_TEXT

function ActionBar.start(playerGui: PlayerGui, callbacks: Callbacks)
	local profile: any = nil
	local override: ActionSlots.Bar? = nil
	local classSeen = ""
	local readyAt: { [number]: number } = {}
	local readyTotal: { [number]: number } = {}
	local flashUntil: { [number]: number } = {}
	local dragFrom: number? = nil
	local dragMoved = false
	local dragOrigin = Vector2.zero
	local holdToken = 0
	local heldTip = false
	local promptsShown = 0
	local skillsCue = false
	local dodgeCue = false
	local picked = 1
	local noticed: { [string]: boolean } = {}
	local payloadMoved = false
	local payloadOrigin = Vector2.zero
	local showTip: (number) -> ()
	local hideTip: () -> ()
	-- The slot the card was painted for, so a stale card never sits on
	-- another slot (Kevin: slot 1 showed Bubble Ward, then Tidal Bolt).
	local tipIndex: number? = nil

	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallActions"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 60
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Bar"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0, 0)
	root.Parent = screen

	local contrast = ActionSlots.face()
	local function applyFace(gui: GuiObject, stroke: UIStroke)
		gui.BackgroundColor3 = Color3.fromRGB(contrast.fill[1], contrast.fill[2], contrast.fill[3])
		stroke.Color = Color3.fromRGB(contrast.stroke[1], contrast.stroke[2], contrast.stroke[3])
		stroke.Thickness = contrast.thickness
	end

	local lock = Instance.new("TextButton")
	lock.Name = "Lock"
	lock.Size = UDim2.fromOffset(72, 28)
	lock.Position = UDim2.fromOffset(0, 0)
	lock.BackgroundColor3 = theme("panel")
	lock.BackgroundTransparency = 0
	lock.BorderSizePixel = 0
	lock.Font = Enum.Font.BuilderSansBold
	lock.TextSize = UiTheme.MIN_TEXT
	lock.TextColor3 = theme("text")
	lock.Text = "Lock"
	lock.AutoButtonColor = false
	lock.Parent = root
	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 8)
	lockCorner.Parent = lock
	local lockStroke = Instance.new("UIStroke")
	lockStroke.Thickness = UiTheme.STROKE
	lockStroke.Color = theme("accent")
	lockStroke.Parent = lock
	applyFace(lock, lockStroke)

	local rollKey = Instance.new("TextButton")
	rollKey.Name = "RollKey"
	rollKey.Size = UDim2.fromOffset(64, 28)
	rollKey.Position = UDim2.fromOffset(72, 0)
	rollKey.BackgroundTransparency = 0
	rollKey.BorderSizePixel = 0
	rollKey.Font = Enum.Font.BuilderSansBold
	rollKey.TextSize = UiTheme.MIN_TEXT
	rollKey.TextColor3 = theme("text")
	rollKey.Text = "T"
	rollKey.AutoButtonColor = false
	rollKey.Parent = root
	local rollCorner = Instance.new("UICorner")
	rollCorner.CornerRadius = UDim.new(0, 8)
	rollCorner.Parent = rollKey
	local rollStroke = Instance.new("UIStroke")
	rollStroke.Parent = rollKey
	applyFace(rollKey, rollStroke)
	-- Purple hex tabs to match the slots.
	local function hexTab(gui: TextButton, stroke: UIStroke)
		gui.BackgroundColor3 = Color3.fromRGB(24, 20, 58)
		gui.TextColor3 = Color3.fromRGB(150, 235, 255)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(150, 92, 255)
		stroke.Thickness = 2
	end
	hexTab(lock, lockStroke)
	hexTab(rollKey, rollStroke)
	-- [Ghost] Oct 24: one strip, flush on the slot row, instead of two
	-- loose buttons. The tabs become see-through segments of the strip.
	local tabStrip = Instance.new("Frame")
	tabStrip.Name = "TabStrip"
	tabStrip.BackgroundColor3 = Color3.fromRGB(24, 20, 58)
	tabStrip.BackgroundTransparency = 0.05
	tabStrip.BorderSizePixel = 0
	tabStrip.ZIndex = 0
	tabStrip.Parent = root
	local stripCorner = Instance.new("UICorner")
	stripCorner.CornerRadius = UDim.new(0, 8)
	stripCorner.Parent = tabStrip
	local stripStroke = Instance.new("UIStroke")
	stripStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stripStroke.Color = Color3.fromRGB(150, 92, 255)
	stripStroke.Thickness = 2
	stripStroke.Parent = tabStrip
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.Position = UDim2.new(0.5, 0, 0, 4)
	divider.Size = UDim2.new(0, 1, 1, -8)
	divider.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	divider.BorderSizePixel = 0
	divider.Parent = tabStrip
	for _, tabButton in ipairs({ lock, rollKey }) do
		tabButton.BackgroundTransparency = 1
		tabButton.ZIndex = 2
		local edge = tabButton:FindFirstChildOfClass("UIStroke")
		if edge ~= nil then
			edge.Enabled = false
		end
	end
	local tabTip = Instance.new("TextLabel")
	tabTip.Name = "TabTip"
	tabTip.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	tabTip.BackgroundTransparency = 0.08
	tabTip.BorderSizePixel = 0
	tabTip.Font = Enum.Font.BuilderSans
	tabTip.TextSize = UiTheme.MIN_TEXT
	tabTip.TextColor3 = theme("text")
	tabTip.TextXAlignment = Enum.TextXAlignment.Left
	tabTip.Text = ""
	tabTip.Visible = false
	tabTip.ZIndex = 9
	tabTip.Parent = root
	local tabTipPad = Instance.new("UIPadding")
	tabTipPad.PaddingLeft = UDim.new(0, 6)
	tabTipPad.PaddingRight = UDim.new(0, 6)
	tabTipPad.Parent = tabTip
	local tabTipCorner = Instance.new("UICorner")
	tabTipCorner.CornerRadius = UDim.new(0, 6)
	tabTipCorner.Parent = tabTip
	local TAB_TIPS = {
		Lock = "Lock the bar so drags keep your slots",
		RollKey = "Roll for gear (T)",
	}
	for _, tabButton in ipairs({ lock, rollKey }) do
		tabButton.MouseEnter:Connect(function()
			tabTip.Text = TAB_TIPS[tabButton.Name] or ""
			tabTip.Visible = tabTip.Text ~= ""
		end)
		tabButton.MouseLeave:Connect(function()
			tabTip.Visible = false
		end)
	end
	rollKey.Activated:Connect(function()
		local open = callbacks.onRoll
		if open ~= nil then
			open()
		end
	end)

	local grid = Instance.new("Frame")
	grid.Name = "Slots"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, ActionSlots.TAB_BAND)
	grid.Parent = root
	local layout = Instance.new("UIGridLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.StartCorner = Enum.StartCorner.TopLeft
	layout.Parent = grid

	local buttons = {}
	for index = 1, ActionSlots.COUNT do
		local button = Instance.new("TextButton")
		button.Name = "Slot" .. tostring(index)
		button.BackgroundColor3 =
			Color3.fromRGB(contrast.fill[1], contrast.fill[2], contrast.fill[3])
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.ClipsDescendants = true
		button.LayoutOrder = index
		button.Parent = grid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Border"
		stroke.Thickness = contrast.thickness
		stroke.Color = Color3.fromRGB(contrast.stroke[1], contrast.stroke[2], contrast.stroke[3])
		stroke.Parent = button
		-- Purple hex skin: the painted frame carries the fill and border.
		local hexArt = IconAssets.HexSlot
		if hexArt ~= nil then
			button.BackgroundTransparency = 1
			stroke.Enabled = false
			local hexFrame = Instance.new("ImageLabel")
			hexFrame.Name = "HexFrame"
			hexFrame.BackgroundTransparency = 1
			hexFrame.Size = UDim2.fromScale(1, 1)
			hexFrame.ScaleType = Enum.ScaleType.Stretch
			hexFrame.Image = hexArt
			hexFrame.ZIndex = 1
			hexFrame.Parent = button
			local hexGlow = Instance.new("ImageLabel")
			hexGlow.Name = "HexGlow"
			hexGlow.BackgroundTransparency = 1
			hexGlow.Size = UDim2.fromScale(1, 1)
			hexGlow.ScaleType = Enum.ScaleType.Stretch
			hexGlow.Image = IconAssets.HexSlotGlow or hexArt
			hexGlow.Visible = false
			hexGlow.ZIndex = 1
			hexGlow.Parent = button
		end
		local skillGlow = Instance.new("UIStroke")
		skillGlow.Name = "SkillGlow"
		skillGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		skillGlow.Thickness = 3
		skillGlow.Color = Color3.fromRGB(
			CodexCues.COLOR.skill[1],
			CodexCues.COLOR.skill[2],
			CodexCues.COLOR.skill[3]
		)
		skillGlow.Transparency = 0.15
		skillGlow.Enabled = false
		if IconAssets.HexSlot ~= nil then
			-- The hex glow frame draws the cue; the stroke only keeps its timing.
			skillGlow.Thickness = 0
		end
		skillGlow.Parent = button
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 0.62)
		glyph.Position = UDim2.fromScale(0, 0.26)
		glyph.Font = Enum.Font.BuilderSansBold
		glyph.TextSize = 22
		glyph.TextColor3 = theme("text")
		glyph.Text = ""
		glyph.ZIndex = 2
		local glyphStroke = Instance.new("UIStroke")
		glyphStroke.Thickness = 1.5
		glyphStroke.Color = Color3.fromRGB(10, 6, 28)
		glyphStroke.Parent = glyph
		glyph.Parent = button
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.54)
		art.Size = UDim2.fromScale(0.62, 0.62)
		art.ScaleType = Enum.ScaleType.Fit
		art.Visible = false
		art.ZIndex = 2
		art.Parent = button
		local bind = Instance.new("TextLabel")
		bind.Name = "Bind"
		-- Cyan number badge, top centre.
		bind.AnchorPoint = Vector2.new(0.5, 0)
		bind.Position = UDim2.new(0.5, 0, 0, 3)
		bind.Size = UDim2.fromOffset(16, 16)
		bind.BackgroundTransparency = 0
		bind.BackgroundColor3 = Color3.fromRGB(64, 206, 255)
		bind.BorderSizePixel = 0
		bind.Font = Enum.Font.BuilderSansBold
		bind.TextSize = 11
		bind.TextXAlignment = Enum.TextXAlignment.Center
		bind.TextColor3 = Color3.fromRGB(10, 14, 36)
		bind.Text = ActionSlots.keyLabel(index)
		bind.ZIndex = 6
		bind.Parent = button
		local bindCorner = Instance.new("UICorner")
		bindCorner.CornerRadius = UDim.new(1, 0)
		bindCorner.Parent = bind
		local bindStroke = Instance.new("UIStroke")
		bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bindStroke.Thickness = 1
		bindStroke.Color = Color3.fromRGB(190, 240, 255)
		bindStroke.Parent = bind
		local pad = Instance.new("TextLabel")
		pad.Name = "PadGlyph"
		pad.AnchorPoint = Vector2.new(1, 1)
		pad.Position = UDim2.new(1, -2, 1, -1)
		pad.Size = UDim2.fromOffset(40, 14)
		pad.BackgroundTransparency = 1
		pad.Font = Enum.Font.BuilderSansBold
		pad.TextSize = 11
		pad.TextXAlignment = Enum.TextXAlignment.Right
		pad.TextColor3 = Color3.fromRGB(255, 248, 230)
		pad.Text = ""
		pad.Visible = false
		pad.ZIndex = 7
		pad.Parent = button
		local padStroke = Instance.new("UIStroke")
		padStroke.Thickness = 1
		padStroke.Color = Color3.fromRGB(12, 8, 20)
		padStroke.Parent = pad
		local stacks = Instance.new("TextLabel")
		stacks.Name = "Stacks"
		stacks.AnchorPoint = Vector2.new(0, 1)
		stacks.Position = UDim2.new(0, 3, 1, -2)
		stacks.Size = UDim2.fromOffset(28, 16)
		stacks.BackgroundTransparency = 1
		stacks.Font = Enum.Font.BuilderSansBold
		stacks.TextSize = 13
		stacks.TextXAlignment = Enum.TextXAlignment.Left
		stacks.TextColor3 = Color3.fromRGB(255, 248, 230)
		stacks.Text = ""
		stacks.ZIndex = 6
		stacks.Parent = button
		local stackStroke = Instance.new("UIStroke")
		stackStroke.Thickness = 1
		stackStroke.Color = Color3.fromRGB(12, 8, 20)
		stackStroke.Parent = stacks
		local lockText = Instance.new("TextLabel")
		lockText.Name = "LockText"
		lockText.BackgroundTransparency = 1
		lockText.Size = UDim2.fromScale(1, 0.4)
		lockText.Position = UDim2.fromScale(0, 0.3)
		lockText.Font = Enum.Font.BuilderSansBold
		lockText.TextSize = 14
		lockText.TextColor3 = Color3.fromRGB(255, 220, 140)
		lockText.Text = ""
		lockText.Visible = false
		lockText.ZIndex = 6
		lockText.Parent = button
		local tint = Instance.new("Frame")
		tint.Name = "Tint"
		tint.Size = UDim2.fromScale(0.84, 0.84)
		tint.AnchorPoint = Vector2.new(0.5, 0.5)
		tint.Position = UDim2.fromScale(0.5, 0.5)
		tint.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		tint.BackgroundTransparency = 1
		tint.BorderSizePixel = 0
		tint.Active = false
		tint.ZIndex = 3
		tint.Parent = button
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(0.84, 0.84)
		flash.AnchorPoint = Vector2.new(0.5, 0.5)
		flash.Position = UDim2.fromScale(0.5, 0.5)
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Active = false
		flash.ZIndex = 4
		flash.Parent = button
		local radial = Instance.new("Frame")
		radial.Name = "Radial"
		radial.Size = UDim2.fromScale(0.84, 0.84)
		radial.AnchorPoint = Vector2.new(0.5, 0.5)
		radial.Position = UDim2.fromScale(0.5, 0.5)
		radial.BackgroundColor3 = Color3.new(0, 0, 0)
		radial.BackgroundTransparency = 0.35
		radial.BorderSizePixel = 0
		radial.Active = false
		radial.Visible = false
		radial.ZIndex = 5
		radial.Parent = button
		local sweep = Instance.new("UIGradient")
		sweep.Name = "Sweep"
		sweep.Rotation = 0
		sweep.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweep.Parent = radial
		local seconds = Instance.new("TextLabel")
		seconds.Name = "Seconds"
		seconds.BackgroundTransparency = 1
		seconds.Size = UDim2.fromScale(1, 1)
		seconds.Font = Enum.Font.BuilderSansBold
		seconds.TextSize = 16
		seconds.TextColor3 = Color3.fromRGB(255, 248, 230)
		seconds.Text = ""
		seconds.Visible = false
		seconds.ZIndex = 7
		seconds.Parent = button
		local secondStroke = Instance.new("UIStroke")
		secondStroke.Thickness = 1
		secondStroke.Color = Color3.fromRGB(12, 8, 20)
		secondStroke.Parent = seconds
		local dot = Instance.new("Frame")
		dot.Name = "NewDot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -3, 0, 3)
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BackgroundColor3 = theme("newDot")
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.ZIndex = 8
		dot.Parent = button
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		buttons[index] = button
		-- Desktop hover shows the skill card; phones use the long press below.
		-- The card always follows the slot under the pointer. A drag hides a
		-- card that belongs to another slot instead of leaving it up.
		button.MouseEnter:Connect(function()
			if dragFrom == nil then
				showTip(index)
			elseif tipIndex ~= index then
				hideTip()
			end
		end)
		-- Leaving only hides this slot's own card, so a late MouseLeave from
		-- the previous slot cannot hide the card the next slot just showed.
		button.MouseLeave:Connect(function()
			if tipIndex == index and not heldTip then
				hideTip()
			end
		end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				heldTip = true
				showTip(index)
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			dragFrom = index
			dragMoved = false
			heldTip = false
			dragOrigin = Vector2.new(input.Position.X, input.Position.Y)
			holdToken += 1
			local token = holdToken
			task.delay(0.45, function()
				if token ~= holdToken or dragFrom ~= index then
					return
				end
				heldTip = true
				showTip(index)
			end)
		end)
	end

	-- Purple-hex skill card: name, what it does, effect, cooldown, unlock.
	-- Text comes from SkillTip (skill rows in Classes.luau).
	local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = Color3.fromRGB(30, 18, 60)
	tooltip.BackgroundTransparency = 0.04
	tooltip.BorderSizePixel = 0
	tooltip.Visible = false
	tooltip.Active = false
	tooltip.ZIndex = 20
	tooltip.Parent = screen
	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	tipCorner.Parent = tooltip
	local tipStroke = Instance.new("UIStroke")
	tipStroke.Thickness = UiTheme.STROKE_BOLD
	tipStroke.Color = Color3.fromRGB(150, 92, 255)
	tipStroke.Parent = tooltip
	local tipWash = Instance.new("UIGradient")
	tipWash.Rotation = 90
	tipWash.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 190, 240))
	tipWash.Parent = tooltip
	local tipTitle = Instance.new("TextLabel")
	tipTitle.Name = "Title"
	tipTitle.BackgroundTransparency = 1
	tipTitle.Position = UDim2.fromOffset(SkillTip.PAD + 2, SkillTip.PAD)
	tipTitle.Size = UDim2.new(1, -(SkillTip.PAD + 2) * 2, 0, SkillTip.TITLE)
	tipTitle.Font = Enum.Font.BuilderSansExtraBold
	tipTitle.TextSize = 18
	tipTitle.TextXAlignment = Enum.TextXAlignment.Left
	tipTitle.TextColor3 = Color3.fromRGB(255, 220, 120)
	tipTitle.TextTruncate = Enum.TextTruncate.AtEnd
	tipTitle.Text = ""
	tipTitle.ZIndex = 21
	tipTitle.Parent = tooltip
	local tipBody = Instance.new("TextLabel")
	tipBody.Name = "Body"
	tipBody.BackgroundTransparency = 1
	tipBody.Position = UDim2.fromOffset(SkillTip.PAD + 2, SkillTip.PAD + SkillTip.TITLE)
	tipBody.Size = UDim2.new(1, -(SkillTip.PAD + 2) * 2, 1, -(SkillTip.PAD * 2 + SkillTip.TITLE))
	tipBody.Font = Enum.Font.BuilderSansBold
	tipBody.TextSize = UiTheme.MIN_TEXT
	tipBody.LineHeight = SkillTip.LINE / UiTheme.MIN_TEXT * 0.92
	tipBody.TextXAlignment = Enum.TextXAlignment.Left
	tipBody.TextYAlignment = Enum.TextYAlignment.Top
	tipBody.TextColor3 = theme("text")
	tipBody.TextTruncate = Enum.TextTruncate.AtEnd
	tipBody.Text = ""
	tipBody.ZIndex = 21
	tipBody.Parent = tooltip

	local function promptButton(name: string, text: string): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(44, 44)
		button.BackgroundColor3 = theme("panel")
		button.BackgroundTransparency = 0
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 13
		button.TextColor3 = theme("text")
		button.Text = text
		button.AutoButtonColor = false
		button.Parent = screen
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = theme("accent")
		stroke.Parent = button
		local hexArt = IconAssets.HexButton
		if hexArt ~= nil then
			button.BackgroundTransparency = 1
			button.TextTransparency = 1
			stroke.Enabled = false
			local face = Instance.new("ImageLabel")
			face.Name = "HexFace"
			face.BackgroundTransparency = 1
			face.Size = UDim2.fromScale(1, 1)
			face.ScaleType = Enum.ScaleType.Fit
			face.Image = hexArt
			face.ZIndex = 1
			face.Parent = button
		end
		local key = Instance.new("TextLabel")
		key.Name = "Bind"
		key.BackgroundTransparency = 1
		key.Size = UDim2.fromScale(1, 1)
		key.Font = Enum.Font.BuilderSansBold
		key.TextSize = 14
		key.TextColor3 = Color3.fromRGB(255, 248, 230)
		key.Text = text
		key.ZIndex = 2
		key.Parent = button
		local keyStroke = Instance.new("UIStroke")
		keyStroke.Thickness = 1
		keyStroke.Color = Color3.fromRGB(12, 8, 20)
		keyStroke.Parent = key
		return button
	end

	local dodge = promptButton("Dodge", "Shift")
	local heavy = promptButton("Heavy", "Heavy")
	local attack = promptButton("Swing", "Atk")
	local jump = promptButton("Jump", "Jump")
	heavy.Visible = false
	local dodgePulse = Instance.new("UIStroke")
	dodgePulse.Name = "DodgePulse"
	dodgePulse.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dodgePulse.Thickness = 3
	dodgePulse.Color = Color3.fromRGB(
		CodexCues.COLOR.dodgePulse[1],
		CodexCues.COLOR.dodgePulse[2],
		CodexCues.COLOR.dodgePulse[3]
	)
	dodgePulse.Transparency = 0.1
	dodgePulse.Enabled = false
	dodgePulse.Parent = dodge
	local hexPulse: ImageLabel? = nil
	if IconAssets.HexButton ~= nil then
		dodgePulse.Thickness = 0
		local pulse = Instance.new("ImageLabel")
		pulse.Name = "HexPulse"
		pulse.AnchorPoint = Vector2.new(0.5, 0.5)
		pulse.Position = UDim2.fromScale(0.5, 0.5)
		pulse.Size = UDim2.fromScale(1.22, 1.22)
		pulse.BackgroundTransparency = 1
		pulse.ScaleType = Enum.ScaleType.Fit
		pulse.Image = IconAssets.HexButton
		pulse.ImageColor3 = Color3.fromRGB(90, 230, 255)
		pulse.Visible = false
		pulse.ZIndex = 0
		pulse.Parent = dodge
		hexPulse = pulse
	end
	local dodgeHint = Instance.new("TextLabel")
	dodgeHint.Name = "DodgeHint"
	dodgeHint.BackgroundColor3 = theme("panel")
	dodgeHint.BackgroundTransparency = 0
	dodgeHint.BorderSizePixel = 0
	dodgeHint.Font = Enum.Font.BuilderSansBold
	dodgeHint.TextSize = UiTheme.MIN_TEXT
	dodgeHint.TextColor3 =
		Color3.fromRGB(CodexCues.COLOR.dodge[1], CodexCues.COLOR.dodge[2], CodexCues.COLOR.dodge[3])
	dodgeHint.Text = ""
	dodgeHint.Visible = false
	dodgeHint.ZIndex = 8
	dodgeHint.Parent = screen
	local dodgeHintCorner = Instance.new("UICorner")
	dodgeHintCorner.CornerRadius = UDim.new(0, 8)
	dodgeHintCorner.Parent = dodgeHint
	local dodgeHintStroke = Instance.new("UIStroke")
	dodgeHintStroke.Thickness = 1
	dodgeHintStroke.Color = Color3.fromRGB(12, 8, 20)
	dodgeHintStroke.Parent = dodgeHint
	local interact = promptButton("Interact", "F")
	interact.Visible = false

	local function classId(): string
		if type(profile) == "table" and type(profile.classId) == "string" then
			return profile.classId
		end
		return ""
	end

	local function currentBar(): ActionSlots.Bar
		if override ~= nil then
			return override
		end
		local bars = if type(profile) == "table" then profile.actionBars else nil
		return ActionSlots.barFor(bars, classId())
	end

	local function slotAt(x: number, y: number): number?
		for index, button in ipairs(buttons) do
			local pos = button.AbsolutePosition
			local size = button.AbsoluteSize
			if x >= pos.X and y >= pos.Y and x <= pos.X + size.X and y <= pos.Y + size.Y then
				return index
			end
		end
		return nil
	end

	showTip = function(index: number)
		local bar = currentBar()
		local slot = bar.slots[index]
		if slot == nil or slot.kind == "empty" then
			tooltip.Visible = false
			tipIndex = nil
			return
		end
		local tip = SkillTip.tip(classId(), slot, profile)
		if tip.title == "" then
			tooltip.Visible = false
			tipIndex = nil
			return
		end
		tipTitle.Text = tip.title
		tipBody.Text = table.concat(SkillTip.lines(tip), "\n")
		local button = buttons[index]
		local tipH = SkillTip.height(tip)
		tooltip.Size = UDim2.fromOffset(SkillTip.WIDTH, tipH)
		local screenW = screen.AbsoluteSize.X
		-- Centred over its own slot, so the card reads as that slot's.
		local tipX = button.AbsolutePosition.X
			- screen.AbsolutePosition.X
			+ button.AbsoluteSize.X / 2
			- SkillTip.WIDTH / 2
		if screenW > SkillTip.WIDTH then
			tipX = math.clamp(tipX, 8, screenW - SkillTip.WIDTH - 8)
		end
		local tipY = button.AbsolutePosition.Y - screen.AbsolutePosition.Y - tipH - 8
		tooltip.Position = UDim2.fromOffset(tipX, tipY)
		tooltip.Visible = true
		tipIndex = index
	end

	hideTip = function()
		tooltip.Visible = false
		tipIndex = nil
	end

	local function paint()
		local bar = currentBar()
		local id = classId()
		lock.Text = if bar.locked then "Locked" else "Lock"
		for index, button in ipairs(buttons) do
			local slot = bar.slots[index]
			if slot == nil then
				slot = { kind = "empty", id = "" }
			end
			local glyph = button:FindFirstChild("Glyph")
			local stacks = button:FindFirstChild("Stacks")
			local lockText = button:FindFirstChild("LockText")
			local border = button:FindFirstChild("Border")
			local tint = button:FindFirstChild("Tint")
			local letter, color = ActionSlots.glyph(id, slot)
			local liftedR, liftedG, liftedB = UiTheme.lift(color[1], color[2], color[3])
			local artKey = ActionSlots.art(id, slot)
			local artId = if artKey ~= nil then IconAssets[artKey] else nil
			local art = button:FindFirstChild("Art")
			if art ~= nil and art:IsA("ImageLabel") then
				art.Image = artId or ""
				art.Visible = artId ~= nil
			end
			if glyph ~= nil and glyph:IsA("TextLabel") then
				-- With painted art, a skill keeps its letter as a small corner
				-- badge (roles share art, so two slots can look alike); tonics
				-- and items drop the letter. Without art the big letter stays.
				local badge = artId ~= nil and slot.kind == "skill"
				glyph.Text = if artId ~= nil and not badge then "" else letter
				glyph.TextSize = if badge then 14 else 22
				glyph.Position = if badge
					then UDim2.fromScale(0.5, 0.64)
					else UDim2.fromScale(0, 0.26)
				glyph.Size = if badge then UDim2.fromScale(0.36, 0.26) else UDim2.fromScale(1, 0.62)
				glyph.TextXAlignment = if badge
					then Enum.TextXAlignment.Right
					else Enum.TextXAlignment.Center
				glyph.ZIndex = if badge then 3 else 2
				glyph.TextColor3 = Color3.fromRGB(liftedR, liftedG, liftedB)
			end
			local hexGlow = button:FindFirstChild("HexGlow")
			if hexGlow ~= nil and hexGlow:IsA("ImageLabel") then
				local cue = skillsCue and slot.kind == "skill"
				hexGlow.Visible = index == picked or cue
				if not cue then
					hexGlow.ImageTransparency = 0
				end
			end
			-- [Ghost] Oct 24: empty slots fade so eight blank hexes do not
			-- read as unfinished. The next free slot stays half bright.
			local look = ActionSlots.look(bar, index)
			local fade = ActionSlots.FADE[look] or 0
			button:SetAttribute("Look", look)
			local bindBadge = button:FindFirstChild("Bind")
			if bindBadge ~= nil and bindBadge:IsA("TextLabel") then
				bindBadge.BackgroundTransparency = fade
				bindBadge.TextTransparency = fade * 0.6
			end
			if button:FindFirstChild("HexFrame") == nil then
				button.BackgroundTransparency = fade
			end
			if border ~= nil and border:IsA("UIStroke") then
				border.Transparency = fade
			end
			local hexFrame = button:FindFirstChild("HexFrame")
			if hexFrame ~= nil and hexFrame:IsA("ImageLabel") then
				hexFrame.ImageTransparency = fade
				-- Items and consumables keep a soft rarity tint on the frame.
				if slot.kind == "item" or slot.kind == "consumable" then
					local row = ActionSlots.border(slot, profile)
					hexFrame.ImageColor3 = Color3.fromRGB(
						math.floor(255 + (row[1] - 255) * 0.45),
						math.floor(255 + (row[2] - 255) * 0.45),
						math.floor(255 + (row[3] - 255) * 0.45)
					)
				else
					hexFrame.ImageColor3 = Color3.new(1, 1, 1)
				end
			end
			if border ~= nil and border:IsA("UIStroke") then
				if index == picked then
					border.Color = Color3.fromRGB(255, 255, 255)
				else
					border.Color = rgb(ActionSlots.border(slot, profile))
				end
			end
			local dot = button:FindFirstChild("NewDot")
			if dot ~= nil and dot:IsA("Frame") then
				local seenAt = if noticed[slot.id] == true then math.huge else 0
				dot.Visible = ActionSlots.unseen(slot, profile, seenAt)
			end
			local skillGlow = button:FindFirstChild("SkillGlow")
			if skillGlow ~= nil and skillGlow:IsA("UIStroke") then
				skillGlow.Enabled = skillsCue and slot.kind == "skill"
			end
			local count = ActionSlots.stacks(slot, profile)
			if stacks ~= nil and stacks:IsA("TextLabel") then
				stacks.Text = if count ~= nil then tostring(count) else ""
			end
			local locked = ActionSlots.lockLabel(id, slot, profile)
			if lockText ~= nil and lockText:IsA("TextLabel") then
				lockText.Visible = locked ~= nil
				lockText.Text = locked or ""
			end
			local cooling = (readyAt[index] or 0) > os.clock()
			local reason = ActionSlots.block(id, slot, profile, cooling, true)
			local tone = ActionSlots.tint(reason)
			if tint ~= nil and tint:IsA("Frame") then
				if tone == "range" then
					tint.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
					tint.BackgroundTransparency = 0.45
				elseif tone == "locked" or tone == "unusable" then
					tint.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
					tint.BackgroundTransparency = 0.35
				else
					tint.BackgroundTransparency = 1
				end
			end
		end
	end

	local function publish(bar: ActionSlots.Bar)
		override = bar
		paint()
		local id = classId()
		if id == "" then
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return callbacks.invoke("SetActionBar", id, bar.slots, bar.locked)
			end)
			if not ok or type(result) ~= "table" or result.ok ~= true then
				override = nil
				local message = "Could not save the bar."
				if type(result) == "table" and type(result.error) == "string" then
					message = result.error
				end
				callbacks.onToast(message)
				paint()
				return
			end
			callbacks.onResult(result)
		end)
	end

	-- One purple-hex chip over the pressed slot for "On cooldown" and the
	-- ultimate still charging, instead of a grey toast per key press.
	local nudgeState = { index = nil :: number?, at = nil :: number?, token = 0 }
	local nudgeChip = Instance.new("TextLabel")
	nudgeChip.Name = "CooldownNudge"
	nudgeChip.BackgroundColor3 = Color3.fromRGB(30, 18, 60)
	nudgeChip.BackgroundTransparency = 0.04
	nudgeChip.BorderSizePixel = 0
	nudgeChip.Size = UDim2.fromOffset(CooldownNudge.WIDTH, CooldownNudge.HEIGHT)
	nudgeChip.AnchorPoint = Vector2.new(0.5, 1)
	nudgeChip.Font = Enum.Font.BuilderSansExtraBold
	nudgeChip.TextSize = UiTheme.MIN_TEXT
	nudgeChip.TextColor3 = Color3.fromRGB(226, 208, 255)
	nudgeChip.Visible = false
	nudgeChip.Active = false
	nudgeChip.ZIndex = 19
	nudgeChip.Parent = screen
	do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, UiTheme.CORNER)
		corner.Parent = nudgeChip
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = Color3.fromRGB(150, 92, 255)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = nudgeChip
	end

	local function nudge(index: number, kind: string)
		local now = os.clock()
		nudgeChip.Text = CooldownNudge.text(kind, (readyAt[index] or now) - now)
		if not CooldownNudge.fresh(nudgeState.index, nudgeState.at, index, now) then
			return
		end
		nudgeState.index = index
		nudgeState.at = now
		nudgeState.token += 1
		local token = nudgeState.token
		local button = buttons[index]
		if button ~= nil then
			nudgeChip.Position = UDim2.fromOffset(
				button.AbsolutePosition.X - screen.AbsolutePosition.X + button.AbsoluteSize.X / 2,
				button.AbsolutePosition.Y - screen.AbsolutePosition.Y - 6
			)
		end
		nudgeChip.Visible = true
		task.delay(CooldownNudge.SHOW_SECONDS, function()
			if nudgeState.token == token then
				nudgeChip.Visible = false
			end
		end)
	end

	local function runSlot(index: number)
		picked = index
		flashUntil[index] = os.clock() + 0.12
		local bar = currentBar()
		local slot = bar.slots[index]
		if slot == nil or slot.kind == "empty" then
			paint()
			return
		end
		if slot.kind == "item" and slot.id ~= "" then
			noticed[slot.id] = true
		end
		local cooling = (readyAt[index] or 0) > os.clock()
		local reason = ActionSlots.block(classId(), slot, profile, cooling, true)
		local nudgeKind = CooldownNudge.kind(reason)
		if nudgeKind ~= nil then
			nudge(index, nudgeKind)
			paint()
			return
		end
		if reason ~= nil then
			callbacks.onToast(reason)
			paint()
			return
		end
		if slot.kind == "skill" then
			callbacks.onSkill()
		end
		task.spawn(function()
			-- A press must never end in silence: if the server has not
			-- answered after INVOKE_WAIT seconds, say so.
			local answered = false
			task.delay(INVOKE_WAIT, function()
				if not answered then
					callbacks.onToast("No reply from the server. Try again.")
				end
			end)
			local ok, result = pcall(function()
				return callbacks.invoke("UseActionSlot", index)
			end)
			answered = true
			if not ok or type(result) ~= "table" then
				if not ok then
					warn("[ActionBar] UseActionSlot failed: " .. tostring(result))
				end
				callbacks.onToast("Could not use that.")
				return
			end
			if type(result.cooldown) == "number" and result.cooldown > 0 then
				readyTotal[index] = result.cooldown
				readyAt[index] = os.clock() + result.cooldown
			end
			if result.ok ~= true then
				local message = if type(result.error) == "string"
					then result.error
					else "Could not use that."
				local serverKind = CooldownNudge.kind(message)
				if serverKind ~= nil then
					nudge(index, serverKind)
				else
					callbacks.onToast(message)
				end
				paint()
				return
			end
			callbacks.onResult(result)
		end)
	end

	-- Every press ends in a cast, a cooldown chip, or a message. A Lua
	-- error inside the press (paint, a callback) is reported, not swallowed.
	local function useSlot(index: number)
		local ok, err = pcall(runSlot, index)
		if not ok then
			warn("[ActionBar] slot " .. tostring(index) .. " press failed: " .. tostring(err))
			pcall(callbacks.onToast, "Could not use that.")
		end
	end

	-- A slot press while a menu is open does not cast. Say why.
	local function menuBlocked()
		callbacks.onToast(MENU_OPEN_TEXT)
	end

	lock.Activated:Connect(function()
		local bar = currentBar()
		local slots = {}
		for index = 1, ActionSlots.COUNT do
			local slot = bar.slots[index]
			slots[index] = {
				kind = if slot ~= nil then slot.kind else "empty",
				id = if slot ~= nil then slot.id else "",
			}
		end
		publish({ locked = not bar.locked, slots = slots })
	end)
	-- Shift calls onDodge only. The on-screen chip also notes the flash.
	dodge.Activated:Connect(function()
		if callbacks.menuOpen() then
			return
		end
		callbacks.onDodge()
		local note = callbacks.onDodgeChip
		if note ~= nil then
			note()
		end
	end)
	heavy.Activated:Connect(function()
		if callbacks.menuOpen() then
			return
		end
		callbacks.onHeavy()
	end)
	attack.Activated:Connect(function()
		if callbacks.menuOpen() then
			return
		end
		callbacks.onLight()
	end)
	jump.Activated:Connect(function()
		local player = Players.LocalPlayer
		local character = if player ~= nil then player.Character else nil
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid ~= nil then
			humanoid.Jump = true
		end
	end)

	local lastInputName = UserInputService:GetLastInputType().Name
	local function dodgeFace(mobile: boolean): string
		if Keybinds.usesGamepad(lastInputName) then
			return "Y"
		end
		if mobile then
			return "Dodge"
		end
		return "Shift"
	end

	local function place()
		local size = screen.AbsoluteSize
		local mobile = callbacks.mobile() or size.X < 700 or size.Y < 500
		local spot = ActionSlots.placement(size.X, size.Y, mobile)
		local chrome = ActionSlots.chrome(spot)
		lock.Position = UDim2.fromOffset(chrome.lock.x, chrome.lock.y)
		lock.Size = UDim2.fromOffset(chrome.lock.w, chrome.lock.h)
		rollKey.Position = UDim2.fromOffset(chrome.roll.x, chrome.roll.y)
		rollKey.Size = UDim2.fromOffset(chrome.roll.w, chrome.roll.h)
		tabStrip.Position = UDim2.fromOffset(chrome.strip.x, chrome.strip.y)
		tabStrip.Size = UDim2.fromOffset(chrome.strip.w, chrome.strip.h)
		tabTip.Position = UDim2.fromOffset(chrome.tip.x, chrome.tip.y)
		tabTip.Size = UDim2.fromOffset(chrome.tip.w, chrome.tip.h)
		root.Position = UDim2.fromOffset(spot.x, spot.y)
		root.Size = UDim2.fromOffset(spot.w, spot.h)
		grid.Size = UDim2.fromOffset(spot.w, spot.h - ActionSlots.TAB_BAND)
		layout.CellSize = UDim2.fromOffset(spot.slot, spot.slot)
		layout.CellPadding = UDim2.fromOffset(spot.gap, spot.gap)
		local chips = ActionSlots.prompts(spot, size.X, size.Y)
		local cluster = CombatCluster.place(size.X, size.Y, nil, mobile)
		attack.Position = UDim2.fromOffset(cluster.attack.x, cluster.attack.y)
		attack.Size = UDim2.fromOffset(cluster.attack.w, cluster.attack.h)
		dodge.Position = UDim2.fromOffset(cluster.dodge.x, cluster.dodge.y)
		dodge.Size = UDim2.fromOffset(cluster.dodge.w, cluster.dodge.h)
		jump.Position = UDim2.fromOffset(cluster.jump.x, cluster.jump.y)
		jump.Size = UDim2.fromOffset(cluster.jump.w, cluster.jump.h)
		interact.Position = UDim2.fromOffset(chips.interact.x, chips.interact.y)
		interact.Size = UDim2.fromOffset(chips.interact.w, chips.interact.h)
		dodgeHint.Position = UDim2.fromOffset(cluster.dodge.x, math.max(0, cluster.dodge.y - 32))
		dodgeHint.Size = UDim2.fromOffset(math.max(cluster.dodge.w, 88), 28)
		dodgeHint.Text = if dodgeCue then CodexCues.HINT else ""
		dodgeHint.Visible = dodgeCue
		local bind = dodge:FindFirstChild("Bind")
		if bind ~= nil and bind:IsA("TextLabel") then
			bind.Text = dodgeFace(mobile)
		end
		local heavySpot = HeavyChip.place(size.X, size.Y)
		heavy.Visible = HeavyChip.show(mobile)
		if heavy.Visible then
			heavy.Position = UDim2.fromOffset(cluster.heavy.x, cluster.heavy.y)
			heavy.Size = UDim2.fromOffset(cluster.heavy.w, cluster.heavy.h)
		else
			heavy.Position = UDim2.fromOffset(heavySpot.x, heavySpot.y)
			heavy.Size = UDim2.fromOffset(heavySpot.w, heavySpot.h)
		end
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	local function finishDrag(x: number, y: number)
		local from = dragFrom
		local moved = dragMoved
		local carried = payloadMoved
		dragFrom = nil
		dragMoved = false
		payloadMoved = false
		holdToken += 1
		local target = slotAt(x, y)
		if from ~= nil and moved then
			ActionDrag.clear()
			local bar = currentBar()
			if bar.locked then
				callbacks.onToast("Bar is locked.")
			elseif target == nil then
				local nextBar, why = ActionSlots.clear(bar, from)
				if nextBar == nil then
					callbacks.onToast(why or "Bar is locked.")
				else
					publish(nextBar)
				end
			elseif target ~= from then
				local nextBar, why = ActionSlots.swap(bar, from, target)
				if nextBar == nil then
					callbacks.onToast(why or "Bar is locked.")
				else
					publish(nextBar)
				end
			end
			heldTip = false
			return
		elseif from ~= nil and not heldTip and target == from then
			if callbacks.menuOpen() then
				menuBlocked()
			else
				useSlot(from)
			end
		end
		heldTip = false
		local payload = ActionDrag.peek()
		if payload == nil then
			return
		end
		ActionDrag.take()
		if not carried or target == nil then
			return
		end
		local bar = currentBar()
		local accepted, why = ActionSlots.accept(classId(), bar.slots, bar.locked, profile)
		if accepted == nil then
			callbacks.onToast(why or "Could not save the bar.")
			return
		end
		local nextBar, dropWhy = ActionSlots.drop(accepted, target, payload)
		if nextBar == nil then
			callbacks.onToast(dropWhy or "Bar is locked.")
			return
		end
		local checked, checkWhy =
			ActionSlots.accept(classId(), nextBar.slots, nextBar.locked, profile)
		if checked == nil then
			callbacks.onToast(checkWhy or "That skill is not on this class.")
			return
		end
		publish(checked)
	end

	-- Hide the card a press left up, but not one a later hover showed.
	local function hideTipLater()
		local shown = tipIndex
		task.delay(1.2, function()
			if tipIndex == shown then
				hideTip()
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		payloadOrigin = Vector2.new(input.Position.X, input.Position.Y)
		payloadMoved = false
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragFrom == nil and ActionDrag.peek() == nil then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local origin = if dragFrom ~= nil then dragOrigin else payloadOrigin
		local delta = Vector2.new(input.Position.X, input.Position.Y) - origin
		if delta.Magnitude > 8 then
			if dragFrom ~= nil then
				dragMoved = true
			end
			payloadMoved = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				hideTipLater()
			end
			return
		end
		if dragFrom == nil and ActionDrag.peek() == nil then
			return
		end
		finishDrag(input.Position.X, input.Position.Y)
		hideTipLater()
	end)

	local function applyFaces(inputTypeName: string)
		lastInputName = inputTypeName
		local gamepad = Keybinds.usesGamepad(inputTypeName)
		for index, button in ipairs(buttons) do
			local bind = button:FindFirstChild("Bind")
			local glyph = button:FindFirstChild("PadGlyph")
			local face = Keybinds.slotFace(index, inputTypeName)
			if bind ~= nil and bind:IsA("TextLabel") then
				bind.Visible = not gamepad
				if not gamepad then
					bind.Text = face
				end
			end
			if glyph ~= nil and glyph:IsA("TextLabel") then
				glyph.Visible = gamepad
				if gamepad then
					glyph.Text = face
				end
			end
		end
		local dodgeBind = dodge:FindFirstChild("Bind")
		if dodgeBind ~= nil and dodgeBind:IsA("TextLabel") then
			local size = screen.AbsoluteSize
			dodgeBind.Text = dodgeFace(callbacks.mobile() or size.X < 700)
		end
	end
	applyFaces(UserInputService:GetLastInputType().Name)
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		applyFaces(inputType.Name)
	end)

	local codes = {}
	for index = 1, ActionSlots.COUNT do
		local key = ActionSlots.KEYS[index]
		local code = (Enum.KeyCode :: any)[key]
		if code ~= nil then
			table.insert(codes, code)
		end
	end
	ContextActionService:BindActionAtPriority("ShardfallActionBar", function(_name, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local index = ActionSlots.indexForKey(input.KeyCode.Name)
		if index == nil then
			return Enum.ContextActionResult.Pass
		end
		if callbacks.menuOpen() then
			menuBlocked()
			return Enum.ContextActionResult.Sink
		end
		useSlot(index)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(codes))
	local dodgeCodes = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift }
	local padDodge = (Enum.KeyCode :: any)[Keybinds.GAMEPAD.dodge]
	if padDodge ~= nil then
		table.insert(dodgeCodes, padDodge)
	end
	ContextActionService:BindActionAtPriority("ShardfallDodge", function(_name, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if callbacks.menuOpen() then
			return Enum.ContextActionResult.Pass
		end
		callbacks.onDodge()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(dodgeCodes))
	-- ButtonR1 changes hub tabs while the menu is open, so this bind
	-- passes then. While the menu is closed it is the light attack.
	-- ButtonX stays heavy. Do not add this key to the hub sink.
	local lightCode = (Enum.KeyCode :: any)[PadLight.KEY]
	if lightCode ~= nil then
		ContextActionService:BindActionAtPriority("ShardfallLight", function(_name, state)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if not PadLight.fire(PadLight.KEY, callbacks.menuOpen()) then
				return Enum.ContextActionResult.Pass
			end
			callbacks.onLight()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, lightCode)
	end

	local padCodes = {}
	for button in pairs(Keybinds.PAD.buttons) do
		local code = (Enum.KeyCode :: any)[button]
		if code ~= nil then
			table.insert(padCodes, code)
		end
	end
	local modifierCode = (Enum.KeyCode :: any)[Keybinds.PAD.modifier]
	ContextActionService:BindActionAtPriority("ShardfallActionBarPad", function(_name, state, input)
		if callbacks.menuOpen() then
			return Enum.ContextActionResult.Pass
		end
		-- ButtonL1 is a gamepad button. Read it on the pad that produced
		-- this D-pad press. One call: slots 5-8 while LB is held, and
		-- slots 1-4 when it is not. The chord does not also fire 1-4.
		local inputType = input.UserInputType
		local typeName = if inputType ~= nil then inputType.Name else ""
		local modifierDown = false
		if modifierCode ~= nil and inputType ~= nil and Keybinds.usesGamepad(typeName) then
			modifierDown = UserInputService:IsGamepadButtonDown(inputType, modifierCode)
		end
		local index = Keybinds.padChordSlot(input.KeyCode.Name, typeName, modifierDown)
		if index == nil then
			return Enum.ContextActionResult.Pass
		end
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		useSlot(index)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(padCodes))

	ProximityPromptService.PromptShown:Connect(function(prompt)
		promptsShown += 1
		if prompt.KeyboardKeyCode == Enum.KeyCode.E then
			prompt.KeyboardKeyCode = Enum.KeyCode.F
		end
		local bind = interact:FindFirstChild("Bind")
		if bind ~= nil and bind:IsA("TextLabel") then
			local label = if prompt.ActionText ~= "" then prompt.ActionText else "Interact"
			bind.Text = "F  " .. label
		end
		interact.Visible = true
	end)
	ProximityPromptService.PromptHidden:Connect(function()
		promptsShown = math.max(0, promptsShown - 1)
		interact.Visible = promptsShown > 0
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for index, button in ipairs(buttons) do
			local untilAt = readyAt[index]
			local total = readyTotal[index]
			local cover = button:FindFirstChild("Radial")
			local seconds = button:FindFirstChild("Seconds")
			local flash = button:FindFirstChild("Flash")
			if
				cover ~= nil
				and cover:IsA("Frame")
				and type(untilAt) == "number"
				and type(total) == "number"
			then
				local left = ActionSlots.secondsLeft(untilAt, now)
				local amount = ActionSlots.sweep(total - (untilAt - now), total)
				local sweep = cover:FindFirstChild("Sweep")
				if sweep ~= nil and sweep:IsA("UIGradient") then
					sweep.Rotation = amount * 360
				end
				cover.Visible = left > 0
				if seconds ~= nil and seconds:IsA("TextLabel") then
					seconds.Visible = left > 0
					seconds.Text = if left > 0 then tostring(left) else ""
				end
			end
			if flash ~= nil and flash:IsA("Frame") then
				local untilFlash = flashUntil[index]
				flash.BackgroundTransparency = if type(untilFlash) == "number"
						and now < untilFlash
					then 0.45
					else 1
			end
			local skillGlow = button:FindFirstChild("SkillGlow")
			if skillGlow ~= nil and skillGlow:IsA("UIStroke") and skillGlow.Enabled then
				skillGlow.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(now * 6))
				local hexGlow = button:FindFirstChild("HexGlow")
				if hexGlow ~= nil and hexGlow:IsA("ImageLabel") then
					hexGlow.ImageTransparency = skillGlow.Transparency
				end
			end
		end
		dodgePulse.Enabled = dodgeCue
		if dodgeCue then
			dodgePulse.Transparency = 0.05 + 0.3 * (0.5 + 0.5 * math.sin(now * 8))
		end
		if hexPulse ~= nil then
			hexPulse.Visible = dodgeCue
			hexPulse.ImageTransparency = dodgePulse.Transparency
		end
	end)

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
			skillsCue = cue.skills == true
			dodgeCue = cue.dodge == true
			dodgeHint.Text = if dodgeCue then CodexCues.HINT else ""
			dodgeHint.Visible = dodgeCue
			paint()
		end)
	end)

	return {
		setProfile = function(nextProfile: any)
			local id = if type(nextProfile) == "table"
					and type(nextProfile.classId) == "string"
				then nextProfile.classId
				else ""
			if id ~= classSeen then
				readyAt = {}
				readyTotal = {}
				classSeen = id
				override = nil
			end
			profile = nextProfile
			if
				override ~= nil
				and type(nextProfile) == "table"
				and type(nextProfile.actionBars) == "table"
			then
				override = nil
			end
			paint()
			place()
		end,
		-- Combat still reports dodge charges. The prompt stays Shift / Dodge.
		setDodge = function(_charges: number) end,
	}
end

return ActionBar
