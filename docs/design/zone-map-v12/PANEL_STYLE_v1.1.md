# Shared Panel Style v1.1: Prompt (Z8) + Dialog (Z11) components folded in (NOT APPROVED, docs only)

Owner: Prism (design, docs only). Builder: Ghost (`PanelChrome`, `HudShell` prompt, new `DialogHud`; all Ghost-owned, Prism edits none). Base: `cursor/live-build-9721` @ **`908b1f3`**. Date: Oct 24, 2026 (PT).
Asked for in: DP63P https://app.notion.com/p/403c31ca3883814b8d94eeba82410845 (item 1, "PANEL_STYLE dialog + prompt components"). ACK: https://app.notion.com/p/403c31ca388381739823f77864ade274. Source spec: `prism/prompt-dialog` @ `a6e7964` (DP61P Q8-Q14 decided by Ghost; Kevin can veto 12 and 14). Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on PANEL_STYLE v1 (`docs/design/ui-overhaul/PANEL_STYLE.md`, `prism/ui-overhaul` @ `242ed14`); v1 §1-§11 stand. This adds two components to v1 §5 and one shared shell. Sheet: `mockups/04-panel-style-prompt-dialog-sheet.svg`.

## 1. Goal
The prompt, the dialog and (next) the results card are built from the same parts as the panels, so PanelChrome visual QA checks one set of tokens and nothing on the HUD looks like a debug frame.

