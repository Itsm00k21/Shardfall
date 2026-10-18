# Echo queue

Echo edits this file freely. Ids are E-001 up. Ghost keeps combat, raids core, server, schema, remotes, data, merging, and TASKS.md.

Feature freeze until soft launch (issue #15, comment 6244316960; Kevin approved `docs/design/LAUNCH_PLAN.md` in comment 6244422751). Echo's open row is E-006. Do not queue new features. Ghost is holding the phone layout recheck until the `-a6e7` layout lane goes quiet.

Launch scope: [docs/design/LAUNCH_PLAN.md](../design/LAUNCH_PLAN.md). E-001 through E-006 map to M2 (plaza restyle) and M5 (first 60 seconds and playtest). Work only on systems that plan keeps. Leave PARKED systems alone.

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

## E-006 — in progress

Controller pass on the first-60s path. Branch `helper/controller-first60-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/262 into `cursor/live-build-9721`.

The click harness drives a gamepad from Close. With the hub tab column hidden, `PadRing` reaches the rail Roll, Bag, and Pets buttons, then the bag upgrade row (the in-hub Forge step). ButtonA runs the existing `padPress` registry. `UiRouter.switch` opens each rail page. The Roll crack button still cracks once through `rollFromPointer`. The Gold shop Healing Tonic and bag slot buy on ButtonA. Input stays in `Keybinds.luau`. Schema stays 26. No new remote. The plaza Forge sheet, the Chests button, and `SetChestOptions` stay on Ghost's lane.

Assigned in issue #15 comment 6246173340. Cleared to start in PR #255 comment 6246379892.

## Next

E-006 is in progress on `helper/controller-first60-9721`. The phone layout recheck stays with Ghost until the `-a6e7` layout lane goes quiet. Do not start that recheck from this queue.

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
