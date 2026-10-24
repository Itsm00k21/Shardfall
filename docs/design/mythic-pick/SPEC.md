# Mythic 3-Card Chest Pick v1 on PANEL_STYLE, specced flag-off for V1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips, no Robux). Builder: Ghost (RollReel / InventoryHud / MenuHub are Ghost-owned; Prism edits none). Echo: one server gate (Q1). Base: `cursor/live-build-9721` @ **`908b1f3`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP63P https://app.notion.com/p/403c31ca3883814b8d94eeba82410845 (item 3, "Mythic 3-card chest pick on PANEL_STYLE"; "Mythic stays gated in V1 (extraTiers off), no Robux changes"). ACK: https://app.notion.com/p/403c31ca388381739823f77864ade274. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on: chest open-many (`prism/chest-open-many` @ `dcc17bd`, DP61P Q1 decided: chest results live in Bag Z12 › Chests), PANEL_STYLE v1 + v1.1 (`prism/zone-map-v12`), HUD_ZONE_MAP v1.2 (Z12). Mockups: `mockups/01`-`04`.

## 1. Goal
**V1 (flag off):** nobody sees a Mythic pick, and nobody is stuck. A Mythic chest someone already owns shows as locked with a plain reason, and a save that already has a pick waiting can still finish it. **Later (flag on):** opening a Mythic chest shows three real cards in the Bag panel (art, type, NEW or "becomes Dust"), you select one and press TAKE, then the existing Mythic reveal plays. Nothing sits on the hero.

## 2. Where it lives + live audit (@ 908b1f3)
| Live | Evidence | Change here |
|---|---|---|
| `MythicChoice` Frame, `AnchorPoint 0.5` at (0.5, **0.58**), **320×230**, three bare `TextButton`s (name only, Mythic red text, 16 px) on the RollReel gui (`DisplayOrder 40`) | RollReel.luau:451-482, :1135-1188 | cards inside Bag Z12 › Chests (DP61P Q1); retire `MythicChoice` |
| One tap = permanent pick (`ChooseChest` remote), no confirm | RollReel.luau:1239-1272; Remotes.luau:273-274; `ChestConfig.choose` ChestConfig.luau:854-882 | select, then TAKE (Q3) |
| Options carry `templateId, name, rarity, poolId` only | ChestConfig.luau:786-813 | client adds type (from `poolId` armory/pets) and owned/dupe from the bag; no server change |
| While a pick waits, every other chest open fails: "Choose a Mythic card first." | ChestConfig.luau:769-771 | pending pick always reachable, even flag-off (Q2) |
| **Flag leak:** `entriesFor` reads only `pool.public` / weight, never `LaunchGate.extraTiers`; 12 public Mythic entries have weight > 0 (lune probe of `Pools.forArea`: e.g. Bloomheart Bow 9, Grove Phoenix 6, The Last Color 18). `ChestConfig.chances` keeps Mythic at 0.2 / 1.5 / 8 % on Rare / Epic / Legendary chests | ChestConfig.luau:43-48, :269-327, :521-541; LaunchGate.luau:51 (`extraTiers = false`) | **Echo gate (Q1)**. Today only already-owned chests can open (`LaunchGate.chests = false`, LaunchGate.luau:26; ChestConfig.luau:370-373), so exposure is small but real |
| Mythic chest open is one at a time | ChestConfig.luau:779-781 | unchanged |

## 3. Flow
**Flag off (V1, `extraTiers = false`):**
1. Bag › Chests lists owned chests (open-many spec). A Mythic Chest row shows **locked**: lock tile, "×1 · opens when Mythic arrives", no Open button. Status strip on tap: "Mythic is not in V1 yet. Kept safe." The chest stays in the save (no delete, no conversion).
2. **Pending save exception:** if the profile already has `pendingChest` (a pick started before), the Chests tab opens straight onto the pick (flag-on flow below) with the line "Finish this pick to open other chests." Never strand a save.
3. With Q1 in, Rare/Epic/Legendary chests can't land Mythic, so no Mythic reveal plays in V1.
**Flag on (later):**
1. Tap **Open** on a Mythic Chest → the existing chest beat plays (`OPEN_SECONDS.Mythic` 4, skippable after 1 s) inside the Bag body, not on the hero.
2. Three cards deal in (0.08 s stagger). Title "MYTHIC CHEST · PICK 1 OF 3". TAKE is disabled: "SELECT A CARD".
3. Tap a card → gold stroke + check; the others dim to 0.7. TAKE turns gold: "TAKE BLOOMHEART BOW". Tap another card to switch.
4. **TAKE** → `ChooseChest(index)` → "Taking…" → the existing `playOne("Mythic", …)` reveal → result line in the status strip.
5. Collapsing the panel keeps the pick waiting (server already stores it); reopening Bag returns to it. Errors ("Pick one of the three cards.", remote errors) go to the status strip.

