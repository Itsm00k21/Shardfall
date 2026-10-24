# Toast lane kinds v1: one Z6 lane for loot, rare+, errors, room banners and other players' Legendaries (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builder: Ghost (`HudShell`, `HudLayout`, `Ui`, `RollReel` client paths; Prism edits none of them). Base: `cursor/live-build-9721` @ **`9c42ce6`**. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP56P https://app.notion.com/p/403c31ca38838112a4abff69093e8583 (next item 1, "reward feel first"). ACK: https://app.notion.com/p/403c31ca388381ddb081f1fa425ac293. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on: `docs/design/ui-overhaul/HUD_ZONE_MAP.md` (Z6 lane rects, Z8 prompt, `RAIL_SAFE`, v1.1 run state) and `PANEL_STYLE.md` §5 toasts + status strip on `prism/ui-overhaul` (#479). Fixes Havoc's **P2-472-1** (board row https://app.notion.com/p/403c31ca3883819e8c5eca079e79c27b): other players' announces must stop writing into your status banner. Mockups: `mockups/01`–`04`.

## 1. Goal
Every "something happened" line has one home: the **Z6 toast lane**. Your loot feels like a reward (rarity colour, icon, ×N merge, Legendary rays), errors read as errors, room banners stop being a yellow full-width bar, and other players' Legendary pulls appear as a social moment in **their own track** of the lane. They never overwrite your status line, never bury your own drops, and never print raw `**` asterisks.

## 2. Where it lives + live audit (`9c42ce6`)
| What players get today | Evidence | Change here |
|---|---|---|
| Toast is a bare `TextLabel`, 14 px, no icon or kind | HudShell.luau:454-474 (`TextSize = UiTheme.MIN_TEXT`, `UICorner` 8) | Card = `Frame` + accent + icon + text (§7, §9) |
| 3 cards × 36 px, 420 wide, top-centre | `HudLayout.toast` HudLayout.luau:132-158, `toastHost` :161-167, `ToastQueue.MAX = 3` ToastQueue.luau:14 | Z6 rects from HUD_ZONE_MAP §4 (480×40 desktop, 242/224×40 phones, max 2 on phones) |
| Life is 3 s, hard-coded | HudShell.luau:800 and :816 `task.delay(3, …)` | Per-kind life (§5); 3.5 s default = `ShellLayout.BANNER_SECONDS` (ShellLayout.luau:31) |
| Loot goes to **both** the gold banner and a toast, with a "Loot:" prefix | init.client.luau:1643-1648 (`onHint` → `ui.setStatus` + `hudShell.toast`) | Loot is a toast only; "Loot:" stays a parse prefix, never shown |
| Errors go to **both** a toast and the red banner | init.client.luau:1483-1488 | Error toast only (panel open → panel status strip) |
| Room banners are the gold full-width banner | `Ui.luau:320` `showBanner`, HUD_ZONE_MAP §2 seed 7 | Room banner = a toast kind |
| **Other players' announces overwrite your status banner** and show literal `**` (P2-472-1) | RollReel.luau:993-999 (`RollAnnounce` → `hooks.setStatus(payload.text, "ok")`) | World track in Z6 (§3), separate labels / RichText `<font>` (§9) |
| Server side already queues and paces | `Config/BigRoll.luau:17-31`: `MIN_TIER = "Epic"`, `QUEUE = 3`, `GAP = 1`, `BEAM_HOLD` Epic 2.5 / Legendary 3.5, `PLAYER_GAP = 8` | Client track reuses these numbers; no new tunables |

## 3. Flow
1. **Your drop / room / error** → `ToastQueue.pushToast` with a kind → card slides into the **top** of Z6 (newest on top). Same loot item within 1.5 s merges into ×N on the existing card (life restarts).
2. **Rare+ drop** that also asks Equip / Keep → toast card + the Z8 prompt 8 px under the lane (as today). The prompt text never duplicates as a second toast when the prompt is already showing.
3. **Another player's Epic/Legendary** (`RollAnnounce`) → client **world queue** (max 3, 1 s gap) → shows in the **world slot = bottom slot of Z6**, max 1 at a time.
4. **Your cards beat theirs.** If your cards fill the lane, the world card yields (fades 0.2 s) and waits in its queue. Lines older than 20 s are dropped and counted into one "+N more Legendaries" card (also fixes the 72 s-late lines in P3-472-3 on the client side).
5. **Held states:** while a Z12 panel is open, during a Shard Crater run (Z7 run band up), or on the Defeated dialog, the world track is held. Your own lines go to the panel status strip (HUD_ZONE_MAP Q5) or keep using Z6 in a run (v1.1 rects).
6. Nothing from Z6 ever calls `Ui.setStatus`. The status banner stays for nothing on the HUD (panels use their status strip).