## 2. Where it lives
| Component | Zone (HUD_ZONE_MAP v1.2) | Live @ 908b1f3 | Builder |
|---|---|---|---|
| Prompt | Z8 (#487 rects) | flat `panel` Frame, 8 corner, one 14 px label, purple buttons (HudShell.luau:476-520) | `HudShell` prompt + `HudLayout.promptButtons` |
| Dialog: Defeated | Z11 | `CombatHud` Result card, centered (0.38, 0.45), title `230,80,96` (CombatHud.luau:472-533, :946-961) | new `DialogHud` (Q11) |
| Dialog: Confirm | Z11 + backdrop | 4 different salvage confirms (InventoryHud, GearBar, BagTools, MenuHub) | `DialogHud.confirm` |
| Dialog shell (shared) | Z11, Z13 | — | one helper next to `PanelChrome` (Q1) |

## 3. Flow
Prompt: shows under the loot toast, Equip/Keep, replace-in-place queue, waits while a panel/Z11/Z13 is up. Defeated: no backdrop, Continue or the drain timer closes it. Confirm: backdrop, Cancel focused, Esc / B / backdrop tap = Cancel, action shows "Salvaging…" until the server answers, result line goes to the panel status strip. (Full flow: `prompt-dialog/SPEC.md` §3.)

## 4. Layout (component anatomy)
**Prompt (88 tall, width from the zone):** label row 36 (accent 5, icon tile 28 at x 12 on wide, name at x 48, right: queue "1/2" + bolt + delta) · button row 44 at y 36 (`promptButtons`: 88×44 at x 8/104; under `PROMPT_MIN_W` 68×44 at x 8/84) · 8 bottom pad · rarity badge 24 at x 206 when w ≥ 300. Compact (< 200): name 14 truncated "…", delta right, no icon/badge.
**Dialog (184 tall max, bottom pinned):** padding 16 (12 phone) · row 1: icon tile 44 + title (26 / 20; confirm 22 / 16) + optional counter right · body max 2 lines (16 / 14) · buttons pinned to the bottom, 48 / 44 tall: Defeated one full-width Continue; confirm Cancel + action, half width each, gap 10 · Defeated: 4 px drain bar on the bottom edge.
**Shared shell:** Frame + `UICorner` 16 (14 phone) + `UIStroke` 2 + `UIGradient` Rotation 90 `36,40,52 → 26,30,40` + optional top tint Frame (`UIGradient` Transparency 0.84 → 1). The Z13 results card (`prism/run-results`) uses this shell with a gold stroke.

## 5. States + tokens
| Component | State | Look |
|---|---|---|
| Prompt | idle | `UIStroke` 1.5 `Rarities.COLOR[r]`, label-row `UIGradient` rarity @ 0.78 → 1, Equip = PANEL_STYLE equip, Keep = secondary |
| Prompt | queued | "1/2" in the label row, crossfade 0.1 s |
| Prompt | pressed / focus | `UIScale` 0.96 / gold `UIStroke` 3 on Equip (E / ButtonA = Equip, Q / ButtonB = Keep) |
| Dialog | Defeated (decided Q12, Kevin can veto) | stroke 2 `230,80,96` @ 0.15, top tint danger @ 0.84, skull tile, title **`255,150,150`**, Continue primary, drain bar `255,150,150` over `dismissIn` |
| Dialog | Confirm (decided Q14, Kevin can veto) | stroke 2 `255,206,96` @ 0.4, warn tile, backdrop `8,10,16` @ 0.45, **Cancel focused** (secondary), action danger on the right for destructive, primary otherwise |
| Dialog | busy | both buttons disabled (PANEL_STYLE disabled tokens), action label "Salvaging…" |
| Dialog | results (Z13) | stroke 2 gold @ 0.35, top tint gold @ 0.86, see `prism/run-results` |
Tokens are PANEL_STYLE v1 §5-§7 (button kinds, disabled `166,160,186` on `54,46,78`), `Rarities.COLOR` for the 5 V1 tiers (Common `168,168,176`, Uncommon `64,186,98`, Rare `72,142,255`, Epic `186,96,240` with text lifted to `206,150,240`, Legendary `255,196,64`).

## 6. Copy + type
Prompt name 16 / 14 bold in rarity text color; delta 16 / 14 `ok 120,210,150`. Dialog title 26 / 20, confirm title 22 / 16, body 16 / 14, buttons 18 / 16. Minimum 14 everywhere; `TextScaled` off. Copy strings: `prompt-dialog/SPEC.md` §6.

## 7. Visual style
No blur, no drop shadows. Depth = stroke + gradient + the top tint. Icon tiles: `UICorner` 10, `UIStroke` 1.5-2, `UIGradient` Rotation 160 color @ 0.45 → 0.88.

## 8. Motion
Prompt in: +8 px → 0 and `GroupTransparency` 1 → 0, 0.15 s Quart Out; out 0.12 s. Dialog in: `UIScale` 0.94 → 1 + fade 0.12 s; out 0.1 s; backdrop 1 → 0.55 in 0.12 s; drain `Size.X` 1 → 0 linear over `dismissIn`. All `TweenService`.

## 9. Roblox build notes
- Prompt: `Frame` + `UICorner 12` + `UIStroke` + accent `Frame` + label-row `Frame` with `UIGradient` + `ImageLabel` icon + `TextLabel` name (`TextTruncate.AtEnd`) + delta `TextLabel` + 2 `TextButton`s from `promptButtons`. Payload gets `rarity`, `delta`, `icon` (Q10); text stays the fallback.
- Dialog: one `DialogHud` `ScreenGui` (`CoreUISafeInsets`), `CanvasGroup` root for the fade, rect from `HudLayout.zone("Z11")`, `AutomaticSize.Y` capped by `UISizeConstraint` (184). `GuiService.SelectedObject` = Continue / Cancel.
- Shell helper (Q1): `PanelChrome.shell(frame, { stroke = "gold" | "danger", tint = Color3?, phone = bool })` sets corner, stroke, gradient and tint, so panels, dialogs and the results card can't drift apart.
- Prism edits no Ghost-owned file (GearBar, MenuHub, InventoryHud, HudLayout, OnboardHud, RollReveal). This is the build brief.

## 10. Mobile checks
| Viewport | Prompt | Dialog |
|---|---|---|
| 1920×1080 | 420×88, buttons 88×44 | 420×184, buttons 48 |
| 390×844 | 160×88, buttons 68×44 | 294×184, buttons 44, half width 131 |
| 667×375 / 800×400 / 844×390 | 332 / 386 / 408 × 88 | 270 / 328 / 348 × 184, buttons 44 (half width ≥ 118) |
Every tappable piece ≥ 44 tall; text ≥ 14; contrast: dialog title `255,150,150` on `36,40,52` ≈ 7:1, body `244,240,252` ≈ 13:1.

## 11. Open questions (answer by number)
1. **@Ghost:** one shell helper beside `PanelChrome` for panels, Z11 dialogs and the Z13 results card, so PanelChrome QA covers all three in one pass? Prism recommends **yes**.

## Decision log
- Oct 24, 2026: v1 (DP41P) on `prism/ui-overhaul`.
- Oct 24, 2026: v1.1 (Prism, DP63P): prompt + dialog components folded from `prism/prompt-dialog` (DP61P Q8-Q14 decided by Ghost). Still NOT APPROVED until copied into Vision & Design Rules.
