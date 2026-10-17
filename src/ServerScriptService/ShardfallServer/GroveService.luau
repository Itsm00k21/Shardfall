--!strict

--[[
	Plaza Training Grove.

	The dummy prompt is the only input. This service builds the hit, the
	red dodge, the telegraph color, and the clear on the server. The client
	does not call clear and does not send state, a user id, or a guild id.

	Damage comes from the equipped loadout. Gold and Shard Keys stay put.
	The ribbon is a bound collectible, and only when clear says granted.
	It is not equipped. A full bag keeps the station progress and retries
	the grant. Store the grove record only when the call is ok.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local Haven = require(ReplicatedStorage.Shared.Haven)
local Schema = require(ReplicatedStorage.Shared.Schema)
local TrainingGrove = require(ReplicatedStorage.Shared.TrainingGrove)

local GroveService = {}

local STAND_STUDS = 12
local SWING_GAP = 0.4

local readyAt: { [Player]: number } = {}
local startedAt: { [Player]: number } = {}

local ERRORS = TrainingGrove.ERRORS

local ID_FIELDS = { "userId", "UserId", "playerId", "PlayerId", "guildId", "GuildId" }
local PAID_FIELDS = { "productId", "robux", "cost", "skip", "paid" }
local CLOSED_FIELDS = { "state", "color", "clear", "gold", "keys", "action", "granted", "cosmetic", "cosmeticId" }

local function finiteAmount(value: any): boolean
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function requestError(request: any): string?
	if type(request) ~= "table" then
		return ERRORS.hit
	end
	for _, key in ipairs(ID_FIELDS) do
		if request[key] ~= nil then
			return ERRORS.id
		end
	end
	for _, key in ipairs(PAID_FIELDS) do
		if request[key] ~= nil then
			return ERRORS.paid
		end
	end
	for _, key in ipairs(CLOSED_FIELDS) do
		if request[key] ~= nil then
			return ERRORS.clear
		end
	end
	for key in pairs(request) do
		if key ~= "damage" and key ~= "healing" and key ~= "elapsed" then
			return ERRORS.hit
		end
	end
	if not finiteAmount(request.damage) then
		return ERRORS.damage
	end
	if request.healing ~= nil and not finiteAmount(request.healing) then
		return ERRORS.healing
	end
	if request.elapsed ~= nil and not finiteAmount(request.elapsed) then
		return ERRORS.elapsed
	end
	return nil
end

local function refused(reason: string): { [string]: any }
	return {
		ok = false,
		saved = false,
		granted = false,
		keys = 0,
		gold = 0,
		error = reason,
	}
end

local function normalized(saved: any)
	return Schema.applyGrove(saved, { ok = false })
end

local function stationsDone(state: any): boolean
	return type(state) == "table" and state.dummy == true and state.dodge == true and state.room == true
end

local function unmarked(state: any): string?
	local colors = state.colors
	if type(colors) ~= "table" then
		return "red"
	end
	for _, color in ipairs(TrainingGrove.CONFIG.colors) do
		if colors[color] ~= true then
			return color
		end
	end
	return nil
end

local function plan(state: any): string
	if state.dummy ~= true then
		return "hit"
	end
	if state.dodge ~= true then
		return "dodge"
	end
	if state.room ~= true then
		return "color"
	end
	if state.cosmetic ~= true then
		return "clear"
	end
	return "hit"
end

local function meter(state: any, elapsed: number): (number, number)
	local shown = TrainingGrove.readout(state, { elapsed = elapsed })
	if shown.ok == true and type(shown.dps) == "number" and type(shown.hps) == "number" then
		return shown.dps, shown.hps
	end
	return 0, 0
end

-- Pure. Does not write the profile and does not read a player id.
function GroveService.apply(saved: any, request: any): { [string]: any }
	local problem = requestError(request)
	if problem ~= nil then
		return refused(problem)
	end
	local current = normalized(saved)
	local action = plan(current)
	local damage = math.floor(request.damage)
	local healing = 0
	if request.healing ~= nil then
		healing = math.floor(request.healing)
	end
	local elapsed = 0
	if request.elapsed ~= nil then
		elapsed = request.elapsed
	end

	local step: any = nil
	if action == "hit" then
		step = TrainingGrove.hit(current, { damage = damage })
		if step.ok == true and healing > 0 then
			local healed = TrainingGrove.heal(step.state, { healing = healing })
			if healed.ok == true then
				step = healed
			end
		end
	elseif action == "dodge" then
		step = TrainingGrove.dodge(current, { color = "red" })
	elseif action == "color" then
		local color = unmarked(current)
		if color == nil then
			return refused(ERRORS.color)
		end
		step = TrainingGrove.color(current, { color = color })
	else
		step = TrainingGrove.clear(current)
	end

	if type(step) ~= "table" or step.ok ~= true or type(step.state) ~= "table" then
		local reason = ERRORS.state
		if type(step) == "table" and type(step.error) == "string" then
			reason = step.error
		end
		return refused(reason)
	end

	local readyState = step.state
	local state = step.state
	local granted = false
	local cosmeticId = nil
	if action ~= "clear" and stationsDone(state) and state.cosmetic ~= true then
		local cleared = TrainingGrove.clear(state)
		if type(cleared) == "table" and cleared.ok == true and type(cleared.state) == "table" then
			readyState = state
			state = cleared.state
			granted = cleared.granted == true
			if granted then
				cosmeticId = cleared.cosmeticId
			end
		end
	elseif action == "clear" then
		readyState = current
		granted = step.granted == true
		if granted then
			cosmeticId = step.cosmeticId
		end
	end

	local dps, hps = meter(state, elapsed)
	return {
		ok = true,
		saved = false,
		granted = granted,
		cosmeticId = cosmeticId,
		action = action,
		state = state,
		readyState = readyState,
		dps = dps,
		hps = hps,
		keys = 0,
		gold = 0,
	}
end

local function ownsRibbon(data: any): boolean
	if type(data.inventory) ~= "table" then
		return false
	end
	for _, item in pairs(data.inventory) do
		if type(item) == "table" and item.templateId == "grove_ribbon" then
			return true
		end
	end
	return false
end

local function ribbonItem(uid: string, obtainedAt: number)
	return {
		uid = uid,
		templateId = "grove_ribbon",
		name = "Grove Ribbon",
		kind = "Cosmetic",
		rarity = "Common",
		traits = {},
		stats = {},
		poolId = "grove",
		obtainedAt = obtainedAt,
		bound = true,
		tradeable = false,
		stars = 0,
		starProgress = 0,
	}
end

local function holdGold(data: any): (any, any)
	return data.gold, data.shardKeys
end

local function restoreGold(data: any, gold: any, keys: any)
	data.gold = gold
	data.shardKeys = keys
end

-- Writes the profile. Returns without replacing the grove when the call fails.
function GroveService.commit(data: any, request: any, uid: any, obtainedAt: any): { [string]: any }
	if type(data) ~= "table" then
		return refused(ERRORS.state)
	end
	local gold, keys = holdGold(data)
	local outcome = GroveService.apply(data.trainingGrove, request)
	if outcome.ok ~= true then
		restoreGold(data, gold, keys)
		return outcome
	end

	local stateToStore = outcome.state
	if outcome.granted == true and not ownsRibbon(data) then
		local bagFull = Schema.countItems(data) >= Schema.inventoryCap(data)
		local uidOk = type(uid) == "string" and uid ~= ""
		local taken = uidOk
			and (
				(type(data.inventory) == "table" and data.inventory[uid] ~= nil)
				or (type(data.pets) == "table" and data.pets[uid] ~= nil)
			)
		local wrongId = outcome.cosmeticId ~= "grove_ribbon"
		if bagFull or not uidOk or taken or wrongId then
			-- Keep the finished stations and retry the ribbon when the bag has room.
			stateToStore = outcome.readyState
			outcome.granted = false
			outcome.cosmeticId = nil
			outcome.error = if bagFull then "Inventory is full." else "Could not grant the ribbon."
		else
			if type(data.inventory) ~= "table" then
				data.inventory = {}
			end
			local stamped = 0
			if
				type(obtainedAt) == "number"
				and obtainedAt == obtainedAt
				and obtainedAt > 0
				and obtainedAt < math.huge
			then
				stamped = math.floor(obtainedAt)
			end
			local item = ribbonItem(uid, stamped)
			data.inventory[uid] = item
			if type(data.equipped) == "table" then
				Schema.clearEquip(data, uid)
			end
		end
	end

	local stored = Schema.applyGrove(data.trainingGrove, { ok = true, state = stateToStore })
	data.trainingGrove = stored
	outcome.state = stored
	restoreGold(data, gold, keys)
	outcome.saved = true
	outcome.keys = 0
	outcome.gold = 0
	return outcome
end

local function loadoutAmounts(profile: any): (number, number)
	local offense = CombatMath.loadout(profile)
	local damage = 0
	if type(offense) == "table" and finiteAmount(offense.damage) then
		damage = math.floor(offense.damage)
	end
	local healing = 0
	if type(offense) == "table" and finiteAmount(offense.lifesteal) and offense.lifesteal > 0 then
		local healed = math.floor(damage * offense.lifesteal)
		if finiteAmount(healed) then
			healing = healed
		end
	end
	return damage, healing
end

function GroveService.train(player: Player): { [string]: any }
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return refused(ERRORS.id)
	end
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return refused("Stand by the dummy.")
	end
	local grove = Haven.GROVE
	local dx = root.Position.X - grove.x
	local dz = root.Position.Z - grove.z
	if dx * dx + dz * dz > STAND_STUDS * STAND_STUDS then
		return refused("Stand by the dummy.")
	end
	local now = os.clock()
	if now < (readyAt[player] or 0) then
		return refused("Stand still a moment.")
	end

	local DataService = require(script.Parent.DataService)
	local profile = DataService.get(player)
	if profile == nil then
		return refused("Profile is still loading.")
	end
	local damage, healing = loadoutAmounts(profile)
	if startedAt[player] == nil then
		startedAt[player] = now
	end
	local elapsed = now - startedAt[player]
	if not finiteAmount(elapsed) then
		elapsed = 0
	end

	local HttpService = game:GetService("HttpService")
	local uid = HttpService:GenerateGUID(false)
	local outcome: any = nil
	local saved, err = DataService.mutate(player, function(data)
		outcome = GroveService.commit(data, {
			damage = damage,
			healing = healing,
			elapsed = elapsed,
		}, uid, os.time())
		if type(outcome) == "table" and outcome.saved == true then
			return nil
		end
		local reason = "The grove did not take that."
		if type(outcome) == "table" and type(outcome.error) == "string" then
			reason = outcome.error
		end
		return reason
	end)
	if type(outcome) ~= "table" then
		return refused(err or "The grove did not take that.")
	end
	if outcome.saved == true then
		readyAt[player] = os.clock() + SWING_GAP
	end
	if not saved and outcome.saved ~= true then
		outcome.ok = false
		outcome.saved = false
		if type(err) == "string" and outcome.error == nil then
			outcome.error = err
		end
	end
	return outcome
end

function GroveService.start()
	local haven = workspace:FindFirstChild("Haven")
	if haven == nil then
		warn("[Shardfall] Training Grove dummy is missing")
		return
	end
	local bound = 0
	for _, descendant in ipairs(haven:GetDescendants()) do
		if
			descendant:IsA("ProximityPrompt")
			and descendant:GetAttribute("HavenAction") == "grove"
			and descendant:GetAttribute("GroveBound") ~= true
		then
			descendant:SetAttribute("GroveBound", true)
			bound += 1
			descendant.Triggered:Connect(function(player)
				if typeof(player) ~= "Instance" or not player:IsA("Player") then
					return
				end
				GroveService.train(player)
			end)
		end
	end
	if bound == 0 then
		warn("[Shardfall] Training Grove prompt was not bound")
	else
		print(string.format("[Shardfall] Training Grove prompts bound: %d", bound))
	end
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
	startedAt[player] = nil
end)

return GroveService
