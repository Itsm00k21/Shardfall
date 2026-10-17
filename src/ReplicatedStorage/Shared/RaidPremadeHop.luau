--!strict

--[[
	Pure rules for hopping a ready premade party.

	The plaza reserves one server and sends the seated party together.
	One failed member rolls the whole party back. Three tries, then stop.
	Studio stays on the local entry path. Hard and Shardbreaker do not hop.
	This module does not teleport. It does not read a client host id.
	Nothing here spends Robux.
]]

local RaidPremadeHop = {}

RaidPremadeHop.CONFIG = {
	tries = 3,
	partyMin = 4,
	partyMax = 8,
	waitSeconds = 15,
}

RaidPremadeHop.ERRORS = {
	seated = "The raid teleport failed. The party is still seated.",
	capped = "The raid teleport failed too many times. The party is still seated.",
	closed = "Party is ready. Hard and Shardbreaker stay closed.",
	server = "The raid server did not open. The party is still seated.",
	save = "Could not save the party, so the raid teleport was cancelled. The party is still seated.",
	hold = "A teleport is already in progress. The party is still seated.",
	run = "Leave your current run before the ready check.",
}

local ROLES = {
	tank = true,
	healer = true,
	dps = true,
	flex = true,
}

local BANNED = {
	"host",
	"hostUserId",
	"listingId",
	"userId",
	"UserId",
	"playerId",
	"PlayerId",
	"guildId",
	"GuildId",
	"productId",
	"robux",
	"cost",
	"skip",
}

export type Bucket = {
	token: string,
	difficulty: string,
	partySize: number,
	homeJobId: string,
	healer: boolean,
	roles: { [string]: string },
	seen: { [number]: boolean },
	count: number,
}

