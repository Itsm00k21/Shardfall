--!strict

--[[
	Class select, Forge swap, skill casts, and class XP.

	The client names a class or a skill slot. This module checks the row in
	Classes, spends the session resource, and asks CombatService to land
	the hit. Nothing here trusts a damage number from the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local CombatMath = require(ReplicatedStorage.Shared.CombatMath)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local DungeonService = require(script.Parent.DungeonService)
local OnboardingService = require(script.Parent.OnboardingService)

local ClassService = {}

type Session = {
	resource: number,
	guardUntil: number,
	readyAt: { [string]: number },
	chill: number,
}

local sessions: { [Player]: Session } = {}

local function session(player: Player): Session
	local found = sessions[player]
	if found == nil then
		found = {
			resource = 0,
			guardUntil = 0,
			readyAt = {},
			chill = 0,
		}
		sessions[player] = found
	end
	return found
end

local function fx(player: Player, payload: { [string]: any })
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes == nil then
		return
	end
	local remote = remotes:FindFirstChild("CombatFx")
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote:FireClient(player, payload)
	end
end

function ClassService.mods(player: Player): { taken: number, dealt: number }
	local profile = DataService.get(player)
	local classId = if profile ~= nil then profile.classId else ""
	local state = session(player)
	local hp, maxHp = CombatService.vitals(player)
	local standing = not CombatService.isSteering(player)
	local guarding = os.clock() < state.guardUntil
	local unstable = classId == "voidcaster" and state.resource <= 0 and profile ~= nil
	local taken = Classes.takenMultiplier(classId, standing, guarding)
		* Classes.unstableTaken(classId, unstable)
	local dealt = Classes.dealtMultiplier(classId, hp, maxHp, unstable)
	if classId == "frostblade" and state.chill >= 5 then
		dealt *= 1.25
	end
	return { taken = taken, dealt = dealt }
end

function ClassService.select(player: Player, classId: any): { [string]: any }
	if DungeonService.isInRun(player) then
		return { ok = false, error = "Swap classes at the Forge, between runs." }
	end
	if Classes.get(classId) == nil then
		return { ok = false, error = "That class is not in the beta." }
	end
	local saved, err = DataService.mutate(player, function(data)
		data.classId = classId
		if type(data.classXp[classId]) ~= "number" then
			data.classXp[classId] = 0
		end
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save the class." }
	end
	local row = session(player)
	row.resource = if classId == "voidcaster" then 100 else 0
	row.chill = 0
	OnboardingService.note(player, "class")
	return { ok = true, classId = classId, profile = DataService.snapshot(player) }
end

function ClassService.pickTalent(player: Player, talentId: any): { [string]: any }
	if type(talentId) ~= "string" then
		return { ok = false, error = "Pick one of the two level 5 talents." }
	end
	local profile = DataService.get(player)
	if profile == nil or Classes.get(profile.classId) == nil then
		return { ok = false, error = "Pick a class first." }
	end
	local level = Classes.progress(profile.classXp[profile.classId] or 0)
	if level < Classes.TALENT_LEVEL then
		return { ok = false, error = "Class level 5 unlocks a talent." }
	end
	if not Classes.validTalent(profile.classId, talentId) then
		return { ok = false, error = "That talent is not on this class." }
	end
	local saved, err = DataService.mutate(player, function(data)
		data.classTalent[data.classId] = talentId
		return nil
	end)
	if not saved then
		return { ok = false, error = err or "Could not save the talent." }
	end
	return { ok = true, profile = DataService.snapshot(player) }
end

function ClassService.grantXp(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	DataService.mutate(player, function(data)
		local classId = data.classId
		if Classes.get(classId) == nil then
			return nil
		end
		data.classXp[classId] = (data.classXp[classId] or 0) + amount
		return nil
	end)
end

function ClassService.cast(player: Player, slot: any): { [string]: any }
	if not DungeonService.isInRun(player) then
		return { ok = false, error = "Skills are for a crawl." }
	end
	local profile = DataService.get(player)
	if profile == nil then
		return { ok = false, error = "Profile is still loading." }
	end
	local classDef = Classes.get(profile.classId)
	if classDef == nil then
		return { ok = false, error = "Pick a class at the Forge." }
	end
	local state = session(player)
	local talent = profile.classTalent[profile.classId]
	local level = Classes.progress(profile.classXp[profile.classId] or 0)
	if level < Classes.TALENT_LEVEL then
		talent = nil
	end
	local picked: Classes.Skill? = nil
	local key = ""
	if slot == "ult" then
		if CombatService.ultCharge(player) < Classes.ULT_COST then
			return { ok = false, error = "Ultimate is still filling." }
		end
		picked = classDef.ultimate
		key = "ult"
	elseif type(slot) == "number" then
		picked = classDef.skills[math.floor(slot)]
		key = tostring(math.floor(slot))
	end
	if picked == nil then
		return { ok = false, error = "That skill slot is empty." }
	end
	local now = os.clock()
	if now < (state.readyAt[key] or 0) then
		return { ok = false, error = picked.name .. " is still cooling down." }
	end
	local tuned = Classes.tune(picked, talent)
	if tuned.resource < 0 and state.resource < -tuned.resource and classDef.id ~= "voidcaster" then
		return { ok = false, error = "Not enough " .. classDef.resource .. "." }
	end
	if classDef.id == "voidcaster" and tuned.resource < 0 then
		state.resource = math.max(0, state.resource + tuned.resource)
	elseif tuned.resource < 0 then
		state.resource += tuned.resource
	else
		local gain = tuned.resource
		if talent == "bellows" and gain > 0 then
			gain = math.floor(gain * 1.25)
		end
		state.resource = math.min(100, state.resource + gain)
	end
	if tuned.kind == "guard" then
		state.guardUntil = now + 1.5
	end
	if tuned.kind == "vent" then
		tuned.damage = tuned.damage * (1 + state.resource / 50)
		state.resource = 0
	end
	if classDef.id == "frostblade" then
		state.chill = math.min(5, state.chill + math.max(1, tuned.resource))
	end
	state.readyAt[key] = now + tuned.cooldown
	-- vitality.maxHealth is the unbuffed loadout. Percent heals use that
	-- number, then healAmount scales it once. The published max is already
	-- echoed, so a percent of vitals would apply Story Echo twice.
	local offense, vitality = CombatMath.loadout(profile)
	local hits = 0
	if tuned.damage > 0 then
		local views = DungeonService.enemyViews(player)
		local limit = if tuned.radius >= 10 then 4 else 1
		if talent == "riptide" and tuned.id == "tidal_bolt" then
			limit = 2
		end
		for _, enemy in ipairs(views) do
			if hits >= limit then
				break
			end
			hits += 1
			CombatService.strike(player, enemy, offense.damage * tuned.damage, tuned.kind ~= "bolt")
			if classDef.id == "voidcaster" and tuned.id == "hex" then
				CombatService.strike(player, enemy, offense.damage * 0.15, false)
			end
		end
	end
	local healed = 0
	local baseMax = vitality.maxHealth
	if tuned.heal > 0 then
		healed = math.max(1, math.floor(baseMax * tuned.heal))
		CombatService.healAmount(player, healed)
		if classDef.id == "tidecaller" then
			-- Flat share of this heal, not another percent of max.
			CombatService.healAmount(player, math.floor(healed * 0.15))
		end
	end
	if tuned.shield > 0 then
		CombatService.healAmount(player, math.floor(baseMax * tuned.shield))
	end
	if slot == "ult" then
		CombatService.spendUlt(player)
	else
		CombatService.addUlt(player, 8)
	end
	fx(player, {
		kind = "skill",
		name = tuned.name,
		note = tuned.note,
		resource = state.resource,
		resourceName = classDef.resource,
		hits = hits,
		healed = healed,
		sound = if slot == "ult" then classDef.sounds.ult else classDef.sounds.skill,
		color = classDef.palette,
	})
	return {
		ok = true,
		name = tuned.name,
		resource = state.resource,
		profile = DataService.snapshot(player),
	}
end

function ClassService.onHit(player: Player)
	local profile = DataService.get(player)
	if profile == nil or profile.classId ~= "warden" then
		return
	end
	local state = session(player)
	state.resource = math.min(100, state.resource + 8)
	local talent = profile.classTalent.warden
	if talent == "thornmail" then
		local views = DungeonService.enemyViews(player)
		local enemy = views[1]
		if enemy ~= nil then
			CombatService.strike(player, enemy, 4, false)
		end
	end
end

function ClassService.start()
	CombatService.bindClassMods(function(player)
		return ClassService.mods(player)
	end)
end

return ClassService
