# L5 Sound Cue List, Spec v1.2 (NOT APPROVED, docs only)

Owner: Prism (design, docs only, no code, no config edits, no asset uploads). Builders: Ghost (client playback, `Audio` / `UiSfx` rows), Echo (server events the client listens to). Base: `cursor/live-build-9721`. Status: **v1.2, proposal; Ghost closed Q1 and Q7.** Not an official Vision & Design Rules decision until Kevin approves it and it is copied there.
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883812fa966d50ee503d110 (11:55Z Oct 24, 2026, Kevin pre-approved): "L5 sound cue list v1 (hits, roll reveal per rarity, wave start/clear, boss slam; via Audio/UiSfx)."
v1.1 asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca388381818692c13be76248b2 (Oct 24, 2026, Kevin pre-approved): "sound cue sheet for hits, roll reveal (tier-scaled 0.6-2.2 s), wave start/clear and boss slam, routed through Audio/UiSfx, with volume and priority rules." Folded here (ACK https://app.notion.com/p/403c31ca388381bf9d11f641547b5ccf) instead of a new branch / duplicate PR.

**Changelog**
- v1.2 (2026-10-24): Ghost's DP29 rulings folded (board row https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96, ACK https://app.notion.com/p/403c31ca388381bda15dc237843e114b, Kevin pre-approved): **Q7 closed, default `rolls.skipAt = "off"`** (Kevin approved the 2.2 s Legendary reveal, so it must play by default; the setting stays for veterans); **Q1 closed, Legendary cue stays 1.8 s** (choir swell + impact + 4-note theme snippet; the 1.0 s alt is dropped). §4b-2, §6a, §7, §10 updated to match.
- v1.1 (2026-10-24): §4b-2 tier-scaled roll reveal timing (Common 0.6 s → Legendary 2.2 s) reconciled with the live `RollReveal` 1.65 s timeline and v1's cue lengths; §6a explicit volume and priority rules (priority tiers, voice caps + reserve, steal rule, ducking table, per-cue volume, mobile spam caps) routed via `Audio.CUES` / `Audio.cue` and `UiSfx.ids` / `UiSfx.clip`; Q7–Q9 added. Kevin's Q1 (Legendary cue length) stays open.
- v1 (2026-10-24): cue list for hits, roll reveal per tier, wave start/clear, boss slam (+ volley, enter, clear), UI taps.

**Extends, doesn't replace:** `docs/art/audio_cues.md` (G-047, live ids + suggested sounds) and `docs/design/shardfall_audio.md` (pillars, rarity ladder). This spec adds the V1 wave-arena cues, per-cue playback rules (priority, voices, volume, pitch), and placeholder slots. Like G-047, **no new asset id is pasted here.**

Live audio code (read only, `cursor/live-build-9721`; real names, nothing invented):
- `src/ReplicatedStorage/Shared/Audio.luau`: `Audio.GROUPS = { "Music", "SFX", "UI", "Ambience" }`, `Audio.TRACKS` + `Audio.trackFor(zoneId)`, `Audio.CUES` (frozen table: `common, uncommon, rare, epic, legendary, mythic, hit, dodge, perfect, kill, red, yellow, purple, blue`, all `""` today), `Audio.cue(name)` (lowercases the name, returns `nil` unless the id matches `^rbxassetid://%d+$`, so blanks stay silent), `Audio.heard(base, slider)`, `Audio.clampVolume`.
- `src/ReplicatedStorage/Shared/UiSfx.luau`: `UiSfx.ids` (`open, close, tab, press, click, stinger, confirm, toast`; two built-ins `rbxasset://sounds/switch.wav` and `rbxasset://sounds/electronicpingshort.wav`), `UiSfx.clip(action)` (unknown action → `press`), `UiSfx.volume(master, ui)`. Reduced motion does not mute UI; UI volume 0 does.
- Callers: `CombatHud.playCue(name)` (Volume 0.6, `SFX` SoundGroup; calls `hit`, the 4 telegraph colors, `dodge`/`perfect`, `kill`); `RollReel` (`Audio.cue(shown.rarity)` at reel stop, fallback ping for Rare+ at 0.5); `MenuHub` `hubFn.playUi(action)` (`UiSfx.clip` + `UiSfx.volume(master, ui)`); `MusicController` builds the 4 SoundGroups. `Settings.luau` audio = `{ master = 1, music = 0.7, sfx = 1, ui = 1 }`.
- **v1.1 roll reveal read** (`cursor/live-build-9721`): `Shared/RollReveal.luau` `RollReveal.FULL = 1.65` with phase marks `DIM_END 0.15`, `FAST_END 0.6`, `SLOW_END 1.3` (reel stops; `RollReel` plays `Audio.cue(shown.rarity)` at 0.6 volume once `spinProgress ≥ 1`), `GLOW_AT 1.0` (Epic+), `FLASH_AT 1.15` (Legendary+, 2 flashes in 0.5 s), `HOLD_END 1.4`, morph to the card until 1.65; all marks **scale with the duration** (`scaled()`). `RollReveal.duration` = `Settings.rollDuration` (**full 1.65 / short 0.7 / instant 0**, the same for every tier), 0 when `Settings.skipsCutscene(settings, rarity)` (live default `rolls.skipAt = "legendary"`; v1.2 ruling changes it to `"off"`, Q7), paid ≤ free.
- V1 wave enemies + boss numbers: Echo PR #422 `Config/Enemies.luau` (not merged, `LaunchGate.SHOW.enemyTypes = false`); boss attacks per #439 (`VOLLEY_WINDUP` 0.9 s, `LEASH_WINDUP` 1.2 s, `MarkCancel`).

## 1. Goal
Every V1 moment that matters (a hit, an element, a crit, a roll result, a wave starting or ending, a boss slam) has one short, recognizable sound that tells the player what happened without looking, sounds fine on a phone speaker, and never piles into noise in a 12-enemy wave with a party of 4.

## 2. Where it lives
- **Cue names = rows in the existing tables.** Combat, roll and wave cues are keys in `Audio.CUES`, played through `Audio.cue(name)` (blank = silent, so rows can land before assets). UI taps stay in `UiSfx.ids` via `UiSfx.clip(action)`. No new module is required; a `Config`-side copy is Q3.
- **Groups:** SFX cues use the `SFX` SoundGroup, UI cues the `UI` group (both exist via `MusicController`). Music ducking acts on the `Music` group.
- **Not here:** music beds and zone tracks (`Audio.TRACKS`, G-047), class palettes, pets, voice, any asset purchase or Robux.

## 3. Flow (one run, in cue order; timeline in `mockups/01-run-cue-timeline.svg`)
1. Hub: UI taps (`press`, `tab`, `open`/`close`) through `UiSfx`.
2. Roll: reel tick (proposed `reel_tick`) while spinning → at stop, the tier cue (`common` … `legendary`).
3. Wave start (L1: veins sweep 0.0 s → rift flare 0.4 s → enemies 0.8 s): `wave_start` at 0.0, its tail lands on the 0.8 s spawn.
4. Fight: `hit_ember` / `hit_frost` / `hit_void` (or `hit` when no element), `crit` layered on top, `shield_block` on a tank front hit, `kill`, `dodge` / `perfect`.
5. Wave clear: `wave_clear` on the last kill (with the white vein flash) → `loot_collect` as motes reach their owner (one per player).
6. Boss wave: `boss_enter` (L1 4.5 s entrance) → per attack `boss_volley_windup` (0.9 s) and `boss_slam_windup` (1.2 s) → `boss_slam_impact` or `boss_slam_fizzle` (`MarkCancel`) → `boss_clear` on the kill.
7. Run end: `run_win` or `run_wipe` (soft, no "loss" sting; L1 keeps the "all loot kept" tone) → results UI taps.

## 4. Layout: the cue list
Volume = base `Sound.Volume` before sliders (`Audio.heard(base, slider)`); pitch = random `PlaybackSpeed` range; **prio** 1 = never dropped … 5 = first dropped; **max** = voices of that cue at once (touch / desktop). Placeholder: `""` = silent until a licensed free Creator Store id is pasted; `built-in` = an `rbxasset://sounds/` file the repo already uses.

### 4a. Combat (SFX group, 3D on the target unless noted)
| Cue id | Status | Trigger | Prio | Max | Volume | Pitch | Notes / suggested sound | Placeholder |
|---|---|---|---|---|---|---|---|---|
| `hit` | live key | damage payload with no element (fists, neutral) | 3 | 4 / 8 | 0.5 | ±6% | swish + body + short tail (G-047) | `""` |
| `hit_ember` | **new** | damage payload, element ember | 3 | 4 / 8 | 0.5 | ±6% | dry crackle + thump | `""` |
| `hit_frost` | **new** | damage payload, element frost | 3 | 4 / 8 | 0.5 | ±6% | glassy crack, short ice tail | `""` |
| `hit_void` | **new** | damage payload, element void | 3 | 4 / 8 | 0.5 | ±6% | low hum + 80 ms reverse swell | `""` |
| `crit` | **new** | damage payload `crit = true` (layered on the hit, 2D for the hitter only) | 2 | 2 / 3 | 0.55 | ±3% | sharp "ting" (G-047) | `""` |
| `shield_block` | **new** | tank front-arc block (`EnemyAbilities.SHIELDER`, frontMultiplier 0) | 2 | 2 / 3 | 0.55 | ±4% | dull stone clank; teaches "flank it" | `""` |
| `kill` | live key | enemy death | 3 | 3 / 6 | 0.5 | ±5% | low shard chime, pitch +1 semitone per kill within 1 s (cap +4) | `""` |
| `dodge` / `perfect` | live keys | dodge payload | 2 | 1 / 1 | 0.45 / 0.55 | ±3% | dry sidestep / + bright tick (2D) | `""` |
| `player_hurt` | **new** | the local player takes damage (2D) | 2 | 1 / 1 | 0.5 | ±4% | short thud, low-passed; 0.25 s cooldown | `""` |
| `red` `yellow` `purple` `blue` | live keys | Rootvault telegraph colors (live crawl only) | 1 | 1 / 1 | 0.6 | 0 | keep as G-047; V1 boss uses §4c | `""` |

### 4b. Roll reveal (SFX group, 2D; `RollReel` asks `Audio.cue(rarity)`)
| Cue id | Status | Trigger | Prio | Max | Volume | Pitch | Length | Suggested sound | Placeholder |
|---|---|---|---|---|---|---|---|---|---|
| `reel_tick` | **new** (named in G-047) | each reel step while spinning | 4 | 2 / 2 | 0.25 | rises 0 → +12% as the reel slows | 30 ms | wood/glass tick | `built-in` switch.wav (RollReel already uses it at 0.35) |
| `common` | live key | landed Common | 2 | 1 / 1 | 0.4 | ±3% | 0.15 s | soft click/pop | `""` |
| `uncommon` | live key | landed Uncommon | 2 | 1 / 1 | 0.45 | ±3% | 0.3 s | light chime | `""` |
| `rare` | live key | landed Rare | 1 | 1 / 1 | 0.55 | 0 | 0.6 s | bright 2-note chime + shimmer | `built-in` ping (live fallback) |
| `epic` | live key | landed Epic | 1 | 1 / 1 | 0.65 | 0 | 1.0 s | rising arpeggio + bass hit; Music ducks to 40% for 1.0 s | `built-in` ping (live fallback) |
| `legendary` | live key | landed Legendary | 1 | 1 / 1 | 0.75 | 0 | 1.8 s | choir swell + impact + 4-note theme snippet; Music ducks to 25% for 1.8 s | `built-in` ping (live fallback) |
| `mythic` | live key | not shown in V1 (5 tiers) | — | — | — | — | — | leave blank | `""` |
Rule: **x10 roll** (#391) plays ticks once, then **only the best tier's cue once** (no 10 stacked chimes). Ascending ladder: each tier is longer, louder and has one more layer than the one below, so the player hears the tier before reading it. Rarity colors stay visual (`Rarities.COLOR`); sound never replaces the tier word.

### 4b-2. Tier-scaled roll reveal timing (v1.1; Ghost's 0.6–2.2 s ask)
Today every tier gets the same 1.65 s reveal. v1.1 proposes one reveal length **D per tier**; because `RollReveal`'s marks already scale with the duration, nothing else in the timeline changes: the reel stops (and the tier cue fires) at **0.788 × D** (1.3 / 1.65), the Epic+ stroke glow at 0.606 × D, the Legendary flashes at 0.697 × D, the card morph from 0.848 × D to D.
| Tier (V1) | Reveal D | Reel stop = tier cue start | Tier cue length (v1 §4b) | Cue ends | `reel_tick` | Music duck | Visual marks |
|---|---|---|---|---|---|---|---|
| Common | **0.6 s** | 0.47 s | 0.15 s | 0.62 s | ≤ 6 ticks | none | — |
| Uncommon | **0.9 s** | 0.71 s | 0.3 s | 1.01 s | ≤ 9 | none | — |
| Rare | **1.3 s** | 1.02 s | 0.6 s | 1.62 s | ≤ 12 | none | — |
| Epic | **1.65 s** (= today's live full length, unchanged) | 1.30 s | 1.0 s | 2.30 s | ≤ 14 | Music → 40% for 1.0 s | glow at 1.0 s |
| Legendary | **2.2 s** (cap) | 1.73 s | 1.8 s (Q1 closed v1.2) | 3.53 s | ≤ 16 | Music → 25% for 1.8 s | glow 1.33 s, 2 flashes from 1.53 s |
- **How the 2.2 s cap fits v1's 1.8 s Legendary cue:** 2.2 s is the **visual** reveal (until the card is fully up), not the sound. The cue starts at the reel stop (1.73 s) and its tail rings **1.33 s over the shown card**, which is where the "I got it" moment is. So both numbers hold: reveal ≤ 2.2 s, Legendary cue 1.8 s (still within v1 §6 "≤ 2 s one-shots"). (v1.2: Q1 closed at 1.8 s by Ghost, so the shorter 1.0 s alt is dropped.)
- **The ladder still climbs** in both length and loudness: reveal 0.6 → 0.9 → 1.3 → 1.65 → 2.2 s, cue 0.15 → 0.3 → 0.6 → 1.0 → 1.8 s, base volume 0.4 → 0.45 → 0.55 → 0.65 → 0.75 (§4b).
- **Settings:** `short` = `min(D, 0.7)` (so Common stays 0.6, every other tier 0.7; the cue still plays its full length at the stop); `instant` = 0 (card shows at once, the tier cue plays at the card show); `skipAt` keeps zeroing tiers at or above the gate, but **v1.2 default is `"off"`** (Q7 closed), so every tier, Legendary included, plays its full reveal unless the player picks a gate; paid ≤ free stays.
- **x10:** one reveal of the **best** tier's D, one cue (§4b rule).
- **Mythic:** not in V1; keeps today's separate long reveal.
- **Ticks:** `reel_tick` fires per reel row passed, ≤ 20 starts/s (skip ticks if the reel is faster), pitch rising 0 → +12% into the stop; last tick ≥ 0.06 s before the tier cue so they don't smear.

### 4c. Wave + boss (SFX group; 2D unless noted)
| Cue id | Status | Trigger (Echo hook, L1 §9) | Prio | Max | Volume | Pitch | Timing | Suggested sound | Placeholder |
|---|---|---|---|---|---|---|---|---|---|
| `wave_start` | **new** | wave-start event | 1 | 1 / 1 | 0.6 | 0 | 0.8 s, tail on the 0.8 s spawn | rising glass swell + drum hit; wave 5 uses `boss_enter` instead | `""` |
| `wave_clear` | **new** | wave-clear event (last kill) | 1 | 1 / 1 | 0.6 | 0 | 1.2 s | bright 3-note shard chord (main-theme motif) | `""` |
| `loot_collect` | **new** | loot-granted, per owner (local player only) | 3 | 1 / 1 | 0.4 | +2% per extra item, cap +10% | 0.3 s | soft coin/shard pickup; one sound per batch, not per item | `""` |
| `bag_full` | **new** | loot-granted with held/overflow > 0 | 2 | 1 / 1 | 0.45 | 0 | 0.4 s | low two-tone "hmm"; pairs with the amber chip | `UiSfx` `toast` |
| `boss_enter` | **new** | boss-enter event | 1 | 1 / 1 | 0.7 | 0 | 4.5 s (rumble 1.5 s + slab slide 1.0 s + roar) | low rumble → stone slide → roar; Music crossfades to `gnarlBoss` bed | `""` |
| `boss_volley_windup` | **new** | `VolleyEnd` attribute set (#439 V1) | 1 | 1 / 1 | 0.6 | 0 | 0.9 s; bright tick at 0.75 s (the "move now" flash) | charging hum, 3 pulses | `""` |
| `boss_slam_windup` | **new** | `MarkEnd` set (#439 S1) | 1 | 1 / 1 | 0.65 | 0 | rises over exactly 1.2 s to impact | rising whoosh (same family as the old `red`) | `""` |
| `boss_slam_impact` | **new** | slam lands (#439 S3), 3D at the mark | 1 | 1 / 1 | 0.75 | ±2% | 0.6 s | heavy stone hit + glass scatter; mid-frequency click layer for phones | `""` |
| `boss_slam_fizzle` | **new** | `MarkCancel` (#439 S4) | 2 | 1 / 1 | 0.45 | 0 | 0.25 s | dull fizz; teaches "cover cancels the slam" | `""` |
| `boss_clear` | **new** | boss dies | 1 | 1 / 1 | 0.75 | 0 | 2.0 s | big hit + theme stinger; Music ducks to 30% | `""` |
| `run_win` / `run_wipe` | **new** | run-end event | 1 | 1 / 1 | 0.6 / 0.45 | 0 | 2.0 s / 1.5 s | victory stinger / soft descending chord (no harsh "fail") | `""` |

### 4d. UI taps (UI group, 2D, via `UiSfx`; no new actions needed)
| `UiSfx` action | Live id | V1 use (proposed mapping) | Max | Notes |
|---|---|---|---|---|
| `press` | ping | ROLL, Gate, Run Again, Equip, any primary button | 1 | default for unknown actions (`UiSfx.clip`) |
| `click` | switch | list rows, Bag slots, "Later ›" on the draft row | 1 | |
| `tab` | switch | hub tabs, Hard/Normal toggle | 1 | |
| `open` / `close` | switch | panel expands / collapses to its pill | 1 | collapse uses `close`, never silent |
| `confirm` | ping | Shard Draft card pick (#416), salvage confirm | 1 | |
| `toast` | ping | toast lane entry (one lane, so max 1) | 1 | |
| `stinger` | ping | Epic+ crack (live) | 1 | |
Suggested replacements for the 8 clips stay as in G-047.

## 5. States
- **Blank row** (`""`): `Audio.cue` returns nil → silent; `RollReel` keeps its Rare+ ping fallback. Every new key can ship blank.
- **Muted:** SFX slider 0 → combat/roll/wave silent; UI slider 0 → UI silent (`UiSfx.volume`); master 0 → all.
- **Reduced motion:** UI and SFX still play (live rule); only camera shake and particles reduce (L1).
- **Ducked:** Music group at 25–40% during Epic/Legendary/boss_clear (tween back over 0.6 s).
- **Over voice cap:** lowest priority, oldest first, is stopped (§6).

## 6. Numbers
- **Global voice cap:** 24 SFX+UI voices (`shardfall_audio.md` Tech, "~24 on mobile"); proposed **16 on touch**, 24 on desktop. Prio 1 cues never drop and never count toward a per-cue cap overflow.
- **Per-cue caps** are in §4 (`max`, touch / desktop). Hits share one pool: all `hit*` together ≤ 6 touch / 10 desktop.
- **Cooldowns:** same cue on the same target ≥ 0.05 s apart; `player_hurt` 0.25 s; `loot_collect` one per batch.
- **3D:** combat cues parent to an Attachment on the enemy / mark; `RollOffMode` InverseTapered, `RollOffMinDistance` 10, `RollOffMaxDistance` 90 (arena width). Party members' hits on far enemies fall off naturally.
- **Levels:** base volumes 0.25–0.75 (§4); nothing above 0.75 base. Legendary and boss cues are the loudest; ticks the quietest.
- **Lengths:** ≤ 0.6 s for anything that can repeat; ≤ 2 s for one-shots; `boss_enter` 4.5 s is the only long one.

### 6a. Volume and priority rules (v1.1)
**Routing (the only two doors):** every SFX cue is a key in `Audio.CUES`, played with `Audio.cue(name)` (lowercases the name; returns nil for blank or non-`rbxassetid://` ids, so a blank row is silent); every UI tap is an action in `UiSfx.ids`, played with `UiSfx.clip(action)` (unknown → `press`) at `UiSfx.volume(master, ui)`. Heard volume = `Audio.heard(base, slider)` with the `SFX` or `UI` slider (and master). No call site hard-codes an id or a volume; today's literals (`CombatHud.playCue` 0.6, `RollReel` tier cue 0.6 / ping 0.5 / switch 0.35) move to the per-cue base volumes in §4 through the rules table in Q3.
**Priority tiers:**
| Tier | Meaning | Cues |
|---|---|---|
| **P1** never dropped, may steal | the game is telling you something you must know | `wave_start`, `wave_clear`, `boss_enter`, `boss_volley_windup`, `boss_slam_windup`, `boss_slam_impact`, `boss_clear`, `run_win`, `run_wipe`, `rare`, `epic`, `legendary`, live `red` `yellow` `purple` `blue` |
| **P2** own feedback | your own action or your own harm | `crit`, `shield_block`, `dodge`, `perfect`, `player_hurt`, `common`, `uncommon`, `bag_full`, `boss_slam_fizzle` |
| **P3** combat bed | many at once, fine to thin | `hit`, `hit_ember`, `hit_frost`, `hit_void`, `kill`, `loot_collect` |
| **P4** texture | first to go | `reel_tick` |
| UI group | separate pool, never stolen by SFX | `UiSfx` actions (§4d) |
**Voices:** total **16 on touch / 24 on desktop** (Q4 still open). Inside that: **4 reserved for P1** (a boss slam always has a voice), **2 reserved for the UI group**, P3 hits share one pool of **6 touch / 10 desktop**. **Steal rule:** a new cue over its cap (per-cue `max` in §4, pool, or total) stops the playing voice with the **lowest priority, then the oldest**, but only if that voice is a lower tier than the new cue; otherwise the new cue is dropped (a P3 hit never stops a P2 crit). P1 cues never drop and never count against a per-cue cap.
**Ducking (`Music` group tween, plus one SFX rule):**
| Trigger | Target | Hold | Restore |
|---|---|---|---|
| `epic` | Music → 40% | 1.0 s | 0.6 s tween |
| `legendary` | Music → 25% | 1.8 s (Q1 closed) | 0.6 s |
| `boss_clear` | Music → 30% | 2.0 s | 0.6 s |
| `boss_enter` | crossfade to `gnarlBoss` bed (`Audio.FADE_SECONDS` 2) | — | — |
| `boss_slam_windup` → `boss_slam_impact` | **P3 hit pool → 60%** so the slam reads over a crowd | windup + 0.3 s | 0.3 s |
Ducks never stack: the lowest target wins, the longest hold wins. Sliders still apply on top (a ducked Music at slider 0 stays 0).
**Per-cue volume:** base `Sound.Volume` per §4 rows (0.25 tick → 0.75 Legendary / boss impact / boss clear); **nothing above 0.75 base**; P3 combat cues ≤ 0.5 so a full pool (6 × 0.5) never beats one 0.75 P1 cue in perceived loudness; pitch variance per §4 (`PlaybackSpeed`).
**Spam caps (mobile first; desktop in brackets):**
| Cue / group | Cap |
|---|---|
| all `hit*` | pool 6 [10] voices; ≤ 12 [20] starts/s; same target ≥ 0.05 s apart |
| `crit` | hitter only (2D), ≤ 4 [6] starts/s |
| `kill` | ≤ 6 starts/s; pitch ladder +1 semitone per kill within 1 s, cap +4 |
| `player_hurt` | 0.25 s cooldown |
| `loot_collect` | one per loot batch, local player only |
| `reel_tick` | ≤ 20 starts/s, max 2 voices |
| `toast` / `bag_full` | 1 at a time (one toast lane) |
| UI taps | same action ≥ 0.08 s apart, max 1 voice per action |
| Party members' cues | 3D with roll-off (§6); their `crit` / `dodge` / `perfect` / `player_hurt` are never heard by others |

## 7. Edge cases
- **Party of 4, wave 12:** up to ~16 hits/s; the shared hit pool + per-target cooldown keep it to ≤ 6 voices on touch; crits only play for the hitter.
- **x10 roll:** one tier cue (best), see §4b.
- **Lag / late attributes (#439):** windup cues start at the **remaining** time (seek `TimePosition` = elapsed) so the impact still lines up; < 0.15 s left → skip the windup, play impact only.
- **Boss dies mid-windup:** stop windup cues at once; play `boss_clear`.
- **Wipe in the same frame as wave clear:** play `run_wipe` only (no `wave_clear`), matching the "loot first, gray fade" order (L1).
- **Flag off** (`enemyTypes`, `buffDraft`, `waveArena`): cues for those systems never fire; blank rows cost nothing.
- **Unknown cue names:** `Audio.cue` returns nil (silent); `UiSfx.clip` falls back to `press`. Don't rely on either as a feature.
- **v1.1 Reveal skipped by settings:** (v1.2: default `skipAt = "off"`, so this only happens after a player opts in.) With `skipAt` at or below a tier, D = 0 for that tier (live rule); the tier cue still plays once at the card show so the ladder is never silent.
- **v1.1 Roll during a wave (not V1):** rolls are hub-only; if a roll cue and a P1 wave cue ever overlap, both play (both P1) and the Music duck rule applies once.
- **Licensing:** only Roblox-licensed free Creator Store audio or audio Kevin owns (G-047 flags). No paid assets, no other game's sounds.

## 8. Mockups
`mockups/01-run-cue-timeline.svg`: one run on a timeline (roll → wave start → fight → clear → boss windups/impact → win) with each cue's lane, length and priority, plus the 5-tier rarity ladder (length × loudness). Fake data. PNG on the box only.

## 9. Build split
- **Ghost (client):** add the new keys to `Audio.CUES` as `""` (one row each, §4); a small pooled player (reuse Sounds instead of `Instance.new` per cue), per-cue caps, priority drop, pitch range via `PlaybackSpeed`, Music ducking; call sites in CombatHud (element hits, crit, block, hurt), RollReel (`reel_tick`, x10 best-only), wave/boss HUD listeners. UI mapping (§4d) uses the existing `hubFn.playUi`.
- **Echo (server):** the hooks already asked for in L1 §9 (wave-start, wave-clear, loot-granted with held count, boss-enter, run-end) + `element` and `crit` on damage payloads (if not already present) + the #439 boss attributes. No audio on the server.
- **Kevin / later:** pick and paste licensed ids (G-047 fill order). Nothing is bought.
- **Havoc:** 12-enemy party-of-4 stress (voice cap holds, no clipping), x10 roll, lag test on the windups, mute sliders.

## 10. Pass criteria
- [ ] Eyes closed, testers can tell Common / Rare / Legendary apart (3/3) and say "boss slam coming" from sound alone.
- [ ] Testers tell Ember / Frost / Void hits apart at ≥ 2/3 on a phone speaker.
- [ ] Wave 12 + party of 4 on a low-end phone: ≤ 16 voices, no audible crackle, ≥ 30 FPS unchanged.
- [ ] Slam windup sound ends exactly on impact (±50 ms) including after a lag spike.
- [ ] SFX/UI sliders at 0 silence their groups; reduced motion leaves sounds on.
- [ ] Every cue is a key in `Audio.CUES` or an action in `UiSfx.ids`; no id is hard-coded at call sites.
- [ ] (v1.2) Fresh profile (default Settings, `rolls.skipAt = "off"`): a Legendary roll plays the full 2.2 s reveal and the 1.8 s cue; it is not skipped.
- [ ] (v1.1) Reveal lengths measure 0.6 / 0.9 / 1.3 / 1.65 / 2.2 s (±50 ms) and every tier cue starts on the reel stop (±1 frame).
- [ ] (v1.1) In a wave-12 party-of-4 stress, a boss slam windup and impact are always heard (P1 reserve), and the hit pool audibly drops under the slam.

## 11. Open questions (answer by number)
1. ~~**@Kevin (taste):** Legendary reveal = choir swell + impact + a 4-note main-theme snippet (≈ 1.8 s, Music ducks). Or shorter (1.0 s, no theme)? Recommended: 1.8 s with the snippet; it's the moment players crave. *(v1.1: still open.)*~~ **CLOSED v1.2 (Ghost, DP29, Kevin pre-approved): 1.8 s with the snippet.**
2. **@Kevin (taste):** Wipe sound = soft descending chord (no "fail" sting), matching "always keep loot". Recommended: yes.
3. **@Ghost:** Keep cue ids only in `Audio.CUES` (rec, it's already the "Config" for ids) or also mirror the per-cue numbers (prio, max, volume, pitch) as a `Config/Audio` table for Echo's Config rule? Recommended: one small `Audio.CUE_RULES` table next to `CUES`, later.
4. **@Ghost:** Touch voice cap 16 (rec) vs the doc's ~24?
5. **@Echo:** Do damage payloads already carry `element` and `crit` for the client? If not, add both (read-only fields, no Config change).
6. **@Ghost:** OK to reuse the built-in `switch.wav` as the `reel_tick` placeholder (RollReel already plays it at 0.35)? Recommended: yes.
7. ~~**@Ghost:** `Settings` defaults `rolls.skipAt = "legendary"`, and `skipsCutscene` returns true when the tier rank ≥ the gate, so `RollReveal.duration` reads as **0 for Legendary by default** (no reel; the 2.2 s Legendary reveal would only show if a player changes the setting). Intended? Recommended: default `skipAt = "off"` for V1 so new players see the Legendary moment; the setting stays for veterans.~~ **CLOSED v1.2 (Ghost, DP29): default `rolls.skipAt = "off"`; Kevin approved the 2.2 s Legendary reveal and it must play.** Builder note for Ghost: one-line default change in `Settings.luau` (Prism does not edit it).
8. **@Ghost:** Where do the 5 reveal lengths live: a `RollReveal.TIER_SECONDS` table (Common 0.6 · Uncommon 0.9 · Rare 1.3 · Epic 1.65 · Legendary 2.2) multiplying the existing scaled marks, or a column next to `Rarities`? Recommended: `RollReveal.TIER_SECONDS`, `RollReveal.duration` picks it instead of the flat 1.65; `short` / `instant` / paid rules unchanged.
9. **@Ghost:** OK to reserve 4 voices for P1 and 2 for UI inside the 16 / 24 total, and duck the hit pool to 60% under a boss slam? Recommended: yes.

## Decision log
- 2026-10-24 (Ghost GO 11:55Z, Kevin pre-approved for Prism to write it; Prism): **L5 v1** cue list for hits, roll reveal per tier, wave start/clear, boss slam (+ volley, enter, clear), UI taps, with priority / voices / volume / pitch / placeholders. Not approved as a Vision & Design Rules decision.
- 2026-10-24 (Ghost row 403c31ca388381818692c13be76248b2, Kevin pre-approved; Prism): **L5 v1.1** folded on the same branch: tier-scaled reveal 0.6–2.2 s and explicit volume / priority rules. Not approved as a Vision & Design Rules decision.
- 2026-10-24 (Ghost DP29 row https://app.notion.com/p/403c31ca3883816cbc9cc827b26d3c96, Kevin pre-approved; Prism): **L5 v1.2** Q1 closed (Legendary cue 1.8 s), Q7 closed (default `rolls.skipAt = "off"`). Still a proposal until Kevin copies it into Vision & Design Rules.

## Later (not V1)
"Reduce loud sounds" toggle and captions for key cues (named in `shardfall_audio.md`; not in `Settings.luau`), per-class hit palettes, adaptive music stems per wave, enemy voice barks. All go to the Ideas Backlog marked NOT APPROVED.

## Roblox build notes
- `Sound` instances in the `SFX` / `UI` `SoundGroup`s (`MusicController` creates them from `Audio.GROUPS`); 2D cues parent to `SoundService` (as `CombatHud` does), 3D cues to an `Attachment` on the enemy or slam mark.
- Pitch variance = `Sound.PlaybackSpeed = 1 + random(-v, v)` (also shifts length slightly; fine for ≤ ±6%). Don't use `PitchShiftSoundEffect` per hit (cost).
- Ducking = `TweenService` on the `Music` group's `Volume`; no sidechain compressor needed.
- Pool and reuse Sounds; `Sound.Ended` returns them to the pool (today's `Instance.new` + `Debris` per cue is fine for UI, not for wave-12 hits).
- **Voice manager (v1.1):** one client module owns the pool: a table of playing `Sound`s with `{ cue, tier, started }`; on a new cue, check per-cue `max`, pool, reserve and total, then steal per §6a or drop. Ducks are `TweenService` tweens on `SoundGroup.Volume` (Music; SFX hit pool via a child `SoundGroup` "Hits" under `SFX`), restore with `TweenInfo` 0.6 s / 0.3 s. Reveal timing reads `RollReveal.duration` and the scaled marks; the tier cue stays on the `spinProgress ≥ 1` edge as live.
- Timing to server events with `workspace:GetServerTimeNow()` (as #439) and `Sound.TimePosition` to seek on late arrival.
- Ids only as `rbxassetid://<n>` from licensed free Creator Store audio, or the existing `rbxasset://sounds/` built-ins. No uploads, purchases or Robux. Rarity colors (`Rarities.COLOR`) stay visual only.
- **Phone speakers:** every bass-heavy cue (Epic, Legendary, boss slam, boss enter) needs a 1–3 kHz click/transient layer so it still reads on a phone speaker; mix check on a phone at 50% system volume.
