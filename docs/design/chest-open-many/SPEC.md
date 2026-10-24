# Chest open-many results v1: the Roll x10 list, inside the Bag panel (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost (`InventoryHud` chest detail, `RollReel` chest path, `MenuHub` are Ghost-owned; Prism edits none of them). Base: `cursor/live-build-9721` @ **`9c42ce6`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP61P https://app.notion.com/p/403c31ca388381f5a797fa0c556761e7 (item 1: "chest open-many results reusing the x10 list in Z12"). ACK: https://app.notion.com/p/403c31ca388381998cbacb298c1de245. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Reuses: Roll x10 results v1 (`prism/roll-x10-results`, `docs/design/roll-x10-results/SPEC.md`: call-out card, "THE OTHER N" list, beat, order rule; DP51P Q6 decided "reuse for chest open-many"), PANEL_STYLE + HUD_ZONE_MAP (`prism/ui-overhaul`: Z12 rects, buttons, badges, status strip), Bag/Inventory merged panel (`prism/bag-inventory-panel`: 7 tabs incl. Chests). Mockups: `mockups/01`–`04` (PNG renders embedded in `.svg`, same as earlier Prism branches, since this push path carries text only).

## 1. Goal
Opening several chests at once should feel like one event with a winner, and the player should be able to read every result. Same look as Roll x10: one call-out card for the best drop, the rest as a calm best-first list with name, rarity, outcome and power at ≥ 14 px. It all happens **inside the Bag panel (Z12)** where the player pressed Open, never centered and never over the rail.

## 2. Where it lives + live audit (`9c42ce6`)
| What players get today | Evidence | Change here |
|---|---|---|
| "Open N" button in the chest detail, N = min(count, `OPEN_MANY_MAX` 10); Mythic is one at a time | InventoryHud.luau:1587-1601, ChestConfig.luau:31, :776-781 | Same entry; button becomes `OPEN 10` (crack green) next to `Open 1` |
| A centered `ChestGrid` frame 420×220, `UIGridLayout` 128×44 cells, bare `TextLabel`s at 13 px in the rarity color, roll order, no icon, badge or outcome | RollReel.luau:419-446, :1021-1035 | Results replace the Bag body inside Z12 (mockups 01-03) |
| Rare-or-lower best from a Common/Uncommon/Rare chest: grid shows **0.25 s**, then "Opened %d chests." in the banner | RollReel.luau:1201-1213; `quickOpen` ChestConfig.luau:208-220 | Results stay until Done; rows pop at 0.06 s |
| Legendary best (or any best from Epic+ chests): the full single chest reveal plays for the best only; the other 9 are never shown | RollReel.luau:1206-1211 (`playFullReveal`), `playOne` :1063 | Full reveal kept for Legendary (Q3), then it lands in the call-out with the x10 beat |
| Duplicates turn into Shard Dust or a star, and a full bag turns a drop into dust, but nothing tells the player in an open-many | `resolveDrop` kinds `item` / `star` / `dust` (+ `bagFull`), ChestConfig.luau:663-720; DUST Rare 50 / Epic 200, :69-76 | Outcome tag per row: NEW / ★ UP ★n / DUST / BAG FULL, headline totals |
| Pity is silent | `drop.pity = floor ~= nil`, ChestConfig.luau:827 | Small gold PITY marker on that row (Q5) |
| Best = first row of the highest rarity | `ChestConfig.bestIndex`, ChestConfig.luau:744-755 | Same tie-break as Roll x10: rarity → NEW → earliest (Q2) |
Context: chests are **parked** (`LaunchGate.chests = false`, LaunchGate.luau:26; ChestConfig.luau:370-373): play sources stop granting them, but owned chests still open, so this view is for players who already own chests until chests come back. Mythic: Rare/Epic/Legendary chest odds include Mythic 0.2 / 1.5 / 8 % (ChestConfig.luau:45-47) while V1 has 5 tiers (`extraTiers = false`). `pickEntry` falls back one tier when a rarity has no entries (ChestConfig.luau:543-555); I didn't check whether `entriesFor` drops Mythic entries with `extraTiers` off (Q7).