## 4. Layout (safe-area px, from HUD_ZONE_MAP §4 + v1.1)
| Viewport | Z6 lane | Max cards | World slot | Z8 prompt |
|---|---|---|---|---|
| 1920×1080 | x 720-1200, y 76-212 (480×40, gap 8) | 3 | card 3, y 172-212 | x 720-1200, y 220-300 |
| 390×844 | x 16-258, y 80-168 (242×40) | 2 | card 2, y 128-168 | x 16-258, y 172-248 |
| 390×844 boss bar up (v1.1 Q2) | x 16-258, y 124-212 | 2 | held | x 16-258, y 216-292 |
| 667×375 | x 76-300, y 80-168 (224×40) | 2 | card 2 | x 76-300, y 172-248 |
| 800×400 / 844×390 | x 76-300, y 80-168 (224×40) | 2 | card 2 | x 76-300, y 172-248 |
Card anatomy (mockup 01): 5 px accent bar (left, full height) · lead 28 px (26 phone) icon tile / glyph 22 / avatar 26 at x 12 · text from x 50 · right slot (×N, NEW chip, rarity chip) 10 px from the right · 2 px life bar along the bottom, inset 10. At heights under 400 px the rail gap drops to 6 so 6 × 44 still clears the bottom edge (844×390: rail y 80-374).

