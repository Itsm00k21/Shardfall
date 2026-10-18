# Echo queue

Echo edits this file freely. Ids are E-001 up. Ghost keeps combat, raids core, server, schema, remotes, data, merging, and TASKS.md.

Feature freeze until soft launch (issue #15, comment 6244316960; Kevin approved `docs/design/LAUNCH_PLAN.md` in comment 6244422751). E-009 is done. E-010 is in review. Do not queue new features. The phone layout recheck is E-010.

Launch scope: [docs/design/LAUNCH_PLAN.md](../design/LAUNCH_PLAN.md). E-001 through E-007 map to M2 (plaza restyle) and M5 (first 60 seconds and playtest). Work only on systems that plan keeps. Leave PARKED systems alone.

## E-001 — done

Phone layout pass. Branch `helper/phone-layout-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/217. Merged at `aa6ebac`.

At 1280×720 and the phone sizes 844×390, 390×844, and 800×380, nothing overlaps or clips: the Gold, Mastery, and Shards counters versus the Forge/gold banner, the Bag rows, the action bar (phone 2×4), and the quest/starter-goal tracker. `tests/PhoneLayout.spec.luau` fails on overlap.

Follows vision priorities 1 and 2 in `docs/design/vision/VISION.md`. The shots in `docs/design/vision/refs/` are reference only. No copied art, names, or paid offers. No premium currency. Nothing costs Robux.

## E-002 — done

Controller nav. Board row T-188. Brief `docs/hooks/T-188.md`. Branch `helper/controller-nav-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/222. Merged at `f7627d9`.

While MenuHub is open, D-pad and the left stick (`Thumbstick1`, one step per deadzone exit) move a `UIStroke` named `PadRing` (4px, RGB 244,240,252, inset). Up and down follow focus order. Left and right jump to the nearest control. The list is `UiRouter.cycle()` plus Close plus the visible buttons on the open page, and it skips `Visible = false` (raids, market, and pass). Opening focuses the opened tab (`sets` uses the bag tab) and shows the ring there. Mouse, touch, and keyboard hide it. The next gamepad step shows it again. ButtonA runs the handler that button already connected, through a registry MenuHub owns. The focused Roll button goes through the #225 `InputBegan` path (`rollFromPointer`), not a direct `pressRoll()` from the pad. `Activated:Fire` is not used. ButtonA is not in the menu sink, so jump still works in the world. ButtonB keeps the #221 capture path already in `InputBegan`. A focused row inside a ScrollingFrame is scrolled into view. `PadNav` in Shared owns the next index, the deadzone, and which D-pad keys count. `PadFocus` is the client module that calls it. Schema stays 26. No new remote. The action bar is unchanged: closed-hub D-pad slots, ButtonY dodge, ButtonR1 light, and ButtonX heavy stay on the base binds. The one-tap crack guard stays (both `rollButton.Activated` and `InputBegan` still call `pressRoll`, and a pointer press does not crack a second time). The click harness covers the ring, ButtonA on Roll cracking once, ButtonB, scroll, and those closed-hub actions.

Follow-up is E-004 (issue #15 comments 6245616667 and 6245850348).

## E-003 — done

Update the existing `docs/design/playtest_script.md`. Do not create `docs/qa/PLAYTEST_SCRIPT.md`. Branch `helper/playtest-script-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/237. 10 steps max. Each step says what you should see. Feel and looks only. Checked against `3b65804`. T-222, T-223, T-224, T-226, and T-227 are finished behavior. A new profile shows 10 shards. The settings rail caption reads Gear. The Gold shop lists a Healing Tonic and a bag slot. A pet slot is not for sale.

## E-004 — done

Clear stale `restColor` keys and unparent `PadRing` when MenuHub rebuilds a page. Branch `helper/restcolor-padring-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/245. Merged at `1138ae1`.

`hubFn.clear` drops `hubState.restColor` keys for the destroyed row and its descendants. It unparents `PadRing` before `Destroy` when that row is in the cleared subtree, so the same stroke can show again on the next gamepad step. Tabs and Close keep their rest colors. `GuiFake` `Destroy` locks `Parent` after `Destroy`, and children are destroyed too. Schema stays 26. No new remote. Kill switches stay off.

Approved in issue #15 comment 6245616667. Listed in comment 6245850348.

## E-005 — done

Refresh the existing `docs/design/playtest_script.md` for the behavior on `b4ef5a2` (PRs #242 through #250, plus instant Equip from #241, already on that tip). Do not create `docs/qa/PLAYTEST_SCRIPT.md`. Branch `helper/playtest-refresh-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/255 into `cursor/live-build-9721`. Merged at `a27ff39`.

Ten phone steps, about 15 minutes. Each step has a pass line. Feel and looks only. A Heavy tap shows the swing at once and the hit lands after about a third of a second, in front of the character. The bag tip shows the name in the rarity color, one stat per line, and stays on screen. Equip reads Equipped at once. One rail, and the hub tab column stays hidden. Settings hides Trades, Raid invites, and the raids and market hotkeys. Salvage, the dust shop, and the daily boss stay hidden. The Forge sheet scrolls an upgrade row on 390×844 and 844×390. Docs only. Schema stays 26.

Assigned in issue #15 comment 6246173340.

## E-006 — done

Controller pass on the first-60s path. Branch `helper/controller-first60-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/262 into `cursor/live-build-9721`. Merged at `ca72f25`.

The click harness drives a gamepad from Close. With the hub tab column hidden, `PadRing` reaches the rail Roll, Bag, and Pets buttons, then the bag upgrade row (the in-hub Forge step). ButtonA runs the existing `padPress` registry. `UiRouter.switch` opens each rail page. The Roll crack button still cracks once through `rollFromPointer`. The Gold shop Healing Tonic and bag slot buy on ButtonA. Input stays in `Keybinds.luau`. Schema stays 26. No new remote. The plaza Forge sheet, the Chests button, and `SetChestOptions` stay on Ghost's lane.

Assigned in issue #15 comment 6246173340. Cleared to start in PR #255 comment 6246379892.

## E-007 — done

Docs and tests only. Branch `helper/controller-playtest-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/269 into `cursor/live-build-9721`. Merged in #269.

One controller step in the existing `docs/design/playtest_script.md`. Do not create `docs/qa/PLAYTEST_SCRIPT.md`. Open the hub with a gamepad, reach Roll, Bag, and Pets on the rail, then close it. The step has a pass line. Feel and looks only. The other ten steps stay as they are. The click harness tried a gamepad ButtonA and a mouse click on the same rail button in the same frame. On current code that pair fires twice (`UiRouter.switch` once from `padPress`, and the HudShell rail callback once), and the mouse path toggles the hub shut. That case is not in the committed run. No `src/` edit. Schema stays 26. No new remote.

Assigned in PR #262 comment 6246600489.

## E-008 — done

M1 economy invariants. Tests only. Branch `helper/economy-invariants-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/275 into `cursor/live-build-9721`. Merged in #275. Cut from tip `5e2e70e`, then brought onto the base after #270 through #274.

`tests/EconomyInvariants.spec.luau` drives RollShard, BuyGoldShop, and UpgradeGear the way those remotes spend. The harness calls the shared modules, then puts a deep copy back when the mutator returns a reason, which is what `DataService.mutate` does. Gold and Shards stay at or above 0 through a same-frame RollShard burst, a drain past an empty wallet, Gold-shop buys, and Forge upgrades. A refused call compares equal to the profile copied before it. Pity counts up and resets as the Roll panel PityCount prints it (`Pity N/N`, Epic /100, Legendary /1000). Forge gold, the Gnarl's Seed on +8 through +10, and the `Name +N` result match the upgrade table. A new profile from `Schema.template`, `Schema.migrate(nil)`, and an empty reconcile starts with 10 Shards. All five invariants pass. Nothing is pending. Schema stays 26. No remote, no `src/`, no `TASKS.md`, no kill-switch change, no build stamp.

Assigned in PR #269 comment 6246758342.

## E-009 — done

M1 remote fuzz. Tests only. Branch `helper/remote-fuzz-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/285 into `cursor/live-build-9721`. Merged at `0474f65`. Out of `src/`, `TASKS.md`, `ops/`, and `tests/GuiFake.luau`.

`tests/RemoteFuzz.spec.luau` fuzzes every RemoteFunction bound in `src/ServerScriptService/ShardfallServer/Remotes.luau` that is not a key of `PARKED_ACTION`. RemoteEvents (Attack, Dodge, Steer) are skipped. Parked names are skipped: Salvage, BulkSalvage, FusePet, Trade, Market, ClaimPass, PremiumPass, StartDailyBoss, RaidQueue, RaidPost, RaidJoin, RaidPractice, RaidBuy, RaidLeave, RaidReady, BuyTravelPass, BuyDustShard, SetChestOptions, BuyChestBundle, BuyForgeBoost, BuyBoost, BuyPrism, RollPaid, BuyInventoryExpansion.

Each call tries nil, a wrong type, an empty string, a negative, NaN, `math.huge`, a huge string, an unknown id, and an extra argument, as those args apply. The harness uses the same argument checks the remote runs, then the shared module that service calls. A reason or a throw puts the `Schema.deepCopy` back, which is what `DataService.mutate` does. The handler refuses or ignores. It does not throw. A refused or ignored call compares equal to the copy taken before it.

Pending, and not in the committed run: SetAudio accepts a negative and writes `Audio.clampVolume`, which stores 0. `src/ServerScriptService/ShardfallServer/Remotes.luau:444` and `src/ReplicatedStorage/Shared/Audio.luau:41`. No `src/` edit. Schema stays 26. No kill-switch change. No build stamp. Product ids stay 0.

## E-010 — in review

Phone layout recheck. Branch `helper/phone-recheck-9721`, cut from tip `0a6253b`. PR https://github.com/Itsm00k21/Shardfall/pull/291 into `cursor/live-build-9721`. Report `docs/hooks/E-010-phone-recheck.md`. `tests/PhoneRecheck.spec.luau` locks the checks that pass. The playtest script was not edited. No `src/` edit. Schema stays 26. No kill-switch change. Product ids stay 0.

Walked `docs/design/playtest_script.md` at 390×844 and 844×390. Portrait: pass 7, fail 2, manual 2. Landscape: pass 6, fail 3, manual 2. Step 8 fails only in landscape.

Pending, not fixed:

- Portrait hub body under the rail. `MenuHub.luau:902`, `HudLayout.luau:214`, `HudLayout.luau:358`.
- Bag tip clamped to x=8, under the rail at both sizes. `BagBoard.luau:266`, `BagBoard.luau:272`, called from `MenuHub.luau:2312`.
- Landscape rail leaves the 16px inset. `HudLayout.luau:352`.
- Landscape Forge sheet under the rail at every scroll position. `ShellLayout.luau:252`, `Ui.luau:380`.

## Next

Ghost reviews E-010. The four overlaps stay pending. Do not queue a new row.

## PAUSED

Hidden or off per `docs/design/LAUNCH_PLAN.md` (PARKED: code stays, kill switches off, nav hidden). Do not queue these:

- Raid wiring
- Trading / Market Board
- Pet evolution
- Boss pets

## Questions

No remote, schema, or shared-module change is waiting on Ghost. Ghost confirmed the E-001 defaults in issue #15 comment 6244475659:

1. The mid-left rail still overlaps the portrait on 844×390 and 800×380. Leave `railFit`. Do not shrink a button under 44 or drop a rail button in this PR.
2. The equip prompt and the heavy chip still meet the 2×4 bar on 844×390 and 800×380. The bar stays at the bottom and the prompt stays under the toast. The layout spec does not fail that pair.
3. The gold banner stays on BannerFit's 8px lane (`y = 8` on landscape and on 1280×720). It is not pulled down to the 16px safe margin.
4. Counters stay top-right. On a viewport under 500px wide they are a column. They do not move to the vision's left edge.
5. On 844×390 and 800×380 the bag body may scroll at 36–46px. Do not squash the card.
6. No build stamp. This branch does not edit `Build.luau` or the init prints. The printed line is whatever `cursor/live-build-9721` has (`b9366a1+` after the merge).
