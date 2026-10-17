--!strict

--[[
	Daily board. The 4x4 grid shows this week's seals. Buttons stay at
	least 64px so a thumb can hit them. The grid itself is a readout, not
	a control. Premium stays a refusal until the pass is published.

	Each weekly uses the same line as a daily: a done mark, the sentence
	already stored on the profile, and progress/goal. This panel does not
	roll a new sentence. On a tall window the list grows downward beside
	the grid. On a short phone the five weeklies take their own column so
	each sentence stays one line. The card stops at the action bar, and
	the text never sits on the grid.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loops = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Loops"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local LoopHud = {}
local player = Players.LocalPlayer

export type QuestRow = {
	text: string,
	done: boolean,
	header: boolean,
}

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
}

export type Place = {
	mode: string,
	panelW: number,
	panelH: number,
	rowH: number,
	board: Rect,
	today: Rect,
	week: Rect,
	panelBottom: number,
	limitBottom: number,
	todayScroll: boolean,
	weekScroll: boolean,
}

local BOARD_X = 8
local BOARD_Y = 8
local BOARD_W = 124
local BOARD_H = 124
local NOTE_X = 140
local TOP_PAD = 8
local SIDE_PAD = 8
local COLUMN_GAP = 12
local STACK_GAP = 8
local BUTTON_BAND = 72
local BUTTON_GAP = 8
local PANEL_TOP = 72
local ACTION_TOP = 92
local LEFT_MARGIN = 16
local RIGHT_MARGIN = 8
local ROW_COMFORT = 22
local ROW_MIN = 18
local CHAR_PX = 8
local TEXT_GUTTER = 20
local MIN_PANEL_W = 280
local FOOT = BUTTON_BAND + BUTTON_GAP

local labelRows: { TextLabel } = {}
local weekRows: { TextLabel } = {}
local heldProfile: any = nil
local screenRef: ScreenGui? = nil
local panelRef: Frame? = nil
local todayColumn: ScrollingFrame? = nil
local weekColumn: ScrollingFrame? = nil
local weekRule: Frame? = nil
local cells: { TextLabel } = {}

local function finite(value: any): number?
	local number = value
	if type(value) == "string" then
		number = tonumber(value)
	end
	if type(number) ~= "number" then
		return nil
	end
	if number ~= number or number == math.huge or number == -math.huge then
		return nil
	end
	return number
end

local function blank(value: any): boolean
	return type(value) ~= "string" or string.match(value, "%S") == nil
end

local function questRow(text: string, done: boolean, header: boolean): QuestRow
	return {
		text = text,
		done = done,
		header = header,
	}
end

-- Same mark, sentence, and counter the dailies already print. Missing
-- text falls back to the id, then to "Quest". Bad numbers become 0/1.
function LoopHud.questLine(quest: any): string
	if type(quest) ~= "table" then
		return ""
	end
	local label = quest.text
	if blank(label) and (type(quest.id) == "string" or type(quest.id) == "number") then
		label = tostring(quest.id)
	end
	if blank(label) then
		label = "Quest"
	end
	local progress = finite(quest.progress)
	if progress == nil or progress < 0 then
		progress = 0
	end
	local goal = finite(quest.goal)
	if goal == nil or goal < 1 then
		goal = 1
	end
	local mark = if quest.done == true then "x" else " "
	return string.format(
		"[%s] %s %d/%d",
		mark,
		label,
		math.floor(progress :: number),
		math.floor(goal :: number)
	)
end

function LoopHud.todayLines(profile: any): { QuestRow }
	local lines: { QuestRow } = {}
	if type(profile) ~= "table" then
		return lines
	end
	local tier = profile.passTier
	if tier == nil then
		tier = 0
	end
	local tierText = tostring(tier)
	if Loops.PREMIUM_ENABLED ~= true then
		table.insert(lines, questRow(string.format("Pass tier %s", tierText), false, false))
		table.insert(lines, questRow("Premium track is not for sale", false, false))
	elseif profile.passPremium == true then
		table.insert(
			lines,
			questRow(string.format("Pass tier %s · premium", tierText), false, false)
		)
	else
		table.insert(
			lines,
			questRow(string.format("Pass tier %s · premium locked", tierText), false, false)
		)
	end
	local chance = Loops.chance(profile.boardChance)
	table.insert(
		lines,
		questRow(string.format("Second Chance %d/%d", chance, Loops.CHANCE_MAX), false, false)
	)
	if type(profile.dailies) == "table" then
		for _, quest in ipairs(profile.dailies) do
			local text = LoopHud.questLine(quest)
			if text ~= "" then
				local done = type(quest) == "table" and quest.done == true
				table.insert(lines, questRow(text, done, false))
			end
		end
	end
	local best = profile.nightmareBest
	if type(best) == "number" and best == best and best > 0 and best < math.huge then
		table.insert(
			lines,
			questRow(string.format("Nightmare best %ds", math.floor(best)), false, false)
		)
	end
	local ready = if profile.dailyBossReady == true
		then "Daily boss ready"
		else "Daily boss resting"
	table.insert(lines, questRow(ready, false, false))
	return lines
end

-- Reads the stored weekly rows. It does not replace an in-week sentence.
function LoopHud.weekLines(profile: any): { QuestRow }
	local lines: { QuestRow } = {}
	if type(profile) ~= "table" or type(profile.weekly) ~= "table" then
		return lines
	end
	for _, quest in ipairs(profile.weekly) do
		local text = LoopHud.questLine(quest)
		if text ~= "" then
			local done = type(quest) == "table" and quest.done == true
			table.insert(lines, questRow(text, done, false))
		end
	end
	if #lines == 0 then
		return lines
	end
	table.insert(lines, 1, questRow("Weeklies", false, true))
	return lines
end

local function cleanView(viewW: any, viewH: any): (number, number)
	if type(viewW) ~= "number" or viewW ~= viewW or viewW < 240 then
		viewW = 1280
	end
	if type(viewH) ~= "number" or viewH ~= viewH or viewH < 240 then
		viewH = 720
	end
	return viewW, viewH
end

local function columnWidth(chars: number, count: number): number
	if count <= 0 then
		return 0
	end
	local width = math.max(0, math.floor(chars)) * CHAR_PX + TEXT_GUTTER
	if width < 132 then
		width = 132
	end
	return width
end

local function contentWidth(mode: string, todayW: number, weekW: number): number
	if mode == "side" then
		local gap = if todayW > 0 and weekW > 0 then COLUMN_GAP else 0
		return NOTE_X + todayW + gap + weekW + SIDE_PAD
	end
	if mode == "elbow" then
		local beside = if todayW > 0 then NOTE_X + todayW + SIDE_PAD else MIN_PANEL_W
		local under = SIDE_PAD + math.max(weekW, BOARD_W) + SIDE_PAD
		if weekW <= 0 then
			return math.max(MIN_PANEL_W, beside)
		end
		return math.max(MIN_PANEL_W, beside, under)
	end
	return math.max(MIN_PANEL_W, SIDE_PAD + math.max(todayW, weekW, BOARD_W) + SIDE_PAD)
end

local function contentHeight(
	mode: string,
	rowH: number,
	todayCount: number,
	weekCount: number
): number
	local todayH = todayCount * rowH
	local weekH = weekCount * rowH
	if mode == "side" then
		return TOP_PAD + math.max(BOARD_H, todayH, weekH) + FOOT
	end
	if mode == "elbow" then
		local top = math.max(BOARD_H, todayH)
		local gap = if weekCount > 0 then STACK_GAP else 0
		return TOP_PAD + top + gap + weekH + FOOT
	end
	local gap = if todayCount > 0 and weekCount > 0 then STACK_GAP else 0
	return BOARD_Y + BOARD_H + STACK_GAP + todayH + gap + weekH + FOOT
end

local function sideColumns(maxW: number, todayW: number, weekW: number): (number, number, boolean)
	if todayW <= 0 or weekW <= 0 then
		return todayW, weekW, false
	end
	local natural = contentWidth("side", todayW, weekW)
	if natural <= maxW then
		return todayW, weekW, true
	end
	local room = maxW - NOTE_X - COLUMN_GAP - SIDE_PAD
	if room - weekW >= 120 then
		return room - weekW, weekW, true
	end
	return todayW, weekW, false
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return {
		x = math.floor(x),
		y = math.floor(y),
		w = math.max(0, math.floor(w)),
		h = math.max(0, math.floor(h)),
	}
end

local function emptyRect(): Rect
	return { x = 0, y = 0, w = 0, h = 0 }
end

-- Places the grid, today's lines, and the weekly lines. Text stays off
-- the grid. The panel stops where the action bar starts.
function LoopHud.layout(
	viewW: number,
	viewH: number,
	todayCount: number,
	weekCount: number,
	todayChars: number,
	weekChars: number
): Place
	viewW, viewH = cleanView(viewW, viewH)
	todayCount = math.max(0, math.floor(if type(todayCount) == "number" then todayCount else 0))
	weekCount = math.max(0, math.floor(if type(weekCount) == "number" then weekCount else 0))
	local todayW = columnWidth(if type(todayChars) == "number" then todayChars else 0, todayCount)
	local weekW = columnWidth(if type(weekChars) == "number" then weekChars else 0, weekCount)
	local maxW = math.max(MIN_PANEL_W, math.floor(viewW - RIGHT_MARGIN - LEFT_MARGIN))
	local maxH = math.max(FOOT + ROW_MIN, math.floor(viewH - PANEL_TOP - ACTION_TOP))
	local mode = "below"
	local rowH = ROW_MIN
	local fitted = false

	local function accept(
		nextMode: string,
		nextRow: number,
		nextTodayW: number,
		nextWeekW: number
	): boolean
		if contentWidth(nextMode, nextTodayW, nextWeekW) > maxW then
			return false
		end
		if contentHeight(nextMode, nextRow, todayCount, weekCount) > maxH then
			return false
		end
		mode = nextMode
		rowH = nextRow
		todayW = nextTodayW
		weekW = nextWeekW
		fitted = true
		return true
	end

	if not accept("elbow", ROW_COMFORT, todayW, weekW) then
		if not accept("elbow", ROW_MIN, todayW, weekW) then
			local sideToday, sideWeek, sideOk = sideColumns(maxW, todayW, weekW)
			if sideOk then
				if not accept("side", ROW_COMFORT, sideToday, sideWeek) then
					accept("side", ROW_MIN, sideToday, sideWeek)
				end
			end
			if not fitted then
				if not accept("below", ROW_COMFORT, todayW, weekW) then
					accept("below", ROW_MIN, todayW, weekW)
				end
			end
		end
	end

	if not fitted and weekCount > 0 then
		local sideToday, sideWeek, sideOk = sideColumns(maxW, todayW, weekW)
		local colH = maxH - FOOT - TOP_PAD
		if sideOk and weekCount * ROW_MIN <= colH then
			mode = "side"
			rowH = ROW_MIN
			todayW = sideToday
			weekW = sideWeek
			fitted = true
		end
	end

	local panelW = math.min(maxW, contentWidth(mode, todayW, weekW))
	local wantH = contentHeight(mode, rowH, todayCount, weekCount)
	local panelH = math.min(maxH, wantH)
	if fitted and wantH < 220 and 220 <= maxH then
		panelH = 220
	end
	if not fitted then
		panelH = maxH
		panelW = math.min(maxW, math.max(panelW, MIN_PANEL_W))
	end

	local board = rect(BOARD_X, BOARD_Y, BOARD_W, BOARD_H)
	local todayBox = emptyRect()
	local weekBox = emptyRect()
	local todayFull = todayCount * rowH
	local weekFull = weekCount * rowH
	local textBottom = panelH - BUTTON_BAND - BUTTON_GAP

	if mode == "side" then
		local colH = math.max(0, textBottom - TOP_PAD)
		local x = NOTE_X
		if todayCount > 0 then
			todayBox = rect(x, TOP_PAD, todayW, colH)
			x += todayW + COLUMN_GAP
		end
		if weekCount > 0 then
			weekBox = rect(x, TOP_PAD, weekW, colH)
		end
	elseif mode == "elbow" then
		if todayCount > 0 then
			local h = math.min(todayFull, math.max(0, textBottom - TOP_PAD))
			todayBox = rect(NOTE_X, TOP_PAD, todayW, h)
		end
		if weekCount > 0 then
			local top = BOARD_Y + BOARD_H
			if todayBox.h > 0 then
				top = math.max(top, todayBox.y + todayBox.h)
			end
			local y = top + STACK_GAP
			local h = math.min(weekFull, math.max(0, textBottom - y))
			weekBox = rect(SIDE_PAD, y, math.max(0, panelW - SIDE_PAD * 2), h)
		end
	else
		local y = BOARD_Y + BOARD_H + STACK_GAP
		local inner = math.max(0, panelW - SIDE_PAD * 2)
		if todayCount > 0 then
			local h = math.min(todayFull, math.max(0, textBottom - y))
			todayBox = rect(SIDE_PAD, y, inner, h)
			y += todayBox.h
			if weekCount > 0 then
				y += STACK_GAP
			end
		end
		if weekCount > 0 then
			local h = math.min(weekFull, math.max(0, textBottom - y))
			weekBox = rect(SIDE_PAD, y, inner, h)
		end
	end

	return {
		mode = mode,
		panelW = panelW,
		panelH = panelH,
		rowH = rowH,
		board = board,
		today = todayBox,
		week = weekBox,
		panelBottom = PANEL_TOP + panelH,
		limitBottom = viewH - ACTION_TOP,
		todayScroll = todayFull > todayBox.h,
		weekScroll = weekFull > weekBox.h,
	}
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

local function widest(lines: { QuestRow }): number
	local best = 0
	for _, line in ipairs(lines) do
		if #line.text > best then
			best = #line.text
		end
	end
	return best
end

local function viewSize(): (number, number)
	local screen = screenRef
	if screen ~= nil then
		local size = screen.AbsoluteSize
		if size.X >= 240 and size.Y >= 240 then
			return size.X, size.Y
		end
	end
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		local size = camera.ViewportSize
		if size.X >= 240 and size.Y >= 240 then
			return size.X, size.Y
		end
	end
	return 1280, 720
end

local function ensureLine(pool: { TextLabel }, parent: Instance, index: number): TextLabel
	local line = pool[index]
	if line ~= nil then
		return line
	end
	local created = Instance.new("TextLabel")
	created.Name = "Line" .. tostring(index)
	created.BackgroundTransparency = 1
	created.BorderSizePixel = 0
	created.Font = Enum.Font.BuilderSans
	created.TextSize = UiTheme.MIN_TEXT
	created.TextXAlignment = Enum.TextXAlignment.Left
	created.TextYAlignment = Enum.TextYAlignment.Center
	created.TextWrapped = false
	created.TextTruncate = Enum.TextTruncate.AtEnd
	created.Text = ""
	created.Parent = parent
	pool[index] = created
	return created
end

local function paintLines(
	column: ScrollingFrame,
	pool: { TextLabel },
	lines: { QuestRow },
	area: Rect,
	rowH: number,
	scroll: boolean
)
	local show = area.w > 0 and area.h > 0 and #lines > 0
	column.Visible = show
	if not show then
		return
	end
	column.Position = UDim2.fromOffset(area.x, area.y)
	column.Size = UDim2.fromOffset(area.w, area.h)
	column.CanvasSize = UDim2.fromOffset(0, #lines * rowH)
	column.CanvasPosition = if scroll then column.CanvasPosition else Vector2.zero
	column.ScrollBarThickness = if scroll then 4 else 0
	column.ScrollingEnabled = scroll
	for index, item in ipairs(lines) do
		local line = ensureLine(pool, column, index)
		line.LayoutOrder = index
		line.Visible = true
		line.Size = UDim2.new(1, -8, 0, rowH)
		line.Text = item.text
		line.Font = if item.header then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans
		if item.header then
			line.TextColor3 = Color3.fromRGB(255, 206, 96)
		elseif item.done then
			line.TextColor3 = Color3.fromRGB(198, 192, 214)
		else
			line.TextColor3 = Color3.fromRGB(244, 240, 252)
		end
	end
	for index = #lines + 1, #pool do
		pool[index].Visible = false
	end
end

local function placeRule(mode: string, week: Rect)
	local rule = weekRule
	if rule == nil then
		return
	end
	if week.w <= 0 or week.h <= 0 then
		rule.Visible = false
		return
	end
	rule.Visible = true
	if mode == "side" then
		rule.Position = UDim2.fromOffset(week.x - 7, week.y + 4)
		rule.Size = UDim2.fromOffset(2, math.max(0, week.h - 8))
	else
		rule.Position = UDim2.fromOffset(week.x, math.max(0, week.y - 5))
		rule.Size = UDim2.fromOffset(week.w, 2)
	end
end

local function paint()
	local panel = panelRef
	local todayFrame = todayColumn
	local weekFrame = weekColumn
	local profile = heldProfile
	if panel == nil or todayFrame == nil or weekFrame == nil or type(profile) ~= "table" then
		return
	end
	local today = LoopHud.todayLines(profile)
	local week = LoopHud.weekLines(profile)
	local viewW, viewH = viewSize()
	local place = LoopHud.layout(viewW, viewH, #today, #week, widest(today), widest(week))
	panel.Size = UDim2.fromOffset(place.panelW, place.panelH)
	paintLines(todayFrame, labelRows, today, place.today, place.rowH, place.todayScroll)
	paintLines(weekFrame, weekRows, week, place.week, place.rowH, place.weekScroll)
	placeRule(place.mode, place.week)
	paintBoard(profile.board)
end

function LoopHud.setProfile(profile: any)
	if type(profile) ~= "table" then
		return
	end
	heldProfile = profile
	paint()
end

function LoopHud.setOpen(open: boolean)
	if panelRef ~= nil then
		panelRef.Visible = open
	end
end

function LoopHud.isOpen(): boolean
	return panelRef ~= nil and panelRef.Visible
end

function LoopHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallLoops"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 12
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = player:WaitForChild("PlayerGui")
	screenRef = screen

	local panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -UiTheme.PAD, 0, PANEL_TOP)
	panel.Size = UDim2.fromOffset(MIN_PANEL_W, 220)
	panel.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screen
	panelRef = panel
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(BOARD_X, BOARD_Y)
	grid.Size = UDim2.fromOffset(BOARD_W, BOARD_H)
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

	local function column(name: string): ScrollingFrame
		local frame = Instance.new("ScrollingFrame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ScrollBarThickness = 0
		frame.ScrollBarImageColor3 = Color3.fromRGB(198, 192, 214)
		frame.ScrollingDirection = Enum.ScrollingDirection.Y
		frame.AutomaticCanvasSize = Enum.AutomaticSize.None
		frame.CanvasSize = UDim2.new()
		frame.ClipsDescendants = true
		frame.Visible = false
		frame.Parent = panel
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 0)
		list.Parent = frame
		return frame
	end

	todayColumn = column("Today")
	weekColumn = column("Week")

	local rule = Instance.new("Frame")
	rule.Name = "WeekRule"
	rule.BackgroundColor3 = Color3.fromRGB(255, 206, 96)
	rule.BackgroundTransparency = 0.35
	rule.BorderSizePixel = 0
	rule.Visible = false
	rule.Parent = panel
	weekRule = rule

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

	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		paint()
	end)
	paint()

	task.defer(function()
		invoke("Loops")
	end)
end

return LoopHud
