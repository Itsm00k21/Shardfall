# HUD Zone Map v1.2: DP61P answers folded in (Z8 = #487 rects, Z11 184 tall, Z13 results reserved) (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`HudLayout`, `HudShell`, `OnboardHud`, `CombatHud`, UiAudit). Base: `cursor/live-build-9721` @ **`908b1f3`** (#487 merged; #482, #471, #472, #480, #473, #475 merged before it, DP65). Rects measured by running live `HudLayout.equipPrompt`, `toastHost`, `promptButtons`, `onboard`, `characterZone` and `ActionSlots.placement` in lune at each size. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP63P https://app.notion.com/p/403c31ca3883814b8d94eeba82410845 (item 1). ACK: https://app.notion.com/p/403c31ca388381739823f77864ade274. Decisions folded: Prism's DP61P Done row https://app.notion.com/p/403c31ca3883810ea092e3811e3fc1ca (Q1-Q14, all accepted by Ghost under Kevin's pre-approval; Kevin can veto 3, 5, 12, 14). Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on: v1 + v1.1 addendum (`docs/design/ui-overhaul/HUD_ZONE_MAP.md` on `prism/ui-overhaul` @ `242ed14`, PR #479). This file is the delta: any v1/v1.1 table not repeated here still stands. Sibling: `PANEL_STYLE_v1.1.md` (prompt + dialog components). Specs folded: `prism/prompt-dialog` (`a6e7964`), `prism/chest-open-many` (`dcc17bd`). Mockups: `mockups/01`-`04` (PNG inside an SVG wrapper; this push path carries text only).

## 1. Goal
The zone map matches what shipped. The Equip/Keep prompt (Z8) uses the audited #487 rects, the Defeated/confirm dialog (Z11) is 184 tall at every size, the intro card steps aside for the prompt, and the run results card gets its own zone (Z13) so it stops sitting on the hero. Ghost codes one table, UiAudit checks one table.

## 2. Where it lives + what changed since v1.1
| # | DP61P decision (Ghost) | Zone effect in v1.2 | Live @ 908b1f3 |
|---|---|---|---|
| Q8 | Adopt #487 `equipPrompt` rects as Z8 | §4 Z8 rows replaced by the live rects | `HudLayout.equipPrompt` HudLayout.luau:242-264, `promptButtons` :270-276 (same as `10ab718`) |
| Q9 | P2-487-1: `coverWhen("prompt")` + `setCovered` from `paintNotices`, drop `introCard × equipPrompt` from the allow-list | §3: Z4 folds to its tab while Z8 is visible (the tutorial card too) | Ghost's DP63 UI PR; still allow-listed live |
| Q10 | `rarity`, `delta`, `icon` in the prompt payload | style only (PANEL_STYLE v1.1) | `ToastQueue.pushPrompt` text only |
| Q11 | One Z11 `DialogHud` for Defeated + the 4 salvage confirms; panel stays open behind a confirm | Z11 confirm is modal over Z12 (allowed pair, v1 §9) | Defeated = `CombatHud` Result card, centered (CombatHud.luau:472-476) |
| Q12 | Defeated look: skull, soft red title, drain bar (Kevin can veto) | style only | title `230,80,96` |
| Q13 | Goals/intro tab 44 tall at 390×844 | Z4 tab = 112×44 at every size | live `goalsTab` 112×36 (HudLayout.luau:835-838), Ghost's DP63 UI PR |
| Q14 | Cancel focused, red action on the right (Kevin can veto) | style only | four different confirms |
| Q1 | Chest results in Bag Z12 (Chests tab), retire `ChestGrid` | no HUD zone; Z12 only | `manyFrame` centered on the RollReel gui (RollReel.luau:419-446) |
| Q2-Q7 | Chest x10 details, Mythic stays gated | none (Z12 body) | — |
| DP63P | "Z11 184 tall" | §4 Z11 rows, bottom edge pinned | — |

## 3. Flow (changes to v1 §3 only)
| Moment | v1.2 rule |
|---|---|
| Loot that beats your gear | Z6 card + Z8 prompt. **Z4 (goals or tutorial card) folds to its 44 px tab in the same frame** and unfolds when no prompt is left (Q9). On phones Z4 already folded while Z6/Z8 are up (v1 §3); now the intro card does too |
| Defeated | Z11 (non-modal). Closes any panel, hides Z9, hides Z10 on phones and landscape phones, **Z8 waits** (it would overlap Z11 at 667/800/844) |
| Confirm (salvage, later any destructive action) | Z11 + backdrop, modal. The panel behind stays open (Q11). Toasts wait |
| Run cleared (dungeon victory) | **Z13 results card** (spec: `prism/run-results`). Z8 waits; Z4 shows its tab only; phones hide Z10; landscape phones also hold Z6 until Z13 collapses (6 s max) |
| Results collapsed | Z13 folds into a 44 px "Results" tab under the Z4 tab; tap reopens; next run start clears it |
Z11 and Z13 never show together (a run ends in one or the other).

