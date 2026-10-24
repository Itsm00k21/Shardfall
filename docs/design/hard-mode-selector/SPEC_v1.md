# Hard Mode Selector ("Gate dock toggle + Hard card"), Spec v1.2

Owner: Prism (design, docs only, no code). Builders: Ghost (Gate dock UI, world tint), Echo (server checks, Config, Hard-only drop list). Base: `cursor/live-build-9721`. Status: v1.1, Ghost answered Q1, Q2, Q3, Q6 (Oct 24, 2026, Kevin pre-approved); Q4 and Q5 are Kevin taste calls, Prism recommendations recorded as PROVISIONAL. Gray-box only (pre-Phase S). Nothing beyond the answered questions is approved until Ghost/Kevin say so.
**v1.2 (Oct 24, 2026):** adds the **per-player Hard pick** (Ghost GO, board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730, answer 8, Kevin pre-approved). Source: PR #430 / Havoc P2-430-1 stores the pad tier **per player**, so one player's pick can't lock out, drag along, or flip anyone else. The leader-picks rule of v1.1 is replaced in §0b, §2, §3, §4, §5, §7, §9, §10 and the build notes. New mockups 07–11.
Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca38838192b465db2fbca4fda1, item 1, from canvas item **M14**: "Hard mode selector UX spec (unlocks Lv 5, 2x HP, 1.5x dmg, 2x tokens/fragments, Hard-only Epic+ list; locked state, phone first)". Roadmap **5.4 Hard mode (Lv 5)**.

