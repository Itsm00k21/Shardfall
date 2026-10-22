--!strict

--[[
	V1 run pay (Echo's economy sheet rev 2, docs/research/economy_v1.md
	section 2 on PR #369). Data only; nothing reads it yet. Phase 4.1 wires
	run rewards to it.

	Roll Tokens per wave on Normal: 1, 1, 2, 2, then 5 for the boss wave.
	A Normal clear pays 11. Harder difficulties multiply the whole clear and
	round half up (13.75 -> 14, 16.5 -> 17).

	Roll Tokens are the live shardTokens save field; no save change. Earn
	only, nothing here costs Robux.
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

-- Ids normal, hard and nightmare match Rootvault.DIFFICULTIES. medium and
-- insane are new. levelGate is the account level needed to pick it.
Economy.DIFFICULTIES = table.freeze({
	normal = table.freeze({ id = "normal", order = 1, tokenMultiplier = 1, levelGate = 1 }),
	medium = table.freeze({ id = "medium", order = 2, tokenMultiplier = 1.25, levelGate = 5 }),
	hard = table.freeze({ id = "hard", order = 3, tokenMultiplier = 1.5, levelGate = 10 }),
	nightmare = table.freeze({ id = "nightmare", order = 4, tokenMultiplier = 2, levelGate = 15 }),
	insane = table.freeze({ id = "insane", order = 5, tokenMultiplier = 3, levelGate = 20 }),
})

Economy.DIFFICULTY_ORDER = table.freeze({ "normal", "medium", "hard", "nightmare", "insane" })

return table.freeze(Economy)