## 3. Flow
1. **Bag › Chests › a chest** (mockup 04, left): detail shows odds (`ChestConfig.oddsLines`), pity, **Open 1** (secondary) and **OPEN 10** (green, `min(count,10)`; label "OPEN 4" when you own 4). Mythic keeps its 3-card pick, one at a time.
2. **Revealing** (mockup 02 left): the Bag body (tab row stays, locked) becomes the results area. Call-out slot = dashed gold frame "Best chest opens last" + "6 of 10 opened" bar. Rows pop in **roll order** at 0.06 s each (no per-chest crack; chests are the fast path, total ≤ 0.6 s). **Skip »** (110×44) lands all rows at once.
3. **Best lands last**: Legendary = the existing full chest reveal (`playOne`, `REEL_SECONDS.Legendary` 2 s) plays, then the item lands in the call-out with the Roll x10 Legendary beat. Epic = one sweep. Rare and below = just the card.
4. **Results** (mockups 01, 02 middle/right, 03): call-out (EQUIP NOW + Keep, or "Keep in bag (worn is better)"), "THE OTHER N · best first" (N = opened − 1), tally chips, headline strip ("10 Rare Chests: 5 NEW · 2 ★ up · 3 → 150 Shard Dust"), **Done** + **OPEN N MORE** (N = min(left,10); hidden at 0, Done goes full width).
5. **Done** → back to the chest detail (same tab). Header chevron → the Bag collapses into its rail button. Tapping a row opens that item's detail (Bag detail pane / bottom sheet). Dust and BAG FULL rows open nothing (`Active = false`).
6. Errors ("Not enough chests.", "Choose a Mythic card first.") go to the panel status strip, never a banner. No Robux, no "buy more", no key-shop prompt here.

## 4. Layout
**Desktop 1920×1080 (mockup 01)**, Z12 x 112-1552, y 104-920 (same rects as Roll x10):
| Piece | Rect inside the panel | Notes |
|---|---|---|
| Header | 0-1440 × 0-64 | "BAG" + "Chests · opened 10 Rare Chests"; chest chip 210×44 ("7 Rare Chests left", chest-tier stroke); collapse 44 |
| Tabs | y 80, h 44 | Bag's 7 pills, Chests selected; locked while revealing |
| Call-out | x 20-580, y 140-740 (560×600) | "★ LEGENDARY FROM A CHEST ★" 18 caps + source line 14 ("Rare Chest #4 of 10"); icon tile 150 + rays; name 30; badge + outcome; Power 48 with delta; traits 16; EQUIP NOW + Keep 48 |
| The other N | x 600-1420, y 144-740 | title 18 + "best first"; tally chips 30; rows 820×52, gap 6 (9 fit, no scroll): accent 5, icon 40, name 16, badge 24, PITY 24, power 16 (or "+50 Shard Dust" 14), outcome tag 24 |
| Footer | y 746-802 | headline strip 920×44, Done 160×56, OPEN 7 MORE 280×56 (green, chest glyph) |
**Phone 390×844 (mockup 02)**, Z12 x 72-382, y 136-836: header 56 (title "BAG", sub "Opened 10 Rare Chests", chest chip 76×44, collapse 44); call-out 286×346 at y 68 (label "★ LEGENDARY ★" 14); "THE OTHER 9 · BEST FIRST" 14; rows 286×52 compact (name 16 on line 1; badge 22 + PITY + outcome tag on line 2, tag right-aligned) in a `ScrollingFrame` with a bottom fade; sticky footer Done 86×44 + OPEN 7 MORE 192×44. Small batch (2-3 chests): list fits, no scroll; status strip under it for bag-full.
**Landscape 667×375 / 800×400 / 844×390 (mockup 03)**: Z12 x 76-651 / 76-784 / 76-828 (covers Z1/Z3; they hide). Call-out left (230 / 270 / 270 wide, full height; EQUIP 44 + Keep 72×44), rows 48 on the right (4 / 4.5 / 4.5 visible, rest scroll), Done 80×44 + OPEN 7 MORE under the list.
**Order rule (same as Roll x10 §4):** best in the call-out; list by rarity (high → low), then NEW, then ★ UP, then power, then roll order. DUST and BAG FULL rows sink to the bottom at 0.7 opacity.

