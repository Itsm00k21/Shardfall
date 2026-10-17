--!strict

--[[
	Codex teaching cues. Pure rules.

	The server names the moment from facts it already has. The client
	paints that snapshot. It does not send `seen`, a user id, or a guild
	id, and this module does not unlock a Codex row.

	skills glows the skill button while a pack of three is alive.
	telegraphs is a color icon over a boss who is showing red or blue
	alone. shards glows an open socket when a loose shard can go in.
	crafting is an arrow to the Forge while the Haven ask is up.
	dodge pulses the dodge button during a server-owned red telegraph.

	The dodge hint is "Dodge!" and nothing after it. The other four
	cues have no sentence.
]]

local Recipes = require("./Recipes")
local UiTheme = require("./UiTheme")

local CodexCues = {}

CodexCues.HINT = "Dodge!"
CodexCues.SKILL_PACK = 3
CodexCues.KIND = "codex"

-- Light marks on the dark bar. HUD text should clear 4.5.
CodexCues.COLOR = table.freeze({
	skill = { 255, 206, 96 },
	skillInk = { 18, 16, 28 },
	dodge = { 255, 248, 230 },
	dodgeInk = { 28, 24, 40 },
	dodgePulse = { 255, 214, 206 },
	socket = { 255, 206, 96 },
	socketInk = { 40, 34, 58 },
	iconText = { 255, 248, 236 },
	iconInk = { 16, 14, 24 },
	arrow = { 255, 206, 96 },
	red = { 220, 64, 56 },
	blue = { 80, 150, 230 },
})

local HINT = CodexCues.HINT
local KIND = CodexCues.KIND
local PACK = CodexCues.SKILL_PACK

local SOURCE_KEYS = {
	profile = true,
	inHaven = true,
	now = true,
	enemies = true,
}

local FACT_KEYS = {
	now = true,
	enemies = true,
	openSockets = true,
	looseShards = true,
	forgeAsk = true,
}

local ENEMY_KEYS = {
	alive = true,
	boss = true,
	color = true,
	untilAt = true,
	x = true,
	y = true,
	z = true,
}

local EVENT_KEYS = {
	kind = true,
	dodge = true,
	skills = true,
	shards = true,
	crafting = true,
	icon = true,
	hint = true,
	x = true,
	y = true,
	z = true,
}

local CLOSED = {
	seen = true,
	userId = true,
	UserId = true,
	playerId = true,
	PlayerId = true,
	guildId = true,
	GuildId = true,
	productId = true,
	robux = true,
	cost = true,
	skip = true,
	paid = true,
}

local GEAR = {
	Weapon = true,
	Armor = true,
	Accessory = true,
}

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value >= math.huge or value <= -math.huge then
		return nil
	end
	return value
end

local function closedKey(key: any): boolean
	return type(key) == "string" and CLOSED[key] == true
end

local function onlyKeys(value: any, allowed: { [string]: boolean }): boolean
	if type(value) ~= "table" then
		return false
	end
	for key in pairs(value) do
		if type(key) ~= "string" or allowed[key] ~= true or closedKey(key) then
			return false
		end
	end
	return true
end

local function namedShard(value: any): boolean
	if type(value) ~= "string" or value == "" then
		return false
	end
	return string.find(string.lower(value), "shard", 1, true) ~= nil
end

local function openSockets(inventory: any): number
	if type(inventory) ~= "table" then
		return 0
	end
	local total = 0
	local walked = 0
	for _, item in pairs(inventory) do
		walked += 1
		if walked > 600 then
			break
		end
		if type(item) == "table" then
			local sockets = finite(item.sockets)
			if sockets ~= nil and sockets >= 1 then
				local whole = math.floor(sockets)
				if whole > 6 then
					whole = 6
				end
				total += whole
			end
		end
	end
	return total
end

local function looseItem(item: any): boolean
	if type(item) ~= "table" then
		return false
	end
	local sockets = finite(item.sockets)
	if sockets ~= nil and sockets >= 1 then
		return false
	end
	local kind = item.kind
	if type(kind) == "string" and string.lower(kind) == "shard" then
		return true
	end
	if namedShard(item.templateId) or namedShard(item.name) or namedShard(item.uid) then
		return true
	end
	if type(kind) == "string" and GEAR[kind] == true then
		local poolId = item.poolId
		if type(poolId) == "string" and poolId ~= "" and #poolId <= 64 then
			return true
		end
	end
	return false
end

