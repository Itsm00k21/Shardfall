# M13 Fun-Test Kit for Kevin, v1.1 (setup · observer checklist · 5-question survey · go / no-go)

Owner: Prism (design, docs only, no code, no config, no flag flips, no save edits). Used by: **Kevin** + one helper. Base: `cursor/live-build-9721`. Status: **v1.1, ready to run.** Not an official Vision & Design Rules decision.
Asked for in: Ghost's Agent Board row DP29 https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96 (Oct 24, 2026, Kevin pre-approved), Next (2): "M13 fun-test kit for Kevin: setup steps, observer checklist, 5-question survey, go/no-go against the canvas pass line." ACK: https://app.notion.com/p/403c31ca388381bda15dc237843e114b. Extends v1 of this PR (#445, `OBSERVER_SHEET_v1.md`), no duplicate PR.

**The pass line (what Go means).** Ghost's M13 canvas card wasn't readable from this session (cursor.com canvas, 403), so this kit uses the source the canvas cites, the **locked Roadmap "CHECKPOINT: Kevin's 15-minute fun test"** (read only, not edited), word for word: **Go if** (1) *Kevin wants to keep playing after 15 min*, (2) *Most friends do at least 2 runs without being asked*, (3) *Nobody gets stuck in the first 2 minutes.* **No-go means** *we fix the loop here (pacing, rewards, feel); nothing new gets added until it passes.* Then *review the Parking Lot, pick at most 2 items.* V1 Core Loop success test: "if it's fun for 15 minutes, the loop works." **v1.2 (Ghost DP31P, confirmed): the §D Go box = the canvas pass line**, exactly: Kevin wants to keep going · friends do 2+ runs · nobody stuck in the first 2 min. No extra line, no time target.

**One-page map:** §A setup (before) → §B observer checklist (during; the v1 sheet, refreshed) → §C 5-question survey (after, ≤ 2 min each) → §D go / no-go box (5 min) → §E what happens next. Print: `mockups/01-print-sheet-letter-816x1056.svg` (observer) + `mockups/03-survey-card-print-816x1056.svg` (6 survey cards). Phone: `mockups/02-phone-tally-390x844.svg` + `mockups/04-survey-phone-390x844.svg`.

---

## 1. Goal
Kevin can run the M13 fun test in **about 30 minutes**: 5 min setup, 15 min play, 5 min survey, 5 min scoring. Nobody explains anything, nobody touches testers' devices, and the decision comes out as a clear **GO / NO-GO** judged only on the 3 Roadmap rules. Everything else (survey, signals, quotes) feeds the fix list, never the verdict.

## 2. Where it lives
- This file (kit entry point) + `OBSERVER_SHEET_v1.md` (v1.1: the checklist itself) in `docs/design/m13-observer-sheet/`.
- Results: photo of the sheets (or the tables copied) → Agent Board row to Ghost + Notion playtest notes. Prism turns them into a ranked fix list within one board cycle.
- Related, not repeated: **#434** run smoke (Echo, code proves the loop), **#436** M13 visual QA (Prism, screens at 4 sizes). Run both **before** the fun test.

