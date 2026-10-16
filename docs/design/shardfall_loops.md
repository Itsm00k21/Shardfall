# Shardfall Daily & Weekly Loop v1 (draft, Oct 16 2026)

## Principles
- A great day takes 20-40 min of dailies; a casual day takes 10 min and still feels worth it.
- No FOMO punishment: missed dailies partly carry over; streaks have grace days.
- Dailies push players into the fun stuff (dungeons, pets, crafting, groups), never chores.
- Resets: daily at 00:00 UTC with a local-time countdown; weekly on Monday.

## Daily (every day)
| Activity | Time | Reward |
|---|---|---|
| Login chest (streak calendar) | 5 s | Common to Epic chest by day; day 7 = Epic, day 28 = Legendary chest + cosmetic |
| 3 daily quests (pick from 5; 1 free reroll) | 10-20 min | Shard Keys, gold, XP; complete all 3 = bonus chest |
| First Rootvault clear of the day | 6-8 min | 3x XP, guaranteed Rare Chest |
| Daily boss (rotating realm boss) | 3-5 min | Epic chest chance, boss mats |
| Free daily bonus roll (2x luck) | 5 s | shard roll |
| Pet care moment (pet, feed) | 30 s | Affinity + small treat |
| Forge "Daily Commission" (craft 1 requested item) | 2-5 min | crafting XP, Dust |
Quest examples: "Clear 2 rooms using only skills", "Dodge 15 attacks perfectly", "Hatch an egg", "Help a player under Lv 10" (Mentor Tokens), "Discover a hidden combo hint".

## Weekly
| Activity | Reward |
|---|---|
| 5 weekly quests (bigger: "Clear Rootvault Hard 5x", "Reach Affinity +2 with a pet") | Epic chest, gems (free trickle), Shard Keys |
| Weekly world boss / The Heartwood raid (post-beta), lockout once/week for top loot | Relic Set pieces, Legendary chest chance |
| Nightmare Challenge (rotating modifier, timed leaderboard) | title/aura for top 10, Rare+ chests for clears |
| Guild weekly quest (post-beta) | guild XP, guild chest |
| Weekly Shard Spotlight (one featured shard set has boosted odds) | reason to roll this week |
| Weekly Market/Forge special (rotating recipe) | crafting variety |

## Streaks without punishment
- Login streak calendar of 28 days; missing a day doesn't reset, the calendar just pauses.
- Daily quest catch-up: unfinished dailies bank up to 2 days.
- Streak shields: 1 free per week (more via Patron).

## Session flow (example 30-min day)
Login chest -> pet care -> daily roll -> daily quests while running the first Rootvault clear (3x XP) -> daily boss -> Forge commission -> check Market/leaderboard -> log off with a session recap.

## Event layer on top (from progression doc)
Hourly Shardstorms, world bosses every 2-3 h, weekend rushes, seasonal events, community goals.

## Monthly / Seasonal
- Season Pass (6-8 weeks): free + premium track; XP from dailies/weeklies fills it.
- Monthly Mastery challenge with a unique title.

## Notifications (opt-in)
Roblox experience notifications: "Your daily chest is ready", "Shardstorm in 5 min", "Your pet misses you" (max 1/day, never spammy).

## Beta scope
Login streak, 3 dailies + rerolls, first-clear bonus, daily boss (Gnarl variant), weekly quests, Nightmare Challenge leaderboard.

---
# v2 Research & Design (Oct 16 2026)

