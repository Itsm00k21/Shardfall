--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Rarities = require("../src/ReplicatedStorage/Shared/Rarities")
local FirstSession = require("../src/ReplicatedStorage/Shared/FirstSession")

local ERRORS = FirstSession.ERRORS
local CONFIG = FirstSession.CONFIG

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh()
	return FirstSession.fresh().state
end

local function rollOffer(rarity: string, element: string, classId: string, paid: any)
	return {
		rarity = rarity,
		element = element,
		classId = classId,
		paid = paid,
		odds = { Epic = 1, Secret = 1 },
		floor = "Epic",
		luck = 100,
		almost = "Mythic",
	}
end

local function chestOffer(
	weaponRarity: string,
	sockets: any,
	eggRarity: string,
	classId: string,
	paid: any
)
	return {
		classId = classId,
		paid = paid,
		odds = { Legendary = 1 },
		weapon = {
			kind = "Weapon",
			rarity = weaponRarity,
			sockets = sockets,
			classId = classId,
		},
		egg = {
			kind = "egg",
			rarity = eggRarity,
		},
	}
end

local function luaFiles(dir: string): { string }
	local found = {}
	for _, name in ipairs(fs.readDir(dir)) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			for _, child in ipairs(luaFiles(path)) do
				table.insert(found, child)
			end
		elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
			table.insert(found, path)
		end
	end
	return found
end

local function requiresSession(source: string): boolean
	local body = string.gsub(source, "FirstSessionKit", "")
	if string.find(body, "Shared.FirstSession", 1, true) ~= nil then
		return true
	end
	if string.find(body, "Shared/FirstSession", 1, true) ~= nil then
		return true
	end
	if string.find(body, "Parent.FirstSession", 1, true) ~= nil then
		return true
	end
	if string.find(body, 'WaitForChild("FirstSession")', 1, true) ~= nil then
		return true
	end
	if string.find(body, "WaitForChild('FirstSession')", 1, true) ~= nil then
		return true
	end
	if string.find(body, 'require("./FirstSession")', 1, true) ~= nil then
		return true
	end
	if string.find(body, "require('./FirstSession')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("FirstSession kit", function()
	it("starts open for a new player and closed for a returning player", function()
		local opened = FirstSession.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.state.returning).toEqual(false)
		expect(opened.state.granted).toEqual({
			roll = false,
			chest = false,
			miniboss = false,
			forge = false,
		})
		expect(identical(opened.state, FirstSession.fresh().state)).toEqual(false)
		expect(FirstSession.fresh({}).state).toEqual(opened.state)
		expect(FirstSession.fresh({ returning = false }).state).toEqual(opened.state)

		local rigged = FirstSession.rigged(opened.state)
		expect(rigged.ok).toEqual(true)
		expect(rigged.rigged).toEqual(true)
		expect(rigged.applies).toEqual({
			roll = true,
			chest = true,
			miniboss = true,
			forge = true,
		})
		expect(identical(rigged.state, opened.state)).toEqual(false)
		expect(opened.state.granted.roll).toEqual(false)

		local returning = FirstSession.fresh({ returning = true })
		expect(returning.ok).toEqual(true)
		expect(returning.state.returning).toEqual(true)
		expect(FirstSession.rigged(returning.state).rigged).toEqual(false)
		expect(FirstSession.rigged(returning.state).applies.roll).toEqual(false)
		expect(FirstSession.applies(returning.state, "roll").applies).toEqual(false)
		expect(FirstSession.applies(returning.state, "roll").rule).toBeNil()
	end)

	it("names the four floors and does not raise them", function()
		expect(FirstSession.STEPS).toEqual({ "roll", "chest", "miniboss", "forge" })
		expect(CONFIG.rollFloor).toEqual("Rare")
		expect(CONFIG.chestWeaponRarity).toEqual("Rare")
		expect(CONFIG.chestSockets).toEqual(1)
		expect(CONFIG.eggFloor).toEqual("Uncommon")
		expect(CONFIG.armorRarity).toEqual("Uncommon")
		expect(CONFIG.ringRarity).toEqual("Uncommon")
		expect(CONFIG.ringCost).toEqual(0)

		local state = fresh()
		local roll = FirstSession.applies(state, "roll", "warden")
		expect(roll.applies).toEqual(true)
		expect(roll.rule).toEqual({
			step = "roll",
			kind = "shard",
			floor = "Rare",
			orBetter = true,
			match = "class",
			classId = "warden",
			element = "Verdant",
		})
		expect(roll.rule.odds).toBeNil()

		local chest = FirstSession.applies(state, "chest", "frostblade")
		expect(chest.rule).toEqual({
			step = "chest",
			weapon = {
				kind = "Weapon",
				floor = "Rare",
				exact = true,
				sockets = 1,
				match = "class",
				classId = "frostblade",
			},
			egg = {
				kind = "egg",
				floor = "Uncommon",
				orBetter = true,
			},
		})

		local armor = FirstSession.applies(state, "miniboss")
		expect(armor.rule).toEqual({
			step = "miniboss",
			kind = "Armor",
			floor = "Uncommon",
			exact = true,
		})

		local ring = FirstSession.applies(state, "forge")
		expect(ring.rule).toEqual({
			step = "forge",
			kind = "Ring",
			floor = "Uncommon",
			exact = true,
			cost = 0,
		})
		expect(ring.rule.robux).toBeNil()
		expect(ring.rule.productId).toBeNil()
		expect(state.granted.forge).toEqual(false)
	end)
