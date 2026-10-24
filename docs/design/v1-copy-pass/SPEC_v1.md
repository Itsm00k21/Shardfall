# V1 Copy Pass: every player-facing string on the V1 loop, Spec v1 (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (UI files: OnboardHud, RollReveal/RollReel, HudLayout, results card, HubStyle), Echo (server strings: SessionGuide, WaveArena, HardMode, DungeonService, StarterGoals). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP35P https://app.notion.com/p/403c31ca3883816faf2bc49bb360274c, task 1 ("V1 copy pass: one docs page listing every player-facing string on the V1 loop … file:line, a proposed line, phone length check, one voice. No code edits."). ACK: https://app.notion.com/p/403c31ca388381ed80a3d6e3208b6952. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.

**Source read (read only, repo wins):** `cursor/live-build-9721` @ `1445560` (Oct 24, 2026 ~8:10 AM PT), which now includes the merged train #451 → #454 → #455 (Wren guide, Shard Gate pad, wave arena HUD, results card). Those new systems are still **flagged off** in `Shared/LaunchGate.luau` (`waveArena` :40, `hardMode` :53, `firstSessionGuide` :57, `m12Results` :58), so players don't see them yet; this pass fixes the words before the flags flip.
- Every row's file:line was machine-checked against `1445560` (the current text appears on that line). Line numbers move with later commits. Paths in the table are short; full paths are in §2.
- Design context (link, don't copy): #449 T3 first-session guide, #428 Wave HUD, #429 Results + Run Again, #397 roll reveal, #413 / T7 Crater Square and hub art kit (sign renamed Shard Gate), #414 Shard Crater, #420 phone layout review (D3 toast lane, center keep-out), #423 store briefs (names list), #439 boss telegraphs.

## 0. The one voice (rules every line below follows)
1. **Wren speaks for the game.** Short, warm, a little excited about loot, never sarcastic. Present tense, second person. Most lines are 2–8 words. At most one "!" per screen.
2. **Verb first** on anything the player does: "Crack…", "Step on…", "Follow…", "Clear…".
3. **Buttons are CAPS** and 1–2 words (CRACK x1, SKIP, RUN AGAIN), matching `HubStyle` (CLOSE, EQUIP, CRACK x1). Body text is sentence case. Today the roll-again button has 2 spellings (Roll Again / Roll again).
4. **Our names, spelled out, always the same:** Crater Square, Lumen Heart, Shard Gate (never just "the Gate"), Shard Crater, Hollow Warden, Wren, Roll Tokens, Shards, Essence, Fragments. Levels are "Lv 5" (plates already do this).
5. **Tap on phones, click on desktop.** No "press" in touch text. One desktop-only variant is allowed (`desktop =` rows).
6. **Say each thing once.** The Skip intro button is on the card, so the hint lines don't repeat "Or press Skip intro."
7. **Failures tell the player what to do next** ("Could not save. Try again."). No dev words a player can see (no "LaunchGate", "unusable", "arena action"). Closed things say "Closed" / "opens later", never a promised date.
8. **No Robux, prices, offers or "pay to skip" words anywhere in the loop.** House style keeps no contractions (matches every current string).

## 1. Goal
One page Ghost and Echo can work from to make every word a new player reads in the first 10 minutes (hub → Wren guide → Shard Gate → 5 waves → results → Run Again → roll reveal) sound like one game, fit a 390×844 phone, and use our own names. The page lists **122 strings** (78 changes, 44 keeps) with file:line, the proposed line and a length check.

## 2. Where it lives
| Short name in table | Full path (under `src/`) | Owner |
|---|---|---|
| HavenBuilder.luau | ServerScriptService/ShardfallServer/HavenBuilder.luau | Echo/Ghost (world) |
| Haven.luau | ReplicatedStorage/Shared/Haven.luau | Echo |
| SessionGuide.luau | ReplicatedStorage/Shared/SessionGuide.luau | Echo |
| Onboarding.luau | ReplicatedStorage/Shared/Onboarding.luau | Echo |
| OnboardHud.luau | StarterPlayer/StarterPlayerScripts/ShardfallClient/OnboardHud.luau | **Ghost** |
| OnboardingService.luau | ServerScriptService/ShardfallServer/OnboardingService.luau | Echo |
| StarterGoals.luau | ReplicatedStorage/Shared/StarterGoals.luau | Echo |
| WaveArenaConfig.luau | ReplicatedStorage/Shared/Config/WaveArenaConfig.luau | Echo |
| HardMode.luau | ReplicatedStorage/Shared/HardMode.luau | Echo |
| init.luau | server/WaveArena/init.luau | Echo |
| WaveArenaHost.luau | ServerScriptService/ShardfallServer/WaveArenaHost.luau | Echo |
| Hud.luau | server/WaveArena/Hud.luau | Echo |
| Enemies.luau | ReplicatedStorage/Shared/Config/Enemies.luau | Echo |
| Ui.luau | StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau | **Ghost** |
| DungeonService.luau | ServerScriptService/ShardfallServer/DungeonService.luau | Echo |
| Dungeons.luau | ReplicatedStorage/Shared/Dungeons.luau | Echo |
| ResultsCard.luau | StarterPlayer/StarterPlayerScripts/ShardfallClient/WaveArena/ResultsCard.luau | **Ghost** |
| init.client.luau | StarterPlayer/StarterPlayerScripts/ShardfallClient/init.client.luau | Ghost |
| HubStyle.luau, RollScreen.luau, RollSummary.luau, RollReveal.luau | ReplicatedStorage/Shared/… | **Ghost** |
| RollReel.luau | StarterPlayer/StarterPlayerScripts/ShardfallClient/RollReel.luau | **Ghost** |

Out of scope: parked systems (raids, market, guild, classes, doors, chests, pets care, pass; LaunchGate `SHOW = false`), Debug/dev-only messages ("Skipped the wave.", "Spawned the boss."), validator error strings ("…is unusable.") that only reach logs, and the store copy (`docs/design/store_copy.md`).

## 3. Flow (the order a new player meets these strings)
| Step | Where | Rows |
|---|---|---|
| 1 | Spawn in Crater Square: signs, Lumen Heart, gate plates, prompts | A1–A25 |
| 2 | Wren card + pill: open, crack 3 free shards | B1–B12, F1–F30 |
| 3 | Rare+ reveal → "Now test it at the Shard Gate" → arrow → pad | B13–B18, C1–C10 |
| 4 | Into the Shard Crater: wave chip, boss bar, wave toasts | B19–B20, D1–D12 |
| 5 | Results card → RUN AGAIN / hub | E1–E11 |
| 6 | Goals tracker (Goals N/5) all along; old intro + card chrome | B21–B34 |

## 4. Layout (phone length check)
Method: estimated text width = sum of glyph widths for BuilderSans Bold (caps 0.66 em, lower/digits 0.53 em, space 0.27 em, punctuation 0.33 em) × TextSize, compared with the real box from the code. Format strings are checked with a worst-case sample (e.g. "Wave 3 clear! +40 gold · +25 XP · +2 Roll Tokens"). This is an estimate: Ghost confirms the 4 tight rows with `TextService:GetTextSize` in Studio. Boxes used:
- **sign**: 144 px × 1 line(s) at 18 px (HB:208 BillboardGui 160x36, 18 px)
- **plate**: 284 px × 1 line(s) at 28 px (HB:249 Nameplate 300x84, title 28 / subline 18)
- **plate_t**: 284 px × 1 line(s) at 28 px (HB:249 title 28 px)
- **plate_s**: 284 px × 1 line(s) at 18 px (HB:249 subline 18 px)
- **prompt**: 200 px × 1 line(s) at 19 px (Roblox default ProximityPrompt (est.))
- **toast**: 178 px × 2 line(s) at 14 px (#420 D3 toast lane at 390x844: 178 px x 2 lines, 14 px)
- **card**: 260 px × 2 line(s) at 14 px (OnboardHud body 14 px, ~260 px text width at 390x844 x 2 lines)
- **pill**: 256 px × 1 line(s) at 14 px (HudLayout pill <= 280 px, 14 px)
- **goal**: 260 px × 1 line(s) at 14 px (Goals tracker 280 px, 14 px)
- **head**: 256 px × 1 line(s) at 16 px (OnboardHud heading 16 px)
- **button**: 116 px × 1 line(s) at 16 px (HudLayout button <= 132 px, 16 px)
- **boss**: 280 px × 1 line(s) at 16 px (BossBar label 280x22, 16 px)
- **results**: 248 px × 1 line(s) at 16 px (ResultsCard 280x180 panel, 16 px rows)
- **status**: 358 px × 1 line(s) at 14 px (run label, 390 px minus margins)
- **reveal**: 200 px × 1 line(s) at 14 px (reveal card line (est.))
- **badge**: 60 px × 1 line(s) at 10 px (summary tile badge 10 px)

Result: **4 strings are too long today** (C5 dev message, D3 old wave label, E11 Auto Farm, F29 badge). **All proposed lines fit** their box at 390×844. 667×375, 800×400 and desktop boxes are the same size or wider (OnboardHud card caps at 340 px, toast lane is 240–320 px), so a line that fits portrait fits everywhere.


### A. Hub signs and prompts

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| A1 | `HavenBuilder.luau:691` | sign | `Lumen Heart` | keep | 105/144 OK → 105/144 OK | Crater centerpiece label. |
| A2 | `HavenBuilder.luau:741` | sign | `Boss Plaza` | `Crater Square` | 95/144 OK → 124/144 OK | Spawn plaza sign. V1 hub name from #413/T7 (Q3). |
| A3 | `HavenBuilder.luau:793` | sign | `Armory` | keep | 60/144 OK → 60/144 OK |  |
| A4 | `HavenBuilder.luau:792` | prompt | `Armory \| Weapons and armor` | keep | 121/200 OK → 121/200 OK | ActionText / ObjectText. |
| A5 | `HavenBuilder.luau:911` | sign | `Forge` | keep | 50/144 OK → 50/144 OK |  |
| A6 | `HavenBuilder.luau:910` | prompt | `Forge \| Upgrade gear` | keep | 87/200 OK → 87/200 OK |  |
| A7 | `HavenBuilder.luau:1148` | sign | `Shop` | keep | 40/144 OK → 40/144 OK | No prices or Robux on the sign (rule). |
| A8 | `HavenBuilder.luau:1162` | sign | `Shrine` | keep | 60/144 OK → 60/144 OK |  |
| A9 | `Haven.luau:106` | toast | `The shrine wakes inside a run.` | keep | 203/356 OK → 203/356 OK | Good Wren-style line. |
| A10 | `HavenBuilder.luau:1037` | sign | `Pet Garden` | keep | 95/144 OK → 95/144 OK |  |
| A11 | `HavenBuilder.luau:1036` | prompt | `Pets \| Companions` | keep | 76/200 OK → 76/200 OK |  |
| A12 | `HavenBuilder.luau:989` | prompt | `Coming Soon \| Guild Hall` | `Closed \| Guild Hall` | 111/200 OK → 74/200 OK | guilds is parked; one word for every closed thing (rule 7). |
| A13 | `Haven.luau:152` | toast | `The Guild Hall is coming soon.` | `The Guild Hall opens later.` | 207/356 OK → 188/356 OK | No promise of a date. |
| A14 | `HavenBuilder.luau:1066` | prompt | `Coming Soon \| Observatory` | `Closed \| Observatory` | 111/200 OK → 83/200 OK |  |
| A15 | `Haven.luau:169` | toast | `Hidden combos are coming soon.` | `The Observatory opens later.` | 207/356 OK → 198/356 OK | Names the place, not a hidden system. |
| A16 | `Haven.luau:143` | toast | `The daily shop is not open yet.` | `The Market opens later.` | 207/356 OK → 161/356 OK | Sign says Market (HB:950); line said 'daily shop'. |
| A17 | `HavenBuilder.luau:1904` | plate | `portal.name \| Haven.gatePlate(portal)` | `Shard Gate \| Lv 1 · 5 waves` | 137/284 OK → 148/284 OK | Gate plate title/subline. Today: 'Rootvault' / 'Lv 1 · Solo' (HV:180, HV:193). |
| A18 | `Haven.luau:180` | plate_t | `Rootvault` | `Shard Gate` | 137/284 OK → 148/284 OK | Only if the V1 Gate reuses this arch (T7 renamed the sign Shard Gate). |
| A19 | `Haven.luau:193` | plate_s | `Lv 1 · Solo` | `Lv 1 · 5 waves` | 92/284 OK → 114/284 OK | Solo is wrong once M16 parties is on; wave count is from WaveArenaConfig (6, 8, 10, 12, boss). |
| A20 | `HavenBuilder.luau:1771` | prompt | `Waves \| Solo` | `(retire)` | 53/200 OK → – | Old pier entry; the Shard Gate pad replaces it in V1. Two ways in = confusion. |
| A21 | `HavenBuilder.luau:1787` | prompt | `Sealed \| portal.message` | `Sealed \| <gate name>` | 101/200 OK → 72/200 OK | ObjectText is the whole message today, e.g. 'Sunken Reach is sealed.' (HV:229). |
| A22 | `Haven.luau:229` | toast | `Sunken Reach is sealed.` | `Tidecrypt is sealed.` | 161/356 OK → 140/356 OK | BUG: gate is named Tidecrypt (HV:215), line says Sunken Reach. |
| A23 | `Haven.luau:211` | toast | `Opens at level 15.` | `Opens at Lv 15.` | 122/356 OK → 101/356 OK | Use 'Lv' everywhere (plates already do). |
| A24 | `WaveArenaConfig.luau:226` | prompt | `Shard Gate` | keep | 101/200 OK → 101/200 OK | Shard Gate pad ObjectText. |
| A25 | `WaveArenaConfig.luau:227` | prompt | `Enter` | keep | 53/200 OK → 53/200 OK | Pad ActionText. |

### B. Wren guide (T3) and goals

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| B1 | `Onboarding.luau:188` | pill | `Wren: ` | keep | 40/256 OK → 40/256 OK | Pill prefix while the guide runs. |
| B2 | `Onboarding.luau:190` | pill | `Shardfall: ` | keep | 77/256 OK → 77/256 OK |  |
| B3 | `SessionGuide.luau:42` | card | `Crack your first shard.` | `The sky cracked. Crack your first shard.` | 159/520 OK → 273/520 OK | Opener gets the one line of story (from old OB:21). |
| B4 | `SessionGuide.luau:44` | pill | `Welcome` | keep | 54/256 OK → 54/256 OK | short |
| B5 | `SessionGuide.luau:50` | card | `Crack your first shard. Tap ROLL below.` | `Tap CRACK below.` | 273/520 OK → 120/520 OK | Button says CRACK x1 (HS:22). Repeat of opener dropped (Q1). |
| B6 | `SessionGuide.luau:51` | card | `Click ROLL or press R.` | `Click CRACK or press R.` | 157/520 OK → 166/520 OK | Pinned by validator SG:379 (builder edits both). |
| B7 | `SessionGuide.luau:52` | goal | `Crack shard 1` | keep | 91/260 OK → 91/260 OK |  |
| B8 | `SessionGuide.luau:54` | card | `Tap ROLL at the bottom. Or press Skip intro.` | `Tap CRACK at the bottom.` | 304/520 OK → 172/520 OK | Skip intro button is on the card already; drop the repeat (rule 6). |
| B9 | `SessionGuide.luau:60` | card | `Nice! Two more free shards.` | keep | 184/520 OK → 184/520 OK |  |
| B10 | `SessionGuide.luau:63` | card | `Tap ROLL at the bottom. Or press Skip intro.` | `Tap CRACK at the bottom.` | 304/520 OK → 172/520 OK |  |
| B11 | `SessionGuide.luau:69` | card | `Last free shard. Make it count!` | keep | 210/520 OK → 210/520 OK |  |
| B12 | `SessionGuide.luau:72` | card | `Tap ROLL at the bottom. Or press Skip intro.` | `Tap CRACK at the bottom.` | 304/520 OK → 172/520 OK |  |
| B13 | `SessionGuide.luau:79` | card | `A Rare! Now test it at the Shard Gate.` | keep | 256/520 OK → 256/520 OK | Best line in the game. Template for the rest. |
| B14 | `SessionGuide.luau:80` | card | `An Epic! Now test it at the Shard Gate.` | keep | 264/520 OK → 264/520 OK | Pinned SG:391. |
| B15 | `SessionGuide.luau:81` | card | `A Legendary! Now test it at the Shard Gate.` | keep | 293/520 OK → 293/520 OK | Pinned SG:394. |
| B16 | `SessionGuide.luau:82` | goal | `Step on the Gate` | `Step on the Shard Gate` | 111/260 OK → 154/260 OK | Full name every time (rule 4). |
| B17 | `SessionGuide.luau:84` | card | `Follow the arrow to the Gate. Or press Skip intro.` | `Follow the arrow to the Shard Gate.` | 340/520 OK → 241/520 OK |  |
| B18 | `SessionGuide.luau:85` | card | `Follow the arrow to the Gate.` | `Follow the arrow to the Shard Gate.` | 198/520 OK → 241/520 OK | Pinned SG:397. |
| B19 | `SessionGuide.luau:91` | card | `Step in. Smash the shardlings!` | keep | 206/520 OK → 206/520 OK |  |
| B20 | `SessionGuide.luau:94` | card | `Clear wave 1 in the arena.` | `Clear wave 1 in the Shard Crater.` | 174/520 OK → 226/520 OK | Arena name (Q3). |
| B21 | `Onboarding.luau:21` | card | `The sky cracked. Shards fell on the wilds.` | `(retire with old intro)` | 284/520 OK → – | Old class/sapling/door intro: classes and doors are parked in LaunchGate. |
| B22 | `OnboardHud.luau:72` | card | `Finish this step in the world. Or press Skip intro.` | `Finish this step in the world.` | 346/520 OK → 203/520 OK | Fallback hint. |
| B23 | `OnboardHud.luau:163` | head | `Shardfall` | `Wren` | 78/256 OK → 36/256 OK | Guide card heading while the T3 guide runs (pill already says 'Wren:'). |
| B24 | `OnboardHud.luau:205` | button | `Continue` | keep | 70/116 OK → 70/116 OK |  |
| B25 | `OnboardHud.luau:221` | card | `That did not go through. Press Skip intro to start.` | `That did not go through. Tap Skip intro.` | 346/520 OK → 271/520 OK | 'Tap' on touch (rule 5). |
| B26 | `OnboardHud.luau:226` | button | `Skip intro` | keep | 83/116 OK → 83/116 OK |  |
| B27 | `OnboardHud.luau:492` | goal | `Goals %d/%d` | keep | 77/260 OK → 77/260 OK |  |
| B28 | `OnboardingService.luau:90` | toast | `Try it in the world first.` | keep | 174/356 OK → 174/356 OK |  |
| B29 | `OnboardingService.luau:102` | toast | `Could not save.` | `Could not save. Try again.` | 103/356 OK → 176/356 OK | Tell the player what to do. |
| B30 | `StarterGoals.luau:60` | goal | `Roll 10 shards` | `Crack 10 shards` | 98/260 OK → 106/260 OK | Verb (Q1). |
| B31 | `StarterGoals.luau:61` | goal | `Craft your first item at the Forge` | `(swap) Clear wave 5 at the Shard Gate` | 234/260 OK → – | forgeCraft is parked in LaunchGate: goal can't be done in V1. |
| B32 | `StarterGoals.luau:62` | goal | `Clear Rootvault` | `Clear wave 1 at the Shard Gate` | 111/260 OK → 206/260 OK | Rootvault is not the V1 Gate. |
| B33 | `StarterGoals.luau:63` | goal | `Reach Lv 5` | keep | 71/260 OK → 71/260 OK | Matches Hard unlock. |
| B34 | `StarterGoals.luau:64` | goal | `Join or browse a guild` | `(swap) Equip a Rare or better` | 150/260 OK → – | guilds is parked: goal can't be done in V1. Pinned list at ST:157-161. |

### C. Shard Gate pad and Hard

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| C1 | `HardMode.luau:24` | toast | `Hard unlocks at Lv 5.` | keep | 142/356 OK → 142/356 OK |  |
| C2 | `HardMode.luau:25` | toast | `This party is on Hard (Lv 5).` | keep | 190/356 OK → 190/356 OK |  |
| C3 | `HardMode.luau:26` | toast | `That difficulty is closed.` | `Hard is closed right now.` | 181/356 OK → 170/356 OK | Only Hard can be closed. |
| C4 | `HardMode.luau:146` | toast | `Level %d opens %s.` | `%s opens at Lv %d.` | 129/356 OK → 127/356 OK | Today reads 'Level 5 opens hard.' (lowercase id). Builder capitalizes the id. |
| C5 | `init.luau:180` | toast | `The wave arena is off (LaunchGate.waveArena), so this does nothing yet.` | `The Shard Gate is closed right now.` | 484/356 LONG → 241/356 OK | Dev text a player could see. |
| C6 | `WaveArenaHost.luau:550` | toast | `The wave arena is off.` | `The Shard Gate is closed right now.` | 148/356 OK → 241/356 OK | Same at WH:554 and WH:583. |
| C7 | `WaveArenaHost.luau:576` | toast | `Could not enter the arena.` | `Could not open the Shard Gate. Try again.` | 177/356 OK → 280/356 OK | Same at WH:617 and WI:186. |
| C8 | `WaveArenaHost.luau:668` | toast | `You are not in the arena.` | `You are not in a run.` | 166/356 OK → 137/356 OK |  |
| C9 | `WaveArenaHost.luau:677` | toast | `Could not do that.` | `Could not do that. Try again.` | 122/356 OK → 195/356 OK |  |
| C10 | `init.luau:188` | toast | `Entered the wave arena.` | `Into the Shard Crater!` | 159/356 OK → 155/356 OK |  |

### D. Wave HUD and run toasts

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| D1 | `Hud.luau:38` | boss | `Wave %d / %d` | `Wave %d/%d` | 71/280 OK → 187/280 OK | Drop the spaces. Boss wave adds the name: 'Wave 5/5 · Hollow Warden' (Q4). |
| D2 | `Enemies.luau:204` | boss | `Boss` | `Hollow Warden` | 36/280 OK → 110/280 OK | Only where a name shows (boss bar/billboard). Name from #423/#439 (Q4). |
| D3 | `Ui.luau:605` | status | `%s  ·  Wave %d  ·  %d left%s%s` | `Wave %d · %d left` | 440/358 LONG → 111/358 OK | Old endless-waves label. Worst case today: 'Wave Arena · Wave 3 · 12 left · hit during the gold weak spot 5s'. |
| D4 | `Ui.luau:600` | toast | `  ·  hit during the gold weak spot` | `Hit the gold spot!` | 217/356 OK → 122/356 OK | Move tips to the toast lane, not the label. |
| D5 | `Ui.luau:598` | toast | `  ·  stand in the sunbeam` | `Stand in the sunbeam!` | 157/356 OK → 144/356 OK |  |
| D6 | `Ui.luau:612` | button | `Next wave \| Fighting` | `NEXT WAVE \| FIGHTING` | 74/116 OK → 89/116 OK | Buttons in caps (rule 3). |
| D7 | `DungeonService.luau:1789` | toast | `Wave %d cleared. %s.` | `Wave %d clear! %s` | 283/356 OK → 308/356 OK | %s = '+40 gold · +25 XP · +2 Roll Tokens' (· not commas; currency name from Economy.luau:10). |
| D8 | `DungeonService.luau:2167` | toast | `Wave %d clear. Next wave in %ds.` | `Next wave in %ds.` | 214/356 OK → 114/356 OK | Avoid two 'clear' toasts back to back. |
| D9 | `DungeonService.luau:1854` | toast | `Defeated.` | keep | 66/356 OK → 66/356 OK |  |
| D10 | `DungeonService.luau:1856` | toast | `Waves ended.` | `Run over.` | 84/356 OK → 62/356 OK | Same word as the results card title (E). |
| D11 | `DungeonService.luau:1858` | toast | `Clear did not save.` | `Your clear did not save. Try again.` | 129/356 OK → 236/356 OK |  |
| D12 | `Dungeons.luau:526` | status | `Wave Arena` | `Shard Crater` | 74/358 OK → 89/358 OK | Run name shown in labels (Q3). |

### E. Results and Run Again

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| E1 | `ResultsCard.luau:19` | results | `Run over` | keep | 66/248 OK → 66/248 OK | Title |
| E2 | `ResultsCard.luau:21` | results | `Defeated` | keep | 70/248 OK → 70/248 OK |  |
| E3 | `ResultsCard.luau:23` | results | `Timed out` | `Out of time` | 74/248 OK → 87/248 OK |  |
| E4 | `ResultsCard.luau:27` | results | `Cleared` | `Shard Crater cleared!` | 61/248 OK → 171/248 OK | Win title earns a beat. |
| E5 | `ResultsCard.luau:31` | results | `Waves cleared %s` | `Waves %s/5` | 121/248 OK → 71/248 OK | Shorter; total from config at build time. |
| E6 | `ResultsCard.luau:32` | results | `Tokens %d` | `+%d Roll Tokens` | 74/248 OK → 120/248 OK | Currency's real name (Economy.luau:10). |
| E7 | `ResultsCard.luau:33` | results | `Fragments %d` | `+%d Fragments` | 100/248 OK → 105/248 OK |  |
| E8 | `ResultsCard.luau:40` | results | `%s x%d` | `<loot name> x%d` | 103/248 OK → 106/248 OK | BUG: prints the raw id (e.g. 'shard_chip x2'); names exist at WC:239-240. |
| E9 | `ResultsCard.luau:46` | results | `Essence %d` | `+%d Essence` | 83/248 OK → 88/248 OK |  |
| E10 | — | button | `(no Run Again string in code yet)` | `RUN AGAIN` | – → 89/116 OK | Ghost's results UI (#429) isn't built; use this label. Secondary: HUB. |
| E11 | `init.client.luau:791` | toast | `Auto Farm is on. Wins and losses start the same run again.` | `Auto Farm on. Runs restart by themselves.` | 390/356 LONG → 282/356 OK | Only if Auto Farm ships in V1. |

### F. Roll reveal

| # | Ref | Box | Current | Proposed | Phone check now → proposed | Why |
|---|---|---|---|---|---|---|
| F1 | `HubStyle.luau:22` | button | `CRACK x1` | keep | 74/116 OK → 74/116 OK | Hub roll button. Verb (Q1). |
| F2 | `HubStyle.luau:23` | button | `CRACK x10` | keep | 83/116 OK → 83/116 OK |  |
| F3 | `RollScreen.luau:24` | button | `CRACK x1` | keep | 74/116 OK → 74/116 OK | Mirror of HS:22. |
| F4 | `RollScreen.luau:26` | button | `AUTO` | keep | 42/116 OK → 42/116 OK |  |
| F5 | `RollScreen.luau:27` | button | `AUTO ON` | keep | 68/116 OK → 68/116 OK |  |
| F6 | `RollScreen.luau:28` | button | `ODDS` | keep | 42/116 OK → 42/116 OK |  |
| F7 | `RollScreen.luau:29` | button | `Details` | `DETAILS` | 61/116 OK → 74/116 OK | Caps like its row mates. |
| F8 | `RollReel.luau:263` | button | `Roll` | `CRACK` | 36/116 OK → 53/116 OK | Second roll button says Roll; hub says CRACK (Q1). |
| F9 | `RollReel.luau:531` | button | `Rolling...` | `Cracking...` | 77/116 OK → 86/116 OK | Matches RV:328. |
| F10 | `RollReel.luau:249` | button | `Auto` | `AUTO` | 36/116 OK → 42/116 OK | Same toggle as RS:26 in a different case. |
| F11 | `RollReel.luau:250` | button | `Quick` | `QUICK` | 44/116 OK → 53/116 OK |  |
| F12 | `RollReel.luau:251` | button | `Shake` | `SHAKE` | 44/116 OK → 53/116 OK |  |
| F13 | `RollReel.luau:160` | head | `Odds` | `ODDS` | 36/256 OK → 42/256 OK |  |
| F14 | `RollReel.luau:363` | button | `Equip` | `EQUIP` | 44/116 OK → 53/116 OK | HS:21 already says EQUIP. |
| F15 | `RollReel.luau:364` | button | `Keep` | `KEEP` | 36/116 OK → 42/116 OK |  |
| F16 | `RollReel.luau:370` | button | `Roll Again` | `CRACK AGAIN` | 85/116 OK → 110/116 OK | RM:25 says 'Roll again': 3 spellings of one button. |
| F17 | `RollReel.luau:393` | button | `Skip` | `SKIP` | 36/116 OK → 42/116 OK |  |
| F18 | `RollReel.luau:776` | toast | `Received %s.` | `Got %s!` | 151/356 OK → 114/356 OK | Shorter, warmer. |
| F19 | `RollReel.luau:893` | toast | `Roll failed.` | `Could not crack. Try again.` | 84/356 OK → 184/356 OK |  |
| F20 | `RollReel.luau:1060` | toast | `Duplicate %s became %d Shard Dust.` | keep | 304/356 OK → 304/356 OK | stars is parked; only shows if dupes merge. |
| F21 | `RollReveal.luau:321` | reveal | `Cracking for gear` | keep | 121/200 OK → 121/200 OK |  |
| F22 | `RollReveal.luau:328` | reveal | `Cracking...` | keep | 75/200 OK → 75/200 OK |  |
| F23 | `RollReveal.luau:341` | reveal | `+%d %s` | keep | 62/200 OK → 62/200 OK | '+1 Shard' / '+3 Shards'. |
| F24 | `RollReveal.luau:343` | reveal | `Added to your Shards` | keep | 141/200 OK → 141/200 OK |  |
| F25 | `RollSummary.luau:24` | button | `Skip` | `SKIP` | 36/116 OK → 42/116 OK |  |
| F26 | `RollSummary.luau:25` | button | `Roll again` | `CRACK AGAIN` | 83/116 OK → 110/116 OK |  |
| F27 | `RollSummary.luau:26` | button | `Close` | `CLOSE` | 44/116 OK → 53/116 OK | HS:20 already says CLOSE. |
| F28 | `RollSummary.luau:27` | badge | `NEW` | keep | 20/60 OK → 20/60 OK |  |
| F29 | `RollSummary.luau:29` | badge | `Auto-salvaged` | `Salvaged` | 68/60 LONG → 44/60 OK | RollSummaryHud already shortens it to this. |
| F30 | `RollSummary.luau:108` | reveal | `Auto-salvaged +%d Essence` | `Salvaged +%d Essence` | 176/200 OK → 142/200 OK |  |

## 5. States
- **Guide on vs off** (`firstSessionGuide`): on → pill "Wren: …" and the B rows from SessionGuide; off → the old Onboarding intro (B21) which describes parked class/sapling/door steps. Proposal: when the guide ships, the old intro lines retire with it.
- **Wave arena on vs off** (`waveArena`): off → Rootvault/legacy wave strings (A17–A20, D3–D12) are what players read; on → Shard Gate pad + D1/D2 + E rows. Both sets are fixed by this pass so the switch doesn't change the voice.
- **Rarity variants:** B13–B15 already branch Rare/Epic/Legendary. Keep that pattern for any new reveal line.
- **Error / closed:** every failure row in C ends with what to do next.

## 6. Numbers
122 rows · 78 proposed changes · 44 keeps · 2 bugs (A22 Tidecrypt/Sunken Reach name mismatch, E8 raw loot id `shard_chip` shown on the results card) · 2 goals players can't finish in V1 (B31 Forge craft, B34 guild: both systems parked) · 1 dev string a player can see (C5) · 2 spellings of the roll-again button (F16 "Roll Again", F26 "Roll again").

## 7. Edge cases
- **Pinned strings:** SessionGuide's validator pins 4 lines (SG:379, 391, 394, 397) and StarterGoals pins its list (ST:157–161). Changing those lines means changing the pin in the same commit (Echo).
- **Format strings:** keep the `%d/%s` order the code expects; HardMode C4 swaps order, so the builder updates the `string.format` arguments too and capitalizes the id ("Hard").
- **Long names:** item names in "Got %s!" (F18) can be long ("Legendary Voidcaster Staff"); the toast lane wraps to 2 lines, still fits.
- **Localization:** V1 is English only. All proposed lines leave ≥ 20% width slack in their box except the gate plate subline (A19, ~45% slack).
- **Kid readers:** no word over 3 syllables in Wren's lines except "Legendary" (it's the payoff).

## 8. Mockups
None needed: this is a text pass. The phone boxes are the existing ones from the code (§4). Visual context lives in #428, #429, #449.

## 9. Build split
- **Ghost (UI files, read-only for Prism):** OnboardHud (B22–B27), Ui.luau (D3–D6), ResultsCard (E1–E9), RUN AGAIN label (E10), HubStyle/RollScreen/RollReel/RollSummary/RollReveal (F rows), init.client (E11). Studio text-fit check on C5, D3, E11, F29 replacements.
- **Echo (server/shared strings):** HavenBuilder/Haven (A rows), SessionGuide + its pins (B rows), StarterGoals + pins (B30–B34, needs Ghost's OK on the swaps), HardMode, WaveArena, DungeonService/Dungeons (C, D rows), Enemies display name (D2).
- **Kevin:** Q1–Q4 below (taste). Ghost may close them under pre-approval.
- **Prism:** none further; v1.1 folds answers.

## 10. Pass criteria (Kevin can check these)
1. Play the first 10 minutes on a phone: every line fits on one card/toast without "…" truncation.
2. The roll button, the guide and the goals all use the same verb (Q1).
3. "Shard Gate" is never shortened to "the Gate" on screen.
4. No player-visible string mentions LaunchGate, ids like `shard_chip`, or a gate name that doesn't match its plate.
5. No goal in "Goals N/5" points at a parked system.
6. Every button is CAPS; no button has two spellings.
7. No Robux, price or offer words anywhere in the loop.

## 11. Open questions (answer by number)
1. **@Kevin (taste):** the roll verb. **A: CRACK** everywhere a player acts (button already says CRACK x1, guide says "Crack your first shard"; only the guide's "Tap ROLL" and RollReel change). B: ROLL everywhere (HubStyle/RollScreen change). Currency stays "Roll Tokens" either way. **Prism recommends A**: it's ours (no other Roblox roll game "cracks"), and it's the smaller change.
2. **@Kevin (taste):** guide card heading reads **"Wren"** while the T3 guide runs (pill already says "Wren: …"). Prism recommends **yes**.
3. **@Kevin (taste):** player-facing place names **Crater Square** (hub, replaces the "Boss Plaza" sign) and **Shard Crater** (arena, replaces "Wave Arena"), from #413/#414. Prism recommends **yes, both**.
4. **@Kevin (taste):** show the boss name **"Hollow Warden"** on the boss bar ("Wave 5/5 · Hollow Warden") instead of the config name "Boss". Prism recommends **yes**.
5. **@Ghost:** starter goals B31/B34 point at parked Forge craft and guilds. Swap to "Clear wave 5 at the Shard Gate" and "Equip a Rare or better" (Prism's proposal), or your pick? Reward table in StarterGoalPay is untouched.

## Decision log
- 2026-10-24 (Prism): v1 copy pass written from `cursor/live-build-9721` @1445560 (train #451/#454/#455 merged), 122 rows. NOT APPROVED.

## Roblox build notes
- All strings are plain `TextLabel.Text` / `TextButton.Text` / `ProximityPrompt.ActionText` + `ObjectText` / `BillboardGui` labels. No RichText needed; keep `TextScaled = false` and fixed TextSize (14 body, 16 buttons, 18 signs) so the length check holds. Use `TextWrapped = true` on toasts and the guide body (2 lines max) and `TextTruncate = AtEnd` only as a safety net.
- Caps buttons: write the caps in the string (not a font transform), so `TextService:GetTextSize` matches what renders.
- "·" (U+00B7) renders in BuilderSans; keep it as the one separator. "★" is already used in RollSummary.
- Touch targets unchanged: every button named here sits in an existing ≥ 44 px control (HudLayout `UiTheme.TOUCH`, OnboardHud buttons 140×52).
- Mobile-first checks: 390×844 (budgets above), 667×375 and 800×400 (card ≤ 340 px, toast lane 240–260 px), desktop 1280×720 (toast lane 320 px). No new panel, nothing enters the #420 center keep-out.
