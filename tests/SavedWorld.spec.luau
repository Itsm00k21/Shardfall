--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local SavedWorld = require("../src/ReplicatedStorage/Shared/SavedWorld")

describe("SavedWorld", function()
	it("drops a saved hub and keeps the camera, terrain, and characters", function()
		expect(SavedWorld.shouldRemove("ShardfallWorld", "Folder", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("Haven", "Model", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("Baseplate", "Part", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("SpawnLocation", "SpawnLocation", false)).toBeTrue()
		expect(SavedWorld.shouldRemove("Camera", "Camera", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("Terrain", "Terrain", false)).toBeFalse()
		expect(SavedWorld.shouldRemove("SomeRig", "Model", true)).toBeFalse()
	end)
end)
