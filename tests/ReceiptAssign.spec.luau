--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

describe("ProcessReceipt", function()
	it("is only assigned, never read", function()
		local reads = {}
		local assignments = 0
		for _, path in ipairs(luaFiles("src")) do
			local source = fs.readFile(path)
			local index = 1
			while true do
				local at = string.find(source, ".ProcessReceipt", index, true)
				if at == nil then
					break
				end
				local after = string.match(string.sub(source, at + #".ProcessReceipt"), "^%s*(.)")
				if after == "=" then
					assignments += 1
				else
					table.insert(reads, path)
				end
				index = at + 1
			end
		end
		expect(#reads).toEqual(0)
		expect(assignments).toEqual(1)
		local receipt = fs.readFile("src/ServerScriptService/ShardfallServer/ReceiptService.luau")
		expect(string.find(receipt, "ProcessReceipt ==", 1, true) == nil).toBeTrue()
		expect(string.find(receipt, "ProcessReceipt ~=", 1, true) == nil).toBeTrue()
		expect(string.find(receipt, ".ProcessReceipt =", 1, true) ~= nil).toBeTrue()
	end)
end)
