--!strict

--[[
	Bottom action bar. Eight square slots on keys 1-8.

	A click, a tap, or the key asks the server to use that slot. Shift
	dodges. F is the interact prompt and only shows while a prompt is up.
	On a gamepad the D-pad uses slots 1-4, and holding LB uses slots 5-8.
	The corner shows that glyph while a gamepad was the last input, and
	the key number otherwise. Both paths call useSlot.

	The old cluster used the settings gear, the help-tab question mark, and
	an empty icon, and it dropped the key when the engine had already
	handled it. These slots bind above that and show the skill glyph.
]]

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionDrag = require(Shared:WaitForChild("ActionDrag"))
local ActionSlots = require(Shared:WaitForChild("ActionSlots"))
local Keybinds = require(Shared:WaitForChild("Keybinds"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local ActionBar = {}

export type Callbacks = {
	invoke: (string, ...any) -> any,
	menuOpen: () -> boolean,
	onDodge: () -> (),
	onSkill: () -> (),
	onToast: (string) -> (),
	onResult: (any) -> (),
	mobile: () -> boolean,
}

local function rgb(row: { number }): Color3
	return Color3.fromRGB(row[1], row[2], row[3])
end

local function theme(name: string): Color3
	local row = UiTheme.RGB[name]
	return Color3.fromRGB(row[1], row[2], row[3])
end

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
	local payloadMoved = false
	local payloadOrigin = Vector2.zero
	local showTip: (number) -> ()
	local hideTip: () -> ()

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

	local grid = Instance.new("Frame")
	grid.Name = "Slots"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 36)
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
		button.BackgroundColor3 = theme("body")
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
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = theme("accent")
		stroke.Parent = button
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 0.7)
		glyph.Position = UDim2.fromScale(0, 0.06)
		glyph.Font = Enum.Font.BuilderSansBold
		glyph.TextSize = 22
		glyph.TextColor3 = theme("text")
		glyph.Text = ""
		glyph.ZIndex = 2
		glyph.Parent = button
		local bind = Instance.new("TextLabel")
		bind.Name = "Bind"
		bind.AnchorPoint = Vector2.new(1, 1)
		bind.Position = UDim2.new(1, -3, 1, -2)
		bind.Size = UDim2.fromOffset(22, 16)
		bind.BackgroundTransparency = 1
		bind.Font = Enum.Font.BuilderSansBold
		bind.TextSize = 13
		bind.TextXAlignment = Enum.TextXAlignment.Right
		bind.TextColor3 = Color3.fromRGB(255, 248, 230)
		bind.Text = ActionSlots.keyLabel(index)
		bind.ZIndex = 6
		bind.Parent = button
		local bindStroke = Instance.new("UIStroke")
		bindStroke.Thickness = 1
		bindStroke.Color = Color3.fromRGB(12, 8, 20)
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
		tint.Size = UDim2.fromScale(1, 1)
		tint.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		tint.BackgroundTransparency = 1
		tint.BorderSizePixel = 0
		tint.Active = false
		tint.ZIndex = 3
		tint.Parent = button
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.Active = false
		flash.ZIndex = 4
		flash.Parent = button
		local radial = Instance.new("Frame")
		radial.Name = "Radial"
		radial.Size = UDim2.fromScale(1, 1)
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
		buttons[index] = button
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

	local tooltip = Instance.new("TextLabel")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = theme("panel")
	tooltip.BackgroundTransparency = 0
	tooltip.Font = Enum.Font.BuilderSansBold
	tooltip.TextSize = UiTheme.MIN_TEXT
	tooltip.TextColor3 = theme("text")
	tooltip.TextWrapped = true
	tooltip.Text = ""
	tooltip.Visible = false
	tooltip.ZIndex = 8
	tooltip.Parent = screen
	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0, 8)
	tipCorner.Parent = tooltip
	local tipStroke = Instance.new("UIStroke")
	tipStroke.Color = theme("accent")
	tipStroke.Parent = tooltip

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
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = UiTheme.STROKE_BOLD
		stroke.Color = theme("accent")
		stroke.Parent = button
		local key = Instance.new("TextLabel")
		key.Name = "Bind"
		key.BackgroundTransparency = 1
		key.Size = UDim2.fromScale(1, 1)
		key.Font = Enum.Font.BuilderSansBold
		key.TextSize = 14
		key.TextColor3 = Color3.fromRGB(255, 248, 230)
		key.Text = text
		key.Parent = button
		local keyStroke = Instance.new("UIStroke")
		keyStroke.Thickness = 1
		keyStroke.Color = Color3.fromRGB(12, 8, 20)
		keyStroke.Parent = key
		return button
	end

	local dodge = promptButton("Dodge", "Shift")
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
			return
		end
		local name, note = ActionSlots.describe(classId(), slot, profile)
		tooltip.Text = name .. "\n" .. note
		local button = buttons[index]
		tooltip.Size = UDim2.fromOffset(180, 48)
		local tipX = button.AbsolutePosition.X - screen.AbsolutePosition.X
		local tipY = button.AbsolutePosition.Y - screen.AbsolutePosition.Y - 52
		tooltip.Position = UDim2.fromOffset(tipX, tipY)
		tooltip.Visible = true
	end

	hideTip = function()
		tooltip.Visible = false
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
			if glyph ~= nil and glyph:IsA("TextLabel") then
				glyph.Text = letter
				glyph.TextColor3 = Color3.fromRGB(liftedR, liftedG, liftedB)
			end
			if border ~= nil and border:IsA("UIStroke") then
				border.Color = rgb(ActionSlots.border(slot, profile))
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

	local function useSlot(index: number)
		flashUntil[index] = os.clock() + 0.12
		local bar = currentBar()
		local slot = bar.slots[index]
		if slot == nil or slot.kind == "empty" then
			return
		end
		local cooling = (readyAt[index] or 0) > os.clock()
		local reason = ActionSlots.block(classId(), slot, profile, cooling, true)
		if reason ~= nil then
			callbacks.onToast(reason)
			paint()
			return
		end
		if slot.kind == "skill" then
			callbacks.onSkill()
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return callbacks.invoke("UseActionSlot", index)
			end)
			if not ok or type(result) ~= "table" then
				callbacks.onToast("Could not use that.")
				return
			end
			if type(result.cooldown) == "number" and result.cooldown > 0 then
				readyTotal[index] = result.cooldown
				readyAt[index] = os.clock() + result.cooldown
			end
			if result.ok ~= true then
				local message = if type(result.error) == "string" then result.error else "Could not use that."
				callbacks.onToast(message)
				paint()
				return
			end
			callbacks.onResult(result)
		end)
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
	dodge.Activated:Connect(callbacks.onDodge)

	local function place()
		local size = screen.AbsoluteSize
		local mobile = callbacks.mobile() or size.X < 700
		local spot = ActionSlots.placement(size.X, size.Y, mobile)
		root.Position = UDim2.fromOffset(spot.x, spot.y)
		root.Size = UDim2.fromOffset(spot.w, spot.h)
		grid.Size = UDim2.fromOffset(spot.w, spot.h - 36)
		layout.CellSize = UDim2.fromOffset(spot.slot, spot.slot)
		layout.CellPadding = UDim2.fromOffset(spot.gap, spot.gap)
		local chips = ActionSlots.prompts(spot, size.X, size.Y)
		dodge.Position = UDim2.fromOffset(chips.dodge.x, chips.dodge.y)
		dodge.Size = UDim2.fromOffset(chips.dodge.w, chips.dodge.h)
		interact.Position = UDim2.fromOffset(chips.interact.x, chips.interact.y)
		interact.Size = UDim2.fromOffset(chips.interact.w, chips.interact.h)
		local bind = dodge:FindFirstChild("Bind")
		if bind ~= nil and bind:IsA("TextLabel") then
			bind.Text = if mobile then "Dodge" else "Shift"
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
			useSlot(from)
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
		local checked, checkWhy = ActionSlots.accept(classId(), nextBar.slots, nextBar.locked, profile)
		if checked == nil then
			callbacks.onToast(checkWhy or "That skill is not on this class.")
			return
		end
		publish(checked)
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
				task.delay(1.2, hideTip)
			end
			return
		end
		if dragFrom == nil and ActionDrag.peek() == nil then
			return
		end
		finishDrag(input.Position.X, input.Position.Y)
		task.delay(1.2, hideTip)
	end)

	local function applyFaces(inputTypeName: string)
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
	ContextActionService:BindActionAtPriority(
		"ShardfallActionBar",
		function(_name, state, input)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if callbacks.menuOpen() then
				return Enum.ContextActionResult.Pass
			end
			local index = ActionSlots.indexForKey(input.KeyCode.Name)
			if index == nil then
				return Enum.ContextActionResult.Pass
			end
			useSlot(index)
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(codes)
	)
	ContextActionService:BindActionAtPriority(
		"ShardfallDodge",
		function(_name, state)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if callbacks.menuOpen() then
				return Enum.ContextActionResult.Pass
			end
			callbacks.onDodge()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift
	)

	local padCodes = {}
	for button in pairs(Keybinds.PAD.buttons) do
		local code = (Enum.KeyCode :: any)[button]
		if code ~= nil then
			table.insert(padCodes, code)
		end
	end
	local modifierCode = (Enum.KeyCode :: any)[Keybinds.PAD.modifier]
	ContextActionService:BindActionAtPriority(
		"ShardfallActionBarPad",
		function(_name, state, input)
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
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(padCodes)
	)

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
			if cover ~= nil and cover:IsA("Frame") and type(untilAt) == "number" and type(total) == "number" then
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
				flash.BackgroundTransparency = if type(untilFlash) == "number" and now < untilFlash then 0.45 else 1
			end
		end
	end)

	return {
		setProfile = function(nextProfile: any)
			local id = if type(nextProfile) == "table" and type(nextProfile.classId) == "string"
				then nextProfile.classId
				else ""
			if id ~= classSeen then
				readyAt = {}
				readyTotal = {}
				classSeen = id
				override = nil
			end
			profile = nextProfile
			if override ~= nil and type(nextProfile) == "table" and type(nextProfile.actionBars) == "table" then
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
