--!strict

--[[
	Server-side swings, shots, and hit points.

	The client only sends which way the camera is looking. This module
	decides if a melee swing reaches an enemy, or spawns the projectile a
	bow or staff fires. Rolled weapon stats supply the damage. Armor supplies
	HP and Defense. 	An equipped pet hits the nearest enemy on its own timer
	using Pet Damage. Auto attack is a server timer: the client only sends
	on or off, and this module picks the nearest enemy in weapon range.
	Nothing here trusts a damage number from the client.

	DungeonService registers the enemies. This file does not build the rooms.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatFeel = require(ReplicatedStorage.Shared.CombatFeel)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Materials = require(ReplicatedStorage.Shared.Materials)
local Quality = require(ReplicatedStorage.Shared.Quality)
local DataService = require(script.Parent.DataService)
local LoopService = require(script.Parent.LoopService)
local OnboardingService = require(script.Parent.OnboardingService)

local CombatService = {}

export type EnemyView = {
	id: string,
	defense: number,
	boss: boolean,
	phase: number,
	weak: boolean,
	armoredMultiplier: number,
	x: number,
	y: number,
	z: number,
}

type Hooks = {
	enemies: (Player) -> { EnemyView },
	onEnemyHit: (Player, string, number, boolean, boolean) -> (),
	onPlayerDown: (Player) -> (),
	inRun: (Player) -> boolean,
	paysProgress: ((Player) -> boolean)?,
}

type State = {
	hp: number,
	maxHp: number,
	defense: number,
	nextAttack: number,
	nextCompanion: number,
	ready: boolean,
	combo: number,
	comboAt: number,
	dodge: CombatFeel.DodgeState,
	ult: number,
	hurt: boolean,
}

type Shot = {
	part: Part,
	x: number,
	y: number,
	z: number,
	dirX: number,
	dirY: number,
	dirZ: number,
	speed: number,
	remaining: number,
	player: Player,
	fromPlayer: boolean,
	damage: number,
	critChance: number,
	critDamage: number,
	lifesteal: number,
	heavy: boolean,
	landed: boolean?,
}

local classMods = function(_player: Player): { taken: number, dealt: number }
	return { taken = 1, dealt = 1 }
end
local onPlayerHit = function(_player: Player) end

local hooks: Hooks = {
	enemies = function(_player)
		return {}
	end,
	onEnemyHit = function(_player, _id, _amount, _crit, _heavy) end,
	onPlayerDown = function(_player) end,
	inRun = function(_player)
		return false
	end,
}

local vitals: { [Player]: State } = {}
local telegraphs: { [Player]: { CombatFeel.Telegraph } } = {}
local autoOn: { [Player]: boolean } = {}
local steerUntil: { [Player]: number } = {}
local shots: { Shot } = {}
local rng = Random.new()
local lastHint: { [Player]: number } = {}

local function fx(player: Player, payload: { [string]: any })
	if player.Parent == nil then
		return
	end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		return
	end
	local remote = remotes:FindFirstChild("CombatFx")
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote:FireClient(player, payload)
	end
end

local function hint(player: Player, text: string)
	local now = os.clock()
	if (lastHint[player] or 0) + 1.2 > now then
		return
	end
	lastHint[player] = now
	fx(player, { kind = "hint", text = text })
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp ~= nil and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function ensure(player: Player): State
	local state = vitals[player]
	if state == nil then
		state = {
			hp = CombatMath.BASE_HEALTH,
			maxHp = CombatMath.BASE_HEALTH,
			defense = 0,
			nextAttack = 0,
			nextCompanion = 0,
			ready = false,
			combo = 0,
			comboAt = 0,
			dodge = CombatFeel.blankDodge(os.clock()),
			ult = 0,
			hurt = false,
		}
		vitals[player] = state
	end
	return state
end

-- The body stays full so a fall cannot zero it. MaxHealth matches the combat
-- bar (the place default is 500, which is what the overhead used to read
-- while the HUD still said 100).
local function syncBody(player: Player, maxHp: number)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local maxHealth = math.max(1, maxHp)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if humanoid.MaxHealth ~= maxHealth then
		humanoid.MaxHealth = maxHealth
	end
	if humanoid.Health ~= humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function paint(part: BasePart, hp: number, maxHp: number)
	part:SetAttribute("ShardfallHp", hp)
	part:SetAttribute("ShardfallMax", maxHp)
	local fill = part:FindFirstChild("Fill", true)
	if fill ~= nil and fill:IsA("Frame") then
		local ratio = 0
		if maxHp > 0 then
			ratio = math.clamp(hp / maxHp, 0, 1)
		end
		fill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function ensureBar(part: BasePart, studs: number, color: Color3): TextLabel
	local existing = part:FindFirstChild("ShardfallBar")
	local gui: BillboardGui
	if existing ~= nil and existing:IsA("BillboardGui") then
		gui = existing
	else
		local created = Instance.new("BillboardGui")
		created.Name = "ShardfallBar"
		created.Size = UDim2.fromOffset(92, 22)
		created.StudsOffset = Vector3.new(0, studs, 0)
		created.AlwaysOnTop = true
		created.Parent = part
		gui = created
	end

	if gui:FindFirstChild("Back") == nil then
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Position = UDim2.fromOffset(0, 14)
		back.Size = UDim2.new(1, 0, 0, 8)
		back.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
		back.BorderSizePixel = 0
		back.Parent = gui

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0
		fill.Parent = back
	end

	local label = gui:FindFirstChild("Vitals")
	if label ~= nil and label:IsA("TextLabel") then
		return label
	end
	local legacy = gui:FindFirstChild("Name")
	if legacy ~= nil and legacy:IsA("TextLabel") then
		legacy.Name = "Vitals"
		return legacy
	end

	local name = Instance.new("TextLabel")
	name.Name = "Vitals"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 12)
	name.Font = Enum.Font.BuilderSansBold
	name.TextSize = 12
	name.TextColor3 = Color3.fromRGB(240, 236, 248)
	name.TextStrokeTransparency = 0.4
	name.Text = ""
	name.Parent = gui
	return name
end

local function publish(player: Player, state: State)
	local hp, maxHp = CombatMath.clampVitals(state.hp, state.maxHp)
	state.hp = hp
	state.maxHp = maxHp
	local hrp = rootPart(player)
	if hrp ~= nil then
		paint(hrp, hp, maxHp)
		local nameLabel = ensureBar(hrp, 3.2, Color3.fromRGB(110, 210, 140))
		nameLabel.Text = string.format("HP  %d / %d", hp, maxHp)
	end
	syncBody(player, maxHp)
	fx(player, {
		kind = "hp",
		hp = hp,
		maxHp = maxHp,
	})
end

local function attachCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		local waited = character:WaitForChild("Humanoid", 5)
		if waited ~= nil and waited:IsA("Humanoid") then
			humanoid = waited
		end
	end
	if humanoid ~= nil then
		-- Combat HP lives on the session, not on the Humanoid. Fall damage
		-- and a stale Health script used to zero the body while the bar
		-- still read 50/100. The body stays full so only damagePlayer can
		-- down the player. MaxHealth follows the combat max so the overhead
		-- does not stay on the place default of 500.
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end)
		local pinning = false
		local function pin()
			if pinning or humanoid.Parent == nil then
				return
			end
			pinning = true
			humanoid.Health = humanoid.MaxHealth
			pinning = false
		end
		humanoid.HealthChanged:Connect(pin)
		syncBody(player, ensure(player).maxHp)
		pin()
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp ~= nil and hrp:IsA("BasePart") then
		hrp:SetAttribute("ShardfallName", player.DisplayName)
		ensureBar(hrp, 3.2, Color3.fromRGB(110, 210, 140))
		publish(player, ensure(player))
	end
