# Echo queue

Echo edits this file freely. Ids are E-001 up. Ghost keeps combat, raids core, server, schema, remotes, data, merging, and TASKS.md.

Feature freeze until soft launch (issue #15, comment 6244316960; Kevin approved `docs/design/LAUNCH_PLAN.md` in comment 6244422751). Until then Echo works only on E-001, E-002 (controller nav), and E-003 (update `docs/design/playtest_script.md`). Do not queue new features.

Launch scope: [docs/design/LAUNCH_PLAN.md](../design/LAUNCH_PLAN.md). E-001, E-002, and E-003 map to M2 (plaza restyle) and M5 (first 60 seconds and playtest). Work only on systems that plan keeps. Leave PARKED systems alone.

## E-001 — done

Phone layout pass. Branch `helper/phone-layout-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/217. Merged at `aa6ebac`.

At 1280×720 and the phone sizes 844×390, 390×844, and 800×380, nothing overlaps or clips: the Gold, Mastery, and Shards counters versus the Forge/gold banner, the Bag rows, the action bar (phone 2×4), and the quest/starter-goal tracker. `tests/PhoneLayout.spec.luau` fails on overlap.

Follows vision priorities 1 and 2 in `docs/design/vision/VISION.md`. The shots in `docs/design/vision/refs/` are reference only. No copied art, names, or paid offers. No premium currency. Nothing costs Robux.

## E-002 — done

Controller nav. Board row T-188. Brief `docs/hooks/T-188.md`. Branch `helper/controller-nav-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/222. Merged at `f7627d9`.

While MenuHub is open, D-pad and the left stick (`Thumbstick1`, one step per deadzone exit) move a `UIStroke` named `PadRing` (4px, RGB 244,240,252, inset). Up and down follow focus order. Left and right jump to the nearest control. The list is `UiRouter.cycle()` plus Close plus the visible buttons on the open page, and it skips `Visible = false` (raids, market, and pass). Opening focuses the opened tab (`sets` uses the bag tab) and shows the ring there. Mouse, touch, and keyboard hide it. The next gamepad step shows it again. ButtonA runs the handler that button already connected, through a registry MenuHub owns. The focused Roll button goes through the #225 `InputBegan` path (`rollFromPointer`), not a direct `pressRoll()` from the pad. `Activated:Fire` is not used. ButtonA is not in the menu sink, so jump still works in the world. ButtonB keeps the #221 capture path already in `InputBegan`. A focused row inside a ScrollingFrame is scrolled into view. `PadNav` in Shared owns the next index, the deadzone, and which D-pad keys count. `PadFocus` is the client module that calls it. Schema stays 26. No new remote. The action bar is unchanged: closed-hub D-pad slots, ButtonY dodge, ButtonR1 light, and ButtonX heavy stay on the base binds. The one-tap crack guard stays (both `rollButton.Activated` and `InputBegan` still call `pressRoll`, and a pointer press does not crack a second time). The click harness covers the ring, ButtonA on Roll cracking once, ButtonB, scroll, and those closed-hub actions.

Follow-up approved in issue #15 comment 6245616667. Ghost is listing it. No new id. Default yes on both: clear `hubState.restColor` keys in `hubFn.clear`, and unparent `PadRing` before `Destroy` when its row is in the cleared subtree.

## E-003 — in progress

Update the existing `docs/design/playtest_script.md`. Do not create `docs/qa/PLAYTEST_SCRIPT.md`. Branch `helper/playtest-script-9721`. 10 steps max. Each step says what you should see. Feel and looks only.

## Next

After E-001, E-002, and E-003, queue only M2 and M5 core-loop polish from `docs/design/LAUNCH_PLAN.md`. That is the first-run flow (spawn, plaza, first dungeon, first loot, first crack in under 60 seconds), readability, and phone feel. Do not add new ids for that polish.

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
