# First 30 Seconds: New Player Flow, Spec v1

Owner: Prism (design). Builders: Ghost (UI), Echo (server). Base: `cursor/live-build-9721` @ `9269e61`. Docs only, no code.
Asked for in: Agent Board row "Prism queue: next designs", item 1 (https://app.notion.com/p/403c31ca3883815ab11dd9936bb685e4). Master prompt: #15 comment 6379920900.
Scope: **spawn → intro → first roll → first fight**. Everything after wave 1 follows the locked V1 Core Loop §7 (waves 1–3, boss, results).

Sources (link, don't copy):
- Locked flow: V1 Core Loop §7 "First-Time Player Flow" and §1 "3 free tutorial rolls. The 3rd is rigged to a Rare." (Notion, locked).
- Roll reveal: PR #397 `docs/design/roll-reveal/SPEC_v1.2.md` (v1.3). Tier timings 0.55 / 0.70 / 0.90 / 1.30 / 2.20 s, Skip ≥ 88×44, 56 px ROLL-only collapse bar.
- Chrome: PR #392 `docs/ui/reference/STYLE.md`. Rarity colors: `Shared/Rarities.luau` `Rarities.COLOR`. Tiers and odds: `Shared/Config/Rarities.luau`.
- What's built today (read-only check of `cursor/live-build-9721`): `Shared/Onboarding.luau` (an older cold open: class pedestals → swing → dodge → door → Haven), `OnboardHud` (card at 16,96, 460×144, chevron folds it into a "Shardfall: <step>" pill; Goals panel folds to a tab; Skip pays the same starter kit), `FirstSession` (`rollFloor = "Rare"`), `OnboardingService` (`onboardStep`, `onboardDone`), `UiTheme` (`TOUCH = 44`, `CORNER = 10`, `MOTION.open = 0.26`). The solo wave arena is PR #382 (gated off).

## 1. Goal
In the first 30 seconds a new player cracks 3 free shards (the 3rd is a guaranteed Rare that goes straight into their hand), walks into the Shard Gate and lands a first kill, with the character visible the whole time.

## 2. Where it lives
- **World:** spawn plaza with Oracle Wren (NPC) and the Shard Gate pad within ~40 studs of spawn, both in the first camera shot.
- **HUD, "Focus mode":** for new players only (`onboardDone ~= true`) the HUD shows just four things:
  1. **Oracle card**, top-left (the existing `OnboardHud` card, new lines). The chevron collapses it to the existing 44 px **pill**. Tapping the pill expands it again.
  2. **Goal chip**, under the card (the existing Goals panel, one line). Tapping it collapses it to a 44×44 `◆ n/N` tab.
  3. **ROLL bar**, bottom-center. This is the #397 56 px ROLL-only collapse bar in a tutorial mode (FREE badge, pulse ring). The **mini reveal stage** docks next to it.
  4. **Gate dock**, in the same bottom-center slot as the ROLL bar, shown only on the Gate pad. Its chevron collapses it to a 44 px "Shard Gate ›" pill.
- The rail, Bag, currency pill and GearBar stay hidden until roll 3 resolves. Then they fade in (0.26 s) with a `newDot` on Bag.
- Also hidden in Focus mode until the hand-off (phone layout review F8): the live portrait + HP block, and the ActionBar's 2×4 skill grid with the attack/dodge/jump/heavy cluster. At every phone size they sit under the Oracle card (top-left) and the ROLL bar (bottom-center). They fade back in with the rail at the hand-off beat (~10 s).
- **Center keep-out:** no UI inside x 30–70% / y 28–73% of the viewport at any beat, on any size; **on portrait the top is 35%** (phone layout review D1, provisional until Kevin's phone playtest). World-space markers (BillboardGui, Beam) are allowed.
- **Bottom slot after the hand-off (review D2):** in the hub the live skill bar + attack/dodge/jump/heavy cluster also hides while the ROLL bar or the Gate dock is up, and comes back when the bar slides down or the player walks off the pad. In the arena the collapse bar hides.
- Leaving: **Skip intro** on the card ends Focus mode and pays the same kit (live behavior, kept). Returning players never see any of this.

## 3. Flow
Beat timeline. Times assume the player follows prompts. Idle fallbacks are in brackets.

| t (s) | Beat | What the player sees / does | Server |
|---|---|---|---|
| 0.0 | Spawn | Fade from black (0.4 s). Camera tweens 0.6 s to over-shoulder framing with Wren on the left and the Gate on the right. | `onboardStep = "spawn"` |
| 0.4 | Intro | Oracle card slides in from the left (0.26 s): **"Crack your first shard."** + "Tap ROLL below." Goal chip: "Crack 3 shards 0/3". | |
| 0.7 | Prompt | ROLL bar rises (0.26 s, Back Out). Badge "FREE ×3", label "Weapon shard", gold ring pulses. [no tap by 4.0 s: a pointer hand bounces on ROLL; by 9 s Wren repeats the line] | |
| ~2 | Roll 1 tap | ROLL → disabled. The card auto-collapses to the pill. Reveal plays in the **mini stage** at full length (#397 tier timing, 0.55–0.90 s typical) with the "Tap to skip" hint. | free roll, Weapon pool, auto-equip-if-better, `onboardStep = "roll2"` |
| ~3 | Result 1 | Stage shows tier chip + "1 in N" + name + "✓ Equipped". The icon tweens into the character's hand (0.35 s). Goal 1/3. Wren: "Nice! Two more free shards." (pill gets `newDot`) | |
| ~4–5 | Roll 2 | ROLL re-enabled ("FREE ×2", "Armor shard"). Tap → reveal → "✓ Equipped". Goal 2/3. | Armor pool, `roll3` |
| ~6–7 | Roll 3 | "FREE ×1", "Weapon shard". Tap → **Rare or better** (0.90 s for Rare): blue ring burst on the stage + a world ParticleEmitter burst on the character. | Weapon pool with `FirstSession.rollFloor` Rare, `onboardStep = "gate"` |
| ~8 | **Fast win** | "RARE · 1 in 15 · Frostbite Edge · ✓ Equipped". Goal chip ✓ "Crack 3 shards 3/3" (gold stroke 1.2 s). Wren: "A Rare! Now test it at the Shard Gate." | |
| ~10 | Hand-off | Stage fades (0.26 s), ROLL bar slides down. The rail and Bag fade in with a `newDot` on Bag. A world Beam runs from the character to the Gate, plus a BillboardGui "Shard Gate · N m". Goal: "Enter the Shard Gate". | |
| ~10–14 | Walk | The player walks about 30 studs (about 2 s at WalkSpeed 16). [no movement by 6 s after the hand-off: an edge arrow at the screen border points to the Gate] | |
| ~14 | On the pad | The Gate dock replaces the ROLL bar slot: "Shard Gate · Solo · starts in 3", Normal (selected), 🔒 Hard "Lv 5", **START**. The Beam and marker hide. | first-ever run: solo, 3 s countdown |
| ~15–17 | Start | Tap START or wait 3 s. Fade 0.4 s, then teleport (target ≤ 3 s with the arena preloaded). | `onboardStep = "wave1"` |
| ~19 | Arena | Toast "Wave 1/5" (1.2 s). Goal: "Clear wave 1 0/3". A hint chip above the attack button: "Tap ⚔ to attack" (mouse: "Click to attack"). | wave 1 spawns 3 shardlings near the player |
| ~20–24 | **First kill** | Damage numbers, then the kill. Toast "First kill!" The hint chip hides after 2 hits or 6 s. | first-kill event (analytics) |
| ~24–30 | Wave 1 clear | Goal 3/3 ✓, toast "Wave 1 cleared!", Wren (pill `newDot`): "Easy! Clear wave 3 to earn a roll." Next goal: "Clear wave 3". The spec ends here and the Core Loop §7 takes over. | `onboardStep = "done"` at results (Core Loop) |

Cancel / back:
- **Skip intro** (card) works at any beat before START. It ends Focus mode, pays the same kit, and unused free rolls stay as Roll Tokens (no loss).
- A tap during a reveal skips to the result (#397). It never cancels a roll.
- The Gate dock chevron collapses the dock. Walking off the pad closes it.
- Opening any menu hides the card and chip (live `OnboardHud.setCovered`).

## 4. Layout
Scale + offset anchors as noted. The keep-out box is checked at every size.

**Frames (phone layout review F7).** The keep-out boxes and the landscape tables use **full-screen px**: (0,0) is the screen's top-left, including the Roblox top bar (52 px on phones, 58 on desktop). There are two ScreenGuis:
- **FocusTop** (`ScreenInsets = DeviceSafeInsets`) holds the pieces that share the top-bar band on landscape phones: the Oracle card, the pill and the mini reveal stage. Their left edge is `GuiService.TopbarInset.Min.X + 8`, never a hard-coded x, so they don't sit on the Roblox menu/chat buttons or a landscape notch. Roblox's PlayerList is off in Focus mode, so the top-right of that band is free.
- **FocusHud** (`ScreenInsets = CoreUISafeInsets`) holds everything else. Subtract the top inset from a table's y to get its offset.

On portrait, "top" is the CoreUISafe top edge: about 99 px on a notched 390×844 (a 47 px notch plus the 52 px top bar), or 52 with no notch.

**Center keep-out (px)**
| Size | x | y |
|---|---|---|
| 390×844 | 117–273 | **296**–616 (35%, D1; was 236) |
| 667×375 | 200–467 | 105–274 |
| 800×400 | 240–560 | 112–292 |
| 1280×720 | 384–896 | 202–526 |

**Portrait phone 390×844** (mockups 01, 02)
| Piece | Anchor / Position | Size | Notes |
|---|---|---|---|
| Oracle card | (0,0) / (16, top+4) | (1,-32) × 112 → 358×112 | chevron 44×44 top-right; Skip intro 84×40 visual, 44 hit |
| Pill (collapsed card) | (0,0) / (16, top+4) | auto 176–240 × 44 | live `IntroPill` |
| Goal chip | (0,0) / (16, card bottom+8) | 216×44 | collapsed tab 44×44. If card bottom + 8 + 44 would pass the keep-out top, the chip starts as the tab and opens to 216×44 when the card folds to the pill at roll 1 (F9). Since D1 (top 296) a notched phone fits it (y 223–267), so the chip opens at once. It shows as its tab while a toast is in the lane |
| ROLL bar | (0.5,1) / (0.5,0, 1,-8-safeBottom) | 250×56 | ring +6 px; label 13 px above |
| Mini reveal stage | (0.5,1) / above the bar, gap 8 | (1,-32) × 120 | top edge 618 ≥ 616 ✓ |
| Gate dock | same slot as the ROLL bar | (1,-32) × 64 | START ≥ 92×48 |
| Hint chip | above the attack button, gap 12 | 150×44 | follows the CombatHud button |
| Toasts | the one toast lane (review §4a, D3): x 88–266, y 231–267 | 178×36 | #397 toast style. Max 1 on screen, the rest queue; loot/rarity before info |

**Landscape phone 667×375** (mockup 03)
| Piece | Position | Size | Notes |
|---|---|---|---|
| Oracle card | (TopbarInset.Min.X + 8, 6) in FocusTop, ≈ (100, 6) right of the Roblox chat button | 360×88 | single-line text + chevron + Skip intro 84×44; bottom 94 < 105 ✓ |
| Pill | (TopbarInset.Min.X + 8, 8) in FocusTop | auto × 44 | |
| Goal chip | (safeLeft + 12, 60) | **184**×44 (was 204, F10); a 44×44 tab while the card is expanded | The expanded card (x 100–460, y 6–94) overlapped a 204 px chip at y 60, so the chip stays a tab (x 12–56) until the card folds to the pill at roll 1. Bottom 104 < 105, and right edge ≤ 196 < 200 |
| ROLL bar | (0.5,1) / bottom 14 | 240×56 | x 213–453, clear of the thumbstick (≤ 164). The live combat cluster (attack x 379–443, dodge 327–371) would overlap it, so it's hidden in Focus mode (F8) |
| Mini reveal stage | (1,0) / (-16-safeRight, 8) in FocusTop | 280×84 | top-right. Bottom 92 < 105 ✓ (F12: it must stay in FocusTop; built in CoreUISafe it would drop to y 60–144 and cross the keep-out) |
| Gate dock | bottom-center, bottom 14 | 318×60 | label 12 px above it at y ≥ 280. The live cluster hides while it's up (D2) |
| Hint chip | above the attack button | 150×44 | |

**Landscape 800×400** (mockup 04)
| Piece | Position | Size |
|---|---|---|
| Oracle card | (100, 6) | 400×96 (bottom 102 < 112 ✓) |
| Pill / Goal chip | (TopbarInset.Min.X + 8, 8) / (safeLeft + 12, 60) | auto×44 / 204×44 (right edge ≤ 236 < 240). Tab 44×44 while the card is expanded, because the card (y 6–102) would cover the chip (F10) |
| ROLL bar | bottom-center, bottom 14 | 260×56 |
| Mini reveal stage | top-right (-16-safeRight, 8) | 300×92 |
| Gate dock | bottom-center | 340×60 |
| Hint chip / toasts | above the attack button / the toast lane in the top band x 524–784, y 8–44 (D3) | 150×44 / 260×36 |

**Desktop 1280×720 and up** (mockup 05). `UIScale = clamp(min(w/1280, h/720), 1, 1.5)` on the Focus root.
| Piece | Position | Size |
|---|---|---|
| Oracle card | (24, top+0) | 420×112 |
| Goal chip | (24, card bottom+8) | 240×44 |
| ROLL bar | bottom-center, bottom 24 | 320×64, label "ROLL [R]" |
| Mini reveal stage | right of the ROLL bar, gap 16, bottom-aligned | 420×120 |
| Gate dock | bottom-center | 380×64 |
Keys: **R** = roll, **C** = collapse/expand card, **E** or click = START on the pad.

**In the arena (beats ~19–30 s; F11).** The live portrait + HP block comes back top-left (CoreUISafe (16,16), 56 tall). Everything else docks around it, using Ghost's #416 Q5 dock rule.
- **Portrait 390×844:** only one 44 px row fits between the HP block (bottom ≈ 171) and the mid-left rail (top ≈ 242): y 179–223. The Oracle pill sits there and carries the goal (`"◆ Clear wave 1 0/3"`, ≤ 160 wide), so the separate goal chip is hidden in the arena. On a first run the #416 buff strip sits right of the pill (x 184). See the phone layout review, Q1.
- **Landscape phones:** the pill stays in the FocusTop band (TopbarInset.Min.X + 8, 8). Only the goal chip docks 8 px under the HP block, as its 44×44 tab, at 8 px right of the live rail (x 61 at 667, x 66 at 800). The #416 strip goes in the next row.
- **Desktop:** the card/pill and goal chip keep their §4 places. The live HP block is at the top-left, so they start 8 px under it (y ≈ 138).
- **Hint chip:** above the live attack button (CombatCluster). In portrait that spot is the 2×4 skill bar, so see review R10.

## 5. States
| Element | Idle | Press | Disabled | New | Locked |
|---|---|---|---|---|---|
| ROLL bar | fill button 108,78,196, gold stroke 2, ring pulse | fill 86,62,157 + UIScale 0.96 (0.08 s) | buttonDim 54,46,78, muted text, no ring (during a reveal, or FREE ×0) | FREE badge gold + pointer after 4 s idle | Pets/Skills shards not offered in the tutorial (no tab row in Focus mode) |
| Oracle card / pill | expanded card | chevron row 40,34,58 → 54,46,78 | — | slide-in + gold stroke flash 0.6 s on a new line; pill gets `newDot` 230,64,78 | — |
| Goal chip | ◆ text 240,236,248 | collapses to a 44×44 tab | — | done: ✓ ok 110,210,140, gold stroke 1.2 s, then swaps to the next goal (fade 0.15) | — |
| Mini reveal stage | rarity stroke 2 | tap = skip to result | — | "✓ Equipped" chip (ok) or "Saved to Bag" (muted) | — |
| Gate dock START | gold 255,196,64, ink text | UIScale 0.96 | "Starting…" dim while teleporting | pulse 1.0 → 1.04, 0.8 s | — |
| Gate dock Hard | — | tap = toast "Hard unlocks at Lv 5." | — | — | 🔒 + "Lv 5", buttonDim, muted |
| Rail / Bag | hidden | — | — | fade in after roll 3, `newDot` on Bag | hidden before roll 3 |
| Skip intro | dim 54,46,78, muted text | press 36,30,54 | hidden after START | — | — |
Also: **Loading:** ROLL shows `spinner_64` (#397). After 5 s: "Still rolling…". **Error:** a toast with the server text, ROLL re-enabled, the free roll is not used. **Empty / full:** not reachable here (a new bag is empty, and 3 items can't fill it).

## 6. Numbers
**Timings (s):** fade-in 0.4 · camera 0.6 · card/bar slide 0.26 (`UiTheme.MOTION.open`) · collapse 0.15 (`MOTION.panel`) · reveal per #397: Common 0.55, Uncommon 0.70, Rare 0.90, Epic 1.30, Legendary 2.20 · icon-to-hand 0.35 · ring pulse 1.0 loop · pointer after 4.0 idle, bounce ±6 px / 0.5 · Wren repeat at 9.0 · goal done flash 1.2 · first-run gate countdown 3 (normal 15) · teleport target ≤ 3 · wave toast 1.2 · hint auto-hide 6 or 2 hits.
**Targets:** first ROLL tap ≤ 5 s, 3 rolls done ≤ 12 s, on the pad ≤ 16 s, first kill ≤ 30 s.

**Rarity (Rarities.COLOR / Config):** Common 168,168,176 (1 in 2) · Uncommon 64,186,98 (1 in 4) · Rare 72,142,255 (1 in 15) · Epic 186,96,240 (1 in 100) · Legendary 255,196,64 (1 in 1,000).

**Chrome (PR #392):** bg 16,14,24 · panel 28,24,40 · row 40,34,58 · text 240,236,248 · muted 176,168,198 · button 108,78,196 · buttonDim 54,46,78 · gold 255,196,64 · ink 32,22,10 · ok 110,210,140 · danger 230,80,96 · newDot 230,64,78 · gate cyan 120,210,255 (world marker and Beam only). Corners: card/chip 10, buttons 8, stage 12, pill/toast = h/2. Stroke 1 (panels, gold at transparency 0.5), 2 (ROLL, stage).
**Fonts:** BuilderSansBold (names, buttons, Wren), BuilderSans (body), BuilderSansExtraBold (ROLL, START). Wren line 15, body 14, labels 13, badges 13, never under 13 on phones (toasts 13).

**Exact text**
- Wren: "Crack your first shard." (Core Loop, word for word) · "Tap ROLL below." (desktop: "Click ROLL or press R.") · "Nice! Two more free shards." · "Last free shard. Make it count!" · "A Rare! Now test it at the Shard Gate." (an Epic or Legendary third roll says "An Epic!" / "A Legendary!") · "Step in. Smash the shardlings!" · "Easy! Clear wave 3 to earn a roll."
- Goals: "Crack 3 shards n/3" · "Enter the Shard Gate" · "Clear wave 1 n/3" · "Clear wave 3".
- ROLL bar: "ROLL" · "FREE ×3/×2/×1" · "Weapon shard" / "Armor shard" · "Tap to skip".
- Stage: tier name in caps · "1 in N" · item name · "<Kind> · Power N" · "✓ Equipped" / "Saved to Bag".
- Gate dock: "Shard Gate · Solo · starts in N" · "Normal" · "Hard" · "Lv 5" · "START" · "Starting…" · "Hard unlocks at Lv 5."
- Combat: "Tap ⚔ to attack" / "Click to attack" · "Wave 1/5" · "First kill!" · "Wave 1 cleared!".
- Other: "Skip intro" · "Shardfall: <goal>" (pill) · "Could not roll. Try again."

## 7. Edge cases
- **Double-tap ROLL:** the first tap disables the bar until the result shows. Extra taps skip the reveal (#397) and never queue a second roll.
- **Server refuses or times out (5 s):** "Could not roll. Try again.", the free roll is not used, and FREE ×n is unchanged.
- **Rejoin mid-flow:** resume at the saved `onboardStep` (`roll2`, `roll3`, `gate`, `wave1`) with the right FREE count. Never re-grant a roll that already resolved.
- **Roll 1 is better than roll 3** (Epic+ on roll 1): roll 3 still meets the Rare floor but shows "Saved to Bag", and Wren uses the tier line. The win still lands.
- **Player wanders off:** the Gate Beam and edge arrow stay. The flow never blocks movement, and there's no timer.
- **Player taps Skip intro:** the kit and remaining free rolls are paid as tokens, the full HUD shows, and the Gate marker stays for one session as a hint.
- **Bag full:** can't happen with a new bag. If it ever does, the #397 full-bag reply is used.
- **A friend joins or someone else is on the pad:** the first run stays solo for the new player. The normal 15 s party countdown applies to anyone who is not on their first run.
- **Arena not live (Phase 3 gated off):** the flow ends on the pad with "Coming soon" and no dead end. See Q1 for the hub fallback.
- **Dies in wave 1:** keeps loot (locked rule). Wave 1 should be tuned so this is rare.
- **Gamepad:** ROLL = ButtonX, START = ButtonA. The hint shows the CombatHud key glyph.
- **Reduced motion:** no ring pulse, pointer bounce or UIScale punch. Timings unchanged.
- **First time / returning:** Focus mode only when `onboardDone ~= true`. It shows once ever because it rides on the existing save flags, so no new field is needed. That's separate from pending Salvage Q6/Q7 (help line once per session vs once ever).

## 8. Mockups
SVG in `mockups/`. Fake data. The dashed box is the center keep-out. Rendered and checked locally to PNG.
| File | Beat |
|---|---|
| `01-spawn-phone-390x844.svg` | 0–4 s: Wren card, goal chip, ROLL bar FREE ×3 with pointer |
| `02-rare-reveal-phone-390x844.svg` | ~8 s: roll 3 Rare in the mini stage, card collapsed to the pill, icon tween to the hand |
| `03-gate-landscape-667x375.svg` | ~14–17 s: on the Gate pad, Gate dock in the ROLL bar slot, Hard locked |
| `04-first-fight-800x400.svg` | ~20–24 s: wave 1, first-kill toast, hint chip by the attack button |
| `05-desktop-1280x720.svg` | ~3 s desktop: roll 1 Uncommon, stage right of the ROLL bar, keys |

## 9. Build split
**Ghost (UI).** These are requests only. Prism doesn't edit `OnboardHud`, `HudLayout` or `RollReveal`.
- Focus mode in `OnboardHud` / `HudLayout`: the per-size card, pill and goal chip positions from §4, plus the keep-out debug overlay (attribute `ShowKeepOut`, Studio only).
- New Wren lines and goals, driven by `onboardStep`.
- ROLL bar tutorial mode on the #397 collapse bar: FREE badge, ring, pointer and label.
- The mini reveal stage, using the #397 timings and the "Tap to skip" hint.
- The icon-to-hand tween, and the rail/Bag fade-in with `newDot`.
- The Gate dock UI (bottom slot, collapse, locked Hard), the hint chip by the CombatHud attack button, and the toasts.

**Echo (server).**
- Tutorial roll path: 3 free rolls gated on `onboardStep` (`roll1`, `roll2`, `roll3`). Pools are Weapon, Armor, Weapon, and roll 3 uses `FirstSession.CONFIG.rollFloor` "Rare".
- Server-side auto-equip-if-better.
- Step transitions and rejoin resume.
- First-ever Gate run: solo with a 3 s countdown (a Config value) and the arena preloaded.
- The `onboardStep` list **replaces** the old `Onboarding.STEPS` cold-open ids (pedestals → swing → dodge → door → Haven) for V1 (Q3 answered by Ghost, Oct 23, 2026). Skip intro and the same starter kit stay. Nothing is deleted from the repo; the old ids are just no longer the V1 path.
- Analytics (#383): time to the first roll, the 3rd roll, the pad, the first kill, and Skip use.

## 10. Pass criteria (playtest)
1. A fresh account on a 390×844 phone taps ROLL within 5 s of spawn with no help, and finishes 3 rolls by about 12 s. The 3rd is Rare or better.
2. Each new weapon shows up in the character's hand right after its reveal, with "✓ Equipped".
3. Following the prompts, the player lands a first kill by 30 s (median of 3 runs).
4. At 390×844, 667×375, 800×400 and desktop, no UI enters the center keep-out at any beat, and every tap target is at least 44 px tall.
5. The card folds to the pill, the goal chip folds to a tab, and the Gate dock folds to a pill. Skip intro pays the same kit plus the unused rolls.
6. Rejoining mid-flow resumes at the same beat. A returning player never sees Focus mode.
7. A fresh account never sees the old cold open (class pedestals, swing, dodge, door) before or after this flow (Q3 = replace).

## 11. Open questions (answer by number)
1. ~~@Kevin: First fight A (wave 1 via Shard Gate) or B (practice shardling)?~~ **RESOLVED by Kevin (Oct 23, 2026): A.** The first fight is wave 1 of the Normal dungeon through the Shard Gate. Needs the #382 arena gated on; until then the "Coming soon" edge case in §7 applies.
2. ~~@Kevin: OK to treat Core Loop §7 times as starting estimates tuned by this spec?~~ **RESOLVED by Kevin (Oct 23, 2026): yes.** Core Loop §7 times are starting estimates; this spec's ~0:12 rolls / ~0:20 wave 1 are the playtest tune. The locked Core Loop page is not edited here; changing it, or copying this into Vision & Design Rules, still needs Kevin.
3. ~~@Ghost: Replace the old `Onboarding.STEPS` cold open, or run this flow after it?~~ **ANSWERED by Ghost (Oct 23, 2026, Kevin pre-approved Ghost's calls): replace.** For V1 this flow's `onboardStep` list replaces the old cold open (pedestals → swing → dodge → door → Haven). Keep Skip and the same starter kit. Running both would blow the 30 s budget. Kevin can still change this later. Board row: https://app.notion.com/p/403c31ca388381ddaeb5edc911c66a55
4. ~~@Echo: First-ever Gate run solo, 3 s countdown, arena preloaded?~~ **Yes (Echo, Oct 23, 2026).** Solo first run; the 3 s countdown is a Config value; the arena is preloaded in the same place (no TeleportService), with 3 s or less as the target. Board row: https://app.notion.com/p/403c31ca388381dba1c1f358d0618f00
5. ~~@Echo: Free tutorial pools (W, A, W with Rare floor on roll 3) and server auto-equip-if-better?~~ **Yes (Echo).** Server-side pools, free, auto-equip-if-better decided on the server, tracked on the existing onboarding state. Any new save field goes to Ghost first.

Decided by Ghost under Kevin's pre-approval (Oct 23, 2026, board row https://app.notion.com/p/403c31ca388381c0bb72d75abab9bd4d):
- "Force the first roll to full length" = **yes**, so all 3 tutorial rolls play full length. Auto stays hidden until roll 3.
- The salvage tip ships, but it is not shown in the first 30 s, because the Bag stays hidden.
- The Core Loop vs repo rarity-ladder conflict is still open. This spec uses the repo's 5 V1 tiers per the master prompt.

## Decision log
- 2026-10-23 (Kevin): Q1 = **A**, first fight is wave 1 through the Shard Gate (depends on #382 arena being gated on). Q2 = **yes**, Core Loop §7 timings are starting estimates; this spec's timings are the tune. Locked Core Loop page unchanged.
- 2026-10-23 (Ghost, Kevin pre-approved): Q3 = **replace**. The `onboardStep` list replaces the old `Onboarding.STEPS` cold open for V1; Skip and the same starter kit stay; Kevin can change it later. Q4 and Q5 stay open with Echo.
- 2026-10-23 (Echo): Q4 = **yes** (solo, 3 s Config countdown, preloaded arena, 3 s or less). Q5 = **yes** (free server-side tutorial pools, server auto-equip-if-better on existing onboarding state; new save fields go to Ghost first). (Ghost): first roll full length = yes. All §11 questions are now closed.

- 2026-10-23 (Prism, phone layout review, docs/design/phone-layout-review/REVIEW_v1.md): F7: the coordinate frames are now explicit (full-screen px; FocusTop vs FocusHud; x from TopbarInset). F8: Focus mode also hides the live portrait/HP and the skill bar + combat cluster until the hand-off. F9: on notched portrait phones the goal chip starts as its tab. F10: on landscape the goal chip is a tab while the card is expanded (they overlapped), and the 667×375 chip is 184 wide. F11: arena docking around the live HP block (portrait has one row, so the pill carries the goal; landscape keeps the pill in the top band). F12: the mini stage stays in FocusTop. Layout fixes only; the flow and beats are unchanged.
- 2026-10-24 (Ghost, Kevin pre-approved, board row https://app.notion.com/p/403c31ca38838103a80ad21380d7f451; folded by Prism from the phone layout review rev 1.1, docs/design/phone-layout-review/REVIEW_v1.md §8/§10): D1: the portrait keep-out top is 35% (y 296), provisional until Kevin's phone playtest (§2, §4 table, goal chip). D2: after the hand-off, the hub combat cluster hides while the ROLL bar or Gate dock is up (§2). D3: toasts use the one toast lane, max 1 on screen, the rest queue, loot/rarity first (§4 portrait and 800 tables; the 667 lane slot is x 411–651, y 8–44).

## Later (not V1)
Voice lines for Wren, a set-bonus tip (Core Loop: only once the player owns 2 items of the same element), party-join during onboarding, and a Pets/Skills tutorial roll.

## Roblox build notes
Stock Roblox UI only. No blur or glassmorphism (BlurEffect blurs the 3D world, not the GUI), no soft shadows, no web fonts. `ParticleEmitter` only in world space; UI "particles" are tweened ImageLabels. The mockups are a guide, and these notes win.

| Element | Instances |
|---|---|
| Focus root | `ScreenGui` FocusHud (ResetOnSpawn false, ZIndexBehavior Sibling, `ScreenInsets = CoreUISafeInsets`) → `Frame` root + `UIScale` (desktop clamp). Plus `ScreenGui` FocusTop (`ScreenInsets = DeviceSafeInsets`) for the top-band pieces on landscape phones, x from `GuiService.TopbarInset` (listen to its changed signal) (F7) |
| Fade-in | full-screen `Frame` 0,0,0, BackgroundTransparency 0 → 1 over 0.4 s (TweenService Quad Out) |
| Camera | `Camera.CFrame` tween 0.6 s to the authored `SpawnShot` part, then `CameraType` back to Custom |
| Oracle card | `Frame` + `UICorner` 10 + `UIStroke` gold 1 (Transparency 0.5) + left accent `Frame` 4 px button color + portrait `ImageLabel` wren_64 in a circle `Frame` (UICorner 0.5 scale) + `TextLabel`s + `TextButton` chevron 44×44 + `TextButton` Skip intro |
| Pill | live `IntroPill` (`TextButton`, UICorner h/2, UIStroke button 1 @ 0.3, UIPadding 12) + `newDot` `Frame` 12×12 |
| Goal chip | `TextButton` 44 tall + `UICorner` 10 + `UIStroke` + `UIPadding` 12. The done flash is a UIStroke Color/Transparency tween |
| ROLL bar | the #397 collapse bar `TextButton` + `UICorner` 10 + `UIStroke` gold 2 + `UIGradient` (top white 0.92 → transparent) + `ImageLabel` shard_icon + badge `Frame` (UICorner h/2) |
| Ring pulse | `Frame` (transparent fill) + `UICorner` 14 + `UIStroke` gold 2, Transparency tween 0.55 ↔ 0.2, 1.0 s, reverses, repeat −1 |
| Pointer | `ImageLabel` hand_pointer_64, Position tween ±6 px Y, 0.5 s Sine InOut, repeat −1 |
| Mini reveal stage | `Frame` + `UICorner` 12 + `UIStroke` 2 (tier color) + `ImageLabel` glow_soft_256 (ImageColor3 = tier, transparency 0.6) + item tile `Frame` (UICorner 8, UIStroke 2) + `ImageLabel` icon + 4 `ImageLabel` shard_frag sprites tweened outward + text labels + "✓ Equipped" chip |
| Icon-to-hand | clone the item `ImageLabel`, tween Position to `Camera:WorldToViewportPoint(RightHand)` and Size → 0 over 0.35 s, then Destroy |
| Rare burst (world) | `ParticleEmitter` on an `Attachment` in HumanoidRootPart: Rate 0, `:Emit(24)`, Color = tier color, LightEmission 0.6, Lifetime 0.5–0.8, Speed 8–14 |
| Gate path | `Beam` (Attachment0 on HumanoidRootPart, Attachment1 on the Gate pad), Texture arrow_strip, TextureSpeed 1, Width 1.2, FaceCamera true |
| Gate marker | `BillboardGui` (AlwaysOnTop, MaxDistance 200, Size 0,140,0,28, StudsOffset 0,8,0) + `TextLabel` "Shard Gate · N m" |
| Edge arrow | `ImageLabel` arrow_64 clamped to the screen edge from `WorldToViewportPoint` of the Gate, rotated toward it |
| Gate dock | `Frame` + `UICorner` 12 + `UIStroke` gold 1 + `UIListLayout` Horizontal Padding 6: chevron, Normal, Hard (lock_icon), START (`UIScale` pulse) |
| Hint chip | `Frame` + `UICorner` 10 + `UIStroke` gold 1 + `TextLabel` + an `ImageLabel` tail, anchored to the CombatHud attack button's AbsolutePosition |
| Toasts | #397 toast (`Frame` 220×26, UICorner 13, `TextLabel`) |
| Animation | TweenService only. No per-frame Heartbeat except edge-arrow tracking |
| Touch | every interactive piece is a `TextButton`/`ImageButton` at least 44 tall, inside the safe insets |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| wren_64 | 64×64 | Oracle portrait |
| hand_pointer_64 | 64×64 | ROLL pointer |
| arrow_strip | 256×64 | Beam texture (tileable) |
| arrow_64 | 64×64 | edge arrow |
| glow_soft_256, shard_icon, shard_frag_a/b/c, lock_icon, spinner_64 | as in #397 | reused |