end

function CombatService.bindClassMods(fn: (Player) -> { taken: number, dealt: number })
	classMods = fn
end

function CombatService.bindPlayerHit(fn: (Player) -> ())
	onPlayerHit = fn
end

function CombatService.bindHooks(nextHooks: Hooks)
	hooks = nextHooks
end

function CombatService.refresh(player: Player)
	local state = ensure(player)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local _, vitality = CombatMath.loadout(profile)
	local previousMax = state.maxHp
	state.defense = vitality.defense
	state.maxHp = vitality.maxHealth
	if state.ready and state.hp <= 0 then
		-- A profile save on the killing blow used to add the new max onto
		-- 0 (or onto a full bar: 100 + 3 = 103) and the label jumped.
		state.hp = 0
		publish(player, state)
		return
	end
	state.hp = CombatMath.syncVitals(state.hp, previousMax, state.maxHp, state.hurt)
	state.ready = true
	if state.hp >= state.maxHp then
		state.hurt = false
	end
	publish(player, state)
end

function CombatService.revive(player: Player)
	local state = ensure(player)
	state.hp = state.maxHp
	state.ready = true
	state.hurt = false
	publish(player, state)
end

function CombatService.vitals(player: Player): (number, number)
	local state = ensure(player)
	return state.hp, state.maxHp
