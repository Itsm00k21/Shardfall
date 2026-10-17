--!strict

local framework = require("./framework")
local describe = framework.describe
local it = framework.it
local expect = framework.expect

local Loops = require("../src/ReplicatedStorage/Shared/Loops")

describe("Loops", function()
	it("pauses a missed login day and keeps dailies for three days", function()
		local streak, paid = Loops.login(3, 10, 12)
		expect(streak).toEqual(3)
		expect(paid).toEqual(true)
		streak, paid = Loops.login(3, 12, 13)
		expect(streak).toEqual(4)
		expect(Loops.login(4, 13, 13)).toEqual(4)
		local dailies = Loops.rollDailies(1, 2)
		expect(#dailies).toEqual(3)
		dailies[1].born = 1
		local kept = Loops.expire(dailies, 5)
		expect(#kept).toEqual(0)
		local ok, text = Loops.reroll(dailies, 1, 1, 9)
		expect(ok).toEqual(true)
		expect(text ~= "").toEqual(true)
		expect(Loops.reroll(dailies, 1, 1, 3)).toEqual(false)
	end)

	it("pays a bingo line and keeps the premium track off", function()
		local cells = Loops.board()
		expect(Loops.seal(cells, 1)).toEqual(0)
		Loops.seal(cells, 2)
		Loops.seal(cells, 3)
		expect(Loops.seal(cells, 4)).toEqual(1)
		local _xp, tier = Loops.passXp(0, Loops.PASS_XP)
		expect(tier).toEqual(1)
		expect(Loops.premium()).toEqual(false)
		local mult, _, rare = Loops.firstClear(-1, 4)
		expect(mult).toEqual(3)
		expect(rare).toEqual(true)
		mult, _, rare = Loops.firstClear(4, 4)
		expect(mult).toEqual(1)
		expect(rare).toEqual(false)
		local board = { dailies = {}, weekly = {} }
		Loops.refresh(board, 86400 * 3, 1)
		expect(#board.dailies).toEqual(3)
		expect(#board.weekly).toEqual(5)
		expect(Loops.apply(board, board.dailies[1].id, 99) > 0).toEqual(true)
	end)

	it("counts columns and diagonals and caps the board at nine seals", function()
		local column = Loops.board()
		Loops.seal(column, 1)
		Loops.seal(column, 5)
		Loops.seal(column, 9)
		expect(Loops.seal(column, 13)).toEqual(1)
		local diagonal = Loops.board()
		Loops.seal(diagonal, 4)
		Loops.seal(diagonal, 7)
		Loops.seal(diagonal, 10)
		expect(Loops.seal(diagonal, 13)).toEqual(1)
		local scattered = Loops.board()
		Loops.placeSeal(scattered, 4)
		expect(scattered[1]).toEqual(false)
		expect(Loops.sealCount(scattered)).toEqual(1)
		local filled = Loops.board()
		for step = 1, 9 do
			Loops.placeSeal(filled, step)
		end
		expect(Loops.sealCount(filled)).toEqual(9)
		local lines = Loops.lineCount(filled)
		Loops.placeSeal(filled, 99)
		expect(Loops.sealCount(filled)).toEqual(9)
		expect(Loops.lineCount(filled)).toEqual(lines)
		local ordered = Loops.board()
		for _ = 1, 9 do
			Loops.sealNext(ordered)
		end
		expect(ordered[1]).toEqual(true)
		expect(ordered[10]).toEqual(false)
		expect(Loops.sealNext(ordered)).toEqual(Loops.lineCount(ordered))
	end)

	it("spends Second Chance on retry and shuffle", function()
		expect(Loops.mentorCredit(1, 1, 1, false)).toEqual(false)
		expect(Loops.mentorCredit(1, 2, 10, false)).toEqual(false)
		expect(Loops.mentorCredit(1, 2, 0, false)).toEqual(false)
		expect(Loops.mentorCredit(1, 2, 9, false)).toEqual(true)
		expect(Loops.mentorCredit(1, 2, 20, true)).toEqual(true)
		local chance = 0
		for _ = 1, Loops.CHANCE_MAX do
			local granted, nextChance = Loops.grantChance(chance)
			expect(granted).toEqual(true)
			chance = nextChance
		end
		local capped, cappedChance = Loops.grantChance(chance)
		expect(capped).toEqual(false)
		expect(cappedChance).toEqual(Loops.CHANCE_MAX)
		expect(Loops.chance(chance)).toEqual(Loops.CHANCE_MAX)
		local stuck = Loops.board()
		Loops.seal(stuck, 1)
		expect(Loops.retry(stuck, 1, 0)).toEqual(false)
		expect(stuck[1]).toEqual(true)
		local granted, stuckChance = Loops.grantChance(0)
		expect(granted).toEqual(true)
		local moved, moveNote, _lines, left = Loops.retry(stuck, 1, stuckChance)
		expect(moved).toEqual(true)
		expect(moveNote).toEqual("")
		expect(stuck[1]).toEqual(false)
		expect(Loops.sealCount(stuck)).toEqual(1)
		expect(left).toEqual(0)
		expect(Loops.chance(left)).toEqual(0)
		local mixed = Loops.board()
		Loops.seal(mixed, 1)
		Loops.seal(mixed, 2)
		Loops.seal(mixed, 3)
		local _, one = Loops.grantChance(0)
		expect(Loops.shuffle(mixed, 3, one)).toEqual(false)
		local _, two = Loops.grantChance(one)
		local shuffled, _note, _count, after = Loops.shuffle(mixed, 3, two)
		expect(shuffled).toEqual(true)
		expect(Loops.sealCount(mixed)).toEqual(3)
		expect(after).toEqual(0)
		local profile = {
			dailies = {},
			weekly = {},
			weeklyWeek = 0,
			boardChance = 4,
		}
		Loops.refresh(profile, 86400 * 7, 1)
		expect(profile.weeklyWeek).toEqual(1)
		expect(profile.boardChance).toEqual(4)
	end)

	it("keeps every board key an integer from 1 to 16", function()
		local function pure(cells): boolean
			local seen = 0
			for key in pairs(cells) do
				if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > 16 then
					return false
				end
				seen += 1
			end
			return seen == 16
		end

		local fresh = Loops.board()
		expect(pure(fresh)).toEqual(true)

		local placed = Loops.board()
		Loops.placeSeal(placed, 4)
		expect(pure(placed)).toEqual(true)

		local movedBoard = Loops.board()
		Loops.seal(movedBoard, 1)
		local _, points = Loops.grantChance(0)
		local moved = Loops.retry(movedBoard, 2, points)
		expect(moved).toEqual(true)
		expect(pure(movedBoard)).toEqual(true)

		local shuffledBoard = Loops.board()
		Loops.seal(shuffledBoard, 1)
		Loops.seal(shuffledBoard, 2)
		local _, first = Loops.grantChance(0)
		local _, second = Loops.grantChance(first)
		local shuffled = Loops.shuffle(shuffledBoard, 5, second)
		expect(shuffled).toEqual(true)
		expect(pure(shuffledBoard)).toEqual(true)
	end)

	it("refuses premium grants, claims, and skips while the track is off", function()
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local savedProduct = Loops.PASS_PRODUCT_ID
		Loops.PASS_PRODUCT_ID = 101
		local data = {
			receipts = {},
			gems = 5,
			passPremium = false,
			passXp = 0,
		}
		local ok, err = pcall(function()
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-1", 101)
			expect(granted).toEqual(false)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("The premium track is not for sale yet.")
			expect(data.receipts["receipt-1"]).toEqual(nil)
			expect(data.passPremium).toEqual(false)
			expect(data.gems).toEqual(5)
			local claimed, reward, ready, why = Loops.claimPremium(Loops.PASS_XP * 50, 0, true, 9)
			expect(ready).toEqual(false)
			expect(reward).toEqual(nil)
			expect(claimed).toEqual(0)
			expect(why).toEqual("The premium track is not for sale yet.")
			local xp, gems, skipped, skipWhy = Loops.skipTier(0, 500, true)
			expect(skipped).toEqual(false)
			expect(xp).toEqual(0)
			expect(gems).toEqual(500)
			expect(skipWhy).toEqual("The premium track is not for sale yet.")
			local freeClaim, freeReward, freeReady = Loops.claimFree(Loops.PASS_XP, 0)
			expect(freeClaim).toEqual(1)
			expect(freeReady).toEqual(true)
			expect(freeReward.gold).toEqual(150)
			expect(freeReward.gems).toEqual(nil)
		end)
		Loops.PASS_PRODUCT_ID = savedProduct
		if not ok then
			error(err, 2)
		end
	end)

	it("grants cosmetics only when the premium switch is on", function()
		local savedFlag = Loops.PREMIUM_ENABLED
		local savedPass = Loops.PASS_PRODUCT_ID
		local savedArchive = Loops.ARCHIVE_PRODUCT_ID
		Loops.PREMIUM_ENABLED = true
		Loops.PASS_PRODUCT_ID = 101
		Loops.ARCHIVE_PRODUCT_ID = 102
		local ok, err = pcall(function()
			expect(Loops.premiumGemTotal()).toEqual(Loops.PASS_GEMS)
			expect(Loops.archiveRobux()).toEqual(480)
			expect(Loops.keepsPremium(true, true)).toEqual(true)
			expect(Loops.keepsPremium(false, true)).toEqual(false)
			local skins = 0
			local hats = 0
			local trails = 0
			local vfx = 0
			local emotes = 0
			for _, reward in pairs(Loops.PREMIUM_TRACK) do
				expect(reward.gold).toEqual(nil)
				expect(reward.keys).toEqual(nil)
				expect(reward.dust).toEqual(nil)
				expect(reward.damage).toEqual(nil)
				expect(reward.power).toEqual(nil)
				expect(reward.stats).toEqual(nil)
				expect(reward.xp).toEqual(nil)
				if reward.cosmetic == "skin" then
					skins += 1
				elseif reward.cosmetic == "pet_hat" then
					hats += 1
				elseif reward.cosmetic == "trail" then
					trails += 1
				elseif reward.cosmetic == "weapon_vfx" then
					vfx += 1
				elseif reward.cosmetic == "emote" then
					emotes += 1
				end
			end
			expect(skins).toEqual(10)
			expect(hats).toEqual(2)
			expect(trails).toEqual(2)
			expect(vfx).toEqual(1)
			expect(emotes).toEqual(1)
			local data = { receipts = {}, gems = 0 }
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-9", 101)
			expect(granted).toEqual(true)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("")
			expect(data.passPremium).toEqual(true)
			expect(data.gems).toEqual(0)
			expect(data.receipts["receipt-9"]).toEqual(true)
			granted, duplicate = Loops.grantPremium(data, "receipt-9", 101)
			expect(granted).toEqual(true)
			expect(duplicate).toEqual(true)
			expect(data.gems).toEqual(0)
			local missed, _missDup, missWhy = Loops.grantPremium(data, "receipt-x", 999)
			expect(missed).toEqual(false)
			expect(missWhy).toEqual("That product is not the Shard Pass.")
			expect(data.receipts["receipt-x"]).toEqual(nil)
			local archived = { receipts = {}, gems = 80 }
			local archiveOk = Loops.grantPremium(archived, "receipt-a", 102)
			expect(archiveOk).toEqual(true)
			expect(archived.passPremium).toEqual(true)
			expect(archived.gems).toEqual(80)
			expect(Loops.grantPremium(archived, "", 102)).toEqual(false)
			expect(Loops.productKind(0)).toEqual(nil)
			local claimed, reward, ready = Loops.claimPremium(Loops.PASS_XP * 5, 4, true, 0)
			expect(ready).toEqual(true)
			expect(claimed).toEqual(5)
			expect(reward.gems).toEqual(40)
			expect(reward.id).toEqual("pass_hat_moss")
			expect(reward.gold).toEqual(nil)
			local held, blocked, featReady, featWhy =
				Loops.claimPremium(Loops.PASS_XP * 50, 49, true, 0)
			expect(featReady).toEqual(false)
			expect(blocked).toEqual(nil)
			expect(held).toEqual(49)
			expect(featWhy).toEqual("Clear Nightmare to claim this.")
			held, reward, featReady = Loops.claimPremium(Loops.PASS_XP * 50, 49, true, 1)
			expect(featReady).toEqual(true)
			expect(held).toEqual(50)
			expect(reward.id).toEqual("pass_skin_nightmare")
			expect(reward.gems).toEqual(nil)
			local lockedReady = select(3, Loops.claimPremium(Loops.PASS_XP, 0, false, 0))
			expect(lockedReady).toEqual(false)
			local xp, gems, skipped = Loops.skipTier(0, 500, true)
			expect(skipped).toEqual(true)
			expect(xp).toEqual(Loops.PASS_XP)
			expect(gems).toEqual(500 - Loops.SKIP_GEMS)
			local sameXp, sameGems, denied = Loops.skipTier(0, 500, false)
			expect(denied).toEqual(false)
			expect(sameXp).toEqual(0)
			expect(sameGems).toEqual(500)
			local doneXp, doneGems, finished =
				Loops.skipTier(Loops.PASS_XP * Loops.PASS_TIERS, 500, true)
			expect(finished).toEqual(false)
			expect(doneXp).toEqual(Loops.PASS_XP * Loops.PASS_TIERS)
			expect(doneGems).toEqual(500)
			local caches, gain, overflowReady = Loops.overflow(Loops.PASS_XP * 52, 0)
			expect(overflowReady).toEqual(true)
			expect(caches).toEqual(2)
			expect(gain).toEqual(8)
			local earlyCaches, earlyGain, earlyReady = Loops.overflow(Loops.PASS_XP * 10, 0)
			expect(earlyReady).toEqual(false)
			expect(earlyCaches).toEqual(0)
			expect(earlyGain).toEqual(0)
		end)
		Loops.PREMIUM_ENABLED = savedFlag
		Loops.PASS_PRODUCT_ID = savedPass
		Loops.ARCHIVE_PRODUCT_ID = savedArchive
		if not ok then
			error(err, 2)
		end
	end)

	it("matches weekly text to the live goal and leaves dailies alone", function()
		expect(table.isfrozen(Loops.WEEKLY)).toEqual(true)
		expect(#Loops.WEEKLY).toEqual(5)
		expect(Loops.WEEKLY).toEqual({
			{ id = "rooms", text = "Clear 6 Rootvault rooms", goal = 6 },
			{ id = "dodge", text = "Dodge 15 attacks", goal = 15 },
			{ id = "hatch", text = "Hatch 3 eggs", goal = 3 },
			{ id = "forge", text = "Upgrade 3 pieces of gear", goal = 3 },
			{ id = "pet", text = "Pet or feed a companion 3 times", goal = 3 },
		})
		for _, row in ipairs(Loops.WEEKLY) do
			expect(table.isfrozen(row)).toEqual(true)
		end

		expect(Loops.POOL).toEqual({
			{ id = "rooms", text = "Clear 2 Rootvault rooms", goal = 2 },
			{ id = "dodge", text = "Dodge 5 attacks", goal = 5 },
			{ id = "hatch", text = "Hatch an egg", goal = 1 },
			{ id = "forge", text = "Upgrade a piece of gear", goal = 1 },
			{ id = "pet", text = "Pet or feed a companion", goal = 1 },
		})
		local dailies = Loops.rollDailies(8, 0)
		expect(#dailies).toEqual(3)
		expect(dailies[1].id).toEqual("rooms")
		expect(dailies[1].text).toEqual("Clear 2 Rootvault rooms")
		expect(dailies[1].goal).toEqual(2)
		expect(dailies[2].id).toEqual("dodge")
		expect(dailies[2].text).toEqual("Dodge 5 attacks")
		expect(dailies[2].goal).toEqual(5)
		expect(dailies[3].id).toEqual("hatch")
		expect(dailies[3].text).toEqual("Hatch an egg")
		expect(dailies[3].goal).toEqual(1)
		local later = Loops.rollDailies(8, 3)
		expect(later[1].id).toEqual("forge")
		expect(later[1].text).toEqual("Upgrade a piece of gear")
		expect(later[1].goal).toEqual(1)
		expect(later[2].id).toEqual("pet")
		expect(later[2].text).toEqual("Pet or feed a companion")
		expect(later[2].goal).toEqual(1)

		local weeklies = Loops.rollWeekly(9, 0)
		expect(#weeklies).toEqual(5)
		local ids = {}
		for index, quest in ipairs(weeklies) do
			ids[index] = quest.id
			expect(quest.text).toEqual(Loops.WEEKLY[index].text)
			expect(quest.goal).toEqual(Loops.WEEKLY[index].goal)
			expect(quest.progress).toEqual(0)
			expect(quest.done).toEqual(false)
			expect(quest.born).toEqual(9)
		end
		expect(ids).toEqual({ "rooms", "dodge", "hatch", "forge", "pet" })
		local rotated = Loops.rollWeekly(9, 2)
		expect(rotated[1].id).toEqual("hatch")
		expect(rotated[1].text).toEqual("Hatch 3 eggs")
		expect(rotated[1].goal).toEqual(3)
		expect(rotated[2].id).toEqual("forge")
		expect(rotated[2].goal).toEqual(3)
		expect(rotated[3].id).toEqual("pet")
		expect(rotated[3].text).toEqual("Pet or feed a companion 3 times")
		expect(rotated[4].id).toEqual("rooms")
		expect(rotated[4].text).toEqual("Clear 6 Rootvault rooms")
		expect(rotated[4].goal).toEqual(6)
		expect(rotated[5].id).toEqual("dodge")
		expect(rotated[5].text).toEqual("Dodge 15 attacks")
		expect(rotated[5].goal).toEqual(15)

		local board = { dailies = {}, weekly = weeklies }
		expect(Loops.apply(board, "rooms", 5)).toEqual(0)
		expect(weeklies[1].progress).toEqual(5)
		expect(weeklies[1].done).toEqual(false)
		expect(Loops.apply(board, "rooms", 1)).toEqual(1)
		expect(weeklies[1].progress).toEqual(6)
		expect(weeklies[1].done).toEqual(true)

		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local savedProduct = Loops.PASS_PRODUCT_ID
		Loops.PASS_PRODUCT_ID = 101
		local data = {
			receipts = {},
			gems = 5,
			passPremium = false,
		}
		local ok, err = pcall(function()
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-weekly", 101)
			expect(granted).toEqual(false)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("The premium track is not for sale yet.")
			expect(data.receipts["receipt-weekly"]).toEqual(nil)
			expect(data.passPremium).toEqual(false)
			expect(data.gems).toEqual(5)
		end)
		Loops.PASS_PRODUCT_ID = savedProduct
		if not ok then
			error(err, 2)
		end
	end)

	it("does not record a receipt when the premium track is off", function()
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local savedPass = Loops.PASS_PRODUCT_ID
		local savedArchive = Loops.ARCHIVE_PRODUCT_ID
		Loops.PASS_PRODUCT_ID = 101
		Loops.ARCHIVE_PRODUCT_ID = 102
		local data = {
			receipts = {},
			passPremium = false,
			gems = 4,
		}
		local ok, err = pcall(function()
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-off", 101)
			expect(granted).toEqual(false)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("The premium track is not for sale yet.")
			expect(data.receipts["receipt-off"]).toEqual(nil)
			expect(data.passPremium).toEqual(false)
			expect(data.gems).toEqual(4)
			expect(next(data.receipts)).toEqual(nil)
		end)
		Loops.PREMIUM_ENABLED = false
		Loops.PASS_PRODUCT_ID = savedPass
		Loops.ARCHIVE_PRODUCT_ID = savedArchive
		if not ok then
			error(err, 2)
		end
	end)

	it("leaves an unknown product receipt unset when premium is on", function()
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local savedPass = Loops.PASS_PRODUCT_ID
		local savedArchive = Loops.ARCHIVE_PRODUCT_ID
		Loops.PREMIUM_ENABLED = true
		Loops.PASS_PRODUCT_ID = 101
		Loops.ARCHIVE_PRODUCT_ID = 102
		local data = {
			receipts = {},
			passPremium = false,
			gems = 7,
		}
		local ok, err = pcall(function()
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-unknown", 999)
			expect(granted).toEqual(false)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("That product is not the Shard Pass.")
			expect(data.receipts["receipt-unknown"]).toEqual(nil)
			expect(data.passPremium).toEqual(false)
			expect(data.gems).toEqual(7)
			expect(next(data.receipts)).toEqual(nil)
		end)
		Loops.PREMIUM_ENABLED = false
		Loops.PASS_PRODUCT_ID = savedPass
		Loops.ARCHIVE_PRODUCT_ID = savedArchive
		if not ok then
			error(err, 2)
		end
	end)

	it("sets passPremium before recording the receipt id", function()
		expect(Loops.PREMIUM_ENABLED).toEqual(false)
		local savedPass = Loops.PASS_PRODUCT_ID
		local savedArchive = Loops.ARCHIVE_PRODUCT_ID
		Loops.PREMIUM_ENABLED = true
		Loops.PASS_PRODUCT_ID = 101
		Loops.ARCHIVE_PRODUCT_ID = 102
		local steps = {}
		local receipts = setmetatable({}, {
			__newindex = function(self, key, value)
				table.insert(steps, "receipt")
				rawset(self, key, value)
			end,
		})
		local data = setmetatable({
			receipts = receipts,
			gems = 0,
		}, {
			__newindex = function(self, key, value)
				if key == "passPremium" then
					table.insert(steps, "pass")
				end
				rawset(self, key, value)
			end,
		})
		local ok, err = pcall(function()
			local granted, duplicate, reason = Loops.grantPremium(data, "receipt-known", 101)
			expect(granted).toEqual(true)
			expect(duplicate).toEqual(false)
			expect(reason).toEqual("")
			expect(data.passPremium).toEqual(true)
			expect(data.receipts["receipt-known"]).toEqual(true)
			expect(steps[1]).toEqual("pass")
			local sawReceipt = false
			local passBefore = false
			for _, step in ipairs(steps) do
				if step == "pass" and sawReceipt == false then
					passBefore = true
				end
				if step == "receipt" then
					sawReceipt = true
					expect(passBefore).toEqual(true)
				end
			end
			expect(sawReceipt).toEqual(true)
			local written = #steps
			local again, againDup = Loops.grantPremium(data, "receipt-known", 101)
			expect(again).toEqual(true)
			expect(againDup).toEqual(true)
			expect(#steps).toEqual(written)
			expect(data.gems).toEqual(0)
			expect(data.passPremium).toEqual(true)
			expect(data.receipts["receipt-known"]).toEqual(true)
		end)
		Loops.PREMIUM_ENABLED = false
		Loops.PASS_PRODUCT_ID = savedPass
		Loops.ARCHIVE_PRODUCT_ID = savedArchive
		if not ok then
			error(err, 2)
		end
	end)
end)
