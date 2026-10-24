# Run Results Card v1: dungeon victory card in Z13, off center, mobile first (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`CombatHud` is Ghost-owned; Prism edits none of it). Echo: one optional payload field (Q6). Base: `cursor/live-build-9721` @ **`908b1f3`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP63P https://app.notion.com/p/403c31ca3883814b8d94eeba82410845 (item 2, "Victory / run results card on Z11-Z12 style"). ACK: https://app.notion.com/p/403c31ca388381739823f77864ade274. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Zones and style: HUD_ZONE_MAP v1.2 (Z13, `prism/zone-map-v12`), PANEL_STYLE v1.1 dialog shell (same branch), Z11 Defeated look (`prism/prompt-dialog`). Sibling: Shard Crater `ResultsWings` (`prism/results-card-pass` v1.2, gated on `m12Results`); this card uses the same landscape wing rects so the two can share one shell later (Q5). Mockups: `mockups/01`-`05`.

## 1. Goal
After a dungeon clear the player sees, in about 3 seconds, what they got (gold, tokens, XP, level up, voucher, materials) on a card that sits beside the hero, not on it, with one clear Continue and a CRACK shortcut when a voucher dropped. The card folds into a tab instead of vanishing, so loot can be re-read.

## 2. Where it lives + live audit (@ 908b1f3)
| Live | Evidence | Change here |
|---|---|---|
| Victory and Defeated share one `Result` Frame, `AnchorPoint 0.5` at scale **(0.38, 0.45)**, 340 wide, auto height | CombatHud.luau:472-476; title 22 (:500), body 15 (:512), Continue 44 at 15 px, corner 8 (:519-531) | Victory → Z13 card; Defeated → Z11 `DialogHud` (DP61P Q11) |
| At 1920×1080 the card spans about x 560-900, y 284-688: in the #420 keep-out and on the hero (`characterZone` x 880-1040, y 432-702). At 390×844 it spans x −22..318: over the rail (`RAIL_SAFE` x 0-72) and the hero | lune `characterZone`; mockups 02 (live panel), 04 | Z13 rects (§4) |
| Body is 4 text lines ("Gold  340 + 40 Gold Find", "Shard tokens  3", "XP  120", voucher line) | `victoryBody` CombatHud.luau:674-690; `ResultsGrid.voucherLine` (ResultsGrid.luau:103-110) | stat tiles + voucher strip; no "No roll voucher this clear." line |
| Loot tiles 64 px, names 13 px `TextScaled` down to **9 px** | CombatHud.luau:621-634 (`MinTextSize = 9`) | names 14 on 2 lines, no `TextScaled` (MIN_TEXT_PX) |
| Auto-hide after `dismissIn` (6 s; Auto-Farm 4 s), card just disappears | CombatHud.luau:655-672; Dungeons.luau:89-91; DungeonService.luau:1868-1873 | drain bar, then collapse to a 44 px Results tab |
| ScreenGui `DisplayOrder 8`, `MobileShell` (`DeviceSafeInsets`) | CombatHud.luau:200-202 | own gui at DisplayOrder 50, `CoreUISafeInsets` (zone map R2) |
| Payload: `dungeonName, gold, bonusGold, shardTokens, xp, levels, materials[{name,count}], voucher, dismissIn` | DungeonService.luau:1835-1847 | every field drawn; nothing new needed (optional `farm`, Q6) |
Out of scope: the Shard Crater card (`WaveArena/ResultsCard.luau`, centered (0.5, 0.55) 280×180) is covered by `ResultsWings` (`prism/results-card-pass`, gated `m12Results = false`).

## 3. Flow
1. Server sends `kind = "victory"` (`grant` sends it, then `finish` teleports the player to the hub, DungeonService.luau:1835-1847, :1896). Close any open panel; Z8 waits; Z4 shows its tab only; phones hide Z10; landscape phones hold Z6 toasts until the card collapses.
2. Card slides in (from the right edge; from the bottom on portrait), title + stats first, loot tiles pop in at a 0.04 s stagger. If `levels > 0` the LEVEL UP chip pops (`UIScale` 1 → 1.12 → 1).
3. **Continue** closes it. **Chevron** collapses it to the Results tab. **CRACK** (only when `voucher` is set) opens the Roll panel on the matching tab (Armory / Pets) and collapses the card.
4. Drain bar runs `dismissIn`; at 0 the card **collapses** to the Results tab (Q2). Tap the tab to reopen (timer does not restart). Starting the next run clears the tab.
5. Auto-Farm (`dismissIn` = 4): same card, shorter drain; the next run start clears it. With Echo's optional `farm = true` the Continue label reads "Next run in 4 s" (Q6).

