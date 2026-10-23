--!strict

--[[
	Full-bag salvage for Echo's GearSalvage remote (#388). Ghost owns this
	view. Echo's server APIs are unchanged.

	mount(parent, opts) builds three pieces under parent. The caller places
	them:
	  row      "GearRow": Essence, the Auto-salvage toggle and its cap,
	           Select, and "Select all at or below <rarity>".
	  bar      "SalvageBar": "Salvage N for +X Essence" and Clear. Shown
	           while Select is on.
	  confirm  "SalvageConfirm": every salvage goes through it.

	Auto-salvage is read from the profile snapshot the server last sent.
	This view keeps no copy of it, polls nothing, and sends explicit
	{enabled, rarity}. Default is Off. A refused press leaves the label on
	the server's value and shows the reason.

	Equipped, locked and favorite gear cannot be picked. The server checks
	again on confirm. Nothing here costs Robux.

	opts:
	  invoke(action, payload) -> result   GearSalvage call; applies the profile.
	  getProfile() -> profile
	  onChanged()                          repaint the grid (selection changed).
	  onStatus(text, kind)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearHooks = require(Shared:WaitForChild("GearHooks"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local GearBar = {}

GearBar.ROW_H = 52
GearBar.BAR_H = 56

local PICK_CAPS = { "Common", "Uncommon", "Rare", "Epic" }

local COLORS = {
	panel = Color3.fromRGB(28, 24, 40),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(176, 168, 198),
	gold = Color3.fromRGB(255, 196, 64),
	ink = Color3.fromRGB(32, 22, 10),
	danger = Color3.fromRGB(230, 80, 96),
	button = Color3.fromRGB(108, 78, 196),
	buttonDim = Color3.fromRGB(54, 46, 78),
	on = Color3.fromRGB(70, 140, 96),
}

export type Opts = {
	invoke: (action: string, payload: { [string]: any }?) -> any,
	getProfile: () -> any,
	onChanged: () -> (),
	onStatus: (text: string, kind: string) -> (),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function pad(parent: Instance, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.Parent = parent
end

local function widthFor(text: string): number
	return math.max(UiTheme.TOUCH, #text * 8 + 28)
end

local function button(parent: Instance, name: string, text: string, order: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(widthFor(text), UiTheme.TOUCH)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.BuilderSansBold
	b.TextSize = UiTheme.MIN_TEXT
	b.TextColor3 = COLORS.text
	b.Text = text
	b.AutoButtonColor = true
	b.LayoutOrder = order
	b.Parent = parent
	corner(b, 8)
	pad(b, 10, 0)
	return b
end

local function setText(b: TextButton, text: string)
	b.Text = text
	b.Size = UDim2.fromOffset(widthFor(text), UiTheme.TOUCH)
end

local function message(result: any, fallback: string): string
	if type(result) == "table" and type(result.error) == "string" and result.error ~= "" then
		return result.error
	end
	return fallback
end

function GearBar.mount(parent: Instance, opts: Opts)
	local selecting = false
	local busy = false
	local selected: { [string]: boolean } = {}
	local pickIndex = 1
	local token: string? = nil

	-- Settings row: one line that scrolls sideways on a phone.
	local row = Instance.new("ScrollingFrame")
	row.Name = "GearRow"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, GearBar.ROW_H)
	row.ScrollBarThickness = 4
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.fromOffset(0, 0)
	row.ClipsDescendants = true
	row.Parent = parent
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, UiTheme.PAD)
	rowLayout.Parent = row
	pad(row, 2, 0)

	local essence = Instance.new("TextLabel")
	essence.Name = "Essence"
	essence.BackgroundColor3 = COLORS.panel
	essence.BorderSizePixel = 0
	essence.Size = UDim2.fromOffset(120, UiTheme.TOUCH)
	essence.Font = Enum.Font.BuilderSansBold
	essence.TextSize = UiTheme.MIN_TEXT
	essence.TextColor3 = COLORS.gold
	essence.Text = "Essence 0"
	essence.LayoutOrder = 1
	essence.Parent = row
	corner(essence, 8)
	pad(essence, 10, 0)

	local autoButton = button(row, "AutoSalvage", GearHooks.AUTO_OFF, 2, COLORS.buttonDim)
	local capButton = button(row, "AutoCap", GearHooks.capLabel(nil), 3, COLORS.buttonDim)
	local selectButton = button(row, "SelectMode", "Select", 4, COLORS.button)
	local pickButton = button(row, "SelectUpTo", "Select all at or below Common", 5, COLORS.buttonDim)
	local pickRarity = button(row, "SelectRarity", "Common", 6, COLORS.buttonDim)
	pickButton.Visible = false
	pickRarity.Visible = false

	-- Action bar under the grid.
	local bar = Instance.new("Frame")
	bar.Name = "SalvageBar"
	bar.BackgroundColor3 = COLORS.panel
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, GearBar.BAR_H)
	bar.Visible = false
	bar.Parent = parent
	corner(bar, 10)
	pad(bar, 6, 6)
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Padding = UDim.new(0, UiTheme.PAD)
	barLayout.Parent = bar
	local salvageButton = Instance.new("TextButton")
	salvageButton.Name = "SalvageSelected"
	salvageButton.Size = UDim2.new(1, -(96 + UiTheme.PAD), 0, UiTheme.TOUCH)
	salvageButton.BackgroundColor3 = COLORS.buttonDim
	salvageButton.BorderSizePixel = 0
	salvageButton.Font = Enum.Font.BuilderSansBold
	salvageButton.TextSize = 15
	salvageButton.TextColor3 = COLORS.text
	salvageButton.TextTruncate = Enum.TextTruncate.AtEnd
	salvageButton.Text = GearHooks.PICK_NONE
	salvageButton.LayoutOrder = 1
	salvageButton.Parent = bar
	corner(salvageButton, 8)
	pad(salvageButton, 10, 0)
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearSelection"
	clearButton.Size = UDim2.fromOffset(96, UiTheme.TOUCH)
	clearButton.BackgroundColor3 = COLORS.buttonDim
	clearButton.BorderSizePixel = 0
	clearButton.Font = Enum.Font.BuilderSansBold
	clearButton.TextSize = UiTheme.MIN_TEXT
	clearButton.TextColor3 = COLORS.text
	clearButton.Text = "Clear"
	clearButton.LayoutOrder = 2
	clearButton.Parent = bar
	corner(clearButton, 8)

	-- Confirm. Every salvage stops here first.
	local confirm = Instance.new("Frame")
	confirm.Name = "SalvageConfirm"
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.fromScale(0.9, 0)
	confirm.AutomaticSize = Enum.AutomaticSize.Y
	confirm.BackgroundColor3 = COLORS.panel
	confirm.BorderSizePixel = 0
	confirm.Visible = false
	confirm.ZIndex = 20
	confirm.Parent = parent
	corner(confirm, 12)
	pad(confirm, 14, 14)
	local confirmLayout = Instance.new("UIListLayout")
	confirmLayout.SortOrder = Enum.SortOrder.LayoutOrder
	confirmLayout.Padding = UDim.new(0, UiTheme.PAD)
	confirmLayout.Parent = confirm
	local confirmText = Instance.new("TextLabel")
	confirmText.Name = "Text"
	confirmText.BackgroundTransparency = 1
	confirmText.Size = UDim2.new(1, 0, 0, 44)
	confirmText.AutomaticSize = Enum.AutomaticSize.Y
	confirmText.Font = Enum.Font.BuilderSans
	confirmText.TextSize = 15
	confirmText.TextWrapped = true
	confirmText.TextXAlignment = Enum.TextXAlignment.Left
	confirmText.TextColor3 = COLORS.text
	confirmText.Text = ""
	confirmText.ZIndex = 21
	confirmText.LayoutOrder = 1
	confirmText.Parent = confirm
	local confirmYes = Instance.new("TextButton")
	confirmYes.Name = "ConfirmSalvage"
	confirmYes.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
	confirmYes.BackgroundColor3 = COLORS.danger
	confirmYes.BorderSizePixel = 0
	confirmYes.Font = Enum.Font.BuilderSansBold
	confirmYes.TextSize = 15
	confirmYes.TextColor3 = COLORS.text
	confirmYes.Text = "Confirm"
	confirmYes.ZIndex = 21
	confirmYes.LayoutOrder = 2
	confirmYes.Parent = confirm
	corner(confirmYes, 8)
	local confirmNo = Instance.new("TextButton")
	confirmNo.Name = "CancelSalvage"
	confirmNo.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
	confirmNo.BackgroundColor3 = COLORS.buttonDim
	confirmNo.BorderSizePixel = 0
	confirmNo.Font = Enum.Font.BuilderSansBold
	confirmNo.TextSize = 15
	confirmNo.TextColor3 = COLORS.text
	confirmNo.Text = "Cancel"
	confirmNo.ZIndex = 21
	confirmNo.LayoutOrder = 3
	confirmNo.Parent = confirm
	corner(confirmNo, 8)

	local function picked(): { string }
		local list = {}
		for uid in pairs(selected) do
			table.insert(list, uid)
		end
		table.sort(list)
		return list
	end

	local function prune(profile: any)
		local inventory = if type(profile) == "table" and type(profile.inventory) == "table"
			then profile.inventory
			else {}
		for uid in pairs(selected) do
			local item = inventory[uid]
			if item == nil or GearHooks.pickBlock(profile, item) ~= nil then
				selected[uid] = nil
			end
		end
	end

	local function paint()
		local profile = opts.getProfile()
		prune(profile)
		local held = if type(profile) == "table" and type(profile.gearEssence) == "number"
			then math.max(0, math.floor(profile.gearEssence))
			else 0
		essence.Text = string.format("Essence %d", held)
		local on = GearHooks.autoRarity(profile) ~= nil
		setText(autoButton, GearHooks.autoLabel(profile))
		autoButton.BackgroundColor3 = if on then COLORS.on else COLORS.buttonDim
		setText(capButton, GearHooks.capLabel(profile))
		setText(selectButton, if selecting then "Done" else "Select")
		selectButton.BackgroundColor3 = if selecting then COLORS.gold else COLORS.button
		selectButton.TextColor3 = if selecting then COLORS.ink else COLORS.text
		local cap = PICK_CAPS[pickIndex] or "Common"
		setText(pickButton, "Select all at or below " .. cap)
		setText(pickRarity, cap)
		pickButton.Visible = selecting
		pickRarity.Visible = selecting
		bar.Visible = selecting
		local count, gain = GearHooks.estimate(profile, picked())
		salvageButton.Text = GearHooks.salvageLabel(count, gain)
		salvageButton.BackgroundColor3 = if count > 0 then COLORS.danger else COLORS.buttonDim
		salvageButton.AutoButtonColor = count > 0
	end

	local function hideConfirm()
		confirm.Visible = false
		token = nil
	end

	-- One request at a time. A second tap while one is out is dropped, so a
	-- double fire cannot flip a setting twice.
	local function call(action: string, payload: { [string]: any }?, done: (any) -> ())
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, result = pcall(opts.invoke, action, payload)
			busy = false
			if not ok then
				result = { ok = false, error = tostring(result) }
			end
			done(result)
			paint()
		end)
	end

	autoButton.MouseButton1Click:Connect(function()
		local want = GearHooks.autoToggle(opts.getProfile())
		call("auto", { enabled = want.enabled, rarity = want.rarity }, function(result)
			if type(result) ~= "table" or result.ok ~= true then
				opts.onStatus(message(result, "Could not change auto-salvage."), "error")
				return
			end
			opts.onStatus(if type(result.message) == "string" then result.message else "Saved.", "ok")
		end)
	end)

	capButton.MouseButton1Click:Connect(function()
		local want = GearHooks.autoCap(opts.getProfile())
		call("auto", { enabled = want.enabled, rarity = want.rarity }, function(result)
			if type(result) ~= "table" or result.ok ~= true then
				opts.onStatus(message(result, "Could not change auto-salvage."), "error")
				return
			end
			opts.onStatus(if type(result.message) == "string" then result.message else "Saved.", "ok")
		end)
	end)

	selectButton.MouseButton1Click:Connect(function()
		selecting = not selecting
		if not selecting then
			table.clear(selected)
			hideConfirm()
		end
		paint()
		opts.onChanged()
	end)

	pickRarity.MouseButton1Click:Connect(function()
		pickIndex = (pickIndex % #PICK_CAPS) + 1
		paint()
	end)

	pickButton.MouseButton1Click:Connect(function()
		local cap = PICK_CAPS[pickIndex] or "Common"
		call("preview", { rarity = cap }, function(result)
			if type(result) ~= "table" or result.ok ~= true then
				opts.onStatus(message(result, "Could not check the Bag."), "error")
				return
			end
			local profile = opts.getProfile()
			local added = 0
			if type(result.uids) == "table" then
				for _, uid in ipairs(result.uids) do
					local item = if type(profile) == "table" and type(profile.inventory) == "table"
						then profile.inventory[uid]
						else nil
					if type(uid) == "string" and item ~= nil and GearHooks.pickBlock(profile, item) == nil then
						selected[uid] = true
						added += 1
					end
				end
			end
			if added == 0 then
				opts.onStatus(string.format("Nothing at or below %s to salvage.", cap), "info")
			else
				opts.onStatus(string.format("Selected %d at or below %s.", added, cap), "ok")
			end
			opts.onChanged()
		end)
	end)

	clearButton.MouseButton1Click:Connect(function()
		table.clear(selected)
		paint()
		opts.onChanged()
	end)

	salvageButton.MouseButton1Click:Connect(function()
		local list = picked()
		local count = GearHooks.estimate(opts.getProfile(), list)
		if count <= 0 then
			opts.onStatus("Tap gear to select it first.", "info")
			return
		end
		call("preview", { uids = list }, function(result)
			if type(result) ~= "table" or result.ok ~= true or type(result.token) ~= "string" then
				opts.onStatus(message(result, "Could not check that salvage."), "error")
				return
			end
			token = result.token
			local n = if type(result.count) == "number" then math.floor(result.count) else count
			local gain = if type(result.gain) == "number" then math.floor(result.gain) else 0
			local text = string.format("Salvage %d for +%d Essence? This cannot be undone.", n, gain)
			if n < #list then
				text ..= string.format(" %d picked item(s) are protected and stay.", #list - n)
			end
			confirmText.Text = text
			confirm.Visible = true
		end)
	end)

	confirmNo.MouseButton1Click:Connect(hideConfirm)

	confirmYes.MouseButton1Click:Connect(function()
		local held = token
		if held == nil then
			hideConfirm()
			return
		end
		confirm.Visible = false
		call("confirm", { token = held }, function(result)
			token = nil
			if type(result) ~= "table" or result.ok ~= true then
				opts.onStatus(message(result, "Could not salvage that."), "error")
				return
			end
			if type(result.uids) == "table" then
				for _, uid in ipairs(result.uids) do
					selected[uid] = nil
				end
			end
			local count = if type(result.count) == "number" then result.count else 0
			local gained = if type(result.gained) == "number" then result.gained else 0
			opts.onStatus(
				if type(result.message) == "string"
					then result.message
					else string.format("Salvaged %d for %d Essence.", count, gained),
				"ok"
			)
			opts.onChanged()
		end)
	end)

	local handle = {
		row = row,
		bar = bar,
		confirm = confirm,
	}

	function handle.selecting(): boolean
		return selecting
	end

	function handle.isSelected(uid: string): boolean
		return selected[uid] == true
	end

	-- Card tap in Select mode. Returns false and the reason when blocked.
	function handle.toggle(uid: string): (boolean, string?)
		local profile = opts.getProfile()
		local item = if type(profile) == "table" and type(profile.inventory) == "table"
			then profile.inventory[uid]
			else nil
		local why = GearHooks.pickBlock(profile, item)
		if why ~= nil then
			selected[uid] = nil
			paint()
			return false, why
		end
		selected[uid] = if selected[uid] == true then nil else true
		paint()
		return true, nil
	end

	function handle.blockFor(uid: string): string?
		local profile = opts.getProfile()
		local item = if type(profile) == "table" and type(profile.inventory) == "table"
			then profile.inventory[uid]
			else nil
		return GearHooks.pickBlock(profile, item)
	end

	function handle.refresh()
		paint()
	end

	function handle.rarityName(): string
		return PICK_CAPS[pickIndex] or Rarities.ORDER[1]
	end

	paint()
	return handle
end

return GearBar