## 5. States
| State | Look |
|---|---|
| Revealing | dashed call-out slot + "n of N opened"; rows in roll order; Skip visible |
| Legendary best | full chest reveal first, then gold call-out with rays, "★ LEGENDARY FROM A CHEST ★", gold flash once |
| Epic best | purple call-out (Epic text lifted `206,150,240`), "BEST FROM N CHESTS", one sweep |
| Rare-or-lower best | card in the rarity color, "BEST FROM N CHESTS", no beat |
| Not an upgrade | delta `255,150,150` ("−12 vs worn"), one button "Keep in bag (worn is better)" |
| Best is a ★ UP or DUST | call-out shows it anyway with "★ UP ★3" / "+200 Shard Dust" in place of the Power box and a single **OK** button (no EQUIP) |
| Bag full | affected rows get BAG FULL (`255,150,150`); status strip "Bag full: 1 became 200 Shard Dust" (error kind) |
| Pity row | gold outline PITY tag next to the badge |
| Last chests | OPEN N MORE hidden, Done full width, chest chip shows 0 |
| Skip pressed | all rows land; the Legendary reveal + beat still play (Skip skips the wait, not the reward; same as Roll x10 Q2) |

## 6. Copy
"OPEN 10" / "OPEN 4" · "Open 1" · "Best chest opens last" · "6 of 10 opened" · "★ LEGENDARY FROM A CHEST ★" (desktop) / "★ LEGENDARY ★" (phone) · "BEST FROM 3 CHESTS" · source line "Rare Chest #4 of 10" · "THE OTHER 9" + "best first" · tags "NEW" / "★ UP ★3" / "DUST" / "BAG FULL" / "PITY" · "+50 Shard Dust" · "EQUIP NOW" · "Keep" · "Keep in bag (worn is better)" · "OK" · headline "10 Rare Chests: 5 NEW · 2 ★ up · 3 → 150 Shard Dust" · "Bag full: 1 became 200 Shard Dust" · "OPEN 7 MORE" · "Done" · "Skip »" · "7 Rare Chests left". No "Loot:" prefix, no "Opened %d chests." banner.

