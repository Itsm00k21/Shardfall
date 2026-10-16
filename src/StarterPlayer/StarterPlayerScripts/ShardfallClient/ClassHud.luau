--!strict

--[[
	Class sheet. It stays hidden until Skills or Change class.

	The frame is the opaque theme panel. It lists the class name and each
	skill with its cooldown and description. Change class opens the picker.
	Once that picker is open it stays until a class is picked or Close.
	Other panels and a late Haven prompt cannot dismiss that choice.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local MobileShell = require(script.Parent.MobileShell)

local ClassHud = {}

local player = Players.LocalPlayer
local latest: any = nil
local invoke: ((string, ...any) -> any)? = nil
local paint: () -> () = function() end
local panelRef: Frame? = nil
local held = false
local picking = false

local function syncHold()
	local showing = panelRef ~= nil and panelRef.Visible
	held = picking and showing
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
	picking = false
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
	if open then
		paint()
	else
		picking = false
	end
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
	panel.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Active = true
	panel.ClipsDescendants = true
	panel.Parent = screen
	panelRef = panel
	local function place()
		local vx, vy = MobileShell.view(screen)
		local box = ShellLayout.skillsRect(vx, vy)
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
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
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingLeft = UDim.new(0, UiTheme.PAD)
	bodyPad.PaddingRight = UDim.new(0, UiTheme.PAD)
	bodyPad.PaddingBottom = UDim.new(0, UiTheme.PAD)
	bodyPad.Parent = body
	local bodyList = Instance.new("UIListLayout")
	bodyList.FillDirection = Enum.FillDirection.Vertical
	bodyList.Padding = UDim.new(0, UiTheme.PAD)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.Parent = body

	local function card(text: string, color: Color3, height: number): TextButton
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, 0, 0, height)
		item.BackgroundColor3 = color
		item.BackgroundTransparency = 0
		item.BorderSizePixel = 0
		item.Font = Enum.Font.BuilderSansBold
		item.TextSize = UiTheme.MIN_TEXT
		item.TextWrapped = true
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextYAlignment = Enum.TextYAlignment.Top
		item.TextColor3 = Color3.fromRGB(16, 14, 24)
		item.Text = text
		item.Parent = body
		local itemPad = Instance.new("UIPadding")
		itemPad.PaddingTop = UDim.new(0, UiTheme.PAD)
		itemPad.PaddingBottom = UDim.new(0, UiTheme.PAD)
		itemPad.PaddingLeft = UDim.new(0, UiTheme.PAD)
		itemPad.PaddingRight = UDim.new(0, UiTheme.PAD)
		itemPad.Parent = item
		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, UiTheme.CORNER)
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

	local function clearCards()
		for _, child in ipairs(body:GetChildren()) do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end

	local function skillLine(skill: Classes.Skill): string
		return string.format("%s\n%d sec cooldown\n%s", skill.name, skill.cooldown, skill.note)
	end

	local function drawPicker()
		title.Text = "Pick a class. Swap later at the Forge."
		picking = true
		for _, entry in ipairs(Classes.all()) do
			local color = Color3.fromRGB(entry.palette[1], entry.palette[2], entry.palette[3])
			local pick = card(entry.name, color, UiTheme.TAP)
			pick.TextYAlignment = Enum.TextYAlignment.Center
			pick.TextXAlignment = Enum.TextXAlignment.Center
			pick.MouseButton1Click:Connect(function()
				picking = false
				call("SetClass", entry.id)
			end)
		end
		syncHold()
	end

	local function draw()
		clearCards()
		local classId = if type(latest) == "table" then latest.classId else ""
		local classDef = Classes.get(classId)
		if classDef == nil or picking then
			if classDef == nil then
				picking = true
			end
			drawPicker()
			return
		end
		picking = false
		held = false
		local level = if type(latest.classLevel) == "number" then latest.classLevel else 1
		title.Text = string.format("%s  Lv %d", classDef.name, level)
		local color = Color3.fromRGB(classDef.palette[1], classDef.palette[2], classDef.palette[3])
		for index, skill in ipairs(classDef.skills) do
			local cast = card(skillLine(skill), color, 88)
			cast.LayoutOrder = index
			cast.MouseButton1Click:Connect(function()
				playSound(classDef.sounds.skill)
				call("UseSkill", index)
			end)
		end
		local ult = card(skillLine(classDef.ultimate), Color3.fromRGB(255, 214, 120), 88)
		ult.Name = "Ultimate"
		ult.LayoutOrder = 20
		ult.MouseButton1Click:Connect(function()
			playSound(classDef.sounds.ult)
			call("UseSkill", "ult")
		end)
		local talentId = if type(latest.classTalent) == "table"
			then latest.classTalent[classId]
			else nil
		if level >= Classes.TALENT_LEVEL and type(talentId) ~= "string" then
			for index, talent in ipairs(classDef.talents) do
				local pick =
					card(talent.name .. "\n" .. talent.note, Color3.fromRGB(186, 160, 255), 72)
				pick.LayoutOrder = 30 + index
				pick.MouseButton1Click:Connect(function()
					call("PickTalent", talent.id)
				end)
			end
		end
		local change = card("Change class", Color3.fromRGB(210, 206, 220), UiTheme.TAP)
		change.Name = "ChangeClass"
		change.LayoutOrder = 40
		change.TextXAlignment = Enum.TextXAlignment.Center
		change.TextYAlignment = Enum.TextYAlignment.Center
		change.MouseButton1Click:Connect(function()
			picking = true
			draw()
		end)
		syncHold()
	end

	paint = draw
	remotes:WaitForChild("SetClass")
	paint()
end

return ClassHud