local function looseShards(profile: any): number
	if type(profile) ~= "table" then
		return 0
	end
	local total = 0
	local inventory = profile.inventory
	if type(inventory) == "table" then
		local walked = 0
		for _, item in pairs(inventory) do
		walked += 1
		if walked > 600 then
			break
		end
		if looseItem(item) then
				total += 1
			end
		end
	end
	local materials = profile.materials
	if type(materials) == "table" then
		local walked = 0
		for id, count in pairs(materials) do
			walked += 1
			if walked > 80 then
				break
			end
			local amount = finite(count)
			if namedShard(id) and amount ~= nil and amount >= 1 then
				total += 1
			end
		end
	end
	return total
end

local function canCraft(profile: any): boolean
	if type(profile) ~= "table" then
		return false
	end
	local level = finite(profile.craftingLevel)
	local xp = finite(profile.craftingXp)
	if level == nil or xp == nil or xp ~= 0 or level > 1 then
		return false
	end
	local materials = profile.materials
	if type(materials) ~= "table" then
		return false
	end
	for _, recipe in ipairs(Recipes.all()) do
		if recipe.scroll == nil then
			local gate = recipe.level
			if gate == nil or level >= gate then
				local costs = recipe.costs
				local anyCost = false
				local covered = true
				if type(costs) == "table" then
					for id, cost in pairs(costs) do
						anyCost = true
						local have = materials[id]
						local need = finite(cost)
						local owned = finite(have)
						if need == nil or owned == nil or owned < need then
							covered = false
							break
						end
					end
				end
				if anyCost and covered then
					return true
				end
			end
		end
	end
	return false
end

local function forgeAsk(profile: any, inHaven: boolean): boolean
	if inHaven ~= true or type(profile) ~= "table" then
		return false
	end
	local session = profile.firstSession
	if type(session) == "table" and session.returning == true then
		return false
	end
	return canCraft(profile)
end

local function copyEnemies(rows: any): { any }?
	if type(rows) ~= "table" then
		return {}
	end
	local copied = {}
	local walked = 0
	for _, enemy in pairs(rows) do
		walked += 1
		if walked > 64 then
			break
		end
		if type(enemy) ~= "table" or not onlyKeys(enemy, ENEMY_KEYS) then
			return nil
		end
		local x = finite(enemy.x)
		local y = finite(enemy.y)
		local z = finite(enemy.z)
		local untilAt = finite(enemy.untilAt)
		table.insert(copied, {
			alive = enemy.alive == true,
			boss = enemy.boss == true,
			color = if type(enemy.color) == "string" then enemy.color else "",
			untilAt = if untilAt ~= nil then untilAt else 0,
			x = if x ~= nil then x else 0,
			y = if y ~= nil then y else 0,
			z = if z ~= nil then z else 0,
		})
	end
	return copied
end

local function blankEvent(): { [string]: any }
	return {
		kind = KIND,
		dodge = false,
		skills = false,
		shards = false,
		crafting = false,
		icon = "",
		hint = "",
		x = 0,
		y = 0,
		z = 0,
	}
end

local function signatureOf(event: { [string]: any }): string
	local function bit(value: any): string
		return if value == true then "1" else "0"
	end
	return table.concat({
		bit(event.dodge),
		bit(event.skills),
		bit(event.shards),
		bit(event.crafting),
		tostring(event.icon),
		tostring(event.hint),
		tostring(math.floor((event.x :: number) + 0.5)),
		tostring(math.floor((event.y :: number) + 0.5)),
		tostring(math.floor((event.z :: number) + 0.5)),
	}, "|")
end

function CodexCues.cleared(): { [string]: any }
	local event = blankEvent()
	return {
		ok = true,
		event = event,
		signature = signatureOf(event),
	}
end

-- Build the narrow fact table from a server profile and the live fight.
-- A closed key (seen, a user id, Robux) refuses the call.
function CodexCues.facts(source: any): { [string]: any }
	if type(source) ~= "table" or not onlyKeys(source, SOURCE_KEYS) then
		return { ok = false, error = "closed" }
	end
	if source.profile ~= nil and type(source.profile) ~= "table" then
		return { ok = false, error = "profile" }
	end
	if source.inHaven ~= nil and type(source.inHaven) ~= "boolean" then
		return { ok = false, error = "haven" }
	end
	local now = finite(source.now)
	if now == nil then
		return { ok = false, error = "now" }
	end
	local enemies = copyEnemies(source.enemies)
	if enemies == nil then
		return { ok = false, error = "enemy" }
	end
	local profile = source.profile
	local inHaven = source.inHaven == true
	return {
		ok = true,
		facts = {
			now = now,
			enemies = enemies,
			openSockets = openSockets(if type(profile) == "table" then profile.inventory else nil),
			looseShards = looseShards(profile),
			forgeAsk = forgeAsk(profile, inHaven),
		},
	}
