--!strict

--[[
	Ordered profile migrations. Each step is v_n -> v_n+1 and only runs when
	the loaded version is still below `to`. Steps must be numbered 1..n with
	no gaps. Schema.migrate copies the save first, so a step cannot rewrite
	the table the caller still holds.

	A missing schemaVersion is version 1 (SaveMigrate.FLOOR). The caller then
	walks every later step. A missing DataStore key is not a version; that
	is a new profile and Schema returns the template instead of calling run.
]]

local SaveMigrate = {}

SaveMigrate.FLOOR = 1

export type Step = {
	to: number,
	apply: (data: any, versionless: boolean) -> (),
}

-- stored is the schemaVersion field, not the whole profile.
-- nil means the field was absent: load as v1. NaN is corrupt.
-- +inf is a number; the caller rejects it as newer than this build.
function SaveMigrate.versionOf(stored: any): (number?, string?, boolean)
	if stored == nil then
		return SaveMigrate.FLOOR, nil, true
	end
	if type(stored) ~= "number" or stored ~= stored then
		return nil, "corrupt", false
	end
	return stored, nil, false
end

function SaveMigrate.run(data: any, version: number, versionless: boolean, steps: { Step }): number
	for index, step in ipairs(steps) do
		if step.to ~= index then
			error("Save migration steps must be numbered 1..n in order", 0)
		end
		if version < step.to then
			step.apply(data, versionless)
			data.schemaVersion = step.to
			version = step.to
		end
	end
	return version
end

return SaveMigrate
