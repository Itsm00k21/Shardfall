--!strict

--[[
	Heartwood buttons. Each target is 64px.
	Story queue, Normal queue, a premade post, Practice Grove, the vendor,
	a premade leave, and the premade ready check. Leave drops the seat
	while the player is connected. Ready asks the server to score the
	seated party. The client does not send a host, a member list, or
	anyone else's ready flag.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobileShell = require(script.Parent.MobileShell)
local EchoChip = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EchoChip"))
local RaidPremadeHop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidPremadeHop"))

local RaidHud = {}
local player = Players.LocalPlayer
local statusLabel: TextLabel? = nil
local rowRef: Frame? = nil
local toggleRef: TextButton? = nil
local chipRef: TextLabel? = nil
local listener: ((boolean) -> ())? = nil

local function showEcho(label: any)
	local chip = chipRef
	if chip == nil then
		return
	end
	if type(label) ~= "string" or label == "" then
		chip.Text = ""
		chip.Visible = false
		return
	end
	chip.Text = label
	chip.Visible = true
end

function RaidHud.showEcho(label: any)
	showEcho(label)
end

function RaidHud.setListener(fn: (boolean) -> ())
	listener = fn
end

function RaidHud.close()
	if rowRef ~= nil then
		rowRef.Visible = false
	end
	if statusLabel ~= nil then
		statusLabel.Visible = false
	end
end

function RaidHud.isOpen(): boolean
	return rowRef ~= nil and rowRef.Visible
end

local function show(result: any)
	if statusLabel == nil or type(result) ~= "table" then
		return
	end
	if type(result.error) == "string" then
		statusLabel.Text = result.error
	elseif type(result.note) == "string" then
		statusLabel.Text = result.note
	end
end

function RaidHud.setProfile(profile: any)
	if statusLabel == nil or type(profile) ~= "table" then
		return
	end
	local marks = profile.raidMarks or 0
	local best = profile.raidBest or 0
	local line = string.format("Marks %d", marks)
	if profile.raidStory == true then
		line ..= "  Story clear"
	end
	if best > 0 then
		line ..= string.format("  Normal %ds", best)
	end
	if statusLabel.Text == "Heartwood" or string.sub(statusLabel.Text, 1, 5) == "Marks" then
		statusLabel.Text = line
	end
	if toggleRef ~= nil then
		toggleRef.Text = "Raid"
	end
end

function RaidHud.start(invoke: (string, ...any) -> any)
	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallRaids"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 13
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local toggle = Instance.new("TextButton")
	toggle.Name = "RaidToggle"
	toggle.AnchorPoint = Vector2.new(0, 0)
	toggle.Position = UDim2.fromOffset(120, 60)
	toggle.Size = UDim2.fromOffset(96, 64)
	toggle.BackgroundColor3 = Color3.fromRGB(140, 96, 64)
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansBold
	toggle.TextSize = 13
	toggle.TextWrapped = true
	toggle.TextColor3 = Color3.fromRGB(16, 14, 24)
	toggle.Text = "Raid"
	toggle.Visible = false
	toggle.Parent = screen
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 12)
	toggleCorner.Parent = toggle
	toggleRef = toggle

	local chip = Instance.new("TextLabel")
	chip.Name = "EchoChip"
	chip.AnchorPoint = Vector2.new(0, 0)
	chip.BackgroundColor3 = Color3.fromRGB(120, 186, 96)
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.BuilderSansBold
	chip.TextSize = 14
	chip.TextColor3 = Color3.fromRGB(16, 14, 24)
	chip.Text = ""
	chip.Visible = false
	chip.Parent = screen
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, 12)
	chipCorner.Parent = chip
	chipRef = chip

	-- Right edge of the safe rect. A side under 200 uses the portrait
	-- phone, the same fallback EchoChip uses for a bad size.
	local function placeChip()
		local size = screen.AbsoluteSize
		local vx = size.X
		local vy = size.Y
		if vx < 200 or vy < 200 then
			vx = 390
			vy = 844
		end
		local slot = EchoChip.place(vx, vy)
		chip.Position = UDim2.fromOffset(slot.x, slot.y)
		chip.Size = UDim2.fromOffset(slot.w, slot.h)
	end
	placeChip()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeChip)

	local row = Instance.new("Frame")
	row.Name = "Raid"
	row.AnchorPoint = Vector2.new(0, 0)
	row.Position = UDim2.fromOffset(120, 132)
	row.Size = UDim2.fromOffset(420, 134)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = screen
	rowRef = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Wraps = true
	layout.Parent = row

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.AnchorPoint = Vector2.new(0, 0)
	note.Position = UDim2.fromOffset(120, 272)
	note.Size = UDim2.fromOffset(420, 32)
	note.Font = Enum.Font.BuilderSans
	note.TextSize = 13
	note.TextColor3 = Color3.fromRGB(240, 236, 248)
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextWrapped = true
	note.Text = "Heartwood"
	note.Visible = false
	note.Parent = screen
	statusLabel = note

	toggle.Activated:Connect(function()
		local opening = not row.Visible
		if listener ~= nil then
			listener(opening)
		end
		row.Visible = opening
		note.Visible = opening
	end)

	local function button(name: string, text: string, color: Color3, callback: () -> ())
		local hit = Instance.new("TextButton")
		hit.Name = name
		hit.Size = UDim2.fromOffset(64, 64)
		hit.BackgroundColor3 = color
		hit.BorderSizePixel = 0
		hit.Font = Enum.Font.BuilderSansBold
		hit.TextSize = 12
		hit.TextColor3 = Color3.fromRGB(16, 14, 24)
		hit.TextWrapped = true
		hit.Text = text
		hit.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = hit
		hit.Activated:Connect(callback)
	end

	button("Story", "Story", Color3.fromRGB(120, 186, 96), function()
		show(invoke("RaidQueue", "story", "flex"))
	end)
	button("Normal", "Normal", Color3.fromRGB(214, 176, 92), function()
		show(invoke("RaidQueue", "normal", "flex"))
	end)
	button("Board", "Board", Color3.fromRGB(140, 160, 210), function()
		show(invoke("RaidPost", "Learning", "story"))
	end)
	button("Practice", "Practice", Color3.fromRGB(186, 140, 96), function()
		show(invoke("RaidPractice", 1, 1))
	end)
	button("Marks", "Marks", Color3.fromRGB(186, 96, 120), function()
		show(invoke("RaidBuy", "rare_chest"))
	end)
	button("Leave", "Leave", Color3.fromRGB(110, 118, 140), function()
		show(invoke("RaidLeave"))
	end)
	button("Ready", "Ready", Color3.fromRGB(96, 168, 140), function()
		show(invoke("RaidReady"))
	end)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
	end
	if remotes == nil then
		warn("[Shardfall] Remotes are not available")
		return
	end
	local fx = remotes:FindFirstChild("CombatFx")
	if fx == nil then
		fx = remotes:WaitForChild("CombatFx", 15)
	end
	if fx == nil then
		warn("[Shardfall] CombatFx remote is not available")
		return
	end
	if fx:IsA("RemoteEvent") then
		fx.OnClientEvent:Connect(function(payload: any)
			if type(payload) ~= "table" then
				return
			end
			if payload.kind == "victory" or payload.kind == "defeat" then
				showEcho(nil)
				return
			end
			if payload.kind == "premadeRecall" then
				-- The server already decided this player was recalled.
				-- Paint the frozen seated line. Do not read a client id.
				show({ error = RaidPremadeHop.ERRORS.seated })
				if statusLabel ~= nil then
					statusLabel.Visible = true
				end
				return
			end
			if payload.kind ~= "run" then
				return
			end
			local run = payload.run
			if type(run) ~= "table" or run.active ~= true then
				showEcho(nil)
				return
			end
			showEcho(run.echoLabel)
		end)
	end
end

return RaidHud
