--!strict

-- [Ghost] Kevin, Oct 23: the x10 reveal is fast (<= 0.3 s a card, Skip
-- always visible) and ends on a 10-tile summary grid with NEW / ★ up /
-- auto-salvaged badges and Roll again / Close. The grid replaces the old
-- "Cracked" text list; the milestone is a small top toast.

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local GuiFake = require("./GuiFake")
local ActionSlots = require("../src/ReplicatedStorage/Shared/ActionSlots")
local CrackReveal = require("../src/ReplicatedStorage/Shared/CrackReveal")
local Pools = require("../src/ReplicatedStorage/Shared/Pools")
local RollSummary = require("../src/ReplicatedStorage/Shared/RollSummary")
local Settings = require("../src/ReplicatedStorage/Shared/Settings")

local entry = (Pools.get("verdant_armory") :: any).entries[1]

describe("RollSummary: pace", function()
	it("squeezes every rarity to 0.3 s and keeps the crack order", function()
		for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic" }) do
			for _, mode in ipairs({ "full", "quick", "skip" }) do
				local plan = RollSummary.fast(CrackReveal.plan(rarity, mode))
				expect(plan.seconds <= RollSummary.STEP + 1e-9).toBeTrue()
				expect(plan.shakeEnd <= plan.crackEnd).toBeTrue()
				expect(plan.crackEnd <= plan.burstEnd + 1e-9).toBeTrue()
				expect(plan.tensionEnd <= plan.burstEnd + 1e-9).toBeTrue()
				expect(plan.rarity).toEqual(rarity)
			end
		end
	end)

	it("leaves a plan that is already fast alone", function()
		local plan = CrackReveal.plan("Common", "reduced")
		expect(RollSummary.fast(plan)).toEqual(plan)
	end)
end)

