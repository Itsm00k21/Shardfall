--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local RarityConfig = require("../src/ReplicatedStorage/Shared/RarityConfig")
local RollLoop = require("../src/ReplicatedStorage/Shared/RollLoop")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")

local function stopInput(patch: { [string]: any }): RollLoop.StopInput
	local input: RollLoop.StopInput = {
		auto = true,
		tokens = 3,
		bagFull = false,
		rarity = "Common",
		stopAt = "Rare",
		isNew = false,
		isUpgrade = false,
	}
	for key, value in pairs(patch) do
		(input :: any)[key] = value
	end
	return input
end

describe("RollLoop", function()
	it("queues one roll and ignores the press after that", function()
		local state = RollLoop.idle()
		expect(state.phase).toEqual("idle")
		expect(state.queued).toEqual(false)
		state = RollLoop.press(state)
		expect(state.phase).toEqual("revealing")
		expect(state.queued).toEqual(false)
		state = RollLoop.press(state)
		expect(state.queued).toEqual(true)
		local third = RollLoop.press(state)
		expect(third.phase).toEqual("revealing")
		expect(third.queued).toEqual(true)
		local started = RollLoop.finish(third)
		expect(started.phase).toEqual("revealing")
		expect(started.queued).toEqual(false)
		local idle = RollLoop.finish(started)
		expect(idle.phase).toEqual("idle")
		expect(idle.queued).toEqual(false)
	end)

	it(
		"stops auto-roll on tokens, a full bag, the rarity gate, a new item, or an upgrade",
		function()
			expect(RollLoop.stopReason(stopInput({}))).toBeNil()
			expect(RollLoop.stopReason(stopInput({ tokens = 0 }))).toEqual("tokens")
			expect(RollLoop.stopReason(stopInput({ tokens = 0, bagFull = true, isNew = true }))).toEqual(
				"tokens"
			)
			expect(RollLoop.stopReason(stopInput({ bagFull = true }))).toEqual("bag")
			expect(
				RollLoop.stopReason(stopInput({ bagFull = true, rarity = "Rare", isNew = true }))
			).toEqual("bag")
			expect(RollLoop.stopReason(stopInput({ rarity = "Rare" }))).toEqual("rarity")
			expect(RollLoop.stopReason(stopInput({ rarity = "Legendary" }))).toEqual("rarity")
			expect(RollLoop.stopReason(stopInput({ rarity = "Legendary", stopAt = "Off" }))).toBeNil()
			expect(
				RollLoop.stopReason(stopInput({ rarity = "Epic", isNew = true, isUpgrade = true }))
			).toEqual("rarity")
			expect(RollLoop.stopReason(stopInput({ isNew = true }))).toEqual("new")
			expect(RollLoop.stopReason(stopInput({ isNew = true, isUpgrade = true }))).toEqual(
				"new"
			)
			expect(RollLoop.stopReason(stopInput({ isUpgrade = true }))).toEqual("upgrade")
			expect(
				RollLoop.stopReason(stopInput({ auto = false, isNew = true, rarity = "Legendary" }))
			).toBeNil()
			expect(RollLoop.blocked(0, false)).toEqual("tokens")
			expect(RollLoop.blocked(2, true)).toEqual("bag")
			expect(RollLoop.blocked(2, false)).toBeNil()
		end
	)

	it("keeps commons short and uses the real rarity while slowing down", function()
		local settings = Settings.default()
		settings.rolls.skipAt = "off"
		expect(RollLoop.seconds(settings, "Common", true, false)).toEqual(0.6)
		expect(RollLoop.seconds(settings, "Common", false, false)).toEqual(0.6)
		expect(RollLoop.seconds(settings, "Uncommon", true, false)).toEqual(0.6)
		expect(RollLoop.seconds(settings, "Rare", true, false)).toEqual(0.9)
		expect(RollLoop.seconds(settings, "Rare", false, false)).toEqual(1.1)
		expect(RollLoop.seconds(settings, "Epic", false, false)).toEqual(1.65)
		expect(RollLoop.seconds(settings, "Epic", true, false)).toEqual(1.1)
		settings.rolls.animation = "short"
		expect(RollLoop.seconds(settings, "Epic", false, false)).toEqual(0.7)
		expect(RollLoop.seconds(settings, "Common", false, false)).toEqual(0.6)
		settings.rolls.animation = "instant"
		expect(RollLoop.seconds(settings, "Epic", false, false)).toEqual(0)
		settings.rolls.animation = "full"
		expect(RollLoop.seconds(settings, "Epic", false, true)).toEqual(0)
		local skipped = Settings.default()
		expect(RollLoop.seconds(skipped, "Legendary", false, false)).toEqual(0)
		expect(RollLoop.seconds(skipped, "Epic", false, false)).toEqual(1.65)

		local duration = RollLoop.seconds(settings, "Common", true, false)
		expect(RollLoop.tint(0, duration, "Common")).toBeNil()
		local elapsed = 0.9 / 1.65 * duration
		local shown = RollLoop.tint(elapsed, duration, "Common")
		expect(shown).toEqual("Common")
		expect(shown == "Legendary").toEqual(false)

		local epic = RollLoop.seconds(settings, "Epic", false, false)
		local slowed = false
		for step = 0, 100 do
			local at = epic * step / 100
			if RollLoop.slowmo(at, epic, "Epic", false) then
				slowed = true
				expect(RollLoop.slowmo(at, epic, "Common", false)).toEqual(false)
				expect(RollLoop.tint(at, epic, "Epic")).toEqual("Epic")
			end
		end
		expect(slowed).toEqual(true)
		expect(RollLoop.slowmo(epic * 0.8, epic, "Epic", true)).toEqual(false)
		expect(RollLoop.flash("Epic", false, false)).toEqual(true)
		expect(RollLoop.flash("Common", false, false)).toEqual(false)
		expect(RollLoop.flash("Legendary", true, false)).toEqual(false)
		expect(RollLoop.flash("Legendary", false, true)).toEqual(false)
		expect(RollLoop.stinger("Common", false)).toEqual(false)
		expect(RollLoop.stinger("Epic", false)).toEqual(true)
		expect(RollLoop.stinger("Epic", true)).toEqual(false)
		expect(RollLoop.anticipates("Common", false)).toEqual(false)
		expect(RollLoop.anticipates("Rare", false)).toEqual(true)
		expect(RollLoop.anticipates("Rare", true)).toEqual(false)
	end)

	it("counts a real item, a real epic remainder, and a full bag", function()
		local drip = RollLoop.drip()
		expect(drip.amount).toEqual(1)
		expect(drip.text).toEqual("+1")
		expect(RollLoop.drip().amount).toEqual(1)
		expect(RollLoop.nextEpic(0)).toEqual(RarityConfig.EPIC_PITY)
		expect(RollLoop.nextEpic(90)).toEqual(10)
		expect(RollLoop.nextEpic(100)).toEqual(0)
		expect(RollLoop.nextEpic(nil)).toEqual(RarityConfig.EPIC_PITY)
		expect(RollLoop.nearGuarantee(89)).toEqual(false)
		expect(RollLoop.nearGuarantee(90)).toEqual(true)
		expect(RollLoop.streak(0, true)).toEqual(1)
		expect(RollLoop.streak(4, true)).toEqual(5)
		expect(RollLoop.streak(4, false)).toEqual(0)
		expect(RollLoop.isNew("blade", {})).toEqual(true)
		expect(RollLoop.isNew("blade", { blade = true })).toEqual(false)
		expect(RollLoop.junkAction("Common", "Rare", "salvage")).toEqual("salvage")
		expect(RollLoop.junkAction("Uncommon", "Rare", "keep")).toEqual("keep")
		expect(RollLoop.junkAction("Rare", "Rare", "salvage")).toEqual("show")
		expect(RollLoop.junkAction("Common", "Rare", "ask")).toEqual("show")
		expect(RollLoop.resolve("Common", "Rare", "salvage", true)).toEqual("equip")
		expect(RollLoop.resolve("Common", "Rare", "salvage", false)).toEqual("salvage")
		expect(RollLoop.resolve("Rare", "Rare", "salvage", false)).toEqual("show")
		expect(RollLoop.indexText(2, 10)).toEqual("Index  2/10")

		local worn = {
			uid = "old",
			kind = "Weapon",
			rarity = "Common",
			quality = 0,
			stars = 0,
			templateId = "old_blade",
		}
		local profile = {
			equipped = { weapon = "old", armor = {}, accessories = {} },
			inventory = { old = worn },
			pets = {},
		}
		local better = {
			uid = "new",
			kind = "Weapon",
			rarity = "Rare",
			quality = 0,
			stars = 0,
			templateId = "new_blade",
		}
		expect(RollLoop.isUpgrade(profile, better)).toEqual(true)
		local same = {
			uid = "other",
			kind = "Weapon",
			rarity = "Common",
			quality = 0,
			stars = 0,
		}
		expect(RollLoop.isUpgrade(profile, same)).toEqual(false)
		profile.equipped.weapon = nil
		expect(RollLoop.isUpgrade(profile, same)).toEqual(true)
		expect(RollLoop.bagFull(profile, nil)).toEqual(false)
		local packed = { inventory = {}, pets = {} }
		for index = 1, Schema.INVENTORY_CAP - 1 do
			packed.inventory[tostring(index)] = { uid = tostring(index) }
		end
		expect(RollLoop.bagFull(packed, nil)).toEqual(false)
		expect(RollLoop.bagFull(packed, "pending")).toEqual(true)
		expect(RollLoop.best(nil, worn)).toEqual(worn)
		expect(RollLoop.best(worn, better).uid).toEqual("new")
		expect(RollLoop.best(better, worn).uid).toEqual("new")

		local owned = RollLoop.ownedTemplates({
			inventory = {
				new = { uid = "new", templateId = "new_blade" },
				old = { uid = "old", templateId = "old_blade" },
			},
			pets = {},
		}, "new")
		expect(owned.new_blade).toBeNil()
		expect(owned.old_blade).toEqual(true)
		expect(RollLoop.discoveries(profile, { "fresh" }) >= 1).toEqual(true)
	end)

	it("keeps the hub roll on the roll tab", function()
		local root = "src/StarterPlayer/StarterPlayerScripts/ShardfallClient/"
		local hub = fs.readFile(root .. "MenuHub.luau")
		local client = fs.readFile(root .. "init.client.luau")
		expect(string.find(hub, "RollLoop", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "RollShard", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "scheduleAuto", 1, true)).toBeNil()
		expect(string.find(hub, "hooks.onRoll", 1, true)).toBeNil()
		expect(string.find(client, "handoffRoll", 1, true)).toBeNil()
	end)

	it("stops a chain when the hub, the roll tab, or the player is gone", function()
		local function chain(patch: { [string]: any }): RollLoop.ChainInput
			local input: RollLoop.ChainInput = {
				open = true,
				onRoll = true,
				alive = true,
				queued = false,
				holding = false,
				auto = true,
				tokens = 3,
				bagFull = false,
				rarity = "Common",
				stopAt = "Rare",
				isNew = false,
				isUpgrade = false,
			}
			for key, value in pairs(patch) do
				(input :: any)[key] = value
			end
			return input
		end
		expect(RollLoop.canChain(chain({}))).toEqual(true)
		expect(RollLoop.canChain(chain({ open = false }))).toEqual(false)
		expect(RollLoop.canChain(chain({ onRoll = false }))).toEqual(false)
		expect(RollLoop.canChain(chain({ alive = false }))).toEqual(false)
		expect(RollLoop.canChain(chain({ auto = false, holding = true }))).toEqual(true)
		expect(RollLoop.canChain(chain({ auto = false, queued = true }))).toEqual(true)
		expect(RollLoop.canChain(chain({ auto = false }))).toEqual(false)
		expect(RollLoop.canChain(chain({ tokens = 0 }))).toEqual(false)
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local roll = fs.readFile("src/ServerScriptService/ShardfallServer/RollService.luau")
		expect(string.find(hub, "RollLoop.canChain", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "humanoid.Died", 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "stopRollChain", 1, true) ~= nil).toBeTrue()
		expect(string.find(roll, "RollLoop.gap", 1, true) ~= nil).toBeTrue()
	end)

	it("makes the server wait out the reveal before the next crack", function()
		local settings = Settings.default()
		expect(RollLoop.gap(settings, nil, false, false)).toEqual(RarityConfig.COOLDOWN)
		expect(RollLoop.gap(settings, nil, false, true)).toEqual(RarityConfig.QUICK_COOLDOWN)
		expect(RollLoop.gap(settings, "Common", false, false)).toEqual(RarityConfig.COOLDOWN)
		local rare = RollLoop.seconds(settings, "Rare", false, false)
		expect(rare > RarityConfig.COOLDOWN).toBeTrue()
		expect(RollLoop.gap(settings, "Rare", false, false)).toEqual(rare)
		local epic = RollLoop.seconds(settings, "Epic", false, false)
		expect(RollLoop.gap(settings, "Epic", false, true)).toEqual(epic)
		local instant = Settings.normalize({ rolls = { animation = "instant" } })
		expect(RollLoop.gap(instant, "Epic", false, false)).toEqual(RarityConfig.COOLDOWN)
		local reduced = Settings.normalize({ camera = { flash = "reduced" } })
		expect(RollLoop.gap(reduced, "Legendary", false, false)).toEqual(RarityConfig.COOLDOWN)
	end)
end)
