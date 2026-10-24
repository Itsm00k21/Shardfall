# Party Gather Spot ("Gate Ring", canvas T4), Spec v1.2

Owner: Prism (design, docs only, no code). Builders: Ghost (world slots, Gate dock UI), Echo (party server state). Base: `cursor/live-build-9721`. Status: **v1.2** (Oct 24, 2026, DP34P: live prompt audit + T7 v1.1 / M16 v1.1 tie-in; see the v1.2 note). v1.1: Ghost answered Q1, Q3, Q4, Q5 (Oct 24, 2026, Kevin pre-approved); Q2 is a Kevin taste call, Prism recommendation recorded as PROVISIONAL. Gray-box only (pre-Phase S). Nothing beyond the answered questions is approved until Ghost/Kevin say so.
Asked for in: Ghost's Agent Board row (Kevin pre-approved) https://app.notion.com/p/403c31ca38838192b465db2fbca4fda1, item 2, from canvas item **T4**: "Party gather spot spec (room for 4 by the Gate pad, name slots, Friends-only toggle, no prompt overlap)". Roadmap Phase 6 (party).

**v1.2 note (Oct 24, 2026, 8:00 AM PT):** Ghost's DP34P row (https://app.notion.com/p/403c31ca388381fea022e68f6cc3fd35, Kevin pre-approved) asked for "T4 gather spot (4 slots, Friends-only toggle, no prompt overlap with Shard Gate pad)". That is this spec (PR #441), so per the no-duplicate rule it's a version commit here, not a new `prism/t4-gather-spot` branch. v1.2 adds: (a) **§4.1 prompt audit** against the live `HavenBuilder.luau` (two live prompts would sit on / overlap the pad once T7 Q2 moves the `EnterPad` to (0, 98); both are dropped there, which is what Q4 already decided); (b) the **T7 v1.1** tie-in (pad = H12 via `Haven.KIT.gatePad`, sign/arch "Shard Gate", Muster H18 + its H14 path leg follow `musterSpot`); (c) the **M16 v1.1** tie-in (flags `parties` / `partyHpScale` / `afkCheck` default off, ×N badge A in the dock label). Mockup `07-prompt-audit-v1.2.svg` added; 01 relabeled (Muster hidden). No other rule changed.

