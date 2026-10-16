--!strict

--[[
	Wild capture prompt.

	The server owns the shiny roll and the tame. This panel only shows
	the prompt and the result. init.client.luau has to call
	CaptureHud.start(invoke). That file is Ghost's, so the panel stays
	dark until that hook lands. CombatHud is also Ghost's: do not parent
	this prompt from there on this branch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobileShell = require(script.Parent.MobileShell)
local WildCapture = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WildCapture"))

local CaptureHud = {}

export type CaptureCallbacks = {
	onAttempt: ((string) -> ())?,
	onDismiss: (() -> ())?,
}

local player = Players.LocalPlayer
local invokeRemote: ((string, ...any) -> any)? = nil
local onAttempt: ((string) -> ())? = nil
local onDismiss: (() -> ())? = nil
local enemyId = ""
local root: Frame? = nil
local statusLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local started = false
local queued: any = nil

local function setStatus(text: string)
	if statusLabel ~= nil then
		statusLabel.Text = text
	end
end

local function setBody(text: string)
	if bodyLabel ~= nil then
		bodyLabel.Text = text
	end
end

local function show()
	if root ~= nil then
		root.Visible = true
	end
end

local function hide()
	if root ~= nil then
		root.Visible = false
	end
end

local function applyPrompt(encounter: any)
	enemyId = if type(encounter.enemyId) == "string" then encounter.enemyId else ""
	local title = encounter.displayName
	if type(title) ~= "string" or title == "" then
		title = enemyId
	end
	if title == "" then
		title = "creature"
	end
	local percent = math.floor(WildCapture.CAPTURE_CHANCE * 100 + 0.5)
	setStatus("Shiny")
	setBody(
		string.format(
			"A shiny %s is here. Equip a Capture Charm for a %d%% chance to tame it.",
			title,
			percent
		)
	)
	show()
end

local function attempt()
	local id = enemyId
	local callback = onAttempt
	if callback ~= nil then
		callback(id)
		return
	end
	local invoke = invokeRemote
	if invoke == nil then
		CaptureHud.result("Capture is not wired yet.")
		return
	end
	task.spawn(function()
		local callOk, result = pcall(invoke, "Capture", "tame", { enemyId = id })
		if not callOk or type(result) ~= "table" then
			CaptureHud.result("Capture is not wired yet.")
			return
		end
		if result.ok == true then
			CaptureHud.result("Tamed " .. tostring(result.name) .. ".")
		else
			CaptureHud.result(tostring(result.error or "The shiny slipped away."))
		end
	end)
end

local function dismiss()
	local callback = onDismiss
	hide()
	if callback ~= nil then
		callback()
	end
end

function CaptureHud.prompt(encounter: any, callbacks: CaptureCallbacks?)
	if type(encounter) ~= "table" then
		return
	end
	if type(callbacks) == "table" then
		onAttempt = callbacks.onAttempt
		onDismiss = callbacks.onDismiss
	else
		onAttempt = nil
		onDismiss = nil
	end
	queued = encounter
	if root == nil then
		return
	end
	applyPrompt(encounter)
end

function CaptureHud.result(text: string)
	setStatus(text)
	setBody(text)
	show()
end

function CaptureHud.hide()
	hide()
end

function CaptureHud.start(invoke: (string, ...any) -> any)
	if started then
		invokeRemote = invoke
		return
	end
	started = true
	invokeRemote = invoke

	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallCapture"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 16
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local panel = Instance.new("Frame")
	panel.Name = "Capture"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.38)
	panel.Size = UDim2.fromOffset(340, 210)
	panel.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	root = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(12, 10)
	status.Size = UDim2.new(1, -24, 0, 28)
	status.Font = Enum.Font.BuilderSansBold
	status.TextSize = 18
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.fromRGB(255, 214, 96)
	status.Text = "Shiny"
	status.Parent = panel
	statusLabel = status

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(12, 42)
	body.Size = UDim2.new(1, -24, 0, 72)
	body.Font = Enum.Font.BuilderSans
	body.TextSize = 16
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(240, 236, 248)
	body.Text = "A shiny creature can be tamed with a Capture Charm."
	body.Parent = panel
	bodyLabel = body

	local function button(name: string, text: string, color: Color3, x: number, fn: () -> ())
		local control = Instance.new("TextButton")
		control.Name = name
		control.Position = UDim2.fromOffset(x, 132)
		control.Size = UDim2.fromOffset(148, 64)
		control.BackgroundColor3 = color
		control.BorderSizePixel = 0
		control.Font = Enum.Font.BuilderSansBold
		control.TextSize = 16
		control.TextColor3 = Color3.fromRGB(16, 14, 24)
		control.Text = text
		control.Parent = panel
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 12)
		buttonCorner.Parent = control
		control.Activated:Connect(fn)
	end

	button("Tame", "Tame", Color3.fromRGB(120, 186, 96), 12, attempt)
	button("Leave", "Leave", Color3.fromRGB(196, 96, 96), 176, dismiss)
	if queued ~= nil then
		applyPrompt(queued)
	end
end

return CaptureHud
