--!strict

--[[
	Server-side swings, shots, and hit points.

	The client only sends which way the camera is looking. This module
	decides if a melee swing reaches an enemy, or spawns the projectile a
	bow or staff fires. Rolled weapon stats supply the damage. Armor supplies
	HP and Defense. An equipped pet hits the nearest enemy on its own timer
	using Pet Damage. Nothing here trusts a damage number from the client.

	DungeonService registers the enemies. This file does not build the rooms.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Materials = require(ReplicatedStorage.Shared.Materials)
local DataService = require(script.Parent.DataService)

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
	onEnemyHit: (Player, string, number, boolean) -> (),
	onPlayerDown: (Player) -> (),
	inRun: (Player) -> boolean,
}

type State = {
	hp: number,
	maxHp: number,
	defense: number,
	nextAttack: number,
	nextCompanion: number,
	ready: boolean,
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
}

local hooks: Hooks = {
	enemies = function(_player)
		return {}
	end,
	onEnemyHit = function(_player, _id, _amount, _crit) end,
	onPlayerDown = function(_player) end,
	inRun = function(_player)
		return false
	end,
}

local vitals: { [Player]: State } = {}
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
		}
		vitals[player] = state
	end
	return state
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

local function publish(player: Player, state: State)
	local hrp = rootPart(player)
	if hrp ~= nil then
		paint(hrp, state.hp, state.maxHp)
		local nameLabel = hrp:FindFirstChild("Name", true)
		if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
			nameLabel.Text =
				string.format("%d / %d", math.max(0, math.floor(state.hp)), state.maxHp)
		end
	end
	fx(player, {
		kind = "hp",
		hp = math.max(0, state.hp),
		maxHp = state.maxHp,
	})
end

local function ensureBar(part: BasePart, studs: number, color: Color3)
	if part:FindFirstChild("ShardfallBar") ~= nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShardfallBar"
	gui.Size = UDim2.fromOffset(92, 22)
	gui.StudsOffset = Vector3.new(0, studs, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 12)
	name.Font = Enum.Font.BuilderSansBold
	name.TextSize = 12
	name.TextColor3 = Color3.fromRGB(240, 236, 248)
	name.TextStrokeTransparency = 0.4
	name.Text = part:GetAttribute("ShardfallName") or ""
	name.Parent = gui

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

local function attachCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp ~= nil and hrp:IsA("BasePart") then
		hrp:SetAttribute("ShardfallName", player.DisplayName)
		ensureBar(hrp, 3.2, Color3.fromRGB(110, 210, 140))
		publish(player, ensure(player))
	end
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
	if not state.ready then
		state.hp = state.maxHp
		state.ready = true
	else
		if state.maxHp > previousMax then
			state.hp += state.maxHp - previousMax
		end
		if state.hp > state.maxHp then
			state.hp = state.maxHp
		end
	end
	publish(player, state)
end

function CombatService.revive(player: Player)
	local state = ensure(player)
	state.hp = state.maxHp
	state.ready = true
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
	local before = state.hp
	state.hp = math.min(state.maxHp, state.hp + amount)
	local gained = state.hp - before
	if gained <= 0 then
		return
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
	local hit = CombatMath.resolveHit(rawDamage, 0, 1, state.defense, 1, 0)
	state.hp -= hit.amount
	local down = state.hp <= 0
	if down then
		state.hp = 0
	end
	publish(player, state)
	fx(player, {
		kind = "damage",
		amount = hit.amount,
		crit = false,
		x = x,
		y = y + 2,
		z = z,
	})
	if down then
		-- Defer so a killing blow cannot destroy the shot list mid-loop.
		task.defer(hooks.onPlayerDown, player)
	end
	return down
end

local function strikeEnemy(
	player: Player,
	enemy: EnemyView,
	damage: number,
	critChance: number,
	critDamage: number,
	lifesteal: number
)
	local hit = CombatMath.resolveHit(
		damage,
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
	fx(player, {
		kind = "damage",
		amount = amount,
		crit = hit.crit,
		x = enemy.x,
		y = enemy.y + 2,
		z = enemy.z,
	})
	hooks.onEnemyHit(player, enemy.id, amount, hit.crit)
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
		offense.lifesteal
	)
end

function CombatService.attack(player: Player, lookX: any, lookY: any, lookZ: any)
	if not hooks.inRun(player) then
		hint(player, "Enter the Rootvault first. Click swings. Bows and staffs fire a shot.")
		return
	end
	local hrp = rootPart(player)
	if hrp == nil then
		return
	end
	local state = ensure(player)
	local now = os.clock()
	if now < state.nextAttack then
		return
	end
	local profile = DataService.get(player)
	local offense = CombatMath.loadout(profile)
	state.nextAttack = now + CombatMath.cooldown(offense.attackSpeed)

	local facing = hrp.CFrame.LookVector
	local aim = direction(lookX, lookY, lookZ, facing)
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(facing.X, 0, facing.Z)
	end
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end

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
				damage = offense.damage,
				critChance = offense.critChance,
				critDamage = offense.critDamage,
				lifesteal = offense.lifesteal,
			},
			if offense.weaponType == "staff"
				then Color3.fromRGB(120, 220, 140)
				else Color3.fromRGB(230, 210, 140)
		)
		return
	end

	swingFlash(hrp.Position, flat.Unit, offense.range, false)
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
			offense.damage,
			offense.critChance,
			offense.critDamage,
			offense.lifesteal
		)
	end
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
					shot.lifesteal
				)
				hit = true
			end
		else
			local hrp = rootPart(shot.player)
			if
				hrp ~= nil
				and CombatMath.within(x, y, z, hrp.Position.X, hrp.Position.Y, hrp.Position.Z, 3)
			then
				CombatService.damagePlayer(
					shot.player,
					shot.damage,
					hrp.Position.X,
					hrp.Position.Y,
					hrp.Position.Z
				)
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
		lastHint[player] = nil
		CombatService.clearShots(player)
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepShots(math.min(dt, 0.1))
	end)
end

return CombatService
