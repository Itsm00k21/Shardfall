# Bag "Salvage…" Flow + Shard Core Panel: Spec v1


> **Mockup images:** the GitHub connector can only commit text, so the image files named in §8 aren't in this commit yet. They'll be added to this folder (or attached to the PR) in a follow-up.

Owner: Prism (design). Builders: Ghost (UI), Echo (server). Base: `cursor/live-build-9721` @ `49bd902`.
The spec follows the live code; it doesn't invent new systems.

| System | Files |
|---|---|
| Salvage server | `Shared/GearSalvage.luau`, `ShardfallServer/GearSalvageService.luau` (#388 rules) |
| Salvage UI | `ShardfallClient/GearBar.luau` (Ghost), `Shared/GearHooks.luau` |
| Essence | `Shared/Config/Essence.luau` |
| Shard Core | `Shared/Config/ShardCore.luau`, `src/server/ShardCore/*`, `ShardfallClient/ShardCore/{Mount,View}.luau`, the `GearDetail` Shard Core card |

Flags: `LaunchGate.gearSalvage` and `LaunchGate.shardCore` stay **off** until Kevin flips them.
Chrome comes from PR #392 STYLE.md. Nothing here costs Robux.

## 1. Goal
The player turns gear they don't need into Essence in two taps, safely (favorite, locked and equipped gear can never be lost), and spends that Essence to level the Shard Core of a weapon they love.

## 2. Where it lives
- **Salvage…**
  - A button in the Bag's action bar (`GearRow`) on the Weapons and Armor tabs only.
  - It opens the **BulkPicker** popup, anchored bottom-center over the lower half of the Bag and never over screen center on phones.
  - Collapse: the popup's grab bar or Cancel. The Bag stays open.
- **Auto-salvage:**
  - The `Auto: Off/On` pill in the same bar opens the **AutoPopover**.
  - This is the only place the setting changes.
- **Select mode:** `Select` turns on multi-select in the grid and shows the `SalvageBar` ("Salvage N for +X Essence" · Clear).
- **Shard Core:**
  - A card inside the item **detail** panel (weapons only; pets have no core).
  - Desktop and landscape: the detail panel sits right of the grid. Portrait phone: the detail opens after the grid, and Back returns to it.
  - Collapse: the card header chevron folds it to one line, "Shard Core  Lv 2/5 · Essence 128".
- The Bag window itself collapses to its tab bar (chevron at top-left) so the character stays visible (Kevin's rule).

## 3. Flow
### A. Salvage… (bulk)
1. Bag → Weapons or Armor → tap **Salvage…**.
2. BulkPicker opens. Each row asks the server for a `preview` one at a time. Until the reply arrives, the row shows the client estimate (`GearHooks.bulkEstimate`) in muted text.
3. Tap a row with a count above 0 (danger fill). The server `preview {rarity}` returns a **token** (valid for 20 s, `TOKEN_SECONDS`) plus the count, gain and `skipped`.
4. **SalvageConfirm** opens: "Salvage N for +X Essence? This cannot be undone." Below it: "Locked, favorite and equipped gear stays."
5. **Confirm** sends `confirm {token}`. The server deletes only the uids in that token. Toast: "Salvaged N for X Essence." Essence ticks up and the grid repaints.
6. **Cancel** at any step closes the popup and changes nothing.
### B. Salvage selected
1. Tap **Select**. Cards get checkboxes. Equipped, locked and favorite cards are greyed and can't be picked, and they show the reason chip (`GearHooks`: Equipped / Locked / Favorite).
2. The `SalvageBar` updates: "Salvage N for +X Essence". With nothing picked: "Select items to salvage".
3. Tap it → `salvage {uids}` returns a token → the same SalvageConfirm → Confirm.
4. **Clear** unselects everything. Tapping Select again exits select mode.
### C. Auto-salvage
1. Tap the `Auto: Off` pill → AutoPopover.
2. Pick a cap: **Common** or **Uncommon** only (`GearHooks.AUTO_SAFE`).
3. Tapping **Off → On**, or raising the cap, shows the **AutoAsk** tray: "Auto-salvage will destroy new {cap} and lower drops. Turn on?" with **Turn on** / **Cancel**.
4. With it on, the pill reads "⚠ Auto-salvage ON: {cap}s and below" with a warn stroke. Only new drops are converted, never items already in the Bag. Roll results show "Auto-salvaged +N Essence".
### D. Shard Core
1. Open a weapon's detail → Shard Core card (`GetShardCore`).
2. It shows the level pips (0–5), the Essence balance, 5 perk rows (unlocked = check, locked = "Lv N  text" + padlock), and a status line.
3. Tap **Feed N Essence** → `FeedShardCore`. The level goes up, the newly unlocked perk row flashes gold 0.4 s, Essence goes down, and the stat lines update.
4. Back or the chevron returns or collapses.

## 4. Layout
Reference sizes are in pt (390×844 portrait phone).
| Piece | Phone portrait 390×844 | Phone landscape 667×375 / 800×400 | Desktop |
|---|---|---|---|
| Bag window | full width −16, top under HP card | `InventoryLayout.modal`, right of rail | max 1180×680, centered right of rail |
| GearRow | h 48 (`BAR_H`), controls h 44 (phone; the live code has `CONTROL_H` 36, see Q1) | h 48 | h 48, controls 36 |
| Salvage… button | 96×44, rightmost | 96×44 | auto×36 |
| BulkPicker / Confirm / AutoPopover | anchor (0.5,1), width min(360, W−24), bottom inset 12+safe | anchor (1,1) right half, width 340 | anchor (0.5,0.5) of the Bag, width 340/360/320 |
| Popup rows | h 56 (2 lines), gap 8 | h 52 | h 52 |
| Shard Core card | detail page, full width −24 | detail column `detailW` | detail column |
| Feed button | (1,−24) × **44** | ×44 | ×44 (live 36, see Q2) |
| Level pips | 5 × 20 px, gap 8 | same | same |
Safe areas: obey the GUI inset and keep 12 px from the notch and home bar. No popup covers the screen center band (0.35–0.65 h) on phones in portrait; it sits in the bottom half.

## 5. States
| State | Salvage | Shard Core |
|---|---|---|
| Empty | picker row "0 items", dim, not tappable. Hint from `GearHooks` (e.g. "No unlocked, unequipped Commons in Weapons.") | "No weapon to feed." (no weapons) |
| Loading | row text muted "Checking…" until the preview returns. Confirm shows a spinner and is disabled | Feed disabled, "…" |
| Normal | mockups 01–04 | mockup 05 |
| Full (bag full) | the Roll tab's "Salvage now (N for +X Essence)" nudge, live, opens the same confirm | n/a |
| Error | toast with the server text ("That item is a favorite.", "That is closed.", "Could not salvage that.") and nothing deleted | status shows the server text |
| Locked | flag off: the panel shows "That is closed." and the buttons are disabled | flag off: card hidden |
| Disabled | Rare+ auto cap: the dropdown has no Rare; a saved Rare+ cap shows clamped with one plain line (live behavior) | capped: "That core is at its cap." and Feed dim. Short: "Not enough Essence." and Feed dim |

## 6. Numbers
- **Essence per salvaged piece** (`Config/Essence.AMOUNT`): Common 1 · Uncommon 3 · Rare 10 · Epic 40 · Legendary 200. Wallet `profile.gearEssence`, cap 1,000,000,000.
- **Shard Core** (`Config/ShardCore`):
  - Cap 5. Cost to the next level: 5, 15, 40, 100, 250 (410 total).
  - Perks are cumulative and flat on top of totals, and only the equipped weapon counts:

    | Lv | Perk |
    |---|---|
    | 1 | +1% crit chance |
    | 2 | +2% shard find |
    | 3 | +2% move speed |
    | 4 | +5% crit damage |
    | 5 | +1 luck |
- **Token:** 20 s. Rate limit: 4 burst, 1/s.
- **Colors:**
  - Panel 28,24,40 · text 240,236,248 · muted 176,168,198 · gold 255,196,64 (Essence text) · button 108,78,196 (Feed, Select, Salvage…, Cancel in the picker).
  - buttonDim 54,46,78 (0-count rows, Cancel in confirm) · danger 230,80,96 (rows with count > 0, Confirm, Turn on) · AutoAsk tray 60,34,30 · warn stroke 255,168,48 · ok 110,210,140 (perk check).
- **Corners and spacing:** buttons 8 · popups 12 (gold stroke at 0.5 transparency, thickness 1) · card 10 · pill 18. Padding: popup 14/12 · AutoAsk 10/8. Gaps: PAD 8, ask list 6.
- **Fonts and sizes:** BuilderSansBold for buttons and titles (popover title 18) · BuilderSans for body, 14 · help 13 · confirm body 15 · Auto pill BuilderSansExtraBold.
- **Timings:** popup open 0.15 s fade+slide 12 px · Essence count-up 0.4 s · perk unlock flash 0.4 s · toast 2.5 s.
- **Exact text** (live strings):
  - Buttons and titles: "Salvage…" · "Salvage gear · Essence N" · "Cancel" · "Confirm" · "Select" · "Clear" · "Turn on" · "Auto-salvage" · "Shard Core  Lv N/5" · "Feed N Essence" · "Essence N".
  - Picker help: "Weapons and Armor in your Bag. Locked, favorite and equipped gear is never salvaged."
  - Picker rows: "Salvage all Common" · "Salvage all Uncommon and below" · "Salvage all Rare and below".
  - Confirm: "Salvage N for +X Essence? This cannot be undone."
  - AutoPopover help: "Destroys new drops at or below the cap for Essence. Gear you already own is not touched."
  - AutoAsk: "Auto-salvage will destroy new {cap} and lower drops. Turn on?"
  - Shard Core status: "Next level: N Essence" · "Not enough Essence." · "That core is at its cap."

## 7. Edge cases
- **Double-tap Confirm:** the button disables on the first tap. The token is single-use, so a second send deletes nothing.
- **Token expired (more than 20 s on the confirm):** the server refuses. The UI re-previews automatically and shows the new count ("Count changed: N"), and the player confirms again.
- **The player favorites or locks an item between preview and confirm:** the server returns "That item is a favorite." / locked, nothing is deleted, and the UI re-previews.
- **Equipped piece selected:** it can't be picked (greyed). The server also refuses with "Unequip it before salvaging."
- **Bag full on roll:** the Roll-tab nudge "Salvage now" uses `nudge` then `salvageNow {token}`, and the same confirm copy applies.
- **Server refuses or flag off:** "That is closed." Nothing changes.
- **Fast Feed taps:** one request in flight. The button is disabled until the reply. Rate limit replies show "Slow down."
- **First time:** the first Salvage… open shows a one-line tip above the rows: "Favorite (♥) or lock gear to keep it safe." It's dismissible and shown once.
- **Essence at cap:** salvage still deletes, and the gain is clamped. The confirm notes "Essence is full" when gain = 0 (see Q3).

## 8. Mockups
Each image carries a label strip at the top.
| File | State |
|---|---|
| `01-bag-normal-phone.jpg` | Bag normal, action bar with Salvage… (phone portrait) |
| `02-salvage-picker-phone.jpg` | BulkPicker with preview counts |
| `03-salvage-confirm-phone.jpg` | SalvageConfirm after picking or selecting |
| `04-auto-salvage-ask-phone.jpg` | AutoPopover + AutoAsk (cap Common/Uncommon) |
| `05-shard-core-phone.jpg` | Shard Core card Lv 2/5, can feed |
| `06-bag-shard-core-desktop.jpg` | Desktop Bag + detail + Shard Core, character visible |
AI-drawn art notes:
- Item names, icons and star counts in the mockups are placeholders.
- Card proportions in 01 are taller than the live square cells. Build to `cellH = cellW`.
- The Essence icon should be the shard glyph, not a coin.

## 9. Build split
- **Ghost (UI; GearBar, GearDetail, InventoryHud, MenuHub are Ghost-owned):**
  - Controls and Feed at 44 on phones.
  - Popups anchored in the bottom half on portrait.
  - Collapse chevrons on the Bag and the Shard Core card.
  - Auto re-preview on token expiry.
  - Perk unlock flash and the first-time tip.
- **Echo (server):**
  - No new APIs. Keep `preview`, `salvage`, `confirm`, `nudge`, `salvageNow`, `auto`, `GetShardCore` and `FeedShardCore` as they are.
  - Optional: return `expired = true` on a stale token so the UI can re-preview without guessing.

## 10. Pass criteria (playtest)
1. With a favorited, a locked and an equipped Common in the Bag, "Salvage all Common" then Confirm leaves all three, and Essence rises by exactly 1 per other Common.
2. Auto-salvage can't go above Uncommon, and turning it on always asks first.
3. Waiting more than 20 s on the confirm and then pressing Confirm deletes nothing unexpected (it re-previews).
4. Feeding a Lv 2 core with 128 Essence costs 40, unlocks "+2% move speed", and the stat line shows it.
5. At 390×844, every button in these flows is at least 44 px tall, and no popup covers the screen center.

## 11. Open questions
1. @Ghost: should GearRow controls go from 36 to 44 on phones (Kevin's ≥44 rule)? (yes/no)
2. @Ghost: should the Shard Core Feed button go from 36 to 44? (yes/no)
3. @Echo: at the Essence cap, should salvage still delete when the gain is 0, or refuse? (pick)
4. @Kevin: is the first-time "Favorite or lock to keep it safe" tip OK? (yes/no)
5. @Echo: can a stale token return `expired = true`? (yes/no)

## Later (not V1)
- Pet cores (none in V1).
- Armor cores.
- Undo for salvage.
- A "Salvage duplicates only" picker row.
- Per-perk choice (V1 perks are fixed by level).
- Respec or refund of core Essence.
- Salvaging materials.
