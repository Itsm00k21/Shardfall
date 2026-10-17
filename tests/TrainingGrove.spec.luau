--!strict

local fs = require("@lune/fs")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local TrainingGrove = require("../src/ReplicatedStorage/Shared/TrainingGrove")

local ERRORS = TrainingGrove.ERRORS
local CONFIG = TrainingGrove.CONFIG

local function identical(left: any, right: any): boolean
	return left == right
end

local function fresh()
	return TrainingGrove.fresh().state
end

local function blankColors()
	return {
		red = false,
		yellow = false,
		purple = false,
		blue = false,
	}
end

local function blankState()
	return {
		hits = 0,
		damage = 0,
		healing = 0,
		up = true,
		dummy = false,
		dodge = false,
		colors = blankColors(),
		room = false,
		cosmetic = false,
	}
end

local function paysNothing(result: any)
	expect(result.keys).toEqual(0)
	expect(result.gold).toEqual(0)
	expect(result.payout).toBeNil()
	expect(result.reward).toBeNil()
	expect(result.quest).toBeNil()
	expect(result.robux).toBeNil()
	expect(result.productId).toBeNil()
	expect(result.blocked).toBeNil()
	expect(result.required).toBeNil()
end

local function finish(state)
	local hit = TrainingGrove.hit(state, { damage = 30 })
	local healed = TrainingGrove.heal(hit.state, { healing = 10 })
	local dodged = TrainingGrove.dodge(healed.state, { color = "red" })
	local current = dodged.state
	for _, color in ipairs({ "yellow", "blue", "purple", "red" }) do
		local marked = TrainingGrove.color(current, { color = color })
		expect(marked.ok).toEqual(true)
		current = marked.state
	end
	return current
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

