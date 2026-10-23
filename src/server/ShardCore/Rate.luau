--!strict

--[[
	Per-player token buckets for the Shard Core remotes.

	A remote with no rule is refused. Forget a player when they leave.
]]

local Rate = {}

export type Rule = {
	capacity: number,
	perSecond: number,
}

export type Bucket = {
	tokens: number,
	updated: number,
}

function Rate.take(
	buckets: { [string]: Bucket },
	userId: any,
	action: string,
	now: any,
	rule: Rule?
): boolean
	if rule == nil or type(userId) ~= "number" or type(action) ~= "string" then
		return false
	end
	if type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then
		return false
	end
	local key = tostring(userId) .. ":" .. action
	local bucket = buckets[key]
	if bucket == nil then
		bucket = { tokens = rule.capacity, updated = now }
		buckets[key] = bucket
	end
	local elapsed = now - bucket.updated
	if elapsed < 0 then
		elapsed = 0
	end
	bucket.tokens = math.min(rule.capacity, bucket.tokens + elapsed * rule.perSecond)
	bucket.updated = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Rate.forget(buckets: { [string]: Bucket }, userId: any)
	if type(userId) ~= "number" then
		return
	end
	local prefix = tostring(userId) .. ":"
	local drop = {}
	for key in pairs(buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			table.insert(drop, key)
		end
	end
	for _, key in ipairs(drop) do
		buckets[key] = nil
	end
end

return Rate
