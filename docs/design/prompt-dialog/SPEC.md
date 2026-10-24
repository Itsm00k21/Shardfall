# Z8 Equip/Keep prompt + Z11 Defeated/confirm dialog v1 on PANEL_STYLE (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost (`HudShell` prompt, `HudLayout.equipPrompt`/`promptButtons`, `CombatHud` result card, `OnboardHud`, `GearBar`/`InventoryHud`/`BagTools`/`MenuHub` salvage confirms are Ghost-owned; Prism edits none of them). Base: `cursor/live-build-9721` @ **`9c42ce6`**; prompt geometry read from #487 @ **`10ab718`** (Havoc SHIP, DP60), measured in lune with `HudLayout.equipPrompt` + `promptButtons`. Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP61P https://app.notion.com/p/403c31ca388381f5a797fa0c556761e7 (item 2, "note P2-487-1: intro card must yield to the prompt"). ACK: https://app.notion.com/p/403c31ca388381998cbacb298c1de245. Havoc's #487 verdict: https://app.notion.com/p/403c31ca3883817ea6c5f3a133d5b84d. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Zones and style: HUD_ZONE_MAP (Z8, Z11, `RAIL_SAFE`, DisplayOrder ladder) + PANEL_STYLE (buttons, type, contrast) on `prism/ui-overhaul`; toast look from `prism/toast-lane`. Mockups: `mockups/01`–`07` (PNG renders embedded in `.svg`, same as earlier Prism branches, since this push path carries text only).

## 1. Goal
Two small pieces that show up at the worst moments (a drop mid-fight, a death, a destructive tap) should look like the rest of the game and never hide behind something else. The Equip/Keep prompt says **what** dropped and **how much better** it is, with two real 44 px buttons at every size, and the tutorial card steps aside while it's up (P2-487-1). Defeated and confirm share one dialog in Z11: readable, off the rail, one clear action.

## 2. Where it lives + live audit
| What players get today | Evidence | Change here |
|---|---|---|
| Prompt = flat `panel` Frame, 8 corner, one 14 px label (`promptText`, 28 tall) + Equip/Keep in `button` purple, both 14 px | HudShell.luau:476-520 (`DisplayOrder 90` :483) | PANEL_STYLE look: rarity stroke + accent, icon, name in rarity color, power delta, Equip = equip blue, Keep = secondary (§7) |
| #487 rects (lune, `equipPrompt(vx,16,vy)`): 1920×1080 x 750-1170, y 212-300 · 390×844 x 98-258 (160 wide) · 667×375 x 111-443, hotbar from 451 · 800×400 x 190-576, bar 584 · 844×390 x 212-620, bar 628. Height 88 = label 36 + 44 + 8 | HudLayout.luau:242-264 @ 10ab718 | **Keep these rects.** The design fits inside them; no new layout math |
| Buttons: 88×44 at x 8 / 104; under `PROMPT_MIN_W` (390×844, 160 wide) both 68×44 side by side | HudLayout.luau:266-276 @ 10ab718 | Same sizes; compact label (§4) |
| **P2-487-1:** during onboarding at 390×844 the intro card (Onboard `DisplayOrder 95`) covers the whole prompt 160×84 incl. Equip/Keep (prompt 90). It's allow-listed in `HudOverlap.spec` | Havoc DP60; OnboardHud.luau:200; `coverWhen` OnboardHud.luau:508-512, callers init.client.luau:1596-1614 | `OnboardHud.coverWhen("prompt", prompt.Visible)`: card folds to its tab while the prompt is up; drop `introCard × equipPrompt` from the allow-list (keep `toastHost × introCard`) |
| Defeated = `CombatHud` "Result" card, `AnchorPoint 0.5` at scale (0.38, 0.45), 340 wide: at 390 wide it spans x −22..318 over the rail; title 22 in `230,80,96` (4.2:1 on the card), body 15, "Continue" 44 at 15 px, auto-hides after `dismissIn` (default 6 s) | CombatHud.luau:474-533, :655-672, :946-961; HUD_ZONE_MAP seed 4 | Z11 rect at every size, title lifted to `255,150,150`, body 16/14, Continue 48/44, drain bar shows the auto-hide |
| Four different salvage confirms: InventoryHud centered 340 `Confirm` frame, GearBar `SalvageConfirm` panel 360, BagTools `Confirm salvage` button, MenuHub inline "Confirm salvage" row | InventoryHud.luau:524-567, :872-880; GearBar.luau:404-406, :887; BagTools/init.luau:165; MenuHub.luau:4332-4333 | One Z11 confirm component, modal, panel stays open behind |