local function requiresGrove(source: string): boolean
	if string.find(source, "Shared.TrainingGrove", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Shared/TrainingGrove", 1, true) ~= nil then
		return true
	end
	if string.find(source, "Parent.TrainingGrove", 1, true) ~= nil then
		return true
	end
	if string.find(source, 'WaitForChild("TrainingGrove")', 1, true) ~= nil then
		return true
	end
	if string.find(source, "WaitForChild('TrainingGrove')", 1, true) ~= nil then
		return true
	end
	return false
end

describe("TrainingGrove rules", function()
	it("freezes the grove config and starts with the dummy up", function()
		local opened = TrainingGrove.fresh()
		expect(opened.ok).toEqual(true)
		expect(opened.state).toEqual(blankState())
		expect(opened.blocked).toBeNil()
		expect(identical(opened.state, TrainingGrove.fresh().state)).toEqual(false)
		expect(identical(opened.state.colors, TrainingGrove.fresh().state.colors)).toEqual(false)
		expect(TrainingGrove.fresh({}).state).toEqual(opened.state)

		expect(CONFIG.dummyHits).toEqual(1)
		expect(CONFIG.staysUp).toEqual(true)
		expect(CONFIG.window).toEqual(10)
		expect(CONFIG.colors).toEqual({ "red", "yellow", "purple", "blue" })
		expect(CONFIG.dodgeColor).toEqual("red")
		expect(CONFIG.cosmeticId).toEqual("grove_ribbon")
		expect(CONFIG.keys).toEqual(0)
		expect(CONFIG.gold).toEqual(0)
		local keys = 0
		for _ in pairs(CONFIG) do
			keys += 1
		end
		expect(keys).toEqual(8)
		expect(opened.state.up).toEqual(true)
		expect(opened.state.dummy).toEqual(false)
		expect(opened.state.cosmetic).toEqual(false)
		expect(TrainingGrove.hint).toBeNil()
		expect(TrainingGrove.unlock).toBeNil()
		expect(TrainingGrove.jump).toBeNil()
		expect(opened.state.bossId).toBeNil()
		expect(opened.state.phase).toBeNil()
	end)
end)

describe("TrainingGrove hit", function()
	it("counts one finite hit, adds its damage, and leaves the dummy up", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local hit = { damage = 4 }
		table.freeze(hit)
		local struck = TrainingGrove.hit(state, hit)
		expect(struck.ok).toEqual(true)
		expect(struck.counted).toEqual(true)
		expect(struck.hits).toEqual(1)
		expect(struck.damage).toEqual(4)
		expect(struck.dummy).toEqual(true)
		expect(struck.up).toEqual(true)
		expect(struck.state.up).toEqual(true)
		expect(struck.state.dummy).toEqual(true)
		expect(struck.state.dodge).toEqual(false)
		expect(struck.state.room).toEqual(false)
		expect(struck.state.cosmetic).toEqual(false)
		expect(struck.state.colors).toEqual(blankColors())
		expect(struck.down).toBeNil()
		expect(struck.dead).toBeNil()
		expect(struck.fallen).toBeNil()
		expect(struck.hp).toBeNil()
		paysNothing(struck)
		expect(state.hits).toEqual(0)
		expect(state.damage).toEqual(0)
		expect(state.dummy).toEqual(false)
		expect(hit.damage).toEqual(4)
		expect(identical(struck.state, state)).toEqual(false)
		expect(identical(struck.state.colors, state.colors)).toEqual(false)
		expect(identical(struck, TrainingGrove.hit(state, hit))).toEqual(false)

		local zero = TrainingGrove.hit(fresh(), { damage = 0 })
		expect(zero.ok).toEqual(true)
		expect(zero.counted).toEqual(true)
		expect(zero.hits).toEqual(1)
		expect(zero.damage).toEqual(0)
		expect(zero.dummy).toEqual(true)
		expect(zero.up).toEqual(true)
		paysNothing(zero)

		local again = TrainingGrove.hit(struck.state, { damage = 1.5 })
		expect(again.ok).toEqual(true)
		expect(again.hits).toEqual(2)
		expect(again.damage).toEqual(5.5)
		expect(again.dummy).toEqual(true)
		expect(again.up).toEqual(true)
		expect(again.state.cosmetic).toEqual(false)
		expect(struck.state.hits).toEqual(1)
		expect(struck.state.damage).toEqual(4)
		paysNothing(again)

		local current = fresh()
		for _ = 1, 20 do
			local step = TrainingGrove.hit(current, { damage = 1 })
			expect(step.ok).toEqual(true)
			expect(step.up).toEqual(true)
			expect(step.state.up).toEqual(true)
			expect(step.state.cosmetic).toEqual(false)
			current = step.state
		end
		expect(current.hits).toEqual(20)
		expect(current.damage).toEqual(20)
		expect(current.dummy).toEqual(true)
		expect(current.up).toEqual(true)
	end)
end)

describe("TrainingGrove heal", function()
	it("adds healing and completes nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local body = { healing = 6 }
		table.freeze(body)
		local healed = TrainingGrove.heal(state, body)
		expect(healed.ok).toEqual(true)
		expect(healed.healing).toEqual(6)
		expect(healed.dummy).toEqual(false)
		expect(healed.dodge).toEqual(false)
		expect(healed.room).toEqual(false)
		expect(healed.cosmetic).toEqual(false)
		expect(healed.up).toEqual(true)
		expect(healed.state.hits).toEqual(0)
		expect(healed.state.damage).toEqual(0)
		expect(healed.state.healing).toEqual(6)
		expect(healed.state.colors).toEqual(blankColors())
		paysNothing(healed)
		expect(healed.cosmeticId).toBeNil()
		expect(state.healing).toEqual(0)
		expect(body.healing).toEqual(6)
		expect(identical(healed.state, state)).toEqual(false)

		local zero = TrainingGrove.heal(state, { healing = 0 })
		expect(zero.ok).toEqual(true)
		expect(zero.healing).toEqual(0)
		expect(zero.dummy).toEqual(false)
		expect(zero.cosmetic).toEqual(false)

		local more = TrainingGrove.heal(healed.state, { healing = 1.25, paid = true })
		expect(more.ok).toEqual(true)
		expect(more.healing).toEqual(7.25)
		expect(more.dummy).toEqual(false)
		expect(more.dodge).toEqual(false)
		expect(more.room).toEqual(false)
		expect(more.cosmetic).toEqual(false)
		expect(healed.state.healing).toEqual(6)
		paysNothing(more)

		local struck = TrainingGrove.hit(fresh(), { damage = 3 })
		local after = TrainingGrove.heal(struck.state, { healing = 100 })
		expect(after.ok).toEqual(true)
		expect(after.dummy).toEqual(true)
		expect(after.dodge).toEqual(false)
		expect(after.room).toEqual(false)
		expect(after.cosmetic).toEqual(false)
		expect(after.state.hits).toEqual(1)
		expect(after.state.damage).toEqual(3)
		expect(after.up).toEqual(true)
		expect(struck.state.healing).toEqual(0)
	end)
end)

describe("TrainingGrove readout", function()
	it("returns damage, healing, dps, and hps for the caller elapsed and pays nothing", function()
		local state = fresh()
		local struck = TrainingGrove.hit(state, { damage = 30 })
		local healed = TrainingGrove.heal(struck.state, { healing = 10 })
		table.freeze(healed.state)
		table.freeze(healed.state.colors)
		local reading = TrainingGrove.readout(healed.state, { elapsed = 10 })
		local bare = TrainingGrove.readout(healed.state, 10)
		expect(reading.ok).toEqual(true)
		expect(reading.damage).toEqual(30)
		expect(reading.healing).toEqual(10)
		expect(reading.dps).toEqual(3)
		expect(reading.hps).toEqual(1)
		expect(reading.elapsed).toEqual(10)
		expect(reading.window).toEqual(10)
		expect(reading.state.cosmetic).toEqual(false)
		expect(reading.cosmeticId).toBeNil()
		expect(reading.cosmetic).toBeNil()
		paysNothing(reading)
		expect(bare).toEqual(reading)
		expect(identical(reading.state, healed.state)).toEqual(false)
		expect(healed.state.damage).toEqual(30)
		expect(healed.state.healing).toEqual(10)
		expect(healed.state.hits).toEqual(1)

		local fraction = TrainingGrove.readout(healed.state, { elapsed = 4 })
		expect(fraction.ok).toEqual(true)
		expect(fraction.dps).toEqual(7.5)
		expect(fraction.hps).toEqual(2.5)
		expect(fraction.window).toEqual(10)
		paysNothing(fraction)

		local idle = TrainingGrove.readout(healed.state, { elapsed = 0 })
		expect(idle.ok).toEqual(true)
		expect(idle.dps).toEqual(0)
		expect(idle.hps).toEqual(0)
		expect(idle.damage).toEqual(30)
		expect(idle.healing).toEqual(10)
		expect(idle.dps ~= idle.dps).toEqual(false)
		paysNothing(idle)

		local longer = TrainingGrove.readout(healed.state, { elapsed = 20 })
		expect(longer.ok).toEqual(true)
		expect(longer.dps).toEqual(1.5)
		expect(longer.hps).toEqual(0.5)
		expect(longer.window).toEqual(CONFIG.window)
		paysNothing(longer)

		local ready = finish(fresh())
		table.freeze(ready)
		table.freeze(ready.colors)
		local still = TrainingGrove.readout(ready, { elapsed = 10, paid = true })
		expect(still.ok).toEqual(true)
		expect(still.state.cosmetic).toEqual(false)
		expect(still.cosmeticId).toBeNil()
		expect(still.state.room).toEqual(true)
		paysNothing(still)
		expect(ready.cosmetic).toEqual(false)
	end)
end)

describe("TrainingGrove dodge", function()
	it("completes the course only on red and does not mark a color", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		for _, color in ipairs({ "yellow", "purple", "blue" }) do
			local missed = TrainingGrove.dodge(state, { color = color })
			expect(missed.ok).toEqual(true)
			expect(missed.color).toEqual(color)
			expect(missed.dodge).toEqual(false)
			expect(missed.completed).toEqual(false)
			expect(missed.state.dodge).toEqual(false)
			expect(missed.state.colors).toEqual(blankColors())
			expect(missed.state.dummy).toEqual(false)
			expect(missed.state.room).toEqual(false)
			expect(missed.state.cosmetic).toEqual(false)
			paysNothing(missed)
			expect(state.dodge).toEqual(false)
		end

		local paid = TrainingGrove.dodge(state, { color = "yellow", paid = true })
		local free = TrainingGrove.dodge(state, { color = "yellow", paid = false })
		expect(paid).toEqual(free)
		expect(paid.completed).toEqual(false)
		expect(paid.state.dodge).toEqual(false)

		local word = TrainingGrove.dodge(state, "red")
		local tabled = TrainingGrove.dodge(state, { color = "red" })
		expect(word.ok).toEqual(true)
		expect(word).toEqual(tabled)
		expect(word.completed).toEqual(true)
		expect(word.dodge).toEqual(true)
		expect(word.color).toEqual("red")
		expect(word.state.colors.red).toEqual(false)
		expect(word.state.room).toEqual(false)
		expect(word.state.dummy).toEqual(false)
		expect(word.state.cosmetic).toEqual(false)
		expect(word.up).toBeNil()
		expect(word.state.up).toEqual(true)
		paysNothing(word)
		expect(state.dodge).toEqual(false)
		expect(identical(word.state, state)).toEqual(false)
		expect(identical(word.state.colors, state.colors)).toEqual(false)

		table.freeze(word.state)
		table.freeze(word.state.colors)
		local second = TrainingGrove.dodge(word.state, { color = "red" })
		expect(second.ok).toEqual(true)
		expect(second.completed).toEqual(false)
		expect(second.dodge).toEqual(true)
		expect(second.state.dodge).toEqual(true)
		expect(word.state.dodge).toEqual(true)
		paysNothing(second)
	end)
end)

describe("TrainingGrove color", function()
	it("marks the four colors and completes the room only when all are marked", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local order = { "yellow", "blue", "purple", "red" }
		local current = state
		for index, color in ipairs(order) do
			local marked = TrainingGrove.color(current, { color = color })
			expect(marked.ok).toEqual(true)
			expect(marked.color).toEqual(color)
			expect(marked.marked).toEqual(true)
			expect(marked.state.dodge).toEqual(false)
			expect(marked.state.dummy).toEqual(false)
			expect(marked.state.cosmetic).toEqual(false)
			expect(marked.state.up).toEqual(true)
			paysNothing(marked)
			if index < 4 then
				expect(marked.room).toEqual(false)
				expect(marked.state.room).toEqual(false)
			else
				expect(marked.room).toEqual(true)
				expect(marked.state.room).toEqual(true)
			end
			expect(current.colors[color]).toEqual(false)
			expect(identical(marked.state.colors, current.colors)).toEqual(false)
			current = marked.state
		end
		expect(current.colors).toEqual({
			red = true,
			yellow = true,
			purple = true,
			blue = true,
		})
		expect(current.room).toEqual(true)
		expect(current.dodge).toEqual(false)
		expect(state.colors).toEqual(blankColors())

		table.freeze(current)
		table.freeze(current.colors)
		local again = TrainingGrove.color(current, "blue")
		expect(again.ok).toEqual(true)
		expect(again.marked).toEqual(false)
		expect(again.room).toEqual(true)
		expect(again.state.colors.blue).toEqual(true)
		expect(current.colors.blue).toEqual(true)
		paysNothing(again)

		local paid = TrainingGrove.color(state, { color = "blue", paid = true })
		local unpaid = TrainingGrove.color(state, { color = "blue" })
		expect(paid).toEqual(unpaid)
		expect(paid.marked).toEqual(true)
		expect(paid.room).toEqual(false)
		expect(paid.state.colors.blue).toEqual(true)
		expect(paid.state.colors.red).toEqual(false)
	end)
end)

describe("TrainingGrove clear", function()
	it("sets the cosmetic once when every station is done and pays nothing", function()
		local early = TrainingGrove.clear(fresh())
		expect(early.ok).toEqual(true)
		expect(early.ready).toEqual(false)
		expect(early.granted).toEqual(false)
		expect(early.cosmetic).toEqual(false)
		expect(early.cosmeticId).toBeNil()
		expect(early.blocked).toBeNil()
		paysNothing(early)
		expect(early.gold).toEqual(0)

		local hitOnly = TrainingGrove.hit(fresh(), { damage = 1 }).state
		expect(TrainingGrove.clear(hitOnly).granted).toEqual(false)
		expect(TrainingGrove.clear(hitOnly).cosmetic).toEqual(false)

		local dodged = TrainingGrove.dodge(hitOnly, { color = "red" }).state
		expect(TrainingGrove.clear(dodged).granted).toEqual(false)

		local almost = dodged
		for _, color in ipairs({ "red", "yellow", "purple" }) do
			almost = TrainingGrove.color(almost, { color = color }).state
		end
		local missing = TrainingGrove.clear(almost)
		expect(missing.ok).toEqual(true)
		expect(missing.ready).toEqual(false)
		expect(missing.granted).toEqual(false)
		expect(missing.cosmeticId).toBeNil()
		expect(missing.state.cosmetic).toEqual(false)
		paysNothing(missing)
		expect(almost.room).toEqual(false)

		local noDodge = fresh()
		noDodge = TrainingGrove.hit(noDodge, { damage = 2 }).state
		for _, color in ipairs(CONFIG.colors) do
			noDodge = TrainingGrove.color(noDodge, { color = color }).state
		end
		expect(noDodge.room).toEqual(true)
		expect(TrainingGrove.clear(noDodge).granted).toEqual(false)
		expect(TrainingGrove.clear(noDodge).state.cosmetic).toEqual(false)

		local noDummy = TrainingGrove.dodge(fresh(), { color = "red" }).state
		for _, color in ipairs(CONFIG.colors) do
			noDummy = TrainingGrove.color(noDummy, { color = color }).state
		end
		expect(TrainingGrove.clear(noDummy).granted).toEqual(false)

		local ready = finish(fresh())
		expect(ready.dummy).toEqual(true)
		expect(ready.dodge).toEqual(true)
		expect(ready.room).toEqual(true)
		expect(ready.cosmetic).toEqual(false)
		expect(ready.up).toEqual(true)
		table.freeze(ready)
		table.freeze(ready.colors)
		local cleared = TrainingGrove.clear(ready)
		local paid = TrainingGrove.clear(ready, { paid = true })
		local unpaid = TrainingGrove.clear(ready, { paid = false })
		expect(cleared.ok).toEqual(true)
		expect(cleared.ready).toEqual(true)
		expect(cleared.granted).toEqual(true)
		expect(cleared.cosmetic).toEqual(true)
		expect(cleared.cosmeticId).toEqual("grove_ribbon")
		expect(cleared.state.cosmetic).toEqual(true)
		expect(cleared.state.up).toEqual(true)
		expect(cleared.blocked).toBeNil()
		paysNothing(cleared)
		expect(cleared.gold).toEqual(0)
		expect(cleared.keys).toEqual(0)
		expect(paid).toEqual(cleared)
		expect(unpaid).toEqual(cleared)
		expect(ready.cosmetic).toEqual(false)
		expect(identical(cleared.state, ready)).toEqual(false)
		expect(identical(cleared.state.colors, ready.colors)).toEqual(false)

		table.freeze(cleared.state)
		table.freeze(cleared.state.colors)
		local repeatClear = TrainingGrove.clear(cleared.state)
		expect(repeatClear.ok).toEqual(true)
		expect(repeatClear.ready).toEqual(true)
		expect(repeatClear.granted).toEqual(false)
		expect(repeatClear.cosmetic).toEqual(true)
		expect(repeatClear.cosmeticId).toBeNil()
		expect(repeatClear.state.cosmetic).toEqual(true)
		paysNothing(repeatClear)
		expect(repeatClear.gold).toEqual(0)
		expect(repeatClear.keys).toEqual(0)
		expect(cleared.state.cosmetic).toEqual(true)
		expect(identical(repeatClear.state, cleared.state)).toEqual(false)

		local healed = TrainingGrove.heal(cleared.state, { healing = 1 })
		expect(healed.ok).toEqual(true)
		expect(healed.cosmetic).toEqual(true)
		expect(healed.cosmeticId).toBeNil()
		expect(healed.state.cosmetic).toEqual(true)
		local shown = TrainingGrove.readout(cleared.state, { elapsed = 10 })
		expect(shown.cosmeticId).toBeNil()
		expect(shown.state.cosmetic).toEqual(true)
		paysNothing(shown)
	end)
end)

describe("TrainingGrove paid", function()
	it("does not complete a station just because the call was paid", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local dodge = TrainingGrove.dodge(state, { color = "blue", paid = true })
		expect(dodge.ok).toEqual(true)
		expect(dodge.completed).toEqual(false)
		expect(dodge.state.dodge).toEqual(false)
		paysNothing(dodge)

		local early = TrainingGrove.clear(state, { paid = true })
		expect(early.ok).toEqual(true)
		expect(early.granted).toEqual(false)
		expect(early.cosmetic).toEqual(false)
		expect(early.cosmeticId).toBeNil()
		paysNothing(early)
		expect(state.cosmetic).toEqual(false)

		local missing = TrainingGrove.color(state, { paid = true })
		expect(missing.ok).toEqual(false)
		expect(missing.marked).toEqual(false)
		expect(missing.room).toEqual(false)
		paysNothing(missing)

		local bare = TrainingGrove.hit(state, { paid = true })
		expect(bare.ok).toEqual(false)
		expect(bare.counted).toEqual(false)
		expect(bare.dummy).toEqual(false)
		expect(bare.state.hits).toEqual(0)
		paysNothing(bare)

		local free = TrainingGrove.hit(state, { damage = 2, paid = false })
		local paid = TrainingGrove.hit(state, { damage = 2, paid = true })
		local omitted = TrainingGrove.hit(state, { damage = 2 })
		expect(paid).toEqual(free)
		expect(omitted).toEqual(free)
		expect(paid.dummy).toEqual(true)
		expect(paid.counted).toEqual(true)
		paysNothing(paid)
		expect(state.hits).toEqual(0)
	end)

	it("refuses a paid skip and grants nothing", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local ready = finish(fresh())
		table.freeze(ready)
		table.freeze(ready.colors)
		local function refused(extra: { [string]: any })
			local function payload(base: { [string]: any })
				local copy: { [string]: any } = {}
				for key, value in pairs(base) do
					copy[key] = value
				end
				for key, value in pairs(extra) do
					copy[key] = value
				end
				return copy
			end
			local struck = TrainingGrove.hit(state, payload({ damage = 5 }))
			expect(struck.ok).toEqual(false)
			expect(struck.error).toEqual(ERRORS.paid)
			expect(struck.counted).toEqual(false)
			expect(struck.dummy).toEqual(false)
			expect(struck.state.hits).toEqual(0)
			paysNothing(struck)
			expect(struck.productId).toBeNil()
			expect(struck.robux).toBeNil()

			local dodged = TrainingGrove.dodge(state, payload({ color = "red" }))
			expect(dodged.ok).toEqual(false)
			expect(dodged.error).toEqual(ERRORS.paid)
			expect(dodged.completed).toEqual(false)
			expect(dodged.state.dodge).toEqual(false)
			paysNothing(dodged)

			local marked = TrainingGrove.color(ready, payload({ color = "blue" }))
			expect(marked.ok).toEqual(false)
			expect(marked.error).toEqual(ERRORS.paid)
			expect(marked.marked).toEqual(false)
			expect(marked.state.cosmetic).toEqual(false)
			paysNothing(marked)

			local cleared = TrainingGrove.clear(ready, payload({}))
			expect(cleared.ok).toEqual(false)
			expect(cleared.error).toEqual(ERRORS.paid)
			expect(cleared.granted).toEqual(false)
			expect(cleared.cosmetic).toEqual(false)
			expect(cleared.cosmeticId).toBeNil()
			expect(cleared.state.cosmetic).toEqual(false)
			paysNothing(cleared)
			expect(ready.cosmetic).toEqual(false)

			local reading = TrainingGrove.readout(ready, payload({ elapsed = 10 }))
			expect(reading.ok).toEqual(false)
			expect(reading.error).toEqual(ERRORS.paid)
			expect(reading.dps).toEqual(0)
			expect(reading.cosmeticId).toBeNil()
			paysNothing(reading)

			local healed = TrainingGrove.heal(state, payload({ healing = 4 }))
			expect(healed.ok).toEqual(false)
			expect(healed.error).toEqual(ERRORS.paid)
			expect(healed.healing).toEqual(0)
			expect(healed.cosmetic).toEqual(false)
			paysNothing(healed)
		end
		refused({ productId = "grove_skip" })
		refused({ robux = 25 })
		refused({ robux = 0 })
		refused({ cost = 1 })
		refused({ cost = 0 })
		refused({ skip = true })
		refused({ skip = false })
		expect(state).toEqual(blankState())
		expect(ready.cosmetic).toEqual(false)
		expect(ready.dummy).toEqual(true)
	end)
end)

describe("TrainingGrove inputs", function()
	it("refuses a bad hit, a non-red miss is not an error, and unknown colors fail", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		local function badHit(damage: any, err: string)
			local body = { damage = damage }
			table.freeze(body)
			local result = TrainingGrove.hit(state, body)
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(err)
			expect(result.counted).toEqual(false)
			expect(result.hits).toEqual(0)
			expect(result.damage).toEqual(0)
			expect(result.dummy).toEqual(false)
			expect(result.state).toEqual(blankState())
			paysNothing(result)
			expect(state.hits).toEqual(0)
			expect(state.damage).toEqual(0)
		end
		badHit(0 / 0, ERRORS.damage)
		badHit(math.huge, ERRORS.damage)
		badHit(-math.huge, ERRORS.damage)
		badHit(-1, ERRORS.damage)
		badHit(-0.1, ERRORS.damage)
		badHit("1", ERRORS.damage)
		badHit(true, ERRORS.damage)
		badHit({}, ERRORS.damage)
		expect(TrainingGrove.hit(state, nil).error).toEqual(ERRORS.hit)
		expect(TrainingGrove.hit(state, { damage = 1, amount = 1 }).error).toEqual(ERRORS.hit)
		expect(TrainingGrove.hit(state, { 4 }).error).toEqual(ERRORS.hit)
		expect(TrainingGrove.hit(state, { damage = 1, elapsed = 10 }).error).toEqual(ERRORS.hit)

		local kept = TrainingGrove.hit(state, { damage = 8 })
		table.freeze(kept.state)
		table.freeze(kept.state.colors)
		local negative = TrainingGrove.hit(kept.state, { damage = -5 })
		expect(negative.ok).toEqual(false)
		expect(negative.error).toEqual(ERRORS.damage)
		expect(negative.state.hits).toEqual(1)
		expect(negative.state.damage).toEqual(8)
		expect(negative.counted).toEqual(false)
		expect(kept.state.damage).toEqual(8)
		expect(identical(negative.state, kept.state)).toEqual(false)

		local blown = TrainingGrove.hit(kept.state, { damage = 1e308 })
		expect(blown.ok).toEqual(true)
		local overflow = TrainingGrove.hit(blown.state, { damage = 1e308 })
		expect(overflow.ok).toEqual(false)
		expect(overflow.error).toEqual(ERRORS.damage)
		expect(overflow.state.hits).toEqual(2)
		expect(overflow.state.damage).toEqual(blown.state.damage)
		expect(overflow.counted).toEqual(false)
		expect(blown.state.hits).toEqual(2)

		local nanHeal = TrainingGrove.heal(state, { healing = 0 / 0 })
		expect(nanHeal.ok).toEqual(false)
		expect(nanHeal.error).toEqual(ERRORS.healing)
		expect(nanHeal.state.healing).toEqual(0)
		expect(nanHeal.dummy).toEqual(false)
		expect(TrainingGrove.heal(state, { healing = -2 }).error).toEqual(ERRORS.healing)
		expect(TrainingGrove.heal(state, { healing = math.huge }).error).toEqual(ERRORS.healing)
		expect(TrainingGrove.heal(kept.state, { healing = 1e308 }).ok).toEqual(true)
		local healOverflow = TrainingGrove.heal(
			TrainingGrove.heal(kept.state, { healing = 1e308 }).state,
			{ healing = 1e308 }
		)
		expect(healOverflow.ok).toEqual(false)
		expect(healOverflow.error).toEqual(ERRORS.healing)
		expect(healOverflow.cosmetic).toEqual(false)

		local function badElapsed(elapsed: any)
			local result = TrainingGrove.readout(kept.state, { elapsed = elapsed })
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.elapsed)
			expect(result.dps).toEqual(0)
			expect(result.hps).toEqual(0)
			expect(result.state.damage).toEqual(8)
			expect(result.cosmeticId).toBeNil()
			paysNothing(result)
			expect(kept.state.damage).toEqual(8)
		end
		badElapsed(0 / 0)
		badElapsed(math.huge)
		badElapsed(-math.huge)
		badElapsed(-1)
		badElapsed("10")
		expect(TrainingGrove.readout(kept.state, nil).error).toEqual(ERRORS.readout)
		expect(TrainingGrove.readout(kept.state, { elapsed = 1, window = 1 }).error).toEqual(
			ERRORS.readout
		)

		local hot = TrainingGrove.hit(fresh(), { damage = 1e308 })
		local rate = TrainingGrove.readout(hot.state, { elapsed = 1e-10 })
		expect(rate.ok).toEqual(false)
		expect(rate.error).toEqual(ERRORS.elapsed)
		expect(rate.dps).toEqual(0)
		expect(rate.hps).toEqual(0)
		expect(hot.state.damage).toEqual(1e308)

		local unknown = {
			"green",
			"orange",
			"white",
			"Red",
			"RED",
			"blue ",
			" red",
			"",
			"dodge",
			"stack",
			"spread",
			"interrupt",
			"grove",
		}
		for _, color in ipairs(unknown) do
			local dodged = TrainingGrove.dodge(state, { color = color })
			expect(dodged.ok).toEqual(false)
			expect(dodged.error).toEqual(ERRORS.color)
			expect(dodged.completed).toEqual(false)
			expect(dodged.color).toBeNil()
			expect(dodged.state.dodge).toEqual(false)
			expect(dodged.state.colors).toEqual(blankColors())
			local marked = TrainingGrove.color(state, { color = color })
			expect(marked.ok).toEqual(false)
			expect(marked.error).toEqual(ERRORS.color)
			expect(marked.marked).toEqual(false)
			expect(marked.room).toEqual(false)
			expect(marked.color).toBeNil()
			expect(marked.state.colors).toEqual(blankColors())
			expect(state.colors).toEqual(blankColors())
			expect(state.dodge).toEqual(false)
		end
		expect(TrainingGrove.dodge(state, { color = 1 }).error).toEqual(ERRORS.dodge)
		expect(TrainingGrove.dodge(state, nil).error).toEqual(ERRORS.dodge)
		expect(TrainingGrove.color(state, { color = true }).error).toEqual(ERRORS.color)
		expect(TrainingGrove.color(state, "Red").error).toEqual(ERRORS.color)
	end)

	it("refuses a bad record or a user id and does not write the input", function()
		local state = fresh()
		table.freeze(state)
		table.freeze(state.colors)
		expect(TrainingGrove.fresh("no").error).toEqual(ERRORS.state)
		expect(TrainingGrove.fresh({ paid = true }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.fresh({ returning = true }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.fresh({ userId = 7 }).error).toEqual(ERRORS.id)
		expect(TrainingGrove.fresh({ userId = 7 }).state).toEqual(blankState())
		expect(TrainingGrove.fresh({ userId = 7 }).userId).toBeNil()
		expect(TrainingGrove.fresh({ guildId = "grove" }).error).toEqual(ERRORS.id)
		local both = TrainingGrove.fresh({ userId = 1, productId = "skip" })
		expect(both.error).toEqual(ERRORS.id)
		expect(both.userId).toBeNil()
		expect(both.productId).toBeNil()
		expect(both.state.cosmetic).toEqual(false)

		expect(TrainingGrove.hit(nil, { damage = 1 }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.hit(nil, { damage = 1 }).state.hits).toEqual(0)
		expect(TrainingGrove.heal(nil, { healing = 1 }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.readout(nil, { elapsed = 1 }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.dodge(nil, { color = "red" }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.color(nil, { color = "red" }).error).toEqual(ERRORS.state)
		expect(TrainingGrove.clear(nil).error).toEqual(ERRORS.state)
		expect(TrainingGrove.clear(nil).granted).toEqual(false)
		expect(TrainingGrove.clear(state, "now").error).toEqual(ERRORS.clear)
		expect(TrainingGrove.clear(state, { gold = 15 }).error).toEqual(ERRORS.clear)
		expect(TrainingGrove.clear(state, { gold = 15 }).gold).toEqual(0)
		expect(TrainingGrove.clear(state, { gold = 15 }).granted).toEqual(false)
		expect(TrainingGrove.clear(state, { keys = 10 }).keys).toEqual(0)
		expect(TrainingGrove.clear(state, { cosmeticId = "mire_lamp" }).error).toEqual(ERRORS.clear)
		expect(TrainingGrove.clear(state, { cosmeticId = "mire_lamp" }).cosmeticId).toBeNil()
		expect(TrainingGrove.clear(state, { quest = "grove_course" }).error).toEqual(ERRORS.clear)
		expect(TrainingGrove.hit(state, { damage = 1, paid = "yes" }).error).toEqual(ERRORS.hit)

		local lied = blankState()
		lied.dummy = true
		expect(TrainingGrove.clear(lied).error).toEqual(ERRORS.state)
		expect(TrainingGrove.clear(lied).granted).toEqual(false)
		local fallen = blankState()
		fallen.up = false
		expect(TrainingGrove.hit(fallen, { damage = 1 }).error).toEqual(ERRORS.state)
		expect(fallen.up).toEqual(false)
		local ribbon = blankState()
		ribbon.cosmetic = true
		expect(TrainingGrove.clear(ribbon).error).toEqual(ERRORS.state)
		expect(TrainingGrove.clear(ribbon).granted).toEqual(false)
		expect(ribbon.cosmetic).toEqual(true)
		local room = blankState()
		room.room = true
		expect(TrainingGrove.color(room, { color = "red" }).error).toEqual(ERRORS.state)
		local extra = blankState()
		extra.blocked = true
		expect(TrainingGrove.clear(extra).error).toEqual(ERRORS.state)
		expect(TrainingGrove.clear(extra).blocked).toBeNil()
		local tint = blankColors()
		tint.green = true
		local tinted = blankState()
		tinted.colors = tint
		expect(TrainingGrove.dodge(tinted, { color = "red" }).error).toEqual(ERRORS.state)
		expect(tint.green).toEqual(true)

		local ready = finish(fresh())
		local snapshotHits = ready.hits
		local snapshotCosmetic = ready.cosmetic
		table.freeze(ready)
		table.freeze(ready.colors)
		local ranked = { color = "red", userId = 4, productId = "skip" }
		table.freeze(ranked)
		local mixed = TrainingGrove.dodge(ready, ranked)
		expect(mixed.ok).toEqual(false)
		expect(mixed.error).toEqual(ERRORS.id)
		expect(mixed.completed).toEqual(false)
		expect(mixed.state.dodge).toEqual(true)
		expect(mixed.userId).toBeNil()
		expect(mixed.productId).toBeNil()
		expect(ready.cosmetic).toEqual(snapshotCosmetic)
		expect(ready.hits).toEqual(snapshotHits)
		expect(ranked.userId).toEqual(4)

		local function refuseId(key: string, value: any)
			local result = TrainingGrove.hit(state, { damage = 3, [key] = value })
			expect(result.ok).toEqual(false)
			expect(result.error).toEqual(ERRORS.id)
			expect(result.counted).toEqual(false)
			expect(result.state.hits).toEqual(0)
			expect(result[key]).toBeNil()
			paysNothing(result)
			local marked = TrainingGrove.color(state, { color = "blue", [key] = value })
			expect(marked.ok).toEqual(false)
			expect(marked.error).toEqual(ERRORS.id)
			expect(marked.marked).toEqual(false)
			expect(marked[key]).toBeNil()
			local cleared = TrainingGrove.clear(ready, { [key] = value })
			expect(cleared.ok).toEqual(false)
			expect(cleared.error).toEqual(ERRORS.id)
			expect(cleared.granted).toEqual(false)
			expect(cleared.cosmeticId).toBeNil()
			expect(cleared.state.cosmetic).toEqual(false)
			expect(ready.cosmetic).toEqual(false)
		end
		refuseId("userId", 15)
		refuseId("UserId", 15)
		refuseId("playerId", 15)
		refuseId("PlayerId", 15)
		refuseId("guildId", "haven")
		refuseId("GuildId", "haven")

		local carried = blankState()
		carried.guildId = "plaza"
		local hidden = TrainingGrove.clear(carried)
		expect(hidden.error).toEqual(ERRORS.id)
		expect(hidden.granted).toEqual(false)
		expect(hidden.guildId).toBeNil()
		expect(hidden.state.guildId).toBeNil()
		expect(carried.guildId).toEqual("plaza")
		expect(state).toEqual(blankState())
	end)

	it("freezes the grove tables", function()
		expect(function()
			TrainingGrove.ERRORS.paid = "nope"
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.dummyHits = 3
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.keys = 15
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.gold = 15
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.staysUp = false
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.window = 8
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.colors[1] = "green"
		end).toThrow()
		expect(function()
			TrainingGrove.CONFIG.cosmeticId = "mire_lamp"
		end).toThrow()
	end)
end)

describe("TrainingGrove isolation", function()
	it("is required by nothing in src and does not roll, wait, or read the clock", function()
		local source = fs.readFile("src/ReplicatedStorage/Shared/TrainingGrove.luau")
		expect(string.find(source, "require(", 1, true)).toBeNil()
		expect(string.find(source, "CombatFeel", 1, true)).toBeNil()
		expect(string.find(source, "RaidPractice", 1, true)).toBeNil()
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
		expect(string.find(source, "DateTime", 1, true)).toBeNil()
		expect(string.find(source, "tick(", 1, true)).toBeNil()
		local callers = {}
		for _, path in ipairs(luaFiles("src")) do
			if requiresGrove(fs.readFile(path)) then
				table.insert(callers, path)
			end
		end
		expect(callers).toEqual({})
	end)
end)
