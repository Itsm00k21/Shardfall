--!strict
-- [Ghost] RollSummaryHud: the x10 summary grid (Kevin, Oct 23): ten tiles with NEW / ★ up /
-- auto-salvaged badges, a headline, and "Roll again" / "Close". It replaces
-- the old "Cracked" text list on the Roll page.
--
--   mount(parent)   -> handle
--   handle.show(tiles, { onAgain, onClose, phone, view })
--   handle.hide()
--   handle.isOpen()
--   handle.root
--
-- Layout and wording live in Shared/RollSummary, so a Studio preview can
-- mount this with fake tiles and never touch a save.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local RollSummary = require(Shared:WaitForChild("RollSummary"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local View = {}

local KIND_ICON = {
	Weapon = "ItemWeapon",
	Armor = "ItemArmor",
	Relic = "ItemRelic",
	Accessory = "ItemAccessory",
	Pet = "Pets",
}

local INK = Color3.fromRGB(24, 18, 32)
local PANEL = Color3.fromRGB(30, 26, 44)
local TEXT = Color3.fromRGB(240, 236, 250)
local MUTED = Color3.fromRGB(170, 162, 190)
local GOLD = Color3.fromRGB(255, 205, 90)
local OK = Color3.fromRGB(120, 220, 140)

local function rarity3(name: string): Color3
	local r, g, b = UiTheme.rarityColor(name)
	return Color3.fromRGB(r, g, b)
end

-- 0..255 channels, so the GuiFake specs and Studio agree.
local function tint(name: string, t: number): Color3
	local r, g, b = UiTheme.rarityColor(name)
	local function ch(base: number, top: number): number
		return math.floor(base + (top - base) * t + 0.5)
	end
	return Color3.fromRGB(ch(40, r), ch(34, g), ch(58, b))
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(parent: Instance, name: string, value: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = size
	label.TextColor3 = color
	label.Text = value
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 42
	label.Parent = parent
	return label
end

local BADGE_COLOR = {
	[RollSummary.NEW] = OK,
	[RollSummary.STAR_UP] = GOLD,
	[RollSummary.SALVAGED] = Color3.fromRGB(230, 120, 110),
}

function View.mount(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "RollSummary"
	root.BackgroundColor3 = PANEL
	root.BorderSizePixel = 0
	root.Visible = false
	root.Active = true
	root.ZIndex = 40
	root.Parent = parent
	corner(root, 12)
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = GOLD
	edge.Thickness = 2
	edge.Parent = root

	local title = text(root, "Headline", "", 16, TEXT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.ZIndex = 41
	grid.Parent = root

	local again = Instance.new("TextButton")
	again.Name = "RollAgain"
	again.Text = RollSummary.AGAIN
	again.Font = Enum.Font.BuilderSansBold
	again.TextSize = 16
	again.TextColor3 = INK
	again.BackgroundColor3 = GOLD
	again.AutoButtonColor = true
	again.ZIndex = 42
	again.Parent = root
	corner(again, 8)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = RollSummary.CLOSE
	close.Font = Enum.Font.BuilderSansBold
	close.TextSize = 16
	close.TextColor3 = TEXT
	close.BackgroundColor3 = Color3.fromRGB(58, 52, 80)
	close.AutoButtonColor = true
	close.ZIndex = 42
	close.Parent = root
	corner(close, 8)

	local handlers: { onAgain: (() -> ())?, onClose: (() -> ())? } = {}
	local handle = { root = root }

	function handle.isOpen(): boolean
		return root.Visible
	end

	function handle.hide()
		root.Visible = false
	end

	local function tile(index: number, data: RollSummary.Tile, cell: number): Frame
		local color = rarity3(data.rarity)
		local box = Instance.new("Frame")
		box.Name = "Tile_" .. index
		box.BackgroundColor3 = tint(data.rarity, 0.22)
		box.BorderSizePixel = 0
		box.ZIndex = 41
		box.Size = UDim2.fromOffset(cell, cell)
		box:SetAttribute("Rarity", data.rarity)
		box:SetAttribute("Salvaged", data.salvaged)
		corner(box, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2
		stroke.Parent = box
		local artSize = math.floor(cell * 0.42)
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		local key = KIND_ICON[data.kind] or "ItemMisc"
		local image = (IconAssets :: any)[key]
		art.Image = if type(image) == "string" then image else ""
		art.Size = UDim2.fromOffset(artSize, artSize)
		art.Position = UDim2.fromOffset(math.floor((cell - artSize) / 2), 6)
		art.ImageTransparency = if data.salvaged then 0.55 else 0
		art.ZIndex = 42
		art.Parent = box
		local nameSize = if cell >= 84 then 13 else 11
		local name = text(box, "Name", data.name, nameSize, if data.salvaged then MUTED else TEXT)
		name.Position = UDim2.fromOffset(4, artSize + 8)
		name.Size = UDim2.fromOffset(cell - 8, nameSize * 2 + 2)
		local line = text(box, "Line", data.line, 11, if data.salvaged then MUTED else color)
		line.Position = UDim2.fromOffset(4, cell - 17)
		line.Size = UDim2.fromOffset(cell - 8, 14)
		line.TextWrapped = false
		local bx = 3
		for _, badgeText in ipairs(data.badges) do
			local shortText = if badgeText == RollSummary.SALVAGED then "Salvaged" else badgeText
			local width = math.max(28, (utf8.len(shortText) or #shortText) * 7 + 8)
			local badge = text(box, "Badge", shortText, 10, INK)
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = BADGE_COLOR[badgeText] or GOLD
			badge.Position = UDim2.fromOffset(bx, 3)
			badge.Size = UDim2.fromOffset(width, 16)
			badge.TextWrapped = false
			badge.ZIndex = 43
			badge:SetAttribute("Badge", badgeText)
			corner(badge, 4)
			bx += width + 3
		end
		return box
	end

	function handle.show(tiles: { RollSummary.Tile }, opts: any?)
		local options = if type(opts) == "table" then opts else {}
		handlers.onAgain = options.onAgain
		handlers.onClose = options.onClose
		local view: Vector2 = if typeof(options.view) == "Vector2"
			then options.view
			else (parent :: any).AbsoluteSize
		local lay = RollSummary.layout(view.X, view.Y, options.phone == true, #tiles)
		root.Position = UDim2.fromOffset(lay.panel.x, lay.panel.y)
		root.Size = UDim2.fromOffset(lay.panel.w, lay.panel.h)
		title.Text = RollSummary.headline(tiles)
		title.Position = UDim2.fromOffset(lay.pad, lay.pad)
		title.Size = UDim2.fromOffset(lay.panel.w - lay.pad * 2, lay.head - 8)
		for _, child in ipairs(grid:GetChildren()) do
			child:Destroy()
		end
		grid.Position = UDim2.fromOffset(lay.grid.x, lay.grid.y)
		grid.Size = UDim2.fromOffset(lay.grid.w, lay.grid.h)
		for index, data in ipairs(tiles) do
			local box = tile(index, data, lay.cell)
			local col = (index - 1) % lay.cols
			local row = math.floor((index - 1) / lay.cols)
			box.Position = UDim2.fromOffset(col * (lay.cell + lay.gap), row * (lay.cell + lay.gap))
			box.Parent = grid
		end
		local buttonY = lay.panel.h - lay.pad - 40
		local buttonW = math.min(180, math.floor((lay.panel.w - lay.pad * 2 - 10) / 2))
		local left = math.floor((lay.panel.w - buttonW * 2 - 10) / 2)
		again.Position = UDim2.fromOffset(left, buttonY)
		again.Size = UDim2.fromOffset(buttonW, 40)
		close.Position = UDim2.fromOffset(left + buttonW + 10, buttonY)
		close.Size = UDim2.fromOffset(buttonW, 40)
		root.Visible = true
	end

	again.Activated:Connect(function()
		root.Visible = false
		local fn = handlers.onAgain
		if fn ~= nil then
			fn()
		end
	end)
	close.Activated:Connect(function()
		root.Visible = false
		local fn = handlers.onClose
		if fn ~= nil then
			fn()
		end
	end)

	return handle
end

return View
