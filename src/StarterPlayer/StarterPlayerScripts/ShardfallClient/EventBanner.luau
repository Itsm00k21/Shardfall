--!strict
--[[
	Top-centre event banner in the purple hex style. Shows a title plate and
	boost chips only while a real boost is active (EventBannerModel). It lives
	inside ShardfallHud so the chrome sweep keeps it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventBannerModel = require(Shared:WaitForChild("EventBannerModel"))
local IconAssets = require(Shared:WaitForChild("IconAssets"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local EventBanner = {}

local CHIP_TONE: { [string]: Color3 } = {
	luck = Color3.fromRGB(64, 206, 255),
	forge = Color3.fromRGB(196, 140, 255),
}

function EventBanner.start(playerGui: PlayerGui)
	local screen = playerGui:WaitForChild("ShardfallHud", 10)
	if screen == nil then
		return { setProfile = function(_profile: any) end }
	end
	local root = Instance.new("Frame")
	root.Name = "EventBanner"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 6)
	root.Size = UDim2.fromOffset(280, 92)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = screen
	local plate = Instance.new("ImageLabel")
	plate.Name = "Plate"
	plate.Size = UDim2.fromOffset(280, 64)
	plate.BackgroundTransparency = 1
	plate.ScaleType = Enum.ScaleType.Stretch
	plate.Image = IconAssets.EventBanner or ""
	plate.Parent = root
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -40, 0, 26)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.52)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(150, 235, 255)
	title.Text = ""
	title.ZIndex = 2
	title.Parent = plate
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 1.5
	titleStroke.Color = Color3.fromRGB(20, 8, 48)
	titleStroke.Parent = title
	local row = Instance.new("Frame")
	row.Name = "Chips"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 64)
	row.Size = UDim2.new(1, 0, 0, 26)
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local chips: { [string]: TextLabel } = {}
	local function chipFor(id: string, kind: string, order: number): TextLabel
		local chip = chips[id]
		if chip ~= nil then
			return chip
		end
		local made = Instance.new("TextLabel")
		made.Name = "Chip_" .. id
		made.LayoutOrder = order
		made.AutomaticSize = Enum.AutomaticSize.X
		made.Size = UDim2.fromOffset(0, 24)
		made.BackgroundColor3 = Color3.fromRGB(22, 18, 52)
		made.BackgroundTransparency = 0.08
		made.Font = Enum.Font.BuilderSansBold
		made.TextSize = UiTheme.MIN_TEXT
		made.TextColor3 = Color3.fromRGB(235, 245, 255)
		made.Parent = row
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = made
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = made
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Color = CHIP_TONE[kind] or CHIP_TONE.forge
		stroke.Parent = made
		chips[id] = made
		return made
	end

	local profile: any = nil
	local ticking = false
	local function paint()
		local now = os.time()
		local view = EventBannerModel.view(profile, now)
		root.Visible = view.visible
		title.Text = view.title
		local seen: { [string]: boolean } = {}
		for order, chip in ipairs(view.chips) do
			local label = chipFor(chip.id, chip.kind, order)
			label.Text = chip.text
			seen[chip.id] = true
		end
		for id, label in pairs(chips) do
			if not seen[id] then
				label:Destroy()
				chips[id] = nil
			end
		end
		return EventBannerModel.ticking(profile, now)
	end
	local function tick()
		if ticking then
			return
		end
		ticking = true
		task.spawn(function()
			while paint() do
				task.wait(1)
			end
			ticking = false
		end)
	end

	return {
		setProfile = function(nextProfile: any)
			profile = nextProfile
			paint()
			tick()
		end,
	}
end

return EventBanner
