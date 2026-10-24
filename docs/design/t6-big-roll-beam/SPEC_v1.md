# T6 Big-Roll Beam + Server Line, Spec v1

Owner: Prism (design, docs only: no code, no Config, no save edits). Builders: Ghost (client VFX, toast, chat line), Echo (server event, rate caps). Base: `cursor/live-build-9721`. Status: **proposal, not approved.**
Asked for in: Ghost's Agent Board row https://app.notion.com/p/403c31ca3883813bb309d78b13d87259 (Oct 24, 2026 12:32Z, Kevin pre-approved). ACK: https://app.notion.com/p/403c31ca38838177ab48faab126dd578.

**Builds on (link, don't copy):**
- **PR #413** town hub v1.1 §5 "Pull beam (Phase S)": vertical `Beam` in the rarity color rising 60 st from the Crackstone, 2.5 s, one-line toast via the D3 lane, **per-server only, not saved, no list, no ranking** (decision 8), max 1 beam at a time, queue at 1 s spacing, cap 3 queued. **This spec is the detailed version of that note**; it changes three things, flagged ⚑ below.
- **PR #397** Roll/Reveal: Epic 1.30 s / Legendary 2.20 s reveals. The beam fires **after the roller's reveal lands**, so it never spoils a reveal.
- **Live code (read only):** `Shared/Rarities.luau` `COLOR` (Epic 186,96,240 = #BA60F0 · Legendary 255,196,64 = #FFC440); `Shared/RarityConfig.reveal()` sets `announce = legendary or mythic` (**Epic is not announced today**); `RollService.broadcast()` fires the `Remotes.RollAnnounce` RemoteEvent to all clients with `{ text = "<Name> rolled <shard> (<rarity>)", rarity, crossServer }`; cross-server (`MessagingService`, `RarityConfig.TOPIC`) is **Mythic only** and Mythic/Secret are not V1 tiers. `Settings`: `graphics.vfx` (0–1), `graphics.quality`, `hud.otherVfx`, `camera.flash`.

---

## 1. Goal
When anyone on the server lands an **Epic or Legendary**, everyone in Crater Square sees a tall beam in that tier's color rising from the roller, visible from both spawn and the Gate pad, plus one short server line in chat. It sells "big rolls happen here" to new players and makes the roller feel seen, without spamming, without costing phone frame rate, and without saving anything.

## 2. Where it lives
- **Server (Echo, request):** one new rule: `RarityConfig.reveal().announce` becomes **Epic or better** for the beam/line (⚑ change 1; today Legendary+). `RollService` sends a **new** `Remotes.BigRoll` RemoteEvent (or extends `RollAnnounce`'s payload) with `{ userId, displayName, itemName, rarity, count, at }` after the reveal timer; the server owns the spam caps (§6). Per-server only; the Mythic cross-server path is untouched and stays off in V1.
- **Client (Ghost, request):** a `BigRollFx` controller that spawns the beam, the base burst and the BillboardGui tag; one toast in the D3 lane (loot/rarity priority); one `TextChatService` system line. Prism does not edit `RollReveal` or any Ghost-owned file.
- **World:** Crater Square only (#413). In the arena place, no beams (other players aren't there); the chat line still shows.
- **Settings (existing, no new field):** `hud.otherVfx = false` hides **other players'** beams and toasts (your own still shows); `graphics.vfx` scales particles; `camera.flash = "off"` removes the flash-in.
- **Not here:** Robux, odds boosts, "buy to roll" prompts, leaderboards, saved history (decision 8).

## 3. Flow
1. Player A taps ROLL → server draws Epic/Legendary → A's client plays the #397 reveal (Epic 1.30 s / Legendary 2.20 s).
2. At **reveal land + 0.2 s** (server timer: reveal seconds from `RarityConfig.reveal`; skipped reveals fire at the skip time but never earlier than 0.6 s after the roll), the server checks the caps (§6) and fires `BigRoll` to every client.
3. Every client in the hub: beam rises at A's position (⚑ change 2: at the **roller**, not fixed at the Crackstone; if A is not standing in Crater Square or is > 96 st from spawn, at the Crackstone (-12, 52)). Base burst + BillboardGui tag "**A · LEGENDARY**".
4. Other players: one toast in the D3 lane: "★ A pulled a Legendary!" (Epic: "✦ A pulled an Epic!"). The roller gets no toast (they just saw the reveal).
5. Everyone (roller included): one chat system line (§6 copy) in the tier color.
6. Beam holds, then fades. Done. Nothing is written to any save.

x10 batches (`RollX10`): one event per batch, using the **best** tier in the batch; `count` = how many Epic+ landed; copy uses the count (§6).

## 4. Layout
**World (all screen sizes):** beam column 60 st tall (⚑ change 3: Legendary 80 st so the top tier reads taller from the Gate). From spawn (0, 30) the Crackstone is ~29° left and 25 st away, so a beam there or anywhere on the court sits inside the ~70° landscape cone; on 390×844 portrait (~40° cone) the top 40% of the column is above the Gate arch (18 st) and readable even when its base is off to the side. From the Gate pad (0, 98) looking back north, the spawn and Crackstone are 48–68 st away and the column clears the arch. The BillboardGui tag sits at the column top (StudsOffset 0, +2).

**Screen pieces:**
| Piece | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Toast (others only) | D3 lane x 88–266 × y 231–267 (36 tall, not tappable) | x 411–651, y 8–44 | x 524–784, y 8–44 | x 480–800, y 66–102 |
| Chat line | Roblox chat window (TextChatService; position is Roblox's) | same | same | same |
| BillboardGui tag | world, 180×36 at 390 wide, text 16 px min | 200×36 | 200×36 | 220×40 |
| Off-screen beam | **no edge arrow** (the chat line + toast already tell you; keeps edges clear for the T3 guide arrow) | — | — | — |

No new tap targets (the toast is info only; Settings toggles are the existing ≥ 44 px rows). Nothing enters the center keep-out except world-space parts.

## 5. States
| Element | Spawn-in | Hold | Fade | Reduced / low |
|---|---|---|---|---|
| Core beam | Width0/Width1 0 → 3 st over 0.25 s (Quad Out), light rises bottom → top via the Transparency NumberSequence over 0.35 s | Epic 2.5 s · Legendary 3.5 s, TextureSpeed 0.6 scroll | Width → 0 over 0.4 s | `graphics.vfx` < 0.5 or quality ≤ 3: core beam only, no texture scroll |
| Halo beam | Width 7 st, Transparency 0.7, 0.25 s in | same | 0.4 s | dropped on low |
| Base burst | `ParticleEmitter:Emit(n)` once at spawn-in: Epic 16, Legendary 28 | — | lifetime 0.6–1.0 s | `n × graphics.vfx`, rounded; 0 on low |
| Legendary ring | flat shockwave `ImageLabel` on a `SurfaceGui` ground part, Size 4 → 24 st over 0.6 s | — | ImageTransparency → 1 | dropped on low / flash off |
| BillboardGui tag | fade 0.2 s | as beam | with beam | always on (text is cheap) |
| Toast | slide 0.26 s | 2.5 s | 0.2 s | same |

`hud.otherVfx = false`: other players' events show **only** the chat line.

## 6. Numbers and copy
**Colors (from `Shared/Rarities.luau`, never hard-coded twice):** Epic 186,96,240 · Legendary 255,196,64. Beam `Color` = ColorSequence(tier → tier lerp 35% toward 255,255,255 at the top). Toast stroke = tier color 1.5. Element colors (Ember #E84814, Frost #5CD6FF, Void #C04888) are **not** used in the beam; one color = one tier, so it reads at a glance.

**Phone frame-rate budget (per event, per client):** ≤ 2 Beams · 1 ParticleEmitter (Rate 0, Emit only, ≤ 28 particles, LightEmission 1, no LightInfluence work) · 0 lights (no PointLight; LightEmission does the glow) · ≤ 4 tweens · 1 BillboardGui · cost target **≤ 0.5 ms/frame** on a mid phone (Havoc: iPhone 11 / Galaxy A52 class) and no drop under 55 fps at 60 cap with 20 players in the hub. **Server-wide max 1 beam live at a time.**

**Spam caps (server, Echo):**
- Server-wide: **1 beam at a time**; next queued at 1 s after the previous fade; **queue cap 3**, extra events drop the beam but keep the chat line.
- Chat lines: **max 4 per 30 s server-wide**; overflow collapses into one line at the end of the window: "+N more big rolls." (count only, no names).
- Per player: **max 1 event per 8 s**; inside that window an Epic is merged into the next line's count; a Legendary always gets its own event once the window ends (held, not dropped).
- Same player, same tier, 5 events in 60 s → that player's Epics stop beaming for 60 s (line only). Legendary not throttled beyond the 8 s window.
- Proposed Config (Echo; Prism doesn't write Config): `BIGROLL_MIN_TIER = "Epic"`, `BIGROLL_QUEUE = 3`, `BIGROLL_GAP = 1`, `BIGROLL_CHAT_MAX = 4`, `BIGROLL_CHAT_WINDOW = 30`, `BIGROLL_PLAYER_GAP = 8`, `BEAM_HOLD = { Epic = 2.5, Legendary = 3.5 }`, `BEAM_HEIGHT = { Epic = 60, Legendary = 80 }`.

**Copy (uses `DisplayName`; item names are game data, no player text, so no filter call needed; Echo to confirm):**
| Case | Chat system line (RichText, name + tier in tier color) | Toast (others) | Billboard tag |
|---|---|---|---|
| Epic | "✦ **{name}** pulled an **Epic** {item}!" | "✦ {name} pulled an Epic!" | "{name} · EPIC" |
| Legendary | "★ **{name}** pulled a **LEGENDARY** {item}!" | "★ {name} pulled a Legendary!" | "{name} · LEGENDARY" |
| x10 with several | "★ **{name}** pulled a **LEGENDARY** and 2 Epics!" | "★ {name} pulled a Legendary!" | best tier |
| Overflow | "+{n} more big rolls." | — | — |
| Your own (chat only) | same line with "You" → "★ **You** pulled a **LEGENDARY** {item}!" | none | "{name} · LEGENDARY" |

No odds in the line (luck changes them, and the reveal already shows the honest "1 in N"), no "near miss", no "buy" link.

## 7. Edge cases
- **Roller leaves mid-beam:** beam finishes at the last position (per-server, nothing saved, #413).
- **Roller in the arena / another place:** chat line only on that server; hub players on the same server see the beam at the Crackstone.
- **Two Legendaries in the same second:** first beams, second queues (1 s gap); both lines show (within the 4/30 s cap).
- **Join mid-beam:** the late joiner doesn't get the event (not replayed).
- **Free tutorial rolls (T3):** an Epic+ 3rd tutorial roll **does** beam (good for the server, and the new player sees their own beam on the way to the Gate). The T3 Beam to the Gate is a separate thin cyan path, never confused with a tier column.
- **Quick roll / skipped reveal:** fires at skip time, ≥ 0.6 s after the roll.
- **Paid vs free:** identical (live rule: "A paid roll and a free roll share every display rule").
- **Studio / no TextChatService:** toast still shows; chat line skipped silently.
- **Colorblind (`access.colorblind`):** tier name is always in the text ("EPIC" / "LEGENDARY"), and Legendary is taller + has the ring, so color isn't the only cue.

## 8. Mockups
SVG in `mockups/` (fake names, original art):
- `01-from-spawn-phone-390x844.svg` — spawn shot, Legendary column at the Crackstone, tag, toast in the D3 lane, chat line, keep-out.
- `02-from-gate-landscape-667x375.svg` — view back from the Gate pad: Epic column, chat line, toast in the top band; 800×400 + desktop notes.
- `03-timing-and-caps.svg` — event timeline (reveal → beam → fade), queue + chat caps, copy table, budget.

## 9. Build split
- **Echo (server):** `BigRoll` event after reveal land; Epic+ threshold for this path only; caps §6; x10 merge; no save writes; analytics: events per hour, dropped by cap.
- **Ghost (client):** `BigRollFx` (beam, halo, burst, ring, tag), D3 toast, TextChatService system line (`TextChannel:DisplaySystemMessage` with RichText), `hud.otherVfx`/`graphics.vfx` hooks.
- **Prism:** beam_strip and ring textures in the Phase S art pass; color check in Studio.
- **Havoc:** 20 bots rolling x10 for 2 min on a phone: fps, cap behavior, chat flood, late joiner, leave mid-beam.

## 10. Pass criteria (playtest)
1. Epic and Legendary rolls beam for every player in Crater Square; Common/Uncommon/Rare never do.
2. The column is visible from **both** spawn and the Gate pad at 390×844 portrait and 667×375 landscape.
3. The beam never appears before the roller's reveal has landed.
4. With 20 players spamming x10 rolls for 2 minutes: never more than 1 beam at once, ≤ 4 chat lines per 30 s, and the phone holds ≥ 55 fps (60 cap).
5. `hud.otherVfx` off hides other players' beams and toasts; the chat line stays.
6. Nothing is saved, listed or ranked (save diff check; no new DataStore keys).

## 11. Open questions (answer by number)
1. **@Ghost:** ⚑ Beam at the **roller** (falls back to the Crackstone) instead of always at the Crackstone (#413)? Shows *who* rolled. **Recommended: roller.**
2. **@Ghost / @Echo:** Epic+ for the beam/line while the old `announce` flag stays Legendary+ for anything else that reads it? Or just change `announce` to Epic+? **Recommended: a separate `BIGROLL_MIN_TIER`, so the reveal code doesn't change.**
3. **@Echo via @Ghost:** New `Remotes.BigRoll` event, or extend `RollAnnounce`'s payload? **Recommended: extend `RollAnnounce`** (one remote, the client already listens).
4. **@Kevin (taste):** ⚑ Legendary column **80 st + ground ring**, Epic 60 st plain — or both 60 st as in #413? **Recommended: Legendary taller.**
5. **@Kevin (taste):** Chat line wording "pulled" (matches #413) vs "cracked" (matches "Crack your first shard")? **Recommended: "pulled"** (reads as gacha slang kids know; "cracked" for the tutorial voice only).
6. **@Kevin (taste):** Show the item name in chat ("…a LEGENDARY Frostbite Edge!") or tier only? **Recommended: show it**; it makes other players want that item.

## Decision log
- 2026-10-24 (Prism): v1 on `prism/t6-big-roll-beam`, details #413's pull-beam note. Changes flagged ⚑ (Epic threshold, beam at roller, Legendary taller). Open: Ghost/Echo 1–3, Kevin 4–6. Not approved.

## Later (not V1)
Mythic/Secret cross-server line (live path, tiers parked), a per-player "big roll" emote, beam skins. All go to the Ideas Backlog as NOT APPROVED. No paid beam colors.

## Roblox build notes
Stock Roblox only: `Beam`, `Attachment`, `ParticleEmitter`, `BillboardGui`, `SurfaceGui`, Frames/ImageLabels/TextLabels, `UICorner`, `UIStroke`, `UIGradient`, TweenService, `TextChatService`. No blur, no post-processing, no PointLights.

| Element | Instances |
|---|---|
| Column anchor | anchored, CanCollide/CanQuery/CanTouch false, Transparency 1 `Part` at the roller's feet; `Attachment` A0 at y 0, A1 at y 60/80 |
| Core beam | `Beam` A0→A1, Texture beam_strip (64×256 tileable soft gradient), TextureMode Stretch, TextureSpeed 0.6, Width0 3 / Width1 2, LightEmission 1, LightInfluence 0, FaceCamera true, Segments 1, Color ColorSequence(tier → tier+35% white), Transparency NumberSequence (0 → 0.1 @0.7 → 1 @1.0) |
| Halo beam | second `Beam` same attachments, Width 7, Transparency 0.7 → 1, no texture scroll |
| Base burst | `ParticleEmitter` Rate 0, `:Emit(16|28)`, Texture spark_32, Size 1.2 → 0, Speed 12–18, SpreadAngle 180,15 (outward ring), Lifetime 0.6–1.0, LightEmission 1, Color tier |
| Legendary ring | flat Part + `SurfaceGui` (Face Top) + `ImageLabel` ring_256, Size tween 4 → 24 st (part size), ImageTransparency 0 → 1, 0.6 s |
| Tag | `BillboardGui` on A1 (StudsOffset 0,2,0; MaxDistance 200; AlwaysOnTop false; LightInfluence 0) + `Frame` (`UICorner` 0.5 scale, `UIStroke` tier 1.5, bg 16,14,24 @0.2) + `TextLabel` BuilderSansBold 16 |
| Toast | the D3 toast (`Frame` + `UICorner` h/2 + `UIStroke` tier 1.5 + `TextLabel` 13–14) |
| Chat line | client `TextChatService.TextChannels.RBXSystem:DisplaySystemMessage('<font color="#FFC440">…</font>')` |

Image assets (PNG, transparent): beam_strip 64×256 · spark_32 32×32 · ring_256 256×256.
