# First 30 Seconds Re-check vs HUD Zone Map v1.2 (390×844 first; 667×375, 800×400, desktop) (NOT APPROVED, docs only, report only)

Owner: Prism (design QA, docs only: no code, no Config, no flag flips). Fixes: Ghost (client UI), Echo (server, where noted). Base: `cursor/live-build-9721` @ **`a760a64`**. Rects measured by running live `HudLayout.onboard` / `toastHost` / `equipPrompt` / `characterZone` / `actionCluster` / `railFit` / `topRight` and `ActionSlots.placement` in lune at each size (touch = true on phones). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP67P https://app.notion.com/p/403c31ca3883816996fed5f9ecc6bf4b (item 2). ACK: https://app.notion.com/p/403c31ca388381999b28fa05219613c1. Checked against: `docs/design/zone-map-v12/HUD_ZONE_MAP_v1.2.md` (`prism/zone-map-v12`), `docs/design/first-30-seconds/SPEC_v1.md` (`prism/first-30-seconds`), DP61P Z8 spec (`prism/prompt-dialog`, P2-487-1).

## 1. Goal
Confirm the first 30 seconds still give a fast win on a 390×844 phone with the v1.2 zones: intro card, Z4 tab at 44 px, the Z8 cover rule (intro card yields to the Equip prompt, P2-487-1), and the first drop to Equip. List what breaks it, P0-P3, against live code.