## 4. Layout (inside Z12, the Bag panel; nothing outside Z12)
| Viewport | Panel (Z12) | Cards | TAKE |
|---|---|---|---|
| 1920×1080 | x 112-1552, y 104-920 | 3 vertical cards 300×420, gap 20, left of a 460 "How it works" card; icon tile 140, name 22, type 14 caps, badges 24, owned line 16 | 940×52 under the cards |
| 390×844 | x 72-382, y 136-836 | 3 horizontal cards 286×130 stacked, gap 10; tile 72, name 18, type 14, badges 22 | 286×48 + status strip 44 |
| 667×375 | x 76-651, y 16-359 | 3 vertical cards 178×211 side by side, tile 64, name 16 (2 lines), type 14, badges 22 | 551×48 |
| 800×400 | x 76-784, y 16-384 | 3 × 222×236 | 684×48 |
| 844×390 | x 76-828, y 16-374 | 3 × 237×226 | 728×48 |
| Flag off (all sizes) | Chests tab list | Mythic row 64 tall, locked look (PANEL_STYLE "Locked") | none |
The panel covers Z1/Z3 on landscape (zone map v1 allowed pair) and hides Z4/Z8 like every panel. The hero is never under a Mythic card except where the Z12 panel already covers the screen.

## 5. States
| State | Look |
|---|---|
| Locked (flag off) | fill `40,40,52`, `UIStroke` 1 muted @ 0.4, lock glyph, text `166,160,186` (5.0:1), no Open |
| Pending exception | pick view + gold info line in the status strip |
| Dealing | cards pop `UIScale` 0.9 → 1, 0.08 s stagger; rays start |
| Idle | 3 cards full opacity; TAKE disabled (PANEL_STYLE disabled tokens) |
| Selected | gold `UIStroke` 3 + 24-32 px gold check; others `GroupTransparency` 0.3; TAKE gold |
| Taking | TAKE "Taking…", cards inactive until the remote answers |
| Owned dupe | line "Owned · becomes 5,000 Dust" (ChestConfig.DUST.Mythic 5000 + `DUST_MATERIAL` 1 Gnarl's Seed) |
| New | gold "NEW" tag + "first copy" |

## 6. Copy
"MYTHIC CHEST · PICK 1 OF 3" · "You keep the one you take. The other two go back in the chest." (phone: "You keep the one you take.") · type line "WEAPON · BOW" / "PET" · "MYTHIC" badge · "NEW" · "Verdant Armory · first copy" / "Owned · becomes 5,000 Dust" · "SELECT A CARD" / "TAKE BLOOMHEART BOW" / "Taking…" · flag off: "Mythic Chest", "×1 · opens when Mythic arrives", "Mythic is not in V1 yet. Kept safe." · pending: "Finish this pick to open other chests." No Robux, no "buy more", no key shop link.

## 7. Visual style
Card = PANEL_STYLE item card at the Mythic tier: `UICorner` 16 (14 phone), `UIStroke` 2 `Rarities.COLOR.Mythic 230,64,78` @ 0.15, fill `UIGradient` Mythic @ 0.82 → `26,30,40`. Icon tile `UICorner` 14, stroke 3 Mythic, Rotation 160 Mythic @ 0.45 → 0.88. Ray `ImageLabel` (the Legendary 8-ray asset tinted Mythic, Transparency 0.7). **Name text lifted to `255,128,138`** (6.9:1 on `26,30,40`; raw `230,64,78` is 4.1:1, under 4.5). Badge: Mythic pill, PANEL_STYLE badge rules. TAKE = PANEL_STYLE gold button (ink text 12.6:1). The 5 V1 tiers keep their `Rarities.COLOR` values in the Chests list (Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`). No blur, no shadows.

## 8. Motion / VFX
Rays: `Rotation` 0 → 360 over 8 s, looping while visible (selected card only after a pick: others stop). Deal: 0.18 s per card. Select: stroke tween 0.12 s, check pop `UIScale` 0 → 1.1 → 1. TAKE press 0.08 s. Reveal: existing `playOne` Mythic beat + `flashColor("Mythic")` (RollReel.luau:1120-1121), unchanged. Sparks on TAKE: 6 small `Frame`s tweened outward from the tile (a `ParticleEmitter` doesn't render in a `ScreenGui`); in the world, a Mythic red `ParticleEmitter` `Emit(20)` on the HumanoidRootPart when the reveal plays. All `TweenService`.

## 9. Roblox build notes
- Pick view = a child `Frame` of the Bag panel body (Chests tab) via `PanelChrome`; 3 card `TextButton`s (`AutoButtonColor = false`) + `UICorner` + `UIStroke` + `UIGradient` + ray `ImageLabel` + icon `ImageLabel` + `TextLabel`s; TAKE = PANEL_STYLE gold `TextButton`.
- Selection is client-only; only TAKE calls `hooks.invoke("ChooseChest", index)` (same remote, same rate limit `ChooseChest` 4 / 1 s, RateLimiter.luau:34). Keep the `choosing` guard.
- Gate the view on `LaunchGate.on("extraTiers")` **or** a non-nil `pendingChest` in the client snapshot. Flag off + no pending: Mythic row renders locked, no Open.
- Type line from `poolId` (`*_armory` → weapon class from the template, `*_pets` → "PET"); owned from the client inventory snapshot; dupe line from `ChestConfig.DUST.Mythic`.
- Retire `MythicChoice` (RollReel.luau:451-482) after this lands; `playOne` stays.
- **Echo (Q1):** in `entriesFor` (or `ChestConfig.chances`), skip `Mythic`/`Secret` while `extraTiers` is off and give that weight to Legendary, so the odds shown by `oddsLines` match. Server-only, no save-data change; owned Mythic items keep loading.
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Inside Z12 | Smallest tap | Text |
|---|---|---|---|
| 1920×1080 | yes | TAKE 52, cards 300×420 | ≥ 14 |
| 390×844 | yes, right of `RAIL_SAFE` | cards 286×130, TAKE 48, chevron 44 | names 18, type 14 |
| 667×375 | yes | cards 178×211, TAKE 48 | names 16 on up to 2 lines |
| 800×400 / 844×390 | yes | 222 / 237 wide cards | ≥ 14 |
Mockups: `01-mythic-pick-1920x1080.svg` (flag on, selected), `02-mythic-pick-390x844-idle-selected-flagoff.svg`, `03-mythic-pick-landscape-667x375-800x400-844x390.svg`, `04-mythic-live-vs-spec-1920x1080.svg` (live `MythicChoice` + the flag leak).

## 11. Open questions (answer by number)
1. **@Ghost → Echo (flag leak):** gate Mythic (and Secret) out of chest odds and `entriesFor` while `extraTiers` is off, giving the weight to Legendary? Prism recommends **yes, before chests come back on**. Today a Rare/Epic/Legendary chest someone owns can still roll Mythic (0.2 / 1.5 / 8 %), which breaks "5 tiers in V1".
2. **@Ghost:** flag off, show owned Mythic chests as locked ("opens when Mythic arrives") but always let a save that already has a pick waiting finish it (otherwise every chest open fails)? Prism recommends **yes**.
3. **@Kevin (taste):** pick with two taps (select a card, then TAKE) instead of today's one-tap permanent pick? Prism recommends **yes**. A misclick on a Mythic can't be undone.
4. **@Kevin (taste):** cards face-up with art, type and a NEW / "becomes 5,000 Dust" line, in the Mythic red frame with slow rays (no face-down gamble)? Prism recommends **yes**. It's a choice, not a second roll.
5. **@Ghost:** move the pick into Bag › Chests (Z12) like the open-many results and retire `MythicChoice`? Prism recommends **yes**.

## Decision log
- Oct 24, 2026: v1 written for DP63P item 3 (Prism). Specced flag-off for V1 (Mythic gated, no Robux). Nothing decided yet. NOT APPROVED.
