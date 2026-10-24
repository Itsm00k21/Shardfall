# Heartwood Arch (#475) Visual QA vs the Gate look specs (raids = false) (NOT APPROVED, docs only, report only)

Owner: Prism (visual QA, docs only: no code, no Config, no flag flips). Fixes: Ghost (world build / client), Echo (Haven copy, flags). Base: `cursor/live-build-9721` @ **`a760a64`** (#475 `echo/heartwood-p3-polish` merged as `d70d979`). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP67P https://app.notion.com/p/403c31ca3883816996fed5f9ecc6bf4b (item 3, "Heartwood #475 visual QA vs dungeon-look spec"). ACK: https://app.notion.com/p/403c31ca388381999b28fa05219613c1.
Specs checked: `docs/design/dungeon-look/SPEC_v1.md` v1.1 (`prism/dungeon-look` @ `81909ed`), `docs/design/DUNGEON_GATE_PLAZA.md` (on live, the arch look table), `docs/design/town-hub/SPEC_v1.md` v1.1 Crater Square (`prism/town-hub`, decided). Method: code read of `HavenBuilder.buildPortals` + `Haven.PORTALS` (no Studio capture on this box; Havoc confirms in Studio).

## 1. Goal
With raids off, the Heartwood arch should read as a closed raid door that is still a tree, never pull a new player away from the one open gate, and say "opens later" once, clearly, on a phone.

## 2. Where it lives
Crater Square gate row, bearing 12°, (16.2, 106.3), 22 studs tall (`Haven.luau:199-214`). Built by `buildPortals` (`HavenBuilder.luau:1666-1916`), lit by the gate heartbeat (`HavenBuilder.luau:1555-1578`). #475 changed only copy: plate/prompt/toast "Heartwood opens later." (`Haven.luau:378-383`) and kept `gateLit` as an alias of `gateShownOpen` (`Haven.luau:344-356`).
**Spec note:** the dungeon-look spec (Shard Crater arena) has no Heartwood section; it parks Gnarl/Verdant (v1.1 changelog). The arch look lives in `DUNGEON_GATE_PLAZA.md` §Gate spec row 2 and §Light and VFX, which the builder already cites (`HavenBuilder.luau:1185-1187`). This QA uses those plus Crater Square v1.1.

## 3. Flow (what a player sees, raids off)
Spawn faces the row: Rootvault/Shard Gate (open, green neon mouth, lit inlay) dead ahead, Heartwood 12° right. Heartwood: seal bar across a dim amber mouth (glow 0.75), light off until you're within 12 studs (then 0.12), ash rising from the lintel, a **full-bright amber neon crack** across the lintel, plate "Heartwood / Heartwood opens later.", prompt "Heartwood opens later." (HavenAction `soon`, toast with the same line).

## 4. Spec match table
| Item | Spec | Live | Match |
|---|---|---|---|
| Height | taller by 4 (22) | `height = 22` (`Haven.luau:199-214`) | ✓ |
| Body / bark | 92,140,72 body; blackened trunks | body 92,140,72 Wood, bark strips 36,28,22 (`HavenBuilder.luau:1816-1819`) | ✓ (reads green, not blackened; taste, see Q4) |
| Crack | amber 214,140,64 through the lintel | 7×0.35×2.2 **Neon**, Transparency 0, sealed or not (`HavenBuilder.luau:1820-1828`) | ✗ while sealed (P2-HW-1) |
| Light | 214,140,64, 0.35, range 14, pulse 0.15 / 3 s | `GATE_VFX.heartwood` (`HavenBuilder.luau:1271-1290`); off while sealed, 0.12 near | ✓ |
| Particles | ash, rate 5, gray → dull amber | ash rate 5, 70,68,66 → 176,120,64 | ✓ open; ✗ runs while sealed (P3-HW-3) |
| Locked look | "keeps the seal, dims the glow to 0.75, leaves the inlay dark"; "Locked glows lose the light and keep a faint neon edge" (`DUNGEON_GATE_PLAZA.md:163, :191`) | seal 8×1.4×1.4 metal 36,34,40 (`:1800-1810`), glow 0.75 (`:1734`), inlay + court guide gray (`:1113-1130`, `:1927-1945`) | ✓ |
| Plate | `Heartwood` / `Lv 15 · 4–8`; lock reason one short sentence | "Heartwood" / "Heartwood opens later." (`:1915`) | ✗ name twice (P3-HW-2) |
| Prompt | `Finder` (raids on) | raids off: ActionText "Heartwood opens later.", ObjectText "Heartwood" (`:1793-1796`) | ✗ long + doubled (P3-HW-2) |
| Hub cut-down | Crater Square v1.1: the 5 non-V1 arches (Heartwood included) hidden behind `sealedGates` (off), nothing deleted | no `sealedGates` flag in `LaunchGate.luau`; all 6 arches built | ✗ (P2-HW-4) |

## 5. States + findings (P0-P3, report only)
| ID | Sev | Finding | Evidence | Fix |
|---|---|---|---|---|
| P2-HW-1 | P2 | On a **sealed** Heartwood the lintel crack stays full-bright Neon amber. It is the warmest, brightest pixel in the row next to the only open gate, so a new player's eye goes to the closed door. Spec: locked = lose the light, keep a *faint* edge | `HavenBuilder.luau:1820-1828`; `DUNGEON_GATE_PLAZA.md:191` | Ghost: when `sealed`, crack `Transparency` 0.6 (or Color 120,80,44, Material SmoothPlastic); open → 0 Neon. Mockup 01 right |
| P2-HW-4 | P2 | Crater Square v1.1 (decided) hides Heartwood + 4 sealed arches behind `sealedGates` (off). Live builds all six, so the V1 hub shows five closed doors around the Shard Gate | `town-hub/SPEC_v1.md` §2, §9; `LaunchGate.luau` (no `sealedGates`); `HavenBuilder.luau:1666-1916` loops all `Haven.PORTALS` | Echo: `sealedGates = false` in `LaunchGate`; Ghost: `buildPortals` skips non-Rootvault arches (and their prompts, inlay stones, court guides) when off. Nothing deleted |
| P3-HW-2 | P3 | Plate and prompt say the name twice ("Heartwood" / "Heartwood opens later."); the 22-char ActionText wraps on phones | `Haven.luau:378-383`; `HavenBuilder.luau:1793-1796, :1915` | Echo: plate subline + prompt ActionText "Opens later"; ObjectText "Heartwood"; the toast keeps "Heartwood opens later." |
| P3-HW-3 | P3 | Ash keeps emitting on the sealed arch (`particles = reduced ~= true`, ignores `sealed`) | `HavenBuilder.luau:1407, :1575` | Ghost: sealed → `particles = false` (or Rate 2); open → spec rate 5 |
| Info | — | Plate ink is 248,244,230 on a 10,8,12 plate, not the spec's 236,226,190 with stroke 0.35. It reads better on phones; keep | `HavenBuilder.luau:232-234` | none |
No P0/P1: nothing blocks movement, the prompt does something, raids stay closed on the server too (`HavenBuilder.luau:2622`).

## 6. Copy
Proposed: plate "Heartwood" / "Opens later" · prompt "Opens later" (ObjectText "Heartwood") · toast "Heartwood opens later." (unchanged). When raids open: plate `Lv 15 · 4–8` and the Finder/Practice prompts (live).

## 7. Visual style
Sealed: crack at 0.6 transparency, no ash, glow 0.75, light off, seal bar, gray inlay. Open: crack Neon 0, ash 5, light 0.35 pulsing. Colors from `Haven.PORTALS` (no new colors).

## 8. Motion
No new tweens. Gate heartbeat keeps its approach boost (sealed 0.12 near). When raids flip on mid-session (future), crack and ash change on the next build, no tween needed.

## 9. Roblox build notes
Crack: `Part` Neon → set `Transparency` from `sealed` at build (`buildPortals`), no `SurfaceLight`. Ash: `ParticleEmitter.Enabled = look.particles and not gate.sealed` in the heartbeat. `sealedGates`: one `LaunchGate.on` check around the non-Rootvault portal loop body + inlay + court ring; server prompt handlers already check `LaunchGate` (`HavenBuilder.luau:2622`). No blur, no `ColorCorrection`.

## 10. Mobile checks
Portrait 390×844 (~43° horizontal FOV, `DUNGEON_GATE_PLAZA.md` §Phone): from spawn the frame holds Rootvault and Heartwood (and most of Tidecrypt). That's the view where the bright crack competes most (P2-HW-1). 667×375 / 800×400 / desktop: the whole row is in frame; same issue, smaller. Prompt text: "Opens later" fits the default ProximityPrompt width at all sizes; "Heartwood opens later." wraps to two lines on 390×844. Mockup: `01-heartwood-arch-live-vs-fix.svg` (front elevation live vs proposed + the gate row live vs Crater Square).

## 11. Open questions (answer by number)
1. **@Ghost:** dim the crack (0.6) and stop the ash while Heartwood is sealed (P2-HW-1, P3-HW-3)? Prism recommends **yes**.
2. **@Ghost / @Echo:** build the `sealedGates` flag (off) so the V1 hub shows only the Shard Gate, as Crater Square v1.1 decided (P2-HW-4)? Prism recommends **yes**. Heartwood would then be invisible with raids off, and P2-HW-1 only matters when someone turns it on.
3. **@Echo:** plate/prompt "Opens later", toast keeps the full sentence (P3-HW-2)? Prism recommends **yes**.
4. **@Kevin (taste):** the Heartwood body reads green (92,140,72) even though the spec says "blackened trunks". Darken it to 58,64,46 with the bark strips as they are? Prism recommends **yes, when raids open** (no work while it's hidden).

## Decision log
- Oct 24, 2026: v1 QA for DP67P (Prism) on `prism/heartwood-qa` from `a760a64`. P2-HW-1, P2-HW-4, P3-HW-2, P3-HW-3. Q1-Q4 open. Report only, NOT APPROVED.
