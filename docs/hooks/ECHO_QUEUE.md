# Echo queue

Echo edits this file freely. Ids are E-001 up. Ghost keeps combat, raids core, server, schema, remotes, data, merging, and TASKS.md.

Ghost approved the lane split in issue #15 (comment 6244200982) and this starting queue (comment 6244209275). E-003 follows the correction in comment 6244222156.

## E-001 — this PR

Phone layout pass. Branch `helper/phone-layout-9721`. PR https://github.com/Itsm00k21/Shardfall/pull/217.

At 1280×720 and the phone sizes 844×390, 390×844, and 800×380, nothing overlaps or clips: the Gold, Mastery, and Shards counters versus the Forge/gold banner, the Bag rows, the action bar (phone 2×4), and the quest/starter-goal tracker. `tests/PhoneLayout.spec.luau` fails on overlap.

Follows vision priorities 1 and 2 in `docs/design/vision/VISION.md`. The shots in `docs/design/vision/refs/` are reference only. No copied art, names, or paid offers. No premium currency. Nothing costs Robux.

## E-002 — queued

Controller support. D-pad and stick move through every MenuHub tab and button with a visible selection ring. B closes. The action bar maps to controller buttons. Extend the click harness from #213.

## E-003 — queued

Update the existing `docs/design/playtest_script.md`. Do not create `docs/qa/PLAYTEST_SCRIPT.md`. 10 steps max. Each step says what you should see. Feel and looks only.

## Next

After E-001, E-002, and E-003: a pet evolution rules module and tests, then the raid wiring PRs (contest, weekly loot lock, leaver rules, loot stamps). Any remote or schema change goes in its own PR first for Ghost review.

## Questions

No remote, schema, or shared-module change is waiting on Ghost. Defaults used in E-001:

1. The mid-left rail still overlaps the portrait on 844×390 and 800×380. Seven 44px buttons do not fit under the 56px portrait and inside the 16px margin. Default: leave `railFit`. Shrinking a button under 44, or dropping a rail button, is Ghost's call.
2. The equip prompt and the heavy chip still meet the 2×4 bar on 844×390 and 800×380. The toast stack, the prompt, and the bar cannot all stack on a 390-tall screen. Default: the bar stays at the bottom and the prompt stays under the toast. The layout spec does not fail that pair.
3. The gold banner stays on BannerFit's 8px lane (`y = 8` on landscape and on 1280×720). It is inside the viewport. It is not pulled down to the 16px safe margin.
4. Counters stay top-right. On a viewport under 500px wide they are a column. Vision's left-edge column is not used, because that edge is the portrait, the HP bar, and the rail.
5. On 844×390 and 800×380 the bag body is 36–46px tall and scrolls. Header, tabs, and filters stay 44px. Default: scroll, do not squash the card.
6. No build stamp. The client build print is unchanged. Schema stays 26.
