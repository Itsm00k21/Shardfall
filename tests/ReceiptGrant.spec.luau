--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LOOPS = "src/ReplicatedStorage/Shared/Loops.luau"
local RECEIPT = "src/ServerScriptService/ShardfallServer/ReceiptService.luau"
local LOOP_SERVICE = "src/ServerScriptService/ShardfallServer/LoopService.luau"

local function slice(source: string, signature: string, untilNeedle: string): string
	local startAt = string.find(source, signature, 1, true)
	expect(startAt ~= nil).toBeTrue()
	local stopAt = string.find(source, untilNeedle, (startAt :: number) + #signature, true)
	expect(stopAt ~= nil).toBeTrue()
	return string.sub(source, startAt :: number, (stopAt :: number) - 1)
end

local function commentBefore(source: string, signature: string): string
	local fnAt = string.find(source, signature, 1, true)
	expect(fnAt ~= nil).toBeTrue()
	local rows = {}
	local line = ""
	for index = 1, (fnAt :: number) - 1 do
		local char = string.sub(source, index, index)
		if char == "\n" then
			table.insert(rows, line)
			line = ""
		else
			line ..= char
		end
	end
	if line ~= "" then
		table.insert(rows, line)
	end
	local kept = {}
	local cursor = #rows
	while cursor > 0 and rows[cursor] == "" do
		cursor -= 1
	end
	while cursor > 0 and string.sub(rows[cursor], 1, 2) == "--" do
		table.insert(kept, 1, rows[cursor])
		cursor -= 1
	end
	return table.concat(kept, "\n")
end

describe("Receipt grant", function()
	it("writes passPremium before the receipt id", function()
		local loops = fs.readFile(LOOPS)
		expect(string.find(loops, "\nLoops.PREMIUM_ENABLED = false\n", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "\nLoops.PASS_PRODUCT_ID = 0\n", 1, true) ~= nil).toBeTrue()
		expect(string.find(loops, "\nLoops.ARCHIVE_PRODUCT_ID = 0\n", 1, true) ~= nil).toBeTrue()
		local body = slice(loops, "function Loops.grantPremium", "Loops.PREMIUM_TRACK")
		local passAt = string.find(body, "data.passPremium = true", 1, true)
		local idAt = string.find(body, "data.receipts[receiptId] = true", 1, true)
		local dupAt = string.find(body, "data.receipts[receiptId] == true", 1, true)
		expect(passAt ~= nil).toBeTrue()
		expect(idAt ~= nil).toBeTrue()
		expect(dupAt ~= nil).toBeTrue()
		expect((dupAt :: number) < (passAt :: number)).toBeTrue()
		expect((passAt :: number) < (idAt :: number)).toBeTrue()
		expect(string.find(body, "return false", passAt :: number, true) == nil).toBeTrue()
	end)

	it("records a receipt id only after the sku grant sticks", function()
		local receipt = fs.readFile(RECEIPT)
		local body =
			slice(receipt, "function ReceiptService.grant", "function ReceiptService.start")
		expect(string.find(body, "_productId", 1, true) == nil).toBeTrue()
		expect(string.find(body, "ProcessReceipt", 1, true) == nil).toBeTrue()
		local grantAt = string.find(body, "Loops.grantPremium(data, receiptId, productId)", 1, true)
		local gateAt = string.find(body, "if granted ~= true then", 1, true)
		local callAt = string.find(body, "duplicate = Economy.receipt(data, receiptId)", 1, true)
		expect(grantAt ~= nil).toBeTrue()
		expect(gateAt ~= nil).toBeTrue()
		expect(callAt ~= nil).toBeTrue()
		expect((grantAt :: number) < (gateAt :: number)).toBeTrue()
		expect((gateAt :: number) < (callAt :: number)).toBeTrue()
		local refuseAt = string.find(body, "return reason", 1, true)
		expect(refuseAt ~= nil).toBeTrue()
		expect((refuseAt :: number) < (callAt :: number)).toBeTrue()
	end)

	it("does not claim a ProcessReceipt grant that is not there", function()
		local receipt = fs.readFile(RECEIPT)
		local service = fs.readFile(LOOP_SERVICE)
		local openAt = string.find(service, "--[[", 1, true)
		local closeAt = string.find(service, "]]", openAt :: number, true)
		expect(openAt ~= nil).toBeTrue()
		expect(closeAt ~= nil).toBeTrue()
		local header = string.sub(service, openAt :: number, (closeAt :: number) + 1)
		local note = commentBefore(service, "function LoopService.grantPremium")
		local sentences = header .. "\n" .. note
		local claims = string.find(sentences, "ReceiptService calls", 1, true) ~= nil
			or string.find(sentences, "only caller", 1, true) ~= nil
			or string.find(sentences, "from its existing ProcessReceipt", 1, true) ~= nil
		local hasCall = string.find(receipt, "LoopService.grantPremium", 1, true) ~= nil
		if claims then
			expect(hasCall).toBeTrue()
		end
		if hasCall == false then
			expect(claims).toEqual(false)
		end
		expect(string.find(note, "ProcessReceipt", 1, true) ~= nil).toBeTrue()
		expect(string.find(header, "pending", 1, true) ~= nil).toBeTrue()
	end)
end)