end)

describe("FirstSession roll", function()
	it("meets Rare or better only when the element matches the class", function()
		local classes = {
			{ id = "warden", element = "Verdant" },
			{ id = "tidecaller", element = "Tide" },
			{ id = "forgeborn", element = "Fire" },
			{ id = "frostblade", element = "Frost" },
			{ id = "voidcaster", element = "Void" },
		}
		local floor = Rarities.INDEX.Rare
		for _, classInfo in ipairs(classes) do
			for _, rarity in ipairs(Rarities.ORDER) do
				local result = FirstSession.meets("roll", {
					rarity = rarity,
					element = classInfo.element,
					classId = classInfo.id,
				})
				expect(result.ok).toEqual(true)
				expect(result.meets).toEqual(Rarities.INDEX[rarity] >= floor)
				expect(result.rule.floor).toEqual("Rare")
				expect(result.rule.orBetter).toEqual(true)
				expect(result.rule.element).toEqual(classInfo.element)
				expect(result.rule.classId).toEqual(classInfo.id)
			end
			local wrong = FirstSession.meets("roll", {
				rarity = "Rare",
				element = "Fire",
				classId = classInfo.id,
			})
			expect(wrong.meets).toEqual(classInfo.element == "Fire")
		end

		local rare = FirstSession.meets("roll", rollOffer("Rare", "Verdant", "warden", false))
		expect(rare.meets).toEqual(true)
		expect(rare.rule.floor).toEqual("Rare")
		local secret = FirstSession.meets("roll", rollOffer("Secret", "Verdant", "warden", false))
		expect(secret.meets).toEqual(true)
		local uncommon =
			FirstSession.meets("roll", rollOffer("Uncommon", "Verdant", "warden", false))
		expect(uncommon.meets).toEqual(false)
		expect(uncommon.rule.floor).toEqual("Rare")
	end)

	it("accepts the player's pick of two only when one pick is the class element", function()
		local picked = FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Fire",
			classId = "warden",
			picks = { "Verdant", "Fire" },
		})
		expect(picked.ok).toEqual(true)
		expect(picked.meets).toEqual(true)
		expect(picked.rule.picks).toEqual({ "Verdant", "Fire" })
		expect(picked.rule.element).toEqual("Verdant")

		local classPick = FirstSession.meets("roll", {
			rarity = "Epic",
			element = "Verdant",
			classId = "warden",
			picks = { "Fire", "Verdant" },
		})
		expect(classPick.meets).toEqual(true)

		local outside = FirstSession.meets("roll", {
			rarity = "Legendary",
			element = "Tide",
			classId = "warden",
			picks = { "Verdant", "Fire" },
		})
		expect(outside.ok).toEqual(true)
		expect(outside.meets).toEqual(false)
		expect(outside.rule.floor).toEqual("Rare")

		expect(FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Fire",
			classId = "warden",
			picks = { "Fire", "Frost" },
		}).error).toEqual(ERRORS.picks)
		expect(FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Verdant",
			classId = "warden",
			picks = { "Verdant" },
		}).error).toEqual(ERRORS.picks)
		expect(FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Verdant",
			classId = "warden",
			picks = { "Verdant", "Verdant" },
		}).error).toEqual(ERRORS.picks)

		local unmatched = FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Fire",
			classId = "warden",
		})
		expect(unmatched.meets).toEqual(false)
	end)

	it("uses the same Rare floor for a paid roll and a free roll", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local function rolled(paid: any)
			return rollOffer("Epic", "Tide", "tidecaller", paid)
		end
		local free = FirstSession.meets("roll", rolled(false))
		local paid = FirstSession.meets("roll", rolled(true))
		local omitted = FirstSession.meets("roll", rolled(nil))
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.rule.floor).toEqual("Rare")
		expect(paid.rule.orBetter).toEqual(true)
		expect(paid.odds).toBeNil()
		expect(paid.rule.odds).toBeNil()
		expect(paid.rule.luck).toBeNil()

		local freeLow =
			FirstSession.meets("roll", rollOffer("Uncommon", "Tide", "tidecaller", false))
		local paidLow =
			FirstSession.meets("roll", rollOffer("Uncommon", "Tide", "tidecaller", true))
		expect(paidLow).toEqual(freeLow)
		expect(paidLow.meets).toEqual(false)
		expect(paidLow.rule.floor).toEqual("Rare")

		local freeGrant = FirstSession.grant(state, "roll", rolled(false))
		local paidGrant = FirstSession.grant(state, "roll", rolled(true))
		expect(paidGrant).toEqual(freeGrant)
		expect(paidGrant.accepted).toEqual(true)
		expect(paidGrant.reward.rarity).toEqual("Epic")
		expect(paidGrant.reward.floor).toEqual("Rare")
		expect(paidGrant.reward.odds).toBeNil()
		expect(paidGrant.reward.paid).toBeNil()
		expect(paidGrant.reward.element).toEqual("Tide")
		expect(state.granted.roll).toEqual(false)

		local again = FirstSession.grant(
			paidGrant.state,
			"roll",
			rollOffer("Secret", "Tide", "tidecaller", true)
		)
		expect(again.ok).toEqual(true)
		expect(again.applies).toEqual(false)
		expect(again.accepted).toEqual(false)
		expect(again.reward).toBeNil()
		expect(again.rule).toBeNil()
		expect(again.state.granted.roll).toEqual(true)
		expect(paidGrant.state.granted.roll).toEqual(true)
	end)