end

local function active(enemy: any, now: number): boolean
	return enemy.alive == true and type(enemy.untilAt) == "number" and enemy.untilAt > now
end

-- Name the cues. The dodge hint is the constant, never a longer string.
function CodexCues.paint(facts: any): { [string]: any }
	if type(facts) ~= "table" or not onlyKeys(facts, FACT_KEYS) then
		return { ok = false, error = "closed" }
	end
	local now = finite(facts.now)
	if now == nil or type(facts.enemies) ~= "table" then
		return { ok = false, error = "fight" }
	end
	if type(facts.openSockets) ~= "number" or type(facts.looseShards) ~= "number" then
		return { ok = false, error = "sockets" }
	end
	if facts.forgeAsk ~= true and facts.forgeAsk ~= false then
		return { ok = false, error = "forge" }
	end
	local sockets = finite(facts.openSockets)
	local shards = finite(facts.looseShards)
	if sockets == nil or shards == nil or sockets < 0 or shards < 0 then
		return { ok = false, error = "sockets" }
	end

	local dodge = false
	local pack = 0
	local alive = 0
	local icon = ""
	local x, y, z = 0, 0, 0
	local lone: any = nil
	for _, enemy in ipairs(facts.enemies) do
		if type(enemy) ~= "table" or not onlyKeys(enemy, ENEMY_KEYS) then
			return { ok = false, error = "enemy" }
		end
		if enemy.alive == true then
			alive += 1
			lone = enemy
			if enemy.boss ~= true then
				pack += 1
			end
			if active(enemy, now) and enemy.color == "red" then
				dodge = true
			end
		end
	end
	if alive == 1 and type(lone) == "table" and lone.boss == true and active(lone, now) then
		if lone.color == "red" or lone.color == "blue" then
			local px = finite(lone.x)
			local py = finite(lone.y)
			local pz = finite(lone.z)
			if px ~= nil and py ~= nil and pz ~= nil then
				icon = lone.color
				x, y, z = px, py, pz
			end
		end
	end

	local event = blankEvent()
	event.dodge = dodge
	event.skills = pack >= PACK
	event.shards = sockets >= 1 and shards >= 1
	event.crafting = facts.forgeAsk == true
	event.icon = icon
	event.hint = if dodge then HINT else ""
	event.x = x
	event.y = y
	event.z = z
	return {
		ok = true,
		event = event,
		signature = signatureOf(event),
	}
end

-- The client paints only this shape. Any other CombatFx kind is ignored.
function CodexCues.accept(payload: any): { [string]: any }
	if type(payload) ~= "table" or not onlyKeys(payload, EVENT_KEYS) then
		return { ok = false }
	end
	if payload.kind ~= KIND then
		return { ok = false }
	end
	if payload.dodge ~= true and payload.dodge ~= false then
		return { ok = false }
	end
	if payload.skills ~= true and payload.skills ~= false then
		return { ok = false }
	end
	if payload.shards ~= true and payload.shards ~= false then
		return { ok = false }
	end
	if payload.crafting ~= true and payload.crafting ~= false then
		return { ok = false }
	end
	local icon = payload.icon
	if icon ~= "" and icon ~= "red" and icon ~= "blue" then
		return { ok = false }
	end
	local hint = payload.hint
	if payload.dodge == true then
		if hint ~= HINT then
			return { ok = false }
		end
	elseif hint ~= "" then
		return { ok = false }
	end
	local x = finite(payload.x)
	local y = finite(payload.y)
	local z = finite(payload.z)
	if x == nil or y == nil or z == nil then
		return { ok = false }
	end
	return {
		ok = true,
		dodge = payload.dodge == true,
		skills = payload.skills == true,
		shards = payload.shards == true,
		crafting = payload.crafting == true,
		icon = icon,
		hint = hint,
		x = x,
		y = y,
		z = z,
	}
end

function CodexCues.readable(): boolean
	local color = CodexCues.COLOR
	local pairsToCheck = {
		{ color.skill, color.skillInk },
		{ color.dodge, color.dodgeInk },
		{ color.socket, color.socketInk },
		{ color.iconText, color.iconInk },
		{ color.arrow, color.iconInk },
	}
	for _, row in ipairs(pairsToCheck) do
		if UiTheme.contrast(row[1], row[2]) < 4.5 then
			return false
		end
	end
	return true
end

return CodexCues