end

local function heal(player: Player, amount: number, x: number, y: number, z: number)
	if amount <= 0 then
		return
	end
	local state = ensure(player)
	if state.hp <= 0 then
		return
	end
	local before = state.hp
	state.hp = math.min(state.maxHp, state.hp + amount)
	local gained = state.hp - before
	if gained <= 0 then
		return
	end
	if state.hp >= state.maxHp then
		state.hurt = false
	end
	publish(player, state)
	fx(player, {
		kind = "heal",
		amount = gained,
		x = x,
		y = y,
		z = z,
	})
end

-- Returns true when this hit dropped the player. The dungeon ends the run.
function CombatService.noteTelegraph(player: Player, endsAt: number)
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return
	end
	local now = os.clock()
	local list = CombatFeel.pruneTelegraphs(telegraphs[player] or {}, now)
	table.insert(list, CombatFeel.openTelegraph(endsAt))
	telegraphs[player] = list
end

local function awardedRecently(player: Player, now: number): boolean
	local list = telegraphs[player]
	if list == nil then
		return false
	end
	for _, window in ipairs(list) do
		if window.awarded == true and now <= window.endsAt + CombatFeel.DODGE_LATENCY then
			return true
		end
	end
	return false
end

local function grantsProgress(player: Player): boolean
	if hooks.paysProgress == nil then
		return true
	end
	return hooks.paysProgress(player)
end

function CombatService.damagePlayer(
	player: Player,
	rawDamage: number,
	x: number,
	y: number,
	z: number
): boolean
	local state = ensure(player)
	if state.hp <= 0 then
		return true
	end
	local now = os.clock()
	if CombatFeel.iframe(state.dodge, now) then
		-- Ult was already decided when the dodge arrived. A hit during
		-- i-frames does not score a second perfect off a client time.
		local perfect = awardedRecently(player, now)
		fx(player, {
			kind = "dodge",
			perfect = perfect,
			charges = state.dodge.charges,
			ult = state.ult,
			x = x,
			y = y,
			z = z,
		})
		return false
	end
	local mods = classMods(player)
	local before = state.hp
	local nextHp, amount, down =
		CombatMath.applyPlayerDamage(state.hp, state.maxHp, rawDamage, state.defense, mods.taken)
	state.hp = nextHp
	if nextHp < before then
		state.hurt = true
	end
	publish(player, state)
	fx(player, {
		kind = "damage",
		amount = amount,
		crit = false,
		x = x,
		y = y + 2,
		z = z,
	})
	if down then
		-- Defer so a killing blow cannot destroy the shot list mid-loop.
		task.defer(hooks.onPlayerDown, player)
	else
		onPlayerHit(player)
	end
	return down
end

