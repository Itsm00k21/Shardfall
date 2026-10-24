--!strict

--[[
	Wave counter and boss bar. Both stay nil while the arena is off, so
	nothing is drawn. The results card is attached only after the death hold.
]]

local Hud = {}

function Hud.bossBar(run: any): any
	if typeof(run) ~= "table" or typeof(run.enemies) ~= "table" then
		return { shown = false, hp = 0, maxHp = 0, ratio = 0 }
	end
	for _, enemy in ipairs(run.enemies) do
		if enemy.kind == "boss" and enemy.alive == true then
			local ratio = 0
			if enemy.maxHp > 0 then
				ratio = enemy.hp / enemy.maxHp
			end
			return {
				shown = true,
				hp = enemy.hp,
				maxHp = enemy.maxHp,
				ratio = ratio,
			}
		end
	end
	return { shown = false, hp = 0, maxHp = 0, ratio = 0 }
end

function Hud.snapshot(run: any, open: boolean): any
	if open ~= true or typeof(run) ~= "table" then
		return nil
	end
	return {
		wave = run.wave,
		total = run.total,
		text = string.format("Wave %d / %d", run.wave, run.total),
		boss = Hud.bossBar(run),
		phase = run.phase,
		card = run.card,
	}
end

return Hud
