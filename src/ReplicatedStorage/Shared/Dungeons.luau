--!strict

--[[
	Dungeon definitions. Rootvault is the Verdant Wilds crawl: a hub, three
	combat rooms, and Grandmother Gnarl. Later realms get a row here with a
	higher `ascension`. Leave `implemented = false` until that crawl exists;
	the server will not start it.

	Rooms are plain data. DungeonService is what builds the parts in Studio.
	Enemy numbers are the combat inputs (HP, damage, defense, attack speed).
	The boss fight is tuned to finish in under a minute with fists, and
	faster with a rolled weapon.

	Clear rewards are rolled by `rollClear`. Odds below are placeholders.
]]

local Dungeons = {}

export type EnemyDef = {
	id: string,
	name: string,
	maxHealth: number,
	damage: number,
	defense: number,
	attackSpeed: number,
	moveSpeed: number,
	range: number,
	style: "melee" | "projectile",
	minDot: number,
	projectileSpeed: number,
	hover: number,
	boss: boolean,
	phase2At: number,
	weakSeconds: number,
	armoredMultiplier: number,
	fogInterval: number,
	fogDamage: number,
	safeRadius: number,
	color: { number },
	size: { number },
}

export type RoomDef = {
	id: string,
	name: string,
	enemies: { string },
}

export type RewardDef = {
	gold: number,
	shardTokens: number,
	xp: number,
	materials: { [string]: number },
	heartwoodChance: number,
	voucherChance: number,
}

export type ClearReward = {
	gold: number,
	shardTokens: number,
	xp: number,
	materials: { [string]: number },
	voucher: string?,
}

export type DungeonDef = {
	id: string,
	name: string,
	realm: string,
	theme: string,
	ascension: number,
	implemented: boolean,
	floorSize: number,
	rooms: { RoomDef },
	rewards: RewardDef?,
	endless: boolean?,
}

Dungeons.ROOTVAULT_ID = "rootvault"
Dungeons.WAVES_ID = "rootvault_waves"
Dungeons.HEARTWOOD_ID = "heartwood"

-- After a room or wave is empty, the server waits this long, then moves on.
Dungeons.ADVANCE_SECONDS = 3
-- How long the victory card stays up. Auto-farm restarts after the shorter one.
Dungeons.VICTORY_CARD_SECONDS = 6
Dungeons.FARM_RESTART_SECONDS = 4
Dungeons.FARM_DEFEAT_SECONDS = 3
-- Roblox disconnects a player who has not provided input for about 20 minutes.
-- Player.Idled is the hook. Reward cutoff, if it is added later, belongs there.
Dungeons.IDLE_NOTE_SECONDS = 15 * 60

-- PLACEHOLDER wave scaling. Wave 1 is the base stat. Each later wave adds
-- WAVE_HP_PER / WAVE_DAMAGE_PER. Count grows every WAVE_COUNT_EVERY waves.
-- Every WAVE_BOSS_EVERY waves is a boss wave and multiplies again.
Dungeons.WAVE_HP_PER = 0.18
Dungeons.WAVE_DAMAGE_PER = 0.12
Dungeons.WAVE_BASE_COUNT = 2
Dungeons.WAVE_COUNT_EVERY = 2
Dungeons.WAVE_MAX_COUNT = 8
Dungeons.WAVE_BOSS_EVERY = 5
Dungeons.WAVE_BOSS_HP = 1.35
Dungeons.WAVE_BOSS_DAMAGE = 1.15
-- Negative room index so the arena sits on the other side of the hub.
Dungeons.WAVES_ROOM_INDEX = -1

-- Haven occupies the origin. Room n sits REALM_OFFSET plus this many studs
-- further along Z so the crawl does not overlap the islands. Players are
-- teleported. The in-room path is the corridor.
Dungeons.ROOM_SPACING = 140
Dungeons.REALM_OFFSET = 4000
-- 79 studs on a side is about 2x the old 56-stud floor, with space to kite.
Dungeons.FLOOR_SIZE = 79
Dungeons.WALL_HEIGHT = 16
Dungeons.CORRIDOR_WIDTH = 16
-- Player stands far enough from the north wall that a short camera stays inside.
Dungeons.SPAWN_Z = -18
Dungeons.PORTAL_Z = 28
Dungeons.CAMERA_MAX_ZOOM = 18
Dungeons.CAMERA_MIN_ZOOM = 4
-- Fixed crawl light. Brighter than Haven night, and the client applies it
-- only while the character is inside a room so the day cycle stays on the hub.
Dungeons.CRAWL_LIGHT = {
	ambient = { 124, 110, 90 },
	outdoor = { 156, 138, 112 },
	brightness = 1.7,
	clockTime = 14.5,
	fog = { 110, 104, 86 },
}
-- Warm fill plus a thin outline so a rig still reads when shadows are off.
Dungeons.RIM = {
	fill = { 255, 214, 160 },
	fillTransparency = 0.88,
	outline = { 255, 236, 200 },
	outlineTransparency = 0.2,
}

