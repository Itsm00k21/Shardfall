--!strict

-- Kevin, Oct 22: walking is fine with the Roll panel open, but the roll
-- reveal is full screen and must freeze the character for the whole roll
-- (x1, x10, auto) and always free it after: finish, skip, close, error
-- or a hung call (REVEAL_HOLD_MAX failsafe).

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GuiFake = require("./GuiFake")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")
local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local Keybinds = require("../src/ReplicatedStorage/Shared/Keybinds")

local entry = (Pools.get("verdant_armory") :: any).entries[1]

type Rig = {
	world: any,
	hub: any,
	screen: any,
	calls: { { name: string, enabled: boolean } },
	step: (seconds: number) -> (),
	humanoid: any,
}

-- noControls: no PlayerModule at all (a forked/missing ControlModule in
-- the live place). The Humanoid freeze alone must still stop the player.
local function rig(mode: string?, noControls: boolean?): Rig
	local world = GuiFake.world()
	if noControls ~= true then
		world.withControls()
	end
	local humanoid = world.withCharacter()
	local MenuHub = world.load("MenuHub")
	local count = 0
	local function item()
		count += 1
		return {
			uid = "u" .. count,
			templateId = entry.templateId,
			name = entry.name,
			rarity = "Rare",
			kind = entry.kind,
		}
	end
	local calls = {}
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string, ...)
			if name == "RollShard" or name == "RollShards" then
				table.insert(calls, { name = name, enabled = world.controls.enabled })
				if mode == "error" then
					error("server down")
				elseif mode == "hang" then
					return coroutine.yield()
				end
			end
			if name == "RollShard" then
				return {
					ok = true,
					item = item(),
					rarity = "Rare",
					fillerSeed = 3,
					pity = { sinceLegendary = 4 },
				}
			end
			if name == "RollShards" then
				local items = {}
				for index = 1, 10 do
					table.insert(items, {
						item = item(),
						rarity = "Rare",
						fillerSeed = index,
						pity = { sinceLegendary = index },
					})
				end
				return { ok = true, items = items }
			end
			return { ok = true }
		end,
		onBag = function() end,
		onMarket = function() end,
		onDim = function() end,
	})
	hub.setProfile({
		level = 20,
		xp = 0,
		classId = "warden",
		classXp = { warden = 1800 },
		shardTokens = 50,
		gold = 0,
		shardRolls = 0,
		inventory = {},
		pets = {},
		equipped = {},
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	})
	hub.open("roll")
	world.clock.now = 100
	local function step(seconds: number)
		local left = seconds
		while left > 0 do
			world.clock.now += 0.1
			world.runService.Heartbeat:Fire(0.1)
			left -= 0.1
		end
	end
	return {
		world = world,
		hub = hub,
		screen = GuiFake.findNamed(world.playerGui, "ShardfallHub"),
		calls = calls,
		step = step,
		humanoid = humanoid,
	}
end

local function press(r: Rig, name: string)
	GuiFake.activate(GuiFake.findNamed(r.screen, name))
end

