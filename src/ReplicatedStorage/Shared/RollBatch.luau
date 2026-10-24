--!strict

--[[
	Client gate for a ten-shard crack.

	NEED is "Need 9 shards" (RollConfig.cost(10): x10 is 10% off ten
	singles). block(tokens, count) returns that string when count is at
	least 10 and the caller holds fewer tokens than the x10 price.
	A missing, non-numeric, NaN, infinite, or negative token count is 0.
	Any other count returns nil, including a single crack.

	A third argument, including paid = true, does not change the result.
	Each call reads its arguments and does not write them. No clock.
	No RNG. No services. Nothing here costs Robux.
]]

local RollConfig = require("./RollConfig")

local RollBatch = {}

RollBatch.NEED = RollConfig.needText(RollConfig.MULTI_COUNT)

local function held(value: any): number
	if type(value) ~= "number" then
		return 0
	end
	if value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return 0
	end
	return value
end

function RollBatch.block(tokens: any, count: any, _extra: any?): string?
	if type(count) ~= "number" then
		return nil
	end
	if count ~= count or count == math.huge or count == -math.huge or count < RollConfig.MULTI_COUNT then
		return nil
	end
	if held(tokens) < RollConfig.multiCost() then
		return RollBatch.NEED
	end
	return nil
end

return RollBatch