Sources (link, don't copy):
- Locked: V1 Core Loop §3 Party & Run Setup: "Party: 1–4 players, solo allowed", "Lobby: one Shard Gate pad", "15s countdown starts when the first player steps on; Start now button", "Leader picks Normal or Hard (only tiers all members have unlocked)", "Friends-only toggle; no queue", "3–4 arena copies on the same server … server cap ~12–16 players". Personal loot.
- Specs this must match: **#413 Crater Square** (Gate pad (0, 98) Ø16, Shard Gate arch (0, 108), spawn (0, 30), return pad (14, 30), Crackstone (-12, 52) "Roll" prompt, **Muster spot (24, 90) Ø18 with 4 gray-box sockets**, Q3 decided "gray-box now, no party logic until Phase 6"); **#414 Shard Crater** (arena spawn in the center, party of 4 perf budget); #412 Gate dock (bottom-center slot, chevron, Normal/Hard, START, "Shard Gate · Solo · starts in N"); #420 phone layout review (keep-out, D1, D2, D3 toast lane); Hard mode selector spec (this batch, `docs/design/hard-mode-selector/`).
- Chrome: PR #392 `docs/ui/reference/STYLE.md`; colors: gold 255,196,64, gate cyan 120,210,255 (world markers only), ok 110,210,140, danger 230,80,96, muted 176,168,198.

## 0. Directions (pick one) and recommendation
Mockup: `mockups/06-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Gate Ring (the party forms on the pad)** | The Gate pad itself is the lobby (Core Loop). It gets 4 lit **slots** (2×2, inside the Ø16 pad). Step anywhere on the pad and you take the next free slot; your name appears over it. Slot 1 = leader. The Gate dock shows the party count, the leader's Friends-only toggle, Normal/Hard and Start now. | One step, no new prompts, nothing new to learn after the first run (same pad, same dock). Exactly the Core Loop lobby. Phones never need precise standing. | 4 players on a Ø16 pad is snug (slots are 10 studs apart, fine for R15). Needs a rule for the #413 Muster gray box (Q1). |
| B | Muster Arc at (24, 90) | Form up on the 4 #413 sockets beside the pad, then the leader walks onto the Gate pad to start. | Uses the gray box that's already decided; pad stays clear for solo players. | Two steps and a 26-stud walk; two places that both look like "the lobby"; the 15 s countdown rule has to move. |
| C | Party board | A stone with a ProximityPrompt "Party" opens an invite list menu. | Can invite friends from anywhere. | A new prompt near the pad (the overlap Ghost wants to avoid), a menu on phones, slowest path. Better as a Later feature. |

**Recommendation: A, "Gate Ring".** It is the Core Loop lobby as written, it adds zero prompts, and it keeps the first-30-seconds pad flow (#412) unchanged for solo players: a solo player just sees one lit slot. The rest of this spec is A.

## 1. Goal
Up to 4 players gather at the Shard Gate in one step, can see who is in (names over slots), the leader can keep it friends-only, and nobody ever fights a ProximityPrompt or a camera to join.

## 2. Where it lives
- **World (Ghost):** 4 slot discs on the existing Gate pad (0, 98) in Crater Square (#413), plus 4 `BillboardGui` name tags. No new part outside the pad. **No ProximityPrompt on the pad or the slots, and none within 12 studs of the pad center** (the "prompt-free zone"). Join and leave = the existing pad touch zone (EnterPad logic, #413 §9).
- **Screen (Ghost):** the existing #412 Gate dock (bottom-center slot) gains a **Friends-only toggle** (44×44, leader only) and a party label with 4 pips. Members see a read-only dock. Toasts go through the one toast lane (#420 D3).
- **Server (Echo, Phase 6):** party state in memory only (Roadmap Phase 6: "Run and party state in memory only"): slot order, leader, Friends-only flag, tier, countdown. Nothing saved.
- **#413 Muster spot (24, 90):** with A it has no job. Decided (Q1): hide it behind a LaunchGate flag (`musterSpot`, off; nothing deleted).

## 3. Flow
| Step | Trigger | What players see | Server |
|---|---|---|---|
| 1 | First player steps on the pad | Slot 1 lights gold, their name + ★ appears above it. Gate dock rises: "Shard Gate · Party 1/4 · starts in 15" (solo looks the same as #412 with "Solo"). Countdown starts (Core Loop 15 s). | create party, leader = slot 1 |
| 2 | Another player steps on | Next free slot lights cyan, their name appears; label "Party 2/4", pips fill. Leader's dock unchanged; the new member's dock is read-only ("Waiting"). | add member (checks: Friends-only, Hard level, max 4) |
| 3 | Leader taps **Friends-only** | Toggle turns ok-green "ON". Free slots show "Friends only" tags. Members' dock shows the same state, read-only. | set flag; existing non-friend members stay |
| 4 | Non-friend steps on while ON | Their nearest free slot flashes red (0.6 s); toast for them only: "Friends-only party. Wait for the next Gate." They get no dock and are not pushed or teleported. | refuse |
| 5 | Leader picks Normal/Hard | See the Hard mode selector spec. Hard needs every member Lv 5. | |
| 6 | Leader taps **START** (= Start now) or countdown ends | "Starting…", slot rings sweep closed (0.4 s), everyone teleports into the same arena copy (#414 center spawn). | start run with the slot list |
| 7 | Anyone walks off the pad | Their slot goes dark, name fades (0.2 s), later joiners keep their slots (no reshuffle). Leader leaves → next by join order becomes leader (★ moves, toast "You lead the party." for them). Last player leaves → party ends, countdown resets. | update party |
| 8 | After the run | Players return to the return pad (14, 30) (#413), never onto the Gate pad. The party ends; to go again, step back on the pad (Later: "Run it back", Ideas Backlog). | clear party |

**Countdown rules** (Core Loop 15 s): starts when the first player steps on, doesn't restart when others join; if someone joins with < 5 s left, it bumps to 5 s (once per joiner) so they can see the dock (Q3 decided). 4/4 doesn't auto-start early; the leader can tap START any time. The first-ever run stays solo with a 3 s countdown (#412).

**Busy pad:** while a party is on the pad (countdown running), players beyond 4 see "Full" tags; the pad frees as soon as the party teleports (≤ 15 s). There is no queue (Core Loop). With 3–4 arena copies per server, a busy copy count shows as the toast "All Gates busy, back in a moment." (rare).

## 4. Layout
**World (studs; origin Lumen Heart (0, 0), +z south, floor y 120, #413).** Map: `mockups/01-topdown-gate-pad.svg`.

| Thing | Position | Size | Notes |
|---|---|---|---|
| Gate pad | (0, 98) | Ø16 (#413) | unchanged; touch zone = whole pad |
| Slot 1 ★ / 2 | (-5, 94) / (5, 94) | Ø4 discs, 0.2 tall | near row (camera side) so the leader and the first friend read first |
| Slot 3 / 4 | (-5, 102) / (5, 102) | Ø4 | far row; all slots inside the pad (r 6.4 < 8) |
| Name tags | above each slot's player head, `StudsOffset` (0, 3.5, 0) from the HRP; empty slot: on the disc, (0, 0.6, 0) | 3.6 × 1 studs (`Size` UDim2 scale) | `MaxDistance` 60, `AlwaysOnTop` false (stays off the HP bar), text ≥ 13 px at 390 wide |
| Prompt-free zone | r 12 around (0, 98) | — | no ProximityPrompt inside. The Crackstone "Roll" prompt (-12, 52) is 47 studs away; the return pad (14, 30) 69 studs; the Muster spot (24, 90) is flagged off (Q1) |
| Gate arch prompt | none (Q4 decided) | — | START is the dock button / E key. If Ghost keeps an arch prompt, it must be outside the r 12 zone (behind the arch, z ≥ 110 is only 12 from the center, so it would need z ≥ 111 and `MaxActivationDistance` ≤ 4) |

Slot spacing is 10 studs side to side and 8 front to back, so 4 R15 avatars (about 2.5 studs wide) never touch, and the far tags sit higher on screen than the near tags at the default phone zoom (no tag overlap, mockup 02).

### 4.1 Prompt audit (v1.2, live `cursor/live-build-9721` @ `581c995`, read only)
Mockup `07-prompt-audit-v1.2.svg`. Prompts come from `promptOn()` (`ShardfallServer/HavenBuilder.luau:296-320`, default `MaxActivationDistance` 18, `RequiresLineOfSight` false). On the Rootvault arch today (`:1766-1771`):

| Live prompt | Where | Reach | Distance to pad center (0, 98) | v1.2 rule |
|---|---|---|---|---|
| "Enter" (`HavenAction` rootvault) | on the `EnterPad` fill (attribute `EnterDungeon`) | `Haven.GATE_REACH` 8 | 0 once T7 Q2 moves the pad to (0, 98) | **Not built on the moved pad.** Entry = the pad touch zone + dock START / E (Q4). Echo's `Haven.KIT.gatePad` move skips this `promptOn` call; the server path stays the same. |
| "Waves · Solo" (`HavenAction` waves) | arch `PillarL` at ≈ (−7, 108) | `Haven.PIER_REACH` 4 | 12.2 (reach covers z ≥ 104, i.e. the pad's back edge) | **Not built while the Gate pad exists.** Solo = 1 player on the pad + START (the #412 solo flow). |
| "Sealed" (other arches) | next arch on the `GATE_RADIUS` 78 crescent | 8 | ≈ 17+ | hidden with `sealedGates` (T7 Q4 / #413) |
| "Roll" (Crackstone, T7 H13) | (−12, 52) | 10 | 47.5 | keep |
| Muster sockets (T7 H18) | (24, 90) | no prompt | 25.3 | hidden with `musterSpot` (Q1); T7's H14 "Gate pad ↔ Muster" path leg follows the same flag |
| Return pad (T7 H11) | (14, 30) | no prompt | 69.4 | keep |

Result: **0 ProximityPrompts within r 12 of the pad, and no prompt whose reach touches the pad.** Havoc check: stand on each of the 4 slots and on the pad rim (r 8) at all 4 test sizes; no prompt indicator may appear. Prism edits no builder or config; this table is the build contract for Echo / Ghost.

**Flags (M16 v1.1 Q7, decided):** `parties` off = today's solo pad (1 slot lit, no Friends toggle, no party label); on = 4 slots + Friends-only + party label. `partyHpScale` adds the cyan ×N badge (M16 Q6 A) to the label: "Shard Gate · Party 3/4 · Enemy HP ×1.6 · starts in 9". `afkCheck` has no hub UI. All default `false`; Prism flips nothing.

**Screen (full-screen px, #420 frame; nothing enters the center keep-out).**

| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Gate dock (#412) | x 16–374, y 738–802 | x 174–492, y 301–361 | x 230–570, y 326–386 | x 430–850, y 632–696 (420×64 with the toggle) |
| Segments | chevron 44 · Normal 76 · Hard 76 · **Friends 44** · START 92×48 | chevron 44 · Normal/Hard ~54 · Friends 44 · START 92 (Normal/Hard min 54 wide, 44 tall) | Normal/Hard ~65 | Normal/Hard ~99 · START 110 "START [E]" |
| Party label + pips | baseline y 733: "Shard Gate · Party 3/4 · starts in 9" + 4 pips (8 px, gap 12) right of the text | y 293 | y 320 | y 622, keys hint "1 / 2 / F / E" |
| Member label | "Leader Kevin picks · Normal · Friends only · 7" | same | same | same |
| Toasts | lane x 88–266, y 231–267 | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |

Rules: every tap target ≥ 44 px; the toggle is 44×44 with an "ON/OFF" 8 px caption inside the icon area plus a 44 px hit box (caption is decoration; the state is also shown by fill color and in the members' label). In the hub the combat cluster is hidden while the dock is up (D2). No name list on screen: names live in the world tags (cheap, readable, and keeps the phone screen to one dock).

## 5. States
| Element | Idle / empty | Filled | Leader | Locked / refused | Countdown |
|---|---|---|---|---|---|
| Slot disc | muted ring 176,168,198, fill 0.12 | cyan 120,210,255 ring + fill 0.35 | gold 255,196,64 | Friends-only: dim 54,46,78 ring; refused: danger flash 0.6 s | ring sweep fills clockwise over the countdown; last 3 s pulse |
| Name tag | "Open" (muted) / "Friends only" (muted) / "Full" | name, text 240,236,248, cyan stroke | name + ★, gold text | "Friends only" | — |
| Friends toggle | OFF: row 40,34,58, muted icon | ON: ok 110,210,140, ink icon | leader: tappable | member: 60% opacity, read-only | locked during "Starting…" |
| START | gold (#412) | — | leader only | member: "Waiting" dim | "Starting…" |
| Label pips | hollow | filled cyan | — | — | — |
Loading: if the party state is late, the dock shows the solo layout with a `spinner_64` in place of the pips. Error: a refused join or failed start shows a toast with the server text.

## 6. Numbers
- Party 1–4 (Core Loop). Slots 4. Countdown 15 s (Core Loop; Config), join bump to 5 s if < 5 s left (decided, Q3). First-ever run: solo, 3 s (#412).
- Slot discs Ø4, 0.2 tall, at (±5, 94) and (±5, 102). Prompt-free zone r 12. Name tag `MaxDistance` 60.
- Friends-only default: **OFF** (PROVISIONAL, Kevin taste call Q2). Friends = Roblox friends (`Player:IsFriendsWith`, cached per session on join).
- Timings: slot light 0.2 s, name fade 0.2 s, refused flash 0.6 s, start sweep 0.4 s.
- Copy: "Shard Gate · Solo · starts in N" · "Shard Gate · Party n/4 · starts in N" · "Leader <name> picks · <tier> · Friends only · N" · "Open" · "Friends only" · "Full" · "Waiting" · "Friends-only party. Wait for the next Gate." · "You lead the party." · "All Gates busy, back in a moment."

## 7. Edge cases
- **Server authority:** the server assigns slots by join order from the pad touch zone; the client never picks a slot. Friends-only and Hard checks happen on join and again on START.
- **Friends-only turned on with a non-friend already in:** they stay (no kicking in V1). The flag only blocks new joiners.
- **Friend-of-a-friend:** checks are against the **leader's** friends only (simple, predictable). Q2 notes the alternative.
- **Leader handoff:** next by join order; the tier stays if everyone still qualifies (Hard rule), else falls back to Normal (Hard spec §7).
- **Two players step on at the same frame:** server order wins; both get slots if free.
- **Player stands on the pad edge / jumps:** membership uses the touch zone with a 0.5 s grace on leave, so a jump or a stumble doesn't drop a slot.
- **Kids' safety:** no chat or invite UI added; names shown are Roblox display names already visible in the world.
- **Rejoin mid-countdown:** treated as a new join.
- **Performance:** 4 discs + 4 BillboardGuis + 1 `Beam`-free ring tween; no new emitters. Fits #413's hub budget (Parts ≤ 900, emitters ≤ 6).
- **Solo players:** unchanged from #412; the slot ring is just one lit disc.

## 8. Mockups
SVG in repo (fake data, original art, gray-box world): `mockups/01-topdown-gate-pad.svg` (slots, studs, prompt-free zone, Muster flagged) · `mockups/02-leader-phone-390x844.svg` (leader, 3/4, Friends-only off) · `mockups/03-member-landscape-667x375.svg` (member, read-only dock, Friends only on) · `mockups/04-friends-only-refused-800x400.svg` (non-friend refused, toast lane) · `mockups/05-full-desktop-1280x720.svg` (4/4, Hard, countdown 3, keys) · `mockups/06-directions.svg` (A/B/C) · `mockups/07-prompt-audit-v1.2.svg` (v1.2: live prompts near the pad, drop list, M16 badge label). Live HUD dashed, keep-out cyan dashed. PNG renders are on the box only.

## 9. Build split
Phase 6. Gray-box now is optional (the slots are 4 discs on the existing pad).
- **Echo (server):** in-memory party state (slots, leader, Friends-only, tier, countdown), join/leave from the pad touch zone with 0.5 s grace, friend check, Hard level check, start → one arena copy for the slot list. Tests: 5th player refused, Friends-only refuses a non-friend, leader handoff, countdown bump, nothing written to the save.
- **Ghost (world + client):** 4 slot discs + name tags on the pad, Friends-only toggle + party label/pips in the Gate dock, member read-only dock, toasts, F key; flag the #413 Muster spot off (Q1 decided, `musterSpot` off, nothing deleted; T7 H18 sockets + the H14 Gate↔Muster path leg follow it); no arch prompt at all (Q4 decided): with the pad at (0, 98) skip the "Enter" prompt on the moved `EnterPad` and the "Waves · Solo" `PillarL` prompt (§4.1); slots 2–4, Friends toggle and party label only with `parties` on, ×N badge with `partyHpScale` on (M16).
- **Prism:** Phase S look for the slots (shard-shaped sockets, gate-cyan glow) after the fun test.
- **Havoc:** join/leave spam, Friends-only race, leader leaves during "Starting…", 4 players + 1 spectator on the pad edge.

## 10. Pass criteria (playtest)
1. Two testers on phones form a party in ≤ 5 s without instructions (step on the pad).
2. Every player on the pad can read every name tag at 390×844.
3. Friends-only blocks a non-friend and the leader sees the state in one glance.
4. No ProximityPrompt shows anywhere on or near the pad (stand on all 4 slots + the rim, §4.1); the Crackstone prompt never shows from the pad; with `parties` off the solo pad flow is unchanged.
5. Nothing enters the center keep-out; all tap targets ≥ 44 px; solo flow from #412 unchanged.
6. 4 players start together in one arena copy every time (20 tries).

## 11. Open questions (answer by number)
1. ~~@Ghost: What happens to the #413 Muster gray box at (24, 90)?~~ **Hide it behind a `musterSpot` flag (off, nothing deleted) (Ghost, Kevin pre-approved, Oct 24, 2026).** Board row: https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953
2. **@Kevin (taste, open):** Friends-only default OFF or ON, and friends of the leader only or of any member? **PROVISIONAL (Prism recommendation, used until Kevin decides):** default **OFF**, leader's friends only.
3. ~~@Ghost: Countdown rule?~~ **Keep 15 s from the first player; bump to 5 s on a late join (< 5 s left) (Ghost).**
4. ~~@Ghost: Does the Gate keep any ProximityPrompt?~~ **No ProximityPrompt (Ghost).** START is the dock button and the E key; the r 12 prompt-free zone stands.
5. ~~@Ghost: Leader handoff?~~ **By join order (Ghost).**

Ghost's questions are all answered (v1.2 adds none: the two live prompts in §4.1 are dropped under Q4). Only Kevin's taste call (Q2) remains; the spec runs on the PROVISIONAL pick until he answers.

## Decision log
- 2026-10-24 (Prism): v1 published. Recommends direction A (Gate Ring). Five open questions (Ghost 1, 3, 4, 5; Kevin 2). Not approved.
- 2026-10-24 (Ghost, Kevin pre-approved; Kevin can change later; board row https://app.notion.com/p/403c31ca388381eeb7def55a6b3d4953): Q1 = `musterSpot` flag off, nothing deleted. Q3 = keep 15 s from the first player, bump to 5 s on a late join. Q4 = no ProximityPrompt. Q5 = leader handoff by join order. → v1.1.
- 2026-10-24 (Prism): Kevin taste call Q2 (Friends-only default OFF, leader's friends only) recorded as PROVISIONAL, waiting for Kevin.
- 2026-10-24 (Ghost DP34P, Kevin pre-approved; Prism): **v1.2**: DP34P's T4 ask folded here (no duplicate branch/PR). Live prompt audit (§4.1): "Enter" on the moved `EnterPad` and "Waves · Solo" on `PillarL` are not built at the pad (follows Q4); T7 v1.1 + M16 v1.1 tie-ins (flags, ×N badge, Muster H18/H14 follow `musterSpot`). Mockup 07 added. Not approved.

## Later (not V1)
"Run it back" (party stays together after the results screen), invites from the friends list (direction C's good part), party emotes on the slots, cosmetic slot skins (never power). All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox only. No blur, no soft shadows, no web fonts. World effects are Parts, `PointLight`s (Shadows false) and `ParticleEmitter`s; UI motion = TweenService.

| Element | Instances |
|---|---|
| Slot disc | `Part` cylinder Ø4 × 0.2 (Neon off, SmoothPlastic, Color per state), `CanCollide` false, `CanTouch` false (membership uses the pad's touch zone), `CanQuery` false; optional `PointLight` Range 6, Brightness 0.5 for the leader slot only |
| Countdown sweep | `SurfaceGui` on the disc top (`Face` Top, `PixelsPerStud` 20) + `ImageLabel` ring_256 with a `UIGradient` (Transparency NumberSequence, Rotation tween 0 → 360 over the countdown) |
| Name tag | `BillboardGui` (Adornee = player head or the disc, `Size` (3.6, 0, 1, 0) studs, `StudsOffset` (0, 3.5, 0), `MaxDistance` 60, `AlwaysOnTop` false, `LightInfluence` 0) + `Frame` (`UICorner` h/2, `UIStroke` 1.5 state color) + `TextLabel` (Builder Sans Bold, `TextScaled` true with `UITextSizeConstraint` Min 13) |
| Friends toggle | `ImageButton` 44×44 + `UICorner` 8 + friends_icon `ImageLabel` + `TextLabel` "ON/OFF" 8 px; fill ok 110,210,140 / row 40,34,58; `UIScale` press 0.96 |
| Party label | `TextLabel` + 4 pip `Frame`s 8×8 (`UICorner` 0.5 scale, `UIStroke` 1.2 cyan) in a `UIListLayout` Horizontal |
| Refused flash | disc `Color` tween to danger and back (0.6 s) + `ParticleEmitter` Rate 0, `:Emit(8)`, Color danger, Lifetime 0.4 (local client only) |
| Start sweep | TweenService on all discs (Transparency 0 → 1, 0.4 s) + the #413 pad swirl speed-up |
| Input | `ContextActionService`: F = Friends-only (leader), 1 / 2 = tier, E = START (desktop); gamepad Y = toggle |

### Image assets to upload (PNG, transparent)
| Asset | Size | Use |
|---|---|---|
| friends_icon_64 | 64×64 | Friends-only toggle |
| ring_256 | 256×256 | slot countdown sweep |
| spinner_64 | as in #397 | reused |