local function feelTier(player: Player): (string, boolean)
	local profile = DataService.get(player)
	local tier = "med"
	local shake = true
	if profile ~= nil then
		tier = Quality.normalize(profile.graphicsQuality) or "med"
		shake = profile.shake ~= false
	end
	return tier, shake
end

local function strikeEnemy(
	player: Player,
	enemy: EnemyView,
	damage: number,
	critChance: number,
	critDamage: number,
	lifesteal: number,
	heavy: boolean
)
	local mods = classMods(player)
	local hit = CombatMath.resolveHit(
		damage * mods.dealt,
		critChance,
		critDamage,
		enemy.defense,
		rng:NextNumber(),
		lifesteal
	)
	local amount = hit.amount
	if enemy.boss then
		amount = CombatMath.bossTaken(amount, enemy.phase, enemy.weak, enemy.armoredMultiplier)
		if lifesteal > 0 then
			hit.healed = math.floor(amount * lifesteal + 0.5)
		end
	end
	local kind = CombatFeel.weight(hit.crit, heavy, false)
	local juice = CombatFeel.juice(kind)
	local tier, shakeOn = feelTier(player)
	local state = ensure(player)
	fx(player, {
		kind = "damage",
		amount = amount,
		crit = hit.crit,
		heavy = heavy,
		weight = kind,
		hitstop = juice.hitstop,
		flash = juice.flash,
		shake = CombatFeel.shakeAllowed(tier, shakeOn, juice),
		particles = CombatFeel.particlesFor(tier, juice),
		combo = state.combo,
		x = enemy.x,
		y = enemy.y + 2,
		z = enemy.z,
	})
	hooks.onEnemyHit(player, enemy.id, amount, hit.crit, heavy)
	if hit.healed > 0 then
		local hrp = rootPart(player)
		local x, y, z = enemy.x, enemy.y, enemy.z
		if hrp ~= nil then
			x, y, z = hrp.Position.X, hrp.Position.Y, hrp.Position.Z
		end
		heal(player, hit.healed, x, y, z)
	end
end

local function launch(shot: Shot, color: Color3)
	local part = Instance.new("Part")
	part.Name = "ShardfallShot"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.8, 0.8, 0.8)
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(shot.x, shot.y, shot.z)
	part.Parent = workspace
	shot.part = part
	table.insert(shots, shot)
end

local function direction(x: any, y: any, z: any, fallback: Vector3): Vector3
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
		return fallback
	end
	if x ~= x or y ~= y or z ~= z then
		return fallback
	end
	local vector = Vector3.new(x, y, z)
	if vector.Magnitude < 0.05 or vector.Magnitude > 3 then
		return fallback
	end
	return vector.Unit
end

local function swingFlash(origin: Vector3, look: Vector3, reach: number, crit: boolean)
	if look.Magnitude < 0.05 then
		return
	end
	local flash = Instance.new("Part")
	flash.Name = "ShardfallSwing"
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = if crit then Color3.fromRGB(255, 196, 64) else Color3.fromRGB(236, 232, 220)
	flash.Size = Vector3.new(0.35, 0.35, math.clamp(reach, 2, 14))
	flash.CFrame = CFrame.lookAt(origin, origin + look) * CFrame.new(0, 0, -flash.Size.Z / 2)
	flash.Parent = workspace
	Debris:AddItem(flash, 0.12)
end

-- One pet swing when the timer is ready and an enemy is within PET_RANGE.
-- No model: the floating damage number is the hit. Chain Lightning is not
-- fired from here.
function CombatService.companionTick(player: Player)
	if not hooks.inRun(player) then
		return
	end
	local hrp = rootPart(player)
	if hrp == nil then
		return
	end
	local offense = CombatMath.petFromProfile(DataService.get(player))
	if offense == nil then
		return
	end
	local state = ensure(player)
	local now = os.clock()
	if now < (state.nextCompanion or 0) then
		return
	end
	local closest: EnemyView? = nil
	local closestDistance = math.huge
	for _, enemy in ipairs(hooks.enemies(player)) do
		local distance = CombatMath.planarDistance(hrp.Position.X, hrp.Position.Z, enemy.x, enemy.z)
		if distance <= offense.range and distance < closestDistance then
			closest = enemy
			closestDistance = distance
		end
	end
	if closest == nil then
		return
	end
	state.nextCompanion = now + CombatMath.cooldown(offense.attackSpeed)
	strikeEnemy(
		player,
		closest,
		offense.damage,
		offense.critChance,
		offense.critDamage,
		offense.lifesteal,
		false
	)
