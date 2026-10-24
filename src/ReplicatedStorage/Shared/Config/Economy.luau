--!strict

--[[
	V1 run pay (Echo's economy sheet rev 2, docs/research/economy_v1.md
	section 2 on PR #369). The wave table is the Normal base. HardMode and
	Rootvault read the difficulty row. A clear multiplies tokens from that
	row and rounds half up.

	Roll Tokens per wave on Normal: 1, 1, 2, 2, then 5 for the boss wave.
	A Normal clear pays 11. Hard pays 22 (2×). There is no fragments save
	field; fragmentMultiplier is the locked Core Loop number.

	Roll Tokens are the live shardTokens save field. Earn only. Nothing
	here costs Robux or adds a profile field.
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

return table.freeze(Economy)