## 4. Layout (Z13, safe-area px)
| Viewport | Rect | Inside |
|---|---|---|
| 1920×1080 | x 1464-1904, y 432-956 (440 × up to 524, bottom pinned; right column under Z4's tab) | pad 16 · header 44 (chest tile 44, title 26, LEVEL UP chip 22 under it, "4 s" counter, chevron 44) · 3 stat tiles 128×64 · voucher strip 52 with CRACK 112×44 · "LOOT · N KINDS" · 5 × 2 tiles 64 + 2-line names 14 · Continue 48 · drain 4 |
| 1280×720 | x 936-1264, y 196-704 (328 wide, clear of the bar at x ≤ 924 and the keep-out x 384-896) | same, tiles 4 per row |
| 390×844 | x 80-374, y 624-836 (294×212; below the keep-out at 616; Z10 hidden) | pad 12 · header 44 (tile 32, title 16 caps, "Level up · Lv 13" 14 green, chevron 44) · stat pills 36 · scrolling chip row 36 (voucher chip first, then "Verdant Wood ×5"…) · Continue 44 · drain 4 |
| 667×375 | x 471-651, y 56-359 (wing 180×303; Z10/Z4 hidden) | title "CLEARED" 18 + dungeon 14, chevron 44 · 3 stat rows 28 · voucher chip 32 "Crack ready" · tiles 44 + "+N" · Continue 44 |
| 800×400 | x 568-784, y 56-384 (216×328) | same, "Armory crack ready" |
| 844×390 | x 601-828, y 56-374 (227×318) | same |
| Collapsed tab | 112×44 under the Z4 tab (zone map v1.2 §4) | chest glyph + "Results" 16 |
Landscape wings = `ResultsWings` widths (floor(0.27 × vx)), so both result cards land in the same place.

## 5. States
| State | Look |
|---|---|
| Open | gold stroke 2 @ 0.35, top gold tint, drain bar gold |
| Level up | `LEVEL UP · Lv N` chip (ok green) under the title; N = level after (client reads it from the HUD; payload has `levels` count only) |
| Voucher | strip + CRACK (crack green). No voucher: strip hidden, loot moves up |
| No materials | loot block hidden; card shrinks (desktop) / chip row shows the voucher only |
| > 10 kinds (desktop) | 9 tiles + "+N" tile (ResultsGrid fold rule) |
| Collapsed | Results tab, gold stroke, chest glyph |
| Auto-Farm | drain 4 s; with Q6 the button reads "Next run in 4 s" |
| Clear did not save | run note "Clear did not save." when `grant` returns false (DungeonService.luau:1899-1903); unchanged, not part of this card |

## 6. Copy
Title `string.upper(dungeonName) .. " CLEARED"` (fallback "ROOTVAULT CLEARED"); landscape "CLEARED" + name under it (same rule as ResultsWings v1.1 Q3). Stats: "GOLD +340" with "+40" find in green, "TOKENS +3", "XP +120". Voucher: "Voucher · one free Armory crack" / "one free Pets crack"; phone chip "Armory crack"; landscape "Crack ready". Loot: material display names + "×N". Buttons: "Continue", "CRACK". Tab: "Results".

## 7. Visual style
PANEL_STYLE v1.1 shell (`36,40,52 → 26,30,40`, `UICorner` 16 / 14, `UIStroke` 2 `255,206,96` @ 0.35, top tint gold @ 0.86). Title gold `255,206,96` (10:1 on the shell). Stat tiles = PANEL_STYLE card (`26,30,40`, divider stroke). Material tiles: `UIGradient` Rotation 160 of the material color (`Materials.DEFS[id].color`) @ 0.5 → 0.88, stroke = color lifted 35% toward white, qty badge `18,12,34` @ 0.15 + `255,220,120` 14 bold bottom-right. Voucher strip gold @ 0.92 fill, gold stroke 1.5. Buttons: Continue primary, CRACK crack green. No blur, no shadows.

## 8. Motion / VFX
Open 0.2 s Quart Out (16 px slide + `GroupTransparency`); tiles 0.04 s stagger, `UIScale` 0.9 → 1; LEVEL UP chip pop 0.25 s; drain `Size.X` linear over `dismissIn`; collapse 0.15 s `Size` + `Position` into the tab rect. World: optional gold `ParticleEmitter` `Emit(12)` on the HumanoidRootPart (hub spawn), the same burst ResultsWings uses. All `TweenService`.

## 9. Roblox build notes
- New Ghost-owned `ResultsHud` (or a `DialogHud.results` variant) on its own `ScreenGui`, `DisplayOrder 50`, `ScreenInsets = CoreUISafeInsets`. `CombatHud` keeps parsing `kind = "victory"` and hands the payload over; `kind = "defeat"` goes to Z11 (DP61P Q11). Remove the shared `Result` Frame once both are in.
- Rect from `HudLayout.zone("Z13", vx, vy)`; bottom-pinned with `AnchorPoint (0,1)` / `(1,1)`, `AutomaticSize.Y` + `UISizeConstraint`. Never `AnchorPoint 0.5` on a scale position.
- Shell via the PANEL_STYLE v1.1 helper (`PanelChrome.shell`). Stat tiles: `Frame` + `UICorner 12` + `UIStroke` + `ImageLabel` (UiIcons) + 2 `TextLabel`s. Loot: `ScrollingFrame` (phone, horizontal `UIListLayout`, `AutomaticCanvasSize = X`) or `UIGridLayout` (desktop, CellSize 64×106). Data from `ResultsGrid.merge` (unchanged); `ResultsGrid.layout` with `MAX_ROWS` 2 still decides the "+N" fold.
- Names: `TextSize 14`, `TextWrapped`, 2 lines, `TextScaled = false` (drops the `UITextSizeConstraint` 9 at CombatHud.luau:631-634).
- CRACK: client-only, opens the Roll panel tab via the existing MenuHub/rail open call; no remote.
- Collapse tab: a 112×44 `TextButton` in the Z13 tab rect; cleared on the next `onRun({ active = true })`.
- Gamepad: `SelectedObject` = Continue; ButtonB = collapse.
- Prism edits no Ghost-owned file. This is the build brief.

## 10. Mobile checks
| Viewport | Off the keep-out / hero | Rail | Smallest tap | Text |
|---|---|---|---|---|
| 1920×1080 | yes (x ≥ 1464 vs keep-out ≤ 1344) | clear | chevron 44, CRACK 112×44, Continue 48 | ≥ 14 |
| 390×844 | yes (y ≥ 624 vs 616) | clear (x ≥ 80) | chevron 44, Continue 44 | ≥ 14; chip row scrolls |
| 667×375 | yes (x ≥ 471 vs 467) | clear | 44 | ≥ 14 |
| 800×400 / 844×390 | yes | clear | 44 | ≥ 14 |
Mockups: `01-results-1920x1080.svg`, `02-results-390x844-open-collapsed-live.svg`, `03-results-landscape-667x375-800x400-844x390.svg`, `04-results-live-vs-spec-1920x1080.svg`, `05-results-component-sheet.svg`.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** victory card on the right side (desktop and landscape) and as a bottom sheet on phones, instead of the center? Prism recommends **yes**. It's your "off the screen center" rule, and the hero stays in view.
2. **@Kevin (taste):** when the timer runs out, the card folds into a small "Results" tab you can tap to re-read, instead of disappearing? Prism recommends **yes**. Collapse, not close.
3. **@Ghost:** CRACK button on the voucher strip that opens the Roll panel (client only), and hide the "No roll voucher this clear." line? Prism recommends **yes**.
4. **@Ghost:** loot names at 14 px on 2 lines, dropping the `TextScaled` 13 → 9 px rule? Prism recommends **yes** (MIN_TEXT_PX).
5. **@Ghost:** one Z13 shell for this card and the Crater `ResultsWings` once `m12Results` flips (same wing rects already)? Prism recommends **yes, after the flip**.
6. **@Ghost → Echo:** add `farm = true` to the victory payload so Auto-Farm can say "Next run in 4 s"? Prism recommends **yes**, small and optional; until then only the drain bar shows it.

## Decision log
- Oct 24, 2026: v1 written for DP63P item 2 (Prism). Nothing decided yet. NOT APPROVED.