Dungeons.ENEMIES = {
	vine_crawler = {
		id = "vine_crawler",
		name = "Vine Crawler",
		maxHealth = 36,
		damage = 8,
		defense = 1,
		attackSpeed = 0.75,
		moveSpeed = 11,
		range = 6,
		style = "melee",
		minDot = 0.1,
		projectileSpeed = 0,
		hover = 0,
		boss = false,
		phase2At = 0,
		weakSeconds = 0,
		armoredMultiplier = 1,
		fogInterval = 0,
		fogDamage = 0,
		safeRadius = 0,
		color = { 72, 140, 74 },
		size = { 3.2, 2.2, 4.2 },
	},
	spore_bat = {
		id = "spore_bat",
		name = "Spore Bat",
		maxHealth = 22,
		damage = 7,
		defense = 0,
		attackSpeed = 0.85,
		moveSpeed = 14,
		range = 34,
		style = "projectile",
		minDot = -1,
		projectileSpeed = 42,
		hover = 3.5,
		boss = false,
		phase2At = 0,
		weakSeconds = 0,
		armoredMultiplier = 1,
		fogInterval = 0,
		fogDamage = 0,
		safeRadius = 0,
		color = { 156, 96, 210 },
		size = { 2.4, 1.2, 2.4 },
	},
	root_brute = {
		id = "root_brute",
		name = "Root Brute",
		maxHealth = 78,
		damage = 14,
		defense = 4,
		attackSpeed = 0.4,
		moveSpeed = 7,
		range = 7,
		style = "melee",
		minDot = 0.2,
		projectileSpeed = 0,
		hover = 0,
		boss = false,
		phase2At = 0,
		weakSeconds = 0,
		armoredMultiplier = 1,
		fogInterval = 0,
		fogDamage = 0,
		safeRadius = 0,
		color = { 122, 84, 52 },
		size = { 5.2, 5.6, 4.4 },
	},
	moss_crawler = {
		id = "moss_crawler",
		name = "Moss Crawler",
		maxHealth = 48,
		damage = 9,
		defense = 3,
		attackSpeed = 0.6,
		moveSpeed = 8,
		range = 6,
		style = "melee",
		minDot = 0.15,
		projectileSpeed = 0,
		hover = 0,
		boss = false,
		phase2At = 0,
		weakSeconds = 0,
		armoredMultiplier = 1,
		fogInterval = 0,
		fogDamage = 0,
		safeRadius = 0,
		color = { 86, 150, 78 },
		size = { 4.2, 2.4, 5.2 },
	},
	thorn_sprite = {
		id = "thorn_sprite",
		name = "Thorn Sprite",
		maxHealth = 40,
		damage = 11,
		defense = 1,
		attackSpeed = 0.9,
		moveSpeed = 13,
		range = 7,
		style = "melee",
		minDot = 0.05,
		projectileSpeed = 0,
		hover = 2.2,
		boss = false,
		phase2At = 0,
		weakSeconds = 0,
		armoredMultiplier = 1,
		fogInterval = 0,
		fogDamage = 0,
		safeRadius = 0,
		color = { 170, 255, 176 },
		size = { 2.4, 2.6, 2.2 },
	},
	grandmother_gnarl = {
		id = "grandmother_gnarl",
		name = "Grandmother Gnarl",
		maxHealth = 220,
		-- Level 2, starter bar (CombatMath.BASE_HEALTH 100, little defense).
		-- Was 18: six failed slams deleted the bar. 10 is ten failed slams.
		-- Walking out of the red square deals none of this.
		damage = 10,
		defense = 0,
		-- Cooldown after a slam lands is 1/attackSpeed. Was 0.25 (4.0s).
		-- 0.20 is 5.0s, and the boss windup is CombatFeel.TELEGRAPH_BOSS
		-- (1.8s), so the next red square does not open on top of the last.
		attackSpeed = 0.2,
		moveSpeed = 6,
		range = 16,
		style = "melee",
		minDot = -1,
		projectileSpeed = 0,
		hover = 0,
		boss = true,
		-- At half HP she stops guarding a weak spot and fills the room with fog.
		phase2At = 0.5,
		weakSeconds = 1.6,
		armoredMultiplier = 0.45,
		-- Was 4s / 14 damage, which stacked with the slam on a fresh bar.
		-- 7s / 8, and Rootvault.sameBeat still keeps fog off a slam heartbeat.
		fogInterval = 7,
		fogDamage = 8,
		safeRadius = 8,
		color = { 36, 92, 58 },
		size = { 8, 9, 7 },
	},
} :: { [string]: EnemyDef }

