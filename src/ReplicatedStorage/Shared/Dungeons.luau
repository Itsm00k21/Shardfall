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

-- Hub at the origin. Room n sits this many studs further along Z so the
-- rooms do not overlap. Players are teleported; there is no corridor.
Dungeons.ROOM_SPACING = 140

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
	grandmother_gnarl = {
		id = "grandmother_gnarl",
		name = "Grandmother Gnarl",
		maxHealth = 220,
		damage = 18,
		defense = 0,
		attackSpeed = 0.25,
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
		fogInterval = 4,
		fogDamage = 14,
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
	floorSize = 56,
	rooms = {
		{
			id = "thicket",
			name = "Choked Thicket",
			enemies = { "vine_crawler", "vine_crawler" },
		},
		{
			id = "canopy",
			name = "Spore Canopy",
			enemies = { "spore_bat", "spore_bat", "vine_crawler" },
		},
		{
			id = "den",
			name = "Brute Den",
			enemies = { "root_brute", "vine_crawler" },
		},
		{
			id = "heart",
			name = "Gnarl's Heart",
			enemies = { "grandmother_gnarl" },
		},
	},
	rewards = {
		gold = 45,
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
	floorSize = 56,
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
	floorSize = 56,
	rooms = {},
	rewards = nil,
}

local LIST: { DungeonDef } = { ROOTVAULT, WAVES, TIDECRYPT }

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

-- Where room `index` (1-based) is built, in studs. The hub is index 0.
function Dungeons.roomOrigin(index: number): (number, number, number)
	return 0, 0, index * Dungeons.ROOM_SPACING
end

function Dungeons.enemy(kind: string): EnemyDef?
	return Dungeons.ENEMIES[kind]
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
	{ x = -14, z = 8 },
	{ x = 14, z = -6 },
	{ x = 0, z = 14 },
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
		gold = math.floor(8 + n * 3),
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