## A. Sourced findings (quotes are from pages pulled via web search)
- **Passes you keep after buying are loved.** r/marvelrivals: "Permanent battle pass is definitely a big deal... a really nice FOMO compromise." (https://www.reddit.com/r/marvelrivals/comments/1h6m0qk/this_is_insane/). r/halo: "No FOMO crap, just grind whenever you feel like it." (https://www.reddit.com/r/halo/comments/nzpc5h/halo_infinite_seems_to_have_the_best_battle_pass/). r/Helldivers: "I'm asking to be able to take a break and not forever miss out on rewards I paid for the ability to earn." (https://www.reddit.com/r/Helldivers/comments/1hr065y/)
- **Bringing back an old pass for a limited time still reads as FOMO.** Marvel Rivals Dev Talk Vol.14 re-sold the S0 pass for a limited time. A reply: "this is not eliminating fomo it is using fomo to get you to buy it." (https://www.reddit.com/r/marvelrivals/comments/1klo70g/)
- **Rivals gotcha:** the pass must be bought before the season ends, and Steam players were caught off guard that you "need to unlock pages again." (https://steamcommunity.com/app/2767030/discussions/0/591768737062847801/)
- **Premium currency back from the pass:** Fortnite's pass "will now cost 800 V-Bucks and award 800 V-Bucks for completing it" (it used to be 1,000 plus 500 bonus). (https://www.fortnite.com/news/fortnite-v-bucks-price-increase)
- **Warframe Nightwave catch-up:** missed Weekly and Elite acts come back "three at a time". Daily acts last 3 days. Dailies give 1,000 standing, weeklies 4,500, elites 7,000, and each of the 30 ranks costs 10,000. (https://wiki.warframe.com/w/Nightwave). One player said "I started last week and was able to get to level 30 from level 1" (https://www.reddit.com/r/Warframe/comments/d964pd/). Players also enjoyed the "Pet your Kubrow or Kavat (Very Important)" daily (https://www.reddit.com/r/Warframe/comments/bmzxb6/).
- **FFXIV Wondrous Tails bingo:** 9 seals land at random on a 4x4 grid, and lines pay rewards. Second Chance points come from running duties with players new to them: "a great incentive to play with newer players" (https://www.icy-veins.com/ffxiv/wondrous-tails-guide-and-weekly-rewards). Retry costs 1 point and Shuffle costs 2. (https://ffxiv.gamerescape.com/wiki/Wondrous_Tails)
- **Chore fatigue:** "Felt like opening a work email at 11pm... a chore list someone else wrote for me." (https://www.reddit.com/r/MMORPG/comments/1uevnsd/). "people do their chores for progress and then log off... the entire thing appears to be joyless." (https://www.reddit.com/r/MMORPG/comments/1bh28ob/). Genshin commissions: "too low stakes for me to care but too rewarding for me to skip entirely" (https://www.reddit.com/r/Genshin_Impact/comments/yc1c1n/). But some players say "they've fit into my daily routine really well" when they only take about 15 minutes.
- **Anti-FOMO praise:** GW2 players note that event rewards come back later: "every single reward available next year anyway." (https://www.reddit.com/r/Guildwars2/comments/1o5yh0v/)
- **Not researched in depth this pass (general knowledge only, verify before relying on it):** Destiny 2 pinnacles and bounty clutter (bounties were later reduced), Warframe Sortie, Archon Hunt and Steel Path weekly rotations, FFXIV Duty Roulette daily bonus, Apex, Diablo IV and PoE seasons, HSR's daily training (about 5 min, one 500-point bar), and Roblox games (Blox Fruits, PS99, Anime Last Stand), which commonly use login calendars and passes with Robux tier skips.

## B. Shardfall design
**Daily (target 15-25 min; 5 min "minimum day" still gets ~60% of value)**
- **Daily Bar (HSR-style):** fill 500 Activity from any mix of activities (dungeon clear 200, quest 100, boss 150, Forge 100, pet care 50). Fill it and get the daily chest plus Pass XP. You choose how to fill it.
- **3 dailies from a pool of 5, 1 free reroll.** Dailies stay up for **3 days** (Nightwave-style) so missing one day costs nothing.
- **Daily Roulette (Duty Roulette):** your first random dungeon run gets +100% XP and a Rare chest, plus a bonus if your party has a new player.
- **Login calendar:** missing a day pauses it instead of resetting it. You get 2 free grace days a month.

**Weekly (target 2-3 h per week, spread out)**
- **Shard Board, bingo-style:** each week you get a 4x4 grid. Clearing 9 activities places 9 seals at random, and lines pay out: 1 line gives an Epic chest, 2 give Gems plus Keys, 3 give a Legendary chest. **Second Chance** points come from running content with players under level 10 or new to it (max 9), with Retry for 1 and Shuffle for 2. This is the community hook.
- **5 weekly quests plus 2 Elite** (Nightmare or raid). Missed weeklies are kept and come back 3 at a time.
- **Weekly world boss/raid lockout** and a **Nightmare leaderboard** (top 10 earn titles).
- **Group bonus:** party runs give +15% Pass XP, and Patron aura stacking stays under the +100% cap.

**Shard Pass (about 8-week season)**
- **50 tiers**, each costing 10,000 Pass XP. Grind target: about 35 min a day finishes it in about 6 weeks, leaving 2 weeks of slack. A casual 15 min a day plus weeklies should still reach about tier 40 (estimates, to be tuned in playtests).
- **Free track:** Keys, Dust, gold, 2 pet cosmetics, a title, and about 25% of the premium Gem cost back.
- **Premium track (about 400 Robux of Gems):** about 10 skins, pet hats and trails, a weapon VFX and an emote, plus **100% of the premium price refunded in Gems** by tier 50 (Fortnite-style "pass pays for the next"). No raw power, so it doesn't break shard/Relic balance.
- **Never expires once bought:** finish it any season, and earned tiers are never re-locked (avoids the Rivals complaint). Past passes can be bought anytime from a "Pass Archive" at about +20% (Halo-style, permanent, not limited-time).
- **Overflow:** after tier 50, repeatable Shard Key caches.
- **Tier skips** cost Gems, but the top cosmetic also needs a feat (for example, clear Nightmare) so whales can't buy the bragging piece outright.

**Surprise and delight:** a 1-in-20 "Lucky Quest" pays triple, a pet sometimes brings you a gift, Shardstorm events give double Pass XP, and a weekly Pet Moment quest (Warframe's "pet your Kavat" was a fan favorite).

## C. Pitfalls to avoid
1. Dailies so rewarding that players do them and log off. Keep about 60% of progress in normal play (Genshin sentiment).
2. Streak resets and expiring paid content (the top hate).
3. "Limited return" passes that create new FOMO.
4. Fetch, talk-to quests: every task should be real gameplay.
5. Odd-numbered costs and leftover waste (Genshin resin complaint). Make sure the numbers divide evenly.
6. Quest clutter (Destiny bounties, general knowledge): cap visible tasks at about 8.
7. A pass you can only finish by grinding hard. Ship with a slack buffer and catch-up XP in the last 2 weeks.

## Beta build (T-015)

The beta loop (login streak, 3 dailies with one reroll, first-clear bonus, daily Gnarl, weeklies, Nightmare leaderboard) is already live. This pass adds the Shard Board polish and the premium track, with the track switched off.

**Shard Board.** Each week is a 4x4 grid. Finishing a daily or weekly places one seal on a random empty cell, and the week stops at 9 seals. A line is a full row, a full column, or either diagonal. Payouts are unchanged: 1 line is an Epic chest, 2 lines are 5 Gems and 3 Shard Keys, 3 lines are a Legendary chest. `boardLines` is a high-water mark, so Retry or Shuffle cannot farm the same chest twice.

**Second Chance.** Helping another player under level 10, or a player who is new to that content, grants 1 point, up to 9. You cannot credit yourself. Retry costs 1 and moves one seal. Shuffle costs 2 and lays the same seals down again at random. The count is `boardChance` on the profile, a number from 0 to 9. The board stays a pure 16-boolean array. Points survive the weekly board reset. They are earned by helping, and the cap is 9, so a new week does not wipe them. There is no party list in the live run yet, so points stay at 0 until GHOST calls `LoopService.noteMentor` from a clear that has an ally. The call is server-only.

**Shard Pass.** 50 tiers, `Loops.PASS_XP` (1000) each, same pace the free track already uses. The design note of 10,000 per tier is a tuning target for when the pass is published. Changing it now would slow free players, so it stays 1000.

The premium track is cosmetics and a Gem refund. No gold, keys, dust, or stats. It has 10 skins, 2 pet hats, 2 trails, 1 weapon VFX, and 1 emote. Gem rows pay 40 and sum to 400, which is the 400 Robux price. Tier 50 is Nightmare Bloom and pays no Gems. It stays locked until `nightmareBest` is at least 1, so the bragging skin cannot be bought outright. A tier skip costs 80 Gems, adds one tier of Pass XP, and still cannot claim Nightmare Bloom without that clear. After tier 50, each extra tier is a cache of 4 Shard Keys. That overflow function is not called from the live free claim.

A bought pass never expires, and earned tiers are never re-locked. The Pass Archive is the same entitlement at 480 Robux (400 plus 20%). It does not refund more Gems than the 400 price. Product ids are 0 until GHOST publishes them. A non-positive id never matches.

`Loops.PREMIUM_ENABLED` is false. While it is false, `grantPremium`, `claimPremium`, and `skipTier` refuse and write nothing, so a receipt is left pending instead of being swallowed. Free claim rewards are unchanged. The client Pass button still gets "The premium track is not for sale yet."
