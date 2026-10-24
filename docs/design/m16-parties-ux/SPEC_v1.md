# M16 Parties UX (1–4 players), Spec v1.1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no Config, no flag flips, no save edits). Builders: Echo (party server state, HP scaling, AFK rule, flags), Ghost (Gate dock label, wave chip badge, toasts, results line). Base: `cursor/live-build-9721` @ `581c995`. Status: **v1.1, Q1–Q7 decided by Ghost under Kevin's pre-approval (DP34P https://app.notion.com/p/403c31ca388381fea022e68f6cc3fd35, ACK https://app.notion.com/p/403c31ca3883815f8aa3ffeff8eda432).** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there. Gray-box UI only (pre-Phase S). **All new feature flags default off.**
Asked for in: Ghost's Agent Board row DP31P https://app.notion.com/p/403c31ca388381feb52fdb6685c444a5 (Oct 24, 2026, Kevin pre-approved), part 2: "M16 parties UX spec (1–4 players): party join flow at the T4 gather spot, Friends-only toggle, HP scaling readout ×(1+0.3×(n−1)), personal loot display, anti-AFK warning (damage in 3 of 5 waves)." ACK: https://app.notion.com/p/403c31ca3883813bb703cccb4dc0e0fa.

**What this extends (link, don't copy; nothing here contradicts them):**
- **#441 Party gather spot "Gate Ring" v1.1** (`prism/party-gather-spot`, `docs/design/party-gather-spot/SPEC_v1.md`): the join flow, 4 slots on the Gate pad (0, 98), slot 1 = leader, leader handoff by join order, 15 s countdown + 5 s late-join bump, no ProximityPrompt within r 12, Friends-only toggle 44×44 (leader only, default OFF PROVISIONAL, Kevin #441 Q2), Muster flagged off. **M16 reuses all of it unchanged** and only adds the HP readout to the dock label.
- **#429 Results + Run Again** (M12) + **#455** (Echo's server `RunResults` payload, flag `m12Results` off): personal `RunResults` snapshot per player, loot list built only from server-recorded grants, party RUN AGAIN goes back through the Gate pad countdown.
- **#428 Wave HUD** (wave chip in the #420 top-left stack, boss bar on wave 5, HARD chip inside the chip), **#420** phone layout review (center keep-out, D3 one toast lane, loot outranks info), **#437** Hard mode selector (Hard needs Lv 5), **#413 / T7** Crater Square (Gate pad, return pad (14, 30)), **#414** Shard Crater arena.
- Locked V1 Core Loop §3 (read only): "Party: 1–4 players, solo allowed", "Lobby: one Shard Gate pad", "Friends-only toggle; no queue", "3–4 arena copies on the same server", personal loot. Roadmap Phase 6: run and party state in memory only.

**Repo read (read only; repo wins).** `Shared/Rarities.luau` `COLOR`: Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64. `Shared/LaunchGate.luau` `SHOW`: no party, HP-scale or AFK flag exists today. `Shared/DungeonConfig.luau`: the old boss-HP scaling from #362 was closed and not carried over, so **there is no live party HP scaling**; this spec's formula is new. `ShardfallServer/EchoParty.luau` is the raid/Story Echo backfill helper (not the Gate party; untouched). UI chrome: PR #392 `docs/ui/reference/STYLE.md` via `mocklib` (panel 28,24,40, row 40,34,58, gold 255,196,64, cyan 120,210,255, ok 110,210,140, danger 230,80,96, muted 176,168,198).

---

## 0. Taste calls (DECIDED v1.1: HP readout **A**, AFK outcome **A**)
Mockup `01-flow-scaling-options.svg` (bottom half).

**HP scaling readout**
| | Option | Good | Bad |
|---|---|---|---|
| **A (DECIDED, Q6)** | **Cyan "×1.6" badge** in the Gate dock party label (hub) and inside the #428 wave chip / boss bar (arena) | Same number everywhere, 1 glance, mirrors the HARD chip pattern, explains "why is this enemy tanky" | One more 40×18 element in the chip |
| B | Dock only (hub), nothing in the arena | Cleanest arena HUD | Players forget it once the fight starts; leaving mid-run changes HP with no readout |
| C | Words, no number ("Enemies tougher (3 players)") | Friendly for young players | Hides the ×1.3 / ×1.6 / ×1.9 steps the spec asks to show; longer text on phones |

**What happens at the 3rd missed wave (AFK)**
| | Option | Good | Bad |
|---|---|---|---|
| **A (DECIDED, Q1)** | **Hold the payout:** player stays in the run, drops already granted stay (keep-earned rule), no later drops, no end-of-run tokens/fragments/boss clear; stops counting for HP scaling | No kicking, no teleport mid-run, fair to the 3 players who did fight; can't be farmed by idling | AFK player may still stand around (harmless; they don't add HP) |
| B | Send to hub at the 3rd miss | Clear consequence | Teleport mid-run is jarring for a kid who was just slow / lagging; harder to test |
| C | Warn only, never penalize (just stop counting for HP) | Gentlest | Idling in a friend's party still pays out (farm risk) |

