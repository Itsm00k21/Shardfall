# Roll test gaps

G-055. Cases the roll specs do not lock. Read against `RollMath.luau`, `RollLoop.luau`, `RollBoard.luau`, and `tests/RollMath.spec.luau`, `tests/RollLoop.spec.luau`, `tests/RollBoard.spec.luau`. This file does not change code.

The specs already cover the weight sheet, pity not firing at 50, the live guarantee at 1000, weapon and pet and armor and material traits, the one-deep press queue, stop order (tokens, bag, rarity, new, upgrade), chain gates for a closed hub, and disclose lines that do not print 0.0%. The rows below are the holes.

## Risks

| id | risk | where | rating | test to add |
|---|---|---|---|---|
| R1 | A NaN pity counter never becomes a number. The guarantee never fires, and the bar never fills | `RollMath.luau:357-360`, `RollMath.luau:418-430` | high | `rollsSinceLegendary` is `0/0`. The roll is not forced. After it, the counter is `1`, not NaN. Same for `totalRolls` |
| R2 | An auto-stop the ladder does not know keeps rolling | `RollBoard.luau:124-134` | high | `shouldRollAgain(true, "mythic", "Legendary", 3)` is true. `shouldRollAgain(true, "", "Common", 3)` is true. `shouldRollAgain(true, "Rare", "nope", 3)` is true. A real stop still wins: Rare stop plus Rare result is false |
| R3 | A queued press ignores the rarity, new, and upgrade stops | `RollLoop.luau:346-367` | medium | `canChain` with `queued` true, `stopAt` `"Rare"`, `rarity` `"Legendary"`, `isNew` true is true. The same input with `bagFull` true is false. The same input with `tokens` 0 is false |
| R4 | `nextStop` of an unknown word jumps to Uncommon, which is not Off | `RollBoard.luau:169-176` | medium | `nextStop("Off")` is `"Uncommon"`. `nextStop("Legendary")` is `"Off"`. `nextStop("Mythic")` is `"Uncommon"`. `nextStop("nope")` is `"Uncommon"` |
| R5 | Armor and accessory upgrade arrows are untested. A pet must not count as an upgrade | `RollLoop.luau:240-274` | medium | Empty armor slot, same slot, incoming power higher: true. Incoming uid equals the equipped uid: false. `kind` `"Pet"`: false. Accessory slot uses `equipped.accessories`, not `equipped.armor` |
| R6 | A pending uid already in the bag is counted twice by a bad reading of `bagFull` | `RollLoop.luau:277-292` | medium | Cap minus one items, pending uid already in `inventory`: false. Same bag, pending uid absent: true. `pets` holds the pending uid: false |
| R7 | Quick and short reveals above Rare are only locked for Epic | `RollLoop.luau:72-104` | medium | Legendary, Mythic, and Secret with `quick` true equal `math.min(RollReveal.duration(...), 1.1)`. Rare with `animation` `"short"` equals `math.min(base, 0.7)`. Reduced motion stays 0 for Secret |
| R8 | `mint` error paths and the craft pool default are untested | `RollMath.luau:467-485` | medium | Unknown template throws. Empty uid throws. Omitted `poolId` stores `"craft"`. A non-number `now` stores `0`. Pity is unchanged |
| R9 | A bad weight or an unknown rarity throws out of the roll | `RollMath.luau:131-147`, `RollMath.luau:165-170` | medium | `entryWeight` on rarity `"Godly"` throws. A negative weight throws. A pool whose positive weights are all filtered by pity throws from `pickFrom` |
| R10 | Accessory drops are not in the trait test | `RollMath.luau:397-402` | low | Kind `"Accessory"` at Rare has `#traits == 0`. Kind `"Cosmetic"` has `#traits == 0`. Weapon at Rare still has one |
| R11 | Equal power keeps the current best. A non-table challenger is ignored | `RollLoop.luau:415-433` | low | Same rarity, `powerOf` tied: `best` returns the current uid. `best(current, "nope")` returns current |
| R12 | History tie-break and junk rows | `RollBoard.luau:138-158` | low | Two items, same `obtainedAt`, uids `"b"` and `"a"`: `"a"` is first. A string in the list is dropped. `limit` 0 returns an empty list |
| R13 | Pity text and the 1% format boundary | `RollMath.luau:191-216` | low | `pityText(80, 50)` is `"Pity 50 / 50 toward Legendary"`. `pityText(3, 0)` is `"Pity 1 / 1 toward Legendary"`. `formatChance(0.01)` is `"1.00%"`. `formatChance(0.00999)` is `"0.999%"` |
| R14 | Bar math rejects a bad fill without going NaN | `RollBoard.luau:25-34`, `RollBoard.luau:161-166` | low | `fill(0/0, 100)` is 0. `fill(-4, 100)` is 0. `fill(10, 0)` is 0. `celebrationScale("nope")` is 1. `oddsLines("nope", 0, 0, 0)` is `{}` |

## Cases already locked

Do not re-file these. The spec names are the lock.

| area | locked by |
|---|---|
| Weight percents, luck shift, negative luck, zero-weight omit | `RollMath.spec.luau` describe `RollMath odds` |
| No Legendary at 50. Force at 1000. Natural Legendary clears the counter and is not marked forced | `RollMath.spec.luau` describe `RollMath rolls` |
| One queue slot. A third press stays queued, it does not add a second queue | `RollLoop.spec.luau` first `it` |
| Stop reason order and `blocked` | `RollLoop.spec.luau` second `it` |
| Chain off when the hub, the roll tab, or the player is gone. Hold chains. A queue chains with auto off | `RollLoop.spec.luau` `stops a chain` |
| Server gap is the longer of the cooldown and the reveal | `RollLoop.spec.luau` last `it` |
| Disclose lines, boost, vip, pity argument ignored, no `0.0%` | `RollBoard.spec.luau` |
| Pulse at 0.9 and payoff only when the shown counter is 0 | `RollBoard.spec.luau` third `it` |

## Suggested order

Write R1 and R2 first. A NaN counter and a bad stop string both look like a broken promise to the player. R3 should lock the current rule in a comment on the test: a queued press is a manual extra roll, and the auto stops do not cancel it.

Flags: none. Pity here is the Shardfall dry-roll counter. No paid random item is added by these cases.
