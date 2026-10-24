--!strict

--[[
	Per-player heartbeat isolation.

	One crawl that throws must not cancel the other players' ticks.
	A fault warns once and may destroy that run. It never grants loot.
	A run already in finish() (resolving) is left alone so cleanup
	cannot pay twice.
]]

local RunTick = {}

export type Sweep = {
	completed: { string },
	failed: { string },
	destroyed: { string },
	granted: { string },
	warnings: { string },
	seen: { [string]: boolean },
}

-- warnNow, then whether the run may be destroyed. Resolving means
-- finish() already owns the run. Destroying it again can pay twice.
function RunTick.fault(warned: boolean, hasRun: boolean, resolving: boolean): (boolean, boolean)
	return warned ~= true, hasRun == true and resolving ~= true
end

local function copySeen(warned: { [string]: boolean }?): { [string]: boolean }
	local seen: { [string]: boolean } = {}
	if warned == nil then
		return seen
	end
	for key, value in pairs(warned) do
		seen[key] = value
	end
	return seen
end

-- steps runs once per id. A throw records that id and continues.
-- granted stays empty: a fault does not pay. seen is a new table.
function RunTick.sweep(ids: { string }, step: (string) -> (), warned: { [string]: boolean }?): Sweep
	local seen = copySeen(warned)
	local completed = {}
	local failed = {}
	local destroyed = {}
	local granted = {}
	local warnings = {}
	for _, id in ipairs(ids) do
		local ok, err = pcall(step, id)
		if ok then
			table.insert(completed, id)
		else
			table.insert(failed, id)
			local warnNow, destroy = RunTick.fault(seen[id] == true, true, false)
			if warnNow then
				seen[id] = true
				table.insert(warnings, tostring(err))
			end
			if destroy then
				table.insert(destroyed, id)
			end
		end
	end
	return {
		completed = completed,
		failed = failed,
		destroyed = destroyed,
		granted = granted,
		warnings = warnings,
		seen = seen,
	}
end

return RunTick
