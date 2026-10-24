--!strict

--[[
	Small-enemy juice. A hit flashes the body. A death leaves a puff.
	The boss uses the death hold instead of a puff.
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

local Feel = {}

local function cfgOf(config: any): any
	return if config == nil then WaveArenaConfig else config
end

function Feel.hitFlash(enemy: any, config: any?): any
	local cfg = cfgOf(config)
	return {
		kind = "hitFlash",
		id = enemy.uid,
		seconds = cfg.feel.hitFlash,
		x = enemy.x,
		z = enemy.z,
		color = cfg.feel.flashColor,
	}
end

function Feel.deathPuff(enemy: any, config: any?): any
	local cfg = cfgOf(config)
	return {
		kind = "deathPuff",
		id = enemy.uid,
		seconds = cfg.feel.deathPuff,
		x = enemy.x,
		z = enemy.z,
		color = cfg.feel.puffColor,
	}
end

return Feel
