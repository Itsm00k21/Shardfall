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
	RollShard = { capacity = 3, perSecond = 1 },
	RollPaid = { capacity = 2, perSecond = 0.5 },
	EquipItem = { capacity = 6, perSecond = 3 },
	UnequipItem = { capacity = 6, perSecond = 3 },
	RemoveItem = { capacity = 4, perSecond = 2 },
	GetProfile = { capacity = 4, perSecond = 1 },
	GetOdds = { capacity = 4, perSecond = 1 },
	DevGrant = { capacity = 4, perSecond = 2 },
	-- Attacks are limited by weapon cooldown too. This only stops a flood.
	Attack = { capacity = 8, perSecond = 6 },
	Dungeon = { capacity = 4, perSecond = 1 },
	Craft = { capacity = 4, perSecond = 1 },
	UseTonic = { capacity = 3, perSecond = 1 },
	FeedItem = { capacity = 4, perSecond = 2 },
	SetAutoAttack = { capacity = 4, perSecond = 1 },
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
