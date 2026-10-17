--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local SavedWorld = require("../src/ReplicatedStorage/Shared/SavedWorld")

describe("SavedWorld", function()
	it("drops a saved hub and keeps the camera, terrain, characters, and the spawn plate", function()
		expect(SavedWorld.shouldRemove("ShardfallWorld", "Folder", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("Haven", "Model", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("Baseplate", "Part", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("SpawnLocation", "SpawnLocation", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("Camera", "Camera", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("Terrain", "Terrain", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("SomeRig", "Model", true)).toBeFalse()
		expect(SavedWorld.shouldRemove("KevinAscencio", "Model", false, true)).toBeFalse()
		expect(SavedWorld.shouldClearDefault("Baseplate", "Part", false)).toBeFalse()
		expect(SavedWorld.shouldClearDefault("SpawnLocation", "SpawnLocation", false)).toBeFalse()
		expect(SavedWorld.shouldClearDefault("Baseplate", "Part", true)).toBeTrue()
		expect(SavedWorld.shouldClearDefault("SpawnLocation", "SpawnLocation", true)).toBeTrue()
		expect(SavedWorld.shouldClearDefault("HubSpawn", "SpawnLocation", true)).toBeFalse()
	end)
end)
