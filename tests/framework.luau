--!strict

--[[
	A small TestEZ-style runner for Lune.

	Specs call describe / it / expect, the same shape as TestEZ
	(https://roblox.github.io/testez/). The official TestEZ bootstrap walks
	Roblox instances, and this repo's tests also have to run on a machine
	with no Studio, so the runner lives here. Dropping a spec into a TestEZ
	Explorer plugin later means keeping these function names.

	Run everything with `lune run tests/run`.
]]

local framework = {}

type Case = {
	name: string,
	fn: () -> (),
}

local cases: { Case } = {}
local prefix: { string } = {}

local function show(value: any, depth: number): string
	if depth > 3 then
		return "..."
	end
	local kind = typeof(value)
	if kind == "string" then
		return string.format("%q", value)
	end
	if kind ~= "table" then
		return tostring(value)
	end
	local parts = {}
	local count = 0
	for key, child in pairs(value) do
		count += 1
		if count > 12 then
			table.insert(parts, "...")
			break
		end
		table.insert(
			parts,
			string.format("[%s] = %s", show(key, depth + 1), show(child, depth + 1))
		)
	end
	table.sort(parts)
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(left: any, right: any): boolean
	if left == right then
		return true
	end
	if typeof(left) ~= "table" or typeof(right) ~= "table" then
		return false
	end
	for key, value in pairs(left) do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key, value in pairs(right) do
		if not deepEqual(value, left[key]) then
			return false
		end
	end
	return true
end

function framework.describe(name: string, fn: () -> ())
	table.insert(prefix, name)
	fn()
	table.remove(prefix)
end

function framework.it(name: string, fn: () -> ())
	local title = table.concat(prefix, " › ")
	if title ~= "" then
		title ..= " › "
	end
	table.insert(cases, { name = title .. name, fn = fn })
end

function framework.expect(actual: any)
	local assertion = {}

	function assertion.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			error("expected " .. show(expected, 0) .. "\n     got " .. show(actual, 0), 2)
		end
	end

	function assertion.toBeCloseTo(expected: number, epsilon: number?)
		local tolerance = epsilon or 1e-9
		if type(actual) ~= "number" or math.abs(actual - expected) > tolerance then
			error(
				"expected "
					.. tostring(actual)
					.. " to be within "
					.. tostring(tolerance)
					.. " of "
					.. tostring(expected),
				2
			)
		end
	end

	function assertion.toBeTrue()
		if actual ~= true then
			error("expected true, got " .. show(actual, 0), 2)
		end
	end

	function assertion.toBeFalse()
		if actual ~= false then
			error("expected false, got " .. show(actual, 0), 2)
		end
	end

	function assertion.toBeNil()
		if actual ~= nil then
			error("expected nil, got " .. show(actual, 0), 2)
		end
	end

	function assertion.toBeGreaterThan(expected: number)
		if type(actual) ~= "number" or actual <= expected then
			error("expected " .. tostring(actual) .. " > " .. tostring(expected), 2)
		end
	end

	function assertion.toBeLessThan(expected: number)
		if type(actual) ~= "number" or actual >= expected then
			error("expected " .. tostring(actual) .. " < " .. tostring(expected), 2)
		end
	end

	function assertion.toThrow()
		if type(actual) ~= "function" then
			error("toThrow expected a function", 2)
		end
		local ok = pcall(actual)
		if ok then
			error("expected the function to throw", 2)
		end
	end

	return assertion
end

function framework.run(): number
	if #cases == 0 then
		print("No tests registered.")
		return 1
	end
	local failed = 0
	for index, case in ipairs(cases) do
		local ok, err = xpcall(case.fn, function(inner)
			return debug.traceback(tostring(inner), 2)
		end)
		if ok then
			print(string.format("  ok  %d  %s", index, case.name))
		else
			failed += 1
			print(string.format("FAIL  %d  %s", index, case.name))
			print(err)
		end
	end
	print(string.format("\n%d passed, %d failed", #cases - failed, failed))
	return if failed == 0 then 0 else 1
end

return framework
