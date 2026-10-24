--!strict

--[[
	V1 run pay (Echo's economy sheet rev 2, docs/research/economy_v1.md
	section 2 on PR #369). The wave table is the Normal base. HardMode and
	Rootvault read the difficulty row. A clear multiplies tokens from that
	row and rounds half up. Phase 4.1 still owns per-wave pay for waves 1-4.
	The wave-5 boss clear reads BOSS_CLEAR_TOKENS from this file.

	Roll Tokens per wave on Normal: 1, 1, 2, 2, then 5 for the boss wave.
	A Normal clear pays 11. Hard pays 22 (2×). There is no fragments save
	field; fragmentMultiplier is the locked Core Loop number. This boss
	grant pays the boss row only (5), on every tier. Hard does not multiply
	that 5.

	Roll Tokens are the live shardTokens save field. The grant-once run ids
	need their own bounded list (bossClearRuns) because the ledger is shared
	and short. Earn only. Nothing here costs Robux.
]]

local Economy = {}

Economy.VERSION = "v1"

Economy.WAVES = table.freeze({
	table.freeze({ id = "wave_1", wave = 1, boss = false, tokens = 1 }),
	table.freeze({ id = "wave_2", wave = 2, boss = false, tokens = 1 }),
	table.freeze({ id = "wave_3", wave = 3, boss = false, tokens = 2 }),
	table.freeze({ id = "wave_4", wave = 4, boss = false, tokens = 2 }),
	table.freeze({ id = "wave_5_boss", wave = 5, boss = true, tokens = 5 }),
})

-- Sum of WAVES on Normal. The config test checks they agree.
Economy.NORMAL_CLEAR_TOKENS = 11

-- Wave-5 boss clear only. Must match the boss row in WAVES. Not the 11.
Economy.BOSS_CLEAR_TOKENS = 5

-- How many recent run ids a profile remembers. The newest stays.
-- A run that just cleared is the newest, so a rejoin cannot pay it twice.
Economy.BOSS_CLEAR_RUNS = 16

-- The boss grant will not push shardTokens past this. The wallet is not
-- raised when it is already here; the run id is still remembered.
Economy.BOSS_CLEAR_TOKEN_CAP = 1000000

Economy.ROUNDING = "half_up"

-- Locked Core Loop: Hard unlocks at Lv 5, enemies have 2× HP and 1.5×
-- damage, and a clear pays 2× tokens and 2× fragments. Medium, Nightmare,
-- and Insane stay in this table. LaunchGate.extraDifficulties (off) is
-- what keeps them from being offered. levelGate is the account level.
Economy.DIFFICULTIES = table.freeze({
	normal = table.freeze({
		id = "normal",
		order = 1,
		tokenMultiplier = 1,
		fragmentMultiplier = 1,
		hpMultiplier = 1,
		damageMultiplier = 1,
		levelGate = 1,
	}),
	medium = table.freeze({
		id = "medium",
		order = 2,
		tokenMultiplier = 1.25,
		fragmentMultiplier = 1.25,
		hpMultiplier = 1.25,
		damageMultiplier = 1.25,
		levelGate = 5,
	}),
	hard = table.freeze({
		id = "hard",
		order = 3,
		tokenMultiplier = 2,
		fragmentMultiplier = 2,
		hpMultiplier = 2,
		damageMultiplier = 1.5,
		levelGate = 5,
	}),
	nightmare = table.freeze({
		id = "nightmare",
		order = 4,
		tokenMultiplier = 2,
		fragmentMultiplier = 2,
		hpMultiplier = 2,
		damageMultiplier = 2,
		levelGate = 15,
	}),
	insane = table.freeze({
		id = "insane",
		order = 5,
		tokenMultiplier = 3,
		fragmentMultiplier = 3,
		hpMultiplier = 3,
		damageMultiplier = 3,
		levelGate = 20,
	}),
})

Economy.DIFFICULTY_ORDER = table.freeze({ "normal", "medium", "hard", "nightmare", "insane" })

local BANNED = { robux = true, productId = true, cost = true, skip = true }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function positiveInt(value: any): boolean
	return finite(value) and value > 0 and value == math.floor(value)
end

local function hasBanned(row: any): boolean
	if type(row) ~= "table" then
		return false
	end
	for key in pairs(row) do
		if BANNED[key] == true then
			return true
		end
	end
	return false
end

-- Boss-clear numbers. A bad sheet pays nothing. Pass a table to test a
-- broken copy; nil checks this module.
function Economy.validate(source: any?): (boolean, string)
	local data = if source == nil then Economy else source
	if type(data) ~= "table" then
		return false, "Economy is missing"
	end
	if hasBanned(data) then
		return false, "Economy must not price Robux"
	end
	if not positiveInt(data.BOSS_CLEAR_TOKENS) then
		return false, "BOSS_CLEAR_TOKENS must be a positive whole number"
	end
	if not positiveInt(data.BOSS_CLEAR_RUNS) or data.BOSS_CLEAR_RUNS > 32 then
		return false, "BOSS_CLEAR_RUNS must be a whole number from 1 to 32"
	end
	if not positiveInt(data.BOSS_CLEAR_TOKEN_CAP) or data.BOSS_CLEAR_TOKEN_CAP > 1000000000 then
		return false, "BOSS_CLEAR_TOKEN_CAP must be a positive whole number"
	end
	if data.BOSS_CLEAR_TOKEN_CAP < data.BOSS_CLEAR_TOKENS then
		return false, "BOSS_CLEAR_TOKEN_CAP must hold the boss grant"
	end
	if type(data.WAVES) ~= "table" then
		return false, "WAVES is missing"
	end
	local bossTokens = nil
	local bosses = 0
	local sum = 0
	for _, wave in ipairs(data.WAVES) do
		if type(wave) ~= "table" or hasBanned(wave) then
			return false, "a wave must not price Robux"
		end
		if not positiveInt(wave.tokens) then
			return false, "wave tokens must be a positive whole number"
		end
		sum += wave.tokens
		if wave.boss == true then
			bosses += 1
			bossTokens = wave.tokens
			if wave.wave ~= 5 or wave.id ~= "wave_5_boss" then
				return false, "the boss wave must be wave_5_boss"
			end
		end
	end
	if bosses ~= 1 or bossTokens == nil then
		return false, "WAVES must name one boss wave"
	end
	if data.BOSS_CLEAR_TOKENS ~= bossTokens then
		return false, "BOSS_CLEAR_TOKENS must match the boss wave"
	end
	if data.NORMAL_CLEAR_TOKENS ~= sum then
		return false, "NORMAL_CLEAR_TOKENS must equal the wave sum"
	end
	if type(data.DIFFICULTIES) == "table" then
		for _, row in pairs(data.DIFFICULTIES) do
			if hasBanned(row) then
				return false, "a difficulty must not price Robux"
			end
		end
	end
	return true, ""
end

-- Boss row only. tokenMultiplier scales the 11-token clear, not this.
-- nil is the flat boss row. A known tier is still 5. Anything else pays nothing.
function Economy.bossClearPay(tier: any): number?
	local ok = Economy.validate()
	if ok ~= true then
		return nil
	end
	if tier ~= nil then
		if type(tier) ~= "string" or Economy.DIFFICULTIES[tier] == nil then
			return nil
		end
	end
	return Economy.BOSS_CLEAR_TOKENS
end

return table.freeze(Economy)