## 4. Layout (safe-area px; replaces v1 §4 rows for Z6, Z8, Z11, Z4 tab; adds Z13)
| Zone | 1920×1080 | 390×844 | 667×375 | 800×400 | 844×390 |
|---|---|---|---|---|---|
| Z6 toast lane = live `toastHost` (3 × 36 + 2 × 8) | x 750-1170, y 80-204 | x 98-258, y 80-204 | x 111-531, y 80-204 | x 190-610, y 80-204 | x 212-632, y 80-204 |
| **Z8 prompt = #487 `equipPrompt`** (88 tall: label 36 + 44 + 8) | **x 750-1170, y 212-300** | **x 98-258, y 212-300** (160 wide, buttons 68×44) | **x 111-443** (8 px left of the bar at 451) | **x 190-576** (bar 584) | **x 212-620** (bar 628) |
| Z8 buttons (`promptButtons`) | Equip 88×44 at x 8, Keep at x 104, y 36 | 68×44 at x 8 / 84 | 88×44 | 88×44 | 88×44 |
| **Z11 dialog, 184 tall, bottom pinned** | **x 750-1170, y 772-956** | **x 80-374, y 596-780** | **x 381-651, y 176-360** (moved, Q1) | **x 456-784, y 196-380** (moved) | **x 480-828, y 190-374** (moved) |
| **Z13 results (new)** | x 1464-1904, y 432-956 (440 wide, auto height, max 524, bottom pinned) | x 80-374, y 624-836 (294×212) | x 471-651, y 56-359 (wing) | x 568-784, y 56-384 | x 601-828, y 56-374 |
| Z13 collapsed tab | x 1792-1904, y 188-232 (under the Z4 tab) | x 262-374, y 356-400 | x 539-651, y 180-224 | x 672-784, y 180-224 | x 716-828, y 180-224 |
| Z4 tab (Q13) | 112×44 at the live `goalsTab` spot (x 1792, y 136) | x 262-374, y 304-348 | x 539-651, y 128-172 | x 672-784, y 128-172 | x 716-828, y 128-172 |
Scale + offset (for `HudLayout.zone`): Z11 desktop `(0.5,-210, 1,-308)` / `(0,420, 0,184)`; Z11 portrait `(0,80, 1,-248)` / `(1,-96, 0,184)`; Z11 landscape: x from `characterZone` right + 8 to vx − 16, 184 tall, bottom edge as in the table (DP61P's bottoms). Z13 desktop `(1,-456, 1,-648)` / `(0,440, 0,524)` with `AutomaticSize.Y` + `UISizeConstraint` max 524 (pinned to the bottom edge); Z13 portrait `(0,80, 1,-220)` / `(1,-96, 0,212)`; Z13 landscape wing w = floor(0.27 × vx) (180 / 216 / 227, the `ResultsWings` widths), x = vx − 16 − w, y 56 to vy − 16. Z8 and Z6 stay computed by the live functions; don't re-derive them.
**Why Z11 moved on landscape (Q1):** DP61P put it at x 76-436. At 667 the live `characterZone` is x 293-373, y 150-243, so that dialog sat on the hero (80×67 px). Right of the hero, over the action bar (hidden while Z11 is up, v1 §3), it clears the hero at all three sizes and lines up with the Z13 wing.

## 5. States (adds to v1 §5)
| Zone | States |
|---|---|
| Z8 | hidden · 1 prompt · queued "1/2" (replace in place) · waiting (panel, Z11 or Z13 up) |
| Z4 | + **covered by Z8** (folds to its 44 px tab, "Step 2/6" or "Goals 2/5") |
| Z11 | hidden · Defeated (drain bar) · confirm (backdrop, Cancel focused) · confirm busy ("Salvaging…") |
| Z13 | hidden · open (drain bar) · collapsed tab · cleared on next run start |

## 6. Copy
Unchanged from v1 §6 and DP61P (prompt "Equip" / "Keep" / "1/2"; Defeated "Defeated" + server text + "Continue"; confirm "Salvage 12 pieces?" / "Cancel" / "Salvage 12"). New: Z13 tab "Results"; Z4 tab while covered "Step %d/%d".

## 7. Visual style
Z8, Z11 and Z13 use the PANEL_STYLE v1.1 components (`PANEL_STYLE_v1.1.md`): dialog shell `36,40,52 → 26,30,40`, `UICorner` 16 (14 phone), `UIStroke` 2 (Defeated danger, confirm and results gold), rarity stroke 1.5 on the prompt. Zone outlines in the mockups are review overlays only.

## 8. Motion
Unchanged (v1 §8). Added: Z4 fold for Z8 uses the same 0.2 s `Size` tween as the goals fold, started in the same frame Z8 shows. Z13 open 0.2 s (slide 16 px from the right edge / from the bottom on portrait + fade), collapse 0.15 s into its tab.

## 9. Roblox build notes + UiAudit
- Ghost adds Z8 (pointer to `equipPrompt`), Z11, Z13 and the Z13 tab to `HudLayout.zone()`; Prism edits no Ghost-owned file.
- `HudOverlap.spec`: drop `introCard × equipPrompt` (Q9); add rect checks for Z11 and Z13 at the 5 sizes above. **No new allowed pairs.** Visible-together failures to add: Z8 × Z11, Z8 × Z13, Z11 × Z13, Z13 × Z6 on landscape phones, Z11/Z13 × Z10 on phones.
- **Keep-out exemptions** (rect only, not a visible pair): Z11 crosses the #420 keep-out by 16 px at 1920 (y 772-788) and 20 px at 390 (y 596-616); both clear the live hero rect (`characterZone` y 432-702 / 337-548) by 70 / 48 px (Q3). On landscape Z11 crosses the keep-out's right side (x 381-467 at 667) and clears the hero rect; Z8 (#487, Havoc SHIP) crosses both at 667/800/844, as v1.1 Q6 accepted for the toast lane.
- DisplayOrder (v1 §9 ladder): Z13 = **results 50** (the slot already reserved); Z11 Defeated 92, confirm 105; Z8 90; Onboard drops to 32 (v1 Q-R4) so the covered-tab rule is belt and braces.
- `CombatHud`'s ScreenGui is `DisplayOrder 8` mounted with `MobileShell` (`DeviceSafeInsets`, CombatHud.luau:200-202). Z11/Z13 move to their own `CoreUISafeInsets` guis (v1 R2), which is why the live card's pixels differ from `HudLayout` rects on notched phones.

## 10. Mobile checks (script over the §4 table + live rects)
| Viewport | Z8 | Z11 | Z13 | Touch |
|---|---|---|---|---|
| 1920×1080 | clear of all; above the keep-out (302) | clear of hero, rail, bar; keep-out +16 px (Q3) | clear of keep-out, hero, bar, Z4 tab | buttons 88×44 / 48 |
| 390×844 | keep-out +4 px (live), RAIL_SAFE clear | Z10 hidden; RAIL_SAFE clear; keep-out +20 px | below the keep-out (616); Z10 hidden | 68×44 compact; 44 everywhere |
| 667×375 | live #487 rect, on the hero band (accepted, waits for Z11/Z13) | right of hero; Z10 hidden; Z8 waits | Z10, Z4, Z8 hidden; Z6 held | 44 |
| 800×400 / 844×390 | same | same | same | 44 |
Mockups: `01-zone-map-v12-1920x1080.svg`, `02-zone-map-v12-390x844-states.svg` (prompt + folded tab, Defeated, Z13 reserved), `03-zone-map-v12-landscape-667x375-800x400-844x390.svg`, `04-panel-style-prompt-dialog-sheet.svg`.

## 11. Open questions (answer by number)
1. **@Ghost:** move landscape Z11 right of the hero (x 381-651 at 667, 456-784 at 800, 480-828 at 844) instead of DP61P's x 76-436, which sits on the live `characterZone`? Prism recommends **yes**.
2. **@Ghost:** make the live `toastHost` (36 px cards, 124 tall) the official Z6 and drop v1.1's 40 px card target, so Z8 stays at y 212 everywhere? Prism recommends **yes**. Changing it would move the audited #487 prompt.
3. **@Kevin (taste):** accept the 184-tall Z11 dipping 16 px (desktop) / 20 px (phone) into the bottom of the center keep-out? It stays 70 / 48 px clear of the hero. Prism recommends **yes**. The alternative is a 160-tall dialog with 1-line bodies.
4. **@Ghost:** reserve Z13 for the results card (DisplayOrder 50, rules in §3) so `prism/run-results` builds into a known slot? Prism recommends **yes**.
5. **@Ghost / @Havoc:** add the §9 failure pairs and Z11/Z13 rect checks to `HudOverlap.spec` with no new allowed pairs? Prism recommends **yes**.

## Decision log
- Oct 24, 2026: v1 (DP41P), v1.1 (DP43P) on `prism/ui-overhaul`.
- Oct 24, 2026: v1.2 written for DP63P (Prism): DP61P Q1-Q14 folded as decided by Ghost (Kevin can veto 3, 5, 12, 14); Z8 = #487 rects, Z11 184 tall, Z13 reserved. v1.2 Q1-Q5 open. Still NOT APPROVED until copied into Vision & Design Rules.