end)

describe("FirstSession gear", function()
	it("accepts a Rare weapon with one socket and an Uncommon or better egg", function()
		local state = fresh()
		local offer = chestOffer("Rare", 1, "Uncommon", "warden", false)
		table.freeze(offer)
		table.freeze(offer.weapon)
		table.freeze(offer.egg)
		local met = FirstSession.meets("chest", offer)
		expect(met.meets).toEqual(true)
		expect(met.rule.weapon.sockets).toEqual(1)
		expect(met.rule.weapon.floor).toEqual("Rare")
		expect(met.rule.weapon.exact).toEqual(true)
		expect(met.rule.egg.floor).toEqual("Uncommon")
		expect(met.rule.egg.orBetter).toEqual(true)

		local granted = FirstSession.grant(state, "chest", offer)
		expect(granted.accepted).toEqual(true)
		expect(granted.reward.weapon).toEqual({
			kind = "Weapon",
			rarity = "Rare",
			sockets = 1,
			classId = "warden",
		})
		expect(granted.reward.egg.rarity).toEqual("Uncommon")
		expect(granted.reward.egg.floor).toEqual("Uncommon")
		expect(identical(granted.reward.weapon, offer.weapon)).toEqual(false)
		expect(offer.weapon.rarity).toEqual("Rare")
		expect(offer.weapon.sockets).toEqual(1)
		expect(state.granted.chest).toEqual(false)

		local betterEgg =
			FirstSession.meets("chest", chestOffer("Rare", 1, "Secret", "voidcaster", true))
		expect(betterEgg.meets).toEqual(true)
		local commonEgg =
			FirstSession.meets("chest", chestOffer("Rare", 1, "Common", "warden", false))
		expect(commonEgg.meets).toEqual(false)
		local epicWeapon =
			FirstSession.meets("chest", chestOffer("Epic", 1, "Uncommon", "warden", true))
		expect(epicWeapon.meets).toEqual(false)
		expect(epicWeapon.rule.weapon.floor).toEqual("Rare")
		local noSocket =
			FirstSession.meets("chest", chestOffer("Rare", 0, "Uncommon", "warden", false))
		expect(noSocket.meets).toEqual(false)
		local twoSockets =
			FirstSession.meets("chest", chestOffer("Rare", 2, "Rare", "warden", false))
		expect(twoSockets.meets).toEqual(false)

		local mismatched = chestOffer("Rare", 1, "Uncommon", "warden", false)
		mismatched.weapon.classId = "tidecaller"
		expect(FirstSession.meets("chest", mismatched).meets).toEqual(false)

		local paid =
			FirstSession.grant(state, "chest", chestOffer("Rare", 1, "Epic", "forgeborn", true))
		local free =
			FirstSession.grant(state, "chest", chestOffer("Rare", 1, "Epic", "forgeborn", false))
		expect(paid).toEqual(free)
		expect(paid.reward.weapon.rarity).toEqual("Rare")
		expect(paid.reward.egg.rarity).toEqual("Epic")
		expect(paid.reward.odds).toBeNil()
	end)

	it("accepts an Uncommon armor piece and a free Uncommon ring", function()
		local state = fresh()
		for _, rarity in ipairs(Rarities.ORDER) do
			local armor =
				FirstSession.meets("miniboss", { kind = "Armor", rarity = rarity, paid = true })
			local ring = FirstSession.meets(
				"forge",
				{ kind = "Ring", rarity = rarity, cost = 0, paid = false }
			)
			expect(armor.meets).toEqual(rarity == "Uncommon")
			expect(ring.meets).toEqual(rarity == "Uncommon")
			expect(armor.rule.floor).toEqual("Uncommon")
			expect(armor.rule.exact).toEqual(true)
			expect(ring.rule.floor).toEqual("Uncommon")
			expect(ring.rule.cost).toEqual(0)
			expect(ring.rule.exact).toEqual(true)
		end

		local armor = FirstSession.grant(state, "miniboss", {
			kind = "Armor",
			rarity = "Uncommon",
			paid = true,
			odds = { Epic = 1 },
		})
		expect(armor.accepted).toEqual(true)
		expect(armor.reward).toEqual({
			step = "miniboss",
			kind = "Armor",
			rarity = "Uncommon",
			floor = "Uncommon",
			exact = true,
		})
		expect(armor.reward.odds).toBeNil()
		expect(armor.reward.paid).toBeNil()

		local weapon = FirstSession.meets("miniboss", { kind = "Weapon", rarity = "Uncommon" })
		expect(weapon.meets).toEqual(false)
		local rareArmor =
			FirstSession.meets("miniboss", { kind = "Armor", rarity = "Rare", paid = true })
		expect(rareArmor.meets).toEqual(false)

		local ring = FirstSession.grant(state, "forge", {
			kind = "Ring",
			rarity = "Uncommon",
			paid = true,
			odds = { Epic = 1 },
		})
		expect(ring.accepted).toEqual(true)
		expect(ring.reward).toEqual({
			step = "forge",
			kind = "Ring",
			rarity = "Uncommon",
			floor = "Uncommon",
			exact = true,
			cost = 0,
		})
		expect(ring.reward.robux).toBeNil()
		expect(ring.reward.productId).toBeNil()
		expect(ring.reward.paid).toBeNil()

		local priced = FirstSession.meets("forge", { kind = "Ring", rarity = "Uncommon", cost = 5 })
		expect(priced.meets).toEqual(false)
		local robux = FirstSession.meets("forge", { kind = "Ring", rarity = "Uncommon", robux = 1 })
		expect(robux.meets).toEqual(false)
		local product = FirstSession.meets("forge", {
			kind = "Ring",
			rarity = "Uncommon",
			productId = "ring_pack",
		})
		expect(product.meets).toEqual(false)
		local epic = FirstSession.meets("forge", {
			kind = "Ring",
			rarity = "Epic",
			cost = 0,
			paid = true,
		})
		expect(epic.meets).toEqual(false)
		expect(epic.rule.floor).toEqual("Uncommon")
		expect(epic.rule.cost).toEqual(0)

		local paidArmor =
			FirstSession.meets("miniboss", { kind = "Armor", rarity = "Uncommon", paid = true })
		local freeArmor =
			FirstSession.meets("miniboss", { kind = "Armor", rarity = "Uncommon", paid = false })
		expect(paidArmor).toEqual(freeArmor)
	end)
end)

