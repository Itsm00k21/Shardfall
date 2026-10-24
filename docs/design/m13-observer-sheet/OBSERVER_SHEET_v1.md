# M13 Fun-Test Observer Sheet (Kevin's 15-minute go / no-go), v1

Owner: Prism (design, docs only, no code, no config). Used by: **Kevin** (or whoever sits next to the testers). Base: `cursor/live-build-9721`. Status: **v1, ready to print or use on a phone.** Not an official Vision & Design Rules decision.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883818abc23e33d062c9c26 (11:40Z Oct 24, 2026, GO 2, Kevin pre-approved): "M13 fun-test observer sheet for Kevin (what to watch in the first 2 min, stuck points, the 'friends do 2+ runs' tally), docs only."

Sources (link, don't copy): Roadmap **CHECKPOINT: Kevin's 15-minute fun test** (Kevin plays 15 min on a fresh save; 3–6 friends play; nobody explains anything; **Go if** Kevin wants to keep playing after 15 min, most friends do at least 2 runs without being asked, nobody gets stuck in the first 2 minutes) · Roadmap Analytics onboarding funnel (joined → first roll → first equip → entered gate → cleared wave 1 → finished first run → second roll → second run) · #412 first 30 seconds (fast win) · related, **not duplicated here:** PR #436 M13 visual QA checklist (screen-by-screen visual pass, run it *before* the fun test) and PR #434 M13 run smoke (Echo's logic test of the same loop).

**How this differs from #436 and #434:** #434 proves the loop works (code). #436 proves every screen looks right (visual QA at 4 sizes). **This sheet watches people**: where they hesitate, where they get stuck, and whether they choose to play again. It has no pass/fail per screen.

## 1. Goal
One sheet lets Kevin run the fun test without explaining anything, write down what each tester does in their first 2 minutes, mark every stuck point with a short code, tally who does 2+ runs without being asked, and reach a clear **Go / No-go** in 5 minutes after the session.

## 2. Where it lives
- This file: `docs/design/m13-observer-sheet/OBSERVER_SHEET_v1.md` (phone-friendly: short tables, tick boxes, readable on GitHub mobile).
- **Print version:** `mockups/01-print-sheet-letter-816x1056.svg` (one US Letter / A4 page, black on white, open in a browser → Print → "Fit to page"). Print 1 copy per 6 friends.
- **Phone version:** `mockups/02-phone-tally-390x844.svg` (one tester per screen, big tick boxes; a picture of how to fill this file on a phone).
- Results: a photo of the filled sheet (or this file's tables copied into a note) goes to Ghost on the Agent Board / the Notion playtest notes. Prism turns stuck codes into a fix list.

## 3. Flow (how to run the session)
**Before (5 min)**
1. ☐ Build: the live test place on `cursor/live-build-9721` (or the one Ghost names). Write the build stamp from the screen corner: ________
2. ☐ #434 smoke green and #436 visual pass done (or known fails noted), so the test finds fun problems, not known bugs.
3. ☐ LaunchGate flags **as shipped** (don't flip anything for the test).
4. ☐ Kevin on a **fresh save**. Friends on fresh saves if possible (note who isn't).
5. ☐ Stopwatch ready. Write each tester's name + device (phone / tablet / PC) in the tally.

**During (15 min)**
1. Say only: "Play Shardfall for 15 minutes. I'll just watch." **Don't explain, don't point, don't touch their device.**
2. Start the stopwatch when they spawn. In the first 2 minutes, write the time each checkpoint (§4 A) happens.
3. Whenever someone is stuck (§4 B rule), write the **code + time** (e.g. `S4 1:12`). If stuck > 60 s, give **one** short hint and add **R** (rescued), e.g. `S4 1:12 R`.
4. Count runs. A run "starts" when they enter the gate / Waves pier. Mark if the 2nd run happened **without being asked**.
5. Note 1–2 quotes per person (what they say out loud is gold).

**After (5 min)**
1. Ask each friend one question only: "Would you play again tomorrow?" (Y / N / maybe). Don't argue.
2. Kevin answers his own: "Do I want to keep playing right now?"
3. Fill the **Go / No-go** box (§10). Photo the sheet. Post it.

## 4. Layout (what's on the sheet)
### A. First 2 minutes: write the time (m:ss) each happens
Target times are guides from the first-30-seconds rule and the onboarding funnel, not pass/fail.

| # | Checkpoint (funnel step) | Target | F1 | F2 | F3 | F4 | F5 | F6 |
|---|---|---|---|---|---|---|---|---|
| A1 | Moves / looks around (any input) | ≤ 0:05 | | | | | | |
| A2 | Finds the Roll stone (Verdant armory) and rolls (first roll) | ≤ 0:30 | | | | | | |
| A3 | Reads the reveal (says or reacts to the tier/item) | ≤ 0:40 | | | | | | |
| A4 | Equips the item (first equip) | ≤ 1:00 | | | | | | |
| A5 | Reaches the gate / Waves pier and starts (entered gate) | ≤ 1:30 | | | | | | |
| A6 | Clears wave 1 | ≤ 2:00 | | | | | | |
| A7 | Reaction at 2:00: 🙂 into it · 😐 neutral · 🙁 bored/confused | — | | | | | | |

Kevin's own row goes in the same table as **K** if he wants it (he plays too).

### B. Stuck points: write `code m:ss` (add **R** if you hinted)
**Stuck =** no progress for **15 s**, or asks "what do I do?", or opens and closes the same menu 3 times, or walks away from the screen.

| Code | Stuck at | Watch for |
|---|---|---|
| S1 | Finding Roll | wanders the hub, never reaches the Roll stone |
| S2 | Reveal | can't tell what they got, can't close / Skip |
| S3 | Bag / equip | doesn't open the bag, doesn't equip, equips and can't tell it worked |
| S4 | Finding the gate | doesn't find the Waves pier / gate |
| S5 | Start / party | waits at the gate, unsure about Solo vs party or Start |
| S6 | Controls | can't attack, camera fights them, thumbstick/attack missed on phone |
| S7 | Between waves | thinks the run ended, stands still in the break |
| S8 | Boss (wave 5) | dies repeatedly, ignores telegraphs, doesn't know it's the boss |
| S9 | Death / wipe | thinks loot is lost, can't find how to go again |
| S10 | Results | doesn't find Run again / Roll again, closes and wanders |
| S11 | UI in the way | panel over the middle, button too small, text unreadable (write the device) |
| S12 | Other | write one line |

### C. The 2+ runs tally (Roadmap: "most friends do at least 2 runs without being asked")
| Tester | Device | Run 1 (✓ cleared / ✗ died / ← left) | Run 2 started unprompted? (m:ss) | Runs total | Asked to play again? (if yes, Run 2 doesn't count) | "Play again tomorrow?" |
|---|---|---|---|---|---|---|
| F1 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |
| F2 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |
| F3 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |
| F4 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |
| F5 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |
| F6 | | | ☐ yes ☐ no | | ☐ | Y / N / ? |

**Count:** friends with 2+ unprompted runs ____ / friends ____ → more than half? ☐ yes ☐ no

### D. Signals (tick when you see it, any tester)
| Good | Bad |
|---|---|
| ☐ "ooh" / laughs at a reveal | ☐ checks their phone / other app |
| ☐ shows their screen to someone | ☐ sighs, "what now?" |
| ☐ talks about what to roll next | ☐ AFK / walks off |
| ☐ starts a run with a friend on their own | ☐ asks how long this takes |
| ☐ compares items or rarities | ☐ quits before 15 min |

### E. Quotes (1–2 per person)
F1: ______ F2: ______ F3: ______ F4: ______ F5: ______ F6: ______ K: ______

## 5. States
- **Blank** (printed / opened) → **In session** (times and codes filling in) → **Scored** (counts and Go box filled) → **Posted** (photo or copied tables on the board).
- Per tester: *not started* · *in first 2 min* · *playing* · *2+ runs* · *quit (write time)*.
- Mark marks: **R** = rescued with a hint (still counts as stuck) · **–** = didn't happen · **?** = didn't see it.

## 6. Numbers
- Session: 15 min of play + 5 min setup + 5 min scoring. 3–6 friends (Roadmap).
- First-2-min targets: §4 A (roll ≤ 0:30, equip ≤ 1:00, gate ≤ 1:30, wave 1 cleared ≤ 2:00).
- Stuck threshold: 15 s without progress; hint only after 60 s; one hint max per stuck point.
- **Go rules (Roadmap, all three):** Kevin wants to keep playing after 15 min · more than half of the friends do 2+ runs unprompted · **zero** stuck points (S-codes) before 2:00 for anyone. Rescues (R) before 2:00 count as stuck.

## 7. Edge cases
- **Friend has played before:** play anyway, mark "returning"; their first-2-min row doesn't count for the "nobody stuck" rule, their run tally does.
- **Crash / disconnect / server bug:** write `BUG m:ss` + what happened; it isn't a fun signal. If it stops the test for > 2 min, restart that tester's clock and note it.
- **Friend asks a question:** answer only "What do you think?" Write the question (it's a stuck point if it's about what to do).
- **Party play:** friends may team up; that's fine. Each still gets their own row. Note who led.
- **Fewer than 3 friends:** run it, but mark the result "provisional".
- **Kevin is both player and observer:** he fills his own row after; a second person (or a phone voice memo) watches the friends.
- **Paid prompts:** if any Robux prompt shows up, write `PAY m:ss` (there should be none).

## 8. Mockups
SVG in `mockups/` (fake data, original layout): `01-print-sheet-letter-816x1056.svg` (one printable page with all 5 blocks for 6 testers + Kevin) · `02-phone-tally-390x844.svg` (one tester per phone screen, filled example, tick boxes ≥ 44 px). PNG renders on the box only.

## 9. Build split
- **Kevin:** runs the session, fills the sheet, posts the photo.
- **Ghost:** schedules the test, names the build, decides go / no-go follow-ups with Kevin.
- **Prism:** turns stuck codes + quotes into a ranked fix list (UI and readability items) within one board cycle of the photo.
- **Echo / Havoc:** take `BUG` lines and any server-side stuck points (S7–S9 logic).
- Nothing to build in the game for this sheet.

## 10. Pass criteria (the Go / No-go box)
| Rule (Roadmap checkpoint) | Result |
|---|---|
| Kevin wants to keep playing after 15 min | ☐ yes ☐ no |
| Most friends (> half) do 2+ runs without being asked | __ / __ ☐ yes ☐ no |
| Nobody gets stuck in the first 2 minutes (no S-code or R before 2:00) | ☐ yes ☐ no |
| **GO** only if all three are yes | ☐ **GO** ☐ **NO-GO** |

**No-go means** (Roadmap): fix the loop here (pacing, rewards, feel); nothing new gets added until it passes. Write the top 3 stuck codes by count: 1 ____ 2 ____ 3 ____

## 11. Open questions (answer by number)
1. **@Kevin:** Will someone else sit with the friends while you play, or should the sheet assume you watch afterwards (voice memo / screen recordings)? Recommended: one helper watches live; you fill your own row after.
2. **@Kevin:** Print (paper) or phone? Both are in the PR. Recommended: print one page for the room, phone for remote friends.
3. **@Ghost:** Should the stuck codes map to the Roadmap funnel events so Echo's server log can confirm the times later (e.g. A2 = first roll)? Recommended: yes, as a later cross-check only; the sheet stays human-first.

## Decision log
- 2026-10-24 (Ghost GO 11:40Z, Kevin pre-approved; Prism): v1 published on `prism/m13-observer-sheet`. Links #436 (visual QA) and #434 (run smoke) instead of repeating them. Not approved as a Vision & Design Rules decision.

## Roblox build notes
None needed: this is a paper/phone sheet, not game UI. For the test itself use the shipped build: don't flip LaunchGate flags, don't add debug UI, don't show the Studio device frame. If a later version wants an in-game "playtest marker" key for timestamps, it goes to the Ideas Backlog as NOT APPROVED.
