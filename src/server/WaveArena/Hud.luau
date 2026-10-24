--!strict

--[[
	Wave counter and boss bar. Both stay nil while the arena is off, so
	nothing is drawn. The results card is attached only after the death hold.

	A fight snapshot also carries the wave HUD: living enemies and adds,
	the boss name or a "Wave n/n" label, the difficulty tier, whether Hard
	really scales, and the seconds left on the run clock. Hard does not
	scale wave combat yet, so isHardReal stays false and the client keeps
	the HARD chip hidden. Nothing here is saved.
]]

local function sharedRoot()
	if game ~= nil and game.GetService ~= nil then
		local folder = script.Parent
		if folder ~= nil and folder.Name == "server" then
			return require(folder:WaitForChild("SharedRequire"))
		end
		if folder ~= nil and folder.Parent ~= nil then
			return require(folder.Parent:WaitForChild("SharedRequire"))
		end
		error("SharedRequire is not beside this module")
	end
	local source = debug.info(1, "s")
	local marker = "src/server/"
	local at = string.find(source, marker, 1, true)
	if at == nil then
		error("SharedRequire could not see src/server in " .. source)
	end
	local rest = string.sub(source, at + #marker)
	local _, slashes = string.gsub(rest, "/", "")
	if slashes == 0 then
		return require("./SharedRequire")
	end
	local prefix = ""
	local parent = string.char(46, 46)
	for _ = 1, slashes do
		prefix ..= parent .. "/"
	end
	return require(prefix .. "SharedRequire")
end

local SharedRequire = sharedRoot()

local WaveArenaConfig = SharedRequire.module("Config/WaveArenaConfig")

local Hud = {}

-- Wave combat still uses the base hp and damage. Economy's Hard
-- multipliers are not applied, so a Hard tier is not a real scale.
local HARD_IS_REAL = false

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

local function difficultyOf(run: any): string
	local tier = run.tier
	if type(tier) ~= "string" or tier == "" then
		return "normal"
	end
	return string.lower(tier)
end

local function timeoutOf(config: any): number
	local cfg = if typeof(config) == "table" then config else WaveArenaConfig
	local limit = cfg.timeout
	if type(limit) ~= "number" or limit ~= limit or limit <= 0 or limit >= math.huge then
		return 480
	end
	return limit
end

local function timeLeft(run: any, config: any): number
	local elapsed = run.seconds
	if type(elapsed) ~= "number" or elapsed ~= elapsed or elapsed < 0 or elapsed >= math.huge then
		elapsed = 0
	end
	local left = timeoutOf(config) - elapsed
	if left < 0 then
		left = 0
	end
	return left
end

-- Living non-adds, living adds, and the living boss's name. A dead boss
-- does not keep the name, so the wave label can come back.
local function living(run: any): (number, number, string?)
	local enemiesLeft = 0
	local addsLeft = 0
	local bossName: string? = nil
	local enemies = run.enemies
	if typeof(enemies) ~= "table" then
		return 0, 0, nil
	end
	for _, enemy in ipairs(enemies) do
		if typeof(enemy) == "table" and enemy.alive == true then
			if enemy.kind == "add" then
				addsLeft += 1
			else
				enemiesLeft += 1
			end
			if bossName == nil and enemy.kind == "boss" then
				local name = enemy.name
				if type(name) ~= "string" or name == "" then
					name = "Boss"
				end
				bossName = name
			end
		end
	end
	return enemiesLeft, addsLeft, bossName
end

local function outside(run: any): any
	local difficulty = "normal"
	if typeof(run) == "table" then
		difficulty = difficultyOf(run)
	end
	return {
		wave = 0,
		total = 0,
		text = "",
		boss = { shown = false, hp = 0, maxHp = 0, ratio = 0 },
		phase = nil,
		card = nil,
		enemiesLeft = 0,
		addsLeft = 0,
		bossName = nil,
		label = nil,
		difficulty = difficulty,
		isHardReal = HARD_IS_REAL,
		secondsLeft = nil,
	}
end

function Hud.snapshot(run: any, open: boolean, config: any?): any
	if open ~= true then
		return nil
	end
	if typeof(run) ~= "table" or run.inArena == false then
		return outside(run)
	end
	local enemiesLeft, addsLeft, bossName = living(run)
	local label: string? = nil
	if bossName == nil then
		local wave = if type(run.wave) == "number" then run.wave else 0
		local total = if type(run.total) == "number" then run.total else 0
		label = string.format("Wave %d/%d", wave, total)
	end
	return {
		wave = run.wave,
		total = run.total,
		text = string.format("Wave %d / %d", run.wave, run.total),
		boss = Hud.bossBar(run),
		phase = run.phase,
		card = run.card,
		enemiesLeft = enemiesLeft,
		addsLeft = addsLeft,
		bossName = bossName,
		label = label,
		difficulty = difficultyOf(run),
		isHardReal = HARD_IS_REAL,
		secondsLeft = timeLeft(run, config),
	}
end

return Hud
