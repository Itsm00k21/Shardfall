# Onboarding research

G-054. First-five-minute patterns from published Roblox beginner notes, set against `docs/design/shardfall_onboarding.md` and the live step list. This file does not change code.

Choice: the other games were not opened. A blank cell means this pass found no first-five note. Shardfall's minute plan is the design doc. The live steps are `Onboarding.STEPS`. The two kits are `Onboarding.starter` and `FirstSessionKit.grant`.

Flags: these rows name live experiences so we do not copy them. Do not take fruit names, aura names, weapon-roll menus, or a group-gated auto button into Shardfall.

## What the notes agree on

| pattern | where it showed up | Shardfall doc | take |
|---|---|---|---|
| One next step, visible | Blox Fruits: talk to the quest NPC before the first hits (Earnaldo, updated 2026-08-26) | Goal tracker after minute 5, three at a time | Keep `StarterGoals`. Three visible, five total |
| The first rare thing is the hook | Sol's RNG tutorial: roll, open storage, roll 10, drink the tutorial potion (Fandom tutorial, updated 2026-07-29) | First reel is Rare or better, then the weapon changes | Keep the reel. Do not make the reel the class |
| Menus before the first fight | Anime Zero: codes, a weapon roll, two slots, then a damage node, then Story (Bloxodes, 2026-10-06) | Fight first, roll second, Haven last | Keep fight-then-roll. Do not open with a code box |
| The "tutorial" is the whole first region | Blox Fruits First Sea is described as levels 1 to 700, about 4–8 hours (same Earnaldo note) | Haven at minute 5, then Rootvault Normal | Keep the five-minute wall. Do not stretch the teach across a sea |
| Auto and a shorter roll are separate | Sol's RNG: auto roll wants a group join. Quick roll is a 100 Robux pass (AllThingsHow, 2026-08-30) | Not in the five-minute doc. Live auto is on the Roll tab | Keep free auto. Do not gate it on a group or a pass |

Dungeon Quest's first five minutes were not opened this pass. G-048 already has the loop: a dungeon, then better gear. Nothing new from that title here.

## Design timeline against the live steps

The doc's clock is the draft dated Oct 16 2026. The live list is six lines. There is no cutscene module behind step `open`.

| doc clock | doc beat | live | gap |
|---|---|---|---|
| 0:00–0:20 | Sky, a 10s skippable cutscene, one narrator line | `open`: "The sky cracked. Shards fell on the wilds." (`Onboarding.luau:14`) | Text only. The doc already allows a camera pan for beta |
| 0:20–0:50 | Five pedestals, a 3s move, "You can switch anytime at the Forge" | `class`: "Five pedestals. Pick the one that fits your hands." (`Onboarding.luau:16-18`) | No preview timer in this module |
| 0:50–1:40 | Three saplings, skill 1, a red dodge, a level-up, skill 2 | `swing` and `dodge` only (`Onboarding.luau:20-21`) | No skill step and no level-up step |
| 1:40–2:20 | Carry a shard to a shrine. Rare or better. Socket it. The swing changes | No step id. The floor lives on `FirstSession.CONFIG.rollFloor` (`FirstSession.luau:42`) | The teach is a reward rule, not a step |
| 2:20–3:40 | Two rooms, a door choice, a mini-boss | `door`: "Two doors. Look, then choose." (`Onboarding.luau:22`) | No mini-boss step. The armor reward is `FirstSession` step `miniboss` |
| 3:40–4:20 | A Rare chest, then a pet egg that hatches | No chest step. Step id `chest` is `FirstSession.luau:30`. The weapon rarity and the egg floor are `FirstSession.CONFIG` (`FirstSession.luau:43-45`) | Same split |
| 4:20–5:00 | Plaza flyover, daily chest, goal "Clear Rootvault (Normal)", a Legendary passerby | `haven`: "Haven. The Forge remembers what you carry." (`Onboarding.luau:23`) | No flyover, no daily chest, and no passerby in this module |
| After 5:00 | Five goals, three at a time, each pays Shard Keys | `StarterGoals.GOALS` is those five lines. `visible` is 3. Pay is 10 `shardKeys` (`StarterGoals.luau:43-62`) | The parenthetical "unlock talent" is not on the level row. The row says "Reach Lv 5" |

