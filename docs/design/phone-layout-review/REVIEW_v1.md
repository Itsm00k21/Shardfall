# Phone Layout Review v1: all 6 Prism spec PRs

Owner: Prism (design, docs only). For: Ghost (UI owner), Echo (FYI). Date: Oct 23, 2026 (PT).
Asked for in: Ghost's Agent Board row, item 2 (https://app.notion.com/p/403c31ca3883815687a3f85a05f4323e). It covers the phone layout review at 390×844, 667×375 and 800×400, a desktop sanity check, and #416 Q5.
Reviewed (spec branch heads before this review's fixes): #397 `prism/roll-reveal-v1.2` @ c6cd62e · #398 `prism/salvage-shard-core` @ cd9747f · #412 `prism/first-30-seconds` @ a28fd2d · #413 `prism/town-hub` @ c5cc350 · #414 `prism/dungeon-look` @ 6d17ef6 · #416 `prism/buffs-pick3` @ 7262b09.
Live HUD baseline: `cursor/live-build-9721` @ `581c995`. I read `HudLayout.luau`, `CombatCluster.luau`, `ActionSlots.luau`, `InventoryLayout.luau` and `MobileShell.luau`, and recomputed every rect with the same math (§2). No code was changed.

## 0. Conventions used in this review
- **Frame:** every number is in **full-screen px**: (0,0) is the screen's top-left, including the Roblox top bar. That's the same frame as the center keep-out table in #412 §4. To build a piece in a `CoreUISafeInsets` ScreenGui, subtract the top inset.
- **Insets assumed** (verify on device with `GuiService:GetInsetArea`):

| Viewport | Device it stands for | Top reserved | Bottom | Sides | Safe GUI (CoreUISafe) |
|---|---|---|---|---|---|
| 390×844 | notched portrait phone | 0–99 (notch 47 + mobile top bar 52) | 810–844 home indicator | 0 | 390×711 |
| 667×375 | small landscape phone, no notch | 0–52 top bar | 0 | 0 | 667×323 |
| 800×400 | landscape phone | 0–52 top bar | 0 | 0 (a notched phone adds about 47 per side) | 800×348 |
| 1280×720 | desktop | 0–58 top bar | 0 | 0 | 1280×662 |

- **Center keep-out** (from #412 §4, x 30–70%, y 28–73%): 390×844 x 117–273, y 236–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526.
- **Touch:** every tappable thing must be at least 44 px tall (a visual can be smaller if its hit box is 44). Text minimum on phones is 13, with badges at 11 (R7).
- Fix ids: **F** = a fix this review applied directly on the spec's branch, each with a Decision-log line. **R** = a recommendation only (it changes direction or touches Ghost's code). **C** = a cross-spec conflict.

## 1. Summary verdicts

| PR | Spec | Verdict | Why |
|---|---|---|---|
| #397 | Roll / Reveal v1.3 | **Pass with fixes** | F1 (desktop Skip back to one size, 88×44), F2 (collapse bar had no geometry), F3 (the x10 summary scrolled at 667×375), F4 (10 px badges). The collapsed bar's bottom slot depends on Q2. |
| #398 | Bag Salvage + Shard Core v1.1 | **Pass with fixes** | F5 (header 64 → 44 typo), F6 (landscape confirm buttons could scroll out of view). R5 asks Ghost to check the landscape Bag column. |
| #412 | First 30 Seconds v1 | **Pass with fixes** | The most layout issues, all fixed in place (F7–F12). The coordinate frame was ambiguous. The live HUD sat under the card and the ROLL bar. On landscape the card covered the goal chip, and on notched portrait the goal chip crossed the keep-out. The Gate dock vs. combat cluster is Q2. |
| #413 | Town / Hub v1.1 | **Pass** | World-only spec; it adds no screen UI. Billboard text ≥ 18 px is fine. F13 is a doc line (Gate doc done in PR #418). |
| #414 | Dungeon Look v1.1 | **Pass with fixes** | F14: the loot chip had a vague, conflicting position ("top-right under the wave toast"). It now has exact sizes per viewport. |
| #416 | Buffs Pick-3 v1.1 | **Pass with fixes** | F15–F19. The (12, 52) strip overlapped the live portrait. The held pill overlapped the currency pills. The landscape draft row and Later covered the jump/attack cluster. The portrait tray crossed the keep-out. Q5 is now resolved with live numbers. Q1 and Q3 are open for the portrait top band and toasts. |

No PR fails. Every 44 px target, 88×44 Skip and 56 px collapse bar now agrees across the specs (§6).

## 2. Live HUD baseline (Ghost's code, computed, full-screen px)

| Live element | 390×844 | 667×375 | 800×400 | 1280×720 |
|---|---|---|---|---|
| Portrait (face) | x 16–72, y 115–171 | x 16–72, y 68–124 | x 16–72, y 68–124 | x 16–72, y 74–130 |
| HP bar | x 80–258, y 115–171 | x 80–300, y 68–124 ⚠ crosses keep-out | x 80–300, y 68–124 ⚠ | x 80–300, y 74–130 |
| Currency pills | column x 266–374, y 115–227 | strip x 311–651, y 100–132 ⚠ | strip x 444–784, y 100–132 ⚠ | strip x 924–1264, y 110–146 |
| Toast host (3 cards) | x 98–258, y 179–303 ⚠ | x 123–543, y 132–256 ⚠ | x 190–610, y 132–256 ⚠ | x 430–850, y 138–262 ⚠ |
| Mid-left rail (6 buttons) | x 16–80, y 242–666 (64 px) | x 16–53, y 132–354 (**37 px** ⚠ R6) | x 16–58, y 132–384 (**42 px** ⚠ R6) | x 16–80, y 177–601 |
| 2×4 skill bar / desktop action row | x 158–374, y 566–706 ⚠ | x 451–651, y 227–359 ⚠ | x 584–784, y 252–384 | row x 356–924, y 604–704 |
| Attack | x 310–374, y 730–794 | x 379–443, y 295–359 | x 504–576, y 312–384 | x 1192–1264, y 632–704 |
| Dodge / Jump | 258–302 / 206–250, y 750–794 | 327–371 y 315–359 / 399–443 y 243–287 ⚠ | 448–496 y 336–384 / 528–576 y 256–304 ⚠ | 1136–1184 / 1216–1264 |
| Thumbstick zone (Roblox, approximate) | x 16–198, y 640–794 | x 16–164, y 211–359 | x 16–200, y 236–384 | — (WASD) |

⚠ means the live element already crosses the #412 keep-out or misses the 44 px floor. That's Ghost's code, so I don't fix it here. See R6 and R9.

## 3. Per-viewport tables

Status: ✓ OK · **F#** fixed by this review · **C#/Q#** conflict or open question.

### 3.1 Portrait 390×844

| Screen | Element (spec) | Position / size | Status |
|---|---|---|---|
| Roll page open | Tabs, ROLL, toggles (#397) | tabs (1,-24)×44; ROLL 0.55w×72 ≈ 214×72; toggles ≥ 88×48 | ✓ |
| | x10 Skip (#397) | bottom-right of the page, 88×44 | ✓ (F1 makes it one size) |
| | x10 summary 5×2 (#397) | panel 366 wide, tile = min(96, (366−60)/5) = 61 | ✓ badges legible after F4 (11 px) |
| | Milestone toast (#397) | top-center 220×26 | ✓ not interactive |
| Roll page collapsed | Collapse bar (#397) | x 70–320, y 746–802 (250×56) | **F2** adds the geometry. **C1**: it overlaps the live attack/dodge/jump (y 730–794) outside Focus mode → Q2 |
| Bag (full-screen modal) | Salvage sheet (#398) | bottom sheet 366 wide, top ≥ y 422; rows 52; buttons ≈ 169×44; pill 44 | ✓ |
| | Core card (#398) | header 44, Feed 44, perk rows 30 (not tappable) | ✓ (F5 fixes the "64 px header" typo) |
| Focus mode, 0–10 s | Oracle card (#412) | x 16–374, y 103–215 | ✓ only because the live portrait/HP is hidden (**F8**) |
| | Goal chip (#412) | 216×44 at y 223 would end at 267, inside the keep-out (x 117–232, y 236–267) | **F9**: it starts as the 44×44 tab (x 16–60) and opens when the card folds |
| | ROLL bar (#412 = #397 bar) | x 70–320, y 746–802 | ✓ with the cluster hidden (**F8**) |
| | Mini reveal stage (#412) | x 16–374, y 618–738 | ✓ top 618 ≥ 616 (2 px). R8: it sits over the thumbstick zone |
| | Toasts (#412) | top+4 220×26 = y 103–129 | **C2**: lands on the Oracle card/pill → Q3 |
| Gate pad (hub) | Gate dock (#412/#413) | x 16–374, y 738–802; START ≥ 92×48 | **C1**: overlaps attack/dodge/jump → Q2 |
| Arena, wave 1 | Oracle pill + goal (#412) | one row, y 179–223, pill ≤ 160 wide, carries the goal text | **F11**. Only one row fits above the rail → Q1 |
| | Hint chip (#412) | "above the attack button" = on the 2×4 skill bar (y 566–706) | R10 |
| | Loot chip (#414) | through the toast host | **F14** → Q3 |
| Arena, draft | Header / row / Later (#416) | header y 250; row 3×116×196 at y 284–480; Later 120×44 at y 490–534 | **F19**: clear of the skill bar (top 566). The row is in the center only during the pick moment ✓ |
| | Held pill (#416) | x 274–374, y 235–279 (100×44 "Buff ›") | **F18**: it was on the currency pill column |
| | Tray (#416) | one row of 3 × 116×48 under the pill | **F15** (the stacked version ended at y 256). On a notched phone it still crosses the keep-out → Q1 |
| | Buff strip (#416, Q5) | (16, 179), ≤ 74 wide; list 93 wide | **F16**: (12, 52) sat on the live portrait |
| | Resonance toast (#416) | through the toast host | **F17** → Q3 |

### 3.2 Landscape 667×375

| Screen | Element (spec) | Position / size | Status |
|---|---|---|---|
| Roll page open | Crystal left (0.33), right column 0.45w (#397) | ROLL ≥ 72 tall, toggles ≥ 88×48 | ✓ |
| | x10 summary (#397) | 5×2 with tile 96 needed about 340 px of height, but the safe height is 323 | **F3**: tile = min(96, (panelW−60)/5, (safeH−150)/2) = 86 |
| Roll page collapsed | Collapse bar (#397) | x 213–453, y 305–361 (240×56) | **F2**. **C1**: overlaps attack (379–443) and dodge (327–371) → Q2 |
| Bag | Salvage side sheet (#398) | W 300, H = Bag − 16, the body scrolls | **F6**: pinned Cancel / Salvage N footer. R5: column check |
| Focus mode | Oracle card (#412) | FocusTop (TopbarInset.Min.X + 8, 6), 360×88, y 6–94 | **F7** sets the frame. Built in CoreUISafe it would drop to y 58–146 and cross the keep-out |
| | Goal chip (#412) | tab x 12–56, y 60–104, then 184×44 after roll 1 | **F10**: the expanded card (x 100–460, y 6–94) covered a 204 px chip |
| | ROLL bar (#412) | x 213–453, y 305–361 | ✓ thumbstick ≤ 164. The live cluster is hidden in Focus (**F8**) |
| | Mini stage (#412) | FocusTop x 371–651, y 8–92 | **F12** ✓ (bottom 92 < 105) |
| Gate pad | Gate dock (#412/#413) | x 174–492, y 301–361 (318×60) | **C1** → Q2 |
| Arena | Goal tab (#412) | x 61–105, y 132–176 (right of the live rail) | **F11** ✓ |
| | Buff strip (#416) | x 61, y 132 (184 on a first run), list 131 wide | **F16** ✓ |
| | Held pill (#416) | x 493–651, y 136–180 | **F18** ✓ (x > 467) |
| | Loot chip (#414) / Resonance toast (#416) | notice column x 475–651: chip 176×36 at y 184–220 | **F14 / F17** ✓. One notice at a time (the skill bar's top is at 227) |
| | Tray (#416) | one row 547×52 at y 52–104 | ✓ covers the HP/pills only while open. It folds after a pick, an outside tap or 4 s |
| Arena, draft | Header / row / Later (#416) | header y 56; row 3×136×132 at y 86–218; Later x 531–651, y 56–100 | **F19**: the old row (y 92 + 190, CoreUISafe → down to y 334) covered jump/attack, and Later at y 316 sat on the dodge button |

### 3.3 Landscape 800×400

| Screen | Element (spec) | Position / size | Status |
|---|---|---|---|
| Roll page | as 667, tile = min(96, …, (348−150)/2 = 99) = 96 | 5×2 fits | ✓ |
| Roll page collapsed | Collapse bar (#397) | x 270–530, y 330–386 (260×56) | **F2**. **C1**: overlaps attack (504–576) and dodge (448–496) → Q2 |
| Bag | Salvage side sheet (#398) | W 320, pinned footer | **F6** ✓ |
| Focus mode | Oracle card (#412) | FocusTop (TopbarInset.Min.X + 8, 6), 400×96, y 6–102 | ✓ (F7). On a notched phone x comes from TopbarInset, so it clears the notch |
| | Goal chip (#412) | tab, then 204×44 at x 12–216, y 60–104 | **F10** (the card covered it) |
| | ROLL bar / mini stage (#412) | ROLL x 270–530, y 330–386; stage FocusTop x 484–784, y 8–100 | ✓ (F8, F12) |
| Gate pad | Gate dock (#412/#413) | x 230–570, y 326–386 | **C1** → Q2 |
| Arena | Goal tab / buff strip | x 66, y 132 / y 132 (184 on a first run); list 166 wide | **F11 / F16** ✓ |
| | Held pill / notice column | x 626–784, y 136–180 / x 568–784, chip 216×36 | **F18 / F14 / F17** ✓ |
| Arena, draft | Header / row / Later (#416) | header y 56; row 3×150×160 at y 86–246; Later x 664–784, y 56–100 | **F19**: clear of the jump button (256) and the skill bar (252) |

### 3.4 Desktop 1280×720 (sanity check)

| Element | Position / size | Status |
|---|---|---|
| #397 page | caps 1180×680, UIScale; Skip now 88×44 (F1) | ✓ |
| #397 collapse bar | x 480–800, y 632–696 (320×64) | **C1**: on the live 8-slot action row (y 604–704) → Q2. One option is to sit above the row at y 532–596, which is clear of the keep-out (526) |
| #398 sheet | bottom-right of the Bag, W 340 | ✓ |
| #412 card / goal / ROLL / stage | card (24, 62) 420×112; goal 240×44; ROLL x 480–800, y 632–696; stage x 816–1236 | Card and goal clear the HP block only in Focus mode (F8). ROLL and stage sit on the action row unless it's hidden (F8 hides it until the hand-off) |
| #412 Gate dock | 380×64 bottom-center | **C1** → Q2 (above the row at y 532–596 works on desktop) |
| #416 draft | header y 208; row 3×200×280 at y 254–534; Later y 552–596 | ✓ (action row at 604) |
| #416 held pill / strip / resonance | pill x 1106–1264, y 150–194; strip x 88, y 138; resonance 320×52 under the pill | ✓ (F16, F18) |
| #414 loot chip | 220×30 top-right under the currency pills | ✓ |

## 4. Shared HUD zone map (who owns which region, and when)

Mockups: `mockups/zones-390x844.svg`, `mockups/zones-667x375.svg`, `mockups/zones-800x400.svg`, plus `mockups/zones-1280x720.svg`. Each shows the hub (Focus mode, ROLL, Gate pad) on the left and the arena (wave, held draft) on the right, with the computed live HUD dashed.

| Region | 390×844 | 667×375 | 800×400 | Owner and when |
|---|---|---|---|---|
| Top-bar band | y 0–99 | y 0–52 | y 0–52 | Roblox core buttons always. On landscape, **#412 FocusTop** (card, pill, mini stage) uses the free part from TopbarInset.Min.X + 8, Focus mode only. The **#416 tray** opens just under it (y 52–104) while open |
| Top-left stack | x 16–258, y 115–223 | x 16–300, y 68–228 | x 16–300, y 68–228 | Live portrait + HP **always**. Under it, in order: a future #417 wave counter → the #412 Oracle pill/goal (first run) → the #416 buff strip (from the first draft on). On landscape and desktop it shifts 8 px right of the rail where the rail crosses the band (R4) |
| Top-right column | x 266–374, y 115–279 | x 475–651, y 100–220 | x 568–784, y 100–220 | Live currency pills **always** → the **#416 held pill** (after Later or a timeout, during the next wave) → one notice at a time: a **#414 loot chip** (wave clear, 2 s) or the **#416 Resonance toast** (pick +0.3 s, 2 s). On portrait, notices go through the toast host (Q3) |
| Top-center toasts | x 98–258, y 179–303 | x 123–543, y 132–256 | x 190–610, y 132–256 | Live toast host (Ghost). Proposed lane for the #397 milestone toast, the #412 wave/first-kill toasts, the #414 loot chip (portrait) and the #416 Resonance toast (portrait) → Q3 |
| Center keep-out | x 117–273, y 236–616 | x 200–467, y 105–274 | x 240–560, y 112–292 | Nobody, except the **#416 draft row during the pick moment** (scrim on, at most 8 s) and the open **#397 Roll page / #398 Bag** (opened menus) |
| Mid-left rail | x 16–80, y 242–666 | x 16–53, y 132–354 | x 16–58, y 132–384 | Live rail, hidden in #412 Focus mode until roll 3 / the hand-off |
| Bottom-center slot | x 16–374, y 738–802 | x 174–492, y 301–361 | x 230–570, y 326–386 | **Hub:** the #397 collapse bar or the #412 ROLL bar (the same 56 px bar), **replaced** by the #412/#413 Gate dock while on the pad. **Arena:** the combat cluster. The proposal hides the collapse bar there (R2/Q2) |
| Bottom-right cluster | x 158–374, y 566–794 | x 327–651, y 227–359 | x 448–784, y 252–384 | Live skill bar + attack/dodge/jump **always**, except in #412 Focus mode before the hand-off (F8) and possibly in the hub while ROLL or the Gate dock is up (Q2) |
| Bottom-left thumbstick | x 16–198, y 640–794 | x 16–164, y 211–359 | x 16–200, y 236–384 | Roblox thumbstick always. Spec UI must not take taps there. The #412 portrait mini stage overlaps it (R8) |

## 5. Cross-spec conflicts found

| # | Region | Who collides | Moment | Resolution |
|---|---|---|---|---|
| C1 | Bottom-center | #397 collapse bar, #412 ROLL bar, #412/#413 Gate dock vs. the live attack/dodge/jump and skill bar | Hub, any time ROLL is collapsed or the player is on the pad (outside Focus mode) | Q2 (recommended: in the hub the cluster hides while one of these bars is up; in the arena the collapse bar hides) |
| C2 | Top-center / top-left | #412 toasts (top+4) vs. the #412 card/pill; the #414 loot chip and #416 Resonance toast vs. the live currency pills | Focus beats; wave clear (loot chip at 0–2 s and Resonance at about 1.2–3.3 s overlap in time) | F14 / F17 give a landscape notice column that shows one at a time. Portrait goes through the toast host → Q3 |
| C3 | Top-left | #416 strip (12, 52) vs. the live portrait (16–72); the #412 goal chip vs. the live HP; strip vs. goal on a first run | Arena | F11 / F16 dock order (R4) |
| C4 | Top-right | #416 held pill (y 52) vs. the live currency pills | Arena, held draft | F18 |
| C5 | Bottom-right | #416 landscape draft row + Later vs. jump/attack/dodge | Pick moment | F19 |
| C6 | Top-left, landscape | #412 Oracle card vs. the #412 goal chip | Focus, 0–2 s | F10 |

## 6. Shared values check

| Value | #397 | #398 | #412 | #413 | #414 | #416 | Result |
|---|---|---|---|---|---|---|---|
| Skip ≥ 88×44 | 88×44 (desktop was 72×36) | — | refers to #397 | — | — | — | ✓ after F1 |
| Collapse / ROLL bar 56 px | 56 (sizes added) | — | 56 (64 desktop) | "existing 56 px" | — | — | ✓ after F2 |
| Touch ≥ 44 | ✓ | ✓ (desktop 36 visual, 44 hit) | ✓ (Skip intro 40 visual, 44 hit) | ✓ | ✓ | ✓ | ✓ |
| Collapse, not close | 56 px bar | 44 px pill / 44 px header (F5) | pill / tab / dock pill | n/a | n/a | pill + strip | ✓ |
| Toast style | 220×26 | — | 220×26 | — | 36 tall chip on phones | 52 tall toast | OK. Different sizes for different jobs; one lane (Q3) |
| Rarity colors (5 tiers) | Rarities.rgb | same | same | Epic/Legendary beams | same | same | ✓ identical RGB |
| Hard = Lv 5, no Nightmare | — | — | ✓ | ✓ | ✓ | ✓ (odds table) | ✓ |
| Min text on phones | 14 (badges 11 after F4) | 13 help | 13 | billboard ≥ 18 | 13 | card sub line 11 | R7 |

## 7. Fix list

### Applied on the spec branches (each with a Decision-log line)
1. **F1**, #397 §4/§9/build notes: x10 Skip is ≥ 88×44 on **every** size. Desktop was 72×36, which contradicted "one size".
2. **F2**, #397 §4: added the collapse-bar row (portrait 250×56, 667 240×56, 800 260×56, desktop 320×64, bottom-center), matching the #412 ROLL bar.
3. **F3**, #397 §4: x10 tile = min(96, (panelW−60)/5, (safeH−150)/2), so the 5×2 summary doesn't scroll at 667×375.
4. **F4**, #397 §6: badges h 18 / text 11 (were 16 / 10).
5. **F5**, #398 Scope: the core card collapses to its **44 px** header (the text said 64).
6. **F6**, #398 §4: landscape sheets pin the Cancel / Salvage N footer, and only the body scrolls.
7. **F7**, #412 §4 + build notes: explicit frames (full-screen px; a FocusTop DeviceSafe gui for the landscape top band, x from `GuiService.TopbarInset`; FocusHud CoreUISafe for the rest; portrait top ≈ 99 when notched).
8. **F8**, #412 §2: Focus mode also hides the live portrait/HP and the skill bar + attack/dodge/jump/heavy until the hand-off.
9. **F9**, #412 §4 portrait: the goal chip starts as its 44×44 tab when card + chip would cross the keep-out top.
10. **F10**, #412 §4 landscape: the goal chip is a tab while the card is expanded, and the 667 chip is 184 wide.
11. **F11**, #412 §4: arena docking around the live HP block (portrait has one row and the pill carries the goal; landscape keeps the pill in the top band and the goal tab right of the rail).
12. **F12**, #412 §4: the landscape mini stage must live in FocusTop.
13. **F13**, #413 Sources + §11: the `DUNGEON_GATE_PLAZA.md` update is **done in PR #418** (https://github.com/Itsm00k21/Shardfall/pull/418).
14. **F14**, #414 §6: loot chip sizes and places per viewport (landscape notice column 176/216×36; portrait through the toast host; desktop 220×30 under the pills).
15. **F15**, #416 §4: the portrait tray is one row of 3 × 116×48.
16. **F16**, #416 §4 (Q5): the strip docks 8 px under the live HP block, right of the rail on landscape and desktop. The list width is capped at keep-out left − x − 8, and it folds after 4 s.
17. **F17**, #416 §4: the Resonance toast uses the landscape notice column (176/216 wide) and goes through the toast host on portrait.
18. **F18**, #416 §4: the held pill docks under the currency pills (portrait 100×44 "Buff ›").
19. **F19**, #416 §4: the table is in full-screen px. The landscape draft row and Later are clear of the jump/attack/skill bar (667 row 136×132, 800 150×160, Later in the header band). The portrait row and Later are clear of the skill bar.

The stray wrapper lines left by an earlier push were also removed from #397, #398, #412, #413 and #414. That's housekeeping, not a design fix.

### Recommended only (no spec text changed)
1. **R1**, all specs, portrait: the band above the keep-out is only 137 px on a notched phone (99–236), and the live HP + pills already fill it. Recommendation: on portrait, measure the keep-out top from 35% (y 296) instead of 28%. The character sits around y 390–520, so it stays covered. → Q1.
2. **R2**, #397 / #412 / #413: a bottom-slot contract. In the hub, the 56 px bar (ROLL / collapse) and the Gate dock share the bottom-center, and the dock replaces the bar on the pad. In the arena the combat cluster owns the bottom and the collapse bar hides. On desktop the dock and bar can instead sit above the action row (y 532–596). → Q2.
3. **R3**, #397 / #412 / #414 / #416: one notice lane. All one-line transient notices (milestone, wave n/5, first kill, loot chip, Resonance, auto-picked) queue in the live `ToastQueue` host (max 3), and that host moves out of the landscape keep-out (to the top band, one visible row). → Q3.
4. **R4**, Ghost HUD: one top-left stack rule for everyone: live portrait/HP → #417 wave counter (when it gets UI) → #412 pill/goal → #416 strip, docked 8 px apart and right of the rail where they cross.
5. **R5**, #398 (Ghost check): `InventoryLayout.detailW(…, phone=true)` returns the full body width. If the landscape Bag runs as `phone`, there's no right detail column, and the 300 px side sheet covers the grid's right half. If so, use W = min(300, 0.45 × Bag W).
6. **R6**, live code (Ghost): `railFit` shrinks the rail to 37 px (667×375) and 42 px (800×400), under the 44 px floor.
7. **R7**, #416 / #397: shared type floor on phones of body 13 and badges/caps 11. The #416 card sub line (11–13) should be 12–13, and the main effect 13.
8. **R8**, #412 portrait: the mini reveal stage (y 618–738) covers the thumbstick zone. Make only the item tile the tap-to-skip target, and let touches elsewhere pass through to the thumbstick.
9. **R9**, live code (Ghost): on 667 and 800 the live HP bar, currency strip, toast host and jump button cross the #412 keep-out. Decide whether the live combat HUD follows the keep-out or only spec panels do.
10. **R10**, #412 hint chip: in portrait, "above the attack button" lands on the 2×4 skill bar. The must-have is a gold ring on the attack button; the label can shrink to "Tap ⚔" 96×32 over the empty skill-bar row for ≤ 6 s.

## 8. Open questions (answer by number)
1. **@Ghost (R1):** On notched portrait phones the band above the keep-out (y 99–236) can't hold the live HP/pills plus the #416 tray, #412 goal chip or any toast. OK to move the portrait keep-out top from 28% to **35% (y 296)**? Prism recommends yes. Landscape and desktop stay as they are.
2. **@Ghost (R2):** In the **hub** (no enemies), may the attack/dodge/jump cluster and skill bar hide while the 56 px ROLL / collapse bar or the Gate dock is up? Otherwise both overlap the cluster at every phone size. In the **arena** the collapse bar would hide. Prism recommends yes. The alternative is moving those bars above the cluster, but on phones that lands in the keep-out.
3. **@Ghost (R3):** Route all one-line transient notices through the live `ToastQueue` host, and move that host to the top band on landscape phones (one row visible, the rest queue)? Prism recommends yes. Without it, portrait has no free spot for the #414 loot chip or the #416 Resonance toast.

No questions for Kevin. Nothing here is a taste call. These are layout rules Ghost owns.

## 9. Files
- Review: `docs/design/phone-layout-review/REVIEW_v1.md` (this file).
- Zone maps (SVG, fake data, original art): `mockups/zones-390x844.svg`, `mockups/zones-667x375.svg`, `mockups/zones-800x400.svg`, `mockups/zones-1280x720.svg`.
- Spec edits are on each spec's own branch (not this one): #397, #398, #412, #413, #414, #416. Each has a Decision-log line that points here.
