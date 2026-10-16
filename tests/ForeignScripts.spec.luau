--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ForeignScripts = require("../src/ReplicatedStorage/Shared/ForeignScripts")

describe("Foreign script scan", function()
	it("skips Roblox player scripts and still flags a stray world script", function()
		expect(table.find(ForeignScripts.SERVICES, "StarterPlayer")).toBeNil()

		expect(ForeignScripts.shouldFlag("StarterPlayer", {
			"RbxCharacterSounds",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterPlayer", {
			"PlayerScriptsLoader",
			"PlayerModule",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterPlayer", {
			"ServerAuthorityClient",
			"ServerAuthority",
			"PlayerModule",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterPlayer", {
			"ServerAuthorityServer",
			"ServerAuthority",
			"PlayerModule",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterPlayer", {
			"InputSetup",
			"PlayerModule",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()

		expect(ForeignScripts.shouldFlag("Workspace", { "Animate", "Workspace" })).toBeFalse()
		expect(ForeignScripts.shouldFlag("Workspace", { "Health", "Workspace" })).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterGui", { "ChatScript", "StarterGui" })).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterGui", { "BubbleChat", "StarterGui" })).toBeFalse()

		expect(ForeignScripts.shouldFlag("ServerScriptService", {
			"LegacyWorld",
			"ServerScriptService",
		})).toBeTrue()
		expect(ForeignScripts.shouldFlag("Workspace", { "OldSpawner", "Workspace" })).toBeTrue()
		expect(ForeignScripts.shouldFlag("ServerScriptService", {
			"init",
			"ShardfallServer",
			"ServerScriptService",
		})).toBeFalse()
		expect(ForeignScripts.shouldFlag("StarterPlayerScripts", {
			"init",
			"ShardfallClient",
			"StarterPlayerScripts",
			"StarterPlayer",
		})).toBeFalse()
	end)
end)
