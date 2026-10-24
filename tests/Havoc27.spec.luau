--!strict
local framework = require("./framework")
local describe, it, expect = framework.describe, framework.it, framework.expect
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local WaveFlow = require("../src/ReplicatedStorage/Shared/WaveFlow")
local WFS = require("../src/ServerScriptService/ShardfallServer/WaveFlowService")

describe("Havoc DP27", function()
	it("a wiped run takes no damage, opens no wave, and pays nothing", function()
		local p = LaunchGate.SHOW.enemyTypes
		LaunchGate.SHOW.enemyTypes = true
		local ok, e = pcall(function()
			local profile = Schema.template()
			local saves = 0
			local sink = { player = nil, profile = profile, persist = function(_d) saves += 1 return true end }
			local run = WFS.start(sink :: any)
			assert(run ~= nil)
			local w0 = run.wave
			WFS.wipe(run)
			local dealt, guard = 0, 0
			while run.clear ~= true and guard < 500 do
				guard += 1
				local boxes = WaveFlow.boxes(run)
				if #boxes == 0 then break end
				for _, b in ipairs(boxes) do dealt += WFS.hurt(run, b.id, 1e9, sink :: any) end
			end
			expect(dealt).toEqual(0)
			expect(run.wave).toEqual(w0)
			expect(run.rewarded == true).toEqual(false)
			expect(saves).toEqual(0)
		end)
		LaunchGate.SHOW.enemyTypes = p
		if not ok then error(e, 0) end
	end)
end)