## 5. States (kinds)
| Kind | Look | Life | Merge / cap | Sound |
|---|---|---|---|---|
| Loot (Common/Uncommon) | stroke `divider` @ 0.3, accent + name in rarity colour, icon tile | 3.5 s | same item in 1.5 s → ×N | soft tick (existing UI sfx) |
| Rare+ (Rare/Epic/Legendary) | 2 px rarity stroke, rarity tint gradient, gold **NEW** chip on first find. Epic: one gradient sweep 0.6 s. Legendary: static rays behind the icon + sweep (no rotation, per Bag Q3) | 3.5 s; Legendary 4 s and pinned on top until it fades | never merges | existing rare / big-roll sting |
| Error | `loss 220,92,96` accent + stroke, warn glyph, white text | 4 s | identical text within 2 s doesn't repeat | error blip |
| Room banner | gold accent, door glyph, gold caps "ROOT HALL · ROOM 2/5" (phones "ROOT HALL 2/5") | 2.5 s | replaces the previous room card | none |
| Success | `ok` accent + check ("Bag slot added. 35 / 61 slots.") | 2.5 s | — | UI click |
| World: Legendary | fill `64,48,110` → slate, rarity stroke, player headshot 26 + globe badge, "{player} pulled {item}" + LEGENDARY chip (phones "{player} · {item}") | 3.5 s (`BEAM_HOLD.Legendary`) | max 1 visible, queue 3, 1 s gap | silent (the beam already plays one) |
| World: Legendary + Epics | "{player} pulled {item} and N Epics" (fixes P3-472-2's unnamed first Legendary) | 3.5 s | one line per x10 | silent |
| World: Epic fold | Epic stroke, "{player} pulled N Epics" + EPIC chip | 2.5 s (`BEAM_HOLD.Epic`) | folds per player | silent |
| World: burst | dashed `150,120,240` stroke, muted "+N more Legendaries this minute" | 2.5 s | replaces dropped lines (> 20 s old or queue full) | silent |
Lane states: empty · 1-3 cards (2 on phones) · full (world yields) · held (panel / run / dialog) · routed (panel open: your lines → panel status strip).

## 6. Copy
Loot: item name only, "×N" right; no "Loot:" prefix. Rare+: item name + NEW. Error: one short sentence, ≤ 30 chars on phones ("Best gear is already on." instead of "Your best gear is already equipped."). Room: "ROOM NAME · ROOM n/N" (phones drop the middle word). World: "Kev_99 pulled Dawnbloom Wolf" (player name truncates at 12 chars first, then the item with "…"). No exclamation marks, no asterisks, no "★" glyph inside the text (the chip carries the tier).

## 7. Visual style (Roblox values)
Card fill `20,24,32` @ 0.06 transparency; `UICorner` 10; `UIStroke` 1.5 (2 for Rare+); accent `Frame` 5 px; text Builder Sans Bold 16 desktop / 14 phones (`UiTheme.MIN_TEXT`, never `TextScaled`); colours from `UiTheme.RARITY` for text (Epic lifted to `206,150,240`, PANEL_STYLE §5) and `Rarities.COLOR` for strokes/fills. Legendary rays = one `ImageLabel` (the Bag detail ray asset), static, `ImageTransparency` 0.6. No blur, no drop shadow, no `UIGradient` animation except the one-shot sweep.

## 8. Motion
In: 0.15 s, `Position` +8 px → 0 and `GroupTransparency` 1 → 0 (`CanvasGroup` per card, or tween each child). Hold: life bar `Size` X 1 → 0, Linear, over the kind's life. Out: 0.2 s fade + 8 px up; cards below slide up 0.15 s. Epic/Legendary sweep: `UIGradient.Offset` −1 → 1 in 0.6 s, once. World yield: 0.2 s fade, re-enter later from the bottom. All `TweenService` with `UiTheme.MOTION` values; no `RenderStepped`.

## 9. Roblox build notes
- `ToastQueue` stays the model; add a `kind` field to `Toast` and a separate `world` list (max 1 shown, queue 3). `pushToast(state, text)` keeps working as kind `"info"` so nothing breaks while callers move over.
- Card = `Frame` (`ClipsDescendants`) + `UICorner` 10 + `UIStroke` + accent `Frame` + lead (`ImageLabel` item icon in a rarity tile / glyph `ImageLabel` / headshot via `Players:GetUserThumbnailAsync(userId, HeadShot, Size48x48)`) + `TextLabel` (`TextTruncate.AtEnd`) + optional chip `TextLabel` (`AutomaticSize.X`) + life bar `Frame` 2 px.
- **World text:** either two `TextLabel`s in a horizontal `UIListLayout` (player white, item in rarity colour) or one `TextLabel` with `RichText = true` and `<font color="#FFC448">item</font>` built from **structured fields** (`player`, `item`, `rarity`, `epics`) instead of `payload.text`. Escape `<>&` (BigRollBeam's `clean()` already strips `<>`). Either way, drop the `**` markers. The `RollAnnounce` payload needs those fields from the server (Echo/Ghost; until then parse the current text and strip `*`).
- Rects come from `HudLayout.zone("Z6", vx, vy)` (HUD_ZONE_MAP Q1). Phone max 2 = `TOAST_MAX` per HUD_ZONE_MAP §9.
- `RollReel.luau:997` stops calling `hooks.setStatus` for announces; init.client.luau:1644 and :1487 stop mirroring into `ui.setStatus`.
- DisplayOrder: toast 100 (HUD_ZONE_MAP §9 ladder). Every card is `Active = false` (display only; no touch target needed). The Z8 prompt buttons stay 44 tall.
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Mockup | Checks |
|---|---|---|
| 1920×1080 | `02-toast-lane-1920x1080.svg` | 3 cards + Z8 inside the top-centre band; clear of Z3/Z4 and the keep-out |
| 390×844 | `03-toast-lane-390x844-states.svg` (Epic + world + Z8 · room + error · boss bar) | 242 wide at 14 px; `RAIL_SAFE` clear; Z4 folds to its tab while Z6/Z8 are up (#465 Q4) |
| 667×375, 844×390, 800×400 | `04-toast-lane-landscape.svg` | 224 wide at 14 px, max 2; lane crosses the keep-out corner (HUD_ZONE_MAP Q6, accepted compromise) |
Text never below 14 px; the longest phone strings truncate with "…" instead of shrinking. Kinds sheet: `01-toast-kinds-sheet.svg`.

## 11. Open questions (answer by number)
1. **@Ghost:** world announces as the **bottom slot of Z6** (one lane, own track, yields to your cards) rather than a second lane elsewhere? Prism recommends **yes**. There's no free band for a second lane on phones (390 and 375-tall landscape top rows are full).
2. **@Ghost / Echo:** send `RollAnnounce` as structured fields (`player`, `userId`, `item`, `rarity`, `epics`) so the client builds the line and can show the headshot? Prism recommends **yes**. It removes the `**` problem at the source.
3. **@Kevin:** hold other players' announces during your own Shard Crater run and while a panel is open (they wait up to 20 s, then fold into "+N more")? Prism recommends **yes**. Your fight and your panel stay quiet.
4. **@Kevin:** world cards silent (the beam already plays a sound in the world)? Prism recommends **silent**.
5. **@Ghost:** life per kind (loot 3.5 s, Legendary 4 s, error 4 s, room/success 2.5 s) instead of the flat 3 s? Prism recommends **yes**.
6. **@Ghost:** keep Epic world lines at all (BigRoll `MIN_TIER = "Epic"`) or Legendary+ only in the lane? Prism recommends **keep Epic folds** (one line per player, 2.5 s); they stop at `EPIC_BURST`.
