--!strict

--[[
	The Phase 2 save field is equipLoadout: one string per slot, "" when
	empty. It is additive. schemaVersion stays 26 on this branch.

	migrate() copies first and edits the copy only. The table the caller
	still holds is not written. That is the #381 rule (Schema.migrate
	copies, then SaveMigrate.run). #381 is not merged here, so this
	function is the step, and Schema.reconcile only fills a missing
	equipLoadout from the template.

	After #381 lands, register it without rewriting the other steps:

	  local function migrateTo27(raw: any, versionless: boolean)
	    Save.apply(raw, versionless, ctx)
	  end
	  -- Schema.MIGRATIONS append { to = 27, apply = migrateTo27 }
	  -- Schema.VERSION = 27

	Do not bump the version before that. A v27 document would look
	"newer" to a v26 server and that server would refuse the load.
	apply() assumes the caller already copied. It only writes
	equipLoadout. Gold, bag, and equipped stay as they are.
]]

local Validate = require("./Validate")

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

local function empty(ctx: any): { [string]: string }
	local loadout = {}
	for _, id in ipairs(ctx.slots.ORDER) do
		loadout[id] = ""
	end
	return loadout
end

-- Mutates data.equipLoadout only. versionless keeps a table that is
-- already there (then drops ids the player does not own). A missing
-- or non-table field becomes empty slots.
function Save.apply(data: any, versionless: boolean, ctx: any)
	if type(data) ~= "table" then
		return
	end
	local current = data.equipLoadout
	if type(current) == "table" then
		data.equipLoadout = Validate.loadout(data, ctx)
		return
	end
	if versionless and current ~= nil then
		-- A versionless save stored something that is not a loadout.
		-- Do not guess. Empty slots are the safe default.
		data.equipLoadout = empty(ctx)
		return
	end
	data.equipLoadout = empty(ctx)
end

function Save.migrate(raw: any, ctx: any): (any?, string?)
	if type(raw) ~= "table" then
		return nil, "corrupt"
	end
	local copy = deepCopy(raw, 0)
	Save.apply(copy, raw.schemaVersion == nil, ctx)
	return copy, nil
end

return Save