## 7. Visual style
Exactly the Roll x10 components (call-out `UICorner` 14 + `UIStroke` 3 rarity; rows `UICorner` 10, `UIStroke` 1.5 rarity @ 0.45, 5 px accent, rarity → `26,30,40` `UIGradient`), PANEL_STYLE buttons (EQUIP blue, OPEN green = crack kind, Done/Keep secondary), badges 24/22 at 14 px caps. New pieces: chest chip (pill-ish 10 radius, stroke = **chest tier** `Rarities.COLOR`, chest glyph 22), tags DUST `198,192,214`, ★ UP `150,200,255`, BAG FULL `255,150,150`, PITY gold outline (transparent fill). Colors only from `Rarities.COLOR` (Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`). No blur, no shadows.

## 8. Motion
Rows: `UIScale` 0.9 → 1 + transparency, 0.12 s, 0.06 s stagger, in roll order. Legendary: existing `playOne` chest reveal (unchanged), then the Roll x10 beat (0.0-0.3 s gold flash `Frame` over the results area, 0.3-0.6 s call-out `UIScale` 1 → 1.08 → 1.04 Back Out, rays `Rotation` 0 → 360 / 6 s while visible). Epic: one `UIGradient` `Offset` sweep −1 → 1 in 0.6 s. Re-sort to best-first after the last row lands: rows tween `Position` 0.2 s Quart Out. Reduced motion: no rotation, no re-sort tween (snap). All `TweenService`.

## 9. Roblox build notes
- Results are a child `Frame` of the Bag panel body (Chests tab), not the `ChestGrid` frame on the RollReel `ScreenGui`. Retire `manyFrame` / `fillGrid` (RollReel.luau:419-446, :1021-1035) once this lands; the single-chest reveal (`playOne`) and the Mythic pick stay as they are.
- Share one builder with Roll x10 (`ResultsList` or inside PanelChrome, Ghost's call): call-out + list + footer, fed rows of `{ name, rarity, kind, power, stars, dust, bagFull, pity, isNew }`. Chest rows come straight from the `OpenChest` result (`results`, `bestIndex`, `tier`); no new remote, no server change.
- Best + order: pure client helpers (`best(rows)`, `order(rows)`), shared with Roll x10. `ChestConfig.bestIndex` can stay for the server/announce path.
- List: `ScrollingFrame` + `UIListLayout` Padding 6, rows `Frame` 52 (48 landscape). No `UIGridLayout`. Text 16 / 14, `TextScaled` off, names truncate "…".
- Rays: one `ImageLabel` (original 12-ray star, Phase S art), `Rotation` tween; flash one `Frame`; scale `UIScale`. ParticleEmitters only on the 3D chest in `playOne`, never in the 2D panel.
- Touch: Skip 110×44, Done ≥ 86×44, OPEN ≥ 192×44 phone / 280×56 desktop, rows tappable 52 tall.
- Prism edits no Ghost-owned file. This is the build brief.

## 10. Mobile checks
| Viewport | Check | Result |
|---|---|---|
| 1920×1080 | inside Z12, 9 rows no scroll, footer 56, center keep-out only under the panel | pass (mockup 01) |
| 390×844 | panel right of `RAIL_SAFE` (x 0-72); call-out 286×346; rows 52 with 16 px names; tags right-aligned on line 2 so long names never collide; footer 44 | pass (mockup 02) |
| 667×375 | call-out 230 fits name 18 + EQUIP 44; 4 rows visible | pass, tight (mockup 03) |
| 800×400 / 844×390 | call-out 270; 4.5 rows visible | pass (mockup 03) |
| Small batch (2-3) | list fits, status strip visible, Done full width | pass (mockup 02 right) |

## 11. Open questions (answer by number)
1. **@Ghost:** show open-many results inside the Bag panel (Z12, Chests tab) and retire the centered `ChestGrid` frame? Prism recommends **yes**. It's the same move as Roll x10 Q1 (DP51P), and the grid sits in the keep-out today.
2. **@Ghost:** use the Roll x10 tie-break for the best (rarity → NEW → earliest) on the client, instead of "first of the highest rarity"? Prism recommends **yes**. One rule for both result views.
3. **@Kevin (taste):** for a Legendary from an open-many, keep the full chest reveal (~2 s) first, then land it in the call-out with the x10 beat? Prism recommends **yes**. Without it, a Legendary chest drop gets less ceremony than a Legendary shard.
4. **@Ghost:** show every outcome (NEW / ★ UP / DUST / BAG FULL) on its row, with dust totals in the headline? Prism recommends **yes**. Today dupes and a full bag silently become dust.
5. **@Kevin (taste):** a small gold PITY tag on a row that came from a pity floor? Prism recommends **yes**. It's honest, and players like seeing pity pay out.
6. **@Ghost:** add an "OPEN N MORE" repeat button (min(left, 10); hidden at 0)? Prism recommends **yes**. No Robux and no key-shop link, just the chests you already own.
7. **@Ghost / @Kevin:** Mythic in chest odds (0.2 / 1.5 / 8 % on Rare / Epic / Legendary chests) vs the 5-tier V1: confirm that no Mythic can land while `extraTiers` is off (`entriesFor` / `pickEntry` fallback)? Prism recommends **confirm it, and keep it gated for V1**. This spec draws only the 5 V1 tiers.

## Decision log
- Oct 24, 2026: v1 written for DP61P item 1 (Prism). Nothing decided yet.
