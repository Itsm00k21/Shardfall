# Roll x10 results v1: a Legendary call-out and a readable list, no cramped grid (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost (`MenuHub` roll page, `RollSummaryHud`, `RollReveal` are Ghost-owned; Prism edits none of them). Base: `cursor/live-build-9721` @ **`9c42ce6`** (client/UI files identical to `5501c2f`, where the line refs were read). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP51P https://app.notion.com/p/403c31ca38838108916bf0353aac7dc4 (item 2, overhaul step 5: "no cramped grid, Legendary call-out"). ACK: https://app.notion.com/p/403c31ca388381db9a78e9f3ba6d7204. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Supersedes: the x10 summary section of Roll/Reveal spec v1.2 (`prism/roll-reveal-v1.2`, #397: 5×2 grid + best tile) and PANEL_STYLE §5 "Roll x10 grid". Keeps: `RollSummary` data (outcomes, headline, STEP 0.3 s), the per-card crack pace, Skip, the existing big-roll sound. Mockups: `mockups/01`–`04`.

## 1. Goal
Ten pulls should feel like one event with a winner, not a spreadsheet. The best pull gets a big call-out card (Legendary: rays, gold flash, scale pop). The other nine read as a calm list, best first, with name, rarity, outcome and power at ≥ 14 px. It all happens **inside the Roll panel** (Z12), so it never sits on the screen center or over the rail.

## 2. Where it lives + live audit (`5501c2f`)
| What players get today | Evidence | Change here |
|---|---|---|
| A 5-column grid of ≤ 104 px tiles in its own frame, **centered on screen** (desktop x 672-1248, y 372-708, inside the keep-out; 390×844 x 9-380, y 259-585, over `RAIL_SAFE` x 0-72) | RollSummary.luau:266-296 (`layout`, `MAX_CELL 104`, `x = (vx − w)/2`, `y = (vy − h)/2`); mounted on the hub screen, MenuHub.luau:2004 | Results replace the pedestal area **inside Z12** |
| Cramped text: names 13 px (11 px when cells < 84, i.e. every phone), result line 11, badges 10 | RollSummaryHud.luau:168, :175, :183 | Rows with name 16, badge 14, outcome tag 14 |
| No winner. The approved best tile (v1.2) isn't in live: no "best" code in RollSummary or RollSummaryHud, tiles are in roll order | grep @ 5501c2f | Best pull = call-out card; tie-break kept from v1.2 (NEW wins, then earliest roll) |
| Skip is 72×30 at 15 px | MenuHub.luau:1991-1995 | Skip 110×44 (phone) / 120×48 (desktop) |
| Chest open-many (≤ 10, `ChestConfig.OPEN_MANY_MAX`) flashes a 128×44 text grid for 0.25 s, then "Opened %d chests." | RollReel.luau:446, :1021-1035, :1201-1213 | Same results view when the chest roll lands on the Roll panel (Q3) |

