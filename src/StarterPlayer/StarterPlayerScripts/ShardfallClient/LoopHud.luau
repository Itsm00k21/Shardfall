--!strict

--[[
	Daily board. The 4x4 grid shows this week's seals. Buttons stay at
	least 64px so a thumb can hit them. The grid itself is a readout, not
	a control. Premium stays a refusal until the pass is published.

	The panel matches ShellLayout.loopRect: 280 by 220, under the top
	corner and clear of the Attack / Dodge / Skills / Tonic / Items /
	Travel / Menu bar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loops = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loops"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local LoopHud = {}
local player = Players.LocalPlayer
local label: TextLabel? = nil
local cells: { TextLabel } = {}

local function questLine(quest): string
	if type(quest) ~= "table" then
		return ""
	end
	local mark = if quest.done == true then "x" else " "
	return string.format(
		"[%s] %s %d/%d",
		mark,
		tostring(quest.text or quest.id or "Quest"),
		quest.progress or 0,
		quest.goal or 1
	)
end

local function paintBoard(board: any)
	local lit = Loops.litCells(if type(board) == "table" then board else {})
	for index, cell in ipairs(cells) do
		local sealed = type(board) == "table" and board[index] == true
		if lit[index] == true then
			cell.BackgroundColor3 = Color3.fromRGB(120, 186, 96)
			cell.Text = "x"
		elseif sealed then
			cell.BackgroundColor3 = Color3.fromRGB(214, 176, 92)
			cell.Text = "o"
		else
			cell.BackgroundColor3 = Color3.fromRGB(48, 42, 62)
			cell.Text = ""
		end
	end
end

function LoopHud.setProfile(profile: any)
	if label == nil or type(profile) ~= "table" then
		return
	end
	local lines = {}
	local tier = tostring(profile.passTier or 0)
	if Loops.PREMIUM_ENABLED ~= true then
		table.insert(lines, string.format("Pass tier %s", tier))
		table.insert(lines, "Premium track is not for sale")
	elseif profile.passPremium == true then
		table.insert(lines, string.format("Pass tier %s · premium", tier))
	else
		table.insert(lines, string.format("Pass tier %s · premium locked", tier))
	end
	local chance = Loops.chance(profile.boardChance)
	table.insert(lines, string.format("Second Chance %d/%d", chance, Loops.CHANCE_MAX))
	if type(profile.dailies) == "table" then
		for _, quest in ipairs(profile.dailies) do
			table.insert(lines, questLine(quest))
		end
	end
	if type(profile.weekly) == "table" then
		local done = 0
		local total = 0
		for _, quest in ipairs(profile.weekly) do
			total += 1
			if type(quest) == "table" and quest.done == true then
				done += 1
			end
		end
		if total > 0 then
			table.insert(lines, string.format("Weeklies %d/%d", done, total))
		end
	end
	local best = profile.nightmareBest or 0
	if best > 0 then
		table.insert(lines, string.format("Nightmare best %ds", best))
	end
	local ready = if profile.dailyBossReady == true
		then "Daily boss ready"
		else "Daily boss resting"
	table.insert(lines, ready)
	label.Text = table.concat(lines, "\n")
	paintBoard(profile.board)
end

function LoopHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallLoops"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 12
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -UiTheme.PAD, 0, 72)
	panel.Size = UDim2.fromOffset(280, 220)
	panel.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screen
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(8, 8)
	grid.Size = UDim2.fromOffset(124, 124)
	grid.BackgroundTransparency = 1
	grid.Parent = panel

	local cellSize = 28
	local gap = 4
	for index = 1, 16 do
		local column = (index - 1) % 4
		local rowIndex = math.floor((index - 1) / 4)
		local cell = Instance.new("TextLabel")
		cell.Name = "Cell" .. tostring(index)
		cell.Position = UDim2.fromOffset(column * (cellSize + gap), rowIndex * (cellSize + gap))
		cell.Size = UDim2.fromOffset(cellSize, cellSize)
		cell.BackgroundColor3 = Color3.fromRGB(48, 42, 62)
		cell.BorderSizePixel = 0
		cell.Font = Enum.Font.BuilderSansBold
		cell.TextSize = 14
		cell.TextColor3 = Color3.fromRGB(16, 14, 24)
		cell.Text = ""
		cell.Parent = grid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = cell
		cells[index] = cell
	end

	local note = Instance.new("TextLabel")
	note.Name = "Quests"
	note.Position = UDim2.fromOffset(140, 8)
	note.Size = UDim2.fromOffset(132, 140)
	note.BackgroundTransparency = 1
	note.Font = Enum.Font.BuilderSans
	note.TextSize = UiTheme.MIN_TEXT
	note.TextColor3 = Color3.fromRGB(244, 240, 252)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.TextWrapped = true
	note.Text = "Dailies"
	note.Parent = panel
	label = note

	local row = Instance.new("ScrollingFrame")
	row.Name = "Actions"
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, UiTheme.PAD, 1, -(UiTheme.TAP + UiTheme.PAD))
	row.Size = UDim2.new(1, -UiTheme.PAD * 2, 0, UiTheme.TAP)
	row.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	row.BackgroundTransparency = 0
	row.BorderSizePixel = 0
	row.ScrollBarThickness = 4
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.Parent = panel
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
	rowCorner.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, UiTheme.PAD)
	layout.Parent = row

	local function button(name: string, text: string, color: Color3, callback: () -> ())
		local hit = Instance.new("TextButton")
		hit.Name = name
		hit.Size = UDim2.fromOffset(UiTheme.labelWidth(text), UiTheme.TAP)
		hit.BackgroundColor3 = color
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = UiTheme.MIN_TEXT
		hit.TextColor3 = Color3.fromRGB(16, 14, 24)
		hit.TextWrapped = false
		hit.TextTruncate = Enum.TextTruncate.None
		hit.Text = text
		hit.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = hit
		hit.Activated:Connect(callback)
	end

	button("Reroll", "Reroll", Color3.fromRGB(214, 176, 92), function()
		invoke("RerollDaily", 1)
	end)
	button("Daily", "Daily", Color3.fromRGB(186, 96, 86), function()
		invoke("StartDailyBoss")
	end)
	button("Claim", "Claim", Color3.fromRGB(120, 186, 96), function()
		invoke("ClaimPass")
	end)
	button("Pass", "Pass", Color3.fromRGB(140, 140, 168), function()
		local result = invoke("PremiumPass")
		if type(result) ~= "table" or result.ok ~= true then
			return
		end
		if type(result.productId) ~= "number" or result.productId <= 0 then
			return
		end
		-- Prompt only. ProcessReceipt is assign-only and stays in ReceiptService.
		game:GetService("MarketplaceService"):PromptProductPurchase(player, result.productId)
	end)

	task.defer(function()
		invoke("Loops")
	end)
end

return LoopHud
