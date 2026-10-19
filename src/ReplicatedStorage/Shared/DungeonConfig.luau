--!strict

--[[
	Dungeon tunables in one place (Kevin's Oct 19 playtest fixes, and the
	Rootvault Trial numbers as they land). Pure data plus tiny helpers.
	Nothing here costs Robux.
]]

local DungeonConfig = {}

-- Rootvault crawl: after the last enemy in a room dies, the banner counts
-- down this many seconds, then the first open door is taken for the
-- player (the same teleport a door click uses). Clicking a door sooner
-- still works.
DungeonConfig.ROOM_CLEAR_SECONDS = 3

function DungeonConfig.roomClearText(seconds: number?): string
	return string.format("Room clear. Next room in %ds.", seconds or DungeonConfig.ROOM_CLEAR_SECONDS)
end

-- Doors the countdown never takes for the player (they spend currency).
DungeonConfig.AUTO_DOOR_SKIP = table.freeze({ shop = true })

-- The door the countdown takes: the first open door that costs nothing.
function DungeonConfig.autoDoor(offer: any): string?
	if type(offer) ~= "table" then
		return nil
	end
	for _, door in ipairs(offer) do
		if type(door) == "table" and type(door.id) == "string" and DungeonConfig.AUTO_DOOR_SKIP[door.id] ~= true then
			return door.id
		end
	end
	return nil
end

-- Boss health (Kevin's clip: Gnarl's flat 220 HP fell to one 131 hit once
-- she dropped below half, where she takes full damage). Bosses now size
-- to the run owner's weapon at spawn so the Normal fight lasts about
-- BOSS_FIGHT_SECONDS, with a per-level floor for weak or unarmed builds.
-- Difficulty multipliers (Rootvault.scale) apply on top.
DungeonConfig.BOSS_FIGHT_SECONDS = 36 -- target on Normal; 30-45s band
DungeonConfig.BOSS_FIGHT_MIN = 30
DungeonConfig.BOSS_FIGHT_MAX = 45
-- Share of the fight spent swinging (the rest is dodging red squares).
DungeonConfig.BOSS_UPTIME = 0.8
-- Skills and pets on top of weapon swings.
DungeonConfig.BOSS_EXTRA_DAMAGE = 1.25
-- Mirrors Gnarl's phase 1: armour lets this fraction through, except in the
-- weak window (weakSeconds out of each slam cycle).
DungeonConfig.BOSS_ARMORED = 0.45
DungeonConfig.BOSS_WEAK_SHARE = 1.6 / 5
DungeonConfig.BOSS_HP_PER_LEVEL = 60

-- Expected weapon damage per second, crits included.
function DungeonConfig.playerDps(offense: any): number
	if type(offense) ~= "table" then
		return 0
	end
	local damage = tonumber(offense.damage) or 0
	local speed = tonumber(offense.attackSpeed) or 1
	local critChance = math.clamp(tonumber(offense.critChance) or 0, 0, 1)
	local critDamage = math.max(1, tonumber(offense.critDamage) or 1)
	if damage ~= damage or speed ~= speed or damage <= 0 or speed <= 0 then
		return 0
	end
	return damage * speed * (1 + critChance * (critDamage - 1))
end

-- Seconds to burn `health` at `dps`: phase 1 (top half) behind armour,
-- phase 2 at full damage, scaled by uptime and extra damage.
function DungeonConfig.fightSeconds(health: number, dps: number): number
	if dps <= 0 then
		return math.huge
	end
	local phaseOne = DungeonConfig.BOSS_ARMORED * (1 - DungeonConfig.BOSS_WEAK_SHARE) + DungeonConfig.BOSS_WEAK_SHARE
	local effective = dps * DungeonConfig.BOSS_UPTIME * DungeonConfig.BOSS_EXTRA_DAMAGE
	return (health / 2) / (effective * phaseOne) + (health / 2) / effective
end

function DungeonConfig.bossHealth(baseHealth: number, dps: number, level: number?): number
	local lv = math.max(1, math.floor(tonumber(level) or 1))
	local floorHp = baseHealth + DungeonConfig.BOSS_HP_PER_LEVEL * (lv - 1)
	local perHp = DungeonConfig.fightSeconds(1, dps)
	local sized = if perHp == math.huge then 0 else DungeonConfig.BOSS_FIGHT_SECONDS / perHp
	return math.floor(math.max(floorHp, sized) + 0.5)
end

return table.freeze(DungeonConfig)