end

function CombatService.autoEnabled(player: Player): boolean
	local flag = autoOn[player]
	if flag == nil then
		return true
	end
	return flag
end

function CombatService.setAutoAttack(player: Player, enabled: boolean)
	autoOn[player] = enabled
end

-- True while the client reports movement keys or a thumbstick. Expires so a
-- dropped "released" message cannot pin the character in place.
function CombatService.setSteering(player: Player, moving: boolean)
	if moving then
		steerUntil[player] = os.clock() + 0.8
	else
		steerUntil[player] = 0
	end
end

function CombatService.isSteering(player: Player): boolean
	return os.clock() < (steerUntil[player] or 0)
end

local function releaseSwing(
	player: Player,
	hrp: BasePart,
	offense: CombatMath.Offense,
	aim: Vector3,
	flat: Vector3,
	charged: boolean
)
	local state = ensure(player)
	local now = os.clock()
	if now < state.nextAttack then
		return
	end
	if now < state.dodge.iframeUntil then
		-- A dodge cancels the end of a swing. The next hit waits out the roll.
		return
	end
	local step = CombatFeel.advanceCombo(state.combo, state.comboAt, now, charged)
	state.combo = step.chain
	state.comboAt = now
	state.nextAttack = now + CombatMath.cooldown(offense.attackSpeed)
	local damage = offense.damage * step.multiplier

	if offense.style == "projectile" then
		local start = hrp.Position + aim * 3
		launch(
			{
				part = nil :: any,
				x = start.X,
				y = start.Y,
				z = start.Z,
				dirX = aim.X,
				dirY = aim.Y,
				dirZ = aim.Z,
				speed = offense.projectileSpeed,
				remaining = offense.range,
				player = player,
				fromPlayer = true,
				damage = damage,
				critChance = offense.critChance,
				critDamage = offense.critDamage,
				lifesteal = offense.lifesteal,
				heavy = step.heavy,
			},
			if offense.weaponType == "staff"
				then Color3.fromRGB(120, 220, 140)
				else Color3.fromRGB(230, 210, 140)
		)
		return
	end

	swingFlash(hrp.Position, flat, offense.range, step.heavy)
	local closest: EnemyView? = nil
	local closestDistance = math.huge
	for _, enemy in ipairs(hooks.enemies(player)) do
		if
			CombatMath.hitsMelee(
				hrp.Position.X,
				hrp.Position.Z,
				flat.X,
				flat.Z,
				enemy.x,
				enemy.z,
				offense.range,
				offense.minDot
			)
		then
			local distance =
				CombatMath.planarDistance(hrp.Position.X, hrp.Position.Z, enemy.x, enemy.z)
			if distance < closestDistance then
				closest = enemy
				closestDistance = distance
			end
		end
	end
	if closest ~= nil then
		strikeEnemy(
			player,
			closest,
			damage,
			offense.critChance,
			offense.critDamage,
			offense.lifesteal,
			step.heavy
		)
	end
end

function CombatService.attack(player: Player, lookX: any, lookY: any, lookZ: any, charged: any)
	-- Haven has nothing to swing at. The old tip sat on the gold banner
	-- from the moment the player spawned.
	if not hooks.inRun(player) then
		return
	end
	local hrp = rootPart(player)
	if hrp == nil then
		return
	end
	local offense = CombatMath.loadout(DataService.get(player))
	local facing = hrp.CFrame.LookVector
	local aim = direction(lookX, lookY, lookZ, facing)
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(facing.X, 0, facing.Z)
	end
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	releaseSwing(player, hrp, offense, aim, flat.Unit, charged == true)
	OnboardingService.note(player, "swing")
