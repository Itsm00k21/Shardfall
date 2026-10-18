--!strict

--[[
	E-009. M1 remote fuzz.

	Every RemoteFunction bound in Remotes.luau, except keys of PARKED_ACTION.
	RemoteEvents (Attack, Dodge, Steer, and the server pushes) are not
	called. Each probe is a bad argument: nil, a wrong type, an empty
	string, a negative, NaN, math.huge, a huge string, an unknown id, and
	one extra argument.

	The body is the same check the remote runs, then the shared module that
	service calls. DataService.mutate is Schema.deepCopy, and a reason or a
	throw puts that copy back. A refused or ignored call leaves the profile
	equal to the copy taken before it. Nothing under src/ changes here.

	Pending, omitted from this run: SetAudio with a negative. The remote
	accepts any tonumber result and writes Audio.clampVolume, which turns a
	negative into 0. That changes musicVolume and sfxVolume.
	src/ServerScriptService/ShardfallServer/Remotes.luau:444
	src/ReplicatedStorage/Shared/Audio.luau:41
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Audio = require("../src/ReplicatedStorage/Shared/Audio")
local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local Crafting = require("../src/ReplicatedStorage/Shared/Crafting")
local Dungeons = require("../src/ReplicatedStorage/Shared/Dungeons")
local Economy = require("../src/ReplicatedStorage/Shared/Economy")
local FirstSessionKit = require("../src/ReplicatedStorage/Shared/FirstSessionKit")
local GoldShop = require("../src/ReplicatedStorage/Shared/GoldShop")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local Onboarding = require("../src/ReplicatedStorage/Shared/Onboarding")
local Pets = require("../src/ReplicatedStorage/Shared/Pets")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Quality = require("../src/ReplicatedStorage/Shared/Quality")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local Recipes = require("../src/ReplicatedStorage/Shared/Recipes")
local RollMath = require("../src/ReplicatedStorage/Shared/RollMath")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local Stars = require("../src/ReplicatedStorage/Shared/Stars")
local Trading = require("../src/ReplicatedStorage/Shared/Trading")
local Travel = require("../src/ReplicatedStorage/Shared/Travel")

local USER_ID = 42
local HUGE_STRING = string.rep("x", 4096)
local UNKNOWN = "no-such-id"
local WRONG = { wrong = true }

type Result = { ok: boolean, error: string? }

type Handler = (any, any, any, any, any, any) -> Result

type Probe = {
	label: string,
	n: number,
	a: any,
	b: any,
	c: any,
	d: any,
	e: any,
}

type Remote = {
	name: string,
	arity: number,
	omit: { [string]: boolean }?,
	more: { Probe }?,
}

local function fail(message: string): Result
	return { ok = false, error = message }
end

local function restore(data, backup)
	local keys = {}
	for key in pairs(data) do
		table.insert(keys, key)
	end
	for _, key in ipairs(keys) do
		data[key] = nil
	end
	for key, value in pairs(backup) do
		data[key] = value
	end
end

-- DataService.mutate: backup, run, put the backup back when the mutator
-- returns a reason or throws. The live table keeps its identity.
local function mutate(data, mutator: (any) -> any): (boolean, string?)
	local backup = Schema.deepCopy(data)
	local ok, result = pcall(mutator, data)
	if not ok or result ~= nil then
		restore(data, backup)
		if not ok then
			return false, "Could not update your profile."
		end
		if type(result) == "string" then
			return false, result
		end
		return false, "Could not update your profile."
	end
	return true, nil
end

local function refused(saved: boolean, err: string?, fallback: string): Result
	if saved then
		return { ok = true }
	end
	if type(err) ~= "string" or err == "" then
		return fail(fallback)
	end
	return fail(err)
end

local function steadyRng()
	return {
		nextNumber = function(_self): number
			return 0
		end,
		nextInteger = function(_self, minValue: number, _maxValue: number): number
			return minValue
		end,
	}
end

local function nextUid(): string
	return "fuzz-uid"
end

local function validUid(uid: any): boolean
	return type(uid) == "string" and #uid > 0 and #uid <= 64 and string.match(uid, "^[%w%-]+$") ~= nil
end

local function poolFromClient(poolId: any)
	if type(poolId) ~= "string" or string.match(poolId, "^[%w_]+$") == nil or #poolId > 64 then
		return nil
	end
	local pool = Pools.get(poolId)
	if pool == nil or pool.public ~= true then
		return nil
	end
	return pool
end

local function findPet(data, uid: string)
	if type(data.companions) ~= "table" then
		return nil
	end
	for _, pet in ipairs(data.companions) do
		if pet.uid == uid then
			return pet
		end
	end
	return nil
end

local handlers: { [string]: Handler } = {}

function handlers.GetProfile(_data, _extra)
	return { ok = true }
end

function handlers.GetOdds(data, poolId)
	if type(poolId) ~= "string" then
		return fail("Unknown shard.")
	end
	local pool = Pools.get(poolId)
	if pool == nil or pool.public ~= true then
		return fail("Unknown shard.")
	end
	local luck = RarityConfig.luckFromProfile(data)
	RarityConfig.disclose(pool, luck)
	return { ok = true }
end

function handlers.RollShard(_data, poolId, _skip)
	if poolFromClient(poolId) == nil then
		return fail("Unknown shard.")
	end
	-- A public pool would crack. The probes never name one.
	error("RollShard fuzz reached a public pool", 0)
end

function handlers.RollShards(_data, poolId, count)
	local total = count
	if type(total) ~= "number" or total ~= total or total == math.huge then
		return fail("Roll 1 to 10 shards.")
	end
	total = math.floor(total)
	if total < 1 or total > 10 then
		return fail("Roll 1 to 10 shards.")
	end
	if poolFromClient(poolId) == nil then
		return fail("Unknown shard.")
	end
	-- A public pool would crack. The probes never name one.
	error("RollShards fuzz reached a public pool", 0)
end

function handlers.OpenChest(data, tier, count)
	if type(tier) ~= "string" or ChestConfig.FLOOR[tier] == nil then
		return fail("Unknown chest.")
	end
	local amount = count
	if type(amount) ~= "number" then
		amount = 1
	end
	local saved, err = mutate(data, function(profile)
		local captured = ChestConfig.open(profile, tier, amount, steadyRng(), os.time(), nextUid)
		if captured.ok ~= true then
			return captured.error or "Could not open that chest."
		end
		return nil
	end)
	return refused(saved, err, "Could not open that chest.")
end

function handlers.ChooseChest(data, index)
	if type(index) ~= "number" then
		return fail("Pick one of the three cards.")
	end
	local saved, err = mutate(data, function(profile)
		local captured = ChestConfig.choose(profile, math.floor(index), steadyRng(), os.time(), nextUid)
		if type(captured) ~= "table" or captured.ok ~= true then
			local reason = if type(captured) == "table" then captured.error else nil
			return reason or "Could not choose that card."
		end
		return nil
	end)
	return refused(saved, err, "Could not choose that card.")
end

function handlers.MergeChest(data, tier)
	if type(tier) ~= "string" then
		return fail("Unknown chest.")
	end
	local saved, err = mutate(data, function(profile)
		local merged, reason = ChestConfig.merge(profile, tier)
		if merged == nil then
			return reason or "Could not merge those chests."
		end
		return nil
	end)
	return refused(saved, err, "Could not merge those chests.")
end

function handlers.BuyChest(data, tier)
	if type(tier) ~= "string" or not ChestConfig.forSale(tier) then
		return fail("That chest is not sold.")
	end
	local saved, err = mutate(data, function(profile)
		local bought, reason = ChestConfig.buyWithKeys(profile, tier)
		if bought == nil then
			return reason or "Could not buy that chest."
		end
		return nil
	end)
	return refused(saved, err, "Could not buy that chest.")
end

function handlers.ClaimLogin(data)
	local saved, err = mutate(data, function(profile)
		local granted, reason = ChestConfig.claimLogin(profile, os.time())
		if granted == nil then
			return reason or "Could not claim the daily chest."
		end
		return nil
	end)
	return refused(saved, err, "Could not claim the daily chest.")
end

function handlers.EquipItem(data, uid)
	if not validUid(uid) then
		return fail("You do not have that item.")
	end
	local saved, err = mutate(data, function(profile)
		local item = Schema.findItem(profile, uid)
		if item == nil then
			return "You do not have that item."
		end
		return Schema.equipItem(profile, item)
	end)
	return refused(saved, err, "You do not have that item.")
end

function handlers.UnequipItem(data, uid)
	if not validUid(uid) then
		return fail("You do not have that item.")
	end
	local saved, err = mutate(data, function(profile)
		local item = Schema.findItem(profile, uid)
		if item == nil then
			return "You do not have that item."
		end
		if not Schema.isEquipped(profile, uid) then
			return "That item is not equipped."
		end
		Schema.clearEquip(profile, uid)
		return nil
	end)
	return refused(saved, err, "You do not have that item.")
end

function handlers.RemoveItem(data, uid)
	if not validUid(uid) then
		return fail("You do not have that item.")
	end
	local saved, err = mutate(data, function(profile)
		local item, bag = Schema.findItem(profile, uid)
		if item == nil or bag == nil then
			return "You do not have that item."
		end
		local held = Trading.consumeBlock(uid)
		if held ~= nil then
			return held
		end
		if item.locked == true then
			return "That item is locked."
		end
		bag[uid] = nil
		Schema.clearEquip(profile, uid)
		return nil
	end)
	return refused(saved, err, "You do not have that item.")
end

function handlers.Debug(_data, _action)
	-- DebugService.run refuses before any mutate when RunService:IsStudio()
	-- is false. This harness is not Studio.
	return fail("Dev tools only work in Studio.")
end

function handlers.DevGrant(_data, kind)
	if type(kind) ~= "string" then
		return fail("Unknown dev grant.")
	end
	-- RollService.devGrant hits the same Studio check next.
	return fail("Dev tools only work in Studio.")
end

local function enterDungeon(data, dungeonId)
	local id = dungeonId
	if id == nil then
		id = Dungeons.ROOTVAULT_ID
	end
	if type(id) ~= "string" then
		return fail("Unknown dungeon.")
	end
	local dungeon = Dungeons.get(id)
	if dungeon == nil then
		return fail("Unknown dungeon.")
	end
	if not Dungeons.isUnlocked(dungeon, data.ascension) then
		return fail(string.format("Reach Ascension %d to enter %s.", dungeon.ascension, dungeon.name))
	end
	if dungeon.implemented ~= true or #dungeon.rooms == 0 then
		return fail(dungeon.name .. " is not built yet.")
	end
	-- DungeonService.enter stops here when the world folder is missing.
	-- It has not written the profile.
	return fail("The dungeon world is still loading.")
end

function handlers.Dungeon(data, action, dungeonId, _extra)
	if type(action) ~= "string" then
		return fail("Unknown dungeon action.")
	end
	if action == "enter" then
		return enterDungeon(data, dungeonId)
	end
	if action == "door" then
		return fail("No doors are open.")
	end
	if action == "advance" then
		return fail("You are not in a dungeon.")
	end
	if action == "leave" then
		return { ok = true }
	end
	if action == "skip" then
		return fail("Dev tools only work in Studio.")
	end
	return fail("Unknown dungeon action.")
end

function handlers.Craft(data, recipeId, targetUid)
	if targetUid ~= nil and not validUid(targetUid) then
		return fail("You do not have that item.")
	end
	if type(recipeId) == "string" then
		local recipe = Recipes.get(recipeId)
		if recipe ~= nil and type(recipe.result) == "table" then
			local kind = recipe.result.kind
			local closed = (kind == "reroll" and not LaunchGate.on("forgeReroll"))
				or (kind ~= "reroll" and not LaunchGate.on("forgeCraft"))
			if closed then
				return fail("That is closed.")
			end
		end
	end
	if type(recipeId) ~= "string" or string.match(recipeId, "^[%w_]+$") == nil or #recipeId > 64 then
		return fail("Unknown recipe.")
	end
	local saved, err = mutate(data, function(profile)
		local summary, reason = Crafting.commit(profile, recipeId, targetUid, RollMath.defaultRng(), nextUid(), os.time())
		if reason ~= nil or summary == nil then
			return reason or "Could not craft that."
		end
		return nil
	end)
	return refused(saved, err, "Could not craft that.")
end

function handlers.BuyGoldShop(data, offerId)
	local reason: string? = nil
	local saved, err = mutate(data, function(profile)
		reason = GoldShop.apply(profile, offerId)
		return reason
	end)
	if not saved then
		local message = if type(reason) == "string" then reason else err
		if type(message) ~= "string" or message == "" then
			message = "Could not buy that."
		end
		return fail(message)
	end
	return { ok = true }
end

function handlers.Travel(_data, destinationId)
	if type(destinationId) ~= "string" then
		return fail("Unknown destination.")
	end
	-- Not in a run, so TravelService.go reaches Travel.get before mutate.
	if Travel.get(destinationId) == nil then
		return fail("Unknown destination.")
	end
	return fail("You are still loading.")
end

function handlers.SetShake(data, enabled)
	if type(enabled) ~= "boolean" then
		return fail("Shake must be on or off.")
	end
	local saved, err = mutate(data, function(profile)
		profile.shake = enabled == true
		return nil
	end)
	return refused(saved, err, "Could not save the shake setting.")
end

function handlers.SetAudio(data, music, sfx)
	if tonumber(music) == nil or tonumber(sfx) == nil then
		return fail("Volume needs a number.")
	end
	local saved, err = mutate(data, function(profile)
		profile.musicVolume = Audio.clampVolume(music)
		profile.sfxVolume = Audio.clampVolume(sfx)
		return nil
	end)
	return refused(saved, err, "Could not update your profile.")
end

function handlers.SetSettings(data, patch)
	if type(patch) ~= "table" then
		return fail("Settings need a table.")
	end
	local nextSettings = Settings.normalize(patch)
	local saved, err = mutate(data, function(profile)
		profile.uiSettings = nextSettings
		local quality = nextSettings.graphics.quality
		profile.graphicsQuality = if quality == "auto" then "" else quality
		if Quality.normalize(profile.graphicsQuality) == nil then
			profile.graphicsQuality = ""
		end
		profile.shake = nextSettings.camera.shake
		profile.musicVolume = nextSettings.audio.music
		profile.sfxVolume = nextSettings.audio.sfx
		return nil
	end)
	return refused(saved, err, "Could not update your profile.")
end

function handlers.SetGraphicsQuality(data, tier)
	local id = Quality.normalize(tier)
	if id == nil then
		return fail("Unknown graphics quality.")
	end
	local saved, err = mutate(data, function(profile)
		profile.graphicsQuality = id
		return nil
	end)
	if not saved then
		return refused(saved, err, "Could not update your profile.")
	end
	return { ok = true }
end

local function setFlag(data, uid, flag: string, value)
	if not validUid(uid) or type(value) ~= "boolean" then
		return fail("You do not have that item.")
	end
	local saved, err = mutate(data, function(profile)
		local item = Schema.findItem(profile, uid)
		if item == nil then
			return "You do not have that item."
		end
		if flag == "locked" then
			item.locked = value
		else
			item.favorite = value
		end
		return nil
	end)
	return refused(saved, err, "You do not have that item.")
end

function handlers.SetItemLock(data, uid, locked)
	return setFlag(data, uid, "locked", locked)
end

function handlers.SetItemFavorite(data, uid, favorite)
	return setFlag(data, uid, "favorite", favorite)
end

function handlers.FeedItem(data, keptUid, feederUid)
	if not validUid(keptUid) or not validUid(feederUid) then
		return fail("You do not have that item.")
	end
	local saved, err = mutate(data, function(profile)
		local kept, keptBag = Schema.findItem(profile, keptUid)
		local feeder, feederBag = Schema.findItem(profile, feederUid)
		if kept == nil or feeder == nil or keptBag == nil or feederBag == nil then
			return "You do not have that item."
		end
		local held = Trading.consumeBlock(feederUid) or Trading.consumeBlock(keptUid)
		if held ~= nil then
			return held
		end
		if feeder.locked == true then
			return "That item is locked."
		end
		if keptBag ~= feederBag then
			return "Feed a duplicate of the same item."
		end
		local preview, reason = Stars.commit(kept, feeder)
		if preview == nil then
			return reason or "Could not feed that."
		end
		feederBag[feederUid] = nil
		Schema.clearEquip(profile, feederUid)
		return nil
	end)
	return refused(saved, err, "Could not feed that.")
end

function handlers.SetAutoFarm(_data, enabled)
	if type(enabled) ~= "boolean" then
		return fail("Auto farm needs on or off.")
	end
	-- DungeonService.setAutoFarm stores a session flag, not the profile.
	return { ok = true }
end

function handlers.SetAutoAttack(_data, enabled)
	if type(enabled) ~= "boolean" then
		return fail("Auto attack needs on or off.")
	end
	-- CombatService.setAutoAttack stores a session flag, not the profile.
	return { ok = true }
end

function handlers.UseTonic(_data)
	-- CombatService.useTonic returns before mutate when health is already full.
	-- This profile is not in a fight.
	return fail("Already at full health.")
end

function handlers.SetActionBar(data, classId, slots, locked)
	if type(classId) ~= "string" then
		return fail("Pick a class at the Forge.")
	end
	local bar, why = ActionSlots.accept(classId, slots, locked, data)
	if bar == nil then
		return fail(why or "The bar needs 8 slots.")
	end
	local saved, err = mutate(data, function(profile)
		if type(profile.actionBars) ~= "table" then
			profile.actionBars = {}
		end
		profile.actionBars[classId] = bar
		return nil
	end)
	return refused(saved, err, "Could not save the bar.")
end

function handlers.UseActionSlot(data, index)
	if type(index) ~= "number" then
		return fail("That slot is empty.")
	end
	local slotIndex = math.floor(index)
	if slotIndex < 1 or slotIndex > ActionSlots.COUNT then
		return fail("That slot is empty.")
	end
	local classId = data.classId
	if type(classId) ~= "string" or classId == "" then
		return fail("Pick a class at the Forge.")
	end
	return fail("That slot is empty.")
end

function handlers.HatchPet(data)
	local saved, err = mutate(data, function(profile)
		if (profile.eggs or 0) < 1 and (profile.gold or 0) < Pets.EGG_COST then
			return "An egg costs 50 gold."
		end
		if (profile.eggs or 0) > 0 then
			profile.eggs -= 1
		else
			profile.gold -= Pets.EGG_COST
		end
		local pet = Pets.hatch(0)
		pet.uid = nextUid()
		if type(profile.companions) ~= "table" then
			profile.companions = {}
		end
		table.insert(profile.companions, pet)
		return nil
	end)
	return refused(saved, err, "Could not hatch.")
end

function handlers.PetCare(data, uid, kind)
	if type(uid) ~= "string" or (kind ~= "pet" and kind ~= "feed") then
		return fail("Pet or feed a companion.")
	end
	local saved, err = mutate(data, function(profile)
		local pet = findPet(profile, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		if kind == "pet" then
			Pets.pet(pet)
		else
			Pets.feed(pet)
		end
		return nil
	end)
	return refused(saved, err, "Could not do that.")
end

function handlers.PaintPet(data, uid, primary, secondary, glow)
	if type(uid) ~= "string" or type(primary) ~= "string" then
		return fail("Pick a color.")
	end
	local saved, err = mutate(data, function(profile)
		local pet = findPet(profile, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		Pets.colors(pet, primary, if type(secondary) == "string" then secondary else "sap", if type(glow) == "string" then glow else "none")
		return nil
	end)
	return refused(saved, err, "Could not paint.")
end

function handlers.FavoritePet(data, uid, locked)
	if type(uid) ~= "string" or type(locked) ~= "boolean" then
		return fail("Pick a companion.")
	end
	local saved, err = mutate(data, function(profile)
		local pet = findPet(profile, uid)
		if pet == nil then
			return "That companion is not in the den."
		end
		pet.favorite = locked
		return nil
	end)
	return refused(saved, err, "Could not lock that.")
end

function handlers.Loops(data)
	local saved, err = mutate(data, function(profile)
		Loops.refresh(profile, os.time(), USER_ID)
		return nil
	end)
	return refused(saved, err, "The board is not ready.")
end

function handlers.RerollDaily(data, index)
	if type(index) ~= "number" or index < 1 or index > 3 then
		return fail("Pick a daily.")
	end
	local slot = math.floor(index)
	local saved, err = mutate(data, function(profile)
		local now = os.time()
		local today = Loops.dayNumber(now)
		Loops.refresh(profile, now, USER_ID)
		if profile.dailyRerollDay == today then
			return "One free reroll a day."
		end
		local worked, text = Loops.reroll(profile.dailies, slot, today, USER_ID + slot)
		if not worked then
			return text
		end
		profile.dailyRerollDay = today
		return nil
	end)
	return refused(saved, err, "Could not reroll.")
end

function handlers.UpgradeGear(data, uid)
	if type(uid) ~= "string" or uid == "" then
		return fail("Pick a piece of gear.")
	end
	local saved, err = mutate(data, function(profile)
		local item = profile.inventory[uid]
		local upgraded, why = Economy.upgrade(item, profile)
		if not upgraded then
			return why
		end
		return nil
	end)
	return refused(saved, err, "Could not upgrade that.")
end

function handlers.Onboard(data, action)
	if action == "skip" then
		local saved, err = mutate(data, function(profile)
			if profile.onboardDone ~= true then
				Onboarding.starter(profile)
			end
			FirstSessionKit.grant(profile)
			return nil
		end)
		return refused(saved, err, "Could not save.")
	end
	if data.onboardDone == true then
		return { ok = true }
	end
	if data.onboardStep ~= "open" and data.onboardStep ~= "haven" then
		return fail("Try it in the world first.")
	end
	local saved, err = mutate(data, function(profile)
		if profile.onboardStep == "haven" then
			Onboarding.starter(profile)
		else
			local following = Onboarding.next(profile.onboardStep)
			if following == nil then
				Onboarding.starter(profile)
			else
				profile.onboardStep = following
			end
		end
		if profile.onboardDone == true then
			FirstSessionKit.grant(profile)
		end
		return nil
	end)
	return refused(saved, err, "Could not save.")
end

function handlers.SetClass(data, classId)
	if Classes.get(classId) == nil then
		return fail("That class is not in the beta.")
	end
	local saved, err = mutate(data, function(profile)
		profile.classId = classId
		if type(profile.classXp[classId]) ~= "number" then
			profile.classXp[classId] = 0
		end
		FirstSessionKit.grant(profile)
		return nil
	end)
	return refused(saved, err, "Could not save the class.")
end

function handlers.PickTalent(data, talentId)
	if type(talentId) ~= "string" then
		return fail("Pick one of the two level 5 talents.")
	end
	if Classes.get(data.classId) == nil then
		return fail("Pick a class first.")
	end
	local level = Classes.progress(data.classXp[data.classId] or 0)
	if level < Classes.TALENT_LEVEL then
		return fail("Class level 5 unlocks a talent.")
	end
	if not Classes.validTalent(data.classId, talentId) then
		return fail("That talent is not on this class.")
	end
	local saved, err = mutate(data, function(profile)
		profile.classTalent[profile.classId] = talentId
		return nil
	end)
	return refused(saved, err, "Could not save the talent.")
end

function handlers.UseSkill(_data, _slot)
	-- ClassService.cast returns before a profile write when the player is
	-- not in a crawl.
	return fail("Skills are for a crawl.")
end

local REMOTES: { Remote } = {
	{ name = "GetProfile", arity = 0 },
	{ name = "GetOdds", arity = 1 },
	{ name = "RollShard", arity = 2 },
	{ name = "RollShards", arity = 2 },
	{
		name = "OpenChest",
		arity = 2,
		more = {
			{ label = "negative count", n = 2, a = "Common", b = -1, c = nil, d = nil, e = nil },
			{ label = "nan count", n = 2, a = "Common", b = 0 / 0, c = nil, d = nil, e = nil },
			{ label = "huge count", n = 2, a = "Common", b = math.huge, c = nil, d = nil, e = nil },
			{ label = "nil count", n = 2, a = "Common", b = nil, c = nil, d = nil, e = nil },
		},
	},
	{ name = "ChooseChest", arity = 1 },
	{ name = "MergeChest", arity = 1 },
	{ name = "BuyChest", arity = 1 },
	{ name = "ClaimLogin", arity = 0 },
	{ name = "EquipItem", arity = 1 },
	{ name = "UnequipItem", arity = 1 },
	{ name = "RemoveItem", arity = 1 },
	{ name = "Debug", arity = 1 },
	{ name = "DevGrant", arity = 1 },
	{
		name = "Dungeon",
		arity = 3,
		more = {
			{ label = "unknown dungeon", n = 3, a = "enter", b = UNKNOWN, c = true, d = nil, e = nil },
		},
	},
	{
		name = "Craft",
		arity = 2,
		more = {
			{ label = "unknown recipe", n = 1, a = "no_such_recipe", b = nil, c = nil, d = nil, e = nil },
		},
	},
	{ name = "BuyGoldShop", arity = 1 },
	{ name = "Travel", arity = 1 },
	{ name = "SetShake", arity = 1 },
	{
		name = "SetAudio",
		arity = 2,
		-- A negative is tonumber-able. clampVolume writes 0. See the header.
		omit = { negative = true, ["negative plus extra"] = true },
	},
	{ name = "SetSettings", arity = 1 },
	{ name = "SetGraphicsQuality", arity = 1 },
	{
		name = "SetItemLock",
		arity = 2,
		more = {
			{ label = "unknown id locked", n = 2, a = UNKNOWN, b = true, c = nil, d = nil, e = nil },
		},
	},
	{
		name = "SetItemFavorite",
		arity = 2,
		more = {
			{ label = "unknown id favorite", n = 2, a = UNKNOWN, b = true, c = nil, d = nil, e = nil },
		},
	},
	{
		name = "FeedItem",
		arity = 2,
		more = {
			{ label = "unknown ids", n = 2, a = UNKNOWN, b = "also-missing", c = nil, d = nil, e = nil },
		},
	},
	{ name = "SetAutoFarm", arity = 1 },
	{ name = "SetAutoAttack", arity = 1 },
	{ name = "UseTonic", arity = 0 },
	{
		name = "SetActionBar",
		arity = 3,
		more = {
			{ label = "unknown class", n = 3, a = UNKNOWN, b = {}, c = true, d = nil, e = nil },
		},
	},
	{ name = "UseActionSlot", arity = 1 },
	{ name = "HatchPet", arity = 0 },
	{
		name = "PetCare",
		arity = 2,
		more = {
			{ label = "unknown pet", n = 2, a = UNKNOWN, b = "pet", c = nil, d = nil, e = nil },
			{ label = "unknown feed", n = 2, a = UNKNOWN, b = "feed", c = nil, d = nil, e = nil },
		},
	},
	{
		name = "PaintPet",
		arity = 4,
		more = {
			{
				label = "unknown pet",
				n = 4,
				a = UNKNOWN,
				b = UNKNOWN,
				c = UNKNOWN,
				d = UNKNOWN,
				e = nil,
			},
		},
	},
	{
		name = "FavoritePet",
		arity = 2,
		more = {
			{ label = "unknown pet", n = 2, a = UNKNOWN, b = true, c = nil, d = nil, e = nil },
		},
	},
	{ name = "Loops", arity = 0 },
	{
		name = "RerollDaily",
		arity = 1,
		more = {
			{ label = "unknown slot", n = 1, a = 99, b = nil, c = nil, d = nil, e = nil },
		},
	},
	{ name = "UpgradeGear", arity = 1 },
	{ name = "Onboard", arity = 1 },
	{ name = "SetClass", arity = 1 },
	{ name = "PickTalent", arity = 1 },
	{ name = "UseSkill", arity = 1 },
}

local BAD = {
	{ "nil", nil },
	{ "wrong type", WRONG },
	{ "empty string", "" },
	{ "negative", -1 },
	{ "nan", 0 / 0 },
	{ "huge", math.huge },
	{ "huge string", HUGE_STRING },
	{ "unknown id", UNKNOWN },
}

local function blankProbe(label: string, n: number): Probe
	return {
		label = label,
		n = n,
		a = nil,
		b = nil,
		c = nil,
		d = nil,
		e = nil,
	}
end

local function makeProbe(label: string, value: any, arity: number, extra: boolean): Probe
	local n = if arity == 0 then 1 else if extra then arity + 1 else arity
	local shown = if arity == 0 then "extra " .. label else if extra then label .. " plus extra" else label
	local probe = blankProbe(shown, n)
	if arity == 0 then
		probe.a = value
		return probe
	end
	if arity >= 1 then
		probe.a = value
	end
	if arity >= 2 then
		probe.b = value
	elseif extra then
		probe.b = "extra"
	end
	if arity >= 3 then
		probe.c = value
	elseif extra and arity == 2 then
		probe.c = "extra"
	end
	if arity >= 4 then
		probe.d = value
	elseif extra and arity == 3 then
		probe.d = "extra"
	end
	if extra and arity >= 4 then
		probe.e = "extra"
	end
	return probe
end

local function probesFor(remote: Remote): { Probe }
	local list = {}
	for _, row in ipairs(BAD) do
		local label = row[1]
		local value = row[2]
		if remote.arity == 0 then
			table.insert(list, makeProbe(label, value, 0, true))
		else
			table.insert(list, makeProbe(label, value, remote.arity, false))
			table.insert(list, makeProbe(label, value, remote.arity, true))
		end
	end
	if remote.name == "SetSettings" then
		for _, probe in ipairs(list) do
			if string.find(probe.label, "wrong type", 1, true) ~= nil then
				probe.a = false
			end
		end
	end
	if remote.more ~= nil then
		for _, probe in ipairs(remote.more) do
			table.insert(list, probe)
		end
	end
	return list
end

local function invoke(handler: Handler, data, probe: Probe): Result
	local n = probe.n
	if n <= 1 then
		return handler(data, probe.a, nil, nil, nil, nil)
	elseif n == 2 then
		return handler(data, probe.a, probe.b, nil, nil, nil)
	elseif n == 3 then
		return handler(data, probe.a, probe.b, probe.c, nil, nil)
	elseif n == 4 then
		return handler(data, probe.a, probe.b, probe.c, probe.d, nil)
	end
	return handler(data, probe.a, probe.b, probe.c, probe.d, probe.e)
end

local function fuzzProfile()
	local data = Schema.template()
	data.eggs = 0
	data.gold = 0
	data.onboardStep = "swing"
	data.lastLoginDay = Loops.dayNumber(os.time())
	-- Loops.refresh fills an empty board. Prime it so an ignored extra
	-- argument on a later refresh does not look like a new write.
	Loops.refresh(data, os.time(), USER_ID)
	return data
end

local function namesIn(source: string, kind: string): { string }
	local found = {}
	local seen = {}
	for name in string.gmatch(source, kind .. '%("([%w]+)"%)') do
		if seen[name] ~= true then
			seen[name] = true
			table.insert(found, name)
		end
	end
	return found
end

local function parkedMap(source: string): { [string]: string }
	local from = string.find(source, "local PARKED_ACTION", 1, true)
	local to = string.find(source, "local function guard", from or 1, true)
	expect(from ~= nil and to ~= nil).toBeTrue()
	local body = string.sub(source, from :: number, (to :: number) - 1)
	local map = {}
	for name, flag in string.gmatch(body, '([%w]+)%s*=%s*"([%w]+)"') do
		map[name] = flag
	end
	return map
end

describe("M1 remote fuzz", function()
	it("covers every RemoteFunction that is not parked", function()
		expect(Schema.VERSION).toEqual(26)
		local source = fs.readFile("src/ServerScriptService/ShardfallServer/Remotes.luau")
		local parked = parkedMap(source)
		local bound = {}
		for _, name in ipairs(namesIn(source, "functionRemote")) do
			bound[name] = true
		end
		for _, name in ipairs(namesIn(source, "eventRemote")) do
			if handlers[name] ~= nil then
				error(name .. " is a RemoteEvent", 0)
			end
		end
		local covered = 0
		for _, remote in ipairs(REMOTES) do
			covered += 1
			if handlers[remote.name] == nil then
				error(remote.name .. " has no handler", 0)
			end
			if bound[remote.name] ~= true then
				error(remote.name .. " is not a bound RemoteFunction", 0)
			end
			if parked[remote.name] ~= nil then
				error(remote.name .. " is parked", 0)
			end
		end
		for name in pairs(bound) do
			local closed = parked[name] ~= nil
			local listed = handlers[name] ~= nil
			if closed == listed then
				error(name .. " must be fuzzed or parked, not both and not neither", 0)
			end
		end
		for name in pairs(handlers) do
			local found = false
			for _, remote in ipairs(REMOTES) do
				if remote.name == name then
					found = true
				end
			end
			if not found then
				error(name .. " is missing from the remote list", 0)
			end
		end
		expect(covered > 0).toBeTrue()
	end)

	for _, remote in ipairs(REMOTES) do
		it("refuses bad " .. remote.name .. " input", function()
			local handler = handlers[remote.name]
			local data = fuzzProfile()
			for _, probe in ipairs(probesFor(remote)) do
				if remote.omit == nil or remote.omit[probe.label] ~= true then
					local before = Schema.deepCopy(data)
					local ok, result = pcall(invoke, handler, data, probe)
					if not ok then
						error(remote.name .. " " .. probe.label .. " threw: " .. tostring(result), 0)
					end
					if type(result) ~= "table" then
						error(remote.name .. " " .. probe.label .. " returned " .. typeof(result), 0)
					end
					expect(data).toEqual(before)
				end
			end
		end)
	end
end)
