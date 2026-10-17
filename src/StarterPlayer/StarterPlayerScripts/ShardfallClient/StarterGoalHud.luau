--!strict

--[[
	Starter-goal tracker.

	Paints up to three rows from a caller-supplied show result.
	Each row is that goal's sentence and its progress out of the
	goal. Progress above the goal is drawn at the goal. An empty
	list, or a result that is not ok, hides the tracker.

	The frame sits under Chrome when Chrome is a plain GuiObject.
	A live CanvasGroup does not draw children added after it is
	parented, so in that case the tracker is a sibling on the
	ScreenGui. applyChrome still hides it and sizes the text.
	A row is at least 18px, and it
	grows with the access text so a 20px label is not clipped in
	an 18px line. HudLayout.place(viewportX, viewportY, rowCount)
	supplies the rect when that function exists. Until then the
	rect sits under the health bar and drops below the toast host
	when they would overlap. On a phone it also stays off the
	equip prompt. A viewport that cannot hold that rect collapses
	the tracker instead of clamping it into the toast or off the
	screen.

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
-- HudShell prompt.Size is 36 + UiTheme.TOUCH + 8, under that host.
local PROMPT_TEXT = 36

export type Row = {
	text: string,
	progress: number,
	goal: number,
	line: string,
}

export type Rect = {
	x: number,
	y: number,
	w: number,
	h: number,
	collapsed: boolean?,
}

export type Chrome = {
	hidden: boolean,
	textScale: number,
	textSize: number,
	lineHeight: number,
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

-- 18px holds 14px text. The extra 4px stays as the text grows, so nothing clips.
function StarterGoalHud.lineHeight(textSize: any): number
	local size = finite(textSize)
	if size == nil or size < BASE_TEXT then
		size = BASE_TEXT
	end
	return math.max(ROW_H, math.floor(size) + ROW_H - BASE_TEXT)
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
		lineHeight = StarterGoalHud.lineHeight(textSize),
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

-- Same spot as HudShell's equip prompt: just under the three-card host.
local function equipPrompt(viewportX: number, margin: number): Rect
	local toast = HudLayout.toast(viewportX, margin)
	local host = toastHost(viewportX, margin)
	return {
		x = toast.x,
		y = host.y + host.h + TOAST_GAP,
		w = toast.w,
		h = PROMPT_TEXT + UiTheme.TOUCH + TOAST_GAP,
	}
end

local function hideRect(): Rect
	return { x = 0, y = 0, w = 0, h = 0, collapsed = true }
end

local function onScreen(box: Rect, viewportX: number, viewportY: number, margin: number): boolean
	if box.w < UiTheme.TOUCH or box.h <= 0 then
		return false
	end
	if box.x < margin or box.y < margin then
		return false
	end
	if box.x + box.w > viewportX - margin then
		return false
	end
	if box.y + box.h > viewportY - margin then
		return false
	end
	return true
end

local function fitWidth(viewportX: number, margin: number, originX: number): number?
	local room = viewportX - margin - originX
	if room < UiTheme.TOUCH then
		return nil
	end
	if room < WIDTH then
		return math.floor(room)
	end
	return WIDTH
end

local function clearOf(box: Rect, block: Rect, prompt: Rect, rail: Rect): boolean
	if HudLayout.overlaps(box, block) or HudLayout.overlaps(box, prompt) then
		return false
	end
	if HudLayout.overlaps(box, rail) then
		return false
	end
	return true
end

local function fallback(viewportX: number, viewportY: number, rowCount: number, lineH: number): Rect
	local margin = UiTheme.safeMargin()
	local rows = rowCount
	if rows < 1 then
		rows = 1
	elseif rows > ROW_COUNT then
		rows = ROW_COUNT
	end
	local health = HudLayout.health(margin)
	local height = rows * lineH + 8
	local x = health.x + 8
	local y = health.y + health.h + 8
	local width = fitWidth(viewportX, margin, x)
	if width == nil then
		return hideRect()
	end
	local box: Rect = { x = x, y = y, w = width, h = height }
	local block = toastHost(viewportX, margin)
	local prompt = equipPrompt(viewportX, margin)
	local railFit = HudLayout.railFit(viewportY, margin, RAIL_COUNT, UiTheme.TAP, UiTheme.TOUCH)
	local rail: Rect = { x = railFit.x, y = railFit.y, w = railFit.w, h = railFit.h }
	local railRight = railFit.x + railFit.w + TOAST_GAP
	local phone = HudLayout.breakpoint(viewportX, viewportY) == "phone"

	if HudLayout.overlaps(box, block) then
		local nextX = x
		if nextX < railRight then
			nextX = railRight
		end
		local nextW = fitWidth(viewportX, margin, nextX)
		if nextW ~= nil then
			box = { x = nextX, y = block.y + block.h + TOAST_GAP, w = nextW, h = height }
		end
	end

	-- Phones only. Prefer the full width just under the prompt. A short
	-- phone that cannot hold that uses the gap beside the prompt instead.
	if phone and HudLayout.overlaps(box, prompt) then
		local moved = false
		local originX = x
		if originX < railRight then
			originX = railRight
		end
		local belowW = fitWidth(viewportX, margin, originX)
		if belowW ~= nil then
			local below: Rect = {
				x = originX,
				y = prompt.y + prompt.h + TOAST_GAP,
				w = belowW,
				h = height,
			}
			if
				onScreen(below, viewportX, viewportY, margin)
				and clearOf(below, block, prompt, rail)
			then
				box = below
				moved = true
			end
		end
		if not moved then
			local slots: { Rect } = {}
			local limit = math.min(block.x, prompt.x) - TOAST_GAP
			local leftW = math.floor(limit - railRight)
			if leftW > WIDTH then
				leftW = WIDTH
			end
			if leftW >= UiTheme.TOUCH then
				table.insert(slots, { x = railRight, y = box.y, w = leftW, h = height })
			end
			local rightX = math.max(block.x + block.w, prompt.x + prompt.w) + TOAST_GAP
			if rightX < railRight then
				rightX = railRight
			end
			local rightW = fitWidth(viewportX, margin, rightX)
			if rightW ~= nil then
				table.insert(slots, { x = rightX, y = box.y, w = rightW, h = height })
			end
			for _, slot in ipairs(slots) do
				if
					onScreen(slot, viewportX, viewportY, margin)
					and clearOf(slot, block, prompt, rail)
				then
					box = slot
					break
				end
			end
		end
	end

	if not onScreen(box, viewportX, viewportY, margin) or HudLayout.overlaps(box, block) then
		return hideRect()
	end
	if phone and HudLayout.overlaps(box, prompt) then
		return hideRect()
	end
	return box
end

-- HudLayout.place(viewportX, viewportY, rowCount) wins when it returns a rect.
function StarterGoalHud.place(
	viewportX: number,
	viewportY: number,
	rowCount: number,
	textSize: number?
): Rect
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
	return fallback(vx :: number, vy :: number, count, StarterGoalHud.lineHeight(textSize))
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
	local textSize = BASE_TEXT
	local lineH = ROW_H
	if heldSettings ~= nil then
		local chromeState = StarterGoalHud.chrome(heldSettings)
		textSize = chromeState.textSize
		lineH = chromeState.lineHeight
	end
	local count = if #rows > 0 then #rows else 1
	local vx, vy = viewport()
	local box = StarterGoalHud.place(vx, vy, count, textSize)
	local show = StarterGoalHud.shown(#rows, heldSettings)
	if box.collapsed == true then
		show = false
	end
	frame.Visible = show
	if box.collapsed ~= true then
		frame.Position = UDim2.fromOffset(box.x, box.y)
		if #rows > 0 then
			frame.Size = UDim2.fromOffset(box.w, box.h)
		end
	end
	for index = 1, ROW_COUNT do
		local label = labels[index]
		local row = rows[index]
		if label ~= nil then
			label.TextSize = textSize
			label.Position = UDim2.fromOffset(8, 4 + (index - 1) * lineH)
			label.Size = UDim2.new(1, -16, 0, lineH)
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
	if chrome ~= nil and chrome:IsA("GuiObject") and not chrome:IsA("CanvasGroup") then
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
	frame.BackgroundTransparency = 0.08
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
	task.defer(function()
		apply(StarterGoalHud.rows(held))
	end)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		apply(StarterGoalHud.rows(held))
	end)
end

return StarterGoalHud