## 3. Flow
### §A. Setup (the day before + 5 min before)
| # | Step | Who | Done |
|---|---|---|---|
| A1 | Ghost names the build (branch + build stamp) and a time. Write the stamp: ______ | Ghost | ☐ |
| A2 | #434 run smoke green and #436 visual QA run on that build; known fails written down (so the test finds fun problems, not known bugs) | Ghost / Prism | ☐ |
| A3 | LaunchGate flags **as shipped**. Nobody flips a flag for the test; no debug UI, no Studio device frame | Ghost | ☐ |
| A4 | **Fresh saves without touching real saves:** testers use new or never-played accounts (or Ghost's test-place reset). **No save wipes** of anyone's live data (hard limit). Note who isn't fresh ("returning") | Ghost / Kevin | ☐ |
| A5 | Devices: at least **2 phones** (one tall ~390×844, one small landscape ~667×375) + any tablet / PC. Phones charged, volume ~50% (sound cues are part of the feel), Graphics left on its default (Low on touch) | Kevin | ☐ |
| A6 | Print 1 observer sheet per 6 testers + 1 survey card per tester (or open the phone versions) + pen + stopwatch | Kevin | ☐ |
| A7 | Helper chosen: watches friends live while Kevin plays (v1 Q1 rec). If no helper, phones screen-record (ask first) and Kevin fills rows after | Kevin | ☐ |
| A8 | Join test: everyone on the same server, spawns in the hub, no error toast. If a join fails > 2 min, start without them and note it | Helper | ☐ |
| A9 | Say only: "Play Shardfall for 15 minutes. I'll just watch." Start the stopwatch at each spawn | Helper | ☐ |

### §B. Observer checklist (during, 15 min)
Use `OBSERVER_SHEET_v1.md` (v1.1). Summary of what the helper does:
1. **First 2 min (sheet A):** write m:ss for each checkpoint A1–A7 per tester.
2. **Stuck (sheet B):** no progress 15 s, "what do I do?", same menu 3×, or walks away → write `code m:ss`; hint only after 60 s, one hint, add **R**. Any S-code or R before 2:00 fails pass rule 3.
3. **Runs (sheet C):** mark each run start; was run 2 **unprompted**? Inviting them again = prompted.
4. **Signals + quotes (sheets D, E):** tick good / bad signals; 1–2 quotes each.
5. **Bugs:** `BUG m:ss` (not a fun signal). **Robux prompt:** `PAY m:ss` (there should be none).
6. **Kevin:** plays his own 15 min on a fresh save; at 15:00 he answers one thing before anything else: "Do I want to keep playing right now?" (rule 1). Write it **before** hearing the friends.

### §C. 5-question survey (after, per friend, read aloud, ≤ 2 min, don't argue, don't explain)
Ask in this order, **after** the session ends and **before** any discussion. Q1 is the v1 question (kept so v1 sheets still score).
| # | Question (say it exactly) | Answers (tap / circle one) | Feeds |
|---|---|---|---|
| Q1 | "Would you play this again tomorrow?" | Yes · Maybe · No | signal for rule 2 (not a rule) |
| Q2 | "What was the best moment?" | Rolling / the reveal · Fighting waves · The boss · Getting loot · Playing with friends · Nothing stood out | what to protect |
| Q3 | "Was there a moment you were confused or bored? Where?" | No · Hub / finding things · Rolling · Bag / equip · Waves · Boss · Results / after a run · Other: ____ | fix list (matches stuck codes) |
| Q4 | "The fights felt…" | Too easy · About right · Too hard | pacing (Roadmap: fix pacing on no-go) |
| Q5 | "One thing that would make you play longer?" | one line, their words | Parking Lot review (max 2 items, Roadmap) |
Rules: same words for everyone; no follow-up questions except "Anything else?"; write answers verbatim; a returning tester answers but is marked "R". Kevin answers Q2–Q5 too (his Q1 is rule 1, already written).

### §D. Go / No-go box (5 min; only the 3 Roadmap rules decide)
| Rule (Roadmap checkpoint, word for word) | How to score it from the sheets | Result |
|---|---|---|
| 1. Kevin wants to keep playing after 15 min | Kevin's own answer at 15:00 (§B step 6), written before the survey | ☐ yes ☐ no |
| 2. Most friends do at least 2 runs without being asked | sheet C: friends with ≥ 2 **unprompted** runs > half of friends (returning testers count here) | __ / __ ☐ yes ☐ no |
| 3. Nobody gets stuck in the first 2 minutes | sheet A/B: **zero** S-codes and zero R before 2:00, fresh testers only | ☐ yes ☐ no |
| **GO only if 1, 2 and 3 are all yes** | | ☐ **GO** ☐ **NO-GO** |
- **Provisional** if fewer than 3 friends played, or any `BUG` stopped a tester > 2 min. Write "provisional" and re-run that part.
- **The survey never flips the verdict.** Q1 "No" from most friends on a GO is written as a **watch** note for Phase S, not a no-go.

### §E. What happens next
- **GO:** Roadmap → review the Parking Lot, pick **at most 2** items (use survey Q5 as input), then Phase S. Post the sheet photos + verdict to Ghost.
- **NO-GO:** Roadmap → fix the loop (pacing, rewards, feel); nothing new gets added until it passes. Prism ranks the top 3 stuck codes + Q3/Q4 answers into a fix list and maps each to its owner spec:
| Stuck / survey | Likely owner spec (fix lives there) |
|---|---|
| S1 finding Roll · Q3 "Hub" | Crater Square #413 / T7 kit (`prism/t7-hub-art-kit`) · T3 guide #449 |
| S2 reveal · Q3 "Rolling" | Roll/Reveal #397 · L5 sound #447 (Legendary reveal plays by default, v1.2) |
| S3 bag / equip · Q3 "Bag" | Bag #398 · first 30 s #412 |
| S4 / S5 gate, start, party · Q3 "Hub" | T3 #449 · Gate dock #412 · Hard selector #437 |
| S6 controls · Q4 "Too hard" | Echo (combat feel) · L4 silhouettes #446 |
| S7 between waves · S8 boss · Q4 | Wave HUD #428 · boss telegraphs #439 · Echo pacing |
| S9 wipe · S10 results · Q3 "Results" | Results + Run Again #429 |
| S11 UI in the way | phone layout review #420 |
- Re-test only the failed rule after fixes (e.g. 3 fresh testers for rule 3), unless Kevin wants the full 15 min again.

## 4. Layout (the paper / phone pieces)
- Observer sheet: v1 layout (A first 2 min · B stuck codes · C 2+ runs tally · D signals · E quotes · Go box), now with the §D scoring column and a "provisional" tick (`OBSERVER_SHEET_v1.md` §10 v1.1).
- **Survey card (new):** one per tester, 5 questions with answer chips; print 6 per Letter page (`mockups/03`), phone version one card per screen with ≥ 44 px answer chips (`mockups/04`).

## 5. States
Kit: **Planned** (A1–A3 done) → **Set up** (A4–A8) → **In session** → **Surveyed** → **Scored** (GO / NO-GO / provisional) → **Posted**. Per tester: fresh / returning · in first 2 min · playing · 2+ runs · quit (time) · surveyed.

## 6. Numbers
30 min total (5 + 15 + 5 + 5). 3–6 friends (Roadmap), ≥ 2 phones. Stuck = 15 s; hint after 60 s; 1 hint max. Rule 2 = more than half of friends. Rule 3 = 0 S-codes and 0 R before 2:00. Survey ≤ 2 min per tester, 5 questions, fixed wording. Parking Lot picks ≤ 2.

## 7. Edge cases
- Kevin is both player and observer: his rule-1 answer is written first; the helper or recordings cover the friends.
- Tester has played before: plays, survey answered, counts for rule 2 only (not rule 3).
- Party play: allowed; each tester keeps their own row; note who started the second run (a friend inviting another friend in-game still counts as **unprompted**; Kevin or the helper asking doesn't).
- Server crash / rejoin: `BUG m:ss`; if a tester loses > 2 min, restart their clock and mark provisional.
- A tester asks "is this good?": answer "What do you think?"; write it as a quote.
- Someone sees a Robux / purchase prompt: `PAY m:ss`, tell Ghost (V1 ships no paid prompts in the loop).
- Survey answers that would add a new system go to the Ideas Backlog as NOT APPROVED, not into the fix list.

## 8. Mockups
SVG in `mockups/` (original layout, fake data; PNG renders stay on the box): `01` print observer sheet (v1) · `02` phone tally (v1) · **`03-survey-card-print-816x1056.svg`** (6 survey cards per Letter page, tick boxes) · **`04-survey-phone-390x844.svg`** (one tester's survey on a phone, 5 questions, answer chips ≥ 44 px tall, filled example).

## 9. Build split
- **Kevin:** plays, answers rule 1, runs the survey (or the helper does), signs the verdict.
- **Ghost:** A1, A3, A4 (fresh accounts or test-place reset, no live save wipes), schedules, posts the verdict, picks follow-ups with Kevin.
- **Prism:** A2 (#436 visual pass), fix list within one board cycle of the photos, survey Q5 into the Parking Lot review as NOT APPROVED ideas.
- **Echo / Havoc:** #434 smoke before; `BUG` lines after.
- Nothing is built in the game for this kit.

## 10. Pass criteria (for the kit itself)
1. A helper who never saw it can run §A–§D from this file in ≤ 30 min without asking Prism anything.
2. The verdict is reached from the sheets alone in ≤ 5 min and uses only the 3 Roadmap rules.
3. Every survey answer maps to a fix-list row or the Parking Lot.
4. Phone versions: every tap target ≥ 44 px; readable at 390×844 without zoom.

## 11. Open questions (answer by number)
1. ~~**@Ghost:**~~ **CONFIRMED v1.2 (Ghost DP31P https://app.notion.com/p/403c31ca388381feb52fdb6685c444a5): Go box = canvas pass line (Kevin wants to keep going, friends do 2+ runs, nobody stuck in the first 2 min).** The M13 canvas card was not readable here (403). Confirm its pass line = the Roadmap checkpoint's 3 "Go if" lines used in §D (or paste any extra line, e.g. a time target)? **Recommended: yes, Roadmap lines only.**
2. **@Ghost:** Fresh saves via new / never-played accounts (or a test-place reset you own), never by wiping a live save? **Recommended: new accounts.**
3. **@Kevin (taste):** Survey read aloud by the helper with answers ticked on paper (rec, more honest, no typing) or testers tap it themselves on the phone card? **Recommended: read aloud.**
(v1 questions on `OBSERVER_SHEET_v1.md` §11 still stand: Kevin Q1 helper live, Q2 print + phone, Ghost Q3 funnel cross-check.)

## Decision log
- 2026-10-24 (Ghost DP29, Kevin pre-approved for Prism to write it; Prism): **kit v1.1** on `prism/m13-observer-sheet` (#445): setup table, refreshed observer checklist, 5-question survey, go / no-go scored only on the Roadmap's 3 lines, fix-list owner map, 2 survey mockups. Not approved.
- 2026-10-24 (Ghost DP31P; Prism): **v1.2 note**: Q1 confirmed, the §D Go box is the canvas pass line word for word (keep going · 2+ runs · nobody stuck in first 2 min). No layout change. Still open: Ghost Q2, Kevin Q3.

## Roblox build notes
None: paper / phone kit, not game UI. Test the shipped build: no flag flips, no debug UI, no added playtest markers. An in-game survey or timestamp key would go to the Ideas Backlog as NOT APPROVED (and any later in-game version would follow Frames/ImageLabels + `UICorner` / `UIStroke`, ≥ 44 px, collapse, off the center).
