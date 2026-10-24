# M13 Visual QA Checklist (roll → equip → seat → Waves pier → 5 waves → Results → boss clear → wipe → rejoin → roll again), v1

Owner: Prism (design, docs only, no code). Used by: Echo / Havoc on the M13 smoke run (PR #434, `echo/m13-run-smoke` @ `73e3a49`), Ghost for UI fixes. Base: `cursor/live-build-9721`. Status: **v1, ready to use** (Ghost GO, board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, pick 3, Kevin pre-approved). Not an official Vision & Design Rules decision. Pass/fail is visual only; Echo's Lune smoke covers the logic.

Sources (link, don't copy): PR #434 body (live path, 6 pending cases) · #420 phone layout review (keep-out, D1 portrait top 35%, D2 hub cluster hides under the Gate dock, D3 one toast lane, R7 text sizes) · #412 first 30 seconds (Gate dock) · #397 roll reveal v1.2 · #428 Wave HUD v1.1 · #429 Results v1.3 (5-token fly-in, Hard-clear variant) · Element glow read v1.1 (`prism/element-glow-read`) · Hard accent v1.1 · `Shared/Rarities.luau` · STYLE.md (PR #392).

## 1. Goal
One pass on a Studio build, at **390×844, 667×375, 800×400 and 1280×720**, tells us whether every screen on the M13 loop is readable, tappable, off the screen center, and uses the right colors, with a screenshot for every fail. A fail here is a **visual** bug for Ghost (or Echo for world/server visuals), never a logic bug.

## 2. Where it lives
This file (`docs/design/m13-visual-qa/CHECKLIST_v1.md`) + the overlay sheet `mockups/01-qa-overlay-frames.svg`. Results go as a comment on PR #434 (Echo) or a board row to Ghost; screenshots named `m13_<step>_<size>_<pass|fail>.png`. Nothing in the game changes.

## 3. Flow (how to run it)
1. Rojo-sync `echo/m13-run-smoke` (or `cursor/live-build-9721`). **Leave every LaunchGate flag as shipped** (`equip`, `waveArena`, `elementGlow`, `hardMode` off), as PR #434 says. Do not publish.
2. Studio → Test → Device emulator. Sizes: **390×844** (portrait phone), **667×375** (small landscape phone), **800×400** (wide Android landscape), **1280×720** (desktop, mouse + keyboard). Turn "Show device frame" off; capture at 100%.
3. Walk the loop once per size (≈ 6 min each): roll → bag equip → seat (only if a test stub opens EquipSlot; otherwise mark N/A) → Waves pier (Solo) → waves 1–5 (Gnarl on 5) → Results/clear hint → fall once → Stop/Play (rejoin) → roll again.
4. For each row below tick **P** (pass), **F** (fail + screenshot) or **N/A** per size. Hold each capture against the overlay sheet (keep-out, toast lane, 44 px gauge).
5. Post the table with fails first.

## 4. Layout rules every capture is checked against
Full-screen px, #420 frame (0,0 = top-left incl. the Roblox top bar).

| Rule | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| **Center keep-out** (no panel, card or toast may enter; world VFX and enemies may) | x 117–273, y 296–616 | x 200–467, y 105–274 | x 240–560, y 112–292 | x 384–896, y 202–526 |
| **One toast lane** (D3) | x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |
| **Touch target** | every tappable ≥ 44×44 px (hit box, not just art) | same | same | mouse: ≥ 32 px OK; key hint shown |
| **Text** (R7) | ≥ 13 px body; 10–11 px only for badges/captions | same | same | same |
| **Panels collapse** | every panel has a 44 px chevron that **folds** it to a bar/pill (not just closes) | same | same | same (+ key) |

## 5. The checklist
Columns: **390 / 667 / 800 / D** = the four sizes. "Live" = what the M13 path shows today on `cursor/live-build-9721`; "Spec" = what the linked spec asks for once its PR lands (check only if that build is in the test).

### A. Global (check on every screen)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| A1 | Center keep-out | No panel/card/toast/popup enters the cyan box (overlay sheet). Enemies, drops, VFX may. | ☐ | ☐ | ☐ | ☐ |
| A2 | Touch targets | Every button/tile/chevron ≥ 44×44 hit box; nothing tappable under 44 on 390/667/800. | ☐ | ☐ | ☐ | ☐ |
| A3 | Collapse | Each panel on this loop (bag, Gate dock, Results) has a chevron that folds it to a bar/pill and back; folded state never covers combat buttons. | ☐ | ☐ | ☐ | ☐ |
| A4 | One toast lane | At most one toast visible, inside the lane; no toast over HP, currency or the dock. | ☐ | ☐ | ☐ | ☐ |
| A5 | Safe insets | Nothing under the notch / Roblox top bar (portrait y < 99, landscape y < 52, desktop y < 58). | ☐ | ☐ | ☐ | ☐ |
| A6 | Text | Body ≥ 13 px, no clipped or "…" text on any button at any size. | ☐ | ☐ | ☐ | ☐ |
| A7 | Rarity colors | Every rarity stroke/name matches `Rarities.COLOR`: Common **168,168,176** · Uncommon **64,186,98** · Rare **72,142,255** · Epic **186,96,240** · Legendary **255,196,64** (eyedrop the stroke). Only 5 tiers visible (no Mythic/Secret in V1). | ☐ | ☐ | ☐ | ☐ |
| A8 | Rendering | Only Roblox-native looks: no blur, glass, soft drop shadows; corners/strokes = `UICorner`/`UIStroke`. | ☐ | ☐ | ☐ | ☐ |
| A9 | No paid prompt | No Robux / purchase prompt anywhere on the loop; no pay-to-win UI. | ☐ | ☐ | ☐ | ☐ |

### B. Roll (Verdant armory Crackstone, 1 Shard Token)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| B1 | Roll button | Reachable in one tap from the hub, ≥ 44 px, shows the token count (10 → 9). | ☐ | ☐ | ☐ | ☐ |
| B2 | Reveal | Reveal card is off-center or sized inside #397's frame; the tier color (A7) is on the card stroke + name; tier word readable in ≤ 1 s. | ☐ | ☐ | ☐ | ☐ |
| B3 | Skip / close | Skip/close ≥ 44 px, never covers the item name. | ☐ | ☐ | ☐ | ☐ |
| B4 | Fast win | First roll → item in the bag in ≤ 30 s from spawn (Kevin's first-30-seconds rule). | ☐ | ☐ | ☐ | ☐ |

### C. Equip (bag, live EquipItem)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| C1 | Bag opens off-center | Bag panel stays out of the keep-out (or is a full-screen sheet with its own close + fold) and collapses with its chevron. | ☐ | ☐ | ☐ | ☐ |
| C2 | Cards | Square cards, corner 10, 2 px rarity stroke, name in rarity color, `E` badge on equipped (STYLE.md). | ☐ | ☐ | ☐ | ☐ |
| C3 | EQUIP / UPGRADE | Both ≥ 44 px tall; UPGRADE 255,190,60 with dark text; dim state when short/maxed. | ☐ | ☐ | ☐ | ☐ |
| C4 | Equipped feedback | After equip, the `E` badge shows at once; no double toast. | ☐ | ☐ | ☐ | ☐ |

### D. Seat (Phase 2 EquipSlot → GearBar slot; flag `equip` off, so only with a test stub)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| D1 | Flag off | With the shipped flag, no slot-seat UI appears and nothing says "error". (Live) | ☐ | ☐ | ☐ | ☐ |
| D2 | Seated slot (stub only) | GearBar slot shows the item icon with its rarity stroke; slot ≥ 44 px; bar stays off center. Else N/A. | ☐ | ☐ | ☐ | ☐ |

### E. Waves pier (Rootvault gate, "Waves" prompt, Solo)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| E1 | Prompt | The "Waves · Solo" ProximityPrompt is readable, not overlapping another prompt; tap area ≥ 44 px on touch. | ☐ | ☐ | ☐ | ☐ |
| E2 | Hub cluster | Combat cluster hidden while a hub dock/prompt owns the bottom (#420 D2); nothing stacks on the thumbstick. | ☐ | ☐ | ☐ | ☐ |
| E3 | Teleport | Loading/transition has no stuck center panel; HUD reappears within 2 s. | ☐ | ☐ | ☐ | ☐ |

### F. Five wave rows (waves 1–5, Gnarl on 5)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| F1 | Wave counter | "Wave N" readable each wave. Live: the existing hint/counter. Spec #428: wave chip at 390 x 16–150, y 179–223 / 667 x 61–197, y 132–176 / 800 x 66–222, y 132–176 / D x 88–268, y 138–182. | ☐ | ☐ | ☐ | ☐ |
| F2 | Wave 5 boss | Gnarl reads as the boss (bigger, gold-stroked look); boss bar (spec #428) not in the keep-out and not over the toast lane. | ☐ | ☐ | ☐ | ☐ |
| F3 | Enemy reads | 3–8 enemies readable at zoom 18; HP bars don't overlap each other's text; enemy bars ≤ 1 per enemy. | ☐ | ☐ | ☐ | ☐ |
| F4 | Element glow (flag off) | With `elementGlow` off: warm Rim only, **no** element colors, no pips, no lights. (Live) | ☐ | ☐ | ☐ | ☐ |
| F5 | Glow budget (only on a #432 test build) | ≤ **6** element glows and ≤ **4** pool lights on touch (≤ 12 / 12 on desktop); every alive enemy ≤ 1 Highlight, **dead = 0**; enemy Highlights ≤ **18**; pip on the bar, **no bar stroke** (glow read v1.1). | ☐ | ☐ | ☐ | ☐ |
| F6 | Telegraph vs Ember | Boss telegraph rings (threat orange, white rim) never read as an Ember glow (only on builds with both). | ☐ | ☐ | ☐ | ☐ |
| F7 | Wave clear hint | "Wave N cleared. +G gold, +X XP, +T tokens." sits in the toast lane, one per clear. | ☐ | ☐ | ☐ | ☐ |
| F8 | Buff pips (spec #416/#428) | If present: pips under the wave chip, 10 px, element colors from `Config/Elements` (Ghost Q7). | ☐ | ☐ | ☐ | ☐ |

### G. Results (live: wave-clear hint / CombatHud victory card; spec: #429 Results wings)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| G1 | Live card | CombatHud `Result` card (340 wide, centered at 0.38, 0.45) — **known keep-out conflict** on 390 and 667 (flag it, don't fail M13 for it; #429 replaces it). | ☐ | ☐ | ☐ | ☐ |
| G2 | Continue | Continue button ≥ 44 px, never covered by the loot grid. | ☐ | ☐ | ☐ | ☐ |
| G3 | Loot grid | `ResultsGrid` tiles 64 px with rarity strokes (A7); max 2 rows, "+N" fold. | ☐ | ☐ | ☐ | ☐ |
| G4 | #429 wings (spec build only) | Stats wing 390 x 16–374, y 107–287 / 667 x 16–196 / 800 x 16–232 / D x 16–368; loot + actions wing 390 y 620–802 / 667 x 471–651 / 800 x 568–784 / D x 912–1264. RUN AGAIN 52–64 tall, ROLL 48–64. Wings fold to the 56 px bar. | ☐ | ☐ | ☐ | ☐ |

### H. Boss clear (wave 5 paid)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| H1 | Token number shown = token number paid | The number on screen equals the wallet change. **Live today: +2 tokens** on the wave-5 hint (`Dungeons.waveReward(5)`), while the Economy sheet (`Config.Economy.WAVES[5].tokens`) says **5**. See the flag below. | ☐ | ☐ | ☐ | ☐ |
| H2 | 5-token fly-in (#429 v1.2, spec build + #431 only) | 5 Roll Token icons fly from the boss point to ROLL in < 0.8 s, pass over the keep-out only as motion (no panel), "BOSS +5" chip after the Roll Tokens label; once per clear (no repeat on rejoin). **N/A on live** (no `bossClear` payload). | ☐ | ☐ | ☐ | ☐ |
| H3 | Hard-clear variant (#429 v1.3, Hard builds only) | Same 5 tokens + HARD badge only; no red sky (Hard accent v1.1 is HUD-only). N/A while `hardMode` is off. | ☐ | ☐ | ☐ | ☐ |

> **Flag: wave-5 tokens 2 (live) vs 5 (Economy sheet).** Echo found live `Dungeons.waveReward(5)` pays **2** Shard Tokens on every wave-5 clear and stores no run id, while `Config.Economy.WAVES` says **5** and nothing reads it (PR #434, pending case 2). The **#429 Results 5-token fly-in depends on the 5-token boss grant from #431** (`BossClearReward`): with live code the fly-in would promise 5 while the wallet gets 2. Until #431 lands, H1 is the only valid check, and the fly-in must read its count from the `bossClear.tokens` payload (never a hard-coded 5). Q1 below.

### I. Wipe
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| I1 | Defeat line | "The waves stop when you fall. Rewards from cleared waves are still yours." readable, in the toast lane or the card, ≥ 13 px. | ☐ | ☐ | ☐ | ☐ |
| I2 | No loss look | No red "you lost tokens" number; the wallet number doesn't drop. | ☐ | ☐ | ☐ | ☐ |

### J. Rejoin (Stop → Play, same save)
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| J1 | Wallet + equip | Token count and the equipped item (`E` badge, GearBar if stubbed) match the session you left. | ☐ | ☐ | ☐ | ☐ |
| J2 | No replay | No reveal, fly-in or "boss clear" toast replays on join. | ☐ | ☐ | ☐ | ☐ |
| J3 | First-30-seconds | Returning player doesn't get the first-run Focus mode again (#412). | ☐ | ☐ | ☐ | ☐ |

### K. Roll again
| # | Check | Pass when | 390 | 667 | 800 | D |
|---|---|---|---|---|---|---|
| K1 | Token count | Shows 9 → 8 (starter tokens; not a boss-clear credit on live). | ☐ | ☐ | ☐ | ☐ |
| K2 | Same reveal rules | B2–B3 still pass. | ☐ | ☐ | ☐ | ☐ |

## 6. Numbers
Sizes 390×844 / 667×375 / 800×400 / 1280×720. Touch ≥ 44 px. Text ≥ 13 px (badges 10–11). Glow budget 6 touch / 12 desktop, lights 4 / 12, enemy Highlight ceiling 18, ≤ 1 Highlight per alive enemy, 0 per dead (glow read v1.1). Rarity colors per A7. Tokens: live wave 5 = 2, Economy sheet = 5, #429 fly-in = 5 (needs #431). Starter tokens 10 → 9 → 8.

## 7. Edge cases
- **Flags off** is the expected state; any element glow, Hard UI, wave-arena UI or seat UI showing with shipped flags is a **fail** (F4, D1).
- **Live victory card in the keep-out** (G1) is known; log it as "replaced by #429", not as a new M13 bug.
- **Rejoin mid-run** isn't on the M13 path; if it happens, note what the HUD shows.
- **Low graphics:** repeat F3–F5 once at Graphics 1 on 390×844.
- **Party:** M13 is Solo; party checks wait for the party gather spot + Hard v1.2 builds.

## 8. Mockups
`mockups/01-qa-overlay-frames.svg`: the four frames with the keep-out (cyan), toast lane (gold), dock and wave chip homes (green) and a 44×44 gauge (red). Overlay a capture at 100% to check A1, A2, A4. PNG on the box only.

## 9. Build split
- **Echo / Havoc:** run it on #434's build; post fails with screenshots on PR #434.
- **Ghost:** UI fails (A–G, I–K) on Ghost-owned files.
- **Echo:** world/server visual fails (F4–F6, H1).
- **Prism:** answer "is this a design fail?" questions; update this list when #428/#429/#431/#432 land.

## 10. Pass criteria
M13 visual pass = **no F** in sections A–F and I–K at any of the 4 sizes, with G1 and the H1 token mismatch logged as known (until #429/#431). Every F has a screenshot.

## 11. Open questions (answer by number)
1. **@Ghost / Echo:** Wave-5 boss tokens: is the right number **5** (Economy sheet, #431 grant, #429 fly-in) and live's **2** the bug? Recommended: yes; keep the fly-in reading `bossClear.tokens` so it can never show more than is paid.
2. **@Ghost:** Log the live CombatHud victory card's keep-out overlap (G1) as a known issue fixed by #429, rather than a new M13 fail? Recommended: yes.
3. **@Ghost:** Should Havoc run the checklist on #434 alone (flags as shipped), or on a combined test build with #428/#429/#432 to tick the spec rows too? Recommended: #434 alone first; spec rows stay N/A.

## Decision log
- 2026-10-24 (Prism): v1 published from Ghost's GO (board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, Kevin pre-approved). 11 sections (A–K), 4 sizes, wave-5 token flag (live 2 vs sheet 5) tied to #429's fly-in. Not a Vision & Design Rules decision.

## Roblox build notes
Nothing to build. When fixing a fail, stay stock Roblox: `Frame`/`ImageLabel` + `UICorner`/`UIStroke`/`UIGradient`, `TweenService` for motion, `ParticleEmitter` only in world space, `GuiObject.Active` + 44 px hit boxes (`TextButton` size, not art size), `UIScale` for desktop clamps, `CoreUISafeInsets` for the top inset. No blur, no glass, no web fonts.