## 3. Flow
1. **CRACK x10** (green, Roll panel crack row). The pedestal area becomes the results area in the same panel.
2. **Revealing** (mockup 02 left): each card plays its mini crack at ≤ `RollSummary.STEP` 0.3 s and drops into the list (0.06 s pop). The call-out slot is a dashed gold frame that says "Best pull lands last" with a progress bar ("6 of 10 cracked"). **Skip »** (110×44) lands the rest at once.
3. **Best pull lands last**: the call-out fills. Rarity decides the beat (§8): Legendary = flash + scale pop + rays; Epic = a sweep; Rare and below = just the card.
4. **Results** (mockups 01, 02 middle/right): call-out (EQUIP NOW + Keep, or "Keep in bag (worn is better)" when it isn't an upgrade), "THE OTHER 9" list best first, a tally row (Legendary ×1 · Epic ×1 · …), the `RollSummary.headline` line, and **Done** / **CRACK x10 · 10 Shards**.
5. **Done** or the header chevron → back to the pedestal (Done) or the panel collapses into the rail button (chevron). Tapping a row opens that item in the Bag detail (same Z12 rect, Bag tab).
6. Not enough Shards: CRACK x10 is disabled and the strip says "Not enough Shards." No Robux prompt, no "buy more".

## 4. Layout
**Desktop 1920×1080 (mockup 01)**, Z12 x 112-1552, y 104-920:
| Piece | Rect inside the panel | Notes |
|---|---|---|
| Header | 0-1440 × 0-64 | "ROLL" + "Gear Shards · x10 results"; Shards chip 170×44 ("36 Shards left"); collapse 44 |
| Tabs | y 80, h 44 | Gear Shards · Pet Shards (locked while a batch runs) |
| Call-out card | x 20-580, y 140-740 (560×600) | label "★ LEGENDARY PULL ★" 18 caps; icon tile 150 with rays; name 30; badge + NEW; Power box 48 with delta; traits line 16; EQUIP NOW (blue) + Keep 48 |
| The other 9 | x 600-1420, y 144-740 | title 18 + "best first"; tally chips 30 tall; **9 rows × 52, gap 6** (820 wide): accent bar 5, icon 40, name 16, badge 24, power 16, outcome tag 24 (NEW / COPY / SALVAGED +6 Essence) |
| Footer | y 746-802 | headline strip 920×44 (`RollSummary.headline`), Done 160×56, CRACK x10 280×56 (green) |
**Phone 390×844 (mockup 02)**, Z12 x 72-382, y 136-836: header 56; call-out 286×346 at y 68 (icon 80, name 20, badges 24, Power box 40, EQUIP NOW + Keep 44); "THE OTHER 9 · BEST FIRST" 14; list rows 286×52 (icon 36, name 16, badge 22, outcome tag 24) in a `ScrollingFrame` (3 rows visible, fade at the bottom edge); sticky footer Done 86×44 + CRACK x10 192×44. Reveal state: dashed call-out slot 286×220 + list in roll order + Skip 110×44 bottom-right.
**Landscape 667×375 / 800×400 (mockup 03)**: Z12 x 76-651 / 76-784 (covers Z1/Z3). Call-out on the left (230 / 270 wide, full height), list on the right (rows 48), Done + CRACK x10 under the list. 4 / 5 rows visible, the rest scroll.
**Order rule:** best pull in the call-out; the list is sorted by rarity (high → low), then NEW first, then power, then roll order. Auto-salvaged rows sink to the bottom at 0.7 opacity.

## 5. States
| State | Look |
|---|---|
| Revealing | dashed call-out slot + progress; list fills in roll order; Skip visible |
| Legendary best | gold call-out, rays rotating, "★ LEGENDARY PULL ★", gold flash once, EQUIP NOW if it beats what you wear |
| Epic best | purple call-out (Epic text lifted `206,150,240`), "BEST PULL", one `UIGradient` sweep, no rays |
| Rare-or-lower best | same card in the rarity color, "BEST PULL", no beat |
| Not an upgrade | delta in `255,150,150` ("−12 vs worn"); one button "Keep in bag (worn is better)" |
| Pet Shards batch | same layout; outcomes are NEW / ★ up / ★ fed (from `RollSummary.OUTCOMES`); EQUIP NOW becomes "Set active" |
| Two Legendaries | call-out shows the tie-break winner; the other Legendary is the first list row with a gold accent and a "LEGENDARY" badge (no second beat) |
| Not enough Shards | CRACK x10 disabled, reason in the strip |
| Skip pressed | all rows land at once; the call-out beat still plays (it's the reward, ~0.6 s) |

## 6. Copy
"★ LEGENDARY PULL ★" · "BEST PULL" · "Best pull lands last" · "6 of 10 cracked" · "THE OTHER 9" + "best first" · tally "Legendary ×1" · outcome tags "NEW" / "COPY" / "SALVAGED" (+ "+6 Essence" on desktop) / "★ UP" / "★ FED" · "EQUIP NOW" · "Keep" · "Keep in bag (worn is better)" · "+56 vs worn" · headline from `RollSummary.headline` ("x10: 4 NEW · 2 auto-salvaged (+12 Essence)") · "Legendary pity reset" · "Done" · "CRACK x10 · 10 Shards" (phone "CRACK x10") · "Skip »" · "Not enough Shards."

## 7. Visual style
Call-out: `UICorner` 14, `UIStroke` 3 in `Rarities.COLOR`, fill = radial-look via two stacked `UIGradient` frames (rarity @ 0.7 → `26,30,40`); icon tile `UIStroke` 3. List row: `UICorner` 10, `UIStroke` 1.5 rarity @ 0.45, 5 px accent `Frame` in the rarity color, horizontal `UIGradient` (rarity @ 0.84 → `26,30,40` at 0.55). Tags: pills, 14 px caps, NEW gold `255,206,96`, COPY `150,200,255`, SALVAGED `198,192,214`. Buttons per PANEL_STYLE (EQUIP blue, CRACK green, Done/Keep secondary). No blur, no drop shadows.

## 8. Motion (mockup 04)
- Rows: pop in at 0.06 s stagger (`UIScale` 0.9 → 1 + transparency, 0.12 s) as each mini crack ends (≤ 0.3 s per card, unchanged).
- **Legendary beat** (total ~0.6 s, then idle): 0.00-0.30 s gold flash `Frame` over the results area (BackgroundTransparency 0.6 → 1) + the existing big-roll sound; 0.30-0.60 s call-out `UIScale` 1 → 1.08 → 1.04 (Back Out), rays fade in; 0.60 s+ rays `Rotation` 0 → 360 every 6 s (loop while visible), EQUIP NOW gets gamepad focus. No screen shake.
- **Epic**: one sweep (child `Frame` with `UIGradient` Transparency band, `Offset` −1 → 1 in 0.6 s, once).
- Respect reduced motion (`uiSettings` if present): no rotation, flash at half strength.

## 9. Roblox build notes
- Results live in the Roll panel body (a child `Frame` that replaces the pedestal area), not a separate `RollSummaryHud` root, so the rect is Z12 and UiAudit sees one panel. `RollSummary.tiles` / `headline` / `OUTCOMES` stay as the data source; add a pure `RollSummary.best(tiles)` (tie-break NEW → earliest) and `RollSummary.order(tiles)` for the list sort (Ghost-owned).
- List: `ScrollingFrame` + `UIListLayout` (Padding 6), rows `Frame` 52 tall (48 landscape). No `UIGridLayout`.
- Call-out rays: one `ImageLabel` (original 12-ray star, Phase S art), `ImageTransparency` 0.7, `Rotation` tween; flash: one `Frame`; scale: `UIScale`. ParticleEmitters are optional (a few gold sparks on the 3D pedestal only, never in the 2D panel).
- Skip: `TextButton` ≥ 110×44 (phone) / 120×48, 16 px. Replace the 72×30 button at MenuHub.luau:1991-1992.
- Text: name 16, badge 14, tags 14, nothing `TextScaled`. Names truncate with "…" on one line in rows (full name is in the Bag detail).
- Chest open-many can reuse the same view when it's opened from the Roll panel; from the world it keeps today's single best reveal (Q3).
- Prism edits no Ghost-owned file. This is the build brief.

## 10. Mobile checks
| Viewport | Check | Result |
|---|---|---|
| 1920×1080 | results inside Z12; call-out 560×600; 9 rows at 16 px fit with no scroll; buttons 56 | pass (mockup 01) |
| 390×844 | panel right of `RAIL_SAFE`; call-out 286×346; rows 52 with 16 px names; Skip 110×44; footer 44 | pass (mockup 02) |
| 667×375 | call-out 230 wide fits name 18 + EQUIP 44; list scrolls (4 rows) | pass, tight (mockup 03) |
| 800×400 | call-out 270; 5 rows visible | pass (mockup 03) |
| Desktop 1280×720 | panel 816×456 by formula: call-out 360 wide, list scrolls | by formula |

## 11. Open questions (answer by number)
1. **@Ghost:** move the x10 results into the Roll panel body (Z12) and retire the centered `RollSummaryHud` root? Prism recommends **yes**. Centered is how it lands in the keep-out and over the rail on phones.
2. **@Kevin (taste):** the Legendary beat = gold flash + scale pop + rotating rays (no screen shake), about 0.6 s, still played after Skip? Prism recommends **yes**. Skip should skip the wait, not the reward.
3. **@Ghost:** reuse this view for chest open-many when it's opened from the Roll panel? Prism recommends **yes**. Today it's a 0.25 s text grid nobody can read.
4. **@Ghost:** list order = rarity → NEW → power → roll order (instead of roll order)? Prism recommends **yes**. "Best first" is the point of a results screen.
5. **@Kevin (taste):** label "★ LEGENDARY PULL ★" (Legendary) vs "BEST PULL" (everything else)? Prism recommends **yes**.

## Decision log
- Oct 24, 2026: v1 written for DP51P item 2 (Prism). Nothing decided yet.