describe("FirstSession skip", function()
	it("grants each open step once and skips a step that was already granted", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local skipped = FirstSession.skip(state, { classId = "warden" })
		expect(skipped.ok).toEqual(true)
		expect(skipped.rewards).toEqual({
			{
				step = "roll",
				kind = "shard",
				floor = "Rare",
				orBetter = true,
				match = "class",
				classId = "warden",
				element = "Verdant",
			},
			{
				step = "chest",
				weapon = {
					kind = "Weapon",
					floor = "Rare",
					exact = true,
					sockets = 1,
					match = "class",
					classId = "warden",
				},
				egg = {
					kind = "egg",
					floor = "Uncommon",
					orBetter = true,
				},
			},
			{
				step = "miniboss",
				kind = "Armor",
				floor = "Uncommon",
				exact = true,
			},
			{
				step = "forge",
				kind = "Ring",
				floor = "Uncommon",
				exact = true,
				cost = 0,
			},
		})
		expect(skipped.rewards[4].robux).toBeNil()
		expect(skipped.rewards[1].rarity).toBeNil()
		expect(skipped.rewards[1].odds).toBeNil()
		expect(skipped.state.granted).toEqual({
			roll = true,
			chest = true,
			miniboss = true,
			forge = true,
		})
		expect(state.granted.roll).toEqual(false)
		expect(identical(skipped.state, state)).toEqual(false)
		expect(FirstSession.rigged(skipped.state).rigged).toEqual(false)

		local again = FirstSession.skip(skipped.state, { classId = "warden" })
		expect(again.ok).toEqual(true)
		expect(again.rewards).toEqual({})
		expect(again.state.granted).toEqual(skipped.state.granted)

		local rolled =
			FirstSession.grant(state, "roll", rollOffer("Rare", "Frost", "frostblade", false))
		expect(rolled.accepted).toEqual(true)
		local rest = FirstSession.skip(rolled.state, { classId = "frostblade" })
		expect(rest.ok).toEqual(true)
		expect(#rest.rewards).toEqual(3)
		expect(rest.rewards[1].step).toEqual("chest")
		expect(rest.rewards[2].step).toEqual("miniboss")
		expect(rest.rewards[3].step).toEqual("forge")
		expect(rest.state.granted.roll).toEqual(true)
		expect(rolled.state.granted.roll).toEqual(true)
		expect(rolled.state.granted.chest).toEqual(false)

		local late = FirstSession.grant(rest.state, "forge", { kind = "Ring", rarity = "Uncommon" })
		expect(late.accepted).toEqual(false)
		expect(late.applies).toEqual(false)
		expect(late.reward).toBeNil()
		expect(late.rule).toBeNil()
	end)

	it("refuses a paid skip and grants nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		local function refused(request: any)
			local result = FirstSession.skip(state, request)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.paid)
			expect(result.rewards).toEqual({})
			expect(result.state.granted.roll).toEqual(false)
			expect(result.state.granted.forge).toEqual(false)
			expect(identical(result.state, state)).toEqual(false)
		end
		refused({ classId = "warden", paid = true })
		refused({ classId = "warden", productId = "skip_intro" })
		refused({ classId = "warden", robux = 25 })
		refused({ classId = "warden", cost = 1 })
		expect(state.granted).toEqual({
			roll = false,
			chest = false,
			miniboss = false,
			forge = false,
		})

		local free =
			FirstSession.skip(state, { classId = "warden", paid = false, cost = 0, robux = 0 })
		expect(free.ok).toEqual(true)
		expect(#free.rewards).toEqual(4)
		expect(free.rewards[4].cost).toEqual(0)
		expect(state.granted.roll).toEqual(false)
	end)

	it("gives a returning player nothing", function()
		local state = FirstSession.fresh({ returning = true }).state
		table.freeze(state)
		table.freeze(state.granted)
		local skipped = FirstSession.skip(state, { classId = "warden" })
		expect(skipped.ok).toEqual(true)
		expect(skipped.rewards).toEqual({})
		expect(skipped.state.returning).toEqual(true)
		expect(skipped.state.granted.roll).toEqual(false)
		expect(state.granted.chest).toEqual(false)

		local granted =
			FirstSession.grant(state, "roll", rollOffer("Secret", "Verdant", "warden", true))
		expect(granted.ok).toEqual(true)
		expect(granted.applies).toEqual(false)
		expect(granted.meets).toEqual(true)
		expect(granted.accepted).toEqual(false)
		expect(granted.reward).toBeNil()
		expect(granted.rule).toBeNil()
		expect(granted.state.granted.roll).toEqual(false)
		expect(FirstSession.rigged(granted.state).rigged).toEqual(false)
	end)
end)

describe("FirstSession after the kit", function()
	it("rigs nothing once every step is granted", function()
		local state = fresh()
		local rolled = FirstSession.grant(state, "forge", { kind = "Ring", rarity = "Uncommon" })
		expect(rolled.accepted).toEqual(true)
		local armed =
			FirstSession.grant(rolled.state, "miniboss", { kind = "Armor", rarity = "Uncommon" })
		local geared =
			FirstSession.grant(armed.state, "chest", chestOffer("Rare", 1, "Rare", "warden", false))
		local done =
			FirstSession.grant(geared.state, "roll", rollOffer("Rare", "Verdant", "warden", false))
		expect(done.accepted).toEqual(true)
		expect(done.state.granted).toEqual({
			roll = true,
			chest = true,
			miniboss = true,
			forge = true,
		})
		local quiet = FirstSession.rigged(done.state)
		expect(quiet.rigged).toEqual(false)
		expect(quiet.applies).toEqual({
			roll = false,
			chest = false,
			miniboss = false,
			forge = false,
		})

		local later =
			FirstSession.grant(done.state, "roll", rollOffer("Secret", "Verdant", "warden", true))
		expect(later.ok).toEqual(true)
		expect(later.applies).toEqual(false)
		expect(later.accepted).toEqual(false)
		expect(later.reward).toBeNil()
		expect(later.rule).toBeNil()
		expect(later.state.granted).toEqual(done.state.granted)
		expect(FirstSession.applies(done.state, "chest").applies).toEqual(false)
		expect(FirstSession.applies(done.state, "chest").rule).toBeNil()
	end)

	it("returns a new table and does not write the input", function()
		local state = fresh()
		local offer = rollOffer("Rare", "Verdant", "warden", true)
		table.freeze(state)
		table.freeze(state.granted)
		table.freeze(offer)
		table.freeze(offer.odds)
		local granted = FirstSession.grant(state, "roll", offer)
		expect(granted.accepted).toEqual(true)
		expect(granted.reward.rarity).toEqual("Rare")
		expect(state.granted.roll).toEqual(false)
		expect(offer.rarity).toEqual("Rare")
		expect(offer.floor).toEqual("Epic")
		expect(offer.odds.Secret).toEqual(1)
		expect(identical(granted.state, state)).toEqual(false)
		expect(identical(granted.reward, offer)).toEqual(false)
		expect(identical(granted, FirstSession.grant(state, "roll", offer))).toEqual(false)

		local low = rollOffer("Common", "Verdant", "warden", true)
		table.freeze(low)
		local missed = FirstSession.grant(state, "roll", low)
		expect(missed.ok).toEqual(true)
		expect(missed.applies).toEqual(true)
		expect(missed.meets).toEqual(false)
		expect(missed.accepted).toEqual(false)
		expect(missed.reward).toBeNil()
		expect(missed.rule.floor).toEqual("Rare")
		expect(low.rarity).toEqual("Common")
		expect(state.granted.roll).toEqual(false)
		expect(identical(missed.state, state)).toEqual(false)
	end)
end)

describe("FirstSession inputs", function()
	it("refuses a bad record or offer without throwing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.granted)
		expect(FirstSession.fresh("no").error).toEqual(ERRORS.state)
		expect(FirstSession.fresh({ returning = "yes" }).error).toEqual(ERRORS.state)
		expect(FirstSession.fresh({ paid = true }).error).toEqual(ERRORS.state)
		expect(FirstSession.applies(nil, "roll").error).toEqual(ERRORS.state)
		expect(FirstSession.applies(state, "haven").error).toEqual(ERRORS.step)
		expect(FirstSession.applies(state, "roll", "Warden").error).toEqual(ERRORS.class)
		expect(FirstSession.meets("loot", { rarity = "Rare" }).error).toEqual(ERRORS.step)
		expect(FirstSession.meets("roll", nil).error).toEqual(ERRORS.offer)
		expect(FirstSession.meets("roll", { rarity = "Rare", element = "Verdant" }).error).toEqual(
			ERRORS.class
		)
		expect(FirstSession.meets("roll", {
			rarity = "nope",
			element = "Verdant",
			classId = "warden",
		}).error).toEqual(ERRORS.rarity)
		expect(FirstSession.meets("roll", {
			rarity = "Rare",
			element = "",
			classId = "warden",
		}).error).toEqual(ERRORS.offer)
		expect(FirstSession.meets("roll", {
			rarity = "Rare",
			element = "Verdant",
			classId = "warden",
			paid = "yes",
		}).error).toEqual(ERRORS.offer)
		expect(FirstSession.meets("chest", { weapon = { kind = "Weapon" } }).error).toEqual(
			ERRORS.offer
		)
		expect(
			FirstSession.meets("forge", { kind = "Ring", rarity = "Uncommon", cost = 1.5 }).error
		).toEqual(ERRORS.offer)
		expect(FirstSession.grant(state, "roll", { rarity = "Rare" }).ok).toEqual(false)
		expect(FirstSession.grant(state, "roll", { rarity = "Rare" }).accepted).toEqual(false)
		expect(state.granted.roll).toEqual(false)

		local skipped = FirstSession.skip(state, nil)
		expect(skipped.ok).toEqual(false)
		expect(skipped.rewards).toEqual({})
		expect(FirstSession.skip(state, {}).error).toEqual(ERRORS.class)
		expect(FirstSession.skip(state, { classId = "nope" }).error).toEqual(ERRORS.class)
		expect(state.granted).toEqual({
			roll = false,
			chest = false,
			miniboss = false,
			forge = false,
		})

		local forgeOnly = {
			returning = false,
			granted = {
				roll = true,
				chest = true,
				miniboss = true,
				forge = false,
			},
		}
		local ring = FirstSession.skip(forgeOnly, {})
		expect(ring.ok).toEqual(true)
		expect(ring.rewards).toEqual({
			{
				step = "forge",
				kind = "Ring",
				floor = "Uncommon",
				exact = true,
				cost = 0,
			},
		})
		expect(forgeOnly.granted.forge).toEqual(false)

		expect(FirstSession.rigged({ returning = false }).error).toEqual(ERRORS.state)
		expect(FirstSession.grant({
			returning = false,
			granted = { roll = false, chest = false, miniboss = false, forge = false, extra = true },
		}, "roll", rollOffer("Rare", "Verdant", "warden", false)).error).toEqual(ERRORS.state)
	end)

	it("freezes the error strings", function()
		expect(function()
			FirstSession.ERRORS.paid = "nope"
		end).toThrow()
		expect(function()
			FirstSession.CONFIG.rollFloor = "Epic"
		end).toThrow()
		expect(function()
			FirstSession.ELEMENTS.warden = "Fire"
		end).toThrow()
	end)
end)

describe("FirstSession isolation", function()
	it("is required only by the kit mint and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/FirstSession.luau")
		local requires = {}
		for path in string.gmatch(source, 'require%("([^"]+)"%)') do
			table.insert(requires, path)
		end
		expect(requires).toEqual({ "./Rarities" })
		expect(string.find(source, "math.random", 1, true)).toBeNil()
		expect(string.find(source, "os.time", 1, true)).toBeNil()
		expect(string.find(source, "os.clock", 1, true)).toBeNil()
		expect(string.find(source, "os.date", 1, true)).toBeNil()
		expect(string.find(source, "Random", 1, true)).toBeNil()
		expect(string.find(source, "GetService", 1, true)).toBeNil()
		expect(string.find(source, "DataStore", 1, true)).toBeNil()
		expect(string.find(source, "MemoryStore", 1, true)).toBeNil()
		expect(string.find(source, "Marketplace", 1, true)).toBeNil()
		expect(string.find(source, "task.", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresSession(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({ "src/ReplicatedStorage/Shared/FirstSessionKit.luau" })
	end)
end)
