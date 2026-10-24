--!strict

--[[
	Shard Core card for the selected weapon (#389). Ghost owns this view.
	Echo's server and config are unchanged: the numbers come from
	Shared.Config.ShardCore and a feed is Echo's FeedShardCore remote.

	build(parent, opts) adds one "CoreCard" frame to parent (which should
	have a UIListLayout). Layout is UIListLayout + AutomaticSize only, so
	nothing overlaps at any width.

	  CoreHeader  "Shard Core  Lv 1/5", taps collapse/expand.
	  CoreBody    progress pips, Essence and next cost, perk ladder,
	              one "Feed N Essence" button for THIS weapon's core.
	  CoreConfirm inline under Feed: "Spend N Essence on X core?" with
	              Feed / Cancel. Nothing is spent before the confirm.
	After a feed: a toast "Bramble Fang core Lv 1: +1% crit chance", and
	the next paint lights the new pip and the unlocked perk row (Fresh).
	Clip 4 (Oct 23): the all-cores picker is gone; only the selected
	weapon's core is fed here.

	opts:
	  uid       the selected weapon
	  profile   the latest profile snapshot (read only)
	  order     LayoutOrder in parent
	  open      start expanded (default true)
	  onToggle(open)
	  invoke(action, uid) -> answer   yields; "FeedShardCore"
	  onFed(answer, uid)              the caller mirrors and repaints
	  onStatus(text, kind)
	  fonts { header, body }?  colors?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShardCore = require(Shared:WaitForChild("Config"):WaitForChild("ShardCore"))
local GearHooks = require(Shared:WaitForChild("GearHooks"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local CoreCard = {}

CoreCard.FEED = "FeedShardCore"
-- How long the new pip and perk row stay lit after a feed.
CoreCard.FRESH_SECONDS = 2.5

-- The last feed this client saw: { uid, level, at }. The host repaints
-- after a feed, so the next build reads this to light the new level.
local fresh: { uid: string, level: number, at: number }? = nil

-- "Bramble Fang core Lv 1: +1% crit chance"
function CoreCard.fedText(name: string, level: number): string
	for _, perk in ipairs(ShardCore.PERKS) do
		if perk.level == level then
			return string.format("%s core Lv %d: %s", name, level, perk.text)
		end
	end
	return string.format("%s core Lv %d", name, level)
end

function CoreCard.feedLabel(level: number, essence: number): (string, boolean)
	local cost = ShardCore.costToNext(level)
	if cost == nil then
		return "Core maxed", false
	end
	if essence < cost then
		return string.format("Feed %d Essence  (have %d)", cost, essence), false
	end
	return string.format("Feed %d Essence", cost), true
end

local DEFAULT = {
	card = Color3.fromRGB(24, 20, 52),
	row = Color3.fromRGB(36, 30, 74),
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(170, 162, 200),
	ok = Color3.fromRGB(110, 210, 140),
	core = Color3.fromRGB(120, 210, 255),
	track = Color3.fromRGB(46, 40, 86),
	gold = Color3.fromRGB(255, 196, 64),
	ink = Color3.fromRGB(24, 18, 12),
	dim = Color3.fromRGB(58, 52, 88),
	stroke = Color3.fromRGB(120, 86, 220),
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

local function list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
end

local function stack(parent: Instance, name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = order
	f.Parent = parent
	list(f, 6)
	return f
end

function CoreCard.build(parent: Instance, opts: any): any
	local colors = DEFAULT
	if type(opts.colors) == "table" then
		colors = table.clone(DEFAULT)
		for key, value in pairs(opts.colors) do
			(colors :: any)[key] = value
		end
	end
	local fonts = if type(opts.fonts) == "table" then opts.fonts else {}
	local headerFont = fonts.header or Enum.Font.BuilderSansBold
	local bodyFont = fonts.body or Enum.Font.BuilderSans
	-- Hosts pass bind so gamepad A presses reach the same handler.
	local function bind(button: GuiButton, handler: () -> ())
		if type(opts.bind) == "function" then
			opts.bind(button, handler)
		else
			button.Activated:Connect(handler)
		end
	end

	local profile = opts.profile
	local uid: string = opts.uid
	local open = opts.open ~= false
	local busy = false

	local function text(host: Instance, name: string, value: string, order: number, color: Color3, bold: boolean?): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = if bold then headerFont else bodyFont
		label.TextSize = UiTheme.MIN_TEXT
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = color
		label.Text = value
		label.LayoutOrder = order
		label.Parent = host
		return label
	end

	local function button(host: Instance, name: string, value: string, order: number, fill: Color3, ink: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		b.BackgroundColor3 = fill
		b.BorderSizePixel = 0
		b.AutoButtonColor = true
		b.Font = headerFont
		b.TextSize = UiTheme.MIN_TEXT
		b.TextColor3 = ink
		b.TextWrapped = true
		b.Text = value
		b.LayoutOrder = order
		b.Parent = host
		corner(b, 8)
		pad(b, 10, 0)
		return b
	end

	local card = Instance.new("Frame")
	card.Name = "CoreCard"
	card.BackgroundColor3 = colors.card
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = if type(opts.order) == "number" then opts.order else 95
	card.Parent = parent
	corner(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = colors.stroke
	stroke.Thickness = 1.5
	stroke.Parent = card
	pad(card, 10, 10)
	list(card, 8)

	local level = ShardCore.levelOf(profile, uid)
	local essence = ShardCore.essenceOf(profile)

	local header = button(card, "CoreHeader", "", 1, colors.row, colors.text)
	header.TextXAlignment = Enum.TextXAlignment.Left

	local body = stack(card, "CoreBody", 2)

	-- Progress: one segment per level, filled up to the core level.
	local bar = Instance.new("Frame")
	bar.Name = "CoreBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.LayoutOrder = 1
	bar.Parent = body
	list(bar, 4, true)
	local lit = 0
	if fresh ~= nil and fresh.uid == uid and fresh.level == level and os.clock() - fresh.at < CoreCard.FRESH_SECONDS then
		lit = level
	end
	local function glow(target: GuiObject)
		target:SetAttribute("Fresh", true)
		local ring = Instance.new("UIStroke")
		ring.Name = "FreshGlow"
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = colors.gold
		ring.Thickness = 2
		ring.Parent = target
		task.delay(CoreCard.FRESH_SECONDS, function()
			if ring.Parent ~= nil then
				ring:Destroy()
			end
		end)
	end
	for step = 1, ShardCore.CAP do
		local seg = Instance.new("Frame")
		seg.Name = "Step" .. step
		seg.BorderSizePixel = 0
		seg.Size = UDim2.new(1 / ShardCore.CAP, -4, 1, 0)
		seg.BackgroundColor3 = if step == lit then colors.gold elseif step <= level then colors.core else colors.track
		seg.LayoutOrder = step
		seg.Parent = bar
		corner(seg, 4)
		if step == lit then
			glow(seg)
		end
	end

	local nextText, canFeedThis = GearHooks.coreNext(level, essence, ShardCore.COST)
	text(body, "CoreEssence", string.format("Essence %d  ·  %s", essence, nextText), 2, if canFeedThis then colors.text else colors.muted)

	local ladder = stack(body, "Perks", 3)
	for _, perk in ipairs(ShardCore.perkRows(level)) do
		local row = text(
			ladder,
			"Perk" .. tostring(perk.level),
			string.format("%s  Lv %d  %s", if perk.unlocked then "✓" else "🔒", perk.level, perk.text),
			perk.level,
			if perk.unlocked then colors.ok else colors.muted,
			perk.unlocked
		)
		row:SetAttribute("Unlocked", perk.unlocked == true)
		if perk.level == lit then
			row.TextColor3 = colors.gold
			glow(row)
		end
	end

	local inventory = if type(profile) == "table" and type(profile.inventory) == "table" then profile.inventory else {}
	local owned = inventory[uid]
	local name = if type(owned) == "table" and type(owned.name) == "string" then owned.name else "Weapon"
	local feedText, canFeed = CoreCard.feedLabel(level, essence)
	local cost = ShardCore.costToNext(level)
	local feed = button(
		body,
		"CoreFeed",
		feedText,
		4,
		if canFeed then colors.gold else colors.dim,
		if canFeed then colors.ink else colors.muted
	)
	feed:SetAttribute("CanFeed", canFeed)

	local confirm = stack(body, "CoreConfirm", 5)
	confirm.Visible = false

	local function paintHeader()
		header.Text = string.format("%s  %s", if open then "▼" else "▶", GearHooks.coreHeader(level))
		body.Visible = open
	end
	paintHeader()

	bind(header, function()
		open = not open
		paintHeader()
		if type(opts.onToggle) == "function" then
			opts.onToggle(open)
		end
	end)

	local function status(message: string, kind: string)
		if type(opts.onStatus) == "function" then
			opts.onStatus(message, kind)
		end
	end

	if canFeed and cost ~= nil then
		text(
			confirm,
			"CoreAsk",
			string.format("Spend %d Essence on %s core?  Lv %d → %d", cost, name, level, level + 1),
			1,
			colors.text,
			true
		)
		local choices = Instance.new("Frame")
		choices.Name = "CoreChoices"
		choices.BackgroundTransparency = 1
		choices.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
		choices.LayoutOrder = 2
		choices.Parent = confirm
		list(choices, 8, true)
		local yes = button(choices, "CoreConfirmFeed", string.format("Feed %d Essence", cost), 1, colors.gold, colors.ink)
		yes.Size = UDim2.new(0.5, -4, 1, 0)
		local no = button(choices, "CoreCancel", "Cancel", 2, colors.dim, colors.text)
		no.Size = UDim2.new(0.5, -4, 1, 0)
		bind(no, function()
			confirm.Visible = false
		end)
		bind(yes, function()
			if busy then
				return
			end
			busy = true
			yes.Text = "Feeding..."
			task.spawn(function()
				local ok, answer = pcall(opts.invoke, CoreCard.FEED, uid)
				busy = false
				if not ok or type(answer) ~= "table" or answer.ok ~= true then
					local why = if ok and type(answer) == "table" and type(answer.error) == "string"
						then answer.error
						else "Could not feed that core."
					status(why, "error")
					yes.Text = string.format("Feed %d Essence", cost)
					return
				end
				local now = math.floor(tonumber(answer.level) or level + 1)
				fresh = { uid = uid, level = now, at = os.clock() }
				status(CoreCard.fedText(name, now), "ok")
				confirm.Visible = false
				if type(opts.onFed) == "function" then
					opts.onFed(answer, uid)
				end
			end)
		end)
	end

	bind(feed, function()
		if not canFeed then
			status(if cost == nil then name .. " core is maxed." else string.format("Need %d Essence (you have %d).", cost, essence), "error")
			return
		end
		confirm.Visible = not confirm.Visible
	end)

	return {
		frame = card,
		feed = feed,
		confirm = confirm,
		isOpen = function(): boolean
			return open
		end,
	}
end

return CoreCard