## 3. Flow
**Z8 prompt**
1. An item drop that beats what you wear calls `hudShell.prompt(text, uid)` → `ToastQueue.pushPrompt` (HudShell.luau:811-825). The loot toast goes to Z6 above; the prompt appears under it (slide 8 px + fade 0.15 s).
2. If onboarding is on screen, the intro card and goals fold to their Z4 tab **in the same frame** (`coverWhen("prompt")` + `setCovered` recheck, like the roll fix in #487). Mockup 02.
3. **Equip** equips (same remote as the bag) → success toast "Sunfang Greatsword equipped". **Keep** dismisses. If another prompt is queued, the label shows "1/2" and the next one slides in.
4. When no prompt is left, the intro card unfolds back (0.2 s). It doesn't advance the tutorial by itself.
5. A panel opening hides Z8 (HUD_ZONE_MAP §3: "Z8 waits"); the prompt comes back when the panel collapses.
**Z11 dialog**
1. **Defeated**: the server sends `kind = "defeat"` → collapse any open panel, hide Z9 (and Z10 on phones), show the dialog. **Continue** or the `dismissIn` timer closes it. No backdrop: the world stays visible.
2. **Confirm** (salvage, later any destructive or costly action): opened from a panel or the hotbar. Backdrop dims everything (allowed pair "Confirm dialog + its backdrop"). The panel behind **stays open** (Q4). **Cancel** has focus; Esc / B / tapping the backdrop = Cancel. The action button is danger red for destructive actions, primary otherwise. Result goes to the panel status strip.

## 4. Layout
**Z8 prompt (inside the #487 `equipPrompt` rect, 88 tall)**
| Piece | Wide (≥ 300: 1920, 667, 800, 844) | Compact (< 200: 390×844 = 160) |
|---|---|---|
| Label row y 0-36 | accent 5 · icon tile 28 at x 12, y 4 · name 16 bold rarity text at x 48 · right: queue "1/2" 14 muted + bolt 14 + delta 16 `ok` | accent 5 · name 14 bold, truncated "…" at x 12 · delta 14 right (x −8) |
| Buttons y 36-80 | Equip 88×44 at x 8, Keep 88×44 at x 104 (`promptButtons`) · rarity badge 24 at x 206 if w ≥ 300 | Equip 68×44 at x 8, Keep 68×44 at x 84 |
| Rect per size | 1920 x 750-1170 · 667 x 111-443 (8 px left of the hotbar at 451) · 800 x 190-576 · 844 x 212-620; all y 212-300 | 390 x 98-258, y 212-300 |
HUD_ZONE_MAP §4 listed target Z8 rects (e.g. 390: x 16-258, y 172-248). #487's rects already clear the hotbar, toasts and Goals tab and passed Havoc's audit, so this spec adopts them (Q1); Prism updates the zone map table when Ghost agrees.
**Z11 dialog (HUD_ZONE_MAP Z11; height 184 when the body is 2 lines, growing up from the same bottom edge)**
| Viewport | Rect | Padding / title / body / buttons |
|---|---|---|
| 1920×1080 | x 750-1170, y 772-956 (zone map 796-956 at 160) | 16 / 26 (confirm 22) / 16 / 48 |
| 390×844 | x 80-374, y 596-780 (Z10 hidden; clear of `RAIL_SAFE` x 0-72, y 250-594) | 12 / 20 (16) / 14 / 44 |
| 667×375 | x 76-436, y 176-360 | 12 / 20 / 14 / 44 |
| 800×400 | x 76-436, y 196-380 | same |
| 844×390 | x 76-436, y 190-374 | same |
Anatomy: icon tile 44 (skull for Defeated, warn for confirm) + title on one row; body under it (max 2 lines); buttons pinned to the bottom (Defeated: one full-width **Continue**; confirm: **Cancel** + action, each half width, gap 10); Defeated has a 4 px drain bar on the bottom edge + "4 s" counter top-right.

## 5. States
| Piece | State | Look |
|---|---|---|
| Z8 | idle | rarity stroke 1.5 + accent; label tint `UIGradient` rarity @ 0.78 → transparent |
| Z8 | queued (2+) | "1/2" in the label row; next prompt replaces in place (no stacking) |
| Z8 | pressed | `UIScale` 0.96, fill −15% (PANEL_STYLE) |
| Z8 | gamepad / keyboard | Equip has focus: gold `UIStroke` 3 outline; E / ButtonA = Equip, Q / ButtonB = Keep |
| Z8 | intro card up (onboarding) | card + goals fold to the Z4 tab "Step 2/6" while Z8 is visible; unfold after |
| Z8 | panel open | hidden, waits in `ToastQueue` |
| Z11 Defeated | showing | danger stroke 2 `230,80,96` @ 0.15, top tint, title `255,150,150`, drain bar `255,150,150` |
| Z11 confirm | showing | gold panel stroke, backdrop `8,10,16` @ 0.45, Cancel focused |
| Z11 confirm | action pressed | buttons disabled + "Salvaging…" on the action until the server answers; then close + status strip line |

## 6. Copy
Z8: item name (from the drop) · "+56" (power delta vs worn) · "1/2" · "Equip" · "Keep". Toast after equip: "Sunfang Greatsword equipped". Z11 Defeated: title "Defeated" · body = `payload.text` (server copy, unchanged; mockup sample "The Brute Den boss got you. Your loot is safe.") · "Continue" · "4 s". Z11 confirm (salvage): title "Salvage 12 pieces?" · body "+340 Essence. Locked, favorite and equipped gear stays. This can't be undone." (phone: "+340 Essence. Locked and equipped gear stays. Can't be undone.") · "Cancel" · "Salvage 12". Numbers come from the existing confirm strings (GearBar.luau:748, :887).

## 7. Visual style
| Piece | UICorner | UIStroke | Fill / UIGradient | Text |
|---|---|---|---|---|
| Z8 frame | 12 | 1.5 `Rarities.COLOR[r]` | `20,24,32` @ 0.05; label row `UIGradient` rarity @ 0.78 → 1 | name 16/14 Builder Sans Bold in `UiTheme.RARITY` (Epic lifted `206,150,240`), delta `ok 120,210,150` |
| Z8 accent | — | — | `Frame` 5 wide, rarity color | — |
| Z8 icon tile | 10 | 1.5 rarity | Rotation 160 rarity @ 0.45 → 0.88 | — |
| Equip / Keep | 10 | equip / secondary (PANEL_STYLE §5) | equip `52,104,192 → 32,76,156` / secondary `52,58,72 → 40,46,58` | 16 (14 compact) |
| Z11 dialog | 16 (14 phone) | Defeated 2 `230,80,96` @ 0.15 · confirm 2 `255,206,96` @ 0.4 | Rotation 90 `36,40,52 → 26,30,40`; Defeated top tint `230,80,96` @ 0.84 → 1 | title 26/20 bold, body 16/14 `244,240,252` / `222,218,234` |
| Continue / Cancel / Salvage | 10 | per kind | primary purple / secondary / danger `188,58,68 → 160,40,50` | 18/16 |
| Backdrop | — | — | `Frame` `8,10,16` @ 0.45 | — |
Colors only from `Rarities.COLOR` (Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240`, Legendary `255,196,64`) and PANEL_STYLE tokens. No blur, no drop shadows.

## 8. Motion
Z8 in: `Position` +8 px → 0 and `GroupTransparency` 1 → 0, 0.15 s Quart Out; out 0.12 s. Replace (queued): crossfade 0.1 s. Intro card fold/unfold: the existing Z4 fold tween (0.2 s `Size`). Z11 in: `UIScale` 0.94 → 1 + fade, 0.12 s (HUD_ZONE_MAP §8); out 0.1 s. Drain bar: `Size.X` 1 → 0 linear over `dismissIn`. Backdrop: `BackgroundTransparency` 1 → 0.55 in 0.12 s. Legendary prompts get no extra beat (the toast lane and the drop already carry it). All `TweenService`, no `RenderStepped`.

## 9. Roblox build notes
- **P2-487-1 fix (Ghost):** in init (where the other `coverWhen` calls live, init.client.luau:1596-1614) add `OnboardHud.coverWhen("prompt", function() return hudShell.promptVisible() end)` (or read `ShardfallPrompt.Prompt.Visible`), and call `OnboardHud.setCovered("prompt", …)` from `paintNotices()` so the card hides the same frame the prompt shows (same trick as `setCovered("roll")` in #487). Then remove `introCard × equipPrompt` from `HudOverlap.spec`'s allow-list; keep `toastHost × introCard`.
- Z8 stays in `ShardfallPrompt` (`DisplayOrder 90`, `CoreUISafeInsets`). Build: `Frame` + `UICorner 12` + `UIStroke` + accent `Frame` + label-row `Frame` with `UIGradient` + `ImageLabel` icon (item icon or `UiIcons`) + name `TextLabel` (`TextTruncate.AtEnd`) + delta `TextLabel` + two `TextButton`s placed by `HudLayout.promptButtons(w)`. Read rarity / power delta from the prompt payload (add `rarity`, `delta`, `icon` fields to `ToastQueue.pushPrompt`'s prompt; text stays the fallback).
- Z11 = one new `DialogHud` (Ghost-owned) on its own `ScreenGui`: Defeated at `DisplayOrder 92`, confirm + backdrop at `105` (HUD_ZONE_MAP §9 ladder). `CombatHud`'s Result card keeps victory/results and hands `kind = "defeat"` to the dialog. The four salvage confirms call `DialogHud.confirm({ title, body, action, danger = true }, onYes)`.
- Rects from `HudLayout.zone("Z11", vx, vy)`: anchor bottom-left, `AutomaticSize.Y` capped at 184 (`UISizeConstraint`). Never `AnchorPoint 0.5` on a scale position.
- Text: never below 14; `TextScaled` off; body `TextWrapped`, 2 lines max (`MaxVisibleGraphemes` not needed).
- Gamepad: `GuiService.SelectedObject` = Equip (Z8) / Cancel (confirm) / Continue (Defeated).
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Check | Result |
|---|---|---|
| 1920×1080 | Z8 750-1170 × 212-300, above the keep-out (y 302); Z11 above the action bar (964) | pass (mockups 01, 04) |
| 390×844 | Z8 160 wide, Equip/Keep 68×44 inside the frame; intro card folded while up; Z11 x 80-374 clear of `RAIL_SAFE`; buttons 44 | pass (mockups 02, 05) |
| 667×375 | Z8 x 111-443 ends 8 px before the hotbar (451); 88×44; Z11 x 76-436 | pass (mockups 03, 06) |
| 800×400 / 844×390 | Z8 ends at 576 / 620 vs bar 584 / 628 | pass (mockups 03, 06) |
| Touch | every tappable piece ≥ 44 tall; compact buttons 68 wide | pass |
Finding for Havoc: in his #487 probe the 390×844 `goalsTab` is **112×36** (36 < `MIN_TOUCH_PX` 44). It's the tab the intro card folds into here, so it should be 44 tall (Q6).

## 11. Open questions (answer by number)
1. **@Ghost:** adopt #487's `equipPrompt` rects as the official Z8 (instead of HUD_ZONE_MAP's older targets) and design inside them? Prism recommends **yes**. They're audited and clear the hotbar at every size.
2. **@Ghost:** fix P2-487-1 with `coverWhen("prompt")` + a `setCovered` recheck from `paintNotices`, and drop `introCard × equipPrompt` from the allow-list? Prism recommends **yes**. Equip/Keep is the step the tutorial is asking for, so it must be visible.
3. **@Ghost:** add `rarity`, `delta` and `icon` to the prompt payload so the prompt can show what dropped and how much better it is? Prism recommends **yes**. Client-only, no remote change.
4. **@Ghost:** one Z11 `DialogHud` for Defeated + every confirm, with the panel staying open behind a confirm (modal backdrop), replacing the four salvage confirms? Prism recommends **yes**.
5. **@Kevin (taste):** Defeated look: skull tile, title in soft red `255,150,150`, a drain bar that shows the auto-close (6 s default)? Prism recommends **yes**. The live red title is 4.2:1, below the 4.5 floor.
6. **@Ghost / @Havoc:** make the 390×844 Goals/intro tab 44 tall (it measures 112×36 in the #487 probe)? Prism recommends **yes**. 44 is the touch floor.
7. **@Kevin (taste):** confirm buttons: Cancel focused by default, destructive action in danger red on the right? Prism recommends **yes**. A misclick costs nothing.

## Decision log
- Oct 24, 2026: v1 written for DP61P item 2 (Prism). Nothing decided yet.
