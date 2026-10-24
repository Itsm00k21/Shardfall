--!strict

--[[
	Phase 0.5 hookups. Studio stays off the live DataStore unless
	StoreAdapter.STUDIO_LIVE is on. The save buttons do not fall through
	to DebugTools.apply. LaunchGate.saveTools stays off.
]]

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")

describe("Phase 0.5 save hooks", function()
	it("keeps save tools off and Studio off the live store by default", function()
		expect(LaunchGate.on("saveTools")).toEqual(false)
		expect(LaunchGate.SHOW.saveTools).toEqual(false)
		local store = fs.readFile("src/ServerScriptService/ShardfallServer/StoreAdapter.luau")
		expect(string.find(store, "StoreAdapter.STUDIO_LIVE = false", 1, true) ~= nil).toBeTrue()
		local guard = string.find(store, "RunService:IsStudio() and StoreAdapter.STUDIO_LIVE ~= true", 1, true)
		local probe = string.find(store, "GetDataStore(PROBE_STORE)", 1, true)
		local live = string.find(store, "return dataStoreAdapter()", 1, true)
		expect(guard ~= nil and probe ~= nil and live ~= nil).toBeTrue()
		expect((guard :: number) < (probe :: number)).toBeTrue()
		expect((guard :: number) < (live :: number)).toBeTrue()
		local debug = fs.readFile("src/ServerScriptService/ShardfallServer/DebugService.luau")
		local autosave = string.find(debug, 'action == "autosave"', 1, true)
		local version = string.find(debug, 'action == "saveversion"', 1, true)
		local apply = string.find(debug, "DebugTools.apply(data, action)", 1, true)
		expect(autosave ~= nil and version ~= nil and apply ~= nil).toBeTrue()
		expect((autosave :: number) < (apply :: number)).toBeTrue()
		expect((version :: number) < (apply :: number)).toBeTrue()
		expect(string.find(debug, "DataService.save(player)", 1, true) ~= nil).toBeTrue()
		expect(string.find(debug, "schemaVersion", 1, true) ~= nil).toBeTrue()
	end)
end)
