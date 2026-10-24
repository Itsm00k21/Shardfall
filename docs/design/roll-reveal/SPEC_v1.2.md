# Roll Screen + Shard Crack Reveal: Spec v1.3


> **Mockups:** SVG mockups are in `mockups/` (folded in from closed PR #399). The JPG names in §8 are Prism's local renders.

Owner: Prism (design). Builders: Ghost (UI), Echo (server). Base: `cursor/live-build-9721` @ `49bd902`.
Supersedes v1.2 (file name kept so PR links stay valid). Changes in v1.3, from Ghost's answers in #15 comment 6380154154:
- **One Skip size:** at least **88×44** on phones (replaces the 96×44 / 88×44 mismatch).
- **Roll page collapses** to the 56 px ROLL-only bar (decided; it does not close fully).
- **Best-tile tie-break:** the **NEW** tile wins, then the earliest roll.
- Tier timings 0.55 / 0.70 / 0.90 / 1.30 / 2.20 s confirmed (Kevin approved ~0.6 s to 2.2 s).
- SVG mockups from #399 added, including `10-x10-best-tile`.

Changes in v1.2:
- Skip is at least 44 px tall on phones.
- The x10 summary is a 5×2 grid with a best-tile highlight (both approved by Ghost in #15 comment 6379856660).
- Tier-scaled timings kept (Kevin approved; Ghost to add them in RollReveal, 6378886198).
- The spec no longer depends on where the roll page lives (MenuHub or its own module).

Chrome comes from PR #392 `docs/ui/reference/STYLE.md`. Rarity colors come from `Shared/Rarities.luau` `Rarities.rgb`. Tiers and odds come from `Shared/Config/Rarities.luau`.

## 1. Goal
The player taps ROLL and, in under a second for common pulls (about 2 s for Legendary), sees what they got and how rare it is, with no confusion and no waiting.

## 2. Where it lives
- The **Roll page** (a tab of the main menu). The spec doesn't care which file hosts it. Ghost picks the host, and everything below is anchored to the Roll page's root frame.
- Open: the Roll tab or rail button. Collapse (**decided**, Ghost): the header chevron folds the page to a 56 px bar docked at the bottom (ROLL button only). Close: the X at top-right.
- Kevin's rule: the crystal and reveal sit in the page, not over the character. When the page is collapsed, nothing covers screen center.

## 3. Flow
1. Idle. The player picks a tab (Weapons / Armor / Pets / Skills) and x1 or x10.
2. Tap ROLL. The client asks the server. ROLL goes disabled (buttonDim) and the tabs lock.
3. **x1:** Charge → Burst → Reveal at the tier timing (§6). Any tap jumps to Reveal. Another tap on the reveal returns to Idle.
4. **x10:** each card plays a 0.3 s mini crack (`RollSummary.STEP`). **Skip** is visible the whole batch, and tapping it jumps to the summary. The batch ends on the **x10 summary** (5×2). **Roll again** repeats x10, and **Close** returns to Idle.
5. Cancel/back: the X or Back on the summary = Close. A tap or back during a reveal = skip to the result, never cancel the roll (the server already paid).
6. Not enough currency: ROLL shakes, the currency amount flashes danger, and no request is sent.

## 4. Layout
Reference is the phone portrait 390×844 (pt). All Roll-page children use scale + offset.
| Piece | Anchor / Position | Size | Notes |
|---|---|---|---|
| Currency pill | (1,0) / (1,-12, 0,12) | auto × 40 | `+` hit box ≥ 44×44 |
| Tabs row | (0.5,0) / (0.5,0, 0,60) | (1,-24) × 44 | 4 equal, gap 6, labels shorten when narrow |
| Crystal stage | (0.5,0.42) | min(0.7w, 0.38h) square | idle bob ±4 px / 2 s |
| Pity arc | right of crystal | 64×64 | "112/150" |
| Pip strip | (0.5,0) below crystal | (1,-48) × 56 | 5 pips 40 px + labels; "i" hit box 44 |
| ROLL | (0.5,1) / (0.5,0, 1,-24-safe) | 0.55w × 72 (phone) / 96 (tall) | never < 44 tall |
| x1/x10, Auto/Skip toggles | left / right of ROLL | ≥ 88×48 each, gap 8 | stacked |
| **x10 Skip** (`SkipBatch`) | (1,1) / (1,-16, 1,-16-safe) | **≥ 88×44 on every size** | one size (v1.3; desktop was 72×36 until the phone layout review, F1); v1.1 had 72×30 |
| x10 summary panel | (0.5,0.5) | phone (1,-24) × auto; desktop 760 × auto | §6 values |
| Milestone toast | (0.5,0) / top inset 4 | 220×26 | |
| **Collapse bar** (collapsed page) | (0.5,1) / (0.5,0, 1,-8-safeBottom) on portrait; bottom 14 on landscape phones; bottom 24 on desktop | portrait 250×56 · 667×375 240×56 · 800×400 260×56 · desktop 320×64 | the same slot and sizes as the #412 ROLL bar. Who owns the bottom slot in the hub vs. the arena is in the phone layout review (R2) |
Phone landscape 667×375 and 800×400: the crystal stage moves left (0.33, 0.5), and the pips, ROLL and toggles stack in a right column at 0.45w. The x10 summary stays a 5×2 grid, with tile = min(96, (panelW-2·14-4·8)/5, (safeH-150)/2). The height term keeps it from scrolling at 667×375, where the safe height is about 323, so tile = 86. Desktop (≥ 1280 w): the page caps at 1180×680, centered right of the left rail.
Safe areas: obey `GuiService:GetGuiInset()` and keep 12 px from the notch and home bar.

## 5. States
| State | Look |
|---|---|
| Empty | not used (the roll page always has a crystal) |
| Loading | ROLL shows a rotating `spinner_64` ImageLabel (TweenService Rotation 0→360, 0.8 s loop) and is disabled. The crystal pulses slowly. After 5 s: "Still rolling…" |
| Normal | Idle as in mockup `01-idle-phone.jpg` |
| Full (bag full) | ROLL is enabled. The server returns its full-bag reply, and the "Salvage now" nudge (`GearHooks.SALVAGE_NOW`, live) appears above ROLL |
| Error | toast with the server text, ROLL is re-enabled, nothing is charged |
| Locked | tab locked: padlock + muted label, tap = "Unlocks at …" toast |
| Disabled | while rolling: tabs and toggles dim (buttonDim 54,46,78) |

## 6. Numbers
### Tiers (Config/Rarities.luau) and colors (Rarities.rgb)
| Tier | RGB | Odds | Cracks |
|---|---|---|---|
| Common | 168,168,176 | 1 in 2 | 0 |
| Uncommon | 64,186,98 | 1 in 4 | 1 |
| Rare | 72,142,255 | 1 in 15 | 2 |
| Epic | 186,96,240 | 1 in 100 | 3 |
| Legendary | 255,196,64 | 1 in 1,000 | 4 |
Pity: Legendary only. Soft from roll 101 (+2%/roll), hard at 150 (`Rarities.PITY`). The meter reads "N/150".

### x1 timings (s), tier-scaled. Ghost adds these in RollReveal
| Tier | Charge | Burst | Hold | Total |
|---|---|---|---|---|
| Common | 0.15 | 0.10 | 0.30 | 0.55 |
| Uncommon | 0.25 | 0.12 | 0.33 | 0.70 |
| Rare | 0.35 | 0.15 | 0.40 | 0.90 |
| Epic | 0.60 | 0.20 | 0.50 | 1.30 |
| Legendary | 1.00 (+0.2 dim) | 0.35 flash + 0.1 punch | 0.85 | 2.20 |
Skip is never gated: `skipReady` is true from 0. Auto skips Common, Uncommon and Rare.

### x10
- Each card takes at most 0.3 s. Skip is always visible.
- Summary: a 5×2 grid in roll order.
  - Panel: 30,26,44, corner 12, gold stroke 2 (255,205,90).
  - Tiles: square, corner 8, fill = rarity mixed 22% into 40,34,58, border 2 in the rarity color.
  - Badges: corner 4, h 18, text 11, ink 24,18,32. NEW 120,220,140 · ★ up 255,205,90 · Salvaged 230,120,110.
  - Roll again: 255,205,90, text 24,18,32. Close: 58,52,80, text 240,236,250. Both h 44, corner 8, BuilderSansBold 16.
- **Best tile** (approved): the highest rarity in the batch. Tie-break (decided): a **NEW** tile wins; if still tied, the earliest roll.
  - Border becomes gold 255,205,90 at thickness 3.
  - A gold glow sprite behind the tile (`ImageLabel` `glow_soft_256`, ImageColor3 255,205,90, ImageTransparency 0.4, size tile+16). No blur or drop shadow: Roblox can't render them.
  - A "BEST" badge at top-right in 255,205,90.
  - It pulses once (scale 1.0 → 1.06 → 1.0 over 0.4 s) when the summary opens.

### Chrome and type
- Colors: bg 16,14,24 · panel 28,24,40 · row 40,34,58 · text 240,236,248 · muted 176,168,198 · button 108,78,196 · buttonDim 54,46,78 · gold 255,196,64 · ink 32,22,10 · danger 230,80,96.
- Skip: fill 20,24,32, text 244,240,252, BuilderSansBold 15, corner 8.
- Fonts: BuilderSansBold (titles, buttons, names), BuilderSans (body), BuilderSansExtraBold (the ROLL word). Text ≥ 14 except badges (11).
- Corners: CORNER 10, buttons 8, popups 12. PAD 8.

### Exact text
"ROLL" · "x1" · "x10" · "Auto" · "Skip" · "x10 Results" · "Roll again" · "Close" · "BEST" · "NEW" · "★ up" · "Salvaged" · "1 in N" banner · "Not enough Shards."

## 7. Edge cases
- Double-tap ROLL: the first tap disables the button, and the second tap is ignored until Idle.
- Fast taps during x10 jump to the summary, never skip the summary itself.
- Server refuses or times out after 5 s: toast "Could not roll. Try again.", ROLL re-enabled, nothing charged.
- Bag full: the server's reply plus the "Salvage now" nudge. No crack plays.
- Auto-salvaged drops show the Salvaged badge in the summary and on the x1 result ("Auto-salvaged +N Essence", `GearHooks`).
- First time: the first roll is always played at full length (no Auto). A 1-line hint "Tap to skip" shows during the first charge.
- Reduced motion (a Settings row): no UIScale punch or shake. Timings stay the same.

## 8. Mockups
| File | State |
|---|---|
| `01-idle-phone.jpg` | Idle, phone portrait, 5 pips |
| `02-uncommon-phone.jpg` | x1 Uncommon reveal, phone portrait |
| `09-x10-results-phone-390x844.jpg` | x10 summary 5×2, square tiles, best tile, phone (PIL rebuild) |
| `09-x10-results-desktop.jpg` | x10 summary, desktop 1600×900 |
SVG mockups in `mockups/`: `01-idle.svg`, `02-uncommon.svg`, `09-x10-results.svg`, `10-x10-best-tile.svg`. Legendary and landscape frames come in a later rev.

## 9. Build split
- **Ghost (UI):**
  - Roll page layout and states.
  - Per-tier durations in `RollReveal`.
  - `SkipBatch` sized to ≥ 88×44 on phones.
  - The 5×2 grid and best tile in `RollSummaryHud`.
  - Collapse bar and the toast.
- **Echo (server):** none new. Keep the roll reply's rarity, `autoSalvaged`, `essenceGained`, and NEW / ★ up flags per batch row.

## 10. Pass criteria (playtest)
1. A Common x1 finishes in under 0.6 s and a Legendary takes about 2.2 s. A tap skips either at any moment.
2. On a 390×844 phone, Skip during x10 is at least 44 px tall and reachable with a thumb.
3. The x10 summary is a 5×2 grid of square tiles with the best tile gold-highlighted, plus working Roll again and Close.
4. Pips show the 5 tiers with 1/2, 1/4, 1/15, 1/100 and 1/1K labels in the `Rarities.rgb` colors.
5. When collapsed, the Roll page leaves screen center clear at 390×844, 667×375 and 800×400.

## 11. Open questions
1. ~~@Ghost: collapse bar or close fully?~~ **Collapse to the 56 px ROLL-only bar (Ghost).**
2. ~~@Kevin: on a first-ever roll, force full length with no Auto?~~ **Yes (Ghost, Kevin pre-approved, Oct 23, 2026).** The first-ever roll always plays at full length with no Auto, as §7 already says. Kevin can change it later. Board row: https://app.notion.com/p/403c31ca388381c0bb72d75abab9bd4d
3. ~~@Ghost: best-tile tie-break?~~ **NEW tile, then earliest roll (Ghost).**

## Decision log
- 2026-10-23 (Ghost, Kevin pre-approved): Q2 = **yes**, the first-ever roll plays full length with no Auto. All §11 questions are now closed.

- 2026-10-23 (Prism, phone layout review, docs/design/phone-layout-review/REVIEW_v1.md): F1: Skip is 88×44 on desktop too, so it's really one size. F2: added collapse-bar geometry (the same slot as the #412 ROLL bar). F3: the x10 tile gets a height cap so the 5×2 summary fits 667×375 without scrolling. F4: badges go from 10 to 11 px (h 18) so they're readable on phones. No design change.

## Later (not V1)
Mythic/Secret reveal (Phase 5 appendix in v1.1), Legendary cross-server announcement, and reduced-motion variants.

## Roblox build notes
Everything here must render with stock Roblox UI.
- **Not available:** no blur or glassmorphism (BlurEffect blurs the 3D world, not GUI), no soft drop shadows, no CSS-style glows, no custom web fonts.
- **No particles in the UI:** a `ParticleEmitter` does not render in a ScreenGui or inside a ViewportFrame. All UI "particles" are tweened ImageLabels.
- **Mockups are a guide:** the mockups are AI-drawn. Where one looks softer or more painterly than Roblox can render, these notes win.

| Element | Instances |
|---|---|
| Roll page root | `ScreenGui` (IgnoreGuiInset false, ResetOnSpawn false, ZIndexBehavior Sibling) → `Frame` RollPage + `UIScale` (phone 1.0, desktop by `UIScale` = min(w/1180, h/680)) |
| Panels, pills, tabs | `Frame` / `TextButton` + `UICorner` (8/10/12) + `UIStroke` (ApplyStrokeMode Border, 1–2 px) + `UIPadding` |
| Rows | `UIListLayout` (tabs: Horizontal, Padding 6; toggles: Vertical, Padding 8) |
| Text | `TextLabel` / `TextButton`, `FontFace = Font.fromEnum(Enum.Font.BuilderSans / BuilderSansBold / BuilderSansExtraBold)`, TextSize ≥ 14, `TextScaled` off with `UITextSizeConstraint` where needed |
| Currency pill | `Frame` + `ImageLabel` shard_icon + `TextLabel` + `TextButton` "+" |
| Crystal | **Option A (preferred):** `ViewportFrame` with one low-poly `MeshPart` (flat faceted, Material SmoothPlastic, the tier color via `Color`), a `Camera` and a `WorldModel`; spin and shake via TweenService on the part CFrame. Cracks = `Decal`s on the mesh, or ImageLabel overlays. **Option B (cheap):** an `ImageLabel` crystal_base sprite + crack overlay sprites |
| Crystal glow | `ImageLabel` glow_soft_256 behind the ViewportFrame, ImageColor3 = tier color, ImageTransparency 0.35→0.1 tween while charging |
| Pedestal | part of the crystal mesh scene (VPF), or `ImageLabel` pedestal_hex |
| Burst fragments | 6–10 `ImageLabel` shard_frag sprites, TweenService Position/Rotation/ImageTransparency outward over the burst time, then Destroy |
| Legendary flash / dim | full-screen `Frame`, BackgroundColor3 255,240,200 (flash) or 0,0,0 (dim), BackgroundTransparency tween 1→0.2→1 |
| Screen punch | `UIScale` on RollPage, 1→1.04→1 over 0.1 s (no camera effects needed) |
| Pity arc | `ImageLabel` ring_arc_128 + `UIGradient` (Transparency NumberSequence driven by pity %) to fake the fill |
| Tier pips | `Frame` + `UICorner` (0.5 scale = circle) + `UIStroke` 2; lit = BackgroundTransparency 0, dim = 0.6 |
| Result banner | `Frame` + `UICorner` 10 + `UIStroke` (tier color) + 2 TextLabels |
| ROLL button | `TextButton` + `UICorner` 8 + `UIStroke` gold 2 + `UIGradient` (light top → base) + `ImageLabel` shard_icon |
| Toggles, Skip | `TextButton` + `UICorner` 8; Skip `Size` ≥ (0,88,0,44) on every size |
| x10 summary | `Frame` panel + `UIGridLayout` (CellSize derived from width/5, CellPadding 8, FillDirectionMaxCells 5) + per-tile `UIAspectRatioConstraint` 1.0 |
| Tile | `Frame` + `UICorner` 8 + `UIStroke` 2 + `ImageLabel` icon + `TextLabel` name + badge `Frame`/`TextLabel` (corner 4) |
| Best tile | `UIStroke` gold 3 + `ImageLabel` glow_soft_256 behind (ZIndex −1) + `UIScale` pulse 1→1.06→1 |
| Toast | `Frame` 220×26 + `UICorner` 13 + `TextLabel` |
| Animation | `TweenService` only (TweenInfo Quad/Back Out); no per-frame Heartbeat except the crystal bob |
| Touch | all buttons `TextButton`/`ImageButton` ≥ 44 px tall; `GuiService` inset for safe areas |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| glow_soft_256 | 256×256 | white radial glow; tinted by ImageColor3 (crystal, best tile, reveal) |
| shard_icon | 64×64 | currency and ROLL cost |
| crystal_base (option B) | 512×512 | flat faceted crystal, white so it can be tinted |
| crack_1..4 | 512×512 each | crack overlays, white lines |
| shard_frag_a/b/c | 64×64 each | burst fragments, white (tinted) |
| pedestal_hex (option B) | 512×256 | flat hex base |
| ring_arc_128 | 128×128 | pity arc |
| spinner_64 | 64×64 | loading |
| lock_icon | 32×32 | locked tab |
| crystal mesh (option A) | ≤ 500 tris | MeshPart for the ViewportFrame |