end

function CombatService.dodge(player: Player)
	if not hooks.inRun(player) then
		return
	end
	local state = ensure(player)
	local now = os.clock()
	OnboardingService.note(player, "dodge")
	if not CombatFeel.tryDodge(state.dodge, now) then
		fx(player, { kind = "dodge", perfect = false, charges = 0, ult = state.ult })
		return
	end
	-- The remote may still carry an old client clock. It is not an argument.
	local perfect = CombatFeel.scoreAny(telegraphs[player], now, nil)
	if perfect then
		CombatFeel.notePerfect(state.dodge, now)
		state.ult = math.min(100, state.ult + CombatFeel.PERFECT_ULT)
	end
	if grantsProgress(player) then
		LoopService.progress(player, "dodge", 1)
	end
	local hrp = rootPart(player)
	fx(player, {
		kind = "dodge",
		perfect = perfect,
		charges = state.dodge.charges,
		ult = state.ult,
		x = if hrp ~= nil then hrp.Position.X else 0,
		y = if hrp ~= nil then hrp.Position.Y else 0,
		z = if hrp ~= nil then hrp.Position.Z else 0,
	})
end

function CombatService.ultCharge(player: Player): number
	return ensure(player).ult
end

function CombatService.addUlt(player: Player, amount: number)
	local state = ensure(player)
	state.ult = math.min(100, state.ult + amount)
end

function CombatService.spendUlt(player: Player)
	ensure(player).ult = 0
end

function CombatService.healAmount(player: Player, amount: number)
	local hrp = rootPart(player)
	local x, y, z = 0, 0, 0
	if hrp ~= nil then
		x, y, z = hrp.Position.X, hrp.Position.Y, hrp.Position.Z
	end
	heal(player, amount, x, y, z)
end

function CombatService.strike(player: Player, enemy: EnemyView, damage: number, heavy: boolean)
	strikeEnemy(player, enemy, damage, 0.05, 1.5, 0, heavy)
end

-- Nearest enemy inside the equipped weapon's range. Melee still uses that
-- weapon's arc, aimed at the target. Projectiles fly at the target.
function CombatService.autoTick(player: Player)
	if not CombatService.autoEnabled(player) or not hooks.inRun(player) then
		return
	end
	local hrp = rootPart(player)
	if hrp == nil then
		return
	end
	local state = ensure(player)
	if os.clock() < state.nextAttack then
		return
	end
	local enemies = hooks.enemies(player)
	if #enemies == 0 then
		return
	end
	local offense = CombatMath.loadout(DataService.get(player))
	local enemy = CombatMath.nearestInRange(hrp.Position.X, hrp.Position.Z, enemies, offense.range)
	if enemy == nil then
		hint(player, "No target in range.")
		return
	end
	local ax, ay, az =
		CombatMath.aimAt(hrp.Position.X, hrp.Position.Y, hrp.Position.Z, enemy.x, enemy.y, enemy.z)
	local aim = Vector3.new(ax, ay, az)
	local flat = Vector3.new(ax, 0, az)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	releaseSwing(player, hrp, offense, aim, flat.Unit, false)
end

function CombatService.launchEnemyShot(
	player: Player,
	origin: Vector3,
	target: Vector3,
	damage: number,
	speed: number,
	range: number
)
	local delta = target - origin
	if delta.Magnitude < 0.2 then
		return
	end
	local aim = delta.Unit
	local start = origin + aim * 1.5
	launch({
		part = nil :: any,
		x = start.X,
		y = start.Y,
		z = start.Z,
		dirX = aim.X,
		dirY = aim.Y,
		dirZ = aim.Z,
		speed = speed,
		remaining = range,
		player = player,
		fromPlayer = false,
		damage = damage,
		critChance = 0,
		critDamage = 1,
		lifesteal = 0,
		heavy = false,
	}, Color3.fromRGB(186, 120, 255))
