# Shop + Settings pass v1 on PANEL_STYLE (layout only; NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`MenuHub` shop and settings pages are Ghost-owned; Prism edits neither). Base: `cursor/live-build-9721` @ **`9c42ce6`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP56P https://app.notion.com/p/403c31ca38838112a4abff69093e8583 (next item 3). ACK: https://app.notion.com/p/403c31ca388381ddb081f1fa425ac293. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
**Scope guard:** layout only. Same two Gold offers, same prices, same caps, no new items, no Robux, no Shard Pass changes (the `pass` page is untouched). Builds on `PANEL_STYLE.md` + `HUD_ZONE_MAP.md` (`prism/ui-overhaul`, #479) and the Bag spec (#483). Mockups: `mockups/01`–`04`.

## 1. Goal
Shop and Settings open in the same Z12 rect as every other panel and use the same parts. **Shop:** you see the price, what you already have, and why a button is off, in one glance; buying is one tap and the answer lands in the status strip. **Settings:** real controls (toggles, segmented choices, sliders with − / + steppers) instead of tap-to-cycle text rows, grouped by the 9 existing sections, saved as you change them, and honest about the settings that don't do anything yet.

## 2. Where it lives + live audit (`9c42ce6`)
| What players get today | Evidence | Change here |
|---|---|---|
| Shop = purse banner "Gold  12480" + an optional note line + a 2-card grid; BUY reads "40 Gold" on a gold button 44 tall | MenuHub.luau:6975-6996 (purse), :7006-7083 (offers, `buy.Text = "%d Gold"`, `TOUCH` height), `hubFn.buyOffer` :6922 | Header gold pill, offer cards on PANEL_STYLE, BUY + price split, "what you have" column, status strip |
| Offers are data: Healing Tonic 40 Gold, Bag slot 250 Gold; tonic cap 20, bag bonus cap 500; errors "You need more Gold." / "You cannot carry more tonics." / "Your bag cannot grow more." | GoldShop.luau:22-25, :55-103; Materials.luau:213-217 (`TONIC_CAP = 20`, heal 0.4) | Same data. Errors become **disabled button labels** before you tap ("Need 210 more", "Full · 20 / 20") and the sentence goes to the status strip |
| No paid path in the shop | GoldShop.luau:1-8 ("never reads a product id") | Copy "Gold only · nothing here costs Robux" |
| Settings = 9 section headers (Graphics, Rolls, Camera, Audio, HUD, Hotkeys, Controls, Social, Access) with `cycle()` rows ("Graphics  auto", "Hide HUD  Off") | MenuHub.luau:7265-7273, :7309 `cycle`, rows :7343-7600 | Section list (desktop/landscape) or pill tabs (phone) + per-type controls |
| Saves on every change | MenuHub.luau:2459-2463 (`hubFn.save` → `SetSettings`) | Keep. Subtitle "Saves as you change it", status strip "Saved." |
| **10 settings are saved but nothing reads them** (search by field name outside Settings.luau / MenuHub.luau): `rolls.skipAt`, `rolls.autoConfirm`, `camera.sensitivity`, `graphics.fpsCap`, `hud.damageNumbers`, `hud.otherVfx`, `hud.nameplates`, `controls.mobileScale`, `access.colorblind`, `access.holdToTap` | Settings.luau:88-112 defaults; `rg` finds no reader in src/ @ 9c42ce6 | Rows show a **SOON** locked state (PANEL_STYLE "Locked: never a blank or silent button") until wired; Q1 |
| `rolls.skipAt` options include `mythic` | Settings.luau:76 | V1 shows 5 tiers; Mythic option hidden (stays valid in data) |

## 3. Flow
**Shop:** rail Shop → Z12. Tap **BUY** → button press state (0.08 s) → server reply → status strip "Bought Healing Tonic. You carry 13 / 20." + the "what you have" row counts up + header gold ticks down. Disabled buttons explain themselves; tapping one repeats the reason in the status strip (no error toast, no banner). Panel open = Z6 lines go to the status strip (HUD_ZONE_MAP Q5).
**Settings:** rail Settings → Z12 on the last section used (default Graphics). Change a control → it applies at once → `SetSettings` → status strip "Saved." (1.5 s). **Reset {section}** asks once inline ("Reset Rolls to defaults?" Yes / No in the status strip), never a modal over the rail.

## 4. Layout (safe-area px)
| Viewport | Shop | Settings |
|---|---|---|
| 1920×1080 | Z12 1440×816. Header 64 with gold pill 200×44 + collapse 44. Offer cards 510×300 ×2 from (20,112), gap 16; "What you have" card x 1080-1420, y 112-412; button-state row below (y 464) is mockup-only; status strip y 752 | Header 64 with **Reset {section}** 170×44. Section list x 20-260, rows 52 + gap 6 (9 rows = 516). Body x 280-1420: section title 22 + subtitle, rows 72 tall (gap 12), control right-aligned 14 in |
| 390×844 | Z12 310×700. Header 56: gold pill 118×44 + collapse. Offer cards 286×200 stacked (gap 12). Status strip at the panel bottom | Header 56. Section pills (scroll) 44 tall at y 64. Toggle rows 72; segmented rows 114 (label + help, then the control); slider rows 96 (label, then − track + value) |
| 667×375 | — | Section list 150 wide (rows 44) + rows 50 tall; toggles right-aligned |
| 800×400 | Header 52; two offer cards side by side (w−32)/2; status strip | — |
Controls: **toggle** 64×36 track inside a 64×44 hit area, On/Off text left of it; **segmented** buttons 44 tall, min 64 wide, gap 6; **slider** = − 44 · track (6 tall, knob 22) · + 44 · value 64 right-aligned; **dropdown** not used (fewer than 6 options everywhere).

## 5. States
Shop BUY: ready (gold kind, price left of the button) · pressed · waiting (label "…", 0.3 s max before the reply) · bought (status strip ok) · can't afford (disabled, "Need N more") · at cap (disabled, "Full · 20 / 20" / "Bag is at max") · panel note (`shopNote`) shown in the status strip, not as a floating line.
Settings rows: idle · changed (status strip "Saved.") · **SOON** (control at 0.35 opacity + lock chip "SOON", not interactive, `Active = false` on the control) · disabled by another setting (e.g. Junk below while Junk = Keep: dimmed with the reason as help text).

## 6. Copy
Shop header "SHOP", subtitle "Gold only · nothing here costs Robux" (phone "Gold only"). Offer lines: "Healing Tonic · Heals 40% of your HP. Use it from the action bar." "Bag slot · +1 bag slot, kept forever." Have-lines "You carry 12 / 20", "Bag 34 / 60 slots". Footer "Prices are Gold. Buying never opens a Robux prompt."
Settings: "SETTINGS · Saves as you change it". Row labels drop the two-space value suffix ("Graphics  auto" → label "Graphics quality" + segmented Auto/Low/Med/High). Renames: "Skip cutscene at" → **"Cutscene from"** with options **Every roll / Rare / Epic / Legendary** (help: "Rolls under this tier skip straight to the result"; `off` = Every roll). "Junk" → Ask / Keep / Salvage; "Below" → **"Junk below"**. "Colorblind pips" help "Adds shapes to rarity colours". "Text size" help "Never below 14 px".

## 7. Visual style (Roblox values)
PANEL_STYLE: panel slate + gold stroke, header `42,48,60`, rows = card `26,30,40` + `UIStroke` 1 `divider` @ 0.6, `UICorner` 12. Offer cards: purple tint (`button 108,78,196` @ 0.84 → `26,30,40`), never a rarity colour (offers aren't loot). Gold pill: `gold` @ 0.9 fill + 2 px gold stroke + coin icon. BUY = PANEL_STYLE **Gold** button (ink text 12.6:1). Toggle on = `claim 28,110,70`-ish `34,122,78` + `ok` stroke; off = `buttonDim 54,46,78`. Segmented selected = `button` fill + gold 2 px stroke (same as tabs). Slider fill `gold`, track `buttonDim`. SOON chip `40,40,52` + `muted` @ 0.6 stroke + lock glyph 14 + text `166,160,186`.

## 8. Motion
Panel open/collapse per PANEL_STYLE §8. Toggle knob `Position` 0.12 s Quad Out + track colour 0.12 s. Segmented selection 0.1 s. Slider knob follows the finger (no tween); −/+ step 0.08 s. BUY: press `UIScale` 0.96; on success the have-row value counts up 0.3 s and the header gold counts down 0.3 s. Status strip text crossfade 0.1 s. All `TweenService`.

## 9. Roblox build notes
- Both pages via the shared `PanelChrome` builder (PANEL_STYLE §9) in the Z12 rect (`HudLayout.zone("Z12", vx, vy)`); they stop using the hub scroll page + `hubFn.hexify` look.
- Shop: offers from `GoldShop.offers()` (no hard-coded list), `UIGridLayout` (2 cols desktop/landscape, 1 col phone). Disabled state computed client-side from the same rules as `GoldShop.apply` (gold < price, tonic ≥ `Materials.TONIC_CAP`, bonus ≥ `BAG_BONUS_CAP`); the server stays the authority.
- Settings: section list = `ScrollingFrame` + `UIListLayout` (desktop/landscape) or horizontal pill `ScrollingFrame` (phone). Each row = `Frame` with label/help `TextLabel`s + a control module: `Toggle` (`TextButton` 64×44 + track `Frame` + knob `Frame`, `UICorner` (1,0)), `Segmented` (`UIListLayout` Horizontal of `TextButton`s), `Slider` (`TextButton` − / + and a track `Frame` with `InputBegan/Changed` drag; step 0.1 for 0-1 values, 1 for FOV 50-90, 10% for scales).
- Row data table drives everything: `{ section, key, kind, options/min/max/step, label, help, wired }`. `wired = false` renders SOON; flipping it to true when a reader lands is the only change needed.
- Keep `hubFn.save()` → `SetSettings` per change (debounce 0.3 s for slider drags).
- Touch: every control ≥ 44 (toggle hit area, segment buttons, − / +, section rows 52/44, pills 44). Text ≥ 14.
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Mockup | Checks |
|---|---|---|
| 1920×1080 | `01-shop-desktop-1920x1080.svg`, `02-settings-desktop-1920x1080.svg` | same Z12 rect; BUY 48; section rows 52; controls 44 |
| 390×844 | `03-shop-settings-phone-390x844.svg` (Shop · Shop states · Audio · Camera) | panel right of `RAIL_SAFE`; offers 286 wide; sliders with − / + 44; SOON row readable at 14 px |
| 667×375 / 800×400 | `04-shop-settings-landscape.svg` (Settings HUD 667 · Shop 800) | rows 50 with 44 controls; two offers fit at 800×400 |

## 11. Open questions (answer by number)
1. **@Ghost:** show the 10 unread settings as **SOON** (locked, visible) rather than hiding them or leaving dead toggles? Prism recommends **SOON** until each one has a reader; then flip `wired`.
2. **@Kevin:** rename "Skip cutscene at" → **"Cutscene from: Every roll / Rare / Epic / Legendary"** and hide Mythic in V1? Prism recommends **yes**.
3. **@Ghost:** desktop/landscape Settings with a **left section list**, phones with pill tabs? Prism recommends **yes** (9 sections don't fit one pill row on desktop without scrolling either).
4. **@Ghost:** Shop "What you have" column (Gold, tonics, bag slots) on desktop; phones show the have-line on each card only? Prism recommends **yes**.
5. **@Ghost:** disabled BUY shows the reason as its label ("Need 210 more", "Full · 20 / 20") instead of failing after the tap? Prism recommends **yes**.