local function wholeId(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value <= 0 or value ~= math.floor(value) then
		return nil
	end
	return value
end

local function safeToken(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	if #value < 8 or #value > 64 then
		return nil
	end
	if string.match(value, "^[%w%-]+$") == nil then
		return nil
	end
	return value
end

local function safeJob(value: any): string?
	if type(value) ~= "string" or value == "" or #value > 100 then
		return nil
	end
	if string.find(value, "%c") ~= nil then
		return nil
	end
	return value
end

local function banned(source: any): boolean
	if type(source) ~= "table" then
		return true
	end
	for _, key in ipairs(BANNED) do
		if source[key] ~= nil then
			return true
		end
	end
	return false
end

function RaidPremadeHop.route(isStudio: boolean, difficulty: any): string
	if difficulty ~= "story" and difficulty ~= "normal" then
		return "closed"
	end
	if isStudio == true then
		return "local"
	end
	return "reserve"
end

-- `tries` is how many hops already failed. Under the cap, spend one.
function RaidPremadeHop.spend(tries: any): (number?, string)
	local count = 0
	if tries ~= nil then
		if type(tries) ~= "number" or tries ~= tries or tries < 0 or tries ~= math.floor(tries) then
			return nil, "capped"
		end
		count = tries
	end
	if count >= RaidPremadeHop.CONFIG.tries then
		return count, "capped"
	end
	return count + 1, "go"
end

-- Every seated member must be "ok". One failure, or nobody, rolls back.
function RaidPremadeHop.together(results: any): string
	if type(results) ~= "table" or #results == 0 then
		return "rollback"
	end
	for _, result in ipairs(results) do
		if result ~= "ok" then
			return "rollback"
		end
	end
	return "teleported"
end

function RaidPremadeHop.roleFor(roles: any, userId: any): string
	local id = wholeId(userId)
	if id == nil or type(roles) ~= "table" then
		return "flex"
	end
	local role = roles[tostring(id)]
	if type(role) == "string" and ROLES[role] == true then
		return role
	end
	return "flex"
end

function RaidPremadeHop.pack(draft: any): ({ [string]: any }?, string?)
	if type(draft) ~= "table" or banned(draft) then
		return nil, "That listing is unusable."
	end
	if draft.difficulty ~= "story" and draft.difficulty ~= "normal" then
		return nil, RaidPremadeHop.ERRORS.closed
	end
	local token = safeToken(draft.token)
	local home = safeJob(draft.homeJobId)
	if token == nil or home == nil or type(draft.healer) ~= "boolean" then
		return nil, "That listing is unusable."
	end
	if type(draft.members) ~= "table" then
		return nil, "That listing is unusable."
	end
	local roles: { [string]: string } = {}
	local seen: { [number]: boolean } = {}
	local count = 0
	for _, member in ipairs(draft.members) do
		if type(member) ~= "table" then
			return nil, "That listing is unusable."
		end
		local userId = wholeId(member.userId)
		local role = member.role
		if userId == nil or seen[userId] == true then
			return nil, "That listing is unusable."
		end
		if type(role) ~= "string" or ROLES[role] ~= true then
			return nil, "That listing is unusable."
		end
		seen[userId] = true
		roles[tostring(userId)] = role
		count += 1
	end
	local minSize = RaidPremadeHop.CONFIG.partyMin
	local maxSize = RaidPremadeHop.CONFIG.partyMax
	if count < minSize or count > maxSize then
		return nil, "That listing is unusable."
	end
	return {
		raid = "heartwood",
		difficulty = draft.difficulty,
		premade = true,
		partySize = count,
		token = token,
		homeJobId = home,
		healer = draft.healer,
		roles = roles,
	},
		nil
end

local function copyBucket(bucket: any): Bucket?
	if type(bucket) ~= "table" then
		return nil
	end
	local token = safeToken(bucket.token)
	local home = safeJob(bucket.homeJobId)
	local size = wholeId(bucket.partySize)
	if token == nil or home == nil or size == nil or type(bucket.healer) ~= "boolean" then
		return nil
	end
	if bucket.difficulty ~= "story" and bucket.difficulty ~= "normal" then
		return nil
	end
	local roles: { [string]: string } = {}
	if type(bucket.roles) == "table" then
		local roleCount = 0
		for key, role in pairs(bucket.roles) do
			roleCount += 1
			if roleCount > RaidPremadeHop.CONFIG.partyMax then
				return nil
			end
			if type(key) == "string" and type(role) == "string" and ROLES[role] == true then
				roles[key] = role
			end
		end
	end
	local seen: { [number]: boolean } = {}
	local count = 0
	if type(bucket.seen) == "table" then
		for id, flag in pairs(bucket.seen) do
			if type(id) == "number" and flag == true then
				seen[id] = true
				count += 1
			end
		end
	end
	return {
		token = token,
		difficulty = bucket.difficulty,
		partySize = size,
		homeJobId = home,
		healer = bucket.healer,
		roles = roles,
		seen = seen,
		count = count,
	}
end

function RaidPremadeHop.admit(bucket: any, userId: any, data: any): (Bucket?, string)
	local id = wholeId(userId)
	if id == nil or type(data) ~= "table" or banned(data) then
		return nil, "refuse"
	end
	if data.premade ~= true or data.raid ~= "heartwood" then
		return nil, "refuse"
	end
	if data.difficulty ~= "story" and data.difficulty ~= "normal" then
		return nil, "refuse"
	end
	local token = safeToken(data.token)
	local home = safeJob(data.homeJobId)
	local size = wholeId(data.partySize)
	if token == nil or home == nil or size == nil or type(data.healer) ~= "boolean" then
		return nil, "refuse"
	end
	if size < RaidPremadeHop.CONFIG.partyMin or size > RaidPremadeHop.CONFIG.partyMax then
		return nil, "refuse"
	end
	if type(data.roles) ~= "table" then
		return nil, "refuse"
	end
	local role = data.roles[tostring(id)]
	if type(role) ~= "string" or ROLES[role] ~= true then
		return nil, "refuse"
	end

	local nextBucket: Bucket
	if bucket == nil then
		local roles: { [string]: string } = {}
		local roleCount = 0
		for key, named in pairs(data.roles) do
			roleCount += 1
			if roleCount > RaidPremadeHop.CONFIG.partyMax then
				return nil, "refuse"
			end
			if type(key) == "string" and type(named) == "string" and ROLES[named] == true then
				roles[key] = named
			end
		end
		nextBucket = {
			token = token,
			difficulty = data.difficulty,
			partySize = size,
			homeJobId = home,
			healer = data.healer,
			roles = roles,
			seen = {},
			count = 0,
		}
	else
		local copied = copyBucket(bucket)
		if copied == nil or copied.token ~= token or copied.difficulty ~= data.difficulty then
			return nil, "refuse"
		end
		if copied.partySize ~= size or copied.homeJobId ~= home or copied.healer ~= data.healer then
			return nil, "refuse"
		end
		nextBucket = copied
	end
	if nextBucket.seen[id] ~= true then
		nextBucket.seen[id] = true
		nextBucket.count += 1
	end
	if nextBucket.count > nextBucket.partySize then
		return nil, "refuse"
	end
	if nextBucket.count == nextBucket.partySize then
		return nextBucket, "ready"
	end
	return nextBucket, "wait"
end

function RaidPremadeHop.drop(bucket: any, userId: any): (Bucket?, string)
	local id = wholeId(userId)
	local copied = copyBucket(bucket)
	if id == nil or copied == nil then
		return nil, "empty"
	end
	if copied.seen[id] == true then
		copied.seen[id] = nil
		copied.count -= 1
	end
	if copied.count <= 0 then
		return nil, "empty"
	end
	return copied, "wait"
end

function RaidPremadeHop.ids(bucket: any): { number }
	local list = {}
	local copied = copyBucket(bucket)
	if copied == nil then
		return list
	end
	for id, flag in pairs(copied.seen) do
		if flag == true then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

return RaidPremadeHop