Personal loot (each player sees their own drops) is a Core Loop rule, not a taste call; Q2 decided: **no** teammate Legendary toast in V1 (idea stays in Later, NOT APPROVED).

## 1. Goal
Up to 4 friends gather at the Shard Gate in one step (#441), see **before and during** the run how much tougher enemies get for their party size (×1.0 / ×1.3 / ×1.6 / ×1.9), each see only **their own** drops, and an idle player gets two clear, friendly warnings before they lose the run payout. Solo play and the first 30 seconds (#412) are unchanged; with the flags off nothing on screen changes.

## 2. Where it lives
- **Hub (Ghost):** the #412 / #441 Gate dock. M16 adds only the cyan `×N` badge to the party label row ("Party 3/4 · Enemy HP ×1.6 · starts in 9" + pips). Friends-only toggle, slots, name tags, countdown: as #441.
- **Arena (Ghost):** the #428 `WaveChip` gets the same badge (party only); the wave-5 `BossBar` carries it too. Anti-AFK uses the chip's stroke + a small "!" + the D3 toast lane; no new panel, no new toast host.
- **Results (Ghost on #429, Echo on #455):** the loot wing title reads "YOUR LOOT · N items"; an AFK-flagged player sees one amber line in the stats wing instead of the payout lines.
- **Server (Echo):** party size `n` per arena copy, HP multiplier at each wave start, per-player "wave counted" tracking, AFK flag, `RunResults` gets `party = { n, mult, afk, wavesCounted }`. In memory only, nothing saved (schema unchanged).
- **Flags (Q7 decided: three flags; Echo owns `LaunchGate`, Prism edits nothing):** `parties` (multi-player arena copy from the Gate pad + dock party label), `partyHpScale` (formula + badge), `afkCheck` (rule + warnings + payout hold). **All default `false`.** Off = today's solo Gate pad.
- **Not here:** invites / friends list UI, chat, trading, need/greed rolls, matchmaking queue (Core Loop: no queue), any Robux item. No pay-to-win: nothing bought changes party HP, AFK rules or drops.

## 3. Flow
| Step | Trigger | What players see | Server |
|---|---|---|---|
| 1 | First player steps on the Gate pad | #441 step 1 (slot 1 gold, name + ★, dock rises). Label: "Shard Gate · Solo · starts in 15" (no badge solo). | party n = 1 |
| 2 | 2nd–4th player joins | #441 step 2. Label becomes "Party n/4 · Enemy HP **×1.3/×1.6/×1.9** · starts in N"; the badge pulses once (`UIScale` 1 → 1.1 → 1, 0.2 s). | n, mult (preview) |
| 3 | Leader taps Friends-only | #441 step 3/4 (ON = ok-green, non-friends refused with their own toast). Badge unaffected. | flag |
| 4 | START / countdown ends | #441 step 6: all teleport into one arena copy. Wave chip shows the badge for n ≥ 2. Toast (info): "Party ×1.6: 3 players, enemies are tougher" once, wave 1 only. | lock n for wave 1 |
| 5 | Each wave start | Server recomputes n = connected, non-AFK players in the copy; enemies of that wave spawn with HP × (1 + 0.3 × (n − 1)). If it changed: badge pulses + toast "Party ×1.3: Mika left, enemies get weaker next wave". **Never changes mid-wave** (no HP jumps on living enemies). | mult per wave |
| 6 | Drops | Your drop orbs render on **your** client only; pickup toast "Epic drop: <name>" for you only (D3 lane, loot priority). Teammates' drops never replicate to you. | per-player grants (as today) |
| 7 | Wave ends with no damage from you (`afkCheck` on, n ≥ 2) | **Miss 1:** a 5-pip "hit" row appears under the chip text (green = counted, gray = missed). No toast. | wavesMissed 1 |
| 8 | **Miss 2** | Chip stroke turns amber 2 px + "!" for the whole next wave. Toast at that wave's start: "Hit an enemy this wave to keep your rewards". If still no damage 20 s into the wave, the toast repeats once. Tapping the chip repeats the line. | wavesMissed 2 |
| 9 | **Miss 3** (3 of 5 now impossible) | Badge swaps for a gray "AFK" tag. Toast once: "No damage for 3 waves. No run rewards this time." Player stays in the run and can keep playing (Q1 decided: A, payout held). | afk = true; excluded from n from the next wave; later drops and end payout withheld |
| 10 | Run ends | #429 wings. Stats wing shows the badge; loot wing "YOUR LOOT · N items" (this player's `RunResults` only). AFK player: amber line "No run rewards: damage in 2 of 5 waves. Drops you got stay." instead of Roll Tokens / Fragments / boss clear. RUN AGAIN (party) → Gate pad countdown (#429 Q1). | `RunResults.party` |

**"A wave counts"** (server): the player dealt ≥ 1 damage to any enemy in that wave (boss + adds on wave 5), **or** was down/respawning for more than 50% of it (being knocked out is not AFK; **Q3 decided: such a wave is NOT a miss**). Need 3 of 5. Warn at 2 misses, AFK at 3. **Q4 decided: parties only**: the check runs only when the run starts with n ≥ 2 and stops if the party drops to 1; solo never.

## 4. Layout
Full-screen px, #420 frame. **Center keep-out:** 390×844 x 117–273, y 296–616 · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. **Nothing in this spec enters it.**

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Gate dock (#441, unchanged) | x 16–374, y 738–802 | x 174–492, y 301–361 | x 230–570, y 326–386 | x 430–850, y 632–696 |
| Party label row (+ badge) | x 16–374, y 700–732: "Party 3/4 · Enemy HP" 12 px, badge 40×18 at x 160, "· starts in 9", pips at x 322 | y 270–296 over the dock, same order | y 296–322 | y 600–628, keys hint "1 / 2 / F / E" |
| Wave chip (#428) + badge | chip x 16–150, y 179–223; badge 40×18 inside at the chip's right (x 102–142, y 185–203) | chip x 61–197, y 132–176; badge x 149–189 | chip x 66–222; badge x 174–214 | chip x 88–268, y 138–182; badge x 220–260 |
| Boss bar (wave 5) + badge | in the chip row x 16–206; badge replaces the "adds" sub-line's right end | top band x 160–403, y 8–48; badge at the right end | top band x 200–516 | x 440–840, y 110–150; badge x 780–820 |
| Hit pips (miss ≥ 1) | 5 × 5 px dots, gap 9, inside the chip under the bar (y 216–221) | same, inside the chip | same | same |
| AFK "!" | 16 px amber circle inside the chip, left of the badge | same | same | same |
| AFK / party toasts | D3 lane x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |
| Results (#429 wings) | stats wing y 107–287, loot wing y 620–802 | left / right wings | x 16–232 / x 568–784 | x 16–368 / x 912–1264 |
| AFK results line | stats wing, replaces the token + fragment lines (2 lines, 11 px amber) | same | same | same |

Checks: the chip and boss bar don't grow (badge sits inside them); chip right edges 150 / 197 / 222 / 268 all stay left of the keep-out (200 / 240 / 384 on landscape/desktop; portrait chip is above y 296). The only tappable pieces are the existing 44 px dock buttons, the 44×44 Friends toggle and the 44-tall chip (tap = repeat the AFK line / fold, #428). Badge, pips and "!" are display-only. Dock and wings collapse via their existing chevrons (#412 / #429); the chip folds to a 44×44 badge (#428) that keeps the amber stroke when warned.

## 5. States
| Element | Off / solo | Party | Warned | AFK | Loading |
|---|---|---|---|---|---|
| ×N badge | hidden (×1.0 baseline) | cyan 120,210,255 1.2 px stroke, text cyan 10 px heavy, fill bg 16,14,24 | unchanged | replaced by gray "AFK" tag (dim 54,46,78 fill, muted text) | "×–" until the server value arrives |
| Wave chip stroke | cyan 1.2 px (#428) | same | amber 255,170,60, 2 px + "!" | live gray 150,150,170 | #428 |
| Hit pips | hidden | hidden until miss 1 | 1–2 gray | 3 gray | — |
| Toasts | — | info, cyan stroke | amber stroke | muted stroke | — |
| Results line | — | "Party of 3 · your run" muted | — | amber 2 lines, no payout lines | "Results are on the way…" (#429) |
| Drop orbs | yours | yours only | yours | none after the flag | — |
Interaction: badge pulse `UIScale` 1 → 1.1 → 1 (0.2 s) on change; chip stroke color tween 0.2 s; "!" pops `UIScale` 0 → 1 (0.15 s, Back Out). Hard runs: HARD chip and ×N badge both show (HARD left, badge right); Hard's own 2× HP (#437/#430) multiplies with the party multiplier (Q5).

## 6. Numbers
- Party size 1–4 (Core Loop). Enemy HP multiplier = **1 + 0.3 × (n − 1)**: **1p ×1.0 · 2p ×1.3 · 3p ×1.6 · 4p ×1.9**. Applies to every enemy spawned in the wave, boss included (Q5). Badge text: one decimal ("×1.3").
- Work per player (base enemy HP share): 1p 1.0 · 2p 0.65 · 3p 0.53 · 4p 0.475, so friends always clear a bit faster than solo (the point of partying).
- n = connected, non-AFK players in the arena copy **at each wave start**; locked for that wave.
- Anti-AFK: need damage in **3 of 5** waves. Warn at 2 misses, AFK at 3. Mid-wave repeat toast at **20 s** with no damage (once per wave). Down for over 50% of a wave = present, not a miss (Q3 decided). Parties only, solo off (Q4 decided).
- Timings: badge pulse 0.2 s, stroke tween 0.2 s, "!" pop 0.15 s, toasts 2.5 s (D3 default).
- Config (Echo, proposed, not edited by Prism): `WaveArenaConfig.party = { maxPlayers = 4, hpPerExtra = 0.3 }`, `WaveArenaConfig.afk = { needWaves = 3, ofWaves = 5, warnAtMisses = 2, nudgeSeconds = 20, downShare = 0.5 } -- a wave counts if down time > downShare of it (Q3)`.
- Copy: "Party n/4 · Enemy HP ×N" · "Party ×N: n players, enemies are tougher" · "Party ×N: <name> left, enemies get weaker next wave" · "Hit an enemy this wave to keep your rewards" · "No damage for 3 waves. No run rewards this time." · "No run rewards: damage in N of 5 waves. Drops you got stay." · "YOUR LOOT · N items" · "Party of n · your run" · "<Tier> drop: <name>".

## 7. Edge cases
- **Flags off:** no party label change, no badge, no AFK UI; Gate pad stays solo as today. Each flag works alone: `partyHpScale` off = parties at ×1.0 with no badge; `afkCheck` off = no pips / warnings / holds.
- **Someone leaves / disconnects mid-run:** their already-granted drops stay theirs; n drops at the **next** wave start (toast names them). Last player standing continues solo at ×1.0 from the next wave; the AFK check stops when n becomes 1.
- **Rejoin mid-run:** not supported in V1 (run state in memory); they land on the return pad (14, 30).
- **AFK player becomes active again:** they can still fight, but the hold stands (3 of 5 is no longer reachable). They are excluded from n, so they don't make enemies tougher for others.
- **Whole party AFK:** waves still time out per the live arena rules; nobody gets a payout. No extra rule.
- **Wipe:** misses before the wipe count as normal; wipe results follow #429 ("You keep everything you earned"), AFK line replaces payout only for the flagged player.
- **Hard (#437):** Hard 2× HP × party multiplier (4p Hard = 3.8× base); Hard still needs every member Lv 5 (#441 step 5). **Q5 decided:** the party multiplier multiplies with Hard and applies to the wave-5 boss (Echo still sanity-checks boss time-to-kill at 4p Hard).
- **Healer / support future classes:** "deal damage" would miss a pure healer; classes are flagged off for V1 (`classes` false). Later classes would count healing too (Later list).
- **Exploits:** client never reports damage or AFK state; server counts damage it applied. Tapping the chip does nothing to the rule. One-hit-per-wave idling is allowed by design (the rule targets real AFK, not low skill).
- **Kids' safety:** no new chat, invites or names beyond #441's world tags; the AFK toast never names the AFK player to others (only "<name> left" for disconnects).
- **Personal loot display:** others' drop orbs are never sent to your client, so there's nothing to "steal"; `RunResults.loot` is per player (#455). No "X got Legendary" broadcast in V1 (Q2 decided: no).
- **Toast crowding:** D3 lane max 1; loot toasts outrank party/AFK info toasts; the AFK warning waits ≤ 2.5 s behind a loot toast, never dropped.

## 8. Mockups
SVG in `mockups/` (original art, fake data, gray-box world; live HUD dashed, keep-out cyan dashed; PNG renders stay on the box):
- `01-flow-scaling-options.svg`: 5-step flow, HP scaling bars 1p–4p (×1.0/×1.3/×1.6/×1.9), proposed flags, personal loot rules, and both taste calls (HP readout A/B/C, AFK outcome A/B/C).
- `02-gate-dock-leader-390x844.svg`: hub, leader, Party 3/4, label row with the ×1.6 badge above the #441 dock, Friends toggle OFF.
- `03-arena-afk-warning-667x375.svg`: arena fight, wave chip with ×1.6 + amber "!" (2 misses), AFK toast in the D3 lane, your own drop orb only.
- `04-states-and-results-800x400.svg`: chip states (solo, party, miss 1, warned, AFK), toast copy, and the 800×400 results wings with "YOUR LOOT" and the AFK variant line.
- `05-boss-wave-desktop-1280x720.svg`: 4p wave 5, boss bar + chip with ×1.9, personal Epic drop toast.

## 9. Build split
All behind the three flags (default off). Order: Echo server first, then Ghost UI.
- **Echo (server):** propose `parties`, `partyHpScale`, `afkCheck` in `LaunchGate.SHOW` (false) and the `WaveArenaConfig.party` / `afk` numbers; n per arena copy at each wave start; HP multiplier at enemy spawn (Hard multiplies, Q5); per-player wave counter (damage applied or down > 50%); AFK flag at 3 misses (n ≥ 2 only); withhold later grants + end payout for AFK (Q1); `RunResults.party = { n, mult, afk, wavesCounted }` on #455's payload; party/AFK events to the client. Tests: mult 1.0/1.3/1.6/1.9, no mid-wave change, leave → next wave recount, solo never flagged, down-time counts, AFK payout held but earlier drops kept, nothing saved.
- **Ghost (client):** badge in the #441 dock label and in the #428 chip / boss bar; hit pips, amber stroke, "!", AFK tag; toasts through the D3 lane; #429 "YOUR LOOT" title + AFK line; drop orbs render only for the local player's grants. Studio checks at 390×844, 667×375, 800×400, 1280×720.
- **Prism:** Phase S polish of the badge / pips after M13; review Ghost's screenshots against this spec.
- **Havoc:** 4-player run with one idler (warn at 2, AFK at 3, payout held), leave mid-wave (no HP jump), all-AFK party, Hard 4p HP check, two clients compare drop orbs (no cross-visibility), flags-off regression (solo unchanged).

## 10. Pass criteria (playtest)
1. Two friends on phones form a party in ≤ 5 s with no instructions (#441) and can say how much tougher enemies are ("×1.3") when asked after the run.
2. Server log shows enemy HP × 1.0 / 1.3 / 1.6 / 1.9 for 1–4 players; living enemies never change HP mid-wave.
3. Each tester sees only their own drop orbs and results loot (2 clients side by side).
4. An idle tester gets the pips after 1 miss, the amber "!" + toast after 2, the AFK line after 3; active testers never see an AFK warning in 20 runs.
5. Nothing enters the center keep-out at 390×844, 667×375, 800×400, 1280×720; every tap target ≥ 44 px; solo with flags off is pixel-identical to today.
6. Low-end phone with 4 players: no FPS drop from the badge or pips (they're 3 Frames).

## 11. Open questions (all answered v1.1, Ghost DP34P under Kevin's pre-approval)
1. ~~@Kevin: 3rd missed wave A/B/C~~ **ANSWERED: A, payout held** (stay in run, keep drops already granted, no later drops, no end payout, stop counting for HP).
2. ~~@Kevin: teammate Legendary hype toast~~ **ANSWERED: no teammate Legendary toast** (strictly your own drops; B parked in Later / Ideas Backlog, NOT APPROVED).
3. ~~@Ghost: downed ≥ 50% counts as present?~~ **ANSWERED: yes**, a wave where you're downed over half of it is NOT a miss.
4. ~~@Ghost: AFK check only with n ≥ 2?~~ **ANSWERED: yes, parties only** (never solo; stops if the party drops to 1).
5. ~~@Ghost: stacks with Hard + applies to boss?~~ **ANSWERED: yes to both** (4p Hard = 3.8× incl. the wave-5 boss; Echo sanity-checks boss time-to-kill).
6. ~~@Ghost: HP readout A/B/C~~ **ANSWERED: A** (badge in the dock label + wave chip / boss bar).
7. ~~@Ghost: flags~~ **ANSWERED: yes, three flags** `parties`, `partyHpScale`, `afkCheck`, all default false.
No open questions left in M16. (#441 Kevin Q2, Friends-only default OFF + leader's friends only, stays open there.)

## Decision log
- 2026-10-24 (Ghost DP31P, Kevin pre-approved for Prism to write it; Prism): **M16 v1** on `prism/m16-parties-ux`: reuses #441 join flow + Friends-only unchanged, adds the ×(1+0.3×(n−1)) readout (badge A), per-wave n lock, personal loot display rules, anti-AFK 3-of-5 with warn at 2 / AFK at 3, three flags default off, 5 mockups. Open: Kevin 1–2, Ghost 3–7. Not approved.
- 2026-10-24 (Ghost DP34P, Kevin pre-approved; Prism fold): **M16 v1.1**: Q1 A payout held · Q2 no teammate Legendary toast · Q3 downed > 50% of a wave is not a miss · Q4 AFK check in parties only · Q5 party HP × Hard, boss included · Q6 badge A · Q7 three flags default off. Mockup 01 labels updated (DECIDED). Still a proposal until Kevin copies it into Vision & Design Rules.

## Later (not V1)
Teammate Legendary hype toast (Q2 B), healing counts toward "present" when classes return, invites from the friends list (#441 Later), "Run it back" from the arena (#429 Later), party emotes, cosmetic slot skins (never power). All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only: `Frame`, `TextLabel`, `ImageLabel`, `ImageButton`, `UICorner`, `UIStroke`, `UIGradient`, `UIScale`, `UIListLayout`, TweenService, `ParticleEmitter` (world only). **No blur, no `ColorCorrection`, no BackgroundBlur, no web fonts.** All new UI lives in the existing ScreenGuis (`CoreUISafeInsets`); Prism doesn't edit `Ui.luau`, `HudLayout`, `CombatHud`, `GearBar`, `MenuHub`, `InventoryHud`, `OnboardHud`, `RollReveal` or any Ghost-owned file; Ghost decides where the code goes.
| Element | Instances |
|---|---|
| ×N badge | `Frame` 40×18 (BackgroundColor 16,14,24) + `UICorner` (0.5, 0) + `UIStroke` 1.2 Color 120,210,255 + `TextLabel` Builder Sans Heavy 10 px (`TextScaled` false), parented in the dock label row's `UIListLayout` (Horizontal, Padding 6) and inside `WaveChip` / `BossBar` (AnchorPoint (1, 0), right padding 8); pulse = `UIScale` tween 1 → 1.1 → 1, 0.2 s |
| Hit pips | 5 × `Frame` 5×5 + `UICorner` (0.5, 0) + `UIStroke` 0.8 muted, in a `UIListLayout` Horizontal Padding 4; fill ok 110,210,140 (counted) / muted 176,168,198 (missed) / transparent (to come); `Visible` only after miss 1 |
| Warning | `WaveChip.UIStroke.Color` tween to 255,170,60 + Thickness 2 (0.2 s); "!" = `Frame` 16×16 `UICorner` (0.5, 0) Color 255,170,60 + `TextLabel` "!" ink 32,22,10; pop `UIScale` 0 → 1 0.15 s Back Out |
| AFK tag | same as the badge with fill 54,46,78, stroke none, text "AFK" muted |
| Toasts | existing D3 toast host only (one lane, max 1, loot priority); amber `UIStroke` for the warning variant |
| Results line | #429 stats wing `TextLabel` ×2, 11 px, Color 255,170,60, `TextWrapped` true; hides the token/fragment `Frame`s when `RunResults.party.afk` |
| Drop orbs | the live drop visuals created **client-side from the local player's grant event** (never a replicated workspace Part), so other players' orbs don't exist on your client; rarity tint = `Rarities.COLOR[tier]` (never hard-coded); Epic+ burst = `ParticleEmitter` `:Emit(12)`, Rate 0 |
| Input | chip tap (`ImageButton` overlay 44 tall) = repeat the AFK line / fold (#428); desktop Tab folds the chip (#428); no new keys |

Image assets: none new (badge, pips and "!" are Frames + text). Gray-box until Phase S.
