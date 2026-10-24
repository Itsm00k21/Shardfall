# Party UI v1: Gate Ring strip (Z14) + party member frames (Z15) in HUD Zone Map v1.2 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (client UI, `HudLayout.zone()`, UiAudit), Echo (party remote + server checks). Base: `cursor/live-build-9721` @ **`a760a64`** (#488 merged on top of #473). Date: Oct 24, 2026 (PT). Mockups: `mockups/01`-`05` (PNG inside an SVG wrapper).
Asked for in: Ghost's Agent Board row DP67P https://app.notion.com/p/403c31ca3883816996fed5f9ecc6bf4b (item 1, "Party UI pass: invite/ready strip + member frames in zone map, before parties flip"). ACK: https://app.notion.com/p/403c31ca388381999b28fa05219613c1. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on (link, don't copy): `docs/design/zone-map-v12/HUD_ZONE_MAP_v1.2.md` (`prism/zone-map-v12`), `docs/design/party-gather-spot/SPEC_v1.md` v1.2 (#441, Gate Ring), `docs/design/m16-parties-ux/SPEC_v1.md` v1.1 (×N badge, AFK), `docs/design/hard-mode-selector/` (#437, Hard needs Lv 5).

## 0. What is live (read at a760a64; repo wins)
| What | Live | Evidence |
|---|---|---|
| Switch | `parties = false`. No `partyHpScale` / `afkCheck` flag exists yet (M16 Q7 proposed them) | `Shared/LaunchGate.luau:60` |
| World | Gray pad Ø16 at **(-18, 100)** + 4 slot discs Ø4 at (-23, 96) (-13, 96) (-23, 104) (-13, 104). #488 moved it off the Rootvault lane/pier/mouth; it is **no longer on the Shard Gate pad** that #441 drew | `Config/PartyGather.luau:27-48`, `Validate.luau` lane/pier/mouth checks |
| Party state | memory only: join by standing on the pad, slot 1 = leader, 15 s countdown, 25 s hard stop, late-join bump 5 s, leave grace 0.5 s, Friends-only (default off), per-member tier, Hard needs Lv 5, ×(1 + 0.3 × (n − 1)) stored | `Config/PartyGather.luau:76-92`, `server/PartyGather/Party.luau` |
| What players see | **disc colors only**: open 176,168,198 · member 120,210,255 · leader 255,196,64 · refused flash 230,80,96 (0.6 s) · friends-only 54,46,78; last 3 s pulse; 0.4 s fade sweep at start | `PartyGatherHost.luau:214-238` |
| Start | countdown end → roster locked and **printed**; nobody teleports ("Players stay in the hub") | `PartyGatherHost.luau:16-17, 286-295` |
| Client | **nothing**. No remote carries `Party.view()` (phase, n, cap, leader, friendsOnly, tier, secondsLeft, mult, slots with names) to a client; `startNow`, `setFriendsOnly`, `setTier` exist server-side with no input path | `Party.luau:350-405, 461-524`; no "party" match in `StarterPlayer/` except RaidHud/CombatHud comments |
| Prompts near the pad | none within r 12 (tag `PartyGatherPrompt`, silenced every 5 s) | `PartyGatherPrompt.luau`, `PartyGatherHost.luau:140-149` |

## 1. Goal
Before `parties` flips, a party of 1-4 can see who is in, how long until start, what tier, whether it's Friends-only, and (leader) start it now; in a run everyone sees their teammates' health. Both pieces get fixed slots in the v1.2 zone map, so they never land on the tutorial, toasts, the Equip prompt, dialogs, results, the rail or the screen center.

## 2. Where it lives (new zones; v1.2 tables unchanged otherwise)
| Zone | What | When | Owner |
|---|---|---|---|
| **Z14 Party strip** | Gate Ring strip: label row (Solo/Party n/4, ×N badge, countdown, pips) · Normal/Hard · Invite · Friends-only · START | hub only, while you stand on the ring (`parties` on). It **takes the Z10 action-bar slot** (Z10 hides while you're on the ring, #420 D2) | Ghost |
| **Z15 Party frames** | up to 3 teammate frames (you stay in Z1): avatar initial, name, leader crown, HP bar, DOWN / AFK / left | in a run with n ≥ 2 | Ghost (Echo sends HP) |
| World | the 4 discs (live) + one `BillboardGui` name per taken slot (leader ★), as #441 §2 | ring | Ghost |
"Invite" = Roblox's own `SocialService:PromptGameInvite` sheet (no custom friend list, no chat; Q3). "Ready" = standing on a slot; there is no ready-check button in V1 (Q4).

## 3. Flow
| Moment | Z14 / Z15 | Other zones |
|---|---|---|
| Step on the ring (first) | Z14 slides up into the Z10 slot (0.2 s): "Solo 1/4 · 15 s". Leader controls live | Z10 hides; Z4 stays (it's in its own column); Z13, if still open, folds to its tab |
| 2nd-4th player steps on | label "Party n/4 · ×1.3/×1.6/×1.9 · N s", pip fills, badge pulses once (`UIScale` 1 → 1.1 → 1) | their own Z14 is read-only: tier + Friends shown at 60%, START replaced by "Kevin starts" |
| Non-friend steps on while Friends-only | nothing on their screen except Z6 toast "Friends-only party. Wait for the next Gate." + red disc flash (live) | Z6 |
| Leader taps START / countdown ends | "Starting…" (all controls locked, 0.4 s sweep = live disc sweep) | — |
| Walk off the ring | Z14 slides down (0.15 s), Z10 back | — |
| Panel opened on the ring | Z14 hides (panel wins, one owner of the bottom on phones); comes back on close if still on the ring | Z12 |
| Run start (n ≥ 2) | Z15 shows teammates in join order (leader first) | Z7 wave chip carries the ×N badge (M16) |
| Teammate low / downed / AFK / leaves | frame bar red under 34% · skull + gray bar + "DOWN" · AFK tag (M16) · 60% fade 2 s, then removed | toast "Mika left" (M16 copy) via Z6 |
| You are Defeated | Z15 stays (you watch your party). Z11 sits below it on portrait (596 vs 592) | Z10 hidden (v1.2) |
| Run cleared (Z13 opens) | Z15 hides; the results card owns the right side | Z13 |
| Tap a frame (phone) / Tab (desktop) | the column folds to a 44-tall chip with 3 vertical HP bars; tap again opens | — |

## 4. Layout (safe-area px; new rows for the v1.2 §4 table)
| Zone | 1920×1080 | 390×844 | 667×375 | 800×400 | 844×390 |
|---|---|---|---|---|---|
| **Z14 Party strip** | = Z10: x 676-1244, y 964-1064 (one row) | = Z10: x 158-374, y 600-740 (3 rows) | bottom 124 of Z10: x 451-651, y 235-359 | x 584-784, **y 172-296** | x 628-828, y 250-374 |
| Z14 rows | label · Normal/Hard 200 · Invite 44 · Friends 44 · START 150×48 | label 24 · Normal/Hard 2 × 97 × 44 · Invite 44 + Friends 44 + START 100×48 | label 24 · Normal/Hard 2 × 89 × 44 · Invite, Friends, START 92×44 | same | same |
| **Z15 frames** | column under Z1: **x 16-256, y 88-296** (3 × 240×64, gap 8) | right column: **x 278-374, y 408-592** (3 × 96×56, gap 8) | top row right of Z1: **x 308-532, y 16-60** (3 × 72×44, gap 4); wave chip shrinks to 112 (x 539-651) | x 308-608, y 16-60 (3 × 96×44) | x 308-608, y 16-60 |
| Z15 folded chip | 240×44 at x 16, y 88 | 96×44 at x 278, y 408 | row stays (already 44) | — | — |
Short desktop (1280×720, rail from y 148): Z15 uses the compact row under Z1, x 16-316, y 80-124. Rule for `HudLayout.zone("party")`: column under Z1 if `RAIL_SAFE.top − (Z1.bottom + 16) ≥ 3 × 64 + 2 × 8`; else compact row under Z1 if that gap ≥ 60; else (landscape phones) compact row at x = Z1.right + 8, y 16, ending 8 px left of the wave chip.
**Collision check (all sizes, by rect):** Z14 vs Z4 tab, Z6, Z8, Z11, Z12, Z13, RAIL_SAFE, thumbstick (lower-left): clear; Z14 inherits Z10's live 16 px dip into the #420 keep-out at 390 (y 600-616, same as the live bar). Z15 vs Z4 tab (304-348 / 128-172), Z13 tab (356-400 / 180-224), Z6, Z8, Z11, RAIL_SAFE, keep-out, `characterZone`: clear at all five sizes (390: x 278 > keep-out right 273; Z11 starts at 596). Z15 vs Z13: never together (hides). Z15 vs Z12 panel: phones hide Z15 while a panel is open; desktop panels (x 112+) clear the column (x ≤ 256).
**Finding while placing Z14 (zone map v1.2 bug):** at 800×400 the v1.2 Z4 tab (y 128-172, Q13 44 tall) crosses the live action bar (`ActionSlots.placement` x 584-784, y 164-296) by 8 px at x 672-784. With the live 36 px tab it clears (ends 164). Z14 starts at 172 for that reason. See Q6.

## 5. States
| Element | States |
|---|---|
| Z14 | hidden · solo (n = 1, no badge) · party (badge, pips) · leader / member (read-only 60%) · Friends-only on (green) · Hard locked (lock, "Lv 5" when wide) · last 3 s (countdown text gold) · Starting… (locked) · refused (toast only, you never get a strip) · loading (strip shows "Solo 1/4" until the first view arrives) |
| Z15 frame | member · leader (gold stroke + crown) · low HP < 34% (danger bar) · downed (skull, gray bar, "DOWN") · AFK (M16 tag) · left (60% fade 2 s, removed) · folded chip |
| Buttons | Invite (always, members too) · Friends (leader toggles; members see it) · START (leader only; members get "Kevin starts") |

## 6. Copy
"Solo 1/4 · 15 s" · "Party 3/4 · ×1.6 · 9 s" (desktop: "Gate Ring · Party 3/4 · ×1.6 · starts in 9") · "Normal" · "Hard" · "Lv 5" · "START" / "START [E]" · "Starting…" · "Kevin starts" · "DOWN" · "AFK" · toasts from #441/M16 unchanged ("Friends-only party. Wait for the next Gate.", "You lead the party.", "Mika left"). Invite has no text of ours (Roblox's sheet).

## 7. Visual style
PANEL_STYLE v1.1: strip shell `36,40,52 → 26,30,40` `UIGradient`, `UICorner` 14, `UIStroke` 2 gold 255,206,96 @ 0.6. Frames: fill 20,24,32 @ 0.9, `UICorner` 12, `UIStroke` 1 (leader 2, 255,196,64). Avatar = circle `Frame` + `UICorner` (0.5, 0), fill = the slot color (leader 255,196,64, members 120,210,255 family), initial in ink 20,16,24. HP bar 96,196,120 → danger 230,80,96 under 34%; empty 40,34,58. Badge = M16 cyan ×N. Buttons ≥ 44×44, START gold 255,220,130 → 240,186,70 with ink text. Text Builder Sans 14-18 (min 14). No blur.

## 8. Motion
Z14 in 0.2 s (slide 16 px up + `GroupTransparency`), out 0.15 s. Badge pulse 0.2 s. Countdown last 3 s: label gold, no shake. Frame HP `Size` tween 0.15 s; downed: skull pop `UIScale` 0 → 1 0.15 s Back Out. Fold/unfold 0.15 s. Reduced motion: no slide/pulse, instant swaps.

## 9. Roblox build notes + UiAudit
- New `HudLayout.zone("partyStrip")` = the Z10 rect from `ActionSlots.placement` (bottom 124 on landscape phones) and `zone("partyFrames")` per the §4 rule. Prism edits no Ghost-owned file (`HudLayout`, `HudShell`, `OnboardHud`, `GearBar`, `MenuHub`, `InventoryHud`, `RollReveal`).
- Instances: `ScreenGui` "PartyHud" (`CoreUISafeInsets`, DisplayOrder **45**: above HUD 30, below results 50 and prompt 90). Strip = `CanvasGroup` + `UIGradient` + `UICorner` + `UIStroke`; rows in `UIListLayout`; buttons `ImageButton`/`TextButton` 44+ with `UICorner` 10. Frames = `Frame` ×3 in a `UIListLayout` (vertical on desktop/portrait, horizontal on landscape), avatar `Frame` + `UICorner`(0.5,0) + `TextLabel`, HP `Frame` with a `UIGradient`-free fill child. No `ParticleEmitter` on screen; world name tags are `BillboardGui` (`MaxDistance` 60, `AlwaysOnTop` false).
- **Echo (server):** one RemoteEvent `PartyView` (server → client, ~4 Hz while anyone is on the ring and on change) carrying `Party.view()` fields; one RemoteFunction `PartyAction` (`start` / `friends` / `tier`) that calls `startNow` / `setFriendsOnly` / `setTier` (all already re-check leader, phase and level). In a run: teammate HP from the server (Humanoid health already replicates; a frame can read it, no new remote needed if the roster is known).
- `HudOverlap.spec`: add `partyStrip` (visible-together failures with Z10, Z11, Z13, Z12-on-phone) and `partyFrames` (failures with Z4 tab, Z13 tab, Z6, Z8, Z11, RAIL_SAFE, keep-out) at the 5 sizes. **No new allowed pairs.**
- Keys (desktop): E START, F Friends-only, G Invite, Tab fold frames. 1-8 stay skill keys. Gamepad: Y START, X Friends.

## 10. Mobile checks
| Viewport | Z14 | Z15 | Touch |
|---|---|---|---|
| 1920×1080 | Z10 slot, one row | column 16,88 240×208, clear of RAIL_SAFE (320) | 44 / START 48 |
| 1280×720 | Z10 slot x 356-924 | compact row 16,80 300×44 (rail starts 148) | 44 |
| 390×844 | Z10 slot, thumbstick lower-left stays free | right column x 278-374, y 408-592 | 44 / START 48 |
| 667×375 / 800×400 / 844×390 | bottom 124 of Z10 slot | top row right of Z1 | 44 |
Mockups: `01-party-run-1920x1080.svg`, `02-party-hub-1920x1080.svg`, `03-party-390x844-hub-run-fold-defeat.svg`, `04-party-landscape-667x375-800x400-844x390.svg`, `05-party-component-sheet.svg`.

## 11. Open questions (answer by number)
1. **@Ghost:** add Z14 (strip = Z10 slot) and Z15 (frames, §4 rule) to `HudLayout.zone()` and v1.3 of the zone map? Prism recommends **yes**.
2. **@Ghost / @Echo:** before the flip, add `PartyView` (server → client) + `PartyAction` (start / friends / tier) so the leader can START and toggle Friends-only? Today a party can only wait out the 15 s and nobody sees the countdown. Prism recommends **yes, P1 before `parties` flips**.
3. **@Kevin (taste):** an **Invite** button on the strip that opens Roblox's own invite sheet (`SocialService:PromptGameInvite`; no custom friend list, no chat)? Prism recommends **yes** (behind `parties`).
4. **@Kevin (taste):** no "Ready" button in V1: standing on a slot is ready, the leader's START or the 15 s clock starts it. Prism recommends **no ready button** (an AFK friend can't block the party).
5. **@Kevin (taste):** teammate frames show HP + DOWN only (no teammate loot, no damage meter). Prism recommends **yes**, matches M16 Q2 (own drops only).
6. **@Ghost:** zone map v1.2 bug: the 44 px Z4 tab at 800×400 (y 128-172) hits the live action bar (y 164) by 8 px. Move the landscape Z4 tab to y 120-164 at 800×400 (pills end at 80, Dev slot ends 120) instead of shrinking it back to 36? Prism recommends **yes, y 120-164**.
7. **@Ghost:** the gather ring is now at (-18, 100), 18 st west of the arch, not on the Shard Gate pad (#441 drew it on the pad). Add one world sign "Party" (BillboardGui, 14 px min) over the ring and a gray court guide from the lane? Prism recommends **yes**, else new players never find it.

## Decision log
- Oct 24, 2026: v1 written for DP67P (Prism) on `prism/party-ui` from `a760a64`. Q1-Q7 open. NOT APPROVED until Kevin copies it into Vision & Design Rules.
