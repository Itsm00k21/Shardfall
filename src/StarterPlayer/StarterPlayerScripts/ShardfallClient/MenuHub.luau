--!strict

--[[
	One modal stack. Tabs replace each other. Esc and the backdrop pop.
	The rail fades, then the panel follows. Debug grants live here and
	only while Studio is running.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ClientChrome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ClientChrome"))
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local MenuHub = {}

export type Hooks = {
	invoke: (string, ...any) -> any,
	onRoll: () -> (),
	onBag: () -> (),
	onMarket: () -> (),
	onDim: (boolean) -> (),
}

local function rgb(name: string): Color3
	local row = UiTheme.RGB[name]
	return Color3.fromRGB(row[1], row[2], row[3])
end

function MenuHub.start(playerGui: PlayerGui, hooks: Hooks)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallHub"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 80
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.IgnoreGuiInset = false
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
	backdrop.Parent = screen

	local panel = Instance.new("CanvasGroup")
	panel.Name = "Panel"
	panel.BackgroundColor3 = rgb("panel")
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.GroupTransparency = 1
	panel.Parent = screen
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = UiTheme.STROKE
	panelStroke.Color = rgb("gold")
	panelStroke.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(rgb("panel"), rgb("background"))
	gradient.Parent = panel

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(0, 132, 1, -16)
	tabs.Position = UDim2.fromOffset(8, 8)
	tabs.Parent = panel
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Vertical
	tabList.Padding = UDim.new(0, 6)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(148, 48)
	body.Size = UDim2.new(1, -160, 1, -60)
	body.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(148, 8)
	title.Size = UDim2.new(1, -220, 0, 32)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = rgb("text")
	title.Text = "Menu"
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 8)
	closeButton.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	closeButton.BackgroundColor3 = rgb("buttonDim")
	closeButton.Font = Enum.Font.BuilderSansBold
	closeButton.TextSize = UiTheme.MIN_TEXT
	closeButton.TextColor3 = rgb("text")
	closeButton.Text = "X"
	closeButton.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	local profile: any = nil
	local draft = Settings.default()
	local stack: { string } = {}
	local pages: { [string]: Frame } = {}
	local capturing: string? = nil

	local function view(): (number, number)
		local size = screen.AbsoluteSize
		return if size.X >= 200 then size.X else 1280, if size.Y >= 200 then size.Y else 800
	end

	local function place()
		local vx, vy = view()
		local box = HudLayout.hub(vx, vy, UiTheme.safeMargin())
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

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
		layout.Padding = UDim.new(0, UiTheme.PAD)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		return list
	end

	local function row(parent: Instance, text: string, order: number, fn: (() -> ())?): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -8, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("buttonDim")
		button.BorderSizePixel = 0
		button.Font = Enum.Font.BuilderSans
		button.TextSize = UiTheme.MIN_TEXT
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextColor3 = rgb("text")
		button.Text = "  " .. text
		button.LayoutOrder = order
		button.AutoButtonColor = fn ~= nil
		button.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local pop = Instance.new("UIScale")
		pop.Scale = 0.85
		pop.Parent = button
		TweenService:Create(
			pop,
			TweenInfo.new(UiTheme.MOTION.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		if fn ~= nil then
			button.Activated:Connect(fn)
		end
		return button
	end

	local hero = scroll(page("hero"))
	local bag = scroll(page("bag"))
	local sets = scroll(page("sets"))
	local pets = scroll(page("pets"))
	local roll = scroll(page("roll"))
	local raids = scroll(page("raids"))
	local market = scroll(page("market"))
	local pass = scroll(page("pass"))
	local settingsPage = scroll(page("settings"))

	local function clear(host: ScrollingFrame)
		for _, child in ipairs(host:GetChildren()) do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end

	local function save()
		task.spawn(function()
			pcall(hooks.invoke, "SetSettings", draft)
		end)
	end

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
	end

	local function openTab(id: string, push: boolean)
		if push and stack[#stack] ~= id then
			table.insert(stack, id)
		elseif not push then
			stack = { id }
		end
		show(id)
	end

	local function paint()
		clear(hero)
		clear(bag)
		clear(sets)
		clear(pets)
		clear(roll)
		clear(raids)
		clear(market)
		clear(pass)
		clear(settingsPage)
		local level = if type(profile) == "table" then profile.level or 1 else 1
		local classId = if type(profile) == "table" then profile.classId else ""
		local classDef = Classes.get(classId)
		local classLabel = if classDef ~= nil then classDef.name else "No class"
		row(hero, string.format("Level %d", level), 1, nil)
		row(hero, "Class  " .. classLabel, 2, nil)
		if classDef ~= nil then
			for index, skill in ipairs(classDef.skills) do
				row(
					hero,
					string.format("%s  %ds  %s", skill.name, skill.cooldown, skill.note),
					10 + index,
					nil
				)
			end
			row(
				hero,
				string.format(
					"%s  %ds  %s",
					classDef.ultimate.name,
					classDef.ultimate.cooldown,
					classDef.ultimate.note
				),
				20,
				nil
			)
		end
		row(hero, "Change class", 30, function()
			clear(hero)
			for _, entry in ipairs(Classes.all()) do
				row(hero, entry.name, 1, function()
					task.spawn(function()
						pcall(hooks.invoke, "SetClass", entry.id)
					end)
				end)
			end
		end)
		local count = 0
		if type(profile) == "table" and type(profile.inventory) == "table" then
			for _, item in pairs(profile.inventory) do
				count += 1
				if count <= 12 and type(item) == "table" then
					local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
					local red, green, blue = UiTheme.rarityColor(rarity)
					local line = row(
						bag,
						string.format("%s  %s", tostring(item.name or "Item"), rarity),
						count,
						nil
					)
					line.TextColor3 = Color3.fromRGB(red, green, blue)
				end
			end
		end
		if count == 0 then
			row(bag, "Bag is empty", 1, nil)
		end
		row(bag, "Sets", 40, function()
			openTab("sets", true)
		end)
		row(bag, "Open full bag", 41, function()
			hooks.onBag()
		end)
		row(sets, "Relic sets equip from the bag. Pieces stay raid drops.", 1, nil)
		local companions = 0
		if type(profile) == "table" and type(profile.companions) == "table" then
			for _ in pairs(profile.companions) do
				companions += 1
			end
		end
		local eggs = if type(profile) == "table" then profile.eggs or 0 else 0
		row(pets, string.format("Companions %d    Eggs %d", companions, eggs), 1, nil)
		row(roll, "Roll uses the same result for the spin and the card.", 1, nil)
		row(roll, "Roll", 2, hooks.onRoll)
		local marks = if type(profile) == "table" then profile.raidMarks or 0 else 0
		row(raids, "Finder", 1, nil)
		row(raids, "Vendor", 2, nil)
		row(raids, string.format("Marks %d", marks), 3, nil)
		row(market, "Haven Market", 1, nil)
		row(market, "Open board", 2, hooks.onMarket)
		local tier = if type(profile) == "table" then profile.passTier or 0 else 0
		row(pass, string.format("Pass tier %s", tostring(tier)), 1, nil)
		row(pass, "Claim and daily stay on this tab.", 2, nil)

		local function cycle(label: string, order: number, apply: () -> ())
			row(settingsPage, label, order, function()
				apply()
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
			end
		)
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
		for _, field in ipairs({ "hero", "bag", "pets", "roll", "raids", "market" }) do
			local fieldName = field
			cycle(string.format("Hotkey %s  %s", fieldName, keys[fieldName]), keyOrder, function()
				capturing = fieldName
			end)
			keyOrder += 1
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
	end

	local function close()
		screen.Enabled = false
		panel.GroupTransparency = 1
		stack = {}
		hooks.onDim(false)
	end

	local function pop()
		if #stack > 1 then
			table.remove(stack)
			show(stack[#stack])
			return
		end
		close()
	end

	local function open(id: string)
		local was = screen.Enabled
		screen.Enabled = true
		place()
		openTab(id, false)
		paint()
		show(id)
		hooks.onDim(true)
		panel.GroupTransparency = 1
		local delay = if was then 0 else UiTheme.MOTION.stagger
		task.delay(delay, function()
			if screen.Enabled then
				TweenService:Create(
					panel,
					TweenInfo.new(
						UiTheme.MOTION.open - delay,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					),
					{ GroupTransparency = 0 }
				):Play()
			end
		end)
	end

	for index, tab in ipairs(ClientChrome.TABS) do
		local button = Instance.new("TextButton")
		button.Name = tab.id
		button.LayoutOrder = if tab.id == "settings" then 100 else index
		button.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		button.BackgroundColor3 = rgb("button")
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = UiTheme.MIN_TEXT
		button.TextColor3 = rgb("text")
		button.Text = if tab.key ~= "" then tab.label .. "  [" .. tab.key .. "]" else tab.label
		button.Parent = tabs
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local tabId = tab.id
		button.Activated:Connect(function()
			openTab(tabId, false)
			paint()
			show(tabId)
		end)
	end

	backdrop.Activated:Connect(pop)
	closeButton.Activated:Connect(pop)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if capturing ~= nil and input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode.Name
			if string.match(key, "^%a$") ~= nil or #key == 1 then
				local letter = string.upper(string.sub(key, 1, 1))
				if string.match(letter, "^%a$") ~= nil then
					draft.controls.hotkeys[capturing] = letter
					capturing = nil
					save()
					paint()
					show("settings")
				end
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if screen.Enabled then
				pop()
			end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		local pressed = string.upper(string.sub(input.KeyCode.Name, 1, 1))
		for _, tab in ipairs(ClientChrome.TABS) do
			local hotkey = draft.controls.hotkeys[tab.id]
			if type(hotkey) == "string" and hotkey == pressed then
				open(tab.id)
			end
		end
	end)

	paint()

	return {
		open = open,
		close = close,
		isOpen = function(): boolean
			return screen.Enabled
		end,
		setProfile = function(nextProfile: any)
			profile = nextProfile
			if type(nextProfile) == "table" and type(nextProfile.uiSettings) == "table" then
				draft = Settings.normalize(nextProfile.uiSettings)
				uiScale.Scale = draft.hud.scale
			end
			if screen.Enabled then
				local current = stack[#stack] or "hero"
				paint()
				show(current)
			end
		end,
	}
end

return MenuHub
