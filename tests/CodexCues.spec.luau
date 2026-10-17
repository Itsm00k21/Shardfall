--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local ChestConfig = require("../src/ReplicatedStorage/Shared/ChestConfig")
local Codex = require("../src/ReplicatedStorage/Shared/Codex")
local CodexCues = require("../src/ReplicatedStorage/Shared/CodexCues")
local Loops = require("../src/ReplicatedStorage/Shared/Loops")
local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")

local HINT = "Dodge!"

local function enemy(color: string, boss: boolean, untilAt: number, alive: boolean?)
	return {
		alive = alive ~= false,
		boss = boss,
		color = color,
		untilAt = untilAt,
		x = 10,
		y = 4,
		z = -6,
	}
end

local function fight(rows: { any }, now: number?)
	return {
		now = if now ~= nil then now else 10,
		enemies = rows,
		openSockets = 0,
		looseShards = 0,
		forgeAsk = false,
	}
end

local function profile(overrides: { [string]: any }?)
	local data = {
		craftingLevel = 1,
		craftingXp = 0,
		inventory = {},
		materials = {},
		firstSession = { returning = false, granted = { forge = false } },
	}
	if overrides ~= nil then
		for key, value in pairs(overrides) do
			data[key] = value
		end
	end
	return data
end

describe("Codex cues", function()
	it("pulses dodge only during a red telegraph and keeps the hint", function()
		local winding = CodexCues.paint(fight({ enemy("red", false, 12) }, 10))
		expect(winding.ok).toEqual(true)
		expect(winding.event.dodge).toEqual(true)
		expect(winding.event.hint).toEqual(HINT)
		expect(winding.event.hint).toEqual(Codex.ENTRIES[2].hint)
		expect(#winding.event.hint).toEqual(#HINT)
		expect(winding.event.skills).toEqual(false)
		expect(winding.event.icon).toEqual("")

		local done = CodexCues.paint(fight({ enemy("red", false, 10) }, 10))
		expect(done.event.dodge).toEqual(false)
		expect(done.event.hint).toEqual("")

		local blue = CodexCues.paint(fight({ enemy("blue", false, 12) }, 10))
		expect(blue.event.dodge).toEqual(false)
		expect(blue.event.hint).toEqual("")

		local dead = CodexCues.paint(fight({ enemy("red", false, 12, false) }, 10))
		expect(dead.event.dodge).toEqual(false)
	end)

	it("glows skills while three living grunts share the room", function()
		local pack = {
			enemy("red", false, 0),
			enemy("red", false, 0),
			enemy("red", false, 0),
		}
		local glowing = CodexCues.paint(fight(pack))
		expect(glowing.event.skills).toEqual(true)
		expect(glowing.event.hint).toEqual("")

		pack[3] = enemy("red", false, 0, false)
		local thin = CodexCues.paint(fight(pack))
		expect(thin.event.skills).toEqual(false)

		local bossPack = {
			enemy("red", true, 0),
			enemy("red", false, 0),
			enemy("red", false, 0),
		}
		expect(CodexCues.paint(fight(bossPack)).event.skills).toEqual(false)
	end)

	it("puts a red then blue icon over a boss who is alone", function()
		local red = CodexCues.paint(fight({ enemy("red", true, 20) }, 10))
		expect(red.event.icon).toEqual("red")
		expect(red.event.x).toEqual(10)
		expect(red.event.dodge).toEqual(true)
		expect(red.event.hint).toEqual(HINT)

		local blue = CodexCues.paint(fight({ enemy("blue", true, 20) }, 10))
		expect(blue.event.icon).toEqual("blue")
		expect(blue.event.dodge).toEqual(false)
		expect(blue.event.hint).toEqual("")

		local purple = CodexCues.paint(fight({ enemy("purple", true, 20) }, 10))
		expect(purple.event.icon).toEqual("")

		local crowded = CodexCues.paint(fight({
			enemy("red", true, 20),
			enemy("red", false, 0),
		}, 10))
		expect(crowded.event.icon).toEqual("")
		expect(crowded.event.dodge).toEqual(true)

		local grunt = CodexCues.paint(fight({ enemy("red", false, 20) }, 10))
		expect(grunt.event.icon).toEqual("")
		expect(grunt.event.dodge).toEqual(true)
	end)

	it("glows an open socket only when a loose shard can go in", function()
		local bare = CodexCues.paint({
			now = 1,
			enemies = {},
			openSockets = 1,
			looseShards = 0,
			forgeAsk = false,
		})
		expect(bare.event.shards).toEqual(false)

		local ready = CodexCues.paint({
			now = 1,
			enemies = {},
			openSockets = 1,
			looseShards = 1,
			forgeAsk = false,
		})
		expect(ready.event.shards).toEqual(true)
		expect(ready.event.hint).toEqual("")

		local noSocket = CodexCues.paint({
			now = 1,
			enemies = {},
			openSockets = 0,
			looseShards = 2,
			forgeAsk = false,
		})
		expect(noSocket.event.shards).toEqual(false)
	end)

	it("names the forge ask from the profile, not from a client seen map", function()
		local asked = CodexCues.facts({
			profile = profile({
				materials = { wood = 4, vine = 2 },
			}),
			inHaven = true,
			now = 3,
			enemies = {},
		})
		expect(asked.ok).toEqual(true)
		local painted = CodexCues.paint(asked.facts)
		expect(painted.event.crafting).toEqual(true)
		expect(painted.event.hint).toEqual("")

		local away = CodexCues.facts({
			profile = profile({ materials = { wood = 4, vine = 2 } }),
			inHaven = false,
			now = 3,
			enemies = {},
		})
		expect(CodexCues.paint(away.facts).event.crafting).toEqual(false)

		local crafted = CodexCues.facts({
			profile = profile({
				craftingXp = 12,
				materials = { wood = 4, vine = 2 },
			}),
			inHaven = true,
			now = 3,
			enemies = {},
		})
		expect(CodexCues.paint(crafted.facts).event.crafting).toEqual(false)

		local returning = CodexCues.facts({
			profile = profile({
				materials = { wood = 8, vine = 4 },
				firstSession = { returning = true },
			}),
			inHaven = true,
			now = 3,
			enemies = {},
		})
		expect(CodexCues.paint(returning.facts).event.crafting).toEqual(false)

		local short = CodexCues.facts({
			profile = profile({ materials = { wood = 1, vine = 0 } }),
			inHaven = true,
			now = 3,
			enemies = {},
		})
		expect(CodexCues.paint(short.facts).event.crafting).toEqual(false)
	end)

	it("counts an open socket and a rolled shard on the server profile", function()
		local named = CodexCues.facts({
			profile = profile({
				inventory = {
					blade = {
						uid = "blade",
						kind = "Weapon",
						name = "Thornbound Blade",
						templateId = "thornbound_blade",
						sockets = 1,
					},
					roll = {
						uid = "roll",
						kind = "Weapon",
						name = "Vinewood Sword",
						templateId = "vinewood_sword",
						sockets = 0,
						poolId = "verdant_armory",
					},
				},
			}),
			inHaven = true,
			now = 4,
			enemies = { enemy("red", true, 9) },
		})
		expect(named.ok).toEqual(true)
		expect(named.facts.openSockets).toEqual(1)
		expect(named.facts.looseShards).toEqual(1)
		local painted = CodexCues.paint(named.facts)
		expect(painted.event.shards).toEqual(true)
		expect(painted.event.icon).toEqual("red")
		expect(painted.event.keys).toBeNil()
		expect(painted.event.gold).toBeNil()
	end)

	it("refuses seen, a user id, and a paid field", function()
		local function refuse(extra: { [string]: any })
			local source = {
				profile = profile({}),
				inHaven = true,
				now = 1,
				enemies = {},
			}
			for key, value in pairs(extra) do
				source[key] = value
			end
			local named = CodexCues.facts(source)
			expect(named.ok).toEqual(false)
			expect(named.facts).toBeNil()
		end
		refuse({ seen = { dodge = true } })
		refuse({ userId = 7 })
		refuse({ guildId = "g" })
		refuse({ productId = 1 })
		refuse({ robux = 0 })
		refuse({ cost = 0 })
		refuse({ skip = false })
		refuse({ paid = true })

		local stuffed = fight({
			{
				alive = true,
				boss = true,
				color = "red",
				untilAt = 20,
				x = 1,
				y = 2,
				z = 3,
				seen = true,
			},
		})
		expect(CodexCues.paint(stuffed).ok).toEqual(false)

		local clientHint = fight({})
		clientHint.hint = "Dodge! now"
		expect(CodexCues.paint(clientHint).ok).toEqual(false)
	end)

	it("accepts only the server snapshot", function()
		local painted = CodexCues.paint(fight({ enemy("red", true, 15) }, 10))
		local accepted = CodexCues.accept(painted.event)
		expect(accepted.ok).toEqual(true)
		expect(accepted.dodge).toEqual(true)
		expect(accepted.hint).toEqual(HINT)
		expect(accepted.icon).toEqual("red")

		expect(CodexCues.accept({ kind = "telegraph", color = "red" }).ok).toEqual(false)
		expect(CodexCues.accept({
			kind = "codex",
			dodge = true,
			skills = false,
			shards = false,
			crafting = false,
			icon = "",
			hint = "Dodge! now",
			x = 0,
			y = 0,
			z = 0,
		}).ok).toEqual(false)
		expect(CodexCues.accept({
			kind = "codex",
			dodge = false,
			skills = false,
			shards = false,
			crafting = false,
			icon = "purple",
			hint = "",
			x = 0,
			y = 0,
			z = 0,
		}).ok).toEqual(false)

		local cleared = CodexCues.cleared()
		expect(CodexCues.accept(cleared.event).ok).toEqual(true)
		expect(CodexCues.accept(cleared.event).dodge).toEqual(false)
		expect(CodexCues.accept(cleared.event).hint).toEqual("")
	end)

	it("keeps the cue colors readable on the dark bar", function()
		expect(CodexCues.readable()).toEqual(true)
	end)

	it("does not move schema, paid flags, or the Codex module", function()
		expect(Schema.VERSION).toEqual(26)
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		expect(RarityConfig.PAID_LUCK_ENABLED).toEqual(false)
		expect(ChestConfig.PAID_CHESTS_ENABLED).toEqual(false)
		expect(Codex.ENTRIES[2].hint).toEqual(HINT)

		local cues = fs.readFile("src/ReplicatedStorage/Shared/CodexCues.luau")
		expect(string.find(cues, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(cues, 'HINT ..', 1, true)).toBeNil()
		expect(string.find(cues, '"Dodge!" ..', 1, true)).toBeNil()

		local bar = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		expect(string.find(bar, "SkillGlow", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "DodgePulse", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "DodgeHint", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "CodexCues.HINT", 1, true) ~= nil).toBeTrue()
		expect(string.find(bar, "FireServer", 1, true)).toBeNil()

		local combat = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau")
		expect(string.find(combat, "CodexTelegraph", 1, true) ~= nil).toBeTrue()
		expect(string.find(combat, "CodexIcon", 1, true) ~= nil).toBeTrue()

		local bag = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau")
		expect(string.find(bag, "SocketGlow", 1, true) ~= nil).toBeTrue()

		local haven = fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HavenClient.luau")
		expect(string.find(haven, "ForgeArrow", 1, true) ~= nil).toBeTrue()

		local dungeon = fs.readFile("src/ServerScriptService/ShardfallServer/DungeonService.luau")
		expect(string.find(dungeon, "publishCues", 1, true) ~= nil).toBeTrue()
		expect(string.find(dungeon, "CodexCues.facts", 1, true) ~= nil).toBeTrue()
	end)
end)
