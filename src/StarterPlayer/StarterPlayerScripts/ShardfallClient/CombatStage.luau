--!strict

--[[
	Local combat presentation.

	A held sword, a three-hit pose (or a swapped animation id), slash
	sparks, and a camera pull when an enemy or a drop sits in the lens.
	The server still decides the hit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatAnims = require(Shared:WaitForChild("CombatAnims"))
local CombatFeel = require(Shared:WaitForChild("CombatFeel"))

local CombatStage = {}

local tier = "med"
local intensity = 1
local chain = 0
local lastSwing = 0
local weapon: BasePart? = nil
local tracks: { [string]: AnimationTrack } = {}

local function hand(character: Model): BasePart?
	local found = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if found ~= nil and found:IsA("BasePart") then
		return found
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function holdWeapon(character: Model)
	if weapon ~= nil then
		weapon:Destroy()
		weapon = nil
	end
	local limb = hand(character)
	if limb == nil then
		return
	end
	local blade = Instance.new("Part")
	blade.Name = "HeldWeapon"
	blade.Size = Vector3.new(0.25, 0.25, 2.4)
	blade.Color = Color3.fromRGB(232, 220, 196)
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.Massless = true
	blade.CFrame = limb.CFrame * CFrame.new(0, -0.2, -1.2)
	blade.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = blade
	weld.Parent = blade
	weapon = blade
end

local function playClip(character: Model, name: string): boolean
	local id = CombatAnims.id(name)
	if id == "" then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return false
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local cached = tracks[name]
	if cached == nil then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or track == nil then
			return false
		end
		tracks[name] = track
		cached = track
	end
	cached:Play(0.05, 1, 1)
	return true
end

local function slash(character: Model, sparks: number)
	local blade = weapon
	if blade == nil or sparks <= 0 then
		return
	end
	local trail = Instance.new("Part")
	trail.Name = "Slash"
	trail.Anchored = true
	trail.CanCollide = false
	trail.CanQuery = false
	trail.CanTouch = false
	trail.Material = Enum.Material.Neon
	trail.Color = Color3.fromRGB(255, 244, 220)
	trail.Size = Vector3.new(0.15, 0.15, 2.2)
	trail.CFrame = blade.CFrame
	trail.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = sparks
	emitter.Lifetime = NumberRange.new(0.08, 0.16)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.LightEmission = 0.6
	emitter.Parent = trail
	local born = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		if blade.Parent ~= nil then
			trail.CFrame = blade.CFrame * CFrame.Angles(0, age * 8, 0)
		end
		trail.Transparency = math.clamp(age / 0.18, 0, 1)
		if age > 0.18 then
			if connection ~= nil then
				connection:Disconnect()
			end
			trail:Destroy()
		end
	end)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") and blade.Parent ~= nil then
		blade.CFrame = root.CFrame
			* CFrame.new(1.1, 1.2, -1.4)
			* CFrame.Angles(0, math.rad(70), math.rad(80))
		task.delay(0.16, function()
			local limb = hand(character)
			if limb ~= nil and blade.Parent ~= nil then
				blade.CFrame = limb.CFrame * CFrame.new(0, -0.2, -1.2)
			end
		end)
	end
end

local function mark(name: string, seconds: number)
	local player = Players.LocalPlayer
	if player == nil then
		return
	end
	local gui = player:FindFirstChild("PlayerGui")
	local hud = if gui ~= nil then gui:FindFirstChild("ShardfallHud") else nil
	local button = if hud ~= nil then hud:FindFirstChild(name, true) else nil
	if button ~= nil and button:IsA("GuiButton") then
		button:SetAttribute("CooldownTotal", seconds)
		button:SetAttribute("CooldownUntil", os.clock() + seconds)
	end
end

function CombatStage.setBudget(nextTier: string, nextIntensity: number)
	tier = nextTier
	if type(nextIntensity) == "number" then
		intensity = math.clamp(nextIntensity, 0, 1)
	end
end

function CombatStage.bind(character: Model)
	holdWeapon(character)
	tracks = {}
end

function CombatStage.swing()
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character == nil then
		return
	end
	local now = os.clock()
	local step = CombatFeel.advanceCombo(chain, lastSwing, now, false)
	chain = step.chain
	lastSwing = now
	local clip = CombatFeel.attackAnim(step.index)
	if not playClip(character, clip) then
		slash(
			character,
			CombatFeel.vfxBudget(
				tier,
				intensity,
				CombatFeel.juice(if step.heavy then "heavy" else "light")
			)
		)
	else
		slash(character, CombatFeel.vfxBudget(tier, intensity, CombatFeel.juice("light")))
	end
	mark("Attack", 0.35)
end

function CombatStage.dodge()
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character ~= nil then
		playClip(character, "dodge")
	end
	mark("Dodge", CombatFeel.DODGE_RECHARGE)
end

function CombatStage.skill()
	local player = Players.LocalPlayer
	local character = if player ~= nil then player.Character else nil
	if character ~= nil then
		playClip(character, "skill")
	end
	mark("Skill1", 4)
end

function CombatStage.watchCamera()
	RunService.RenderStepped:Connect(function()
		local player = Players.LocalPlayer
		local character = if player ~= nil then player.Character else nil
		local camera = workspace.CurrentCamera
		if character == nil or camera == nil then
			return
		end
		local head = character:FindFirstChild("Head")
		if head == nil or not head:IsA("BasePart") then
			return
		end
		local origin = camera.CFrame.Position
		local aim = head.Position - origin
		if aim.Magnitude < 0.5 then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(origin, aim, params)
		if hit == nil then
			return
		end
		local part = hit.Instance
		local parent = part.Parent
		local blocks = part.Name == "RarityBeam"
			or part:GetAttribute("ShardfallHp") ~= nil
			or part:GetAttribute("Ox") ~= nil
			or (parent ~= nil and parent:GetAttribute("ShardfallHp") ~= nil)
		if not blocks then
			return
		end
		local desired = aim.Magnitude
		local nextDistance = CombatFeel.cameraDistance(hit.Distance, desired)
		if nextDistance < desired - 0.4 then
			local unit = aim.Unit
			camera.CFrame = CFrame.new(head.Position - unit * nextDistance, head.Position)
		end
	end)
end

return CombatStage
