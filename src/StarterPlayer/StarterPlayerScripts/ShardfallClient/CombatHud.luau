--!strict

--[[
	Health bar, floating numbers, and the victory card.

	The server already decided the hit. CombatFx tells this script where to
	draw it. Clicking the world (not a button) sends Attack with the camera
	direction. The panel's Attack button calls CombatHud.swing() too.

	While the player is steering (keyboard, gamepad, or the touch thumbstick),
	this script tells the server so Auto-Farm stops issuing MoveTo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatHud = {}

export type Callbacks = {
	onRun: (any) -> (),
	onHint: (string) -> (),
}

local player = Players.LocalPlayer
local attackRemote: RemoteEvent? = nil

local function floater(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumber"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 28)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 22
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui

	local born = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		anchor.Position = position + Vector3.new(0, age * 3.2, 0)
		local fade = math.clamp((age - 0.4) / 0.4, 0, 1)
		label.TextTransparency = fade
		label.TextStrokeTransparency = 0.35 + fade * 0.65
		if age >= 0.85 then
			if connection ~= nil then
				connection:Disconnect()
			end
			anchor:Destroy()
		end
	end)
end

local function numberFrom(payload: any, key: string): number?
	local value = payload[key]
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return value
end

function CombatHud.swing()
	local remote = attackRemote
	if remote == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local look = if camera ~= nil then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	remote:FireServer(look.X, look.Y, look.Z)
end

function CombatHud.start(remotes: Instance, callbacks: Callbacks)
	local attack = remotes:WaitForChild("Attack")
	local fx = remotes:WaitForChild("CombatFx")
	assert(attack:IsA("RemoteEvent"), "Attack remote missing")
	assert(fx:IsA("RemoteEvent"), "CombatFx remote missing")
	attackRemote = attack

	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallCombat"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 8
	screen.Parent = player:WaitForChild("PlayerGui")

	local hpFrame = Instance.new("Frame")
	hpFrame.Name = "Health"
	hpFrame.AnchorPoint = Vector2.new(0, 0)
	hpFrame.Position = UDim2.fromOffset(16, 16)
	hpFrame.Size = UDim2.fromOffset(220, 36)
	hpFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	hpFrame.BorderSizePixel = 0
	hpFrame.Parent = screen
	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 8)
	hpCorner.Parent = hpFrame

	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromOffset(10, 2)
	hpText.Size = UDim2.new(1, -20, 0, 16)
	hpText.Font = Enum.Font.BuilderSansBold
	hpText.TextSize = 13
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.TextColor3 = Color3.fromRGB(240, 236, 248)
	hpText.Text = "HP 100 / 100"
	hpText.Parent = hpFrame

	local hpBack = Instance.new("Frame")
	hpBack.Position = UDim2.fromOffset(10, 22)
	hpBack.Size = UDim2.new(1, -20, 0, 8)
	hpBack.BackgroundColor3 = Color3.fromRGB(40, 34, 58)
	hpBack.BorderSizePixel = 0
	hpBack.Parent = hpFrame
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 4)
	backCorner.Parent = hpBack

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(110, 210, 140)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = hpFill

	local function setHp(hp: number, maxHp: number)
		local safeMax = if maxHp > 0 then maxHp else 1
		hpText.Text = string.format("HP  %d / %d", math.floor(hp + 0.5), math.floor(safeMax + 0.5))
		hpFill.Size = UDim2.fromScale(math.clamp(hp / safeMax, 0, 1), 1)
		hpFill.BackgroundColor3 = if hp / safeMax < 0.3
			then Color3.fromRGB(230, 80, 96)
			else Color3.fromRGB(110, 210, 140)
	end

	local card = Instance.new("Frame")
	card.Name = "Result"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.38, 0.45)
	card.Size = UDim2.fromOffset(340, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screen
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card
	local cardPad = Instance.new("UIPadding")
	cardPad.PaddingTop = UDim.new(0, 16)
	cardPad.PaddingBottom = UDim.new(0, 16)
	cardPad.PaddingLeft = UDim.new(0, 16)
	cardPad.PaddingRight = UDim.new(0, 16)
	cardPad.Parent = card
	local cardList = Instance.new("UIListLayout")
	cardList.Padding = UDim.new(0, 6)
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.BackgroundTransparency = 1
	cardTitle.Size = UDim2.new(1, 0, 0, 28)
	cardTitle.Font = Enum.Font.BuilderSansBold
	cardTitle.TextSize = 22
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.TextColor3 = Color3.fromRGB(255, 196, 64)
	cardTitle.Text = ""
	cardTitle.LayoutOrder = 1
	cardTitle.Parent = card

	local cardBody = Instance.new("TextLabel")
	cardBody.BackgroundTransparency = 1
	cardBody.Size = UDim2.new(1, 0, 0, 20)
	cardBody.AutomaticSize = Enum.AutomaticSize.Y
	cardBody.Font = Enum.Font.BuilderSans
	cardBody.TextSize = 15
	cardBody.TextWrapped = true
	cardBody.TextXAlignment = Enum.TextXAlignment.Left
	cardBody.TextYAlignment = Enum.TextYAlignment.Top
	cardBody.TextColor3 = Color3.fromRGB(240, 236, 248)
	cardBody.Text = ""
	cardBody.LayoutOrder = 2
	cardBody.Parent = card

	local dismiss = Instance.new("TextButton")
	dismiss.Size = UDim2.new(1, 0, 0, 32)
	dismiss.BackgroundColor3 = Color3.fromRGB(108, 78, 196)
	dismiss.BorderSizePixel = 0
	dismiss.Font = Enum.Font.BuilderSansBold
	dismiss.TextSize = 15
	dismiss.TextColor3 = Color3.fromRGB(240, 236, 248)
	dismiss.Text = "Continue"
	dismiss.LayoutOrder = 3
	dismiss.Parent = card
	local dismissCorner = Instance.new("UICorner")
	dismissCorner.CornerRadius = UDim.new(0, 8)
	dismissCorner.Parent = dismiss

	local cardGeneration = 0
	local function hideCard()
		card.Visible = false
	end
	dismiss.MouseButton1Click:Connect(hideCard)

	local function showCard(title: string, body: string, titleColor: Color3, hold: number?)
		cardGeneration += 1
		local generation = cardGeneration
		cardTitle.Text = title
		cardTitle.TextColor3 = titleColor
		cardBody.Text = body
		card.Visible = true
		local seconds = hold
		if seconds == nil or seconds <= 0 then
			seconds = 6
		end
		task.delay(seconds, function()
			if generation == cardGeneration then
				hideCard()
			end
		end)
	end

	local function victoryBody(payload: any): string
		local lines = {}
		local gold = numberFrom(payload, "gold") or 0
		local bonus = numberFrom(payload, "bonusGold") or 0
		if bonus > 0 then
			table.insert(lines, string.format("Gold  %d + %d Gold Find", gold, bonus))
		else
			table.insert(lines, string.format("Gold  %d", gold))
		end
		table.insert(
			lines,
			string.format("Shard tokens  %d", numberFrom(payload, "shardTokens") or 0)
		)
		table.insert(lines, string.format("XP  %d", numberFrom(payload, "xp") or 0))
		if type(payload.materials) == "table" then
			local shown = {}
			for _, row in ipairs(payload.materials) do
				if type(row) == "string" then
					table.insert(shown, row)
				elseif type(row) == "table" and type(row.name) == "string" then
					local count = tonumber(row.count)
					if count ~= nil and count > 0 then
						table.insert(shown, string.format("%s x%d", row.name, count))
					end
				end
			end
			if #shown > 0 then
				table.insert(lines, "Materials")
				for _, line in ipairs(shown) do
					table.insert(lines, line)
				end
			end
		end
		if payload.voucher == "armory" then
			table.insert(lines, "Voucher  one free Armory crack")
		elseif payload.voucher == "pets" then
			table.insert(lines, "Voucher  one free Pets crack")
		else
			table.insert(lines, "No roll voucher this clear.")
		end
		return table.concat(lines, "\n")
	end

	fx.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.kind == "damage" or payload.kind == "heal" then
			local x = numberFrom(payload, "x")
			local y = numberFrom(payload, "y")
			local z = numberFrom(payload, "z")
			local amount = numberFrom(payload, "amount")
			if x == nil or y == nil or z == nil or amount == nil then
				return
			end
			local color = Color3.fromRGB(245, 240, 230)
			local text = tostring(math.floor(amount + 0.5))
			if payload.kind == "heal" then
				color = Color3.fromRGB(110, 210, 140)
				text = "+" .. text
			elseif payload.crit == true then
				color = Color3.fromRGB(255, 196, 64)
				text = text .. "!"
			end
			floater(Vector3.new(x, y, z), text, color)
		elseif payload.kind == "hp" then
			local hp = numberFrom(payload, "hp")
			local maxHp = numberFrom(payload, "maxHp")
			if hp ~= nil and maxHp ~= nil then
				setHp(hp, maxHp)
			end
		elseif payload.kind == "run" then
			callbacks.onRun(payload.run)
			if type(payload.text) == "string" and payload.text ~= "" then
				callbacks.onHint(payload.text)
			end
		elseif payload.kind == "hint" then
			if type(payload.text) == "string" then
				callbacks.onHint(payload.text)
			end
		elseif payload.kind == "victory" then
			local title = if type(payload.dungeonName) == "string"
				then payload.dungeonName .. " cleared"
				else "Rootvault cleared"
			showCard(
				title,
				victoryBody(payload),
				Color3.fromRGB(255, 196, 64),
				numberFrom(payload, "dismissIn")
			)
			callbacks.onRun({ active = false })
		elseif payload.kind == "defeat" then
			local text = if type(payload.text) == "string" then payload.text else "Defeated."
			showCard(
				"Defeated",
				text,
				Color3.fromRGB(230, 80, 96),
				numberFrom(payload, "dismissIn")
			)
			callbacks.onRun({ active = false })
		end
	end)

	local steer = remotes:FindFirstChild("Steer")
	local lastSteer = 0
	local wasSteering = false
	local controls: any = nil
	local function moveVector(): Vector3
		if controls == nil then
			local scripts = player:FindFirstChild("PlayerScripts")
			local moduleScript = if scripts ~= nil
				then scripts:FindFirstChild("PlayerModule")
				else nil
			if moduleScript ~= nil and moduleScript:IsA("ModuleScript") then
				local ok, module = pcall(require, moduleScript)
				if ok and type(module) == "table" and type(module.GetControls) == "function" then
					local fetchedOk, fetched = pcall(function()
						return module:GetControls()
					end)
					if fetchedOk then
						controls = fetched
					end
				end
			end
		end
		if type(controls) == "table" and type(controls.GetMoveVector) == "function" then
			local ok, vector = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and typeof(vector) == "Vector3" then
				return vector
			end
		end
		local down = UserInputService:IsKeyDown(Enum.KeyCode.W)
			or UserInputService:IsKeyDown(Enum.KeyCode.A)
			or UserInputService:IsKeyDown(Enum.KeyCode.S)
			or UserInputService:IsKeyDown(Enum.KeyCode.D)
		return if down then Vector3.new(1, 0, 0) else Vector3.zero
	end
	RunService.Heartbeat:Connect(function()
		if steer == nil or not steer:IsA("RemoteEvent") then
			return
		end
		local steering = moveVector().Magnitude > 0.15
		local now = os.clock()
		if steering then
			if not wasSteering or now - lastSteer > 0.35 then
				steer:FireServer(true)
				lastSteer = now
			end
		elseif wasSteering then
			steer:FireServer(false)
		end
		wasSteering = steering
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			CombatHud.swing()
		end
	end)
end

return CombatHud
