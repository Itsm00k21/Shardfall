--!strict

--[[
	Class select, Forge swap, and the four skill buttons.

	Swap is free and only refused while a crawl is active. Buttons are
	64px so a thumb can hit them. Empty class sound ids stay silent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Classes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Classes"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))

local ClassHud = {}

local player = Players.LocalPlayer
local latest: any = nil
local invoke: ((string, ...any) -> any)? = nil
local paint: () -> () = function() end
local panelRef: Frame? = nil

function ClassHud.close()
	if panelRef ~= nil then
		panelRef.Visible = false
	end
end

function ClassHud.isVisible(): boolean
	return panelRef ~= nil and panelRef.Visible
end

function ClassHud.setVisible(open: boolean)
	if panelRef ~= nil then
		panelRef.Visible = open
	end
end

function ClassHud.toggle()
	if panelRef ~= nil then
		panelRef.Visible = not panelRef.Visible
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
	screen.DisplayOrder = 12
	screen.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Classes"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromOffset(16, 140)
	panel.Size = UDim2.fromOffset(360, 220)
	panel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ClipsDescendants = true
	panel.Parent = screen
	panelRef = panel
	local function place()
		local camera = workspace.CurrentCamera
		local vx = if camera ~= nil then camera.ViewportSize.X else 1280
		local vy = if camera ~= nil then camera.ViewportSize.Y else 720
		if vx < 1 then
			vx = 1280
		end
		if vy < 1 then
			vy = 720
		end
		local box = ShellLayout.classRect(vx, vy)
		panel.Position = UDim2.fromOffset(box.x, box.y)
		panel.Size = UDim2.fromOffset(box.w, box.h)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 22)
	title.Font = Enum.Font.BuilderSansBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(240, 236, 248)
	title.Text = "Class"
	title.LayoutOrder = 1
	title.Parent = panel

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 64)
	row.LayoutOrder = 2
	row.Parent = panel
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
			return
		end
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
