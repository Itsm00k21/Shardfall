--!strict

--[[
	RemoteFunctions the test UI calls. Every one of them:

	  1. Rate-limits the player.
	  2. Checks the argument types here, before any service sees them.
	  3. pcalls the service so a bug becomes "Something went wrong." and
	     not a raw error string sent to the client.
	  4. Attaches a fresh profile snapshot on the way out.

	The RemoteFunction instances themselves live in default.project.json
	(ReplicatedStorage.Remotes) so they exist as soon as Rojo syncs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.Shared.Audio)
local ActionBarService = require(script.Parent.ActionBarService)
local ChestService = require(script.Parent.ChestService)
local ClassService = require(script.Parent.ClassService)
local CombatService = require(script.Parent.CombatService)
local CraftService = require(script.Parent.CraftService)
local DataService = require(script.Parent.DataService)
local DebugService = require(script.Parent.DebugService)
local DungeonService = require(script.Parent.DungeonService)
local InventoryService = require(script.Parent.InventoryService)
local PetService = require(script.Parent.PetService)
local RaidService = require(script.Parent.RaidService)
local LoopService = require(script.Parent.LoopService)
local MarketService = require(script.Parent.MarketService)
local OnboardingService = require(script.Parent.OnboardingService)
local RateLimiter = require(script.Parent.RateLimiter)
local PolicyCache = require(script.Parent.PolicyCache)
local RollService = require(script.Parent.RollService)
local TradeService = require(script.Parent.TradeService)
local TravelService = require(script.Parent.TravelService)
local GoldShop = require(ReplicatedStorage.Shared.GoldShop)
local DevAccess = require(ReplicatedStorage.Shared.DevAccess)
local LaunchGate = require(ReplicatedStorage.Shared.LaunchGate)
local Pools = require(ReplicatedStorage.Shared.Pools)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Quality = require(ReplicatedStorage.Shared.Quality)
local Rarities = require(ReplicatedStorage.Shared.Rarities)
local Settings = require(ReplicatedStorage.Shared.Settings)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RemoteCaller = require(ReplicatedStorage.Shared.RemoteCaller)

local Remotes = {}

local folder: Folder? = nil

local function remoteFolder(): Folder
	if folder == nil then
		local found = ReplicatedStorage:WaitForChild("Remotes", 15)
		assert(
			found ~= nil and found:IsA("Folder"),
			"ReplicatedStorage.Remotes is missing. Is Rojo synced?"
		)
		folder = found :: Folder
	end
	return folder :: Folder
end

local function functionRemote(name: string): RemoteFunction
	local instance = remoteFolder():WaitForChild(name, 15)
	assert(instance ~= nil and instance:IsA("RemoteFunction"), "Missing RemoteFunction " .. name)
	return instance
end

local function eventRemote(name: string): RemoteEvent
	local instance = remoteFolder():WaitForChild(name, 15)
	assert(instance ~= nil and instance:IsA("RemoteEvent"), "Missing RemoteEvent " .. name)
	return instance
end

function Remotes.pushPolicy(player: Player, policy: any)
	if player.Parent == nil then
		return
	end
	local remote = eventRemote("PolicyUpdated")
	remote:FireClient(player, policy)
end

function Remotes.pushProfile(player: Player, snapshot: any, saving: boolean)
	if player.Parent == nil then
		return
	end
	eventRemote("ProfileUpdated"):FireClient(player, snapshot, saving)
end

local function firstLine(detail: string): string
	local line = string.match(detail, "^[^\r\n]+") or detail
	if #line > 300 then
		line = string.sub(line, 1, 300)
	end
	return line
end

local function fail(action: string, detail: string)
	warn(string.format("[Shardfall] %s: %s", action, detail))
	return { ok = false, error = firstLine(detail) }
end

local function respond(player: Player, action: string, result: any)
	if type(result) ~= "table" then
		return fail(action, string.format("handler returned %s, expected a table", typeof(result)))
	end
	result.saving = DataService.isPersistent(player)
	local snapshot = DataService.snapshot(player)
	if snapshot ~= nil then
		result.profile = snapshot
	end
	result.policy = PolicyCache.public(player)
	return result
end

-- Remote action name to the launch switch that keeps it closed.
local PARKED_ACTION: { [string]: string } = {
	Salvage = "forgeSalvage",
	BulkSalvage = "forgeSalvage",
	FusePet = "petEvolution",
	Trade = "trading",
	Market = "market",
	ClaimPass = "pass",
	PremiumPass = "pass",
	StartDailyBoss = "pass",
	RaidQueue = "raids",
	RaidPost = "raids",
	RaidJoin = "raids",
	RaidPractice = "raids",
	RaidBuy = "raids",
	RaidLeave = "raids",
	RaidReady = "raids",
	BuyTravelPass = "extraRealms",
	BuyDustShard = "extraCurrencies",
	SetChestOptions = "chests",
	BuyChestBundle = "chests",
	BuyForgeBoost = "paid",
	SetClass = "classes",
	PickTalent = "classes",
	Travel = "travel",
	FeedItem = "stars",
	PetCare = "petCare",
	BuyGoldShop = "goldShop",
	BuyBoost = "paid",
	BuyPrism = "paid",
	RollPaid = "paid",
	BuyInventoryExpansion = "paid",
}

local function guard(player: Player, action: string, callback: () -> any)
	-- typeof, not type. type(player) is "userdata", so a type() check
	-- rejects every real caller before the handler runs.
	local reported = typeof(player)
	local isPlayer = reported == "Instance" and player:IsA("Player")
	local accepted, why = RemoteCaller.accept(reported, isPlayer)
	if not accepted then
		return fail(action, why)
	end
	if not RateLimiter.take(player.UserId, action) then
		return fail(action, "Slow down a moment.")
	end
	local parked = PARKED_ACTION[action]
	if parked ~= nil and not LaunchGate.on(parked) then
		return fail(action, "That is closed.")
	end
	local ok, result = xpcall(callback, function(err)
		return debug.traceback(tostring(err), 2)
	end)
	if not ok then
		return fail(action, tostring(result))
	end
	return respond(player, action, result)
end

local function validUid(uid: any): boolean
	return type(uid) == "string"
		and #uid > 0
		and #uid <= 64
		and string.match(uid, "^[%w%-]+$") ~= nil
end

-- Phase 0.7 audit. A number from the client must be a real number:
-- NaN slips past both sides of a range check and inf floors to inf.
local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Companion uids are looked up, never parsed, so only the size is capped.
local function validKey(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64
end

-- Pet paint is saved as-is, so a color is a short plain id.
local function validColor(value: any): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= 32
		and string.match(value, "^[%w_]+$") ~= nil
end

function Remotes.bind()
	functionRemote("GetProfile").OnServerInvoke = function(player)
		return guard(player, "GetProfile", function()
			local data, loadError = DataService.waitFor(player, 15)
			if data == nil then
				if type(loadError) == "string" and loadError ~= "" then
					return { ok = false, error = loadError }
				end
				return { ok = false, error = "Profile is still loading." }
			end
			return { ok = true }
		end)
	end

	functionRemote("GetOdds").OnServerInvoke = function(player, poolId)
		return guard(player, "GetOdds", function()
			if type(poolId) ~= "string" then
				return { ok = false, error = "Unknown shard." }
			end
			local pool = Pools.get(poolId)
			if pool == nil or pool.public ~= true then
				return { ok = false, error = "Unknown shard." }
			end
			local data = DataService.get(player)
			local luck = RarityConfig.luckFromProfile(data)
			return {
				ok = true,
				odds = RarityConfig.disclose(pool, luck, if data ~= nil then data.sinceEpic else nil),
			}
		end)
	end

	functionRemote("RollShard").OnServerInvoke = function(player, poolId, skip)
		return guard(player, "RollShard", function()
			return RollService.rollFree(player, poolId, skip == true)
		end)
	end

	functionRemote("RollShards").OnServerInvoke = function(player, poolId, count)
		return guard(player, "RollShards", function()
			return RollService.rollMany(player, poolId, count)
		end)
	end

	functionRemote("BuyPrism").OnServerInvoke = function(player)
		return guard(player, "BuyPrism", function()
			return RollService.buyPrismPack(player)
		end)
	end

	functionRemote("BuyBoost").OnServerInvoke = function(player)
		return guard(player, "BuyBoost", function()
			return RollService.buyLuckBoost(player)
		end)
	end

	functionRemote("OpenChest").OnServerInvoke = function(player, tier, count)
		return guard(player, "OpenChest", function()
			if type(count) == "number" and not finite(count) then
				return { ok = false, error = "Pick how many chests to open." }
			end
			return ChestService.open(player, tier, count)
		end)
	end

	functionRemote("ChooseChest").OnServerInvoke = function(player, index)
		return guard(player, "ChooseChest", function()
			if not finite(index) then
				return { ok = false, error = "Pick one of the three cards." }
			end
			return ChestService.choose(player, index)
		end)
	end

	functionRemote("MergeChest").OnServerInvoke = function(player, tier)
		return guard(player, "MergeChest", function()
			return ChestService.merge(player, tier)
		end)
	end

	functionRemote("BuyChest").OnServerInvoke = function(player, tier)
		return guard(player, "BuyChest", function()
			return ChestService.buy(player, tier)
		end)
	end

	functionRemote("ClaimLogin").OnServerInvoke = function(player)
		return guard(player, "ClaimLogin", function()
			return ChestService.claimLogin(player)
		end)
	end

	functionRemote("BuyDustShard").OnServerInvoke = function(player, templateId)
		return guard(player, "BuyDustShard", function()
			return ChestService.buyDust(player, templateId)
		end)
	end

	functionRemote("BuyChestBundle").OnServerInvoke = function(player)
		return guard(player, "BuyChestBundle", function()
			return ChestService.buyBundle(player)
		end)
	end

	functionRemote("SetChestOptions").OnServerInvoke = function(player, mode, salvage)
		return guard(player, "SetChestOptions", function()
			return ChestService.setOptions(player, mode, salvage)
		end)
	end

	functionRemote("RollPaid").OnServerInvoke = function(player, poolId, skip)
		return guard(player, "RollPaid", function()
			return RollService.rollPaid(player, poolId, skip == true)
		end)
	end

	functionRemote("EquipItem").OnServerInvoke = function(player, uid)
		return guard(player, "EquipItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.equip(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("UnequipItem").OnServerInvoke = function(player, uid)
		return guard(player, "UnequipItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.unequip(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("RemoveItem").OnServerInvoke = function(player, uid)
		return guard(player, "RemoveItem", function()
			if not validUid(uid) then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err, removedName = InventoryService.remove(player, uid)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true, removedName = removedName }
		end)
	end

	functionRemote("Debug").OnServerInvoke = function(player, action)
		return guard(player, "Debug", function()
			-- Owner only (Oct 22). DebugService checks again.
			if not DevAccess.player(player) then
				return { ok = false, error = DevAccess.DENIED }
			end
			return DebugService.run(player, action)
		end)
	end

	functionRemote("DevGrant").OnServerInvoke = function(player, kind)
		return guard(player, "DevGrant", function()
			if type(kind) ~= "string" then
				return { ok = false, error = "Unknown dev grant." }
			end
			-- Owner only (Oct 22). RollService.devGrant checks again.
			if not DevAccess.player(player) then
				return { ok = false, error = DevAccess.DENIED }
			end
			return RollService.devGrant(player, kind)
		end)
	end

	functionRemote("Dungeon").OnServerInvoke = function(player, action, dungeonId, extra)
		return guard(player, "Dungeon", function()
			if type(action) ~= "string" then
				return { ok = false, error = "Unknown dungeon action." }
			end
			if action == "enter" and not LaunchGate.dungeonOpen(dungeonId) then
				return { ok = false, error = "That is closed." }
			end
			return DungeonService.action(player, action, dungeonId, extra)
		end)
	end

	functionRemote("Craft").OnServerInvoke = function(player, recipeId, targetUid)
		return guard(player, "Craft", function()
			if targetUid ~= nil and not validUid(targetUid) then
				return { ok = false, error = "You do not have that item." }
			end
			if type(recipeId) == "string" then
				local recipe = Recipes.get(recipeId)
				if recipe ~= nil and type(recipe.result) == "table" then
					local kind = recipe.result.kind
					local closed = (kind == "reroll" and not LaunchGate.on("forgeReroll"))
						or (kind ~= "reroll" and not LaunchGate.on("forgeCraft"))
					if closed then
						return { ok = false, error = "That is closed." }
					end
				end
			end
			return CraftService.craft(player, recipeId, targetUid)
		end)
	end

	functionRemote("Salvage").OnServerInvoke = function(player, targetUid)
		return guard(player, "Salvage", function()
			if not validUid(targetUid) then
				return { ok = false, error = "You do not have that item." }
			end
			return CraftService.salvage(player, targetUid)
		end)
	end

	functionRemote("BuyForgeBoost").OnServerInvoke = function(player)
		return guard(player, "BuyForgeBoost", function()
			return RollService.buyForgeBoost(player)
		end)
	end

	functionRemote("BuyGoldShop").OnServerInvoke = function(player, offerId)
		return guard(player, "BuyGoldShop", function()
			local reason: string? = nil
			local price = 0
			local balance = 0
			local saved, err = DataService.mutate(player, function(data)
				local before = if type(data) == "table" and type(data.gold) == "number" then data.gold else 0
				reason = GoldShop.apply(data, offerId)
				-- [ECHO hook] Record the spend. The event fires after the mutate returns.
				if reason == nil and type(data) == "table" and type(data.gold) == "number" then
					price = before - data.gold
					balance = data.gold
				end
				return reason
			end)
			if not saved then
				local message = if type(reason) == "string" then reason else err
				if type(message) ~= "string" or message == "" then
					message = "Could not buy that."
				end
				return { ok = false, error = message }
			end
			-- [ECHO hook] After the mutate. A zero price is not sent.
			if price >= 1 then
				local tracked, hookErr = pcall(function()
					require(script.Parent.AnalyticsService).economy(
						player,
						"sink",
						"gold",
						price,
						balance,
						"gold_shop"
					)
				end)
				if not tracked then
					warn("[Shardfall] analytics hook: " .. tostring(hookErr))
				end
			end
			return { ok = true }
		end)
	end

	functionRemote("BuyInventoryExpansion").OnServerInvoke = function(player)
		return guard(player, "BuyInventoryExpansion", function()
			return RollService.buyInventoryExpansion(player)
		end)
	end

	functionRemote("Travel").OnServerInvoke = function(player, destinationId)
		return guard(player, "Travel", function()
			if type(destinationId) ~= "string" then
				return { ok = false, error = "Unknown destination." }
			end
			local ok, err = TravelService.go(player, destinationId)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("BuyTravelPass").OnServerInvoke = function(player)
		return guard(player, "BuyTravelPass", function()
			return TravelService.buyPass(player)
		end)
	end

	functionRemote("SetShake").OnServerInvoke = function(player, enabled)
		return guard(player, "SetShake", function()
			if type(enabled) ~= "boolean" then
				return { ok = false, error = "Shake must be on or off." }
			end
			return RollService.setShake(player, enabled)
		end)
	end

	functionRemote("SetAudio").OnServerInvoke = function(player, music, sfx)
		return guard(player, "SetAudio", function()
			if tonumber(music) == nil or tonumber(sfx) == nil then
				return { ok = false, error = "Volume needs a number." }
			end
			if (tonumber(music) :: number) < 0 or (tonumber(sfx) :: number) < 0 then
				return { ok = false, error = "Volume cannot be negative." }
			end
			local ok, err = DataService.mutate(player, function(data)
				data.musicVolume = Audio.clampVolume(music)
				data.sfxVolume = Audio.clampVolume(sfx)
				return nil
			end)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("SetSettings").OnServerInvoke = function(player, patch)
		return guard(player, "SetSettings", function()
			if type(patch) ~= "table" then
				return { ok = false, error = "Settings need a table." }
			end
			local nextSettings = Settings.normalize(patch)
			local ok, err = DataService.mutate(player, function(data)
				data.uiSettings = nextSettings
				local quality = nextSettings.graphics.quality
				data.graphicsQuality = if quality == "auto" then "" else quality
				if Quality.normalize(data.graphicsQuality) == nil then
					data.graphicsQuality = ""
				end
				data.shake = nextSettings.camera.shake
				data.musicVolume = nextSettings.audio.music
				data.sfxVolume = nextSettings.audio.sfx
				return nil
			end)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("SetGraphicsQuality").OnServerInvoke = function(player, tier)
		return guard(player, "SetGraphicsQuality", function()
			local id = Quality.normalize(tier)
			if id == nil then
				return { ok = false, error = "Unknown graphics quality." }
			end
			local ok, err = DataService.mutate(player, function(data)
				data.graphicsQuality = id
				return nil
			end)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true, graphicsQuality = id }
		end)
	end

	functionRemote("SetItemLock").OnServerInvoke = function(player, uid, locked)
		return guard(player, "SetItemLock", function()
			if not validUid(uid) or type(locked) ~= "boolean" then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.setFlag(player, uid, "locked", locked)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("SetItemFavorite").OnServerInvoke = function(player, uid, favorite)
		return guard(player, "SetItemFavorite", function()
			if not validUid(uid) or type(favorite) ~= "boolean" then
				return { ok = false, error = "You do not have that item." }
			end
			local ok, err = InventoryService.setFlag(player, uid, "favorite", favorite)
			if not ok then
				return { ok = false, error = err }
			end
			return { ok = true }
		end)
	end

	functionRemote("BulkSalvage").OnServerInvoke = function(player, rarity)
		return guard(player, "BulkSalvage", function()
			if type(rarity) ~= "string" or Rarities.INDEX[rarity] == nil then
				return { ok = false, error = "Unknown rarity." }
			end
			return CraftService.salvageRarity(player, rarity)
		end)
	end

	functionRemote("FeedItem").OnServerInvoke = function(player, keptUid, feederUid)
		return guard(player, "FeedItem", function()
			if not validUid(keptUid) or not validUid(feederUid) then
				return { ok = false, error = "You do not have that item." }
			end
			return InventoryService.feed(player, keptUid, feederUid)
		end)
	end

	functionRemote("SetAutoFarm").OnServerInvoke = function(player, enabled)
		return guard(player, "SetAutoFarm", function()
			if type(enabled) ~= "boolean" then
				return { ok = false, error = "Auto farm needs on or off." }
			end
			DungeonService.setAutoFarm(player, enabled)
			return { ok = true, autoFarm = enabled }
		end)
	end

	functionRemote("SetAutoAttack").OnServerInvoke = function(player, enabled)
		return guard(player, "SetAutoAttack", function()
			if type(enabled) ~= "boolean" then
				return { ok = false, error = "Auto attack needs on or off." }
			end
			CombatService.setAutoAttack(player, enabled)
			return { ok = true, autoAttack = enabled }
		end)
	end

	functionRemote("UseTonic").OnServerInvoke = function(player)
		return guard(player, "UseTonic", function()
			return ActionBarService.drink(player)
		end)
	end

	functionRemote("SetActionBar").OnServerInvoke = function(player, classId, slots, locked)
		return guard(player, "SetActionBar", function()
			return ActionBarService.set(player, classId, slots, locked)
		end)
	end

	functionRemote("UseActionSlot").OnServerInvoke = function(player, index)
		return guard(player, "UseActionSlot", function()
			if not finite(index) then
				return { ok = false, error = "That slot is empty." }
			end
			return ActionBarService.use(player, index)
		end)
	end

	-- A swing is an event, not a function: the player should not wait on a
	-- round trip before the next click. Cooldown still lives on the server.
	eventRemote("Attack").OnServerEvent:Connect(function(player, lookX, lookY, lookZ, charged)
		local reported = typeof(player)
		local isPlayer = reported == "Instance" and player:IsA("Player")
		local accepted, why = RemoteCaller.accept(reported, isPlayer)
		if not accepted then
			warn("[Shardfall] Attack:", why)
			return
		end
		if not RateLimiter.take(player.UserId, "Attack") then
			return
		end
		local ok, err = xpcall(function()
			if charged == "begin" then
				CombatService.beginCharge(player)
				return
			end
			CombatService.attack(player, lookX, lookY, lookZ)
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		if not ok then
			warn("[Shardfall] Attack:", err)
		end
	end)

	functionRemote("HatchPet").OnServerInvoke = function(player)
		return guard(player, "HatchPet", function()
			return PetService.hatch(player)
		end)
	end
	functionRemote("PetCare").OnServerInvoke = function(player, uid, kind)
		return guard(player, "PetCare", function()
			if not validKey(uid) then
				return { ok = false, error = "Pet or feed a companion." }
			end
			return PetService.care(player, uid, kind)
		end)
	end
	functionRemote("FusePet").OnServerInvoke = function(player, keepUid, feedUid)
		return guard(player, "FusePet", function()
			return PetService.fuse(player, keepUid, feedUid)
		end)
	end
	functionRemote("PaintPet").OnServerInvoke = function(player, uid, primary, secondary, glow)
		return guard(player, "PaintPet", function()
			if not validKey(uid) or not validColor(primary) then
				return { ok = false, error = "Pick a color." }
			end
			if
				(type(secondary) == "string" and not validColor(secondary))
				or (type(glow) == "string" and not validColor(glow))
			then
				return { ok = false, error = "Pick a color." }
			end
			return PetService.paint(player, uid, primary, secondary, glow)
		end)
	end
	functionRemote("FavoritePet").OnServerInvoke = function(player, uid, locked)
		return guard(player, "FavoritePet", function()
			if not validKey(uid) then
				return { ok = false, error = "Pick a companion." }
			end
			return PetService.favorite(player, uid, locked)
		end)
	end
	functionRemote("Trade").OnServerInvoke = function(player, action, payload)
		return guard(player, "Trade", function()
			if type(action) ~= "string" then
				return { ok = false, error = "Unknown trade action." }
			end
			return TradeService.handle(player, action, payload)
		end)
	end
	functionRemote("Market").OnServerInvoke = function(player, action, payload)
		return guard(player, "Market", function()
			if type(action) ~= "string" then
				return { ok = false, error = "Unknown market action." }
			end
			return MarketService.handle(player, action, payload)
		end)
	end
	functionRemote("Loops").OnServerInvoke = function(player)
		return guard(player, "Loops", function()
			local result = LoopService.refresh(player)
			if type(result) == "table" and not LaunchGate.on("leaderboards") then
				result.leaderboard = nil
			end
			return result
		end)
	end
	functionRemote("RerollDaily").OnServerInvoke = function(player, index)
		return guard(player, "RerollDaily", function()
			if not finite(index) then
				return { ok = false, error = "Pick a daily." }
			end
			return LoopService.reroll(player, index)
		end)
	end
	functionRemote("ClaimPass").OnServerInvoke = function(player)
		return guard(player, "ClaimPass", function()
			return LoopService.claim(player)
		end)
	end
	functionRemote("PremiumPass").OnServerInvoke = function(player)
		return guard(player, "PremiumPass", function()
			return LoopService.premium()
		end)
	end
	functionRemote("StartDailyBoss").OnServerInvoke = function(player)
		return guard(player, "StartDailyBoss", function()
			return DungeonService.startDailyBoss(player)
		end)
	end
	functionRemote("RaidQueue").OnServerInvoke = function(player, difficulty, role)
		return guard(player, "RaidQueue", function()
			return RaidService.queue(player, difficulty, role)
		end)
	end
	functionRemote("RaidPost").OnServerInvoke = function(player, tag, difficulty)
		return guard(player, "RaidPost", function()
			return RaidService.post(player, tag, difficulty)
		end)
	end
	functionRemote("RaidJoin").OnServerInvoke = function(player, listingId)
		return guard(player, "RaidJoin", function()
			return RaidService.join(player, listingId)
		end)
	end
	functionRemote("RaidPractice").OnServerInvoke = function(player, wing, phase)
		return guard(player, "RaidPractice", function()
			return RaidService.practice(player, wing, phase)
		end)
	end
	functionRemote("RaidBuy").OnServerInvoke = function(player, itemId)
		return guard(player, "RaidBuy", function()
			return RaidService.buy(player, itemId)
		end)
	end
	functionRemote("RaidLeave").OnServerInvoke = function(player)
		return guard(player, "RaidLeave", function()
			return RaidService.leave(player)
		end)
	end
	functionRemote("RaidReady").OnServerInvoke = function(player)
		return guard(player, "RaidReady", function()
			return RaidService.ready(player)
		end)
	end

	functionRemote("UpgradeGear").OnServerInvoke = function(player, uid)
		return guard(player, "UpgradeGear", function()
			if not validUid(uid) then
				return { ok = false, error = "Pick a piece of gear." }
			end
			return CraftService.upgrade(player, uid)
		end)
	end

	functionRemote("Onboard").OnServerInvoke = function(player, action)
		return guard(player, "Onboard", function()
			if action == "skip" then
				return OnboardingService.skip(player)
			end
			return OnboardingService.advance(player)
		end)
	end

	functionRemote("SetClass").OnServerInvoke = function(player, classId)
		return guard(player, "SetClass", function()
			return ClassService.select(player, classId)
		end)
	end

	functionRemote("PickTalent").OnServerInvoke = function(player, talentId)
		return guard(player, "PickTalent", function()
			return ClassService.pickTalent(player, talentId)
		end)
	end

	functionRemote("UseSkill").OnServerInvoke = function(player, slot)
		return guard(player, "UseSkill", function()
			if type(slot) == "number" and not finite(slot) then
				return { ok = false, error = "That skill slot is empty." }
			end
			return ClassService.cast(player, slot)
		end)
	end

	eventRemote("Dodge").OnServerEvent:Connect(function(player)
		local reported = typeof(player)
		local isPlayer = reported == "Instance" and player:IsA("Player")
		local accepted, why = RemoteCaller.accept(reported, isPlayer)
		if not accepted then
			warn("[Shardfall] Dodge:", why)
			return
		end
		if not RateLimiter.take(player.UserId, "Dodge") then
			return
		end
		local ok, err = xpcall(function()
			CombatService.dodge(player)
		end, function(message)
			return debug.traceback(tostring(message), 2)
		end)
		if not ok then
			warn("[Shardfall] Dodge:", err)
		end
	end)

	eventRemote("Steer").OnServerEvent:Connect(function(player, moving)
		local reported = typeof(player)
		local isPlayer = reported == "Instance" and player:IsA("Player")
		local accepted, why = RemoteCaller.accept(reported, isPlayer)
		if not accepted then
			warn("[Shardfall] Steer:", why)
			return
		end
		if type(moving) ~= "boolean" then
			return
		end
		if not RateLimiter.take(player.UserId, "Steer") then
			return
		end
		CombatService.setSteering(player, moving)
	end)

	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.forget(player.UserId)
	end)
end

return Remotes
