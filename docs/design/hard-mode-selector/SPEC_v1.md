# Hard Mode Selector ("Gate dock toggle + Hard card"), Spec v1

Owner: Prism (design, docs only, no code). Builders: Ghost (Gate dock UI, world tint), Echo (server checks, Config, Hard-only drop list). Base: `cursor/live-build-9721`. Status: proposal, gray-box only (pre-Phase S). Nothing here is approved until Ghost/Kevin say so.
Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca38838192b465db2fbca4fda1, item 1, from canvas item **M14**: "Hard mode selector UX spec (unlocks Lv 5, 2x HP, 1.5x dmg, 2x tokens/fragments, Hard-only Epic+ list; locked state, phone first)". Roadmap **5.4 Hard mode (Lv 5)**.

Sources (link, don't copy):
- Locked: V1 Core Loop §3 Party & Run Setup ("Leader picks Normal or Hard (only tiers all members have unlocked)", "Hard ≈ 2× HP, 1.5× damage"), §4 Dungeon Rewards ("Hard: 2× tokens/fragments + Hard-exclusive Epic+ items"), §5 Progression ("Lv5: Hard mode"), §7 ("Clear Normal to unlock Hard" goal text). Vision & Design Rules, Oct 23, 2026: "Hard mode is V1 (unlocks at Lv 5). Nightmare is not V1."
- Gate: V1 gates are **Normal + Hard (Lv 5) only, no Nightmare** (PR #418, `docs/design/DUNGEON_GATE_PLAZA.md`).
- Specs this builds on: #412 first 30 seconds (the **Gate dock**: bottom-center slot, chevron, Normal, 🔒 Hard "Lv 5", START; "Hard unlocks at Lv 5." toast); #413 Crater Square (Gate pad (0, 98) Ø16, arch (0, 108)); #414 Shard Crater (arena); #420 phone layout review (keep-out, D1 portrait top 35%, D2 hub cluster hides under the Gate dock, D3 one toast lane); party gather spot spec (this same batch, `docs/design/party-gather-spot/`).
- Repo (read-only check): `Shared/Rarities.luau` `Rarities.COLOR` (Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64). **Mismatch found:** `Shared/Config/Economy.luau` `DIFFICULTIES.hard` = `tokenMultiplier 1.5, levelGate 10` (plus `medium`, `nightmare`, `insane` rows); `Shared/Rootvault.luau` `DIFFICULTIES.hard` = `hp 1.5, damage 1.5, level 10`; `Shared/Progression.luau` unlock `level 10 "Hard Rootvault"`. The Core Loop says Lv 5, 2× HP, 1.5× damage, 2× tokens/fragments. The repo is what runs, so this is logged as Q2, not changed here.
- Chrome: PR #392 `docs/ui/reference/STYLE.md` (panel 28,24,40 · row 40,34,58 · button 108,78,196 · gold 255,196,64 · danger 230,80,96 · corners 8/10/12 · strokes 1/2 · Builder Sans). Style Bible v0 (#424, NOT APPROVED) state table: Locked = padlock + muted label.

## 0. Directions (pick one) and recommendation
Mockup: `mockups/06-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Dock toggle + Hard card** | The #412 Gate dock already has Normal and Hard. Tapping Hard selects it and shows a small **Hard card** next to the dock for 4 s: the deal (2× HP · 1.5× dmg · 2× tokens/frags) and a row of Hard-only Epic+ drop tiles. Locked Hard shows the same card dimmed, with a level bar and silhouette tiles. | 1 tap, no new world parts, works the same solo and in a party (the leader picks), the locked card is a clear "why level up" teaser. Fits the bottom slot the dock already owns. | The portrait card briefly overlaps the thumbstick zone (see §4, Q6). |
| B | Twin pads | Two pads side by side at the Gate: Normal pad and Hard pad (locked pad has a seal). | Very readable in the world; no screen UI. | Doubles the lobby, splits parties across two pads, clashes with the party gather spot (T4) and with #413's one-pad hub. Hard's rewards can't be shown without UI anyway. |
| C | Picker sheet | Stepping on the pad opens two big cards (Normal / Hard) in the middle of the screen. | Very clear, room for the drop list. | Sits in the center keep-out, adds a tap every run, fights Kevin's "panels stay off center" rule. |

**Recommendation: A.** It reuses the dock players already learned in their first 30 seconds, adds one small card, and keeps the screen center clear. The rest of this spec is A.

## 1. Goal
At the Shard Gate, a player who has reached Lv 5 can pick Hard in one tap and understands, in under 2 seconds, what it costs (enemies 2× HP, 1.5× damage) and what it pays (2× tokens and fragments, Hard-only Epic+ drops). A player below Lv 5 sees exactly what Hard is and how far away it is, so locked Hard works as a goal instead of a dead button.

## 2. Where it lives
- **Screen (Ghost):** inside the existing #412 **Gate dock** (bottom-center slot, shown only while on the Gate pad). New: the Hard segment's states (§5), a **Hard card** (`HardCard` Frame, sibling of the dock), and the dock label text. Built in the same ScreenGui as the dock (`CoreUISafeInsets`).
- **World (Ghost):** the Gate pad rim and the arch swirl switch to the Hard accent (danger 230,80,96) while Hard is selected (#413 states: idle / on pad / countdown). The arch subline gains `· Hard` at Lv 5 (PR #418 rule).
- **Arena (Ghost):** one "HARD" chip on the run's wave counter (future #417) and one "Hard ×2" line on the results screen. No other arena UI.
- **Server (Echo):** level check on select and again on START; party rule (all members Lv 5); the Hard-only Epic+ drop list in Config (proposed `Shared/Config/Loot.luau` `HARD_ONLY`, read by the client for the tiles). Nothing new is saved: the selection is per pad visit (Q3).
- **Not here:** Nightmare (not V1, no UI, no greyed third option), Robux, passes, boosts. Hard is earned by level only.

## 3. Flow
| Step | Trigger | What the player sees / does | Server |
|---|---|---|---|
| 1 | Step on the Gate pad | Gate dock rises (0.26 s, #412). **Normal** is selected by default. Label "Shard Gate · Solo · starts in 15". | open pad session |
| 2a | Lv ≥ 5, tap **Hard** | Hard turns selected (gold 2 px stroke, red text). Pad rim + swirl tween to red (0.3 s). **Hard card** slides in (0.2 s): HARD chip, "2× HP · 1.5× dmg · 2× tokens/frags", 5 Hard-only drop tiles. Label adds "· HARD". | validate level (party: every member) |
| 2b | Tap a drop tile | The caption line becomes "<name> · <tier> · Hard only" (tile gets a gold stroke). No popup. | — |
| 2c | 4 s pass, or tap the card, or tap Hard again | Portrait: the card folds away (0.2 s); tapping the selected Hard reopens it. Landscape/desktop: the card stays while Hard is selected and folds with its own chevron. | — |
| 3 | Tap **Normal** | Normal selected, pad back to gold, card folds. | — |
| 4 | START (or countdown ends) | "Starting…" (#412). Teleport to the arena with the chosen tier. | **re-check** level (and every party member) on START; if it fails, start Normal and send toast "Back to Normal: Hard needs Lv 5." |
| 5 | In the run | Wave counter shows a small "HARD" chip (danger fill). Enemies use Hard Config (2× HP, 1.5× damage). | Hard Config |
| 6 | Results | Extra line "Hard ×2" next to tokens and fragments; Hard-only drops show a small "HARD" tag on their tile. | grant 2× tokens/frags, roll Hard-only list |

**Locked flow (Lv < 5):** the Hard segment shows 🔒 "Hard · Lv 5" (#412). Tap it: the **locked card** peeks for 4 s: "Hard unlocks at Lv 5 · you're Lv 3", a gold level bar, and the 5 drop tiles as silhouettes (rarity stroke + "?"). Tap the card or wait 4 s to fold it. **In #412 Focus mode (first-ever run)** the card is skipped and only the existing toast "Hard unlocks at Lv 5." plays, so the first 30 seconds stay simple.

**Party flow (leader):** only the leader can switch. If any member is below Lv 5, Hard is locked for the party: the card says "Sam is Lv 3 · all need Lv 5" (lowest member named; if several, "2 players are below Lv 5"). **Members** see the leader's pick read-only (segments at 60% opacity); tapping one gives the toast "The leader picks the difficulty." While Hard is selected, a player below Lv 5 who steps on the pad is refused at the pad (recommended, Q1) and gets the toast "This party is on Hard (Lv 5)."

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
| Toasts | one toast lane (#420 §4a): x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |

Rules:
- Every tap target ≥ 44 px (segments 44 tall, tiles 44×44, START 48 tall). Text ≥ 13 px except caption/badges 11 (#420 R7).
- **Portrait thumbstick:** the card covers x 88–198 of the thumbstick zone (x 16–198, y 640–794) for at most 4 s, the same way the #412 dock already sits over it. The card Frame is `Active = false`, so a touch that misses a tile still reaches the thumbstick; only the tiles are buttons. It never covers the dock, START, or any combat button (the combat cluster is hidden on the pad, D2). Ghost to confirm, Q6 (same rule Ghost set for the #416 tray).
- The card never covers the live currency pills or HP block (portrait y 115–227, landscape y 68–132).
- The card opens **next to** the dock, never as a modal, and never blocks START.

## 5. States
| Element | Idle | Press | Selected | Disabled | Locked | New |
|---|---|---|---|---|---|---|
| Normal segment | row 40,34,58 | `UIScale` 0.96, 0.08 s | button 108,78,196 + gold stroke 2 | member view: 60% opacity | — | — |
| Hard segment | row fill + 1 px danger stroke (0.6), text 255,170,180 | `UIScale` 0.96 | fill 74,28,40 + gold stroke 2 | member view: 60% opacity | buttonDim 54,46,78, 🔒 + "Hard" / "Lv 5" muted; party lock same look | 2 gold pulses + `newDot` on first visit after Lv 5 |
| Hard card | panel + 2 px danger stroke, 4 s timer line along the bottom | tile press: `UIScale` 0.96 | tile: gold stroke 3, caption shows the name | — | panel + 1 px dim stroke, level bar, silhouette tiles ("?", rarity stroke at 0.55) | — |
| Pad (world) | gold rim, violet swirl (#413) | — | Hard: rim + swirl 230,80,96 | — | — | — |
| START | gold, ink text (#412) | `UIScale` 0.96 | — | "Starting…" dim | members: "Waiting" dim (party spec) | — |
Loading: if the Hard-only list hasn't arrived, tiles show `spinner_64` (#397) and the stats line still shows. Error: server refuses Hard → segment snaps back to Normal + toast with the server text. Empty: if Config has no Hard-only items yet, row 2 says "Hard-only drops: coming soon" and no tiles.

## 6. Numbers
- Unlock: account **Lv 5** (Core Loop §5). Party: **every member** Lv 5 (Core Loop §3).
- Hard: enemies **2× HP, 1.5× damage**; **2× tokens and fragments**; **Hard-only Epic+ items** (Core Loop §3/§4). Party HP scaling still applies on top: HP × (1 + 0.3 × (players − 1)).
- All of these are Config values (Echo). Today's repo disagrees (see Sources): `Economy.DIFFICULTIES.hard.levelGate = 10`, `tokenMultiplier = 1.5`; `Rootvault.DIFFICULTIES.hard.hp = 1.5`, `level = 10`; `Progression` unlock at 10. Q2.
- Hard-only list size shown: up to 5 tiles (Epic and Legendary only). Tile order: Legendary first, then Epic, then name.
- Timings: card in 0.2 s (Quad Out), out 0.2 s, auto-fold 4 s (portrait), pad color tween 0.3 s, unlock pulse 2 × 0.4 s.
- Colors: Hard accent = danger 230,80,96 (proposal, Q4); selected text 255,170,180; selected fill 74,28,40. Tile strokes = `Rarities.COLOR` Epic 186,96,240 / Legendary 255,196,64.
- Copy: "Normal" · "Hard" · "Lv 5" · "HARD" · "2× HP · 1.5× dmg · 2× tokens/frags" · "Hard-only drops (Epic+) · tap one" · "Hard unlocks at Lv 5 · you're Lv N" · "<Name> is Lv N · all need Lv 5" · "Hard unlocks at Lv 5." · "Hard mode unlocked! Pick it at the Shard Gate." · "The leader picks the difficulty." · "This party is on Hard (Lv 5)." · "Back to Normal: Hard needs Lv 5." · "Hard ×2".

## 7. Edge cases
- **Server authority:** the client only sends `{tier = "hard"}`; the server checks level (all members) on select and again on START. A spoofed client can't enter Hard below Lv 5 (#413 §7 Havoc risk 4).
- **Member drops below the rule mid-countdown** (a new Lv 3 joins while Hard is selected): refused at the pad (Q1 recommended). Alternative if Ghost prefers: the party falls back to Normal and the leader gets the toast "Back to Normal: Sam is Lv 3."
- **Leader leaves the pad:** the next member by join order becomes leader (party spec); the tier stays as picked if everyone still qualifies, else falls back to Normal.
- **Level-up while standing on the pad:** Hard unlocks live (segment animates from locked to idle, `newDot`).
- **First-ever run (Focus mode, #412):** solo, Normal, 3 s countdown; tapping locked Hard plays the toast only.
- **Rejoin mid-run:** the run keeps its tier (run state, not save).
- **Wipe on Hard:** keep all earned loot, including the 2× payouts so far (Kevin's rule). No "Hard failed" penalty text.
- **Anti-AFK (Core Loop):** unchanged on Hard; AFK members don't get end-of-run rewards on any tier.
- **Nightmare:** not shown anywhere, not even locked (PR #418).
- **Performance:** one extra Frame + ≤ 5 ImageLabels; the pad recolor is a property tween, no new emitters.

## 8. Mockups
SVG in repo (fake data, original art, gray-box world): `mockups/01-locked-phone-390x844.svg` (Lv 3, locked card peek) · `mockups/02-hard-selected-phone-390x844.svg` (Hard selected, tile tapped, red pad) · `mockups/03-hard-landscape-667x375.svg` (party, Hard card right of the dock) · `mockups/04-party-lock-landscape-800x400.svg` (leader view, Sam is Lv 3) · `mockups/05-desktop-1280x720.svg` (keys 1 / 2 / E) · `mockups/06-directions.svg` (A/B/C). The live HUD is dashed; the keep-out is the cyan dashed box. PNG renders are on the box only.

## 9. Build split
Roadmap 5.4. Building waits for Ghost's go (and the Q2 Config fix).
- **Echo (server + Config):** align Hard Config to the Core Loop (Q2); `HARD_ONLY` drop list (Epic+); select/START level checks for every member; Hard multipliers on payouts; refuse low-level joiners on a Hard pad (Q1). Tests: Lv 4 can't start Hard (also with a spoofed remote), party with one Lv 3 can't, payouts are 2×, Hard-only items never drop on Normal.
- **Ghost (client + world):** Hard segment states, Hard card (portrait transient, landscape/desktop persistent), pad + swirl recolor, wave-counter chip, results line, unlock toast + first-visit pulse, keys 1 / 2.
- **Prism:** final copy check and a Phase S pass on the Hard accent (pad VFX, enemy rim) after the fun test.
- **Havoc:** spoofed Hard select, level-up on the pad, leader handoff while Hard is selected, low-level join during countdown.

## 10. Pass criteria (playtest)
1. At 390×844 a Lv 5+ tester switches to Hard and starts in ≤ 2 taps, and can say what Hard pays without help.
2. A Lv 3 tester taps Hard and can say what level they need and roughly how far they are.
3. Nothing enters the center keep-out at any of the 4 sizes; every tap target ≥ 44 px; START is never covered.
4. A party with one member below Lv 5 can't start Hard, and the leader can see who is blocking.
5. Server refuses Hard below Lv 5 even with a spoofed remote.
6. No Nightmare option appears anywhere.

## 11. Open questions (answer by number)
1. **@Ghost:** While Hard is selected, refuse a player below Lv 5 at the pad (recommended: protects the leader's choice), or drop the whole party back to Normal?
2. **@Ghost:** The repo's Hard numbers don't match the Core Loop (Lv 10 vs 5, 1.5× vs 2× tokens, 1.5× vs 2× HP, plus `medium` / `nightmare` / `insane` rows). Should Echo get a Config task (GitHub issue) to align them? Prism didn't touch Config.
3. **@Ghost:** Remember the last tier for the session only (no save write), defaulting to Normal on join? Recommended: yes, session only.
4. **@Kevin (taste):** Hard accent color: danger red 230,80,96 (recommended, reads as "harder" at a glance) or a deep violet that stays closer to the shard palette?
5. **@Kevin (taste):** Show locked players the Hard-only drops as silhouettes (recommended, a reason to level) or hide the list until Lv 5?
6. **@Ghost:** On portrait the Hard card covers part of the thumbstick zone (x 88–198) for up to 4 s, tap-to-dismiss, `Active = false` outside the tiles. OK under the same rule as the #416 tray (provisional until Kevin's phone playtest)?

## Decision log
- 2026-10-24 (Prism): v1 published. Recommends direction A (dock toggle + Hard card). Six open questions (Ghost 1, 2, 3, 6; Kevin 4, 5). Not approved.

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
| Wave chip / results | `Frame` + `UICorner` h/2 + `TextLabel` "HARD" (danger fill, ink text) |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| lock_icon, spinner_64 | as in #397 / #412 | reused |
| hard_chip_skull_32 (optional) | 32×32 | Hard chip glyph; V1 can ship text-only |
| Hard-only item icons | 128×128 | from the item art pipeline (Config list) |
