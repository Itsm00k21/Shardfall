# Hard Accent Pass ("Chip + stroke"): Gate pad + HUD, Spec v1.1

Owner: Prism (design, docs only, no code). Builders: Ghost (client accents on the dock, pad, HUD), Echo (tier state the client reads). Base: `cursor/live-build-9721`. Status: **v1.1, Ghost Q1–Q4 decided** (Ghost board row https://app.notion.com/p/403c31ca38838155a532f79564499765, 09:45Z Oct 24, 2026, Kevin pre-approved; Kevin taste Q5 stays PROVISIONAL). v1 came from Ghost's GO on the Agent Board, Kevin pre-approved: https://app.notion.com/p/403c31ca388381758d47e930e50ccb27, item 3, Oct 24, 2026). Gray-box only (pre-Phase S). The Hard accent color itself is still a **PROVISIONAL** Kevin taste call (Hard mode selector Q4). Not an official Vision & Design Rules decision until Kevin approves it.
Asked for in: Ghost's board row item 3: "Hard accent pass on Gate pad + HUD, against #430 (hardMode flag, default off)." Roadmap **5.4 Hard mode (Lv 5)**.

Sources (link, don't copy):
- **PR #430** (tip `a0e037e`, "Keep Hard pad tiers per player and ship hardMode off", on `7d991b4`), read only:
  - `Shared/LaunchGate.luau`: `hardMode = false` ("Hard at the gate. Off: Normal only. The Hard row stays.") and `extraDifficulties = false` (Medium, Nightmare, Insane).
  - `Shared/HardMode.luau`: `offered("hard")` is false while the flag is off, so `accept` returns `CLOSED` = "That difficulty is closed." **Each player's tier is server memory for that player only**: "One pick does not change anyone else." `touch` reads only the touching player's tier ("Someone else's Hard does not refuse them, pull them onto Hard, or change their tier"). A join starts on Normal. Strings: `REFUSED` "Hard unlocks at Lv 5.", `PAD_REFUSED` "This party is on Hard (Lv 5).", `CLOSED`.
  - `Shared/Config/Economy.luau` `DIFFICULTIES.hard`: `levelGate 5`, `hpMultiplier 2`, `damageMultiplier 1.5`, `tokenMultiplier 2`, `fragmentMultiplier 2` (now matches the locked Core Loop; Hard selector Q2 is done).
  - `DungeonService`: `action "difficulty"` → `setDifficulty` (this player only); the pad calls `enterFromPad` with the player's own tier; `enter` re-checks Lv 5 so a spoofed remote can't skip the pad; the clear grant uses `HardMode.tokens`.
- **Hard mode selector v1.1** (`prism/hard-mode-selector`, compare link, no PR yet): dock toggle + Hard card (direction A), accent danger 230,80,96 (Q4 PROVISIONAL), selected fill 74,28,40, text 255,170,180, pad rim + arch swirl go red, one HARD chip on the wave counter, one "Hard ×2" line on results. **This pass keeps all of that** and adds the rules for flag-off, per-player tiers, and how loud the accent may be.
- Also matched: **Wave HUD v1.1** (#428: HARD chip + red stroke on the chip, Hard boss HP red, Normal boss HP orange PROVISIONAL), **Results v1.2** (#429: stats wing danger stroke, HARD ×2 tags), **Boss telegraphs v1** (`prism/boss-telegraphs`: telegraph orange 255,120,40 is the same on every tier), **#420** (keep-out, D3 toast lane), **#412** Gate dock, **#413** Crater Square pad/arch.
- Chrome: PR #392 `docs/ui/reference/STYLE.md`. Rarity colors (`Shared/Rarities.luau`: Common 168,168,176 · Uncommon 64,186,98 · Rare 72,142,255 · Epic 186,96,240 · Legendary 255,196,64) are unchanged on Hard; Hard-only drops keep their rarity stroke plus a small HARD tag.

## 0. Directions (pick one) and recommendation
Mockup: `mockups/08-directions.svg`.

| | Direction | How it plays | Good | Bad |
|---|---|---|---|---|
| **A** | **Chip + stroke** | Hard shows as **a HARD chip and 2 px red strokes** on your own pieces: the dock Hard segment, the dock label, the pad rim + arch swirl (set on your client only), your name tag, the wave chip, the boss bar, and the results wing. Nothing else changes (v1.1: no sky tint, Q3). | Always readable, never louder than danger/HP red, very cheap (property changes, no new parts), works with #430's per-player tiers. | Subtle in the world; relies on the HUD for "I'm on Hard". |
| B | Full tint | Every HUD panel shifts to a red-tinted panel color, plus a red edge vignette in the arena. | Strong mood. | Red everywhere means nothing reads as danger any more (HP, wipe, Hard boss HP, refusals). It also drowns the telegraphs and costs a full restyle. |
| C | World only | Red pad and red sky; the HUD is identical to Normal. | Cheapest. | In a dark arena there's no proof on screen that you're on Hard, and screenshots and clips can't show it. |

**Recommendation: A.** It answers "am I on Hard?" from any screen in under a second, keeps red meaningful, and costs only property changes. The rest of this spec is A.

## 1. Goal
A player can always tell, from the HUD alone, whether **they** are on Hard, at the Gate and in the arena, on all 4 screen sizes. Hard looks like an earned badge, not an alarm. When `hardMode` is off (as it ships), there are **zero** Hard pixels anywhere.

## 2. Where it lives
- **Gate (Ghost, client):** Gate dock Hard segment + label (Hard selector §5), pad rim + arch swirl recolor, own name tag chip. The pad recolor is a **client-local property change**: the pad is shared, but #430 tiers are per player, so the server never recolors it. Other players keep seeing a gold pad.
- **Arena HUD (Ghost):** wave chip (HARD chip + 2 px red stroke), boss bar (HARD chip + red HP fill + red stroke), results stats wing (red stroke + HARD ×2 tags). All already specified in #428 / #429. This pass just pins the rules.
- **Arena world:** ~~a light warm tint via `Lighting.Ambient` / `OutdoorAmbient`~~ **No sky tint (v1.1, Ghost Q3).** The arena looks the same on both tiers; Hard reads from the HUD.
- **Server (Echo):** the client needs to read its own tier. **Decided (Q2):** the client reads a **server-set per-player tier attribute** (working name `Tier`, "normal" / "hard"; Echo names it) written wherever `HardMode` writes `sessions`. The run's tier comes with the run start the client already gets. No save field (schema stays 26).
- **Not here:** enemy red rims/Highlights (Phase S, after the fun test), Hard pad trails, any Robux, Nightmare (not V1).

## 3. Flow
| Step | Trigger | Accent shown |
|---|---|---|
| 0 | `LaunchGate.hardMode` **off** (default) | Dock shows chevron · **Normal** (static label, not a toggle) · START. No Hard segment, no lock, no "Lv 5", no Hard card, no unlock toast, no HARD chip anywhere. Mockup 02. |
| 1 | Flag on, account Lv < 5, step on the pad | Hard segment locked (Hard selector locked flow). No red yet: a locked segment is dim violet with the padlock. |
| 2 | Flag on, Lv ≥ 5, Hard not picked | Hard segment idle: row fill + 1 px red stroke at 0.6 + pink text. That is the only red on screen. |
| 3 | Tap Hard (`action "difficulty"` → accepted) | Segment selected (fill 74,28,40 + gold 2 px). **Your client** tweens the pad rim + swirl to red (0.3 s). Dock label adds "· HARD" in pink. Your name tag gets a HARD chip. Hard card per the selector spec. |
| 3x | Server refuses (`REFUSED` / `CLOSED`) | Segment snaps back to Normal; toast with the server text. No red stays. |
| 4 | START / countdown ends → arena | Pad accents are gone with the hub. Wave chip shows the HARD chip + 2 px red stroke. No sky tint (v1.1). |
| 5 | Wave 5 | Boss bar: HARD chip, red HP fill, red stroke (#428). Boss telegraphs stay orange (boss telegraph spec). |
| 6 | Results | Stats wing red 2 px stroke, HARD ×2 tags (#429). RUN AGAIN sub-line "Hard · same party". |
| 7 | Back in the hub | Your tier is still Hard (session memory) until you change it or rejoin; the accent comes back the next time you're on the pad. |

## 4. Layout
No new panels or positions. Every accent sits on a piece that already has a layout in the Hard selector, Wave HUD and Results specs, so the #420 keep-out and touch targets are unchanged. **Center keep-out:** 390×844 x 117–273, y 296–616 (D1) · 667×375 x 200–467, y 105–274 · 800×400 x 240–560, y 112–292 · 1280×720 x 384–896, y 202–526. The only new on-screen element is the **name tag chip** (world BillboardGui, 34×14 px chip beside the name; it's world UI, so it can be anywhere in 3D).

| Accent | 390×844 | 667×375 | 800×400 | Desktop 1280×720 |
|---|---|---|---|---|
| Dock Hard segment / label | dock x 16–374, y 738–802; label y 733 | dock x 174–492, y 301–361 | dock x 230–570, y 326–386 | dock x 450–830, y 632–696 |
| Wave chip HARD chip | 38×16 at chip x+10, y+8 (chip x 16–150, y 179–223) | chip x 61–197, y 132–176 | chip x 66–222 | chip x 88–268, y 138–182 |
| Boss bar HARD chip | 36×15 inside the bar (x 16–206, y 179–223) | top band x 160–403, y 8–48 | top band x 200–516 | x 440–840, y 110–150 |
| Name tag chip | BillboardGui `Size` UDim2.fromOffset(110, 18), StudsOffset (0, 3.4, 0), `MaxDistance` 60 | same | same | same |
Touch targets: unchanged (dock segments 44 tall, chip 44×44 collapsed). Text on a red chip is 8–10 px heavy ink (badge size, #420 R7).

## 5. States
| Surface | Flag OFF | ON · Lv < 5 | ON · Normal picked | ON · Hard picked |
|---|---|---|---|---|
| Dock Hard segment | **absent** (Normal is a static label) | locked: buttonDim 54,46,78, padlock, "Hard / Lv 5" muted | idle: row 40,34,58 + 1 px 230,80,96 @ 0.6, text 255,170,180 | selected: fill 74,28,40 + gold 2 px, text 255,170,180 |
| Dock label | "Shard Gate · Solo · 15" | same | same | "… · HARD · 12" in 255,170,180 |
| Pad rim + swirl (your client) | gold rim, violet swirl | same | same | red 230,80,96 rim + swirl (0.3 s tween) |
| Name tag | name only | name only | name only | name + HARD chip |
| Wave chip | 1 px row stroke | — | 1 px row stroke | HARD chip + 2 px red stroke |
| Boss bar | gold stroke, orange HP (PROVISIONAL) | — | same | HARD chip, red stroke, red HP |
| Results wing | gold (clear) / row (wipe) stroke | — | same | red 2 px stroke, HARD ×2 tags |
| Arena sky | default | — | default | default (v1.1: no tint) |
Loading: until the client knows its tier, show Normal (the server default). Error: a refused pick reverts every accent in the same frame.

## 6. Numbers
- Accent tokens (PROVISIONAL, Kevin Q4 on the selector spec): accent **230,80,96**; selected fill **74,28,40**; red-family text **255,170,180**; text on red **ink 32,22,10**. Contrast: ink on accent ≈ 4.8:1; pink text on panel 28,24,40 ≈ 9.6:1.
- Stroke: 2 px on Hard surfaces (1 px idle segment at Transparency 0.6). Chip corner h/2.
- Tweens: pad rim/swirl 0.3 s Quad Out; revert 0.2 s.
- Sky tint: **none** (v1.1, Q3).
- Loudness budget: **at most one filled red element per HUD cluster** (the HARD chip). Everything else red is a stroke. Exception: the Hard boss HP fill (#428).
- Hard values the copy may quote (from #430 Config): Lv 5, 2× HP, 1.5× damage, 2× tokens, 2× fragments.
- Copy: "HARD" · "· HARD" · server strings as-is: "Hard unlocks at Lv 5." · "This party is on Hard (Lv 5)." · "That difficulty is closed." (should never show, because the UI hides Hard when the flag is off).

## 7. Edge cases
- **Flag flips at runtime** (Kevin turns `hardMode` on in a live server): the dock rebuilds with the Hard segment next time it opens. Flag turned **off**: any player still holding "hard" is refused at the pad with `CLOSED` (#430 `touch`); the client hides the segment and reverts the accents. **No toast (v1.1, Q4):** flag off = zero Hard pixels, silently.
- **Per-player tiers (v1.1, Q1 decided):** follow #430. Each member picks their own tier; there is no leader pick. The accents follow **your** tier, so a mixed pad shows a HARD chip on the name tags of members who picked Hard. (The Hard selector spec's leader-pick rule needs the same fold; flagged as an open item, not changed here.)
- **Pad recolor is local:** never set the pad color from the server (it would turn the pad red for everyone, which is the exact Havoc P2-430-1 problem #430 fixed in logic).
- **Rejoin:** a join starts on Normal (#430 `noteJoin`), so no accents until the player picks Hard again.
- **Mid-run:** the run keeps its tier; the HUD accent can't change during a run.
- **Telegraphs:** never red, on any tier (boss telegraph spec).
- **Colorblind:** red always comes with the word HARD (chip or label); strokes alone never carry the meaning.
- **Performance:** property tweens only, plus one 34×14 chip per name tag on Hard. No emitters, no Highlights.

## 8. Mockups
SVG in repo (fake data, original art, gray-box world). `mockups/01-gate-hard-phone-390x844.svg` (flag on, Hard picked: segment, label, local red rim + swirl, name tag) · `mockups/02-gate-flag-off-phone-390x844.svg` (as shipped: Normal only, no Hard pixels) · `mockups/03-arena-hard-phone-390x844.svg` (wave chip with HARD chip + stroke; v1.1 no sky tint) · `mockups/04-arena-boss-hard-landscape-667x375.svg` (boss bar + chip on Hard; telegraph stays orange) · `mockups/05-gate-party-landscape-800x400.svg` (per-player tiers: you on Hard, Sam on Normal) · `mockups/06-desktop-1280x720.svg` · `mockups/07-accent-sheet.svg` (tokens + every surface × flag off / locked / Normal / Hard) · `mockups/08-directions.svg` (A/B/C). Live HUD dashed; keep-out cyan dashed. PNG renders are on the box only.

## 9. Build split
Roadmap 5.4. Building waits for Ghost's go and Kevin flipping `hardMode`.
- **Echo (server):** expose each player's tier to their client (Q2 decided: server-set per-player tier attribute, written wherever `HardMode` writes `sessions`); keep the pad color server-side gold. Tests: one player's Hard never changes another player's attribute; the flag off always reads "normal".
- **Ghost (client):** hide the Hard segment when the flag is off; segment/label states; local pad rim + swirl tween; name tag chip; wave chip / boss bar / results accents per #428/#429. No sky tint, no flag-off toast (v1.1).
- **Prism:** Phase S pass (enemy rim, pad VFX, HARD chip glyph) after the fun test; final check of Kevin's Q4 color.
- **Havoc:** two players on one pad with different tiers (each sees only their own red); flag flipped off mid-session; refused pick reverts every accent; rejoin starts Normal.

## 10. Pass criteria (playtest)
1. At 390×844, in the arena, a tester says whether they're on Hard within 1 s, from the HUD only.
2. With the flag off, a tester finds no Hard UI anywhere (no lock, no "Lv 5", no red chip).
3. Two testers on the same pad, one on Hard: the Normal tester sees a gold pad and no HARD chip on their own name.
4. Testers still read red HP / wipe / refusal text as danger on Hard (the accent doesn't drown it).
5. Nothing new enters the keep-out at any of the 4 sizes; touch targets unchanged (≥ 44 px).

## 11. Open questions (answer by number)
Ghost questions 1–4 are **resolved in v1.1** (Ghost, Oct 24, 2026, board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved):
1. ~~Per-player vs leader pick?~~ **Decided:** per-player tier per #430, no leader pick.
2. ~~How does the client learn its tier?~~ **Decided:** read a server-set per-player tier attribute.
3. ~~Arena sky tint?~~ **Decided:** no sky tint.
4. ~~Flag-off toast?~~ **Decided:** no toast; flag off = zero Hard pixels.
5. **@Kevin (taste, still open from the selector spec Q4):** the Hard accent color. PROVISIONAL: danger red 230,80,96. This pass doesn't change it; all accents swap with one token if you pick another color.

## Decision log
- 2026-10-24 (Ghost, board row https://app.notion.com/p/403c31ca38838155a532f79564499765, Kevin pre-approved): **v1.1.** Q1 per-player tier per #430, no leader pick; Q2 client reads a server-set per-player tier attribute; Q3 no sky tint; Q4 no flag-off toast (flag off = zero Hard pixels). Kevin Q5 (accent color) stays PROVISIONAL. Mockups 03, 04, 05, 06, 07 re-rendered without the warm sky.
- 2026-10-24 (Prism): v1 published from Ghost's GO (board row https://app.notion.com/p/403c31ca388381758d47e930e50ccb27 item 3). Recommends direction A (chip + stroke). Checked against #430 `a0e037e` (flag off by default, per-player tiers, Lv 5 / 2× HP / 1.5× dmg / 2× tokens + fragments). Five open questions (Ghost 1–4; Kevin 5). Not approved.

## Later (not V1)
Red enemy rim on Hard (Highlight or a SurfaceAppearance pass, Phase S), a Hard pad ember emitter, a HARD badge on the player list, and a "Hard clears" counter. All go to the Ideas Backlog as NOT APPROVED.

## Roblox build notes
Stock Roblox UI only. No blur, no glassmorphism, no post-processing (no ColorCorrection/Bloom), no web fonts (Builder Sans / GothamSSm). UI motion = TweenService. The mockups are a guide and these notes win.

| Element | Instances |
|---|---|
| Accent tokens | one shared table on the client (e.g. a `Theme.HARD` entry) so Kevin's Q5 color is a one-line swap. Prism doesn't create the file; it's Ghost's call |
| Dock Hard segment | as in the Hard selector build notes: `TextButton` + `UICorner` 8 + `UIStroke` (2 gold selected / 1 danger @ 0.6 idle) + `TextLabel`; hidden (`Visible = false`) and the Normal button becomes a non-interactive `TextLabel` when `LaunchGate.on("hardMode")` is false |
| Pad rim + swirl | **client** `TweenService` on the pad rim `Part.Color` and the swirl `Texture`/`Beam.Color` (ColorSequence swap) + arch `PointLight.Color`, 0.3 s; this runs only on the client, so it doesn't replicate. Revert on Normal, refusal, leaving the pad |
| Name tag chip | inside the existing name `BillboardGui`: `Frame` 34×14 (danger fill, `UICorner` h/2) + `TextLabel` "HARD" 8 px heavy ink; `Visible` follows the player's `Tier` attribute |
| Wave chip / boss bar | `UIStroke` Thickness 2 Color danger + HARD chip `Frame` (`UICorner` h/2) + `TextLabel`; boss HP fill `Frame` BackgroundColor3 danger (+ `UIGradient` 100% → 85%) |
| Results wing | `UIStroke` 2 danger + HARD ×2 `Frame` tags (#429) |
| Sky tint | none (v1.1, Q3). Don't touch `Lighting` for Hard |

### Image assets to upload (PNG, transparent)
None needed (text chips). Optional: `hard_chip_skull_32` (32×32), shared with the Hard selector and Results specs.
