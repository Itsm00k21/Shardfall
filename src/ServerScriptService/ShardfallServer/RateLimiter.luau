--!strict

--[[
	Per-player token buckets for remotes.

	Each action has a capacity (a burst) and a refill rate. take() returns
	false when the bucket is empty so the remote can ignore the request
	instead of doing the work. This is not security by itself — every remote
	still checks ownership and currency — it just stops a client loop from
	spamming DataStore-adjacent work.

	Forget a player when they leave so the table does not grow forever.
]]

local RateLimiter = {}

type Rule = {
	capacity: number,
	perSecond: number,
}

type Bucket = {
	tokens: number,
	updated: number,
}

local RULES: { [string]: Rule } = {
	-- The shard reel's real gate is RollService's 0.6s / 1.0s clock.
	-- This bucket only stops a burst from outrunning that clock.
	RollShard = { capacity = 4, perSecond = 2 },
	RollPaid = { capacity = 2, perSecond = 0.5 },
	OpenChest = { capacity = 4, perSecond = 2 },
	ChooseChest = { capacity = 4, perSecond = 1 },
	MergeChest = { capacity = 3, perSecond = 1 },
	BuyChest = { capacity = 4, perSecond = 1 },
	ClaimLogin = { capacity = 2, perSecond = 0.2 },
	BuyDustShard = { capacity = 4, perSecond = 1 },
	BuyChestBundle = { capacity = 2, perSecond = 0.5 },
	SetChestOptions = { capacity = 4, perSecond = 1 },
	BuyPrism = { capacity = 2, perSecond = 0.5 },
	BuyBoost = { capacity = 2, perSecond = 0.5 },
	EquipItem = { capacity = 6, perSecond = 3 },
	UnequipItem = { capacity = 6, perSecond = 3 },
	RemoveItem = { capacity = 4, perSecond = 2 },
	GetProfile = { capacity = 4, perSecond = 1 },
	GetOdds = { capacity = 4, perSecond = 1 },
	DevGrant = { capacity = 4, perSecond = 2 },
	-- Attacks are limited by weapon cooldown too. This only stops a flood.
	Attack = { capacity = 8, perSecond = 6 },
	Dodge = { capacity = 6, perSecond = 3 },
	SetClass = { capacity = 4, perSecond = 1 },
	PickTalent = { capacity = 4, perSecond = 1 },
	UseSkill = { capacity = 6, perSecond = 3 },
	Onboard = { capacity = 4, perSecond = 1 },
	UpgradeGear = { capacity = 4, perSecond = 1 },
	HatchPet = { capacity = 4, perSecond = 1 },
	PetCare = { capacity = 6, perSecond = 2 },
	FusePet = { capacity = 3, perSecond = 1 },
	PaintPet = { capacity = 4, perSecond = 1 },
	FavoritePet = { capacity = 4, perSecond = 1 },
	Loops = { capacity = 4, perSecond = 1 },
	RerollDaily = { capacity = 3, perSecond = 0.5 },
	ClaimPass = { capacity = 4, perSecond = 1 },
	PremiumPass = { capacity = 2, perSecond = 0.5 },
	StartDailyBoss = { capacity = 2, perSecond = 0.3 },
	Dungeon = { capacity = 4, perSecond = 1 },
	Craft = { capacity = 4, perSecond = 1 },
	Salvage = { capacity = 4, perSecond = 1 },
	BulkSalvage = { capacity = 2, perSecond = 0.5 },
	BuyForgeBoost = { capacity = 2, perSecond = 0.5 },
	BuyInventoryExpansion = { capacity = 2, perSecond = 0.5 },
	Travel = { capacity = 4, perSecond = 1 },
	BuyTravelPass = { capacity = 2, perSecond = 0.5 },
	SetGraphicsQuality = { capacity = 4, perSecond = 1 },
	SetAudio = { capacity = 4, perSecond = 2 },
	SetItemLock = { capacity = 6, perSecond = 3 },
	SetItemFavorite = { capacity = 6, perSecond = 3 },
	UseTonic = { capacity = 3, perSecond = 1 },
	FeedItem = { capacity = 4, perSecond = 2 },
	SetAutoAttack = { capacity = 4, perSecond = 1 },
	SetAutoFarm = { capacity = 4, perSecond = 1 },
	SetShake = { capacity = 4, perSecond = 1 },
	-- Refreshed while the player is holding a move key.
	Steer = { capacity = 8, perSecond = 4 },
}

local buckets: { [string]: Bucket } = {}

function RateLimiter.take(userId: number, action: string): boolean
	local rule = RULES[action]
	if rule == nil then
		return false
	end
	local now = os.clock()
	local key = tostring(userId) .. ":" .. action
	local bucket = buckets[key]
	if bucket == nil then
		bucket = { tokens = rule.capacity, updated = now }
		buckets[key] = bucket
	end
	local elapsed = math.max(0, now - bucket.updated)
	bucket.tokens = math.min(rule.capacity, bucket.tokens + elapsed * rule.perSecond)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter.forget(userId: number)
	local prefix = tostring(userId) .. ":"
	for key in pairs(buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			buckets[key] = nil
		end
	end
end

return RateLimiter