local ROOTVAULT: DungeonDef = {
	id = Dungeons.ROOTVAULT_ID,
	name = "Rootvault",
	realm = "Verdant Wilds",
	theme = "Nature, beasts, wood, vines",
	ascension = 0,
	implemented = true,
	floorSize = Dungeons.FLOOR_SIZE,
	rooms = {
		{
			id = "thicket",
			name = "Choked Thicket",
			enemies = { "vine_crawler", "vine_crawler" },
		},
		{
			id = "canopy",
			name = "Spore Canopy",
			enemies = { "spore_bat", "spore_bat", "moss_crawler" },
		},
		{
			id = "den",
			name = "Brute Den",
			enemies = { "root_brute", "thorn_sprite" },
		},
		{
			id = "heart",
			name = "Gnarl's Heart",
			enemies = { "grandmother_gnarl" },
		},
	},
	rewards = {
		gold = 360,
		shardTokens = 3,
		xp = 40,
		materials = { wood = 4, vine = 3, spore = 2, bark = 1 },
		-- PLACEHOLDER. A clear can also drop one Heartwood and one roll voucher.
		heartwoodChance = 0.35,
		voucherChance = 0.4,
	},
}

-- One arena. DungeonService fills it from waveKinds / waveStats. Rewards are
-- per wave, not rollClear.
local WAVES: DungeonDef = {
	id = Dungeons.WAVES_ID,
	name = "Rootvault Waves",
	realm = "Verdant Wilds",
	theme = "Endless arena",
	ascension = 0,
	implemented = true,
	endless = true,
	floorSize = Dungeons.FLOOR_SIZE,
	rooms = {
		{
			id = "wave_arena",
			name = "Wave Arena",
			enemies = {},
		},
	},
	rewards = nil,
}

-- Hook for the next realm. Not a crawl yet: the gate is real, the rooms are not.
local TIDECRYPT: DungeonDef = {
	id = "tidecrypt",
	name = "Tidecrypt",
	realm = "Sunken Reach",
	theme = "Water and tide",
	ascension = 1,
	implemented = false,
	floorSize = Dungeons.FLOOR_SIZE,
	rooms = {},
	rewards = nil,
}

local HEARTWOOD: DungeonDef = {
	id = Dungeons.HEARTWOOD_ID,
	name = "The Heartwood",
	realm = "Verdant Wilds",
	theme = "Raid wings",
	ascension = 0,
	implemented = true,
	floorSize = Dungeons.FLOOR_SIZE,
	rooms = {
		{ id = "twins", name = "Thornwarden Twins", enemies = { "grandmother_gnarl" } },
		{ id = "sapwell", name = "Mother Sapwell", enemies = { "grandmother_gnarl" } },
		{ id = "galecrown", name = "Galecrown", enemies = { "grandmother_gnarl" } },
		{ id = "awakened", name = "Grandmother Gnarl Awakened", enemies = { "grandmother_gnarl" } },
	},
	rewards = {
		gold = 480,
		shardTokens = 4,
		xp = 80,
		materials = { wood = 4, vine = 3, spore = 2, bark = 2 },
		heartwoodChance = 0.5,
		voucherChance = 0.2,
	},
}

local LIST: { DungeonDef } = { ROOTVAULT, WAVES, HEARTWOOD, TIDECRYPT }

local byId: { [string]: DungeonDef } = {}
for _, dungeon in ipairs(LIST) do
	byId[dungeon.id] = dungeon
end

function Dungeons.get(dungeonId: string): DungeonDef?
	return byId[dungeonId]
end

function Dungeons.all(): { DungeonDef }
	return LIST
end

function Dungeons.isUnlocked(dungeon: DungeonDef, ascension: any): boolean
	local level = ascension
	if type(level) ~= "number" or level ~= level then
		level = 0
	end
	return level >= dungeon.ascension
end

-- Where room `index` (1-based) is built, in studs. The hub is not a room.
function Dungeons.roomOrigin(index: number): (number, number, number)
	return 0, 0, Dungeons.REALM_OFFSET + index * Dungeons.ROOM_SPACING
end