Sources (link, don't copy):
- Locked: V1 Core Loop §3 Party & Run Setup ("Leader picks Normal or Hard (only tiers all members have unlocked)", "Hard ≈ 2× HP, 1.5× damage"), §4 Dungeon Rewards ("Hard: 2× tokens/fragments + Hard-exclusive Epic+ items"), §5 Progression ("Lv5: Hard mode"), §7 ("Clear Normal to unlock Hard" goal text). Vision & Design Rules, Oct 23, 2026: "Hard mode is V1 (unlocks at Lv 5). Nightmare is not V1."
- Gate: V1 gates are **Normal + Hard (Lv 5) only, no Nightmare** (PR #418, `docs/design/DUNGEON_GATE_PLAZA.md`).
- Specs this builds on: #412 first 30 seconds (the **Gate dock**: bottom-center slot, chevron, Normal, 🔒 Hard "Lv 5", START; "Hard unlocks at Lv 5." toast); #413 Crater Square (Gate pad (0, 98) Ø16, arch (0, 108)); #414 Shard Crater (arena); #420 phone layout review (keep-out, D1 portrait top 35%, D2 hub cluster hides under the Gate dock, D3 one toast lane); party gather spot spec (this same batch, `docs/design/party-gather-spot/`).
- Repo (read-only check): `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). **Mismatch found:** `Shared/Config/Economy.luau` `DIFFICULTIES.hard` = `tokenMultiplier 1.5, levelGate 10` (plus `medium`, `nightmare`, `insane` rows); `Shared/Rootvault.luau` `DIFFICULTIES.hard` = `hp 1.5, damage 1.5, level 10`; `Shared/Progression.luau` unlock `level 10 "Hard Rootvault"`. The Core Loop says Lv 5, 2× HP, 1.5× damage, 2× tokens/fragments. The repo is what runs, so this is logged as Q2, not changed here.
- **PR #430** (`echo/hard-config`, open, flag `LaunchGate.hardMode` off): `Shared/HardMode.luau` `select(level, tier, userId)` / `touch(level, userId)` keep the tier **per player in session memory** (no save field, schema 26). `DungeonService.setDifficulty(player, tier)`; `enter(player, dungeonId, tier)`. With the flag off the pad offers Normal only. Havoc P2-430-1: no server-wide pad tier.
- Chrome: PR #392 `docs/ui/reference/STYLE.md` (panel 28,24,40 · row 40,34,58 · button 108,78,196 · gold 255,196,64 · danger 230,80,96 · corners 8/10/12 · strokes 1/2 · Builder Sans). Style Bible v0 (#424, NOT APPROVED) state table: Locked = padlock + muted label.

## 0. Directions (pick one) and recommendation
Mockup: `mockups/06-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Dock toggle + Hard card** | The #412 Gate dock already has Normal and Hard. Tapping Hard selects it and shows a small **Hard card** next to the dock for 4 s: the deal (2× HP · 1.5× dmg · 2× tokens/frags) and a row of Hard-only Epic+ drop tiles. Locked Hard shows the same card dimmed, with a level bar and silhouette tiles. | 1 tap, no new world parts, works the same solo and in a party (v1.2: each player picks, see §0b), the locked card is a clear "why level up" teaser. Fits the bottom slot the dock already owns. | The portrait card briefly overlaps the thumbstick zone (see §4, Q6). |
| B | Twin pads | Two pads side by side at the Gate: Normal pad and Hard pad (locked pad has a seal). | Very readable in the world; no screen UI. | Doubles the lobby, splits parties across two pads, clashes with the party gather spot (T4) and with #413's one-pad hub. Hard's rewards can't be shown without UI anyway. |
| C | Picker sheet | Stepping on the pad opens two big cards (Normal / Hard) in the middle of the screen. | Very clear, room for the drop list. | Sits in the center keep-out, adds a tap every run, fights Kevin's "panels stay off center" rule. |

**Recommendation: A.** It reuses the dock players already learned in their first 30 seconds, adds one small card, and keeps the screen center clear. The rest of this spec is A.

## 0b. Per-player pick (v1.2): directions and recommendation
Mockup: `mockups/11-per-player-directions.svg`. Context: the V1 Core Loop §3 line "Leader picks Normal or Hard" predates #430. With per-player tiers, a party needs a rule for what the **run** is.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Everyone picks, Hard when all agree** | Every player has a live Normal/Hard toggle on their own dock (their #430 tier). The run is **Hard only when every member picked Hard** (and all are Lv 5+); otherwise it's Normal. Each member's pick shows on their world name tag and in a small party line. | Matches #430 exactly (nobody is dragged into 2× HP enemies), no new prompt, solo is unchanged, one rule to learn. | One player on Normal keeps the party on Normal; needs a clear "waiting on Kai" read (card + tags). |
| B | Leader picks, members confirm | Leader picks Hard; each member gets Accept / Leave. | Close to the Core Loop wording. | Breaks #430 (the leader's pick still drags members), adds a modal near the center every Hard run. |
| C | Majority vote | Most picks win; ties go Normal. | Fast in big parties. | Drags the minority into Hard; harder to read at a glance. |

**Recommendation: A.** It is what #430 already builds on the server, and it keeps the "nobody gets dragged" rule Havoc asked for. Core Loop wording: see Q7 (@Kevin, the Core Loop page is locked, so Prism doesn't edit it).

## 1. Goal
At the Shard Gate, a player who has reached Lv 5 can pick Hard in one tap and understands, in under 2 seconds, what it costs (enemies 2× HP, 1.5× damage) and what it pays (2× tokens and fragments, Hard-only Epic+ drops). A player below Lv 5 sees exactly what Hard is and how far away it is, so locked Hard works as a goal instead of a dead button. **In a party (v1.2)** every member picks for themselves, sees everyone else's pick at a glance, and knows in one read whether the run will be Hard and who it's waiting on.

## 2. Where it lives
- **Screen (Ghost):** inside the existing #412 **Gate dock** (bottom-center slot, shown only while on the Gate pad). New: the Hard segment's states (§5), a **Hard card** (`HardCard` Frame, sibling of the dock), and the dock label text. Built in the same ScreenGui as the dock (`CoreUISafeInsets`).
- **World (Ghost):** the Gate pad rim and the arch swirl switch to the Hard accent (danger 230,80,96) while Hard is selected (#413 states: idle / on pad / countdown). The arch subline gains `· Hard` at Lv 5 (PR #418 rule).
- **Arena (Ghost):** one "HARD" chip on the run's wave counter (future #417) and one "Hard ×2" line on the results screen. No other arena UI.
- **Server (Echo):** per-player tier from #430 `HardMode` (session memory); level check on select and again on START; **run tier rule (v1.2): the run is Hard only if every member's tier is Hard and every member is Lv 5+, checked at START; otherwise Normal**; the Hard-only Epic+ drop list in Config (proposed `Shared/Config/Loot.luau` `HARD_ONLY`, read by the client for the tiles). Nothing new is saved: the selection is per player, session only (Q3, #430).
- **Not here:** Nightmare (not V1, no UI, no greyed third option), Robux, passes, boosts. Hard is earned by level only.

## 3. Flow
| Step | Trigger | What the player sees / does | Server |
|---|---|---|---|
| 1 | Step on the Gate pad | Gate dock rises (0.26 s, #412). **Normal** is selected by default. Label "Shard Gate · Solo · starts in 15". | open pad session |
| 2a | Lv ≥ 5, tap **Hard** | Hard turns selected (gold 2 px stroke, red text). Solo: pad rim + swirl tween to red (0.3 s); party: only your slot ring turns red until everyone picked Hard (v1.2). **Hard card** slides in (0.2 s): HARD chip, "2× HP · 1.5× dmg · 2× tokens/frags", 5 Hard-only drop tiles. Label adds "· HARD". | validate this player's level; store the player's tier (#430) |
| 2b | Tap a drop tile | The caption line becomes "<name> · <tier> · Hard only" (tile gets a gold stroke). No popup. | — |
| 2c | 4 s pass, or tap the card, or tap Hard again | Portrait: the card folds away (0.2 s); tapping the selected Hard reopens it. Landscape/desktop: the card stays while Hard is selected and folds with its own chevron. | — |
| 3 | Tap **Normal** | Normal selected, pad back to gold, card folds. | — |
| 4 | START (or countdown ends) | "Starting…" (#412). Teleport to the arena with the chosen tier. | **re-check** level on START; party: run = Hard only if every member's tier is Hard and all are Lv 5+, else Normal (v1.2); a solo Hard pick that fails the level check starts Normal with toast "Back to Normal: Hard needs Lv 5." |
| 5 | In the run | Wave counter shows a small "HARD" chip (danger fill). Enemies use Hard Config (2× HP, 1.5× damage). | Hard Config |
| 6 | Results | Extra line "Hard ×2" next to tokens and fragments; Hard-only drops show a small "HARD" tag on their tile. | grant 2× tokens/frags, roll Hard-only list |

**Locked flow (Lv < 5):** the Hard segment shows 🔒 "Hard · Lv 5" (#412). Tap it: the **locked card** peeks for 4 s: "Hard unlocks at Lv 5 · you're Lv 3", a gold level bar, and the 5 drop tiles as silhouettes (rarity stroke + "?"). Tap the card or wait 4 s to fold it. **In #412 Focus mode (first-ever run)** the card is skipped and only the existing toast "Hard unlocks at Lv 5." plays, so the first 30 seconds stay simple.

**Party flow (v1.2, per-player pick, replaces "leader picks"):** mockups `07`–`10`.
- **Who picks:** every member taps Normal / Hard on their **own** dock (segments are live for everyone, no longer read-only for members). START and the Friends-only toggle stay leader-only (party gather spot spec).
- **Default:** everyone starts on **Normal** when they join the server (#430 session memory, Q3). A pick is kept for the rest of that server session, so after a run (or Run Again) you're still on what you picked; leaving the server resets it. A Lv < 5 player is always Normal.
- **What the run is:** Hard only when **all** members picked Hard and all are Lv 5+ (checked at START). Otherwise Normal. Solo works exactly as v1.1.
- **What others see (world):** each slot's name tag gets a small red **HARD** chip when that member picked Hard, and their slot ring turns red. The **pad rim and arch swirl turn red only when the whole party is on Hard** (so the pad still means "this run is Hard").
- **What others see (screen):** the dock label reads `Party 3/4 · Hard 2/3 · starts in 9` while picks are mixed, `Party 3/4 · HARD · 9` when all picked Hard, `Party 2/4 · Hard locked (Sam Lv 3) · 11` when someone is below Lv 5. A player who picked Hard sees the **party Hard card** in the Hard card spot: "Hard when all 3 pick it · 2/3", "Waiting on Kai · else Normal", and one chip per member (`Kevin · H`, `Kai · N`). Players on Normal see only the label (no card), so nobody is nagged.
- **One toast when the party tier flips** (D3 lane, info priority, to the whole party): "Everyone picked Hard. This run is Hard." and, if someone switches back, "Kai picked Normal. This run is Normal." No toast for each single pick.
- **START / countdown with mixed picks:** the run starts Normal; players who picked Hard get "Not everyone picked Hard. Starting Normal." Their pick stays Hard for next time.
- **Below Lv 5 in the party:** that member's Hard segment is locked (🔒 "Lv 5"); the label and the Hard card say "Hard locked · Sam is Lv 3 · all need Lv 5"; other members' Hard picks are kept (shown with the chip) but the run is Normal.
- **Joiners (Q1 decided, re-read for v1.2):** while the party is **on Hard** (every member picked Hard), a Lv < 5 player who steps on the pad is refused with "This party is on Hard (Lv 5)." While picks are mixed, anyone can join (the party is Normal anyway). A Lv 5+ joiner keeps their own pick (#430: joining never flips a pick); if the party was all-Hard and they're on Normal, the label drops to `Hard 3/4` and their Hard segment pulses twice so they see why (Q8).
- **Party gather spot interplay:** the Gate Ring slots (party gather spot spec §3–§5) carry the per-member pick: slot ring red = that member picked Hard; name tag chip "HARD". Step 5 of that spec ("Leader picks Normal/Hard") is superseded by this flow; the leader ★ only means START + Friends-only + who leads after a hand-off. Leader hand-off doesn't change anyone's tier.

**Unlock moment:** when the account reaches Lv 5 (anywhere), one toast in the lane (info priority): "Hard mode unlocked! Pick it at the Shard Gate." The next time on the pad, the Hard segment pulses gold twice (`newDot` until first tap). The #412-style goal text "Clear Normal to unlock Hard" becomes "Try Hard at the Shard Gate" once.

Cancel / back: walking off the pad closes the dock and the card (#412). The dock chevron collapses the dock to the 44 px "Shard Gate ›" pill; the card folds with it.

## 4. Layout
Full-screen px, same frame as the #420 review (0,0 = screen top-left including the Roblox top bar). Build in `CoreUISafeInsets` by subtracting the top inset. In the hub the live combat cluster is hidden while the Gate dock is up (#420 D2), so the bottom-right is free on landscape and desktop.

**Center keep-out:** 390×844 x 117–273, y 296–616 (D1, provisional) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. Nothing in this spec enters it.

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Gate dock (#412) | x 16–374, y 738–802 (358×64) | x 174–492, y 301–361 (318×60) | x 230–570, y 326–386 (340×60) | x 450–830, y 632–696 (380×64), `UIScale` clamp |
| Dock segments | chevron 44 · Normal 92 · Hard 92 · START 92×48 (solo); with the party Friends toggle: Normal/Hard 76 each + toggle 44 | chevron 44 · Normal/Hard ~70 each · START 92 | same as 667, Normal/Hard ~81 | Normal/Hard ~94 · START 110 "START [E]" |
| Dock label | centered, baseline y 733, 12 px | y 293, 11 px | y 320, 11 px | y 622, 13 px |
| Hard card | **x 88–374, y 620–724** (286×104), above the dock, right of the rail (rail right edge 80); bottom 724 < dock top 738; top 620 > keep-out bottom 616 | **x 497–651, y 233–361** (154×128), right of the dock in the freed cluster area; left edge 497 > keep-out right 467 | **x 578–784, y 254–386** (206×132); 578 > 560 | **x 846–1146, y 560–696** (300×136), right of the dock |
| Card contents | row 1: HARD chip 46×20 + one stat line (11 px); row 2: caption (11 px); row 3: 5 tiles 44×44, gap 6 | HARD chip + "2× HP · 1.5× dmg" / "2× tokens + fragments" (gold) / caption / 3 tiles 44×44 in a horizontal `ScrollingFrame` (5 total, "›" peek) | same, 4 tiles visible | same, 5 tiles 48×48 |
| Card timing | transient: 4 s, tap to dismiss, tap selected Hard to reopen | stays while Hard is selected; own chevron folds it to nothing (Hard segment reopens) | same as 667 | same as 667 |
| **Party Hard card (v1.2)** | same spot as the Hard card (x 88–374, y 620–724): HARD chip + "Hard when all N pick it · n/N" (12 px), "Waiting on …" (11 px), member chips 22 tall (display-only) | same spot (154×128): "n/N picked", "Waiting on Kai", member chips with 3-letter names | same spot (206×132) | same spot (300×136) |
| **Name tag pick chip (v1.2, world)** | `BillboardGui` tag + 32×12 "HARD" chip (danger fill, ink 8 px bold) at the tag's right end; slot ring danger | same | same | same |
| Dock label (party, v1.2) | "Party 3/4 · Hard 2/3 · starts in 9" (12 px; "Shard Gate · Party 3/4 · Hard 2/3 · starts in 9" fits the 358 px dock width) | 11 px | 11 px | 13 px + keys "1 / 2 / F / E" |
| Toasts | one toast lane (#420 §4a): x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |

Rules:
- Every tap target ≥ 44 px (segments 44 tall, tiles 44×44, START 48 tall). Text ≥ 13 px except caption/badges 11 (#420 R7).
- **Portrait thumbstick:** the card covers x 88–198 of the thumbstick zone (x 16–198, y 640–794) for at most 4 s, the same way the #412 dock already sits over it. The card Frame is `Active = false`, so a touch that misses a tile still reaches the thumbstick; only the tiles are buttons. It never covers the dock, START, or any combat button (the combat cluster is hidden on the pad, D2). Q6 decided: OK under the #416 tray rule (tap-to-dismiss, never over combat buttons), provisional until Kevin's phone playtest.
- The card never covers the live currency pills or HP block (portrait y 115–227, landscape y 68–132).
- The card opens **next to** the dock, never as a modal, and never blocks START.
- **v1.2:** the party Hard card uses the same rect at every size, so the keep-out checks above still hold. Member chips are display-only (no 44 px rule); the only new taps are the members' own Normal/Hard segments, which already meet 44 px. On portrait the party card is transient like the Hard card (4 s, tap to dismiss, reopens on a tap of your selected Hard); the label always carries `Hard n/N`.

## 5. States
| Element | Idle | Press | Selected | Disabled | Locked | New |
|---|---|---|---|---|---|---|
| Normal segment | row 40,34,58 | `UIScale` 0.96, 0.08 s | button 108,78,196 + gold stroke 2 | during "Starting…" only (v1.2: members can pick) | — | — |
| Hard segment | row fill + 1 px danger stroke (0.6), text 255,170,180 | `UIScale` 0.96 | fill 74,28,40 + gold stroke 2 | during "Starting…" only (v1.2) | buttonDim 54,46,78, 🔒 + "Hard" / "Lv 5" muted; party lock same look | 2 gold pulses + `newDot` on first visit after Lv 5 |
| Party Hard card (v1.2) | mixed: panel + 2 px danger stroke, "n/N", member chips (H = danger stroke, N = muted) | — | all Hard: same + gold line "This run is Hard" | — | someone < Lv 5: 1 px dim stroke, dim chip, "Hard locked" | — |
| Name tag + slot (world, v1.2) | Normal: cyan ring (gold for ★) | — | Hard: danger ring + HARD chip | — | Lv < 5: "· Lv 3" after the name | — |
| Hard card | panel + 2 px danger stroke, 4 s timer line along the bottom | tile press: `UIScale` 0.96 | tile: gold stroke 3, caption shows the name | — | panel + 1 px dim stroke, level bar, silhouette tiles ("?", rarity stroke at 0.55) | — |
| Pad (world) | gold rim, violet swirl (#413) | — | Hard: rim + swirl 230,80,96 | — | — | — |
| START | gold, ink text (#412) | `UIScale` 0.96 | — | "Starting…" dim | members: "Waiting" dim (party spec) | — |
Loading: if the Hard-only list hasn't arrived, tiles show `spinner_64` (#397) and the stats line still shows. Error: server refuses Hard → segment snaps back to Normal + toast with the server text. Empty: if Config has no Hard-only items yet, row 2 says "Hard-only drops: coming soon" and no tiles.

## 6. Numbers
- Unlock: account **Lv 5** (Core Loop §5). Party: **every member** Lv 5 (Core Loop §3).
- Hard: enemies **2× HP, 1.5× damage**; **2× tokens and fragments**; **Hard-only Epic+ items** (Core Loop §3/§4). Party HP scaling still applies on top: HP × (1 + 0.3 × (players − 1)).
- All of these are Config values (Echo). Today's repo disagrees (see Sources): `Economy.DIFFICULTIES.hard.levelGate = 10`, `tokenMultiplier = 1.5`; `Rootvault.DIFFICULTIES.hard.hp = 1.5`, `level = 10`; `Progression` unlock at 10. Q2 decided: Echo aligns Config to the locked Core Loop (unlock Lv 5, 2× HP, 1.5× dmg, 2× tokens + fragments) and parks the extra rows (`medium`, `nightmare`, `insane`) behind a flag; nothing is deleted.
- Hard-only list size shown: up to 5 tiles (Epic and Legendary only). Tile order: Legendary first, then Epic, then name.
- Timings: card in 0.2 s (Quad Out), out 0.2 s, auto-fold 4 s (portrait), pad color tween 0.3 s, unlock pulse 2 × 0.4 s.
- Colors: Hard accent = danger 230,80,96 (PROVISIONAL, Kevin taste call Q4); selected text 255,170,180; selected fill 74,28,40. Tile strokes = `Rarities.COLOR` Epic 186,96,240 / Legendary 255,196,64.
- Copy: "Normal" · "Hard" · "Lv 5" · "HARD" · "2× HP · 1.5× dmg · 2× tokens/frags" · "Hard-only drops (Epic+) · tap one" · "Hard unlocks at Lv 5 · you're Lv N" · "<Name> is Lv N · all need Lv 5" · "Hard unlocks at Lv 5." · "Hard mode unlocked! Pick it at the Shard Gate." · ~~"The leader picks the difficulty."~~ (dropped in v1.2) · "This party is on Hard (Lv 5)." · "Back to Normal: Hard needs Lv 5." · "Hard ×2". v1.2: "Party 3/4 · Hard 2/3" · "Hard when all 3 pick it · 2/3" · "Waiting on Kai · else Normal" · "Everyone picked Hard. This run is Hard." · "Kai picked Normal. This run is Normal." · "Not everyone picked Hard. Starting Normal." · "Hard locked · Sam is Lv 3 · all need Lv 5".

## 7. Edge cases
- **Server authority:** the client only sends `{tier = "hard"}`; the server checks level (all members) on select and again on START. A spoofed client can't enter Hard below Lv 5 (#413 §7 Havoc risk 4).
- **Member drops below the rule mid-countdown** (a new Lv 3 joins while the party is all-Hard, v1.2): refused at the pad (decided, Q1): toast "This party is on Hard (Lv 5)." for the joiner; the party keeps Hard.
- **Leader leaves the pad:** the next member by join order becomes leader (party spec). v1.2: tiers are per player, so nothing changes; the run tier is still "all Hard → Hard".
- **Member leaves (v1.2):** if the one Normal member leaves, the rest may now all be on Hard: the party flips to Hard with the one toast. If the party was on Hard, it stays Hard.
- **Pick changes after "Starting…" (v1.2):** segments lock at "Starting…" (#412); a late tap is ignored, no toast.
- **Spoofing (v1.2):** the server only reads each player's own #430 tier; a client can't set another player's tier, and the run tier is decided on the server at START.
- **Level-up while standing on the pad:** Hard unlocks live (segment animates from locked to idle, `newDot`).
- **First-ever run (Focus mode, #412):** solo, Normal, 3 s countdown; tapping locked Hard plays the toast only.
- **Rejoin mid-run:** the run keeps its tier (run state, not save).
- **Wipe on Hard:** keep all earned loot, including the 2× payouts so far (Kevin's rule). No "Hard failed" penalty text.
- **Anti-AFK (Core Loop):** unchanged on Hard; AFK members don't get end-of-run rewards on any tier.
- **Nightmare:** not shown anywhere, not even locked (PR #418).
- **Performance:** one extra Frame + ≤ 5 ImageLabels; the pad recolor is a property tween, no new emitters.

## 8. Mockups
SVG in repo (fake data, original art, gray-box world): `mockups/01-locked-phone-390x844.svg` (Lv 3, locked card peek) · `mockups/02-hard-selected-phone-390x844.svg` (Hard selected, tile tapped, red pad) · `mockups/03-hard-landscape-667x375.svg` (party, Hard card right of the dock) · `mockups/04-party-lock-landscape-800x400.svg` (leader view, Sam is Lv 3) · `mockups/05-desktop-1280x720.svg` (keys 1 / 2 / E) · `mockups/06-directions.svg` (A/B/C). v1.2: `mockups/07-party-picks-phone-390x844.svg` (member view, Hard 2/3, waiting on Kai) · `mockups/08-party-all-hard-landscape-667x375.svg` (all Hard, red pad, one toast) · `mockups/09-party-locked-landscape-800x400.svg` (Sam Lv 3, Hard locked, Kevin's pick kept) · `mockups/10-party-picks-desktop-1280x720.svg` (4/4, Hard 3/4) · `mockups/11-per-player-directions.svg` (A/B/C). The live HUD is dashed; the keep-out is the cyan dashed box. PNG renders are on the box only.

## 9. Build split
Roadmap 5.4. Building waits for Ghost's go (and the Q2 Config alignment, decided: Echo task).
- **Echo (server + Config):** align Hard Config to the locked Core Loop and park extra rows behind a flag, nothing deleted (Q2 decided); `HARD_ONLY` drop list (Epic+); select/START level checks for every member; Hard multipliers on payouts; refuse low-level joiners on a Hard pad (Q1 decided). Tests: Lv 4 can't start Hard (also with a spoofed remote), party with one Lv 3 can't, payouts are 2×, Hard-only items never drop on Normal.
- **Echo (v1.2):** run tier = Hard only if every member's #430 tier is Hard and all are Lv 5+ (at START); party tier-flip event for the one toast; Lv < 5 joiner refused only while the party is all-Hard. Tests: mixed picks start Normal; all Hard starts Hard; a Lv 3 member forces Normal; a joiner's pick is never changed by joining; leader hand-off keeps every tier.
- **Ghost (client + world):** v1.2: members' Normal/Hard segments live, party Hard card, name tag HARD chip + slot ring color, pad recolor only when the party is all-Hard, dock label `Hard n/N`. Hard segment states, Hard card (portrait transient, landscape/desktop persistent), pad + swirl recolor, wave-counter chip, results line, unlock toast + first-visit pulse, keys 1 / 2.
- **Prism:** final copy check and a Phase S pass on the Hard accent (pad VFX, enemy rim) after the fun test.
- **Havoc:** spoofed Hard select, level-up on the pad, leader handoff while Hard is selected, low-level join during countdown.

## 10. Pass criteria (playtest)
1. At 390×844 a Lv 5+ tester switches to Hard and starts in ≤ 2 taps, and can say what Hard pays without help.
2. A Lv 3 tester taps Hard and can say what level they need and roughly how far they are.
3. Nothing enters the center keep-out at any of the 4 sizes; every tap target ≥ 44 px; START is never covered.
4. A party with one member below Lv 5 can't start Hard, and every member can see who is blocking.
4b. (v1.2) In a party of 3 with mixed picks, every tester can say within 2 s whether the run will be Hard and who it's waiting on; nobody ends up in a Hard run they didn't pick.
5. Server refuses Hard below Lv 5 even with a spoofed remote.
6. No Nightmare option appears anywhere.

## 11. Open questions (answer by number)
1. ~~@Ghost: Refuse a Lv < 5 joiner at the pad, or drop the party to Normal?~~ **Refuse at the pad (Ghost, Kevin pre-approved, Oct 24, 2026).** The joiner gets "This party is on Hard (Lv 5)."; the party keeps Hard. Board row: https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953
2. ~~@Ghost: Config task to align Hard numbers?~~ **Yes (Ghost).** Echo aligns Config to the locked Core Loop: unlock **Lv 5**, **2× HP**, **1.5× damage**, **2× tokens + fragments**. Extra rows (`medium`, `nightmare`, `insane`) are parked behind a flag; nothing is deleted. Prism still doesn't touch Config.
3. ~~@Ghost: Remember the last tier?~~ **Session only (Ghost).** No save write; every join starts on Normal.
4. **@Kevin (taste, open):** Hard accent color. **PROVISIONAL (Prism recommendation, used in the mockups until Kevin decides):** danger red 230,80,96. Alternative: a deep violet closer to the shard palette.
5. **@Kevin (taste, open):** Locked players see Hard-only drops as silhouettes, or hide the list until Lv 5? **PROVISIONAL (Prism recommendation):** silhouettes (rarity stroke + "?"), a reason to level.
6. ~~@Ghost: Portrait Hard card over the thumbstick zone for up to 4 s?~~ **Yes (Ghost), same rule as the #416 4 s tray:** tap-to-dismiss, `Active = false` outside the tiles, never over a combat button. Provisional until Kevin's phone playtest.

7. **@Kevin (v1.2):** The locked V1 Core Loop §3 says "Leader picks Normal or Hard". #430 (Havoc P2-430-1) and this v1.2 make it "everyone picks; the run is Hard only when all picked Hard". OK to update the Core Loop wording (Kevin edits locked pages, Prism doesn't)? Recommended: yes.
8. **@Ghost (v1.2):** A Lv 5+ player joins an all-Hard party while on Normal: keep their pick (the party drops to Normal until they tap Hard; their Hard segment pulses twice) or auto-adopt Hard on join? Recommended: keep their pick (matches #430: joining never flips a pick); the leader can use Friends-only to avoid randoms.
9. **@Ghost (v1.2):** Keep a player's pick across runs in the same server session (recommended, matches #430 session memory and makes Run Again keep Hard), or reset to Normal after every run?

Ghost's v1.1 questions are all answered. Open: Kevin Q4, Q5 (taste) and Q7 (Core Loop wording); Ghost Q8, Q9 (v1.2). The spec runs on the recommended picks until answered.

## Decision log
- 2026-10-24 (Prism): v1 published. Recommends direction A (dock toggle + Hard card). Six open questions (Ghost 1, 2, 3, 6; Kevin 4, 5). Not approved.
- 2026-10-24 (Ghost, Kevin pre-approved; Kevin can change later; board row https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953): Q1 = refuse Lv < 5 joiners at the pad. Q2 = yes, Echo aligns Config to the locked Core Loop (Lv 5, 2× HP, 1.5× dmg, 2× tokens + fragments), extra rows parked behind a flag, nothing deleted. Q3 = session only, Normal on join. Q6 = yes, #416 tray rule (tap-to-dismiss, never over combat buttons), provisional until Kevin's phone playtest. → v1.1.
- 2026-10-24 (Prism): Kevin taste calls Q4 (Hard accent: red 230,80,96) and Q5 (locked drops as silhouettes) recorded as PROVISIONAL recommendations, waiting for Kevin.
- 2026-10-24 (Prism, Ghost GO, board row https://app.notion.com/p/403c31ca3883819d821fe59c27a3d730 answer 8, Kevin pre-approved): **v1.2** per-player Hard pick from #430 / P2-430-1. Recommends direction A (everyone picks, Hard when all agree). Default Normal on server join, pick kept for the session; HARD chip on name tags + red slot ring; pad goes red only when the whole party is Hard; party Hard card + `Hard n/N` label; one toast on a party tier flip; Q1 joiner rule re-read for per-player. Supersedes "leader picks" in this spec and step 5 of the party gather spot spec. New mockups 07–11. New questions 7 (Kevin), 8–9 (Ghost). Not approved.

## Later (not V1)
Nightmare / Mythic tiers (Ideas Backlog, NOT APPROVED), per-tier best-wave badges, Hard-only cosmetic pad trails (never power), a "Hard clears" counter on the results screen.

## Roblox build notes
Stock Roblox UI only. No blur or glassmorphism, no soft shadows, no web fonts (Builder Sans / GothamSSm). `ParticleEmitter` only in world space; UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Hard segment | `TextButton` (AutoButtonColor false) + `UICorner` 8 + `UIStroke` 2 (gold when selected, danger 0.6 transparency idle) + `TextLabel` "Hard" + `ImageLabel` lock_icon (locked) + `TextLabel` "Lv 5" + `UIScale` (press 0.96) |
| Hard card | `Frame` HardCard (panel 28,24,40, `Active = false`) + `UICorner` 10 + `UIStroke` 2 danger (locked: 1 dim) + HARD chip `Frame` (`UICorner` h/2) + `TextLabel`s (TextScaled false, 11–12 px) + timer `Frame` 2 px (Size tween 1 → 0 over 4 s, portrait only) |
| Level bar (locked) | `Frame` 6 px (`UICorner` h/2, dim) + inner `Frame` gold, Size = (level − 1) / 4 |
| Drop tiles | `ScrollingFrame` (horizontal, `AutomaticCanvasSize` X, ScrollBarThickness 0) + `UIListLayout` Horizontal Padding 6 + tile `ImageButton` 44×44 + `UICorner` 8 + `UIStroke` 2 (`Rarities.COLOR`) + `UIGradient` top sheen (tier → panel) + icon `ImageLabel`; locked: icon ImageColor3 0,0,0 at 0.6 + "?" `TextLabel` |
| Card motion | TweenService: Position offset +16 → 0 and `GroupTransparency` via `CanvasGroup` 1 → 0, 0.2 s Quad Out; no Heartbeat |
| Pad recolor | Gate pad rim `Part.Color` + swirl `Texture`/`Beam` Color tween 0.3 s; arch inner glow `PointLight` Color (Shadows false) |
| Input | `ContextActionService`: 1 = Normal, 2 = Hard, E = START (desktop), gamepad shoulder buttons cycle; touch = the buttons |
| Party Hard card (v1.2) | reuse the HardCard Frame; member chips = `Frame` 22 tall + `UICorner` 6 + `UIStroke` 1.5 (danger for H, muted for N) + `TextLabel` 10 px in a `UIListLayout` Horizontal; text from party state (server event), no Heartbeat |
| Name tag pick chip (v1.2) | inside each slot's `BillboardGui`: `Frame` 32×12 + `UICorner` 6 + danger fill + `TextLabel` "HARD" 8 px ink; `Visible` from the member's tier attribute (e.g. `ShardfallTier` on the player, server-set); slot ring `Part.Color` tween 0.2 s |
| Wave chip / results | `Frame` + `UICorner` h/2 + `TextLabel` "HARD" (danger fill, ink text) |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| lock_icon, spinner_64 | as in #397 / #412 | reused |
| hard_chip_skull_32 (optional) | 32×32 | Hard chip glyph; V1 can ship text-only |
| Hard-only item icons | 128×128 | from the item art pipeline (Config list) |