The button only advances `open` and `haven`. Any other step returns "Try it in the world first." (`OnboardingService.luau:46-47`). Swing, dodge, class, and door move when the world calls `note`. Skip is the way out. That matches "skip the intro." It does not match a per-step skip.

## Two kits

The design says skip and finish pay the same starter rewards. The service comment says the same thing (`OnboardingService.luau:6`). The functions do not.

| path | what runs | what the player gets |
|---|---|---|
| Last step, or Advance on `haven` | `Onboarding.starter` only (`OnboardingService.luau:27-28`, `OnboardingService.luau:50-51`) | +250 gold, +40 Shard Keys, one Rare chest, one Uncommon chest, three healing tonics, `onboardDone` (`Onboarding.luau:52-65`) |
| Skip | `Onboarding.starter` if not done, then `FirstSessionKit.grant` (`OnboardingService.luau:63-68`) | The currency kit, plus the grant when it accepts |
| Grant, when it accepts | Weapon for the class, `woven_bark_vest` if the miniboss step is open, Shardjaw if they do not own one (`FirstSessionKit.luau:244-275`) | `RING_ID` is nil, so the free ring in the doc is not minted (`FirstSessionKit.luau:32`, `FirstSessionKit.luau:283`) |
| Grant, Forgeborn | The weapon must be Common `iron_hammer` (`FirstSessionKit.luau:190-193`) | The doc's "Rare weapon for every class" is already not true for Forgeborn |
| Grant, no class yet | Returns an error and does not mint (`FirstSessionKit.luau:180-183`). Skip ignores that return (`OnboardingService.luau:68-69`) | Skip still marks the currency kit done. The weapon waits for a later grant |

`ClassService` also calls `grant` (`ClassService.luau:86`). A second grant should no-op once `FirstSession` has marked the steps. Suggested check, not a new reward: one skip and one full clear end with the same gold, the same keys, the same weapon, the same vest, and one Shardjaw.

The doc's "by minute 6, about four upgraded slots and a socketed Rare" is ahead of this code. The live finish path pays chests and tonics, not worn gear. The live skip path can pay a weapon and a vest on top.

## What to keep from the doc

| keep | drop |
|---|---|
| One short line and a hint. The live hints are already that short | A second tutorial track (codes, a stats menu, a group join) |
| Fight, then roll, then Haven, inside five minutes | A first region that is the whole tutorial |
| Rare-or-better first roll, then the swing changes | A roll that replaces the class |
| Skip pays the kit. Finish pays the kit | Two different functions for those two endings |
| Three goals after Haven. Rootvault Normal is the first one | A Legendary passerby as a required beat. It can stay a tease |
| Touch: the world teaches swing and dodge. The button is for open, haven, and skip | Keyboard-only hints on those two prompts |

## Sources

| source | date | used for |
|---|---|---|
| `docs/design/shardfall_onboarding.md` | draft Oct 16 2026 | The minute plan this file compares |
| https://earnaldo.com/blog/blox-fruits-beginner-guide | updated 2026-08-26 | First half hour, quest-before-hits, First Sea length |
| https://sol-rng.fandom.com/wiki/Tutorial | updated 2026-07-29 | Roll, storage, 10 rolls, tutorial potion, later quest batches |
| https://allthings.how/sol-s-rng-how-to-get-auto-roll-and-quick-roll-in-roblox/ | 2026-08-30 | Group gate on auto roll, 100 Robux quick roll |
| https://bloxodes.com/articles/anime-zero-beginner-guide | 2026-10-06 | Menus and a weapon roll before the first dungeon |
