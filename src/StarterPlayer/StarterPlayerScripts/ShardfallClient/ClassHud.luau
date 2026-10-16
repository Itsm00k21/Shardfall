--!strict

--[[
	Class select, Forge swap, and the four skill buttons.

	Swap is free and only refused while a crawl is active. Buttons are
	64px so a thumb can hit them. Empty class sound ids stay silent.

	With no class chosen, the picker stays up until a class is picked or
	the player closes it. Other panels and a late Haven prompt cannot
	dismiss it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local MobileShell = require(script.Parent.MobileShell)

local ClassHud = {}

local player = Players.LocalPlayer
local latest: any = nil
local invoke: ((string, ...any) -> any)? = nil
local paint: () -> () = function() end
local panelRef: Frame? = nil
local held = false

local function classMissing(): boolean
	local classId = if type(latest) == "table" then latest.classId else ""
	return Classes.get(classId) == nil
end

local function syncHold()
	local showing = panelRef ~= nil and panelRef.Visible
	held = classMissing() and showing
end

function ClassHud.holdsChoice(): boolean
	return held and panelRef ~= nil and panelRef.Visible
end

function ClassHud.close()
	if held then
		if panelRef ~= nil then
			panelRef.Visible = true
		end
		return
	end
	if panelRef ~= nil then
		panelRef.Visible = false
	end
end

function ClassHud.dismiss()
	held = false
	if panelRef ~= nil then
		panelRef.Visible = false
	end
end

function ClassHud.isVisible(): boolean
	return panelRef ~= nil and panelRef.Visible
end

function ClassHud.setVisible(open: boolean)
	if panelRef == nil then
		return
	end
	if not open and held then
		panelRef.Visible = true
		return
	end
	panelRef.Visible = open
	syncHold()
end

function ClassHud.toggle()
	if ClassHud.isVisible() then
		ClassHud.dismiss()
	else
		ClassHud.setVisible(true)
	end
end

local function playSound(id: string)
	if string.match(id, "^rbxassetid://%d+$") == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	local group = SoundService:FindFirstChild("SFX")
	if group ~= nil and group:IsA("SoundGroup") then
		sound.SoundGroup = group
	end
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function ClassHud.setProfile(profile: any)
	latest = profile
	paint()
end

function ClassHud.start(remotes: Instance, callRemote: (string, ...any) -> any)
	invoke = callRemote
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallClasses"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 55
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.IgnoreGuiInset = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Classes"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromOffset(16, 140)
	panel.Size = UDim2.fromOffset(360, 220)
	panel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Active = true
	panel.ClipsDescendants = true
	panel.Parent = screen
	panelRef = panel
	local function place()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.classRect(vx, vy)
		local bar = ShellLayout.actionBar(vx, vy)
		local pet = ShellLayout.petRect()
		local minY = pet.y + pet.h + 8
		local bottom = bar.y - 8
		local h = math.max(box.h, 120)
		local y = box.y
		if y + h > bottom then
			y = math.max(minY, bottom - h)
		end
		if y < minY then
			y = minY
		end
		h = math.max(64, math.min(h, bottom - y))
		panel.Position = UDim2.fromOffset(box.x, y)
		panel.Size = UDim2.fromOffset(math.max(box.w, 220), h)
		if held then
			panel.Visible = true
		end
	end
	place()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 48)
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 4)
	title.Size = UDim2.new(1, -88, 1, -4)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 16
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextColor3 = Color3.fromRGB(240, 236, 248)
	title.Text = "Class"
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -8, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(72, 36)
	closeButton.BackgroundColor3 = Color3.fromRGB(54, 48, 72)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.BuilderSansBold
	closeButton.TextSize = 14
	closeButton.TextColor3 = Color3.fromRGB(240, 236, 248)
	closeButton.Text = "Close"
	closeButton.Parent = header
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	closeButton.MouseButton1Click:Connect(function()
		ClassHud.dismiss()
	end)

	local body = Instance.new("ScrollingFrame")
	body.Name = "Choices"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, 48)
	body.Size = UDim2.new(1, 0, 1, -48)
	body.ScrollBarThickness = 6
	body.ScrollingDirection = Enum.ScrollingDirection.XY
	body.AutomaticCanvasSize = Enum.AutomaticCanvasSize.XY
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.Parent = panel
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingLeft = UDim.new(0, 8)
	bodyPad.PaddingRight = UDim.new(0, 8)
	bodyPad.PaddingBottom = UDim.new(0, 8)
	bodyPad.Parent = body

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(0, 64)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Parent = body
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = row

	local function button(parent: Instance, text: string, color: Color3, width: number): TextButton
		local item = Instance.new("TextButton")
		item.Size = UDim2.fromOffset(width, 64)
		item.BackgroundColor3 = color
		item.BorderSizePixel = 0
		item.Font = Enum.Font.BuilderSansBold
		item.TextSize = 13
		item.TextWrapped = true
		item.TextColor3 = Color3.fromRGB(16, 14, 24)
		item.Text = text
		item.Parent = parent
		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 10)
		itemCorner.Parent = item
		return item
	end

	local function call(action: string, ...: any)
		local remote = invoke
		if remote == nil then
			return
		end
		task.spawn(function(...)
			pcall(remote, action, ...)
		end, ...)
	end

	local function draw()
		for _, child in ipairs(row:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local classId = if type(latest) == "table" then latest.classId else ""
		local classDef = Classes.get(classId)
		if classDef == nil then
			title.Text = "Pick a class. Swap later at the Forge."
			for _, entry in ipairs(Classes.all()) do
				local color = Color3.fromRGB(entry.palette[1], entry.palette[2], entry.palette[3])
				local pick = button(row, entry.name, color, 64)
				pick.MouseButton1Click:Connect(function()
					call("SetClass", entry.id)
				end)
			end
			syncHold()
			if held and panelRef ~= nil then
				panelRef.Visible = true
			end
			return
		end
		held = false
		local level = if type(latest.classLevel) == "number" then latest.classLevel else 1
		title.Text = string.format("%s  Lv %d  ·  %s", classDef.name, level, classDef.resource)
		for index, skill in ipairs(classDef.skills) do
			local color =
				Color3.fromRGB(classDef.palette[1], classDef.palette[2], classDef.palette[3])
			local cast = button(row, skill.name, color, 64)
			cast.MouseButton1Click:Connect(function()
				playSound(classDef.sounds.skill)
				call("UseSkill", index)
			end)
		end
		local ult = button(row, "Ult", Color3.fromRGB(255, 214, 120), 64)
		ult.MouseButton1Click:Connect(function()
			playSound(classDef.sounds.ult)
			call("UseSkill", "ult")
		end)
		local swap = button(row, "Swap", Color3.fromRGB(210, 206, 220), 64)
		swap.MouseButton1Click:Connect(function()
			if type(latest) == "table" then
				latest.classId = ""
			end
			draw()
		end)
		local talentId = if type(latest.classTalent) == "table"
			then latest.classTalent[classId]
			else nil
		if level >= Classes.TALENT_LEVEL and type(talentId) ~= "string" then
			for _, talent in ipairs(classDef.talents) do
				local pick = button(row, talent.name, Color3.fromRGB(186, 160, 255), 64)
				pick.MouseButton1Click:Connect(function()
					call("PickTalent", talent.id)
				end)
			end
		end
	end

	paint = draw
	remotes:WaitForChild("SetClass")
	paint()
end

return ClassHud
