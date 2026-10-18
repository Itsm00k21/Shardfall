--!strict

--[[
	Health bar, floating numbers, and the victory card.

	The server already decided the hit. CombatFx tells this script where to
	draw it. A Codex snapshot puts a color icon over the boss. Clicking
	the world (not a button) sends Attack with the camera direction.
	The panel's Attack button calls CombatHud.swing() too.

	While the player is steering (keyboard, gamepad, or the touch thumbstick),
	this script tells the server so Auto-Farm stops issuing MoveTo.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Audio = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Audio"))
local CodexCues = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CodexCues"))
local CombatFeel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatFeel"))
local CombatMath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CombatMath"))
local Keybinds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Keybinds"))
local CombatStage = require(script.Parent:WaitForChild("CombatStage"))
local ShellLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShellLayout"))
local MobileShell = require(script.Parent.MobileShell)

local CombatHud = {}

local function playCue(name: string)
	local id = Audio.cue(name)
	if id == nil then
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
	Debris:AddItem(sound, 4)
end

export type Callbacks = {
	onRun: (any) -> (),
	onHint: (string) -> (),
	onDodgeCharges: ((number) -> ())?,
}

local player = Players.LocalPlayer
local attackRemote: RemoteEvent? = nil
local dodgeRemote: RemoteEvent? = nil
local allowShake = true
local walletLabel: TextLabel? = nil
local pendingWallet: { number }? = nil

local function paintWallet(gold: number, tokens: number, gems: number)
	local label = walletLabel
	if label == nil then
		pendingWallet = { gold, tokens, gems }
		return
	end
	label.Text =
		string.format("%dg  %dt  %dgm", math.floor(gold), math.floor(tokens), math.floor(gems))
end

function CombatHud.setWallet(gold: number, tokens: number, gems: number)
	paintWallet(gold, tokens, gems)
end

local function floater(position: Vector3, text: string, color: Color3, textSize: number?)
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
	label.TextSize = if textSize ~= nil then textSize else 22
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

local function lookVector(): Vector3
	local camera = workspace.CurrentCamera
	return if camera ~= nil then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
end

function CombatHud.swing(charged: boolean?)
	local remote = attackRemote
	if remote == nil then
		return
	end
	local look = lookVector()
	if charged == true then
		-- The server starts its own hold. The boolean on the later packet is ignored.
		remote:FireServer(look.X, look.Y, look.Z, "begin")
		task.delay(CombatFeel.CHARGE_HOLD, function()
			local later = lookVector()
			local current = attackRemote
			if current == nil then
				return
			end
			current:FireServer(later.X, later.Y, later.Z, charged == true)
		end)
		return
	end
	remote:FireServer(look.X, look.Y, look.Z, false)
end

function CombatHud.dodge()
	local remote = dodgeRemote
	if remote == nil then
		return
	end
	remote:FireServer()
end

function CombatHud.setFeel(tier: string, shake: boolean)
	allowShake = shake ~= false and tier ~= "low"
end

-- Same bound as the client's other remote lookups. A missing Attack,
-- Dodge, or CombatFx used to yield start forever and skip the rest of
-- the client script. Leave the combat remotes unset and return.
local REMOTE_WAIT_SECONDS = 15

function CombatHud.start(remotes: Instance, callbacks: Callbacks)
	local attack = remotes:WaitForChild("Attack", REMOTE_WAIT_SECONDS)
	if attack == nil or not attack:IsA("RemoteEvent") then
		warn("[Shardfall] Attack remote is not available")
		return
	end
	local dodge = remotes:WaitForChild("Dodge", REMOTE_WAIT_SECONDS)
	if dodge == nil or not dodge:IsA("RemoteEvent") then
		warn("[Shardfall] Dodge remote is not available")
		return
	end
	local fx = remotes:WaitForChild("CombatFx", REMOTE_WAIT_SECONDS)
	if fx == nil or not fx:IsA("RemoteEvent") then
		warn("[Shardfall] CombatFx remote is not available")
		return
	end
	attackRemote = attack
	dodgeRemote = dodge

	local screen = Instance.new("ScreenGui")
	screen.Name = "ShardfallCombat"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 8
	screen.Parent = player:WaitForChild("PlayerGui")
	MobileShell.mount(screen)

	local hpFrame = Instance.new("Frame")
	hpFrame.Name = "Health"
	hpFrame.AnchorPoint = Vector2.new(0, 0)
	hpFrame.Position = UDim2.fromOffset(16, 16)
	hpFrame.Size = UDim2.fromOffset(220, 36)
	hpFrame.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	hpFrame.BorderSizePixel = 0
	hpFrame.Visible = false
	hpFrame.Parent = screen
	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 8)
	hpCorner.Parent = hpFrame

	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromOffset(10, 2)
	hpText.Size = UDim2.new(1, -20, 0, 16)
	hpText.Font = Enum.Font.BuilderSansBold
	hpText.TextSize = 14
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.TextColor3 = Color3.fromRGB(240, 236, 248)
	hpText.Text = "HP"
	hpText.Parent = hpFrame

	local wallet = Instance.new("TextLabel")
	wallet.Name = "Wallet"
	wallet.BackgroundTransparency = 1
	wallet.Position = UDim2.fromOffset(16, 54)
	wallet.Size = UDim2.fromOffset(220, 16)
	wallet.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	wallet.BackgroundTransparency = 0
	wallet.Font = Enum.Font.BuilderSans
	wallet.TextSize = 14
	wallet.TextXAlignment = Enum.TextXAlignment.Left
	wallet.TextColor3 = Color3.fromRGB(255, 220, 150)
	wallet.TextTruncate = Enum.TextTruncate.AtEnd
	wallet.Text = ""
	wallet.Visible = false
	wallet.Parent = screen
	local walletStroke = Instance.new("UIStroke")
	walletStroke.Thickness = 1
	walletStroke.Color = Color3.fromRGB(16, 14, 24)
	walletStroke.Parent = wallet
	walletLabel = wallet
	if pendingWallet ~= nil then
		paintWallet(pendingWallet[1], pendingWallet[2], pendingWallet[3])
		pendingWallet = nil
	end

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
	hpFill.Size = UDim2.fromScale(0, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(110, 210, 140)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = hpFill

	local comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "Combo"
	comboLabel.BackgroundTransparency = 1
	comboLabel.Position = UDim2.fromOffset(16, 56)
	comboLabel.Size = UDim2.fromOffset(220, 24)
	comboLabel.Font = Enum.Font.BuilderSansBold
	comboLabel.TextSize = 16
	comboLabel.TextXAlignment = Enum.TextXAlignment.Left
	comboLabel.TextColor3 = Color3.fromRGB(255, 214, 120)
	comboLabel.Text = ""
	comboLabel.Parent = screen

	local cueLabel = Instance.new("TextLabel")
	cueLabel.Name = "Telegraph"
	cueLabel.AnchorPoint = Vector2.new(0, 0)
	cueLabel.Position = UDim2.fromOffset(16, 72)
	cueLabel.Size = UDim2.fromOffset(280, 36)
	cueLabel.BackgroundTransparency = 1
	cueLabel.Text = ""
	cueLabel.Visible = false
	cueLabel.Parent = screen

	local cueEdge = Instance.new("Frame")
	cueEdge.Name = "CueEdge"
	cueEdge.Size = UDim2.fromScale(1, 1)
	cueEdge.BackgroundTransparency = 1
	cueEdge.BorderSizePixel = 0
	cueEdge.Active = false
	cueEdge.Visible = false
	cueEdge.ZIndex = 2
	cueEdge.Parent = screen
	local cueStroke = Instance.new("UIStroke")
	cueStroke.Name = "Pulse"
	cueStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cueStroke.Thickness = 5
	cueStroke.Color = Color3.fromRGB(220, 64, 56)
	cueStroke.Transparency = 0.35
	cueStroke.Parent = cueEdge

	local combatHint = Instance.new("TextLabel")
	combatHint.Name = "CombatHint"
	combatHint.AnchorPoint = Vector2.new(0, 1)
	combatHint.Position = UDim2.new(0, 16, 1, -120)
	combatHint.Size = UDim2.fromOffset(280, 36)
	combatHint.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	combatHint.BackgroundTransparency = 0.15
	combatHint.BorderSizePixel = 0
	combatHint.Font = Enum.Font.BuilderSansBold
	combatHint.TextSize = 16
	combatHint.TextColor3 = Color3.fromRGB(110, 210, 140)
	combatHint.TextXAlignment = Enum.TextXAlignment.Left
	combatHint.Text = ""
	combatHint.Visible = false
	combatHint.ZIndex = 4
	combatHint.Parent = screen
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 8)
	hintCorner.Parent = combatHint
	local hintPad = Instance.new("UIPadding")
	hintPad.PaddingLeft = UDim.new(0, 10)
	hintPad.PaddingRight = UDim.new(0, 10)
	hintPad.Parent = combatHint

	local flash = Instance.new("Frame")
	flash.Name = "HitFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.Parent = screen

	local function placeChrome()
		local vx, vy = MobileShell.view(screen)
		local combo = ShellLayout.comboRect()
		comboLabel.Position = UDim2.fromOffset(combo.x, combo.y)
		comboLabel.Size = UDim2.fromOffset(combo.w, combo.h)
		local cue = ShellLayout.cueRect(vx, vy)
		cueLabel.Position = UDim2.fromOffset(cue.x, cue.y)
		cueLabel.Size = UDim2.fromOffset(cue.w, cue.h)
		local bar = ShellLayout.actionBar(vx, vy)
		combatHint.Position = UDim2.fromOffset(16, math.max(96, bar.y - 12))
		combatHint.Size = UDim2.fromOffset(math.min(320, math.max(160, vx - 32)), 36)
	end
	placeChrome()
	local chromeCamera = workspace.CurrentCamera
	if chromeCamera ~= nil then
		chromeCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeChrome)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeChrome)

	local shakeUntil = 0
	local flashUntil = 0
	local cuesSeen = 0
	local cueUntil = 0
	local hintToken = 0
	local function showCombatHint(text: string)
		hintToken += 1
		local token = hintToken
		local shown = if type(text) == "string" then text else ""
		combatHint.Text = shown
		combatHint.TextTransparency = 0
		combatHint.BackgroundTransparency = 0.15
		combatHint.Visible = shown ~= ""
		if shown == "" then
			return
		end
		local fade = TweenService:Create(
			combatHint,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6),
			{ TextTransparency = 1, BackgroundTransparency = 1 }
		)
		fade.Completed:Connect(function()
			if token ~= hintToken then
				return
			end
			combatHint.Visible = false
			combatHint.Text = ""
		end)
		fade:Play()
	end
	local hitstopUntil = 0
	local downHold = false
	local latchedHp = 100
	local latchedMax = 100
	local function paintOverhead(hp: number, maxHp: number)
		local character = player.Character
		if character == nil then
			return
		end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp == nil then
			return
		end
		local bar = hrp:FindFirstChild("ShardfallBar")
		if bar == nil then
			return
		end
		-- The shell already shows this player's HP. Other clients still
		-- see the server bar for party members and enemies.
		if bar:IsA("BillboardGui") then
			bar.Enabled = false
		end
		local label = bar:FindFirstChild("Vitals")
		if label == nil then
			label = bar:FindFirstChild("Name")
		end
		if label ~= nil and label:IsA("TextLabel") then
			label.Text = string.format("HP  %d / %d", hp, maxHp)
		end
	end
	local function drawHp()
		local drawn = if downHold then 0 else latchedHp
		hpText.Text = string.format("HP  %d / %d", drawn, latchedMax)
		paintOverhead(drawn, latchedMax)
		local ratio = if latchedMax > 0 then drawn / latchedMax else 0
		hpFill.Size = UDim2.fromScale(ratio, 1)
		hpFill.BackgroundColor3 = if drawn <= 0 or ratio < 0.3
			then Color3.fromRGB(230, 80, 96)
			else Color3.fromRGB(110, 210, 140)
	end
	local function setHp(hp: number, maxHp: number)
		latchedHp, latchedMax = CombatMath.clampVitals(hp, maxHp)
		drawHp()
	end

	local function pullVitals(root: BasePart)
		local hp = root:GetAttribute("ShardfallHp")
		local maxHp = root:GetAttribute("ShardfallMax")
		if type(hp) == "number" and type(maxHp) == "number" then
			setHp(hp, maxHp)
		end
	end

	local function watchCharacter(character: Model)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 8)
			if root == nil or not root:IsA("BasePart") or character.Parent == nil then
				return
			end
			pullVitals(root)
			root:GetAttributeChangedSignal("ShardfallHp"):Connect(function()
				pullVitals(root)
			end)
			root:GetAttributeChangedSignal("ShardfallMax"):Connect(function()
				pullVitals(root)
			end)
			root.ChildAdded:Connect(function(child)
				if child.Name == "ShardfallBar" then
					drawHp()
				end
			end)
			drawHp()
		end)
	end
	if player.Character ~= nil then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

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
	dismiss.Size = UDim2.new(1, 0, 0, 44)
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
		if downHold then
			downHold = false
			drawHp()
		end
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

	local iconPart: Part? = nil
	local iconRing: UIStroke? = nil
	local iconMark: TextLabel? = nil
	local function clearIcon()
		if iconPart ~= nil then
			iconPart:Destroy()
			iconPart = nil
			iconRing = nil
			iconMark = nil
		end
	end
	local function showIcon(icon: string, x: number, y: number, z: number)
		if icon ~= "red" and icon ~= "blue" then
			clearIcon()
			return
		end
		if iconPart == nil or iconPart.Parent == nil then
			local part = Instance.new("Part")
			part.Name = "CodexTelegraph"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part.Parent = workspace
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "CodexIcon"
			billboard.Size = UDim2.fromOffset(48, 48)
			billboard.StudsOffset = Vector3.new(0, 6, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = part
			local disc = Instance.new("Frame")
			disc.Name = "Disc"
			disc.Size = UDim2.fromScale(1, 1)
			disc.BackgroundColor3 = Color3.fromRGB(
				CodexCues.COLOR.iconInk[1],
				CodexCues.COLOR.iconInk[2],
				CodexCues.COLOR.iconInk[3]
			)
			disc.BorderSizePixel = 0
			disc.Parent = billboard
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = disc
			local ring = Instance.new("UIStroke")
			ring.Name = "Ring"
			ring.Thickness = 4
			ring.Parent = disc
			local letter = Instance.new("TextLabel")
			letter.Name = "Mark"
			letter.BackgroundTransparency = 1
			letter.Size = UDim2.fromScale(1, 1)
			letter.Font = Enum.Font.BuilderSansBold
			letter.TextSize = 20
			letter.TextColor3 = Color3.fromRGB(
				CodexCues.COLOR.iconText[1],
				CodexCues.COLOR.iconText[2],
				CodexCues.COLOR.iconText[3]
			)
			letter.Parent = disc
			local letterStroke = Instance.new("UIStroke")
			letterStroke.Thickness = 1
			letterStroke.Color = Color3.fromRGB(16, 14, 24)
			letterStroke.Parent = letter
			iconPart = part
			iconRing = ring
			iconMark = letter
		end
		if iconPart == nil or iconRing == nil or iconMark == nil then
			return
		end
		iconPart.Position = Vector3.new(x, y, z)
		local rgb = if icon == "blue" then CodexCues.COLOR.blue else CodexCues.COLOR.red
		iconRing.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		iconMark.Text = if icon == "blue" then "B" else "R"
	end

	fx.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local codex = CodexCues.accept(payload)
		if codex.ok == true and type(codex.icon) == "string" then
			local x = codex.x
			local y = codex.y
			local z = codex.z
			if type(x) == "number" and type(y) == "number" and type(z) == "number" then
				showIcon(codex.icon, x, y, z)
			end
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
			local numberSize = if payload.crit == true then 30 else 22
			local combo = numberFrom(payload, "combo")
			if combo ~= nil and combo > 1 then
				comboLabel.Text = string.format("%d hit", combo)
			elseif payload.kind == "damage" then
				comboLabel.Text = ""
			end
			local shake = numberFrom(payload, "shake") or 0
			if allowShake and shake > 0 then
				shakeUntil = os.clock() + shake
			end
			local stop = numberFrom(payload, "hitstop") or 0
			if stop > 0 and (payload.heavy == true or payload.weight == "kill") then
				hitstopUntil = os.clock() + stop
			end
			local flashSeconds = numberFrom(payload, "flash") or 0
			if flashSeconds > 0 then
				flashUntil = os.clock() + flashSeconds
				flash.BackgroundColor3 = if payload.crit == true
					then Color3.fromRGB(255, 196, 64)
					else Color3.fromRGB(255, 255, 255)
			end
			if payload.heavy == true then
				text = text .. "!"
			end
			floater(Vector3.new(x, y, z), text, color, numberSize)
			playCue("hit")
		elseif payload.kind == "telegraph" then
			local colorName = if type(payload.color) == "string" then payload.color else "red"
			cueLabel.Text = ""
			cueLabel.Visible = false
			playCue(colorName)
			local lesson = cuesSeen
			cuesSeen += 1
			if CombatFeel.teachCue(lesson) then
				local rgb = CombatFeel.TELEGRAPHS[colorName]
				if rgb ~= nil then
					cueStroke.Color = Color3.fromRGB(rgb.rgb[1], rgb.rgb[2], rgb.rgb[3])
				end
				cueUntil = os.clock()
					+ (numberFrom(payload, "seconds") or CombatFeel.TELEGRAPH_NORMAL)
				cueEdge.Visible = true
			else
				cueEdge.Visible = false
			end
		elseif payload.kind == "dodge" then
			local charges = numberFrom(payload, "charges")
			if charges ~= nil and callbacks.onDodgeCharges ~= nil then
				callbacks.onDodgeCharges(charges)
			end
			-- A failed dodge reports 0 charges and no position. The clip
			-- belongs to a dodge that spent a charge.
			if charges == 0 and numberFrom(payload, "x") == nil then
				return
			end
			playCue(if payload.perfect == true then "perfect" else "dodge")
			if payload.perfect == true then
				local x = numberFrom(payload, "x") or 0
				local y = numberFrom(payload, "y") or 0
				local z = numberFrom(payload, "z") or 0
				floater(Vector3.new(x, y + 3, z), "PERFECT", Color3.fromRGB(255, 236, 140))
			end
		elseif payload.kind == "kill" then
			playCue("kill")
			local x = numberFrom(payload, "x")
			local y = numberFrom(payload, "y")
			local z = numberFrom(payload, "z")
			if x ~= nil and y ~= nil and z ~= nil and payload.shards == true then
				for index = 1, 4 do
					local shard = Instance.new("Part")
					shard.Name = "KillShard"
					shard.Size = Vector3.new(0.4, 0.4, 0.4)
					shard.Anchored = true
					shard.CanCollide = false
					shard.CanQuery = false
					shard.CanTouch = false
					shard.Material = Enum.Material.Neon
					shard.Color = Color3.fromRGB(255, 214, 120)
					shard.CFrame = CFrame.new(x, y, z)
					shard.Parent = workspace
					local born = os.clock()
					local angle = index * 1.57
					local connection: RBXScriptConnection? = nil
					connection = RunService.RenderStepped:Connect(function()
						local age = os.clock() - born
						shard.Position = Vector3.new(x, y, z)
							+ Vector3.new(
								math.cos(angle) * age * 6,
								age * 4,
								math.sin(angle) * age * 6
							)
						if age > 0.45 then
							if connection ~= nil then
								connection:Disconnect()
							end
							shard:Destroy()
						end
					end)
				end
			end
		elseif payload.kind == "hp" then
			local hp = numberFrom(payload, "hp")
			local maxHp = numberFrom(payload, "maxHp")
			if hp ~= nil and maxHp ~= nil then
				setHp(hp, maxHp)
			end
		elseif payload.kind == "run" then
			callbacks.onRun(payload.run)
			if type(payload.text) == "string" and payload.text ~= "" then
				if CombatFeel.hintOnBanner(payload.text) then
					callbacks.onHint(payload.text)
				else
					showCombatHint(payload.text)
				end
			end
		elseif payload.kind == "hint" then
			if type(payload.text) == "string" then
				if CombatFeel.hintOnBanner(payload.text) then
					callbacks.onHint(payload.text)
				else
					showCombatHint(payload.text)
				end
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
			-- Revive publishes max HP (100 + armor, which is where 103 came
			-- from) in the same breath as this card. Hold the bar at 0 until
			-- the card closes so the fill and the text agree.
			downHold = true
			drawHp()
			showCombatHint("")
			cueEdge.Visible = false
			clearIcon()
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
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if cueEdge.Visible then
			if now >= cueUntil then
				cueEdge.Visible = false
			else
				local pulse = 0.25 + 0.75 * math.abs(math.sin(now * 8))
				cueStroke.Transparency = 1 - pulse
			end
		end
		if now < flashUntil then
			flash.BackgroundTransparency = 0.72
		else
			flash.BackgroundTransparency = 1
		end
		local character = player.Character
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid ~= nil then
			if now < hitstopUntil then
				humanoid.CameraOffset = Vector3.new(0.08, 0, 0)
			elseif allowShake and now < shakeUntil then
				humanoid.CameraOffset =
					Vector3.new(math.noise(now * 40) * 0.4, math.noise(now * 28) * 0.25, 0)
			else
				humanoid.CameraOffset = Vector3.zero
			end
		end
	end)

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
		if input.KeyCode.Name == Keybinds.COMBAT.dodge then
			CombatHud.dodge()
			return
		end
		if
			input.KeyCode.Name == Keybinds.COMBAT.heavy
			or input.KeyCode.Name == Keybinds.GAMEPAD.heavy
		then
			if CombatStage.swing(true) then
				CombatHud.swing(true)
			end
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if CombatStage.swing(false) then
				CombatHud.swing(false)
			end
		end
	end)
end

return CombatHud
