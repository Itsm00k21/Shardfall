--!strict

--[[
	Stage C Shard Core. Essence spend, additive perks, copy-first save.
	The perk hook does not read item.upgrade. Pets are refused.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Classes = require("../src/ReplicatedStorage/Shared/Classes")
local Elements = require("../src/ReplicatedStorage/Shared/Config/Elements")
local EquipSlots = require("../src/ReplicatedStorage/Shared/Config/EquipSlots")
local EquipStats = require("../src/ReplicatedStorage/Shared/Config/EquipStats")
local GearLevels = require("../src/ReplicatedStorage/Shared/Config/GearLevels")
local LaunchGate = require("../src/ReplicatedStorage/Shared/LaunchGate")
local Schema = require("../src/ReplicatedStorage/Shared/Schema")
local ShardCore = require("../src/ReplicatedStorage/Shared/Config/ShardCore")
local UiTheme = require("../src/ReplicatedStorage/Shared/UiTheme")
local Dev = require("../src/server/ShardCore/Dev")
local Feed = require("../src/server/ShardCore/Feed")
local Perks = require("../src/server/ShardCore/Perks")
local Remotes = require("../src/server/ShardCore/Remotes")
local Save = require("../src/server/ShardCore/Save")
local Validate = require("../src/server/ShardCore/Validate")
local View = require("../src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ShardCore/View")
local EquipService = require("../src/server/EquipService/EquipService")

local function weapon(uid: string, upgrade: number?): any
	return {
		uid = uid,
		templateId = "bramble_fang",
		name = "Bramble Fang",
		kind = "Weapon",
		rarity = "Uncommon",
		upgrade = upgrade,
		stars = 2,
		stats = { { id = "damage", value = 12 }, { id = "crit_chance", value = 0.2 } },
	}
end

local function profile(): any
	return {
		gold = 80,
		gearEssence = 0,
		inventory = {},
		pets = {},
		equipped = { weapon = nil, pet = nil, armor = {}, accessories = {} },
		classId = "warden",
		classXp = { warden = 0 },
	}
end

local function equipCtx(gearOn: boolean, coreOn: boolean, applyCore: any): any
	return {
		slots = EquipSlots,
		stats = EquipStats,
		elements = Elements,
		classes = Classes,
		gearConfig = GearLevels,
		gearEnabled = gearOn,
		coreConfig = ShardCore,
		coreEnabled = coreOn,
		applyCore = applyCore,
	}
end

local function stat(view: any, id: string): number
	return view.stats.byId[id]
end

describe("Shard Core numbers", function()
	it("keeps the flag off and the curve modest", function()
		expect(LaunchGate.on("shardCore")).toEqual(false)
		expect(LaunchGate.SHOW.shardCore).toEqual(false)
		expect(ShardCore.CAP).toEqual(5)
		expect(ShardCore.COST).toEqual({ 5, 15, 40, 100, 250 })
		expect(ShardCore.DEV_GRANT).toEqual(100)
		expect(#ShardCore.PERKS).toEqual(5)
		local total = 0
		for index, cost in ipairs(ShardCore.COST) do
			expect(cost >= 1).toBeTrue()
			if index > 1 then
				expect(cost > ShardCore.COST[index - 1]).toBeTrue()
			end
			total += cost
		end
		expect(total).toEqual(410)
		local ids = {
			crit_chance = 0.01,
			shard_find = 0.02,
			move_speed = 0.02,
			crit_damage = 0.05,
			luck = 1,
		}
		for _, perk in ipairs(ShardCore.PERKS) do
			expect(perk.amount).toEqual(ids[perk.id])
			expect(perk.id ~= "damage" and perk.id ~= "health").toBeTrue()
		end
		expect(ShardCore.bonus(0).crit_chance).toBeNil()
		expect(ShardCore.bonus(1).crit_chance).toEqual(0.01)
		expect(ShardCore.bonus(1).shard_find).toBeNil()
		expect(ShardCore.bonus(5).luck).toEqual(1)
		expect(ShardCore.bonus(5).move_speed).toEqual(0.02)
		expect(ShardCore.costToNext(0)).toEqual(5)
		expect(ShardCore.costToNext(4)).toEqual(250)
		expect(ShardCore.costToNext(5)).toBeNil()
	end)
end)

describe("Shard Core save", function()
	it("migrates on a copy and leaves the item alone", function()
		local raw = {
			gold = 9,
			gearEssence = 4,
			inventory = {
				w1 = weapon("w1", 6),
			},
			shardCores = { w1 = 2.9, ["bad id"] = 4, nope = -1, x = "no" },
		}
		local copy, err = Save.migrate(raw, ShardCore)
		expect(err).toBeNil()
		expect(raw.shardCores.w1).toEqual(2.9)
		expect(raw.inventory.w1.upgrade).toEqual(6)
		expect(raw.inventory.w1.coreLevel).toBeNil()
		expect(copy.shardCores.w1).toEqual(2)
		expect(copy.shardCores["bad id"]).toBeNil()
		expect(copy.shardCores.nope).toBeNil()
		expect(copy.inventory.w1.upgrade).toEqual(6)
		expect(copy.inventory.w1.stars).toEqual(2)
		expect(copy.inventory.w1.stats[1].value).toEqual(12)
		expect(copy.inventory.w1.coreLevel).toBeNil()
		expect(copy.gearEssence).toEqual(4)
		copy.inventory.w1.upgrade = 1
		expect(raw.inventory.w1.upgrade).toEqual(6)
		local blank, blankErr = Save.migrate({ gold = 1 }, ShardCore)
		expect(blankErr).toBeNil()
		expect(blank.shardCores).toEqual({})
		expect(blank.gold).toEqual(1)
		expect(Save.migrate("no")).toBeNil()
	end)

	it("adds the map in schema 26 and does not invent a core on the item", function()
		expect(Schema.VERSION).toEqual(26)
		local fresh = Schema.template()
		expect(fresh.schemaVersion).toEqual(26)
		expect(fresh.shardCores).toEqual({})
		expect(fresh.gearEssence).toEqual(0)
		local raw = {
			schemaVersion = 26,
			gold = 5,
			equipped = { weapon = "w1", pet = nil, armor = {}, accessories = {} },
			inventory = {
				w1 = weapon("w1", 4),
			},
		}
		local untouched = Schema.deepCopy(raw)
		local migrated = Schema.migrate(Schema.deepCopy(raw))
		expect(untouched.shardCores).toBeNil()
		expect(untouched.inventory.w1.upgrade).toEqual(4)
		expect(untouched.inventory.w1.coreLevel).toBeNil()
		expect(migrated.schemaVersion).toEqual(26)
		expect(migrated.shardCores).toEqual({})
		expect(migrated.inventory.w1.upgrade).toEqual(4)
		expect(migrated.inventory.w1.coreLevel).toBeNil()
		expect(migrated.inventory.w1.level).toBeNil()
		expect(migrated.gearEssence).toEqual(0)
		local stored = Schema.deepCopy(raw)
		stored.shardCores = { w1 = 3, ["bad id"] = 2, gone = 9 }
		local kept = Schema.migrate(stored)
		expect(kept.shardCores.w1).toEqual(3)
		expect(kept.shardCores.gone).toEqual(5)
		expect(kept.shardCores["bad id"]).toBeNil()
		expect(kept.inventory.w1.upgrade).toEqual(4)
		expect(raw.shardCores).toBeNil()
		local shot = Schema.snapshot(kept)
		expect(shot.shardCores.w1).toEqual(3)
		expect(shot.shardCores.gone).toEqual(5)
		expect(shot.inventory.w1.upgrade).toEqual(4)
	end)
end)

describe("Shard Core feed", function()
	it("spends essence and does not change the weapon", function()
		local data = profile()
		data.gearEssence = 100
		data.equipped.weapon = "w1"
		local item = weapon("w1", 7)
		data.inventory.w1 = item
		local stats = item.stats
		local ok, reason, view = Feed.apply(data, "w1", ShardCore)
		expect(ok).toEqual(true)
		expect(reason).toBeNil()
		expect(view.level).toEqual(1)
		expect(view.spent).toEqual(5)
		expect(view.essence).toEqual(95)
		expect(view.selected).toEqual("w1")
		expect(data.gearEssence).toEqual(95)
		expect(data.shardCores.w1).toEqual(1)
		expect(data.gold).toEqual(80)
		expect(data.equipped.weapon).toEqual("w1")
		expect(item.upgrade).toEqual(7)
		expect(item.stars).toEqual(2)
		expect(item.stats == stats).toEqual(true)
		expect(item.stats[1].value).toEqual(12)
		expect(item.coreLevel).toBeNil()
		expect(item.level).toBeNil()
	end)

	it("walks the curve to the cap and then refuses", function()
		local data = profile()
		data.gearEssence = 410
		data.inventory.w1 = weapon("w1", 0)
		for level = 1, 5 do
			local ok, _, view = Feed.apply(data, "w1", ShardCore)
			expect(ok).toEqual(true)
			expect(view.level).toEqual(level)
		end
		expect(data.gearEssence).toEqual(0)
		expect(data.shardCores.w1).toEqual(5)
		expect(data.inventory.w1.upgrade).toEqual(0)
		local again, why = Feed.apply(data, "w1", ShardCore)
		expect(again).toEqual(false)
		expect(why).toEqual(Validate.CAP)
		expect(data.gearEssence).toEqual(0)
		expect(data.shardCores.w1).toEqual(5)
	end)

	it("refuses a pet, a missing weapon, a short wallet, and a bad id", function()
		local data = profile()
		data.gearEssence = 4
		data.inventory.pet = { uid = "pet", name = "Hound", kind = "Pet", upgrade = 3 }
		data.inventory.helm = { uid = "helm", name = "Helm", kind = "Armor", upgrade = 1 }
		data.pets.pet = data.inventory.pet
		expect(select(2, Feed.apply(data, "pet", ShardCore))).toEqual(Validate.WEAPON)
		expect(select(2, Feed.apply(data, "helm", ShardCore))).toEqual(Validate.WEAPON)
		expect(select(2, Feed.apply(data, "missing", ShardCore))).toEqual(Validate.MISSING)
		expect(select(2, Feed.apply(data, "bad id", ShardCore))).toEqual(Validate.ID)
		expect(data.gearEssence).toEqual(4)
		expect(data.shardCores).toBeNil()
		expect(data.inventory.pet.upgrade).toEqual(3)
		expect(data.inventory.helm.upgrade).toEqual(1)
		data.gearEssence = 100
		data.inventory.w1 = weapon("w1", 1)
		Feed.apply(data, "w1", ShardCore)
		data.gearEssence = 14
		local ok, why = Feed.apply(data, "w1", ShardCore)
		expect(ok).toEqual(false)
		expect(why).toEqual(Validate.ESSENCE)
		expect(data.gearEssence).toEqual(14)
		expect(data.shardCores.w1).toEqual(1)
	end)
end)

describe("Shard Core perks", function()
	it("adds a flat bonus on top of the finished totals", function()
		local finished = {
			lines = {
				{
					id = "damage",
					name = "Damage",
					value = 21.6,
					unit = "flat",
					text = "22",
					fromGear = true,
				},
				{
					id = "crit_chance",
					name = "Crit Chance",
					value = 0.4,
					unit = "percent",
					text = "40.0%",
					fromGear = true,
				},
				{
					id = "crit_damage",
					name = "Crit Damage",
					value = 1.5,
					unit = "multiplier",
					text = "1.50",
					fromGear = false,
				},
				{
					id = "luck",
					name = "Luck",
					value = 1,
					unit = "flat",
					text = "1",
					fromGear = true,
				},
			},
			byId = { damage = 21.6, crit_chance = 0.4, crit_damage = 1.5, luck = 1 },
		}
		local data = profile()
		data.inventory.w1 = weapon("w1", 10)
		data.shardCores = { w1 = 5 }
		local ctx = equipCtx(true, true, Perks.apply)
		local out = Perks.apply(finished, data, { weapon = "w1" }, ctx)
		expect(out.byId.damage).toEqual(21.6)
		expect(out.byId.crit_chance).toBeCloseTo(0.41)
		expect(out.byId.crit_damage).toBeCloseTo(1.55)
		expect(out.byId.luck).toEqual(2)
		expect(out.byId.shard_find).toEqual(0.02)
		expect(out.byId.move_speed).toEqual(0.02)
		expect(data.inventory.w1.upgrade).toEqual(10)
		expect(data.inventory.w1.stats[1].value).toEqual(12)
		local unchanged =
			Perks.apply(finished, data, { weapon = "w1" }, equipCtx(true, false, Perks.apply))
		expect(unchanged.byId.crit_chance).toBeCloseTo(0.41)
	end)

	it("hooks Equip totals after they are finished and skips a seated core of 0", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 4)
		data.shardCores = { w1 = 1, other = 5 }
		local threw = false
		local off = equipCtx(true, false, function()
			threw = true
			return nil
		end)
		local quiet = EquipService.view(data, off)
		expect(threw).toEqual(false)
		EquipService.equip(data, "weapon", "w1", off)
		local before = EquipService.view(data, off)
		local after = EquipService.view(data, equipCtx(true, true, Perks.apply))
		expect(stat(after, "damage")).toEqual(stat(before, "damage"))
		expect(stat(after, "crit_chance")).toBeCloseTo(stat(before, "crit_chance") + 0.01)
		expect(stat(after, "shard_find")).toBeNil()
		expect(data.inventory.w1.upgrade).toEqual(4)
		data.shardCores.w1 = 0
		local zero = EquipService.view(data, equipCtx(true, true, Perks.apply))
		expect(stat(zero, "crit_chance")).toEqual(stat(before, "crit_chance"))
		expect(quiet.loadout.weapon).toEqual("")
	end)

	it("ignores a core on a weapon that is not equipped", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 0)
		data.inventory.w2 = weapon("w2", 0)
		data.inventory.w2.name = "Other"
		data.shardCores = { w2 = 5 }
		EquipService.equip(data, "weapon", "w1", equipCtx(false, false, nil))
		local view = EquipService.view(data, equipCtx(false, true, Perks.apply))
		expect(stat(view, "crit_chance")).toEqual(0.2)
		expect(stat(view, "luck")).toEqual(0)
		expect(view.stats.byId.shard_find).toBeNil()
	end)
end)

describe("Shard Core remotes", function()
	local function deps(data: any, on: boolean, reads: { number })
		return {
			coreOn = function()
				return on
			end,
			read = function()
				reads[1] += 1
				return data
			end,
			mutate = function(_userId, mutator)
				reads[1] += 1
				local why = mutator(data)
				if why ~= nil then
					return false, why
				end
				return true, nil
			end,
			ctx = { config = ShardCore },
		}
	end

	it("does not read a profile while the flag is off", function()
		local data = profile()
		data.gearEssence = 50
		data.inventory.w1 = weapon("w1", 2)
		local reads = { 0 }
		local result = Remotes.handle({
			action = "FeedShardCore",
			userId = 7,
			args = { "w1" },
			now = 1,
		}, deps(data, false, reads), {})
		expect(result).toEqual({ ok = false, error = Validate.OFF })
		expect(reads[1]).toEqual(0)
		expect(data.gearEssence).toEqual(50)
		expect(data.inventory.w1.upgrade).toEqual(2)
		expect(data.shardCores).toBeNil()
	end)

	it("feeds through the remote and rate limits the next call", function()
		local data = profile()
		data.gearEssence = 100
		data.inventory.w1 = weapon("w1", 3)
		local reads = { 0 }
		local buckets = {}
		local fired = 0
		local bound = deps(data, true, reads)
		bound.changed = function()
			fired += 1
		end
		local result = Remotes.handle({
			action = "FeedShardCore",
			userId = 7,
			args = { "w1" },
			now = 10,
		}, bound, buckets)
		expect(result.ok).toEqual(true)
		expect(result.essence).toEqual(95)
		expect(result.level).toEqual(1)
		expect(fired).toEqual(1)
		expect(data.inventory.w1.upgrade).toEqual(3)
		for _ = 1, 4 do
			local get = Remotes.handle({
				action = "GetShardCore",
				userId = 7,
				now = 10,
			}, bound, buckets)
			expect(get.ok).toEqual(true)
		end
		local slowed = Remotes.handle({
			action = "GetShardCore",
			userId = 7,
			now = 10,
		}, bound, buckets)
		expect(slowed.error).toEqual(Validate.SLOW)
		local later = Remotes.handle({
			action = "GetShardCore",
			userId = 7,
			now = 11,
		}, bound, buckets)
		expect(later.ok).toEqual(true)
		expect(later.essence).toEqual(95)
		expect(later.weapons[1].level).toEqual(1)
	end)

	it("refuses a pet without writing", function()
		local data = profile()
		data.gearEssence = 40
		data.inventory.pet = { uid = "pet", kind = "Pet", name = "Hound", upgrade = 1 }
		local reads = { 0 }
		local result = Remotes.handle({
			action = "FeedShardCore",
			userId = 3,
			args = { "pet" },
			now = 1,
		}, deps(data, true, reads), {})
		expect(result.error).toEqual(Validate.WEAPON)
		expect(data.gearEssence).toEqual(40)
		expect(data.inventory.pet.upgrade).toEqual(1)
	end)
end)

describe("Shard Core dev grant", function()
	it("adds essence and does not touch the item", function()
		local data = profile()
		data.inventory.w1 = weapon("w1", 2)
		local ok, text = Dev.grant(data, ShardCore)
		expect(ok).toEqual(true)
		expect(text).toEqual("+100 Essence (now 100).")
		expect(data.gearEssence).toEqual(100)
		expect(data.inventory.w1.upgrade).toEqual(2)
		expect(data.inventory.w1.coreLevel).toBeNil()
		expect(data.shardCores).toBeNil()
		data.gearEssence = ShardCore.WALLET_CAP
		expect(Dev.grant(data, ShardCore)).toEqual(false)
		expect(data.gearEssence).toEqual(ShardCore.WALLET_CAP)
	end)
end)

describe("Shard Core client", function()
	it("turns a preview into labels", function()
		local data = profile()
		data.gearEssence = 100
		data.inventory.w1 = weapon("w1", 0)
		local lines = View.lines(ShardCore.preview(data, nil))
		expect(lines.title).toEqual("Shard Core")
		expect(lines.essenceText).toEqual("Essence: 100")
		expect(lines.feedText).toEqual("Feed 5 Essence")
		expect(lines.canFeed).toEqual(true)
		expect(lines.weapons[1].label).toEqual("Bramble Fang  Lv 0")
		expect(lines.perks[1].text).toEqual("Lv 1  +1% crit chance")
		expect(lines.perks[1].unlocked).toEqual(false)
		expect(lines.perks[2].text).toEqual("Lv 2  +2% shard find")
		data.inventory.pet = { uid = "pet", kind = "Pet", name = "Hound" }
		local only = ShardCore.preview(data, nil)
		expect(#only.weapons).toEqual(1)
		expect(only.weapons[1].uid).toEqual("w1")
	end)

	it("mounts under a parent and feeds without opening the bag", function()
		local calls = {}
		local data = profile()
		data.gearEssence = 100
		data.inventory.bow = weapon("bow", 1)
		data.inventory.bow.name = "Ash Bow"
		data.inventory.fang = weapon("fang", 8)
		local stores: { [any]: any } = {}
		local function reparent(node: any, parent: any?)
			local store = stores[node]
			local old = store.Parent
			if old ~= nil and old ~= parent then
				local oldStore = stores[old]
				if oldStore ~= nil then
					for index, entry in ipairs(oldStore.children) do
						if entry == node then
							table.remove(oldStore.children, index)
							break
						end
					end
				end
			end
			store.Parent = parent
			if parent ~= nil then
				local parentStore = stores[parent]
				if parentStore ~= nil then
					local found = false
					for _, entry in ipairs(parentStore.children) do
						if entry == node then
							found = true
							break
						end
					end
					if not found then
						table.insert(parentStore.children, node)
					end
				end
			end
		end
		local function signal()
			local listeners = {}
			return {
				Connect = function(_self, fn)
					table.insert(listeners, fn)
					return { Disconnect = function() end }
				end,
				Fire = function()
					for _, fn in ipairs(listeners) do
						fn()
					end
				end,
			}
		end
		local guiClasses = { Frame = true, TextLabel = true, TextButton = true }
		local function newInstance(className: string)
			local store = { ClassName = className, Name = className, children = {} }
			local node = {}
			stores[node] = store
			if className == "TextButton" then
				store.MouseButton1Click = signal()
				store.Activated = signal()
			end
			function node:IsA(kind: string): boolean
				if kind == className or kind == "Instance" then
					return true
				end
				if
					(kind == "GuiObject" or kind == "GuiBase2d")
					and guiClasses[className] == true
				then
					return true
				end
				return false
			end
			function node:GetChildren(): { any }
				local copy = {}
				for index, child in ipairs(store.children) do
					copy[index] = child
				end
				return copy
			end
			function node:FindFirstChild(name: string): any
				for _, child in ipairs(store.children) do
					if child.Name == name then
						return child
					end
				end
				return nil
			end
			function node:Destroy()
				reparent(node, nil)
			end
			function node:WaitForChild(name: string)
				return self:FindFirstChild(name)
			end
			return setmetatable(node, {
				__index = store,
				__newindex = function(_self, key, value)
					if key == "Parent" then
						reparent(node, value)
					else
						store[key] = value
					end
				end,
			})
		end
		local function find(root: any, name: string): any
			if root.Name == name then
				return root
			end
			for _, child in ipairs(root:GetChildren()) do
				local found = find(child, name)
				if found ~= nil then
					return found
				end
			end
			return nil
		end
		local function lazy(name: string)
			return setmetatable({ Name = name }, {
				__index = function(_self, key)
					return lazy(name .. "." .. tostring(key))
				end,
			})
		end
		local env = {
			assert = assert,
			error = error,
			ipairs = ipairs,
			pairs = pairs,
			pcall = pcall,
			next = next,
			select = select,
			tostring = tostring,
			tonumber = tonumber,
			type = type,
			math = math,
			string = string,
			table = table,
			setmetatable = setmetatable,
			rawget = rawget,
			rawset = rawset,
			typeof = function(value)
				if stores[value] ~= nil then
					return "Instance"
				end
				return type(value)
			end,
			Instance = { new = newInstance },
			Color3 = {
				fromRGB = function(red, green, blue)
					return { red, green, blue }
				end,
			},
			UDim = {
				new = function(scale, offset)
					return { scale, offset }
				end,
			},
			UDim2 = {
				new = function(a, b, c, d)
					return { a, b, c, d }
				end,
				fromScale = function(x, y)
					return { x, 0, y, 0 }
				end,
				fromOffset = function(x, y)
					return { 0, x, 0, y }
				end,
			},
			Enum = lazy("Enum"),
			game = {
				GetService = function()
					error("mount touched game")
				end,
			},
			require = function(mod)
				if mod == "./View" then
					return View
				end
				error("unexpected require " .. tostring(mod))
			end,
		}
		local source = fs.readFile(
			"src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ShardCore/Mount.luau"
		)
		local chunk = luau.load(luau.compile(source, { debugLevel = 2 }), {
			debugName = "ShardCoreMount",
			environment = env,
		})
		local Mount = chunk()
		local parent = newInstance("Frame")
		local hidden = Mount.mount(parent, {
			config = ShardCore,
			theme = UiTheme,
			enabled = function()
				return false
			end,
			profile = function()
				return data
			end,
			invoke = function()
				table.insert(calls, "hidden")
				return { ok = false }
			end,
		})
		expect(hidden.root.Visible).toEqual(false)
		expect(#calls).toEqual(0)
		hidden.destroy()
		local fed = nil
		local shown = Mount.mount(parent, {
			config = ShardCore,
			theme = UiTheme,
			enabled = function()
				return true
			end,
			profile = function()
				return data
			end,
			invoke = function(action, itemId)
				table.insert(calls, { action, itemId })
				if action == "FeedShardCore" then
					fed = itemId
					return {
						ok = true,
						essence = 95,
						selected = itemId,
						canFeed = true,
						status = "Feed 15 Essence",
						cap = 5,
						weapons = {
							{
								uid = itemId,
								name = "Fed",
								level = 1,
								perks = {},
							},
						},
					}
				end
				return { ok = false, error = "no" }
			end,
		})
		expect(shown.root.Name).toEqual("ShardCore")
		expect(shown.root.Parent).toEqual(parent)
		expect(find(shown.root, "Essence").Text).toEqual("Essence: 100")
		expect(find(shown.root, "Feed").Text).toEqual("Feed 5 Essence")
		expect(find(shown.root, "bow") ~= nil).toBeTrue()
		expect(find(shown.root, "fang") ~= nil).toBeTrue()
		expect(#calls).toEqual(0)
		shown.setWeapon("fang")
		find(shown.root, "Feed").MouseButton1Click:Fire()
		expect(fed).toEqual("fang")
		expect(calls[1][1]).toEqual("FeedShardCore")
		expect(find(shown.root, "Essence").Text).toEqual("Essence: 95")
		expect(data.inventory.fang.upgrade).toEqual(8)
		expect(data.inventory.bow.upgrade).toEqual(1)
		shown.destroy()
		expect(shown.root.Parent).toBeNil()
		expect(Mount.mount(nil, {}).feed()).toBeNil()
		expect(string.find(source, "function Mount.mount", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "GetShardCore", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "FeedShardCore", 1, true) ~= nil).toBeTrue()
		expect(string.find(source, "MarketplaceService", 1, true)).toBeNil()
		expect(string.find(source, "PetCare", 1, true)).toBeNil()
	end)
end)

describe("Shard Core wiring", function()
	it("keeps one hook after the finished totals and a dev grant on the flag", function()
		local totals = fs.readFile("src/server/EquipService/Totals.luau")
		local perks = fs.readFile("src/server/ShardCore/Perks.luau")
		local feed = fs.readFile("src/server/ShardCore/Feed.luau")
		local bind = fs.readFile("src/server/EquipService/Bind.luau")
		local debugService =
			fs.readFile("src/ServerScriptService/ShardfallServer/DebugService.luau")
		local project = fs.readFile("default.project.json")
		local hub =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau")
		local bar =
			fs.readFile("src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau")
		local contrib = string.find(totals, "local function contribution", 1, true)
		local hook = string.find(totals, "ctx.applyCore(result", 1, true)
		expect(contrib ~= nil and hook ~= nil and (contrib :: number) < (hook :: number)).toBeTrue()
		expect(string.find(totals, "ctx.applyCore(result", (hook :: number) + 1, true)).toBeNil()
		local perkBody = string.sub(perks, string.find(perks, "local Perks", 1, true) :: number)
		expect(string.find(perkBody, "item.upgrade", 1, true)).toBeNil()
		expect(string.find(perkBody, "Stars", 1, true)).toBeNil()
		expect(string.find(feed, ".upgrade", 1, true)).toBeNil()
		expect(string.find(feed, "gearEssence", 1, true) ~= nil).toBeTrue()
		expect(string.find(bind, "ShardCore.Perks", 1, true) ~= nil).toBeTrue()
		expect(string.find(bind, 'LaunchGate.on("shardCore")', 1, true) ~= nil).toBeTrue()
		local blockedAt = string.find(debugService, 'DevTools.blocked("Debug", action)', 1, true)
		local essenceAt = string.find(debugService, "-- [ECHO hook] Stage C", 1, true)
		expect(
			blockedAt ~= nil and essenceAt ~= nil and (blockedAt :: number) < (essenceAt :: number)
		).toBeTrue()
		expect(string.find(project, '"FeedShardCore"', 1, true) ~= nil).toBeTrue()
		expect(string.find(project, '"GetShardCore"', 1, true) ~= nil).toBeTrue()
		expect(string.find(project, '"ShardCoreChanged"', 1, true) ~= nil).toBeTrue()
		expect(string.find(hub, "ShardCore", 1, true)).toBeNil()
		expect(string.find(bar, "ShardCore", 1, true)).toBeNil()
		local DevTools = require("../src/ReplicatedStorage/Shared/DevTools")
		expect(DevTools.blocked("Debug", "essence")).toEqual(
			"Shard Core is off (LaunchGate.shardCore), so this does nothing yet."
		)
	end)
end)
