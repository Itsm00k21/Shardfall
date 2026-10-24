--!strict

--[[
	Full-bag salvage for Echo's GearSalvage remote (#388). Ghost owns this
	view. Echo's server APIs are unchanged.

	mount(parent, opts) builds these under parent (popups go on opts.host):
	  row      "GearRow": the thin action bar. The Auto-salvage pill (opens
	           the settings popover), Essence, Select, and in Select mode
	           a "Select all ≤ <rarity>" dropdown.
	  popover  "AutoPopover": the only place auto-salvage changes. A toggle
	           and a cap dropdown limited to Common or Uncommon. Turning it
	           on or raising the cap asks first ("AutoAsk").
	  bar      "SalvageBar": "Salvage N for +X Essence" and Clear. Shown
	           while Select is on.
	  confirm  "SalvageConfirm": every salvage goes through it.

	Auto-salvage is read from the profile snapshot the server last sent.
	This view keeps no copy of it, polls nothing, and sends explicit
	{enabled, rarity}. Default is Off. The client never sends a cap above
	Uncommon (GearHooks.safeCap); a saved Rare+ cap shows in the chip as it
	is, the popover shows it clamped to Uncommon with one plain line, and
	opening the popover while it is on sends the clamp once so the server
	matches the dropdown. A refused clamp is not marked sent: the pill
	stays on the server's value, the reason shows, and the next open
	tries again. A refused press leaves the label on the server's value
	and shows the reason. The chip keeps
	one width on or off so it never shoves Select.

	bulk     "BulkPicker" (Clip 9): "Salvage…" in the row on Weapons and
	         Armor opens it. "Salvage all Common", "… Uncommon and below",
	         "… Rare and below", each with the server preview's count and
	         Essence, then the usual SalvageConfirm. Locked, favorite and
	         equipped gear never counts (the server checks again).

	Equipped, locked and favorite gear cannot be picked. The server checks
	again on confirm. Nothing here costs Robux.

	opts:
	  invoke(action, payload) -> result   GearSalvage call; applies the profile.
	  getProfile() -> profile
	  onChanged()                          repaint the grid (selection changed).
	  onStatus(text, kind)
	  getTab() -> string?                  the inventory tab; bulk select
	                                       keeps to weapons or armor.
	  host                                 where popups are parented.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dropdown = require(script.Parent:WaitForChild("Dropdown"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearHooks = require(Shared:WaitForChild("GearHooks"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local GearBar = {}

-- Thin action bar: 36px controls in a 40px row.
GearBar.ROW_H = 40
GearBar.BAR_H = 48
GearBar.CONTROL_H = 36

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
	-- Auto-salvage on destroys new drops, so it reads as a warning.
	warn = Color3.fromRGB(255, 168, 48),
}

export type Opts = {
	invoke: (action: string, payload: { [string]: any }?) -> any,
	getProfile: () -> any,
	onChanged: () -> (),
	onStatus: (text: string, kind: string) -> (),
	getTab: (() -> string?)?,
	host: Instance?,
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
	return math.max(GearBar.CONTROL_H, #text * 8 + 24)
end

local function button(parent: Instance, name: string, text: string, order: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(widthFor(text), GearBar.CONTROL_H)
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

local function label(parent: Instance, name: string, text: string, order: number, color: Color3, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 20)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = Enum.Font.BuilderSans
	l.TextSize = size
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color
	l.Text = text
	l.LayoutOrder = order
	l.ZIndex = 31
	l.Parent = parent
	return l
end

local function setText(b: TextButton, text: string)
	b.Text = text
	b.Size = UDim2.fromOffset(widthFor(text), GearBar.CONTROL_H)
end

local function message(result: any, fallback: string): string
	if type(result) == "table" and type(result.error) == "string" and result.error ~= "" then
		return result.error
	end
	return fallback
end

local function panel(host: Instance, name: string, width: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(width, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = COLORS.panel
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = 30
	f.Parent = host
	corner(f, 12)
	pad(f, 14, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.gold
	stroke.Transparency = 0.5
	stroke.Thickness = 1
	stroke.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, UiTheme.PAD)
	layout.Parent = f
	return f
end

local function wideButton(parent: Instance, name: string, text: string, order: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, 0, 0, GearBar.CONTROL_H)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.BuilderSansBold
	b.TextSize = 15
	b.TextColor3 = COLORS.text
	b.Text = text
	b.ZIndex = 31
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

function GearBar.mount(parent: Instance, opts: Opts)
	local host: Instance = opts.host or parent
	local selecting = false
	local busy = false
	local selected: { [string]: boolean } = {}
	local pickIndex = 1
	local token: string? = nil
	local pendingAuto: { enabled: boolean, rarity: string }? = nil
	-- Phone width: shorter chip text, and Select mode keeps only what
	-- picking needs so the bar never scrolls sideways.
	local compact = false

	local function tab(): string?
		local getTab = opts.getTab
		if getTab == nil then
			return nil
		end
		return getTab()
	end

	-- The thin action bar. One line, no sideways scroll.
	local row = Instance.new("Frame")
	row.Name = "GearRow"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, GearBar.ROW_H)
	row.ClipsDescendants = false
	row.Parent = parent
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, UiTheme.PAD)
	rowLayout.Parent = row

	local essence = Instance.new("TextLabel")
	essence.Name = "Essence"
	essence.BackgroundColor3 = COLORS.panel
	essence.BorderSizePixel = 0
	essence.Size = UDim2.fromOffset(110, GearBar.CONTROL_H)
	essence.Font = Enum.Font.BuilderSansBold
	essence.TextSize = UiTheme.MIN_TEXT
	essence.TextColor3 = COLORS.gold
	essence.Text = "Essence 0"
	essence.LayoutOrder = 1
	essence.Parent = row
	corner(essence, 8)
	pad(essence, 10, 0)

	-- The Auto-salvage pill comes first so its real state is the first
	-- thing in the bar: amber with dark ink and a warning mark while it is
	-- on, quiet while it is off. Tapping it opens the settings popover; it
	-- never changes the setting by itself.
	local autoButton = button(row, "AutoSalvage", GearHooks.AUTO_OFF, 0, COLORS.buttonDim)
	autoButton.Font = Enum.Font.BuilderSansExtraBold
	local autoCorner = autoButton:FindFirstChildOfClass("UICorner")
	if autoCorner ~= nil then
		autoCorner.CornerRadius = UDim.new(0, GearBar.CONTROL_H // 2)
	end
	local autoPad = autoButton:FindFirstChildOfClass("UIPadding")
	local autoStroke = Instance.new("UIStroke")
	autoStroke.Name = "AutoStroke"
	autoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	autoStroke.Thickness = 2
	autoStroke.Color = COLORS.warn
	autoStroke.Enabled = false
	autoStroke.Parent = autoButton
	local autoMark = Instance.new("TextLabel")
	autoMark.Name = "AutoMark"
	autoMark.BackgroundTransparency = 1
	autoMark.Size = UDim2.fromOffset(24, GearBar.CONTROL_H)
	autoMark.Position = UDim2.fromOffset(-6, 0)
	autoMark.Font = Enum.Font.BuilderSansExtraBold
	autoMark.TextSize = 16
	autoMark.TextColor3 = COLORS.ink
	autoMark.Text = "⚠"
	autoMark.Visible = false
	autoMark.Parent = autoButton
	local selectButton = button(row, "SelectMode", "Select", 4, COLORS.button)
	-- [Ghost] Clip 9: manual bulk salvage, one obvious button.
	local bulkButton = button(row, "BulkSalvage", GearHooks.BULK_BUTTON, 3, COLORS.button)

	local pickOptions = {}
	for _, cap in ipairs(PICK_CAPS) do
		table.insert(pickOptions, { value = cap, text = cap })
	end
	local pickDrop: any = nil

	-- Settings popover. The only place auto-salvage changes.
	local popover = panel(host, "AutoPopover", 320)
	local popTitle = label(popover, "AutoTitle", "Auto-salvage", 1, COLORS.text, 18)
	popTitle.Font = Enum.Font.BuilderSansBold
	label(
		popover,
		"AutoHelp",
		"Destroys new drops at or below the cap for Essence. Gear you already own is not touched.",
		2,
		COLORS.muted,
		13
	)
	local toggleRow = Instance.new("Frame")
	toggleRow.Name = "AutoToggleRow"
	toggleRow.BackgroundTransparency = 1
	toggleRow.Size = UDim2.new(1, 0, 0, GearBar.CONTROL_H)
	toggleRow.LayoutOrder = 3
	toggleRow.ZIndex = 31
	toggleRow.Parent = popover
	local toggleLayout = Instance.new("UIListLayout")
	toggleLayout.FillDirection = Enum.FillDirection.Horizontal
	toggleLayout.Padding = UDim.new(0, UiTheme.PAD)
	toggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	toggleLayout.Parent = toggleRow
	local toggleButton = button(toggleRow, "AutoToggle", "Off", 1, COLORS.buttonDim)
	toggleButton.Size = UDim2.fromOffset(84, GearBar.CONTROL_H)
	toggleButton.ZIndex = 31
	local capDrop = Dropdown.new(toggleRow, {
		name = "AutoCapPick",
		prefix = "Cap",
		options = {
			{ value = "Common", text = "Common" },
			{ value = "Uncommon", text = "Uncommon" },
		},
		value = "Common",
		host = popover,
		width = 180,
		height = GearBar.CONTROL_H,
		order = 2,
		colors = COLORS,
		onChange = function(_: any) end,
	})
	capDrop.button.ZIndex = 31
	-- One plain line under the cap. No "saved cap is Rare" argument with the
	-- dropdown and no Lower button: a higher saved cap is clamped silently.
	local capNote = label(popover, "AutoCapNote", GearHooks.capNote(nil), 4, COLORS.muted, 13)
	local ask = Instance.new("Frame")
	ask.Name = "AutoAsk"
	ask.BackgroundColor3 = Color3.fromRGB(60, 34, 30)
	ask.BorderSizePixel = 0
	ask.Size = UDim2.fromScale(1, 0)
	ask.AutomaticSize = Enum.AutomaticSize.Y
	ask.LayoutOrder = 6
	ask.Visible = false
	ask.ZIndex = 31
	ask.Parent = popover
	corner(ask, 8)
	pad(ask, 10, 8)
	local askLayout = Instance.new("UIListLayout")
	askLayout.SortOrder = Enum.SortOrder.LayoutOrder
	askLayout.Padding = UDim.new(0, 6)
	askLayout.Parent = ask
	local askText = label(ask, "AutoAskText", "", 1, COLORS.text, 14)
	askText.ZIndex = 32
	local askYes = wideButton(ask, "AutoYes", "Turn on", 2, COLORS.danger)
	askYes.ZIndex = 32
	local askNo = wideButton(ask, "AutoNo", "Cancel", 3, COLORS.buttonDim)
	askNo.ZIndex = 32
	local popClose = wideButton(popover, "AutoClose", "Done", 7, COLORS.button)

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
	salvageButton.Size = UDim2.new(1, -(96 + UiTheme.PAD), 0, GearBar.CONTROL_H)
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
	clearButton.Size = UDim2.fromOffset(96, GearBar.CONTROL_H)
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
	local confirm = panel(host, "SalvageConfirm", 360)
	local confirmText = label(confirm, "Text", "", 1, COLORS.text, 15)
	local confirmYes = wideButton(confirm, "ConfirmSalvage", "Confirm", 2, COLORS.danger)
	local confirmNo = wideButton(confirm, "CancelSalvage", "Cancel", 3, COLORS.buttonDim)

	-- Bulk picker. Rows fill from the server preview; the client estimate
	-- shows until it answers.
	local bulk = panel(host, "BulkPicker", 340)
	local bulkTitle = label(bulk, "BulkTitle", "Salvage gear", 1, COLORS.text, 18)
	bulkTitle.Font = Enum.Font.BuilderSansBold
	label(
		bulk,
		"BulkHelp",
		"Weapons and Armor in your Bag. Locked, favorite and equipped gear is never salvaged.",
		2,
		COLORS.muted,
		13
	)
	local bulkRows: { [string]: TextButton } = {}
	local bulkSeen: { [string]: { count: number, gain: number, server: boolean } } = {}
	for index, cap in ipairs(GearHooks.BULK_CAPS) do
		local rowButton = wideButton(bulk, "Bulk" .. cap, GearHooks.bulkTitle(cap), 2 + index, COLORS.buttonDim)
		rowButton.Size = UDim2.new(1, 0, 0, 52)
		rowButton.TextWrapped = true
		rowButton:SetAttribute("Cap", cap)
		bulkRows[cap] = rowButton
	end
	local bulkClose = wideButton(bulk, "BulkCancel", "Cancel", 9, COLORS.button)

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

	local function paintPopover(profile: any)
		local on = GearHooks.autoRarity(profile) ~= nil
		toggleButton.Text = if on then "On" else "Off"
		toggleButton.BackgroundColor3 = if on then COLORS.warn else COLORS.buttonDim
		toggleButton.TextColor3 = if on then COLORS.ink else COLORS.text
		toggleButton:SetAttribute("On", on)
		capDrop.set(GearHooks.safeCap(GearHooks.autoCapName(profile)))
		capNote.Text = GearHooks.capNote(profile)
	end

	local function paintBulk(profile: any)
		for cap, rowButton in pairs(bulkRows) do
			local seen = bulkSeen[cap]
			local count, gain
			if seen ~= nil then
				count, gain = seen.count, seen.gain
			else
				count, gain = GearHooks.bulkEstimate(profile, cap)
			end
			rowButton.Text = GearHooks.bulkTitle(cap) .. "\n" .. GearHooks.bulkLine(count, gain)
			rowButton:SetAttribute("Count", count)
			rowButton:SetAttribute("Gain", gain)
			rowButton:SetAttribute("Server", seen ~= nil and seen.server)
			rowButton.BackgroundColor3 = if count > 0 then COLORS.danger else COLORS.buttonDim
			rowButton.AutoButtonColor = count > 0
		end
	end

	local function paint()
		local profile = opts.getProfile()
		prune(profile)
		local held = if type(profile) == "table" and type(profile.gearEssence) == "number"
			then math.max(0, math.floor(profile.gearEssence))
			else 0
		essence.Text = string.format("Essence %d", held)
		local chipText, on = GearHooks.autoChip(profile)
		if compact then
			chipText = if on then "Auto: On" else "Auto: Off"
			essence.Size = UDim2.fromOffset(math.max(80, #essence.Text * 7 + 20), GearBar.CONTROL_H)
		else
			essence.Size = UDim2.fromOffset(110, GearBar.CONTROL_H)
		end
		essence.Visible = not (compact and selecting)
		autoButton.Visible = not (compact and selecting)
		-- One width on or off (room for the warning mark included), so
		-- turning it on never shoves Select along the row. A phone drops
		-- the gear glyph to keep Salvage… on the row.
		if compact then
			autoButton.Text = chipText
			autoButton.Size = UDim2.fromOffset(widthFor(GearHooks.CHIP_WIDEST_COMPACT), GearBar.CONTROL_H)
		else
			autoButton.Text = chipText .. "  ⚙"
			autoButton.Size = UDim2.fromOffset(widthFor(GearHooks.CHIP_WIDEST .. "  ⚙") + 18, GearBar.CONTROL_H)
		end
		local where = tab()
		-- [Ghost] Clip 11: Select on Pets greyed every pet as "Not gear" and
		-- doubled the warnings. Select only lives on tabs that can salvage,
		-- and leaving one drops Select mode.
		local gearTab = where == nil or where == "weapons" or where == "armor"
		if selecting and not gearTab then
			selecting = false
			table.clear(selected)
			confirm.Visible = false
			token = nil
		end
		selectButton.Visible = gearTab
		bulkButton.Visible = not selecting and gearTab
		bulkButton.Size = UDim2.fromOffset(if compact then 84 else widthFor(GearHooks.BULK_BUTTON), GearBar.CONTROL_H)
		if compact and not selecting and bulkButton.Visible then
			-- A big Essence number would push the row sideways on a phone;
			-- the picker shows the balance instead.
			local room = if row.AbsoluteSize.X > 0 then row.AbsoluteSize.X else 370
			local used = autoButton.Size.X.Offset
				+ essence.Size.X.Offset
				+ bulkButton.Size.X.Offset
				+ selectButton.Size.X.Offset
				+ 3 * UiTheme.PAD
			if used > room then
				essence.Visible = false
			end
		end
		bulkTitle.Text = string.format("Salvage gear  ·  Essence %d", held)
		if not bulkButton.Visible and bulk.Visible then
			bulk.Visible = false
		end
		paintBulk(profile)
		autoButton.BackgroundColor3 = if on then COLORS.warn else COLORS.buttonDim
		autoButton.TextColor3 = if on then COLORS.ink else COLORS.text
		autoButton:SetAttribute("AutoOn", on)
		autoStroke.Enabled = on
		autoMark.Visible = on
		if autoPad ~= nil then
			autoPad.PaddingLeft = UDim.new(0, if on then 26 else 10)
		end
		paintPopover(profile)
		setText(selectButton, if selecting then "Done" else "Select")
		selectButton.BackgroundColor3 = if selecting then COLORS.gold else COLORS.button
		selectButton.TextColor3 = if selecting then COLORS.ink else COLORS.text
		if pickDrop ~= nil then
			pickDrop.button.Visible = selecting
			pickDrop.set(PICK_CAPS[pickIndex] or "Common")
			if not selecting then
				pickDrop.close()
			end
		end
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

	local function hideAsk()
		ask.Visible = false
		pendingAuto = nil
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

	-- Every auto-salvage change goes through here. The cap is clamped to
	-- Common or Uncommon before it leaves the client.
	local function sendAuto(want: { enabled: boolean, rarity: string })
		local safe = { enabled = want.enabled == true, rarity = GearHooks.safeCap(want.rarity) }
		call("auto", safe, function(result)
			if type(result) ~= "table" or result.ok ~= true then
				opts.onStatus(message(result, "Could not change auto-salvage."), "error")
				return
			end
			opts.onStatus(if type(result.message) == "string" then result.message else "Saved.", "ok")
		end)
	end

	-- Ask first when the change turns it on or raises the cap.
	local function requestAuto(want: { enabled: boolean, rarity: string })
		local text = GearHooks.autoAsk(opts.getProfile(), want)
		if text == nil then
			hideAsk()
			sendAuto(want)
			return
		end
		pendingAuto = { enabled = want.enabled, rarity = GearHooks.safeCap(want.rarity) }
		askText.Text = text
		askYes.Text = if GearHooks.autoRarity(opts.getProfile()) == nil then "Turn on" else "Raise cap"
		ask.Visible = true
	end

	local clampCap: () -> () = function() end

	local function openPopover()
		Dropdown.closeAll(host)
		hideAsk()
		bulk.Visible = false
		paint()
		popover.Visible = true
		clampCap()
	end

	local function closePopover()
		hideAsk()
		capDrop.close()
		popover.Visible = false
	end

	autoButton.MouseButton1Click:Connect(function()
		if popover.Visible then
			closePopover()
		else
			openPopover()
		end
	end)

	toggleButton.MouseButton1Click:Connect(function()
		local profile = opts.getProfile()
		local on = GearHooks.autoRarity(profile) ~= nil
		requestAuto(GearHooks.autoWant(profile, not on, capDrop.value()))
	end)

	-- The cap dropdown sends only when it changed. Raising it while on asks.
	local capChanged = function(value: any)
		local profile = opts.getProfile()
		local on = GearHooks.autoRarity(profile) ~= nil
		requestAuto(GearHooks.autoWant(profile, on, value))
	end
	for _, child in ipairs(capDrop.list:GetChildren()) do
		if child:IsA("TextButton") then
			local key = child:GetAttribute("Key")
			child.MouseButton1Click:Connect(function()
				if key ~= GearHooks.safeCap(GearHooks.autoCapName(opts.getProfile())) then
					capChanged(key)
				end
			end)
		end
	end

	-- A saved Rare+ cap that is on: opening the popover sends the clamp
	-- once, quietly, so the server stops salvaging what the dropdown says
	-- it keeps. Mounting and repaints never send. A refused clamp is not
	-- treated as sent, so the next open of the pill tries again.
	local clampSent = false
	clampCap = function()
		local profile = opts.getProfile()
		if busy or clampSent or not GearHooks.capUnsafe(profile) or GearHooks.autoRarity(profile) == nil then
			return
		end
		clampSent = true
		call("auto", { enabled = true, rarity = GearHooks.safeCap(GearHooks.autoCapName(profile)) }, function(result)
			local stillUnsafe = GearHooks.capUnsafe(opts.getProfile())
			if type(result) ~= "table" or result.ok ~= true or stillUnsafe then
				clampSent = false
				opts.onStatus(message(result, "Could not change auto-salvage."), "error")
			end
		end)
	end

	-- Bulk picker: one server preview per row, one at a time.
	local function refreshBulk()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			for _, cap in ipairs(GearHooks.BULK_CAPS) do
				if not bulk.Visible then
					break
				end
				local ok, result = pcall(opts.invoke, "preview", { rarity = cap })
				if ok and type(result) == "table" then
					if result.ok == true then
						bulkSeen[cap] = {
							count = if type(result.count) == "number" then math.floor(result.count) else 0,
							gain = if type(result.gain) == "number" then math.floor(result.gain) else 0,
							server = true,
						}
					elseif type(result.error) == "string" and string.find(result.error, "Nothing", 1, true) then
						bulkSeen[cap] = { count = 0, gain = 0, server = true }
					end
				end
			end
			busy = false
			paint()
		end)
	end

	local function openBulk()
		Dropdown.closeAll(host)
		closePopover()
		hideConfirm()
		table.clear(bulkSeen)
		bulk.Visible = true
		paint()
		refreshBulk()
	end

	local function bulkPick(cap: string)
		local count = GearHooks.bulkEstimate(opts.getProfile(), cap)
		local seen = bulkSeen[cap]
		if (seen ~= nil and seen.count <= 0) or (seen == nil and count <= 0) then
			opts.onStatus(GearHooks.bulkTitle(cap) .. ": nothing to salvage.", "info")
			return
		end
		-- A fresh preview: the server keeps one token per player, so the
		-- picker's last row preview is not this row's.
		call("preview", { rarity = cap }, function(result)
			if type(result) ~= "table" or result.ok ~= true or type(result.token) ~= "string" then
				opts.onStatus(message(result, "Could not check that salvage."), "error")
				return
			end
			token = result.token
			local n = if type(result.count) == "number" then math.floor(result.count) else 0
			local gain = if type(result.gain) == "number" then math.floor(result.gain) else 0
			bulkSeen[cap] = { count = n, gain = gain, server = true }
			bulk.Visible = false
			confirmText.Text = string.format(
				"%s: salvage %d piece%s for +%d Essence? Locked, favorite and equipped gear stays. This cannot be undone.",
				GearHooks.bulkTitle(cap),
				n,
				if n == 1 then "" else "s",
				gain
			)
			confirm.Visible = true
		end)
	end

	bulkButton.MouseButton1Click:Connect(function()
		if bulk.Visible then
			bulk.Visible = false
		else
			openBulk()
		end
	end)
	for cap, rowButton in pairs(bulkRows) do
		rowButton.MouseButton1Click:Connect(function()
			bulkPick(cap)
		end)
	end
	bulkClose.MouseButton1Click:Connect(function()
		bulk.Visible = false
	end)

	askYes.MouseButton1Click:Connect(function()
		local want = pendingAuto
		hideAsk()
		if want ~= nil then
			sendAuto(want)
		end
	end)
	askNo.MouseButton1Click:Connect(function()
		hideAsk()
		paint()
	end)
	popClose.MouseButton1Click:Connect(closePopover)

	selectButton.MouseButton1Click:Connect(function()
		selecting = not selecting
		if not selecting then
			table.clear(selected)
			hideConfirm()
		end
		paint()
		opts.onChanged()
	end)

	local function selectUpTo(cap: string)
		local where = tab()
		if where ~= nil and where ~= "weapons" and where ~= "armor" then
			opts.onStatus("Open Weapons or Armor to bulk select gear.", "info")
			return
		end
		local why = GearHooks.pickEmpty(opts.getProfile(), cap, where)
		if why ~= nil then
			opts.onStatus(why, "info")
			return
		end
		local kind = if where == "weapons" then "Weapon" elseif where == "armor" then "Armor" else nil
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
					if
						type(uid) == "string"
						and item ~= nil
						and (kind == nil or item.kind == kind)
						and GearHooks.pickBlock(profile, item) == nil
					then
						selected[uid] = true
						added += 1
					end
				end
			end
			if added == 0 then
				opts.onStatus(
					GearHooks.pickEmpty(profile, cap, where) or string.format("Nothing at or below %s to salvage.", cap),
					"info"
				)
			else
				opts.onStatus(string.format("Selected %d at or below %s.", added, cap), "ok")
			end
			opts.onChanged()
		end)
	end

	pickDrop = Dropdown.new(row, {
		name = "SelectUpTo",
		prefix = "Select all ≤",
		options = pickOptions,
		value = "Common",
		host = host,
		width = 210,
		height = GearBar.CONTROL_H,
		order = 5,
		colors = COLORS,
		always = true,
		onChange = function(value: any)
			for index, cap in ipairs(PICK_CAPS) do
				if cap == value then
					pickIndex = index
				end
			end
			selectUpTo(PICK_CAPS[pickIndex] or "Common")
		end,
	})
	pickDrop.button.Visible = false

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
		popover = popover,
		bulk = bulk,
		bulkButton = bulkButton,
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

	function handle.count(): (number, number)
		return GearHooks.estimate(opts.getProfile(), picked())
	end

	function handle.refresh()
		paint()
	end

	function handle.openBulk()
		openBulk()
	end

	function handle.setCompact(on: boolean)
		if compact ~= on then
			compact = on
			paint()
		end
	end

	function handle.openAuto()
		openPopover()
	end

	function handle.closePopups()
		closePopover()
		bulk.Visible = false
		Dropdown.closeAll(host)
	end

	function handle.rarityName(): string
		return PICK_CAPS[pickIndex] or Rarities.ORDER[1]
	end

	paint()
	return handle
end

return GearBar