end

function CombatService.clearShots(player: Player)
	for index = #shots, 1, -1 do
		local shot = shots[index]
		if shot.player == player then
			if shot.part ~= nil then
				shot.part:Destroy()
			end
			table.remove(shots, index)
		end
	end
end

function CombatService.useTonic(player: Player)
	local state = ensure(player)
	if state.hp >= state.maxHp then
		return { ok = false, error = "Already at full health." }
	end
	local spent = false
	local ok, err = DataService.mutate(player, function(data)
		local owned = data.consumables[Materials.TONIC_ID] or 0
		if owned < 1 then
			return "You have no Healing Tonic."
		end
		data.consumables[Materials.TONIC_ID] = owned - 1
		spent = true
		return nil
	end)
	if not ok or not spent then
		return { ok = false, error = err or "Could not drink that." }
	end
	local healed = CombatMath.tonicHeal(state.hp, state.maxHp, Materials.TONIC_HEAL)
	local hrp = rootPart(player)
	local x, y, z = 0, 4, 0
	if hrp ~= nil then
		x, y, z = hrp.Position.X, hrp.Position.Y, hrp.Position.Z
	end
	heal(player, healed, x, y, z)
	return { ok = true, healed = healed }
end

local function stepShots(dt: number)
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local x, y, z, remaining = CombatMath.stepProjectile(
			shot.x,
			shot.y,
			shot.z,
			shot.dirX,
			shot.dirY,
			shot.dirZ,
			shot.speed,
			dt,
			shot.remaining
		)
		shot.x, shot.y, shot.z, shot.remaining = x, y, z, remaining
		if shot.part ~= nil then
			shot.part.CFrame = CFrame.new(x, y, z)
		end

		local hit = false
		if shot.player.Parent == nil then
			hit = true
		elseif shot.fromPlayer then
			local closest: EnemyView? = nil
			local closestDistance = math.huge
			for _, enemy in ipairs(hooks.enemies(shot.player)) do
				if
					CombatMath.within(
						x,
						y,
						z,
						enemy.x,
						enemy.y,
						enemy.z,
						CombatMath.PROJECTILE_RADIUS + 1.5
					)
				then
					local distance = CombatMath.planarDistance(x, z, enemy.x, enemy.z)
					if distance < closestDistance then
						closest = enemy
						closestDistance = distance
					end
				end
			end
			if closest ~= nil then
				strikeEnemy(
					shot.player,
					closest,
					shot.damage,
					shot.critChance,
					shot.critDamage,
					shot.lifesteal,
					shot.heavy
				)
				hit = true
			end
		else
			if shot.landed ~= true then
				local hrp = rootPart(shot.player)
				if
					hrp ~= nil
					and CombatMath.within(
						x,
						y,
						z,
						hrp.Position.X,
						hrp.Position.Y,
						hrp.Position.Z,
						3
					)
				then
					-- Mark it before the hit so a hook that steps shots again
					-- cannot apply this orb a second time.
					shot.landed = true
					CombatService.damagePlayer(
						shot.player,
						shot.damage,
						hrp.Position.X,
						hrp.Position.Y,
						hrp.Position.Z
					)
				end
			end
			if shot.landed == true then
				hit = true
			end
		end

		if hit or remaining <= 0 then
			if shot.part ~= nil then
				shot.part:Destroy()
			end
			table.remove(shots, index)
		end
	end
end

function CombatService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(function()
				if player.Parent == nil then
					return
				end
				attachCharacter(player, character)
			end)
		end)
		if player.Character ~= nil then
			task.defer(function()
				local character = player.Character
				if character ~= nil then
					attachCharacter(player, character)
				end
			end)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		vitals[player] = nil
		telegraphs[player] = nil
		autoOn[player] = nil
		steerUntil[player] = nil
		lastHint[player] = nil
		CombatService.clearShots(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepShots(math.min(dt, 0.1))
	end)
end

return CombatService
