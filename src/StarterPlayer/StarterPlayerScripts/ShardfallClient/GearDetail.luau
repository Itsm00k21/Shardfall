--!strict

--[[
	The gear detail panel, shared by the small Bag (MenuHub) and the full
	inventory (InventoryHud). Ghost owns this view. It reads the profile
	snapshot it is given and sends nothing itself: every action is a
	callback the host wires to the existing remotes.

	build(host, opts) adds rows to host, which must have a UIListLayout:

	  Hero            item icon (painted art, not the avatar) in a rarity
	                  frame, the padlock, name with stars and +level in the
	                  rarity colour, and "Rare · Weapon".
	  CompareHeader   "Equipped" / "Compared with X (equipped)".
	  Stat_<id>       one per stat, green/red/= against the worn item.
	  Stat_power, Stat_boost ("Upgrade +N  stats xM"), UpgradeNote.
	  DetailActions   EQUIP and UPGRADE <cost> side by side. Upgrade is
	                  amber with dark ink so it reads at a glance.
	  CoreCard        Shard Core, weapons only, while shardCore is on.

	Everything is UIListLayout + AutomaticSize. No fixed y offsets, so
	the Back button and the first stat line cannot overlap.

	opts:
	  profile, item, order
	  powerOf(item) -> number
	  worn: boolean                 the item is equipped in its slot
	  onEquip(), onUpgrade(), onLock(locked)
	  note: { text, ok }?
	  core: CoreCard opts minus uid/profile, or nil to hide it
	  decorate(button, rest)?       host hover/press styling
	  bind(button, handler)?        host click binding (gamepad aware)
	  fonts { header, body }?, colors?
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagCompare = require(Shared:WaitForChild("BagCompare"))
local Economy = require(Shared:WaitForChild("Economy"))
local HubStyle = require(Shared:WaitForChild("HubStyle"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local LaunchGate = require(Shared:WaitForChild("LaunchGate"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local CoreCard = require(script.Parent:WaitForChild("CoreCard"))

local GearDetail = {}

GearDetail.ICON = 84

local DEFAULT = {
	text = Color3.fromRGB(240, 236, 248),
	muted = Color3.fromRGB(170, 162, 200),
	ok = Color3.fromRGB(110, 210, 140),
	loss = Color3.fromRGB(220, 92, 96),
	equip = Color3.fromRGB(36, 84, 168),
	equipped = Color3.fromRGB(46, 70, 60),
	upgrade = Color3.fromRGB(255, 190, 60),
	ink = Color3.fromRGB(24, 18, 12),
	dim = Color3.fromRGB(58, 52, 88),
	well = Color3.fromRGB(20, 18, 46),
	lockOn = Color3.fromRGB(255, 196, 64),
}

local GLYPH = {
	Weapon = "⚔",
	Armor = "🛡",
	Accessory = "💍",
	Pet = "🐾",
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function rarityColor(rarity: string): Color3
	local r, g, b = UiTheme.rarityColor(rarity)
	return Color3.fromRGB(r, g, b)
end

-- The art key the icon well paints. Pure, so tests can read it.
-- The fallback glyph for a kind with no art (inventory cards use it too).
function GearDetail.glyph(kind: any): string
	return GLYPH[tostring(kind)] or "◆"
end

function GearDetail.artKey(item: any): string
	return HubStyle.itemArt(item)
end

-- [Ghost] Clip 5: one padlock look everywhere. Drawn from frames (an
-- emoji ignores TextColor3): gold and closed while locked, muted grey
-- and open while unlocked.
GearDetail.LOCK_GOLD = Color3.fromRGB(255, 196, 64)
GearDetail.LOCK_GREY = Color3.fromRGB(150, 146, 170)

function GearDetail.lockIcon(parent: Instance, locked: boolean, px: number): Frame
	local color = if locked then GearDetail.LOCK_GOLD else GearDetail.LOCK_GREY
	local icon = Instance.new("Frame")
	icon.Name = "LockIcon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(px, px)
	icon:SetAttribute("Locked", locked)
	icon.Parent = parent
	-- [Ghost] Clip 6: the open lock read as a blob (a closed ring floating
	-- over the body). The shackle is now a thin full arch whose bottom edge
	-- is faded out, so open shows two short legs lifted clear of the body.
	local shackle = Instance.new("Frame")
	shackle.Name = "Shackle"
	shackle.BackgroundTransparency = 1
	shackle.Size = UDim2.fromScale(0.46, 0.56)
	-- Open: the shackle lifts and shifts right.
	shackle.Position = if locked then UDim2.fromScale(0.27, 0.04) else UDim2.fromScale(0.45, -0.1)
	shackle.Parent = icon
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = math.max(1.5, px / 10)
	ring.Color = color
	ring.Parent = shackle
	local fade = Instance.new("UIGradient")
	fade.Name = "LegFade"
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.78, 0),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = ring
	corner(shackle, math.floor(px * 0.23))
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BorderSizePixel = 0
	body.BackgroundColor3 = color
	body.Size = UDim2.fromScale(0.74, 0.44)
	body.Position = UDim2.fromScale(0.13, 0.5)
	body.Parent = icon
	corner(body, math.max(2, math.floor(px / 7)))
	local keyhole = Instance.new("Frame")
	keyhole.Name = "Keyhole"
	keyhole.BorderSizePixel = 0
	keyhole.BackgroundColor3 = Color3.fromRGB(22, 18, 34)
	keyhole.AnchorPoint = Vector2.new(0.5, 0.5)
	keyhole.Position = UDim2.fromScale(0.5, 0.48)
	keyhole.Size = UDim2.fromScale(0.16, 0.32)
	keyhole.Parent = body
	corner(keyhole, math.max(1, math.floor(px / 16)))
	local baseZ = if parent:IsA("GuiObject") then parent.ZIndex else 1
	icon.ZIndex = baseZ
	shackle.ZIndex = baseZ
	body.ZIndex = baseZ + 1
	keyhole.ZIndex = baseZ + 2
	return icon
end

-- [Ghost] Clip 5: worn items show one EQUIPPED state. A first tap arms it
-- ("Tap again to unequip"), a second tap within 3 s unequips. Unequip
-- stays possible (UnequipItem is live) without a second button.
GearDetail.ARM_SECONDS = 3

function GearDetail.wornTap(button: TextButton, onUnequip: (() -> ())?): () -> ()
	local armedAt: number? = nil
	return function()
		if onUnequip == nil then
			return
		end
		local now = os.clock()
		if armedAt ~= nil and now - armedAt <= GearDetail.ARM_SECONDS then
			armedAt = nil
			button.Text = "EQUIPPED"
			button:SetAttribute("Armed", false)
			onUnequip()
			return
		end
		armedAt = now
		button.Text = "Tap again to unequip"
		button:SetAttribute("Armed", true)
		local stamp = now
		task.delay(GearDetail.ARM_SECONDS, function()
			if armedAt == stamp and button.Parent ~= nil then
				armedAt = nil
				button.Text = "EQUIPPED"
				button:SetAttribute("Armed", false)
			end
		end)
	end
end

local function grouped(amount: number): string
	local text = tostring(math.floor(amount))
	local out = text
	repeat
		local count
		out, count = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return out
end

-- Gold still missing for the next upgrade, or nil when it is affordable.
function GearDetail.goldShort(profile: any, item: any): number?
	if type(item) ~= "table" then
		return nil
	end
	local level = tonumber(item.upgrade) or 0
	if level ~= level or level < 0 then
		level = 0
	end
	if level >= Economy.UPGRADE_MAX then
		return nil
	end
	local cost = Economy.upgradeCost(level)
	local gold = if type(profile) == "table" and type(profile.gold) == "number" and profile.gold == profile.gold
		then math.max(0, profile.gold)
		else 0
	if gold >= cost then
		return nil
	end
	return math.ceil(cost - gold)
end

function GearDetail.shortText(missing: number): string
	return string.format("Need %s more gold", grouped(missing))
end

function GearDetail.haveText(profile: any): string
	local gold = if type(profile) == "table"
			and type(profile.gold) == "number"
			and profile.gold == profile.gold
		then math.max(0, profile.gold)
		else 0
	return string.format("You have %s gold", grouped(gold))
end

function GearDetail.build(host: Instance, opts: any): any
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
	local item = opts.item
	local profile = opts.profile
	local base = if type(opts.order) == "number" then opts.order else 1
	local rarity = if type(item.rarity) == "string" then item.rarity else "Common"
	local tint = rarityColor(rarity)

	local function line(parent: Instance, name: string, text: string, order: number, color: Color3, size: number?, bold: boolean?): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = if bold then headerFont else bodyFont
		label.TextSize = size or UiTheme.MIN_TEXT
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = parent
		return label
	end

	local function action(parent: Instance, name: string, text: string, order: number, fill: Color3, ink: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(0.5, -4, 1, 0)
		b.BackgroundColor3 = fill
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.Font = headerFont
		b.TextSize = UiTheme.MIN_TEXT + 1
		b.TextColor3 = ink
		b.TextWrapped = true
		b.Text = text
		b.LayoutOrder = order
		b.Parent = parent
		corner(b, 8)
		if type(opts.decorate) == "function" then
			opts.decorate(b, fill)
		end
		-- Hosts may restyle buttons; ink is pinned so it always contrasts.
		b:SetAttribute("Ink", true)
		b.TextColor3 = ink
		return b
	end

	-- Hero: icon well on the left, text beside it, padlock on the right.
	local hero = Instance.new("Frame")
	hero.Name = "Hero"
	hero.BackgroundTransparency = 1
	hero.Size = UDim2.fromScale(1, 0)
	hero.AutomaticSize = Enum.AutomaticSize.Y
	hero.LayoutOrder = base
	hero.Parent = host
	local heroList = Instance.new("UIListLayout")
	heroList.FillDirection = Enum.FillDirection.Horizontal
	heroList.SortOrder = Enum.SortOrder.LayoutOrder
	heroList.Padding = UDim.new(0, 10)
	heroList.Parent = hero

	local well = Instance.new("Frame")
	well.Name = "ItemIcon"
	well.BackgroundColor3 = colors.well
	well.BorderSizePixel = 0
	well.Size = UDim2.fromOffset(GearDetail.ICON, GearDetail.ICON)
	well.LayoutOrder = 1
	well.Parent = hero
	corner(well, 10)
	local wellStroke = Instance.new("UIStroke")
	wellStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	wellStroke.Thickness = 2.5
	wellStroke.Color = tint
	wellStroke.Parent = well
	local art = IconAssets[GearDetail.artKey(item)]
	if type(art) == "string" then
		local image = Instance.new("ImageLabel")
		image.Name = "Art"
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.8, 0.8)
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = art
		image.Parent = well
	else
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Art"
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.Font = headerFont
		glyph.TextSize = 40
		glyph.TextColor3 = tint
		glyph.Text = GLYPH[tostring(item.kind)] or "◆"
		glyph.Parent = well
	end

	local words = Instance.new("Frame")
	words.Name = "HeroText"
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(1, -(GearDetail.ICON + 10 + UiTheme.TOUCH + 10), 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.LayoutOrder = 2
	words.Parent = hero
	local wordsList = Instance.new("UIListLayout")
	wordsList.SortOrder = Enum.SortOrder.LayoutOrder
	wordsList.Padding = UDim.new(0, 4)
	wordsList.Parent = words
	local title = line(words, "Title", BagCompare.title(item), 1, tint, 18, true)
	title:SetAttribute("Rarity", rarity)
	line(words, "Kind", string.format("%s  ·  %s", rarity, tostring(item.kind or "Item")), 2, colors.muted)

	local locked = item.locked == true
	local padlock = Instance.new("TextButton")
	padlock.Name = "Padlock"
	padlock.Size = UDim2.fromOffset(UiTheme.TOUCH, UiTheme.TOUCH)
	-- [Ghost] Clip 6: no grey disc behind a grey lock. A faint well and a
	-- thin ring in the lock colour keep the touch target readable.
	padlock.BackgroundColor3 = colors.dim
	padlock.BackgroundTransparency = 0.65
	padlock.BorderSizePixel = 0
	padlock.AutoButtonColor = false
	padlock.Text = ""
	padlock.LayoutOrder = 3
	padlock.Parent = hero
	padlock:SetAttribute("Locked", locked)
	corner(padlock, UiTheme.TOUCH // 2)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = 1
	ring.Color = if locked then GearDetail.LOCK_GOLD else GearDetail.LOCK_GREY
	ring.Transparency = if locked then 0.2 else 0.55
	ring.Parent = padlock
	GearDetail.lockIcon(padlock, locked, 24)
	bind(padlock, function()
		if type(opts.onLock) == "function" then
			opts.onLock(not locked)
		end
	end)
	-- [Ghost] Clip 5: pets reuse just the header (icon, name, rarity,
	-- padlock); the host draws their stats and the equip state below.
	if opts.headerOnly == true then
		return {
			hero = hero,
			padlock = padlock,
			nextOrder = base + 1,
		}
	end

	-- Stats against the worn item.
	local detail = BagCompare.detail(profile, item, opts.powerOf)
	local worn = detail.state == "equipped"
	local function tone(name: string): Color3
		if name == "gain" then
			return colors.ok
		elseif name == "loss" then
			return colors.loss
		end
		return colors.text
	end
	-- [Ghost] Clip 4: worn gear already says so on the E badge and the
	-- EQUIPPED button, so the green "Equipped" header is hidden.
	local compareHeader = line(host, "CompareHeader", detail.header, base + 1, if worn then colors.ok else colors.muted)
	compareHeader.Visible = not worn
	local order = base + 2
	for _, row in ipairs(detail.rows) do
		line(host, "Stat_" .. row.id, row.text, order, tone(row.tone))
		order += 1
	end
	line(host, "Stat_power", detail.power.text, order, tone(detail.power.tone), nil, true)
	order += 1
	if detail.boost ~= nil then
		line(host, "Stat_boost", detail.boost.text, order, colors.ok)
		order += 1
	end
	local note = opts.note
	if type(note) == "table" and type(note.text) == "string" then
		line(host, "UpgradeNote", note.text, order, if note.ok then colors.ok else colors.loss)
		order += 1
	end

	-- EQUIP and UPGRADE side by side.
	local actions = Instance.new("Frame")
	actions.Name = "DetailActions"
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, UiTheme.TOUCH)
	actions.LayoutOrder = order
	actions.Parent = host
	order += 1
	local actionList = Instance.new("UIListLayout")
	actionList.FillDirection = Enum.FillDirection.Horizontal
	actionList.SortOrder = Enum.SortOrder.LayoutOrder
	actionList.Padding = UDim.new(0, 8)
	actionList.Parent = actions
	local equip = action(
		actions,
		"DetailEquip",
		if worn then "EQUIPPED" else HubStyle.EQUIP,
		1,
		if worn then colors.equipped else colors.equip,
		colors.text
	)
	local unequip = if type(opts.onUnequip) == "function" then opts.onUnequip else nil
	local wornTap = GearDetail.wornTap(equip, unequip)
	bind(equip, function()
		if worn then
			wornTap()
		elseif type(opts.onEquip) == "function" then
			opts.onEquip()
		end
	end)
	local upgradeText = HubStyle.upgradeLabel(item.upgrade)
	local maxed = string.find(upgradeText, "Max", 1, true) ~= nil
	-- [Ghost] Clip 4: UPGRADE looked pressable with too little gold. The
	-- server still decides; this only dims the button and says the gap.
	local short = if maxed then nil else GearDetail.goldShort(profile, item)
	local upgrade = action(
		actions,
		"Upgrade",
		upgradeText,
		2,
		if maxed or short ~= nil then colors.dim else colors.upgrade,
		if maxed or short ~= nil then colors.muted else colors.ink
	)
	upgrade:SetAttribute("Short", short ~= nil)
	bind(upgrade, function()
		if not maxed and short == nil and type(opts.onUpgrade) == "function" then
			opts.onUpgrade()
		end
	end)
	if short ~= nil then
		line(host, "UpgradeShort", GearDetail.shortText(short), order, colors.muted)
		order += 1
	elseif not maxed then
		-- [Ghost] Clip 6: UPGRADE 150 was bright at Gold 250 (correct), but
		-- the Bag only shows Essence 0, so it read as free. Name the gold.
		line(host, "UpgradeGold", GearDetail.haveText(profile), order, colors.muted)
		order += 1
	end

	local core = nil
	if item.kind == "Weapon" and type(item.uid) == "string" and type(opts.core) == "table" and LaunchGate.on("shardCore") then
		local coreOpts = table.clone(opts.core)
		coreOpts.uid = item.uid
		coreOpts.profile = profile
		coreOpts.order = order
		coreOpts.fonts = opts.fonts
		coreOpts.bind = opts.bind
		core = CoreCard.build(host, coreOpts)
		order += 1
	end

	return {
		hero = hero,
		equip = equip,
		upgrade = upgrade,
		padlock = padlock,
		core = core,
		nextOrder = order,
		worn = worn,
	}
end

return GearDetail
