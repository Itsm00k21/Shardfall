--!strict

--[[
	Fight roster. Waves 1-4 keep the graybox counts. The mix picks type 1,
	2, or 3 for each slot. The boss wave stays one boss and its adds.
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
local Waves = require("./Waves")

local Enemies = {}

export type Load = {
	id: string,
	kind: string,
	typeIndex: number,
}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Enemies.kindAt(waveIndex: number, slot: number, config: any?): string
	local cfg = cfgOf(config)
	local wave = Waves.def(waveIndex, cfg)
	if typeof(wave) ~= "table" then
		return "chaser"
	end
	if wave.kind == "boss" then
		if slot == 1 then
			return "boss"
		end
		return "add"
	end
	local mix = cfg.mix
	local pattern = if typeof(mix) == "table" then mix[waveIndex] else nil
	if typeof(pattern) ~= "table" or #pattern == 0 then
		return "chaser"
	end
	local index = ((slot - 1) % #pattern) + 1
	local kind = pattern[index]
	if kind ~= "chaser" and kind ~= "ranged" and kind ~= "tank" then
		return "chaser"
	end
	return kind
end

function Enemies.loadout(waveIndex: any, config: any?): { Load }
	local cfg = cfgOf(config)
	local roster = Waves.roster(waveIndex, cfg)
	local list: { Load } = {}
	for slot, unit in ipairs(roster) do
		local kind = unit.kind
		if kind ~= "boss" and kind ~= "add" then
			kind = Enemies.kindAt(waveIndex, slot, cfg)
		end
		local profile = WaveArenaConfig.profile(cfg, kind)
		local typeIndex = 0
		if typeof(cfg.types) == "table" and typeof(cfg.types[kind]) == "number" then
			typeIndex = cfg.types[kind]
		end
		table.insert(list, {
			id = profile.id,
			kind = kind,
			typeIndex = typeIndex,
		})
	end
	return list
end

return Enemies
