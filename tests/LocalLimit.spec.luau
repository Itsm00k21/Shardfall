--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LocalLimit = require("./LocalLimit")

local function peak(source: string, name: string): number
	for _, report in LocalLimit.scan(source) do
		if report.name == name then
			return report.locals
		end
	end
	error("missing function " .. name, 2)
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in luaFiles(path) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	table.sort(found)
	return found
end

describe("Local register cap", function()
	it("counts parameters, block locals, and for names toward the peak", function()
		local source = [[
local function f(a)
	local b = 1
	for i = 1, 2 do
		local c = i
	end
end
]]
		expect(peak(source, "f")).toEqual(4)
	end)

	it("gives a nested function its own local stack", function()
		local source = [[
local function outer()
	local a = 1
	local function inner()
		local b = 2
		local c = 3
	end
end
]]
		expect(peak(source, "outer")).toEqual(2)
		expect(peak(source, "inner")).toEqual(2)
	end)

	it("pops locals when a do block ends", function()
		local source = [[
do
	local a = 1
end
local b = 2
]]
		expect(peak(source, "<chunk>")).toEqual(1)
	end)

	it("counts a method self parameter", function()
		local source = [[
function Widget:paint(alpha)
	local color = alpha
end
]]
		expect(peak(source, "paint")).toEqual(3)
	end)

	it("flags a function over 180 locals and allows 180", function()
		local lines = { "local function big()" }
		for index = 1, 180 do
			table.insert(lines, string.format("\tlocal v%d = %d", index, index))
		end
		table.insert(lines, "end")
		local atCap = table.concat(lines, "\n")
		expect(LocalLimit.over(atCap)).toBeNil()
		expect(peak(atCap, "big")).toEqual(180)

		table.insert(lines, #lines, "\tlocal overflow = 1")
		local over = table.concat(lines, "\n")
		local hit = LocalLimit.over(over)
		expect(hit ~= nil).toBeTrue()
		expect((hit :: any).name).toEqual("big")
		expect((hit :: any).locals).toEqual(181)
	end)

	it("keeps every src module at or under 180 locals in every scope", function()
		local files = luaFiles("src")
		expect(#files > 0).toBeTrue()
		for _, path in files do
			local source = fs.readFile(path)
			local ok, result = pcall(LocalLimit.over, source)
			if not ok then
				error(path .. ": " .. tostring(result), 0)
			end
			if result ~= nil then
				error(
					string.format(
						"%s:%d %s has %d locals (limit %d)",
						path,
						result.line,
						result.name,
						result.locals,
						LocalLimit.LIMIT
					),
					0
				)
			end
		end
	end)
end)
