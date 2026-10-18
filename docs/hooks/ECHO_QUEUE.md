# Echo queue

Echo edits this file freely. Ids are E-001 up. Ghost keeps combat, raids core, server, schema, remotes, data, merging, and TASKS.md.

Ghost approved the lane split in issue #15 (comment 6244200982) and this starting queue (comment 6244209275). E-003 follows the correction in comment 6244222156.

## E-001 — in progress

Phone layout pass. This PR.

At 1280×720 and the phone sizes 844×390, 390×844, and 800×380, nothing overlaps or clips: the Gold, Mastery, and Shards counters versus the Forge/gold banner, the Bag rows, the action bar (phone 2×4), and the quest/starter-goal tracker. A layout spec fails on overlap.

Reference for the pass: `docs/design/vision/VISION.md` and `docs/design/vision/refs/`. Priorities 1 and 2 (UI that stays usable, then menu readability). The shots are reference only.

## E-002 — queued

Controller support. D-pad and stick move through every MenuHub tab and button with a visible selection ring. B closes. The action bar maps to controller buttons. Extend the click harness from #213.

## E-003 — queued

Update the existing `docs/design/playtest_script.md`. Do not create `docs/qa/PLAYTEST_SCRIPT.md`. 10 steps max. Each step says what you should see. Feel and looks only.

## Next

After E-001, E-002, and E-003: a pet evolution rules module and tests, then the raid wiring PRs (contest, weekly loot lock, leaver rules, loot stamps). Any remote or schema change goes in its own PR first for Ghost review.

## Questions

None yet.
