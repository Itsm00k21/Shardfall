# Shardfall – Shard Crack Roll Reveal: Build Spec v1.2

v1.2 (2026-10-23) applies Ghost's answers in #15 comment 6379856660: Skip is at least 44 px tall on phones, the 5×2 x10 grid and best-tile highlight are approved, and nothing in this spec depends on where the roll page lives.
v1.1 (2026-10-23) aligns v1 with the UI reference pack (PR #392, `docs/ui/reference/STYLE.md` + `OWNERSHIP.md`, values quoted from `ghost/gear-ui-hooks` @53549b6 and `ghost/roll-x10` @d3686ba).
The pack's screenshots are still missing (see MISSING.md), so this version is **provisional** until they land. Items marked **OPEN** need a call from Kevin or Ghost. Ghost's answers on #15 (comment 6378767634) are marked **RESOLVED**.
**Tiers (RESOLVED):** `Config/Rarities.luau` is canonical. V1 has 5 tiers: Common, Uncommon, Rare, Epic, Legendary. Mythic/Secret are reserved and fold into Legendary until Phase 5. UiTheme's 5-tier list is stale.
Mockups: `01-idle` … `09-x10-results` (portrait 9:16, 720x1280 ref). `01` and `09` are superseded by `v1.1/01-idle`, `v1.1/02-uncommon` and `v1.1/09-x10-results`. `06`–`08` (Mythic) move to Appendix A.

## 0. Ownership (read first)
- `RollReveal.luau` (single-roll clock), `RollSummary.luau` + `RollSummaryHud.luau` (x10 pace + summary), and `MenuHub.luau` (roll page, `SkipBatch`, `Milestone` toast) belong to **Ghost**. Any change in them goes as a request on #15. Nobody else edits those files.
- `RollScreen`, `CrackReveal`, `RollReel`, `UiTheme` are not on the Ghost list. Where the roll page lives (MenuHub or its own screen) is still to be confirmed by Ghost; this spec is written so that it doesn't matter. All sizes are relative to the roll page's own frame and safe area, not to MenuHub.
- Settings rows (Auto, Skip) can be appended to `Settings.luau` (append-only rule).

## 1. Sequence (single roll)
Idle → Charge (shake + glow climbs tier colors; each step = +1 crack + pulse) → Burst → Reveal (item glows tier color, banner "1 in N") → Settle (Roll re-enabled).

## 2. Single-roll timings (5 tiers). Approved by Kevin; Ghost is adding a per-tier duration to RollReveal
Current code: `RollReveal.FULL` 1.65 s full, 0.7 s short, the same for every tier. Proposal: tier-scaled, with Legendary as the top moment.
| Tier | Total | Charge | Burst | Reveal hold | Extras |
|---|---|---|---|---|---|
| Common | < 0.6 s | 0.15 s (no climb, 0 cracks) | 0.10 s snap | 0.30 s | gray glow, small pop |
| Uncommon | ~0.7 s | 0.25 s (gray→green, 1 crack) | 0.12 s | 0.33 s | green pulse |
| Rare | ~0.9 s | 0.35 s (→blue, 2 cracks) | 0.15 s | 0.40 s | blue pulse ring |
| Epic | ~1.3 s | 0.60 s (→purple, 3 cracks) | 0.20 s | 0.50 s | purple streaks |
| Legendary | ~2.2 s | 1.00 s (→gold, 4 cracks, heavy shake, brief screen dim 0.2 s) | 0.35 s white-gold flash + shatter + screen punch 0.1 s | 0.85 s | gold sparks, speed lines, Milestone toast |
Skip is never gated (`skipReady` from 0). A tap jumps to the reveal, and the result stays until the next tap. Auto implies Skip for Common/Uncommon/Rare.

## 2b. x10 roll (adopted from pack)
- Each card shows for at most **0.3 s** (`RollSummary.STEP = 0.3`; `RollSummary.fast` scales longer plans down). This does not use the single-roll clock.
- A mini crack plays per card, compressed into 0.3 s: glow at the tier color → snap. No Hollow drain or flash in x10.
- **Skip** (`SkipBatch`, "Skip") is visible for the whole batch, bottom-right, inside the safe area. It's at least 44 px tall on phones (see §5).
- The batch ends on a **10-tile summary grid, 5 columns × 2 rows** (**APPROVED**, Ghost), (`RollSummaryHud` / `RollSummary`) with **NEW**, **★ up** and **Salvaged** badges, plus **Roll again** and **Close** buttons. The v1 "tap anywhere to close" is replaced by Close.
- Milestones (Legendary) appear as a small top toast, not a banner over the reel.
- x10 adopted (**RESOLVED**, Ghost).
- **Best-tile highlight (APPROVED, Ghost):** the highest-tier tile in the grid (ties go to the first one rolled) gets a 3 px border in its rarity color, a soft outer glow (rarity color, 0.6 transparency, 6 px), and a 0.25 s scale pulse 1.00 → 1.06 → 1.00 when the grid appears. It stays in its grid cell (no enlarging, so the 5×2 layout never shifts). Legendary adds 4–6 small gold sparks around the tile for 0.6 s. Common-only batches get no highlight.

## 3. Colors (RGB) — pack values adopted for chrome
| Token | RGB | Source |
|---|---|---|
| Background | 16,14,24 | InventoryHud `background` (matches v1) |
| Panel | **28,24,40** (was 32,36,46) | GearBar `COLORS.panel` |
| Row / card base | 40,34,58 | InventoryHud `row` |
| x10 summary panel | 30,26,44, gold stroke 2 (255,205,90) | RollSummaryHud |
| Text | 240,236,248 | GearBar |
| Muted text | 176,168,198 | GearBar |
| Primary button | 108,78,196 | GearBar `button` (matches v1) |
| Button dim (rolling / disabled) | 54,46,78 | GearBar `buttonDim` |
| Gold accent / trim | **255,196,64** (was 255,196,72) | GearBar `gold` |
| Ink (text on gold) | 32,22,10 | GearBar `ink` |
| Danger (can't afford flash) | 230,80,96 | GearBar `danger` |
| Roll again | fill 255,205,90, text 24,18,32 | RollSummaryHud |
| Close | fill 58,52,80, text 240,236,250 | RollSummaryHud |
| Skip (x10) | fill 20,24,32, text 244,240,252 | UiTheme body/text |
| Milestone toast | fill 255,206,96 @0.05, text 24,18,12 | MenuHub |
| Badges NEW / ★ up / Salvaged | 120,220,140 / 255,205,90 / 230,120,110; ink 24,18,32 | RollSummaryHud |
| Pity meter + cracks | cyan ~170,235,255 → 255,255,255 | **OPEN** proposal |
| Inactive pip | ~40% brightness | – |

Rarity colors (**RESOLVED**): read `Rarities.rgb` (`Shared/Rarities.luau` on cursor/live-build-9721). Never hardcode.
| Tier | RGB | Odds (Config/Rarities oneIn) |
|---|---|---|
| Common | 168,168,176 | 1 in 2 (remainder) |
| Uncommon | 64,186,98 | 1 in 4 |
| Rare | 72,142,255 | 1 in 15 |
| Epic | 186,96,240 | 1 in 100 |
| Legendary | 255,196,64 | 1 in 1,000 |
Note: Legendary equals chrome gold 255,196,64. To tell them apart, Legendary FX use glow + sparks, not just the trim color.
Mythic (**RESOLVED**): out of scope until Phase 5. Code keeps red 230,64,78; see Appendix A.

## 4. UI elements & states
- **Currency pill** (top right): shard icon + amount, `+` opens shop. On insufficient funds the amount flashes `danger`.
- **Tabs ×4** (Weapons, Armor, Pets, Skills): active (button fill + border) / inactive / locked (padlock, disabled). One row, no sideways scroll; labels shorten when narrow (pack rule). Disabled while rolling.
- **Tier pip strip ×5** (gray, green, blue, purple, gold) with labels 1/2, 1/4, 1/15, 1/100, 1/1K: idle all medium; they light in sequence while charging; on the result only the result tier is lit.
- **Odds "i"** → odds modal (tier, %, 1-in-N, Close). Popup style: corner 12, padding 14/12, gold stroke @0.5 thickness 1.
- **Hero crystal + pedestal**: idle bob / charging / burst / hidden.
- **Pity meter** (Legendary only, `Rarities.PITY`): arc "112/150". The soft zone from roll 101 brightens the arc, and at 150 Legendary is guaranteed and the arc pulses. Pity cracks fill = pity %. No Epic pity in V1.
- **Luck chip**: hidden at x1.0. Corner 8 (chip style).
- **Result banner** "1 in N", tier-colored border. Single roll only, never over the x10 reel.
- **ROLL button**: button fill, gold trim, ROLL + cost. States: idle / pressed / rolling (buttonDim) / can't afford (buttonDim + shake).
- **x1 / x10 toggle**, **Auto / Skip setting toggles** (Settings rows).
- **Legendary milestone**: the cross-server announcement uses the **Milestone toast** (220×26, top-center, 4 px inset, corner 13, size 14).
- **x10 summary grid**: see §2b. Tiles: corner 8, fill = rarity mixed 22% into 40,34,58, border rarity color thickness 2, BuilderSansBold; badges corner 4, height 16, text 10.

## 4b. Type, radius, padding (adopted from pack)
- Font: `BuilderSansBold` for buttons, titles and names; `BuilderSans` for body; `BuilderSansExtraBold` for pills/warnings. The ROLL word uses ExtraBold.
- Text size: minimum `UiTheme.MIN_TEXT` 14 (badges 10 are the pack's exception); buttons 15–16; popup title 18.
- Radius: `UiTheme.CORNER` 10 default; buttons/chips/Skip/Roll again/Close 8; popups 12; tiles 8; pills = height/2.
- Padding: `UiTheme.PAD` 8 list gaps; button padding 10/0; popup 14/12.

## 5. Touch sizes
- Floor: `UiTheme.TOUCH` 44.
- ROLL: ≥ 55% width, ≥ 96 px tall (720w ref), bottom thumb zone, ≥ 24 px safe-area margin.
- x1/x10, Auto/Skip toggles: ≥ 88×56, 8 px gap.
- Tabs: 4 equal, ≥ 120×72, 6 px gap.
- "i", "+": visual 36, hit box ≥ 56.
- x10 `SkipBatch` (**APPROVED**, Ghost): at least **88×44** visible on phones (any viewport whose short side is ≤ 500 px, including 390×844, 667×375 and 800×400), text 15 BuilderSansBold, corner 8, 12 px from the safe-area edge. Desktop may keep 72×30 visible but needs a hit box of at least 88×44.
- x10 grid tiles: on a 390 px wide phone, 5 columns with a 6 px gap give tiles of about 64×64, which clears the 44 floor.
- Result/skip tap area: full screen (single roll).

## 6. Open items
RESOLVED: tier list (5, incl. Uncommon); rarity colors + odds from config; Mythic color (Phase 5); x10 flow.
RESOLVED in v1.2: tier-scaled timings (Kevin approved; Ghost adding per-tier duration in RollReveal, 6378886198); x10 5×2 grid and best-tile highlight; Skip ≥ 44 tall on phones.
OPEN: 1. Where the roll page lives (Ghost to confirm; spec doesn't depend on it). 2. Cyan pity color. 3. Re-check once the MISSING.md screenshots land.

## Appendix A: Phase 5 reserved (Mythic / Secret) — do not build in V1
Mythic (~3.5 s): 1.0 s Hollow drain (screen → grayscale, void swirl, rainbow leaks from cracks) → 0.25 s near-white flash + shatter → 2.25 s burst + reveal. Color TBD in Phase 5 (code red 230,64,78; prismatic proposal). Secret: white, drawn as a moving rainbow (`Rarities.RAINBOW`). Mockups 06–08 apply here. In V1 these ids fold into Legendary.


## Decision log
- 2026-10-23: Ghost (6379856660) approved Skip ≥ 44 tall on phones, the 5×2 x10 grid and the best-tile highlight.
- 2026-10-23: Kevin approved tier-scaled reveal timings (Common <0.6s, Uncommon ~0.7s, Rare ~0.9s, Epic ~1.3s, Legendary ~2.2s). Needs per-tier duration in RollReveal (Ghost).
