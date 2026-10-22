--!strict

--[[
	Wave sequence. Counts come from WaveArenaConfig only.
	There is no client count and no Rootvault wave table.
]]

local WaveArenaConfig = require("../../shared/Config/WaveArenaConfig")

local Waves = {}

export type Unit = {
	id: string,
	kind: string,
}

local function rows(config: any): { any }
	return config.waves
end

function Waves.bodies(wave: any): number
	if typeof(wave) ~= "table" then
		return 0
	end
	if wave.kind == "boss" then
		return (wave.count or 0) + (wave.adds or 0)
	end
	return wave.count or 0
end

-- Bodies that use a gate pad. The boss uses the open centre spot.
function Waves.gateLoad(wave: any): number
	if typeof(wave) ~= "table" then
		return 0
	end
	if wave.kind == "boss" then
		return wave.adds or 0
	end
	return wave.count or 0
end

function Waves.def(index: any, config: any?): any
	local cfg = if config == nil then WaveArenaConfig else config
	if typeof(cfg) ~= "table" or typeof(index) ~= "number" then
		return nil
	end
	if index ~= index then
		return nil
	end
	local n = math.floor(index)
	local wave = rows(cfg)[n]
	if typeof(wave) ~= "table" then
		return nil
	end
	return wave
end

function Waves.roster(index: any, config: any?): { Unit }
	local wave = Waves.def(index, config)
	if wave == nil then
		return {}
	end
	local cfg = if config == nil then WaveArenaConfig else config
	local list: { Unit } = {}
	if wave.kind == "boss" then
		local boss = WaveArenaConfig.profile(cfg, "boss")
		table.insert(list, { id = boss.id, kind = "boss" })
		local adds = wave.adds or 0
		local add = WaveArenaConfig.profile(cfg, "add")
		for _ = 1, adds do
			table.insert(list, { id = add.id, kind = "add" })
		end
		return list
	end
	local profile = WaveArenaConfig.profile(cfg, wave.kind)
	for _ = 1, (wave.count or 0) do
		table.insert(list, { id = profile.id, kind = wave.kind })
	end
	return list
end

function Waves.densest(config: any?): number
	local cfg = if config == nil then WaveArenaConfig else config
	local best = 1
	local most = -1
	for index, wave in ipairs(rows(cfg)) do
		local n = Waves.bodies(wave)
		if n > most then
			most = n
			best = index
		end
	end
	return best
end

function Waves.bossIndex(config: any?): number
	local cfg = if config == nil then WaveArenaConfig else config
	for index, wave in ipairs(rows(cfg)) do
		if wave.kind == "boss" then
			return index
		end
	end
	return #rows(cfg)
end

function Waves.count(config: any?): number
	local cfg = if config == nil then WaveArenaConfig else config
	return #rows(cfg)
end

return Waves