describe("RollSummary: tiles", function()
	it("marks a new drop NEW", function()
		local tile = RollSummary.row({ name = "Iron Blade", rarity = "Rare", kind = "Weapon" }, {}, true)
		expect(tile.isNew).toBeTrue()
		expect(tile.badges[1]).toEqual("NEW")
		expect(tile.line).toEqual("Rare")
	end)

	it("marks a merged dupe ★ up with no name in the line", function()
		local tile = RollSummary.row(
			{ name = "Iron Blade", rarity = "Uncommon" },
			{ merged = true, oldLevel = 0, newLevel = 1 },
			true
		)
		expect(tile.starUp).toBeTrue()
		expect(tile.isNew).toBeFalse()
		expect(tile.badges[1]).toEqual("★ up")
		expect(tile.line).toEqual("★ 0 -> ★ 1")
		expect(string.find(tile.line, "Iron", 1, true) == nil).toBeTrue()
	end)

	it("marks an auto-salvaged drop with its Essence", function()
		local tile = RollSummary.row(
			{ name = "Twig", rarity = "Common" },
			{ autoSalvaged = true, essenceGained = 12 },
			false
		)
		expect(tile.salvaged).toBeTrue()
		expect(tile.badges[1]).toEqual("Auto-salvaged")
		expect(tile.line).toEqual("Auto-salvaged +12 Essence")
		expect(tile.essence).toEqual(12)
	end)

	it("never leaves a hole for an item with no tile", function()
		local a, b = { name = "A", rarity = "Rare" }, { name = "B", rarity = "Epic" }
		local meta = { [a] = RollSummary.row(a, {}, true) }
		local tiles = RollSummary.tiles({ a, b }, meta)
		expect(#tiles).toEqual(2)
		expect(tiles[1].isNew).toBeTrue()
		expect(tiles[2].name).toEqual("B")
		expect(tiles[2].rarity).toEqual("Epic")
	end)

	it("sums the headline", function()
		local tiles = {
			RollSummary.row({ name = "A" }, {}, true),
			RollSummary.row({ name = "B" }, { merged = true, oldLevel = 1, newLevel = 2 }, false),
			RollSummary.row({ name = "C" }, { autoSalvaged = true, essenceGained = 5 }, false),
			RollSummary.row({ name = "D" }, { autoSalvaged = true, essenceGained = 7 }, false),
		}
		expect(RollSummary.headline(tiles)).toEqual(
			"x4 results: 1 NEW · 1 ★ up · 2 auto-salvaged (+12 Essence)"
		)
		expect(RollSummary.headline({ RollSummary.row({ name = "E" }, {}, false) })).toEqual("x1 results: 1 copy")
	end)
end)

describe("RollSummary: one outcome per tile (playtest clip 4)", function()
	local function gear(uid: string, templateId: string, name: string, rarity: string?): any
		return { uid = uid, templateId = templateId, name = name, rarity = rarity or "Rare", kind = "Weapon" }
	end

	it("never marks a dupe of gear owned before the batch NEW", function()
		local owned = { worldroot_staff = true, bramble_fang = true, beastbone_hammer = true }
		local tiles = RollSummary.batch({
			-- At ★5 the dupe pays Essence.
			{ item = gear("w1", "worldroot_staff", "Worldroot Staff", "Legendary"), merged = true, oldLevel = 5, newLevel = 5, essence = 40 },
			-- Fed, but short of the next star.
			{ item = gear("b1", "bramble_fang", "Bramble Fang"), merged = true, oldLevel = 2, newLevel = 2, essence = 0 },
			-- Server did not merge (Stage A off): a plain copy, still not NEW.
			{ item = gear("h2", "beastbone_hammer", "Beastbone Hammer") },
		}, owned)
		expect(tiles[1].isNew).toBeFalse()
		expect(tiles[1].outcome).toEqual("essence")
		expect(tiles[1].badges[1]).toEqual("Essence")
		expect(tiles[1].line).toEqual("★ 5 · +40 Essence")
		expect(tiles[2].isNew).toBeFalse()
		expect(tiles[2].outcome).toEqual("fed")
		expect(tiles[2].line).toEqual("★ 2 · toward ★ 3")
		expect(tiles[3].isNew).toBeFalse()
		expect(tiles[3].outcome).toEqual("copy")
	end)

	it("chains stars through the batch when one item repeats", function()
		local tiles = RollSummary.batch({
			{ item = gear("g1", "wildgrowth_staff", "Wildgrowth Staff") },
			{ item = gear("g1", "wildgrowth_staff", "Wildgrowth Staff"), merged = true, oldLevel = 0, newLevel = 1 },
			{ item = gear("g1", "wildgrowth_staff", "Wildgrowth Staff"), merged = true, oldLevel = 1, newLevel = 2 },
			-- A stale row that still says 0 -> 1 is read from where the chain got to.
			{ item = gear("g1", "wildgrowth_staff", "Wildgrowth Staff"), merged = true, oldLevel = 0, newLevel = 1 },
		}, {})
		expect(tiles[1].outcome).toEqual("new")
		expect(tiles[2].line).toEqual("★ 0 -> ★ 1")
		expect(tiles[3].line).toEqual("★ 1 -> ★ 2")
		expect(tiles[4].outcome).toEqual("fed")
		expect(tiles[4].line).toEqual("★ 2 · toward ★ 3")
	end)

	it("keeps two copies' chains apart", function()
		local tiles = RollSummary.batch({
			{ item = gear("a", "wildgrowth_staff", "Wildgrowth Staff"), merged = true, oldLevel = 0, newLevel = 1 },
			{ item = gear("b", "wildgrowth_staff", "Wildgrowth Staff"), merged = true, oldLevel = 0, newLevel = 1 },
		}, { wildgrowth_staff = true })
		expect(tiles[1].line).toEqual("★ 0 -> ★ 1")
		expect(tiles[2].line).toEqual("★ 0 -> ★ 1")
	end)

	it("a second copy of a brand-new drop inside the batch is not NEW twice", function()
		local tiles = RollSummary.batch({
			{ item = gear("n1", "glade_charm", "Glade Charm") },
			{ item = gear("n2", "glade_charm", "Glade Charm") },
		}, {})
		expect(tiles[1].outcome).toEqual("new")
		expect(tiles[2].outcome).toEqual("copy")
	end)

	it("gives every tile exactly one badge and the header matches them", function()
		local rows = {
			{ item = gear("1", "t1", "A") },
			{ item = gear("2", "t2", "B"), merged = true, oldLevel = 1, newLevel = 2 },
			{ item = gear("2", "t2", "B"), merged = true, oldLevel = 2, newLevel = 2 },
			{ item = gear("3", "t3", "C"), merged = true, oldLevel = 5, newLevel = 5, essence = 20 },
			{ item = gear("4", "t4", "D"), autoSalvaged = true, essenceGained = 4 },
			{ item = gear("5", "t5", "E"), autoSalvaged = true, essenceGained = 8 },
			{ item = gear("6", "t6", "F") },
			{ item = gear("7", "t1", "A") },
			{ item = gear("8", "t8", "G"), merged = true, oldLevel = 0, newLevel = 1 },
			{ item = gear("9", "t9", "H") },
		}
		local tiles = RollSummary.batch(rows, { t2 = true, t3 = true, t8 = true })
		local counted: { [string]: number } = {}
		for _, tile in ipairs(tiles) do
			expect(#tile.badges).toEqual(1)
			counted[tile.badges[1]] = (counted[tile.badges[1]] or 0) + 1
		end
		expect(counted["NEW"]).toEqual(3)
		expect(counted["★ up"]).toEqual(2)
		expect(counted["★ fed"]).toEqual(1)
		expect(counted["Essence"]).toEqual(1)
		expect(counted["Copy"]).toEqual(1)
		expect(counted["Auto-salvaged"]).toEqual(2)
		expect(RollSummary.headline(tiles)).toEqual(
			"x10 results: 3 NEW · 2 ★ up · 1 ★ fed · 1 at ★5 (+20 Essence) · 1 copy · 2 auto-salvaged (+12 Essence)"
		)
	end)
end)

describe("RollSummary: layout", function()
	for _, size in ipairs({ { 1920, 1080, false }, { 1280, 800, false }, { 390, 844, true }, { 844, 390, true } }) do
		it(string.format("fits ten tiles in %dx%d", size[1], size[2]), function()
			local lay = RollSummary.layout(size[1], size[2], size[3], 10)
			expect(lay.cols * lay.rows >= 10).toBeTrue()
			expect(lay.panel.x >= 0).toBeTrue()
			expect(lay.panel.y >= 0).toBeTrue()
			expect(lay.panel.x + lay.panel.w <= size[1]).toBeTrue()
			expect(lay.panel.y + lay.panel.h <= size[2]).toBeTrue()
			expect(lay.grid.x + lay.grid.w <= lay.panel.w).toBeTrue()
			expect(lay.cell >= 40).toBeTrue()
			expect(lay.cellH >= lay.cell).toBeTrue()
			if lay.cell < 84 then
				-- Room for art, a 2-line name and the result line.
				expect(lay.cellH >= 90).toBeTrue()
			end
		end)
	end
	it("uses two rows of five on a desktop", function()
		local lay = RollSummary.layout(1280, 800, false, 10)
		expect(lay.cols).toEqual(5)
		expect(lay.rows).toEqual(2)
	end)
end)

local function rig(rows: ((index: number) -> any)?, inventory: any?)
	local world = GuiFake.world()
	world.withControls()
	world.withCharacter()
	local MenuHub = world.load("MenuHub")
	local count = 0
	local batches = 0
	local hub = MenuHub.start(world.playerGui, {
		invoke = function(name: string, ...)
			if name == "RollShards" then
				batches += 1
				local items = {}
				for index = 1, 10 do
					count += 1
					local row = {
						item = {
							uid = "u" .. count,
							templateId = entry.templateId .. "_" .. count,
							name = entry.name,
							rarity = if index == 10 then "Epic" else "Rare",
							kind = entry.kind,
						},
						rarity = if index == 10 then "Epic" else "Rare",
						fillerSeed = index,
						pity = { sinceLegendary = index },
					}
					if rows ~= nil then
						for key, value in pairs(rows(index) or {}) do
							row[key] = value
						end
					end
					table.insert(items, row)
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
		inventory = inventory or {},
		pets = {},
		equipped = {},
		consumables = {},
		actionBars = ActionSlots.fresh(),
		uiSettings = Settings.default(),
	})
	hub.open("roll")
	world.clock.now = 100
	local screen = GuiFake.findNamed(world.playerGui, "ShardfallHub")
	local function step(seconds: number)
		local left = seconds
		while left > 0 do
			world.clock.now += 0.1
			world.runService.Heartbeat:Fire(0.1)
			left -= 0.1
		end
	end
	local function find(name: string): any
		return GuiFake.findNamed(screen, name)
	end
	return {
		world = world,
		hub = hub,
		screen = screen,
		step = step,
		find = find,
		batches = function()
			return batches
		end,
	}
end

local function tileCount(summary: any): number
	local grid = summary:FindFirstChild("Grid")
	local n = 0
	for _, child in ipairs(grid:GetChildren()) do
		if string.sub(child.Name, 1, 5) == "Tile_" then
			n += 1
		end
	end
	return n
end

describe("x10 reveal and summary", function()
	it("shows Skip for the whole batch and ends on ten tiles in about 3 s", function()
		local r = rig()
		GuiFake.activate(r.find("TimesTen"))
		expect(r.batches()).toEqual(1)
		local skip = r.find("SkipBatch")
		local summary = r.find("RollSummary")
		expect(skip.Visible).toBeTrue()
		expect(summary.Visible).toBeFalse()
		local waited = 0
		while not summary.Visible and waited < 8 do
			expect(skip.Visible).toBeTrue()
			r.step(0.1)
			waited += 0.1
		end
		expect(summary.Visible).toBeTrue()
		-- Ten cards at <= 0.3 s each plus a frame of slack per card.
		expect(waited <= 10 * (RollSummary.STEP + 0.1) + 0.2).toBeTrue()
		expect(skip.Visible).toBeFalse()
		expect(tileCount(summary)).toEqual(10)
		expect(GuiFake.findNamed(summary, "RollAgain").Text).toEqual("Roll again")
		expect(GuiFake.findNamed(summary, "Close").Text).toEqual("Close")
	end)

	it("Skip lands every card at once and opens the summary", function()
		local r = rig()
		GuiFake.activate(r.find("TimesTen"))
		r.step(0.1)
		GuiFake.activate(r.find("SkipBatch"))
		local summary = r.find("RollSummary")
		expect(summary.Visible).toBeTrue()
		expect(tileCount(summary)).toEqual(10)
		expect(r.find("SkipBatch").Visible).toBeFalse()
		expect(r.world.controls.enabled).toEqual(true)
	end)

	it("badges NEW, ★ up and auto-salvaged on the tiles", function()
		local r = rig(function(index: number)
			if index == 2 then
				return { merged = true, oldLevel = 0, newLevel = 1 }
			elseif index == 3 then
				return { autoSalvaged = true, essenceGained = 9 }
			end
			return nil
		end)
		GuiFake.activate(r.find("TimesTen"))
		GuiFake.activate(r.find("SkipBatch"))
		local summary = r.find("RollSummary")
		local grid = summary:FindFirstChild("Grid")
		local function badges(tile: any): { string }
			local out = {}
			for _, child in ipairs(tile:GetChildren()) do
				if child.Name == "Badge" then
					table.insert(out, child:GetAttribute("Badge"))
				end
			end
			return out
		end
		expect(badges(grid:FindFirstChild("Tile_1"))[1]).toEqual("NEW")
		local merged = grid:FindFirstChild("Tile_2")
		expect(table.find(badges(merged), "★ up") ~= nil).toBeTrue()
		expect(merged:FindFirstChild("Line").Text).toEqual("★ 0 -> ★ 1")
		local gone = grid:FindFirstChild("Tile_3")
		expect(table.find(badges(gone), "Auto-salvaged") ~= nil).toBeTrue()
		expect(gone:FindFirstChild("Line").Text).toEqual("+9 Essence")
		expect(gone:FindFirstChild("Badge").Text).toEqual("Salvaged")
		expect(string.find(GuiFake.findNamed(summary, "Headline").Text, "auto-salvaged (+9 Essence)", 1, true) ~= nil).toBeTrue()
	end)

	it("does not tag a dupe of equipped gear NEW (Worldroot Staff, clip 4)", function()
		local owned = {
			uid = "u1",
			templateId = entry.templateId .. "_1",
			name = entry.name,
			rarity = "Legendary",
			kind = entry.kind,
			stars = 2,
		}
		local r = rig(function(index: number)
			if index == 1 then
				-- The server merged the dupe into the copy Kevin wears; the row
				-- carries that copy (same uid), so "not in my bag" is no test.
				return { merged = true, oldLevel = 2, newLevel = 2, essence = 0 }
			end
			return nil
		end, { u1 = owned })
		GuiFake.activate(r.find("TimesTen"))
		GuiFake.activate(r.find("SkipBatch"))
		local grid = r.find("RollSummary"):FindFirstChild("Grid")
		local first = grid:FindFirstChild("Tile_1")
		expect(first:FindFirstChild("Badge"):GetAttribute("Badge")).toEqual("★ fed")
		for index = 1, 10 do
			local n = 0
			for _, child in ipairs(grid:FindFirstChild("Tile_" .. index):GetChildren()) do
				if child.Name == "Badge" then
					n += 1
				end
			end
			expect(n).toEqual(1)
		end
	end)

	it("puts Skip at the bottom right of the reveal card, clear of the Shards pill", function()
		local r = rig()
		local skip = r.find("SkipBatch")
		expect(skip.AnchorPoint.Y).toEqual(1)
		expect(skip.Position.Y.Scale).toEqual(1)
		expect(skip.Position.X.Scale).toEqual(1)
	end)

	it("drops the roll-page clutter: Junk/Below, second Streak/Rolls, plain Odds rows", function()
		local r = rig()
		expect(r.find("Junk").Visible).toBeFalse()
		expect(r.find("OddsLines").Visible).toBeFalse()
		expect(r.find("Progress"):FindFirstChild("Odds")).toBeNil()
		local streaks = 0
		for _, desc in ipairs(r.screen:GetDescendants()) do
			if desc:IsA("TextLabel") and desc.Visible then
				expect(string.find(desc.Text, "^Rolls  %d") == nil).toBeTrue()
				if string.find(desc.Text, "^Streak") ~= nil then
					streaks += 1
				end
			end
		end
		-- Only the streak bar's own label.
		expect(streaks <= 1).toBeTrue()
	end)

	it("Roll again rolls ten more, Close just closes", function()
		local r = rig()
		GuiFake.activate(r.find("TimesTen"))
		GuiFake.activate(r.find("SkipBatch"))
		local summary = r.find("RollSummary")
		GuiFake.activate(GuiFake.findNamed(summary, "RollAgain"))
		expect(r.batches()).toEqual(2)
		expect(summary.Visible).toBeFalse()
		GuiFake.activate(r.find("SkipBatch"))
		expect(summary.Visible).toBeTrue()
		GuiFake.activate(GuiFake.findNamed(summary, "Close"))
		expect(summary.Visible).toBeFalse()
		expect(r.batches()).toEqual(2)
	end)

	it("drops the old Cracked text list", function()
		local r = rig()
		GuiFake.activate(r.find("TimesTen"))
		GuiFake.activate(r.find("SkipBatch"))
		for _, desc in ipairs(r.screen:GetDescendants()) do
			if desc:IsA("TextLabel") then
				expect(desc.Text == "Cracked").toBeFalse()
			end
		end
	end)

	it("shows milestones as a small toast, not a reel banner", function()
		local r = rig()
		local toast = r.find("Milestone")
		expect(toast:GetAttribute("Toast")).toEqual(true)
		expect(toast.Size.Y.Offset <= 28).toBeTrue()
		expect(toast.Size.Y.Scale).toEqual(0)
		expect(toast.Parent.Name ~= "Reel").toBeTrue()
	end)
end)