describe("Roll reveal movement lock", function()
	it("walks with the Roll page open before any roll", function()
		local r = rig()
		expect(r.world.controls.enabled).toEqual(true)
		expect(r.world.binds.ShardfallMenuSink ~= nil).toEqual(true)
		expect(r.world.controls.disables).toEqual(0)
	end)

	it("locks an x1 roll from the press (server wait included) and frees it after", function()
		local r = rig()
		local before = r.world.controls.enables
		press(r, "Roll")
		expect(#r.calls).toEqual(1)
		expect(r.calls[1].enabled).toEqual(false)
		expect(r.world.controls.enabled).toEqual(false)
		r.step(1)
		expect(r.world.controls.enabled).toEqual(false)
		r.step(6)
		expect(r.world.controls.enabled).toEqual(true)
		expect(r.world.controls.disables).toEqual(1)
		expect(r.world.controls.enables).toEqual(before + 1)
	end)

	it("keeps an x10 locked across all ten cards, then frees it once", function()
		local r = rig()
		local before = r.world.controls.enables
		press(r, "TimesTen")
		expect(#r.calls).toEqual(1)
		expect(r.calls[1].name).toEqual("RollShards")
		expect(r.calls[1].enabled).toEqual(false)
		for _ = 1, 30 do
			r.step(0.2)
			if r.world.controls.enabled then
				break
			end
		end
		-- Ten quick cards take a few seconds; no unlock in between.
		r.step(10)
		expect(r.world.controls.enabled).toEqual(true)
		expect(r.world.controls.disables).toEqual(1)
		expect(r.world.controls.enables).toEqual(before + 1)
	end)

	it("frees the player when the roll is skipped", function()
		local r = rig()
		press(r, "Roll")
		r.step(0.2)
		expect(r.world.controls.enabled).toEqual(false)
		press(r, "Roll")
		expect(r.world.controls.enabled).toEqual(true)
	end)

	it("frees the player when the hub closes mid-reveal", function()
		local r = rig()
		press(r, "Roll")
		r.step(0.2)
		expect(r.world.controls.enabled).toEqual(false)
		r.hub.close()
		expect(r.world.controls.enabled).toEqual(true)
		expect(r.world.binds.ShardfallMenuSink).toEqual(nil)
		r.step(5)
		expect(r.world.controls.enabled).toEqual(true)
	end)

	it("frees the player when the roll call errors", function()
		local r = rig("error")
		press(r, "Roll")
		expect(r.calls[1].enabled).toEqual(false)
		expect(r.world.controls.enabled).toEqual(true)
	end)

	it("frees the player after REVEAL_HOLD_MAX when the call hangs", function()
		local r = rig("hang")
		local thread = coroutine.create(function()
			press(r, "Roll")
		end)
		coroutine.resume(thread)
		expect(coroutine.status(thread)).toEqual("suspended")
		expect(r.world.controls.enabled).toEqual(false)
		r.step(Keybinds.REVEAL_HOLD_MAX - 1)
		expect(r.world.controls.enabled).toEqual(false)
		r.step(2)
		expect(r.world.controls.enabled).toEqual(true)
		-- The late reply is dropped and cannot lock again.
		coroutine.resume(thread, {
			ok = true,
			item = { uid = "late", templateId = entry.templateId, rarity = "Rare" },
			rarity = "Rare",
		})
		r.step(5)
		expect(r.world.controls.enabled).toEqual(true)
	end)

	it("expires holds only after REVEAL_HOLD_MAX", function()
		expect(Keybinds.holdExpired(10, 10 + Keybinds.REVEAL_HOLD_MAX - 0.5)).toEqual(false)
		expect(Keybinds.holdExpired(10, 10 + Keybinds.REVEAL_HOLD_MAX + 0.5)).toEqual(true)
		expect(Keybinds.holdExpired(nil, 10)).toEqual(true)
	end)
end)

describe("Roll reveal freezes the Humanoid, not just the PlayerModule", function()
	-- Kevin, Oct 22 9:55 PM: controls:Disable() alone let the character run
	-- left and right behind the x1 and x10 reveals in live Studio.
	local function frozen(r: Rig): boolean
		return r.humanoid.WalkSpeed == 0 and r.humanoid.JumpPower == 0 and r.humanoid.JumpHeight == 0
	end
	local function restored(r: Rig): boolean
		return r.humanoid.WalkSpeed == 16 and r.humanoid.JumpPower == 50 and r.humanoid.JumpHeight == 7.2
	end

	it("leaves WalkSpeed alone on the walkable Roll page", function()
		local r = rig(nil, true)
		expect(restored(r)).toEqual(true)
	end)

	it("freezes an x1 roll from the press to the end with no PlayerModule", function()
		local r = rig(nil, true)
		press(r, "Roll")
		expect(frozen(r)).toEqual(true)
		r.step(1)
		expect(frozen(r)).toEqual(true)
		r.step(6)
		expect(restored(r)).toEqual(true)
	end)

	it("keeps an x10 frozen across every card, then restores once", function()
		local r = rig(nil, true)
		press(r, "TimesTen")
		local thawedEarly = false
		local elapsed = 0
		while r.hub ~= nil and elapsed < 2 do
			r.step(0.2)
			elapsed += 0.2
			if not frozen(r) then
				thawedEarly = true
			end
		end
		expect(thawedEarly).toEqual(false)
		r.step(12)
		expect(restored(r)).toEqual(true)
	end)

	it("restores on skip, close, error and the hang failsafe", function()
		local skip = rig(nil, true)
		press(skip, "Roll")
		skip.step(0.2)
		press(skip, "Roll")
		expect(restored(skip)).toEqual(true)

		local closed = rig(nil, true)
		press(closed, "Roll")
		closed.step(0.2)
		closed.hub.close()
		expect(restored(closed)).toEqual(true)

		local failed = rig("error", true)
		press(failed, "Roll")
		expect(restored(failed)).toEqual(true)

		local hung = rig("hang", true)
		local thread = coroutine.create(function()
			press(hung, "Roll")
		end)
		coroutine.resume(thread)
		expect(frozen(hung)).toEqual(true)
		hung.step(Keybinds.REVEAL_HOLD_MAX + 1)
		expect(restored(hung)).toEqual(true)
	end)

	it("restores to defaults, never zero, if it froze an already-zero Humanoid", function()
		local r = rig(nil, true)
		r.humanoid.WalkSpeed = 0
		press(r, "Roll")
		r.step(8)
		expect(r.humanoid.WalkSpeed).toEqual(16)
	end)
end)