function Dungeons.enemy(kind: string): EnemyDef?
	return Dungeons.ENEMIES[kind]
end

-- Defeat copy follows the realm. Rootvault and Heartwood are Verdant Wilds,
-- so a forest clear does not say Rockdust or name the dungeon as if it
-- were the hazard. Endless keeps the wave line.
function Dungeons.defeatLine(dungeon: DungeonDef?): string
	if dungeon ~= nil and dungeon.endless == true then
		return "The waves stop when you fall. Rewards from cleared waves are still yours."
	end
	local realm = if dungeon ~= nil and type(dungeon.realm) == "string" then dungeon.realm else ""
	if realm == "Verdant Wilds" then
		return "The wilds push you out. Materials from earlier clears are still yours."
	end
	if realm ~= "" then
		return realm .. " pushes you out. Materials from earlier clears are still yours."
	end
	return "You fall. Materials from earlier clears are still yours."
end

function Dungeons.lightLayout(
	floorSize: number
): { { kind: string, x: number, z: number, y: number } }
	local size = floorSize
	if type(size) ~= "number" or size ~= size or size < 16 then
		size = Dungeons.FLOOR_SIZE
	end
	local edge = size / 2 - 3
	return {
		{ kind = "torch", x = -edge * 0.55, z = -edge, y = 6 },
		{ kind = "torch", x = edge * 0.55, z = -edge, y = 6 },
		{ kind = "torch", x = -edge, z = 0, y = 6 },
		{ kind = "torch", x = edge, z = 0, y = 6 },
		{ kind = "crystal", x = -edge * 0.45, z = edge, y = 6 },
		{ kind = "crystal", x = edge * 0.45, z = edge, y = 6 },
		{ kind = "floor", x = 0, z = -edge * 0.25, y = 3.2 },
		{ kind = "floor", x = 0, z = edge * 0.25, y = 3.2 },
	}
end

function Dungeons.inCrawl(x: number, z: number): boolean
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return false
	end
	local half = Dungeons.FLOOR_SIZE / 2 + 6
	local places = { Dungeons.WAVES_ROOM_INDEX }
	local root = Dungeons.get(Dungeons.ROOTVAULT_ID)
	if root ~= nil then
		for index = 1, #root.rooms do
			table.insert(places, index)
		end
	end
	for _, index in ipairs(places) do
		local originX, _, originZ = Dungeons.roomOrigin(index)
		if math.abs(x - originX) <= half and math.abs(z - originZ) <= half then
			return true
		end
	end
	return false
end

function Dungeons.bossPhase(health: number, maxHealth: number, phase2At: number): number
	if maxHealth <= 0 then
		return 1
	end
	if health / maxHealth <= phase2At then
		return 2
	end
	return 1
end

-- Sunbeam pads in the boss room, offsets from the room center.
Dungeons.SUNBEAM_OFFSETS = {
	{ x = -22, z = 8 },
	{ x = 22, z = -4 },
	{ x = 0, z = 20 },
}

-- Eight pads, one per wave slot, spread across the open floor.
Dungeons.ENEMY_SPAWNS = {
	{ x = -26, z = 2 },
	{ x = 26, z = 2 },
	{ x = -14, z = 22 },
	{ x = 14, z = 22 },
	{ x = 0, z = 10 },
	{ x = -26, z = 18 },
	{ x = 26, z = 18 },
	{ x = 0, z = 28 },
}

local function wholeWave(wave: number): number
	local n = math.floor(wave)
	if n < 1 or n ~= n then
		return 1
	end
	return n
end

function Dungeons.isBossWave(wave: number): boolean
	return wholeWave(wave) % Dungeons.WAVE_BOSS_EVERY == 0
end

function Dungeons.waveCount(wave: number): number
	local n = wholeWave(wave)
	local extra = math.floor((n - 1) / Dungeons.WAVE_COUNT_EVERY)
	local count = Dungeons.WAVE_BASE_COUNT + extra
	if count > Dungeons.WAVE_MAX_COUNT then
		return Dungeons.WAVE_MAX_COUNT
	end
	return count
end

function Dungeons.waveMultiplier(wave: number, perWave: number): number
	local n = wholeWave(wave)
	return 1 + (n - 1) * perWave
end

