--!strict

--[[
	Starter-goal tracker.

	Paints up to three rows from a caller-supplied show result.
	Each row is that goal's sentence and its progress out of the
	goal. Progress above the goal is drawn at the goal. An empty
	list, or a result that is not ok, hides the tracker.

	The frame is a child of Chrome, so the shell hide and the
	access text walk include it. HudLayout.place(viewportX,
	viewportY, rowCount) supplies the rect when that function
	exists. Until then the rect sits under the health bar and
	drops below the toast host when they would overlap.

	The server sends the rows. This module does not count, and it
	does not load the rules module. The frame starts hidden.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local StarterGoalHud = {}

local ROW_COUNT = 3
local ROW_H = 18
local WIDTH = 320
local BASE_TEXT = UiTheme.MIN_TEXT
-- Shell rail length, and the three-card toast host in HudShell.
local RAIL_COUNT = 7
local TOAST_CARDS = 3
local TOAST_GAP = 8

export type Row = {
	text: string,
	progress: number,
	goal: number,
	line: string,
}

export type Rect = { x: number, y: number, w: number, h: number }

export type Chrome = {
	hidden: boolean,
	textScale: number,
	textSize: number,
}

local labels: { TextLabel } = {}
local frameRef: Frame? = nil
local screenRef: ScreenGui? = nil
local held: any = nil
local heldSettings: any = nil
local placing = false

local function finite(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function whole(value: any): number?
	local number = finite(value)
	if number == nil or number < 0 or number ~= math.floor(number) then
		return nil
	end
	return number
end

local function readRect(value: any): Rect?
	if type(value) ~= "table" then
		return nil
	end
	local x = finite(value.x)
	local y = finite(value.y)
	local w = finite(value.w)
	local h = finite(value.h)
	if x == nil or y == nil or w == nil or h == nil or w <= 0 or h <= 0 then
		return nil
	end
	return { x = x, y = y, w = w, h = h }
end

local function readGoal(goal: any): Row?
	if type(goal) ~= "table" then
		return nil
	end
	local text = goal.text
	if type(text) ~= "string" or string.match(text, "%S") == nil then
		return nil
	end
	local progress = whole(goal.progress)
	local target = whole(goal.goal)
	if progress == nil or target == nil or target < 1 then
		return nil
	end
	if progress > target then
		progress = target
	end
	return {
		text = text,
		progress = progress,
		goal = target,
		line = string.format("%s %d/%d", text, progress, target),
	}
end

function StarterGoalHud.rows(result: any): { Row }
	local rows: { Row } = {}
	if type(result) ~= "table" or result.ok ~= true or type(result.goals) ~= "table" then
		return rows
	end
	local goals = result.goals
	for index = 1, ROW_COUNT do
		local row = readGoal(goals[index])
		if row ~= nil then
			table.insert(rows, row)
		end
	end
	return rows
end

-- Same hide and text rule as the shell. A profile or its uiSettings both work.
function StarterGoalHud.chrome(settings: any): Chrome
	if type(settings) == "table" and type(settings.uiSettings) == "table" then
		settings = settings.uiSettings
	end
	local hidden = false
	local textScale = 1
	if type(settings) == "table" then
		local hud = settings.hud
		if type(hud) == "table" and hud.hidden == true then
			hidden = true
		end
		local access = settings.access
		if type(access) == "table" then
			local scale = finite(access.textScale)
			if scale ~= nil then
				textScale = scale
			end
		end
	end
	local textSize = math.max(UiTheme.MIN_TEXT, math.floor(BASE_TEXT * textScale + 0.5))
	return {
		hidden = hidden,
		textScale = textScale,
		textSize = textSize,
	}
end

function StarterGoalHud.shown(rowCount: number, settings: any): boolean
	local count = finite(rowCount)
	if count == nil or count < 1 then
		return false
	end
	return not StarterGoalHud.chrome(settings).hidden
end

local function toastHost(viewportX: number, margin: number): Rect
	local toast = HudLayout.toast(viewportX, margin)
	local height = toast.h * TOAST_CARDS + TOAST_GAP * (TOAST_CARDS - 1)
	return { x = toast.x, y = toast.y, w = toast.w, h = height }
end

local function fallback(viewportX: number, viewportY: number, rowCount: number): Rect
	local margin = UiTheme.safeMargin()
	local rows = rowCount
	if rows < 1 then
		rows = 1
	elseif rows > ROW_COUNT then
		rows = ROW_COUNT
	end
	local health = HudLayout.health(margin)
	local height = rows * ROW_H + 8
	local x = health.x + 8
	local y = health.y + health.h + 8
	local room = viewportX - margin - x
	local width = WIDTH
	if room < width then
		width = math.max(UiTheme.TOUCH, math.floor(room))
	end
	local box: Rect = { x = x, y = y, w = width, h = height }
	local block = toastHost(viewportX, margin)
	if HudLayout.overlaps(box, block) then
		local rail = HudLayout.railFit(viewportY, margin, RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH)
		local railRight = rail.x + rail.w + 8
		if x < railRight then
			x = railRight
		end
		y = block.y + block.h + 8
		room = viewportX - margin - x
		width = WIDTH
		if room < width then
			width = math.max(UiTheme.TOUCH, math.floor(room))
		end
		box = { x = x, y = y, w = width, h = height }
	end
	if box.y + box.h > viewportY - margin then
		box.y = math.max(margin, viewportY - margin - box.h)
	end
	if box.x + box.w > viewportX - margin then
		box.w = math.max(UiTheme.TOUCH, viewportX - margin - box.x)
	end
	if HudLayout.overlaps(box, block) then
		box.y = block.y + block.h + 8
	end
	return box
end

-- HudLayout.place(viewportX, viewportY, rowCount) wins when it returns a rect.
function StarterGoalHud.place(viewportX: number, viewportY: number, rowCount: number): Rect
	local vx = finite(viewportX)
	local vy = finite(viewportY)
	if vx == nil or vx < 1 then
		vx = 1280
	end
	if vy == nil or vy < 1 then
		vy = 800
	end
	local count = finite(rowCount)
	if count == nil then
		count = ROW_COUNT
	end
	count = math.floor(count)
	if not placing then
		placing = true
		local placed: Rect? = nil
		local hook = (HudLayout :: any).place
		if type(hook) == "function" then
			local ok, result = pcall(hook, viewportX, viewportY, rowCount)
			if ok then
				placed = readRect(result)
			end
		end
		placing = false
		if placed ~= nil then
			return placed
		end
	end
	return fallback(vx :: number, vy :: number, count)
end

local function viewport(): (number, number)
	local screen = screenRef
	if screen == nil then
		return 1280, 800
	end
	local size = screen.AbsoluteSize
	local vx = if size.X >= 200 then size.X else 1280
	local vy = if size.Y >= 200 then size.Y else 800
	return vx, vy
end

local function apply(rows: { Row })
	local frame = frameRef
	if frame == nil then
		return
	end
	local chromeState: Chrome? = nil
	if heldSettings ~= nil then
		chromeState = StarterGoalHud.chrome(heldSettings)
	end
	local show = StarterGoalHud.shown(#rows, heldSettings)
	frame.Visible = show
	local count = if #rows > 0 then #rows else 1
	local vx, vy = viewport()
	local box = StarterGoalHud.place(vx, vy, count)
	frame.Position = UDim2.fromOffset(box.x, box.y)
	if #rows > 0 then
		frame.Size = UDim2.fromOffset(box.w, box.h)
	end
	for index = 1, ROW_COUNT do
		local label = labels[index]
		local row = rows[index]
		if label ~= nil then
			if chromeState ~= nil then
				label.TextSize = chromeState.textSize
			end
			if row ~= nil then
				label.Visible = true
				label.Text = row.line
			else
				label.Visible = false
				label.Text = ""
			end
		end
	end
end

function StarterGoalHud.present(result: any)
	held = result
	apply(StarterGoalHud.rows(result))
end

function StarterGoalHud.applyChrome(settings: any)
	heldSettings = settings
	apply(StarterGoalHud.rows(held))
end

function StarterGoalHud.start(playerGui: PlayerGui)
	local host = playerGui:FindFirstChild("ShardfallHud")
	if host == nil or not host:IsA("ScreenGui") then
		return
	end
	local holder: Instance = host
	local chrome = host:FindFirstChild("Chrome")
	if chrome ~= nil and chrome:IsA("GuiObject") then
		holder = chrome
	end
	local function discard(root: Instance)
		local previous = root:FindFirstChild("StarterGoals")
		if previous ~= nil then
			previous:Destroy()
		end
	end
	discard(host)
	if holder ~= host then
		discard(holder)
	end
	labels = {} :: { TextLabel }
	screenRef = host

	local frame = Instance.new("Frame")
	frame.Name = "StarterGoals"
	frame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Active = false
	frame.Size = UDim2.fromOffset(WIDTH, ROW_COUNT * ROW_H + 8)
	frame.ZIndex = 2
	frame.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	for index = 1, ROW_COUNT do
		local label = Instance.new("TextLabel")
		label.Name = "Row" .. tostring(index)
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Position = UDim2.fromOffset(8, 4 + (index - 1) * ROW_H)
		label.Size = UDim2.new(1, -16, 0, ROW_H)
		label.Font = Enum.Font.BuilderSans
		label.TextSize = BASE_TEXT
		label:SetAttribute("BaseText", BASE_TEXT)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.TextColor3 = Color3.fromRGB(244, 240, 252)
		label.Text = ""
		label.Visible = false
		label.Active = false
		label.ZIndex = 2
		label.Parent = frame
		labels[index] = label
	end

	frameRef = frame
	apply(StarterGoalHud.rows(held))
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		apply(StarterGoalHud.rows(held))
	end)
end

return StarterGoalHud
