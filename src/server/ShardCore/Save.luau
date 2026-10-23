--!strict

--[[
	profile.shardCores is the core level per weapon uid. It only adds
	to the save. A missing map or a missing uid is level 0. migrate()
	copies first and does not write the caller's table.

	schemaVersion stays 26. Schema.reconcile is the live step (it calls
	the same sanitize). This function is the copy the tests use, and the
	step a later migration can register. Do not bump the version here.

	Items are not edited. item.upgrade, stars, and stats stay as they
	were. gearEssence is not spent here.
]]

local Save = {}

local function deepCopy(value: any, depth: number): any
	if type(value) ~= "table" then
		return value
	end
	if depth > 32 then
		return nil
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child, depth + 1)
	end
	return copy
end

function Save.migrate(raw: any, config: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "corrupt"
	end
	local copy = deepCopy(raw, 0)
	if type(copy) ~= "table" then
		return nil, "corrupt"
	end
	if type(config) == "table" and type(config.sanitize) == "function" then
		copy.shardCores = config.sanitize(copy.shardCores)
	elseif type(copy.shardCores) ~= "table" then
		copy.shardCores = {}
	end
	return copy, nil
end

return Save
