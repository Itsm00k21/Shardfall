--!strict

--[[
	A roll invoke is a land, a miss, or a refusal. Pure.

	classify(invokedOk, result) reads those arguments and returns
	"land", "miss", or "refuse". It does not write them.

	A thrown invoke is a refusal. The pcall error string is not a miss.
	A result that is not a table is a refusal. ok == true with an item
	table is a land. ok == true with no item and no error string is a
	miss. A blank error or a missing error counts as no error. The live
	server does not send that miss. The branch stays.

	Anything else is a refusal. That includes ok ~= true, ok == false,
	and a non-empty error such as "not enough tokens" or the timeout
	string, even when ok == true.

	paid, a product id, Robux, cost, and skip do not change the class.
	An extra argument does not. No clock. No RNG. No services. Nothing
	here costs Robux.
]]

local RollRefuse = {}

export type Class = "land" | "miss" | "refuse"

local function reason(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = string.match(value, "^%s*(.-)%s*$")
	if trimmed == nil or trimmed == "" then
		return nil
	end
	return trimmed
end

function RollRefuse.classify(invokedOk: any, result: any): Class
	if invokedOk ~= true then
		return "refuse"
	end
	if type(result) ~= "table" then
		return "refuse"
	end
	local accepted = result.ok == true
	local item = result.item
	if accepted and type(item) == "table" then
		return "land"
	end
	if accepted and item == nil and reason(result.error) == nil then
		return "miss"
	end
	return "refuse"
end

return RollRefuse