-- Boss flag is the enemy, not the wave. A boss wave's adds stay on the
-- normal scale. The boss itself passes true and picks up WAVE_BOSS_HP.
function Dungeons.waveStats(
	baseHealth: number,
	baseDamage: number,
	wave: number,
	boss: boolean
): (number, number)
	local hpScale = Dungeons.waveMultiplier(wave, Dungeons.WAVE_HP_PER)
	local damageScale = Dungeons.waveMultiplier(wave, Dungeons.WAVE_DAMAGE_PER)
	if boss then
		hpScale *= Dungeons.WAVE_BOSS_HP
		damageScale *= Dungeons.WAVE_BOSS_DAMAGE
	end
	local hp = math.floor(baseHealth * hpScale + 0.5)
	local damage = math.floor(baseDamage * damageScale + 0.5)
	if hp < 1 then
		hp = 1
	end
	if damage < 1 then
		damage = 1
	end
	return hp, damage
end

function Dungeons.waveKinds(wave: number): { string }
	local n = wholeWave(wave)
	if Dungeons.isBossWave(n) then
		return { "grandmother_gnarl", "vine_crawler", "spore_bat" }
	end
	local pool = { "vine_crawler", "spore_bat", "root_brute" }
	local kinds = {}
	local count = Dungeons.waveCount(n)
	for index = 1, count do
		local pick = ((n + index - 2) % #pool) + 1
		table.insert(kinds, pool[pick])
	end
	return kinds
end

function Dungeons.waveReward(wave: number): ClearReward
	local n = wholeWave(wave)
	local materials: { [string]: number } = { wood = 1 }
	if n % 2 == 0 then
		materials.vine = 1
	end
	if n % 4 == 0 then
		materials.spore = 1
	end
	if n % 5 == 0 then
		materials.bark = 1
	end
	local tokens = 0
	if n % 5 == 0 then
		tokens = 2
	elseif n % 3 == 0 then
		tokens = 1
	end
	return {
		gold = math.floor((8 + n * 3) * 8),
		shardTokens = tokens,
		xp = math.floor(6 + n * 2),
		materials = materials,
		voucher = nil,
	}
end

function Dungeons.rollClear(dungeon: DungeonDef, rng: any): ClearReward?
	local reward = dungeon.rewards
	if reward == nil then
		return nil
	end
	local materials = table.clone(reward.materials)
	if rng:nextNumber() < reward.heartwoodChance then
		materials.heartwood = (materials.heartwood or 0) + 1
	end
	local voucher = nil
	if rng:nextNumber() < reward.voucherChance then
		-- 1 is an Armory crack, 2 is a Pets crack. Either spends no shard token.
		if rng:nextInteger(1, 2) == 1 then
			voucher = "armory"
		else
			voucher = "pets"
		end
	end
	return {
		gold = reward.gold,
		shardTokens = reward.shardTokens,
		xp = reward.xp,
		materials = materials,
		voucher = voucher,
	}
end

-- One line for the panel. The next ascension dungeon, or a note that it is
-- unlocked and still a stub.
function Dungeons.progressNote(ascension: any): string?
	local level = ascension
	if type(level) ~= "number" or level ~= level then
		level = 0
	end
	for _, dungeon in ipairs(LIST) do
		if dungeon.implemented == true then
			continue
		end
		if level < dungeon.ascension then
			return string.format("%s unlocks at Ascension %d.", dungeon.name, dungeon.ascension)
		end
		return string.format("%s is unlocked and not built yet.", dungeon.name)
	end
	return nil
end

for _, enemy in pairs(Dungeons.ENEMIES) do
	table.freeze(enemy.color)
	table.freeze(enemy.size)
	table.freeze(enemy)
end
table.freeze(Dungeons.ENEMIES)
table.freeze(Dungeons.SUNBEAM_OFFSETS)
for _, offset in ipairs(Dungeons.SUNBEAM_OFFSETS) do
	table.freeze(offset)
end
table.freeze(Dungeons.ENEMY_SPAWNS)
for _, offset in ipairs(Dungeons.ENEMY_SPAWNS) do
	table.freeze(offset)
end
table.freeze(Dungeons.CRAWL_LIGHT.ambient)
table.freeze(Dungeons.CRAWL_LIGHT.outdoor)
table.freeze(Dungeons.CRAWL_LIGHT.fog)
table.freeze(Dungeons.CRAWL_LIGHT)
table.freeze(Dungeons.RIM.fill)
table.freeze(Dungeons.RIM.outline)
table.freeze(Dungeons.RIM)
table.freeze(ROOTVAULT.rooms)
if ROOTVAULT.rewards ~= nil then
	table.freeze(ROOTVAULT.rewards.materials)
	table.freeze(ROOTVAULT.rewards)
end
table.freeze(ROOTVAULT)
table.freeze(WAVES.rooms)
table.freeze(WAVES)
table.freeze(TIDECRYPT)
table.freeze(LIST)

return Dungeons
