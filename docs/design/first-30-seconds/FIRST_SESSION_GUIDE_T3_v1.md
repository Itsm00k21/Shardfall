# T3 First-Session Guide ("Wren's Trail"), Spec v1

Owner: Prism (design, docs only, no code, no config edits). Builders: Ghost (OnboardHud / Focus mode UI), Echo (onboarding server steps). Base: `cursor/live-build-9721`. Status: **proposal, not approved.**
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381089ec4e42d24ad049f (Oct 24, 2026, Kevin pre-approved): "T3 first-session guide spec (Oracle Wren, 3 free rolls, arrow to Gate, under 2 min)."
**Why this lives on `prism/first-30-seconds`:** the first 30 seconds are already specced here (PR #412, `SPEC_v1.md`, all questions closed): Oracle Wren card/pill, 3 free rolls with the 3rd at Rare or better, the Gate Beam + edge arrow, the first fight. T3 **extends** that flow to a complete guide that ends in under 2 minutes, so it's a second file on the same branch instead of a duplicate branch. `SPEC_v1.md` stays the source for beats 0–30 s; this file adds the guide frame (steps, progress, arrow rules, the end) and beats 30 s–2:00.

Sources (link, don't copy):
- Locked: V1 Core Loop §1 "3 free tutorial rolls. The 3rd is rigged to a Rare." and §7 First-Time Player Flow (Notion, locked; not edited here). Vision & Design Rules (no early exit; keep all earned loot; numbers in Config).
- Repo (read only, `cursor/live-build-9721`): `Shared/FirstSession.luau` (`CONFIG.rollFloor = "Rare"`, no paid skip, "Nothing here costs Robux"), `Shared/Onboarding.luau` (old cold-open `STEPS`, replaced for V1 by #412 Q3), `OnboardingService` (`onboardStep`, `onboardDone`), `OnboardHud` (card + `IntroPill`, Skip pays the same kit). **Oracle Wren is not in code yet.** She exists only in #412 (name, lines, `wren_64` portrait).
- Specs: #412 first 30 s (this branch) · #416 Shard Draft (first draft help line) · #428 Wave HUD v1.1 (Q2: first-run row is session-only, no save field) · #429 Results v1.1 (first run highlights ROLL once) · #420 rev 1.1 (portrait keep-out top 35% = y 296, provisional; one toast lane) · `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64).

## 0. Directions (pick one) and recommendation
Mockup: `mockups/t3-01-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Wren's Trail** | The #412 Wren pill carries a 5-step trail with 5 progress dots ("Oracle Wren · 2/5"); one goal chip shows only the current step. The arrow to the Gate is the world Beam + ground chevrons + a BillboardGui, with an edge arrow when the Gate is off-screen. The guide ends after wave 2 (~1:40) or at the 2:00 cap, whichever comes first. | Reuses every #412 piece; one thing to read at a time; nothing new in the center; easy to cap at 2:00. | Wren is a voice in a pill, not a character on screen, after the spawn shot. |
| B | Wren walks with you | Wren follows the player as an NPC and talks in BillboardGui bubbles. | Diegetic, charming. | Bubbles float into the center keep-out; NPC pathing and arena teleport for her; more code and more risk. |
| C | First-steps checklist | A left panel lists all 5 steps with ticks. | Shows the whole path. | Reads like homework, covers the rail column, and is one more panel to collapse. |

**Recommendation: A, "Wren's Trail".** It fits the rules (panels collapse, center stays clear, ≥ 44 px), keeps the #412 timings, and gives a clear end before 2 minutes. B's charm goes into Phase S as a Wren wave on the spawn shot (Later).

## 1. Goal
A brand-new player is guided by Oracle Wren through their first loop (3 free rolls → follow the arrow to the Gate → first kill → first buff pick → wave 2) and is **fully on their own in under 2 minutes**, with the character visible the whole time and no extra screens.

## 2. Where it lives
- **HUD (Ghost):** the #412 Focus mode pieces. The Wren pill gains a step label ("Oracle Wren · n/5") and 5 progress dots; the goal chip shows the current step only. Toasts use the one D3 lane. Prism doesn't edit `OnboardHud`, `HudLayout`, `RollReveal` or any Ghost-owned file; these are requests.
- **World (Ghost):** the #412 Beam from the character to the Gate pad (arrow texture), ground chevrons every ~6 studs, BillboardGui "Shard Gate · N m", and the 2D edge arrow when the pad is off-screen.
- **Server (Echo):** steps 1–3 use the existing #412 `onboardStep` values (`roll1`–`roll3`, `gate`, `wave1`). Steps 4–5 and the 2:00 cap are **session-only** (server memory, no new save field and no new saved step value), the same rule Ghost set for the first-run row in #428 Q2. `onboardDone` is set where #412 already sets it (at results), or when the guide ends, whichever comes first.
- **Config (Echo):** `GUIDE_MAX_SECONDS = 120`, `EDGE_ARROW_IDLE = 6`, `WREN_REPEAT = 9` in the existing onboarding Config (proposal; Prism doesn't write Config).
- **Not here:** Robux, paid skips, starter packs, or any purchase prompt during the guide (FirstSession: "There is no paid skip").

## 3. Flow
Times assume the player follows prompts; #412 idle fallbacks still apply.

| Step | t (s) | Trigger → what the player sees | Goal chip | Server |
|---|---|---|---|---|
| 1 Crack 3 shards | 0–12 | #412 beats 0–10: Wren "Crack your first shard.", ROLL bar FREE ×3, rolls 1–3 (3rd ≥ Rare), icon to hand. Pill: "Oracle Wren · 1/5". | "Crack 3 shards n/3" | `roll1`–`roll3` (#412) |
| 2 Follow the arrow | 12–18 | Hand-off: rail + Bag fade in ("Bag unlocked!" toast). Beam + chevrons + "Shard Gate · N m" appear. No movement for 6 s → edge arrow at the screen edge. Pill: "2/5 · Follow the arrow to the Gate". | "Enter the Shard Gate" | `gate` |
| 3 First kill | 18–30 | Gate dock (solo, 3 s) → arena → "Wave 1/5" → hint chip "Tap ⚔ to attack" → "First kill!". Pill: "3/5 · Smash the shardlings!". | "Clear wave 1 n/3" | `wave1` |
| 4 Pick a buff | 30–60 | Wave 1 cleared → first Shard Draft (#416) with its one-time line "Pick one. It lasts this run." Wren pill: "4/5 · Pick one buff." The pill stays collapsed during the pick (no extra text in the center). | "Pick a buff" | session-only |
| 5 Clear wave 2 | 60–~100 | Pill: "5/5 · Clear wave 2. You've got this." Wave chip (#428) shows WAVE 2/5. | "Clear wave 2" | session-only |
| End | ≤ 120 | Wave 2 cleared, **or** 2:00 since spawn, whichever is first: toast "You're ready, Seeker!" (D3 lane, info), all 5 dots gold for 1.2 s, the pill fades (0.26 s) and Focus mode ends. The wave chip takes the row (#428 Q2). Unfinished steps simply stop; nothing nags. | hidden (Goals tab keeps "Clear the boss") | `onboardDone` set (existing flag) |

After the end, the first-run results screen highlights ROLL once (#429 v1.1). That's results behavior, not part of the 2-minute guide.

Cancel / back: Skip intro (card, any time before START) ends the guide with the same kit (#412). The pill chevron collapses/expands. Opening any menu hides the pill (live `setCovered`). Leaving mid-guide: rejoin resumes steps 1–3 from `onboardStep`; steps 4–5 are not resumed (session-only), and the player just plays.

## 4. Layout
Full-screen px, the #412 frames (FocusTop for the top band on landscape phones, FocusHud = `CoreUISafeInsets`). Keep-out: 390×844 x 117–273, **y 296**–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Wren step pill (hub) | (16, top+4) = y 103–147, auto 220–260 × 44 | FocusTop (TopbarInset.Min.X + 8, 4), ≈ x 100–360, y 4–48 | same, ≈ x 100–380 | (24, top) 300×44 |
| Progress dots | 5 × 6 px, 9 px apart, top-right inside the pill (not tappable) | same | same | same |
| Goal chip | (16, 155), 216×44 | 44×44 tab at (12, 60) while the pill is in the band | tab at (12, 60) | (24, pill bottom + 8) 240×44 |
| Edge arrow (Gate off-screen) | 44×44 on the safe edge nearest the Gate, 16 px inset; y clamped to 120–560 on the left/right edges (never inside x 117–273 / y 296–616 and never over the ROLL bar or thumbstick zone) | right/left edge, y clamped 120–260 (above the combat cluster) | y clamped 120–280 | y clamped 150–600 |
| Gate distance label | next to the edge arrow, 112×28 | same | same | same |
| Toasts ("Bag unlocked!", "You're ready, Seeker!") | D3 lane x 88–266, y 231–267 | x 411–651, y 8–44 (top band) | x 524–784, y 8–44 | x 480–800, y 66–102 |
| Arena (steps 3–5) | the pill carries the goal in the one row y 179–223 (#412 F11); the #428 chip waits until the guide ends | pill in the FocusTop band; goal tab 8 px under the HP block, right of the rail | same | #412 desktop places |

Checks: every tappable piece is ≥ 44 px (pill, chip/tab, edge arrow); the dots and labels aren't tap targets. The world Beam, chevrons and BillboardGui are world-space, so they may pass the keep-out (as in #412). No guide UI is near the combat cluster, the skill bar or the thumbstick.

## 5. States
| Element | Idle | Press | New | Done | Hidden |
|---|---|---|---|---|---|
| Wren step pill | bg 16,14,24, button stroke 1, Wren portrait 32 px, "Oracle Wren · n/5" 10 px muted + step text 13 px gold-ink | `UIScale` 0.96 → expands the card (#412) | `newDot` 230,64,78 + gold stroke flash 0.6 s on each new step | all dots gold 1.2 s, then fade | menu open (`setCovered`), during a reveal, during the draft pick |
| Progress dot | dim 54,46,78 | — | turns gold 255,196,64 (0.15 s) | gold | with the pill |
| Goal chip | ◆ text | collapses to 44×44 tab | — | ✓ ok 110,210,140 + gold stroke 1.2 s | in the arena on portrait (pill carries it) |
| Edge arrow | 44 px circle, cyan 120,210,255 stroke 2, arrow glyph rotated toward the Gate | tap = camera nudge toward the Gate (0.4 s) | fades in after 6 s idle | hides on the pad | Gate on screen |
| Beam + chevrons | cyan, TextureSpeed 1 | — | — | hide on the pad | after step 2 |

## 6. Numbers
- Step targets (s): 1 ≤ 12 · 2 ≤ 18 · 3 ≤ 30 · 4 ≤ 60 · 5 ≈ 100. **Hard cap 120** (`GUIDE_MAX_SECONDS`).
- Free rolls: **3** (#412; pools Weapon, Armor, Weapon; 3rd uses `FirstSession.CONFIG.rollFloor = "Rare"`).
- Edge arrow: shows after **6 s** with no movement toward the Gate; 44×44; 16 px edge inset; rotation updates at most 10×/s.
- Wren repeat line after **9 s** idle on any step (one repeat per step, no nagging loop).
- Timings: step change flash 0.6 s, dot fill 0.15 s, end flash 1.2 s, pill fade 0.26 s (`UiTheme.MOTION.open`).
- Copy (Wren): "Crack your first shard." (Core Loop, word for word) · "Follow the arrow to the Gate." · "The Gate is this way." (edge arrow) · "Smash the shardlings!" · "Pick one buff." · "Clear wave 2. You've got this." · "You're ready, Seeker!". Goal chips: "Crack 3 shards n/3" · "Enter the Shard Gate" · "Clear wave 1 n/3" · "Pick a buff" · "Clear wave 2". Labels: "Oracle Wren · n/5" · "Shard Gate · N m" · "Bag unlocked!".
- Rarity colors in the reveal and draft cards: `Rarities.COLOR` (5 V1 tiers).

## 7. Edge cases
- **Slow player:** at 2:00 the guide ends wherever it is (no fail state, no nag). Unfinished goals stay in the Goals tab.
- **Fast player:** finishing wave 2 before 1:40 ends the guide early. Good.
- **Skip intro:** the guide ends at once; kit + unused free rolls as tokens (#412).
- **Arena gated off (#382 not live):** step 3 ends on the pad with "Coming soon" (#412 §7); the guide ends there with "You're ready, Seeker!" so there's no dead end.
- **Draft off (fun-test flag):** step 4 is skipped and the trail becomes 4 steps ("n/4").
- **Wipe in waves 1–2:** loot kept (locked rule); the guide ends with the results screen. No "failed" text.
- **Rejoin:** steps 1–3 resume from `onboardStep`; steps 4–5 don't (session-only, no save change).
- **Party/friends:** the first run stays solo (#412 Q4); friends joining later don't see the guide.
- **Reduced motion:** no dot pop or Beam texture scroll; timings unchanged.
- **Returning players:** never see the guide (`onboardDone` already true).

## 8. Mockups
SVG in `mockups/` (fake data, original art): `t3-01-directions.svg` (A/B/C) · `t3-02-trail-phone-390x844.svg` (step 2/5 at ~0:12: step pill with dots, goal chip, Beam + chevrons + Gate label, "Bag unlocked!" in the toast lane, 35% keep-out) · `t3-03-arrow-landscape-667x375.svg` (Gate off-screen: 44 px edge arrow + distance label at the right edge, pill in the top band, goal tab) · `t3-04-timeline.svg` (5 steps against the 2:00 cap + the end toast). PNG renders on the box only.

## 9. Build split
- **Ghost (UI, requests):** step pill label + 5 dots on the #412 pill; goal chip step texts; ground chevrons; edge arrow clamp rules per §4; end toast + Focus mode exit; hide the pill during the draft pick.
- **Echo (server):** session-only steps 4–5 and the 2:00 cap timer (server time from spawn); no new save field or saved step value; analytics: time to each step, guide end reason (`wave2` / `cap` / `skip`).
- **Prism:** Wren portrait (wren_64) and arrow textures in the Phase S pass; copy check.
- **Havoc:** 2:00 cap mid-draft, Skip at every step, rejoin at each step, arena off, draft off.

## 10. Pass criteria (playtest)
1. A fresh account on a 390×844 phone finishes the guide in **under 2:00** (median of 3), with the 3rd free roll Rare or better.
2. A tester who looks away finds the Gate using only the edge arrow within 10 s.
3. Only one guide instruction is on screen at a time, and nothing enters the center keep-out at any size.
4. Every guide tap target is ≥ 44 px; the pill and chip collapse.
5. No save field or saved step value is added (diff check on the save schema, still 26).
6. No Robux or purchase prompt appears before the guide ends.

## 11. Open questions (answer by number)
1. **@Ghost:** Direction A (Wren's Trail on the #412 pill) instead of a walking Wren NPC or a checklist? Recommended: A.
2. **@Ghost:** Steps 4–5 and the 2:00 cap are session-only (no new saved `onboardStep` values), matching your #428 Q2 call. OK?
3. **@Ghost:** End the guide after wave 2 (recommended, ~1:40) or right after the first buff pick (~1:00, shorter but the player hasn't used the buff yet)?
4. **@Ghost:** May a tap on the edge arrow nudge the camera toward the Gate (0.4 s), or should it only point? Recommended: nudge, since the arrow is a 44 px target anyway.
5. **@Kevin (taste, PROVISIONAL):** Wren's end line "You're ready, Seeker!" and calling the player "Seeker". Keep, or another word?

## Decision log
- 2026-10-24 (Prism): T3 v1 published on `prism/first-30-seconds` as an extension of #412, not a new branch. Recommends A. Open: Ghost 1–4, Kevin 5 (provisional). Not approved.

## Later (not V1)
Wren as a walking companion in the hub (direction B) in Phase S, voice lines, a set-bonus tip once the player owns 2 matching items (#412 Later). All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only: Frames, ImageLabels, TextLabels/TextButtons, `UICorner`, `UIStroke`, `UIGradient`, `UIListLayout`, `UIScale`, TweenService, world `Beam` / `BillboardGui` / `ParticleEmitter`. No blur, no soft shadows, no web fonts. The mockups are a guide, and these notes win.

| Element | Instances |
|---|---|
| Wren step pill | live `IntroPill` `TextButton` (`UICorner` h/2, `UIStroke` button 1) + portrait `ImageLabel` wren_64 in a circle `Frame` (`UICorner` 0.5 scale, `UIStroke` cyan 1.5) + 2 `TextLabel`s (step label 10 px, text 13 px BuilderSansBold) + dots `Frame` with `UIListLayout` horizontal (Padding 3) and 5 `Frame`s 6×6 (`UICorner` 0.5 scale) + `newDot` `Frame` 12×12 |
| Step flash | `UIStroke` Color/Transparency tween 0.6 s; dot BackgroundColor3 tween 0.15 s |
| Goal chip | #412 chip (`TextButton` 44 + `UICorner` 10 + `UIStroke` + `UIPadding` 12) |
| Beam | #412 `Beam` (arrow_strip texture, TextureSpeed 1, Width 1.2, FaceCamera) + ground chevrons: `Decal` or flat `ImageLabel` on `SurfaceGui` parts every ~6 studs |
| Gate label | `BillboardGui` (AlwaysOnTop, MaxDistance 200) + `TextLabel` "Shard Gate · N m" |
| Edge arrow | `ImageButton` 44×44 (`UICorner` 0.5 scale, `UIStroke` cyan 2) + arrow_64 `ImageLabel` with Rotation from `Camera:WorldToViewportPoint(gatePad)`; position clamped per §4; updated from a 0.1 s loop (not RenderStepped) |
| End toast | the D3 toast (`Frame` + `UICorner` h/2 + `UIStroke` gold 1.5 + `TextLabel`) |
| Rare burst (step 1) | #412 world `ParticleEmitter` `:Emit(24)` in the tier color |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| wren_64 | 64×64 | Wren portrait (shared with #412) |
| arrow_64, arrow_strip | 64×64 / 256×64 | edge arrow and Beam (shared with #412) |
| chevron_ground_128 | 128×128 | ground chevrons on the path |