## 2. Where it lives (what runs in the first 30 s at a760a64)
| Piece | Live | Evidence |
|---|---|---|
| Flow | **Cold open** (T3 guide is off): card steps open → (class skipped, `classes` off) → swing → dodge → door → haven. No free rolls, no Rare floor in the first 30 s | `LaunchGate.luau:29, :57`; `Onboarding.luau:21-30`; `OnboardingService.luau:96-110` |
| First gear | the **starter kit** (Rare 1-socket weapon + Uncommon armor + egg) is **auto-equipped server-side** when onboarding ends (Haven or Skip) | `OnboardingService.luau:89-93`; `FirstSessionKit.luau:257-264` |
| Loot during the cold open | "Loot: …" lines → `ui.setStatus` + `hudShell.toast` (Z6) | `init.client.luau:1662-1668` |
| Z8 Equip/Keep | `HudShell` builds it and exposes `prompt(text, uid)` (`HudShell.luau:811-829`), **but nothing calls it**: `init.client.luau` only calls `hudShell.toast` (:1405, :1488, :1513, :1574, :1666) | `rg "hudShell\.prompt"` = 0 hits on a760a64 (never wired since T-078's `pushPrompt`, `176f415`) |
| Intro card | `OnboardHud` `ScreenGui` **DisplayOrder 95** over HudShell 30 (toasts) and the prompt gui 90 | `OnboardHud.luau:197`; `HudShell.luau:62, :483` |
| Cover sources | inventory, hub, craft, travel, skills, raid, loop, dev, roll, results, market. **No "prompt" and no "toast"** | `init.client.luau:1602-1640` |

## 3. Flow re-check (390×844, beat by beat)
| t | Beat | Result | Issue |
|---|---|---|---|
| 0-1 s | Spawn, card "The sky cracked. Shards fell on the wilds." (Continue / Skip) | card x 88-374, y 176-296; clear of `characterZone` (y 337) and the rail | chevron 28×28 (**P2-30-3**) |
| 1-5 s | Skip (fast path) | kit equipped server-side; Rare weapon on the hero, **no toast, no reveal, no "✓ Equipped"** | **P2-30-5** |
| 1-30 s | Play the steps (swing saplings, loot) | "Loot: …" toasts (Z6 x 98-258, y 80-204) draw **under** the card for 160×28 px (y 176-204) | **P2-30-2** |
| any | First drop that beats your gear → Equip | **never shown** (Z8 unwired). Equip only via Bag → Equip best | **P1-30-1** |
| any | Goals tab | 112×**36** at x 262-374, y 304-340 (Q13 decided 44) | **P2-30-4** |
**Fast win verdict:** holds only through **Skip** (gear in < 5 s, but silent). Playing the cold open gives no gear moment and no Equip prompt in 30 s. The T3 guide (3 free rolls, Rare floor, `firstSessionGuide`) is what the first-30 spec counted on, and it is off.

## 4. Layout (live rects, safe-area px)
| Piece | 390×844 | 667×375 | 800×400 | 844×390 | 1920×1080 |
|---|---|---|---|---|---|
| Intro card | 88,176 286×120 | 68,88 217×120 | 68,88 276×112 | 68,88 295×120 | 180,836 340×120 (low lane) |
| Collapse chevron (in card) | 28×28 | 28×28 | 28×28 | 28×28 | 28×28 |
| Pill (folded card) | 280×36 | 217×36 | 276×36 | 280×36 | 280×36 |
| Goals tab | 262,304 112×36 | 539,128 112×36 | 672,128 112×36 | 716,128 112×36 | 1792,136 112×36 |
| Z6 toast host | 98,80 160×124 | 111,80 420×124 | 190,80 420×124 | 212,80 420×124 | 750,80 420×124 |
| Z8 prompt (unwired) | 98,212 160×88 | 111,212 332×88 | 190,212 386×88 | 212,212 408×88 | 750,212 420×88 |
| Card ∩ Z6 | **160×28** | **174×124** | **154×112** | **151×120** | none |
| Card ∩ Z8 | **160×84** (whole label + buttons) | none | none | none | none |
| Live rail (`railFit`) | **x 16-80, y 210-634** (64 px) | x 16-60, y 80-359 | x 16-60, y 80-384 | x 16-60, y 80-374 | x 16-80, y 328-752 |
| Action bar | 158,600 216×140 | 451,227 200×132 | 584,164 200×132 | 628,242 200×132 | 676,964 568×100 |
Desktop is clean (card in the low lane, clear of Z6, Z8, Z11, RAIL_SAFE, hero).

## 5. States + findings (P0-P3, report only)
| ID | Sev | Finding | Evidence (a760a64) | Fix (Ghost unless noted) |
|---|---|---|---|---|
| P1-30-1 | **P1** | Z8 Equip/Keep is never shown: `prompt()` has no caller, so "first drop → Equip" can't happen; all of #487/DP61P's Z8 work is invisible to players | `HudShell.luau:811-829`; `init.client.luau:1662-1668` (loot → toast only) | Call `hudShell.prompt(text, uid)` from the loot grant when `HubStyle.bestGear` says the new item beats the equipped one (one call site, same EquipItem remote `HudShell.luau:536-549`) |
| P2-30-2 | P2 | Intro card covers the toast lane on every phone size (160×28 at 390, 151-174 × 112-124 on landscape) and, once Z8 is wired, the whole Equip/Keep prompt at 390 (card 95 > prompt 90). Allowed today by the phone pair in UiAudit | `HudOverlap.spec.luau:119-121`; `OnboardHud.luau:197`; `HudShell.luau:483` | P2-487-1 as decided (DP61P Q9): `coverWhen("prompt")` + `coverWhen("toast")` on phones → card folds to the Z4 tab in the same frame; drop both pairs from the allow-list |
| P2-30-3 | P2 | Intro chevron is 28×28, under the 44 px touch rule | `OnboardHud.luau:303-304`; `HudLayout.luau:933-938` | 44×44 hit (`TextButton` 44, icon 16 centered); card heading width follows `layout.collapse.w` already (`OnboardHud.luau:439`) |
| P2-30-4 | P2 | Goals tab and intro pill are 36 tall (Q13 decided 44) | `HudLayout.luau:829, :838, :939` | `tabH = UiTheme.TOUCH`; at 800×400 move the tab to y 120-164 so it clears the bar (see party-ui Q6) |
| P2-30-5 | P2 | Skip/Haven gives the kit silently: no Z6 card, no reveal, so the fast win isn't felt | `FirstSessionKit.luau:257-264` (equip, no client event) | Echo: fire the existing loot hint for the kit ("Loot: Frostbite Edge"); Ghost: Z6 rarity card "✓ Equipped" (Rare blue 72,142,255 from `Rarities.COLOR`) |
| P3-30-6 | P3 | Zone map v1.2 RAIL_SAFE at 390 (x 0-72, y 250-594) doesn't match the live rail (64 px buttons, x 16-80, y 210-634) | `HudLayout.luau:434` (`railFit`) | Prism: v1.3 table uses the live rail: RAIL_SAFE x 0-88, y 202-642 at 390. Card (x 88) and Z15 still clear |
| P3-30-7 | P3 | With `firstSessionGuide` off, the first-30 spec's beats (3 free rolls, Rare at roll 3, Gate dock) don't run; the spec reads as live in older docs | `LaunchGate.luau:57` | Kevin/Ghost call (Q3) |
No P0: nothing blocks play, nothing sits on the hero, the rail is never covered.

## 6. Copy
Unchanged. New (P2-30-5): Z6 card "<weapon name> · ✓ Equipped" for the kit weapon (e.g. "Frostbite Edge"); Z4 tab while folded "Step n/6".

## 7. Visual style
Fix mockups use PANEL_STYLE v1.1 (card 30,26,44 + gold stroke, tab 20,24,32 @ 0.92 + gold stroke 1, 44 tall). Live rects are drawn from the lune numbers; red = overlap or under-44 target.

## 8. Motion
Card fold for a notice: the same 0.2 s `Size` tween as the goals fold, same frame as Z6/Z8 show; unfold 0.2 s after the last notice clears (toasts live 3 s, `HudShell.luau:803-808`).

## 9. Roblox build notes
`OnboardHud.coverWhen("prompt", function() return ToastQueue.currentPrompt(notices) ~= nil end)` and `"toast"` on phones (Ghost wires it; Prism doesn't touch `OnboardHud`/`HudShell`). Chevron: `TextButton` 44×44, `UICorner` 8, `UIStroke` 1, glyph `TextSize` 16. Tab/pill `UDim2.fromOffset(112, 44)`. No new instances beyond that.

## 10. Mobile checks
| Viewport | Intro card | Z4 tab | Z8 cover rule | First drop → Equip |
|---|---|---|---|---|
| 390×844 | over Z6 (160×28) and Z8 (160×84) | 36 (needs 44) | missing | not shown (P1) |
| 667×375 | over Z6 (174×124) | 36 | missing | not shown |
| 800×400 | over Z6 (154×112) | 36; at 44 it hits the bar | missing | not shown |
| 844×390 | over Z6 (151×120) | 36 | missing | not shown |
| 1920×1080 | clean | 36 | n/a (no overlap) | not shown |
Mockups: `01-first30-390x844-live-vs-fix.svg` (live / notice up → folded / notices gone), `02-first30-landscape-live-667-800-844.svg`, `03-first30-desktop-1920x1080.svg`.

## 11. Open questions (answer by number)
1. **@Ghost:** wire `hudShell.prompt` from loot grants that beat equipped gear (P1-30-1) in your next UI PR, together with P2-487-1 (`coverWhen("prompt")`)? Prism recommends **yes, same PR** (the cover rule only matters once the prompt shows).
2. **@Ghost:** also fold the intro card while a toast is up on phones (`coverWhen("toast")`) and drop both `introCard × toastHost/equipPrompt` pairs from `HudOverlap.spec`? Prism recommends **yes**.
3. **@Kevin (taste):** for the first session, turn the T3 guide on (`firstSessionGuide`: 3 free rolls, the 3rd Rare-or-better, then the Gate) instead of the cold open? Prism recommends **yes after Havoc's first-session pass**. It's the only path that gives a real win in 30 s. Prism flips nothing.
4. **@Kevin (taste):** show the starter kit as a Z6 card "Frostbite Edge · ✓ Equipped" when you Skip (P2-30-5)? Prism recommends **yes**: one card, no extra screen.

## Decision log
- Oct 24, 2026: v1 re-check for DP67P (Prism) on `prism/first-30s-recheck` from `a760a64`. Findings P1-30-1, P2-30-2 to P2-30-5, P3-30-6, P3-30-7. Q1-Q4 open. Report only, NOT APPROVED.
