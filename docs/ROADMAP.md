# Shardfall Roadmap (locked Oct 21, 2026)

Status: approved by Kevin, Oct 21, 2026. This is what we build against.
Date: Oct 21, 2026 (PT)
Source of truth for the loop: V1 Core Loop page (Notion).
Research behind this: `dev_process_research.md`

---

## The one-line plan

Roll gear → equip it → run a wave dungeon → earn tokens → roll again.
Build it ugly first. Prove it's fun. Then make it pretty. Then launch.

## How the phases fit

- **Phases 0–4** = the rough full loop (gray-box). No polish.
- **Checkpoint** = Kevin's fun test. Go or no-go.
- **Phase S** = make ONE dungeon look and feel final.
- **Phases 5–6** = our twists, parties, retention.
- **Phase 7** = launch.
- **Phase 8** = live updates.

Why this order: prove the fun before spending on looks.
Polishing something that isn't fun is the most common way games die.

---

## Decisions (Oct 21, 2026)

- ✅ Phase S added (one dungeon made final, right after the fun test).
- ✅ PRs #358 and #362 closed (old room flow). Their ideas live in the salvage map.
- ✅ Soft-launch ad test at the Roblox minimum (10 credits) is allowed.
  Kevin still OKs it before any money is spent.
- ✅ Retention bar: D1 ≥ 10%, sessions ≥ 10 min, D7 ≥ 2%.

---

## Ground rules (stick to these)

### Building
1. One builder at a time. One milestone at a time.
2. Every phase starts by pulling parts from the salvage map. Reuse before building new.
3. A milestone = one sitting, one PR, one thing Kevin can test.
4. Play screenshot (or short clip) before every merge.
5. Gray-box art until Phase S. Blocks and colors are fine.
6. All numbers live in `src/shared/Config/`. Tuning = edit config, not code.
7. Config test must pass before every merge.
8. Server decides everything: rolls, loot, damage, currency.
9. Studio tests use a mock save. Never touch Kevin's real save.
10. Update `CHANGELOG.md` in every PR.

### Scope
1. New idea? It goes in the Parking Lot. Not the current phase.
2. We review the Parking Lot only at gates (Checkpoint, end of Phase S, end of Phase 6, after launch).
3. To add something to a phase, something the same size leaves.
4. Cut test: "Is the loop still complete without it?" If yes, park it.
5. Bugs that block play always jump the line. Polish does not.
6. Every new system must feed rolling or dungeons. No side systems that stand alone.

### Kevin's daily 15 minutes
1. Builder sends: what changed, one question to answer, how to test.
2. Kevin plays and answers the question.
3. Kevin notes "what felt wrong," not how to fix it. Builder proposes fixes.
4. Clips/screenshots beat long text.

### Friend playtests (at gates only)
- At the Checkpoint, end of Phase S, and before launch.
- 3–6 friends, on phones if possible.
- Don't explain anything. Watch where they get stuck.
- Write down: where they quit, what they asked, what they repeated.

### Balance rule (from Roblox sim postmortems)
- Players find the best path fast and ignore the rest.
- Ember, Frost and Void must stay close in value.
- Check element pick rates and clear times every balance pass.

---

## Phase 0: Foundation

**Goal:** a clean, safe base that every later phase builds on.

**Start:** pull parts from the salvage map (save system, Remotes, RateLimiter, tests, debug tools).

**Milestones (one at a time)**
- 0.1 Park off-plan systems
  - Turn off every PARK item behind LaunchGate flags (add the new flags listed in the salvage map).
  - Delete nothing.
  - Confirm the game still boots with no errors.
- 0.2 PR cleanup
  - Fix the one-line test conflict and merge #359, #360, #364, #365.
  - #358 and #362 are closed (decided Oct 21).
  - Run tests + Play check for merged #361 and #363.
- 0.3 Config folder
  - Items, Rarities, Elements, SetBonuses, Dungeons, Enemies, Rewards, Economy, Strings.
  - Stable IDs (never reuse or rename an ID).
- 0.4 Config validation test (lune)
  - Catches: missing IDs, duplicate IDs, bad odds, negative stats, missing strings.
- 0.5 Save system
  - Keep our DataService (salvage map): it already does ProfileStore-style session locks and versioned migrations.
  - Add the V1 fields as a new schema version.
  - Stores only: IDs, levels, currencies, pity, receipts.
  - Mock store in Studio by default.
  - No NaN, no Instances, no Vector3 in saves.
- 0.6 Services skeleton
  - Roll, Inventory, Dungeon, Reward, Economy. One per system.
  - Run and party state in memory only.
- 0.7 Remotes module
  - Already one module (salvage map). Check it. Every remote checks type, range and rate limit.
- 0.8 Analytics hooks
  - Funnel steps and economy events wired (see Analytics section).
- 0.9 CHANGELOG.md started.

**Done when**
- Parked systems are off and the game boots clean.
- Empty game loads, saves a test value, and reloads it after rejoin.
- Config test passes. Old PRs sorted.

**Playtest check (Kevin)**
- Join, leave, rejoin. Does the test value stay? Any errors on screen?

**Risks**
- Old PRs fight the new structure → merge only the 4 keepers, park the rest.
- Studio writing to live saves → mock store on by default.

**Out of scope**
- Any gameplay. Any UI beyond a debug label.

---

## Phase 1: Rolling

**Goal:** rolling feels great on its own.

**Start:** pull parts from the salvage map: server roll core, roll screen UI, roll areas/pools, rarity ladder (7 → 5), first-session free rolls.

**Milestones**
- 1.1 Server roll
  - One roll from config odds. Server picks the result.
  - Rate-limited remote. Result saved.
- 1.2 Roll button + reveal
  - One big button. Reveal shows tier color and 1-in-N odds.
- 1.3 5 rarity tiers + pity meter
  - Pity counter saved. Meter on screen.
- 1.4 x10 roll at 10% off + auto-roll toggle.
- 1.5 3 free first rolls (tutorial taste).
- 1.6 Tabs: Weapons, Armor, Pets, Skills
  - Each tab fits on one screen. No scrolling. Phone first.
- 1.7 Roll odds test
  - Script rolls 100k times and checks odds match config.

**Done when**
- 100 rolls in Play survive a rejoin (items + pity).
- Odds test passes.

**Playtest check (Kevin)**
- Is rolling fun for 2 minutes? Is the reveal exciting?
- Can you do it all on phone without scrolling?

**Metrics to log**
- Rolls per session. x10 vs x1 use. Auto-roll use.

**Risks**
- Reveal too slow with auto-roll → skip button / fast mode.
- Odds bugs → odds test in CI.

**Out of scope**
- Paid rolls, luck boosts, roll passes, trading.

---

## Phase 2: Equip

**Goal:** gear changes your character and your numbers.

**Start:** pull parts from the salvage map: inventory + equip, hero stats panel, item catalog + stats, gear on body, set bonuses, action bar, skill casts, basic pets.

**Milestones**
- 2.1 Five slots: weapon, armor, pet, skill 1, skill 2.
- 2.2 Stats panel. Stats computed on server from config.
- 2.3 Element scaling
  - Ember → Damage / Crit
  - Frost → Health / Defense
  - Void → Attack Speed / Luck
  - Mixing allowed.
- 2.4 Optional set bonuses (2/3/4 pieces), from config.
- 2.5 Gear on body
  - Armor shells on the R15 body.
  - Two big welded weapons.
  - Pet follows the player.
- 2.6 Auto-equip better gear + undo button + green arrows.

**Done when**
- Screenshot shows gear seated right.
- Equipping changes stats and they save.

**Playtest check (Kevin)**
- Does new gear look and feel stronger?
- Is undo easy to find?

**Metrics to log**
- Auto-equip undo rate. Element mix of equipped gear.

**Risks**
- Gear clipping on different avatars → test 3 avatar types.
- One element obviously best → keep a quick balance sheet in config.

**Out of scope**
- Upgrading gear, fusing, salvaging, Shard Dust.

---

## Phase 3: One dungeon

**Goal:** one solo wave run that's fun to repeat.

**Start:** pull parts from the salvage map: combat core, dungeon run, enemies, Gnarl boss, hub (gate pad).

**Milestones**
- 3.1 Shard Gate pad near spawn → teleports into arena.
- 3.2 Gray-box arena
  - Round, at least 120 studs, sized for the biggest wave.
  - 3 enemy gates. Test with the max enemy count first.
- 3.3 Enemy type 1 (basic chaser) + wave spawner.
- 3.4 Enemy types 2 and 3 (e.g. ranged, tank).
- 3.5 Wave flow: 6 / 8 / 10 / 12 enemies, wave counter on screen.
- 3.6 Boss + 4 adds on wave 5.
- 3.7 Leave anytime, keep loot from cleared waves.
- 3.8 Stuck-enemy check
  - Pathing test with max wave. No enemies stuck after 30s.

**Done when**
- Kevin can clear solo in about 5 minutes.
- No stuck enemies. Server stays smooth at the biggest wave.

**Playtest check (Kevin)**
- Is wave 1 fun in the first 10 seconds?
- Is the boss a clear finale?

**Metrics to log**
- Run started, wave reached, run cleared, run left early, death wave.
- Run length.

**Risks**
- Lag with many enemies → cap and pool enemies, test on phone.
- Too hard / too easy → all HP and damage in config.

**Out of scope**
- Parties, Hard/Nightmare, second dungeon, art pass.

---

## Phase 4: Close the loop

**Goal:** runs pay out, and you want to roll again.

**Start:** pull parts from the salvage map: currencies, results screen, drops.

**Milestones**
- 4.1 Rewards: Roll Tokens + Fragments, server-side, from config.
- 4.2 Results screen: waves cleared, loot grid, best wave.
- 4.3 Run Again button + back-to-roll shortcut.
- 4.4 Economy check
  - Sheet: tokens per run vs roll cost. Target: about 1 run = a few rolls.

**Done when**
- Full loop works with no dead ends: roll → equip → run → reward → roll.
- Rewards save and match config.

**Playtest check (Kevin)**
- After a run, do you want to roll right away?
- Do you want to run again?

**Metrics to log**
- Tokens earned/spent (economy events). Run Again rate.

**Risks**
- Rewards too stingy or too generous → tune in config only.

**Out of scope**
- Shops, dailies, codes, Robux.

---

## ✅ CHECKPOINT: Kevin's 15-minute fun test (go / no-go)

**How**
- Kevin plays 15 minutes, fresh save.
- 3–6 friends play too. Nobody explains anything.

**Go if**
- Kevin wants to keep playing after 15 min.
- Most friends do at least 2 runs without being asked.
- Nobody gets stuck in the first 2 minutes.

**No-go means**
- We fix the loop here (pacing, rewards, feel).
- Nothing new gets added until it passes.

**Then**
- Review the Parking Lot. Pick at most 2 items for later phases.

---

## Phase S: Vertical slice (decided Oct 21, 2026)

**Goal:** one dungeon looks and feels like the real game.

**Start:** pull parts from the salvage map: UI shell, graphics tiers, audio, hub dressing, generated props.

**Milestones**
- S.1 Arena art pass (one theme only).
- S.2 Enemy and boss models + hit effects.
- S.3 Sound: hits, rolls, reveal, wave clear.
- S.4 UI style pass on Roll, Equip, Results.
- S.5 Phone performance check (frame rate at biggest wave).

**Done when**
- A 30-second clip looks good enough for an ad thumbnail.
- Phone holds a steady frame rate in wave 4.

**Playtest check (Kevin)**
- Does it feel like a real game now?

**Risks**
- Art eats the budget → one theme, reuse assets.

**Out of scope**
- More dungeons or themes.

---

## Phase 5: Our twists

**Goal:** what makes Shardfall different from Survive the Swarm.

**Start:** pull parts from the salvage map: chests (Hard/Nightmare rewards) and titles (Nightmare) from PARK, if Kevin unparks them.

**Milestones**
- 5.1 Pick 1 of 3 element buffs between waves.
- 5.2 Fusion cards (two buffs combine).
- 5.3 30s shard-storm cash-out (keep base loot on death).
- 5.4 Hard mode (Lv 5).
- 5.5 Nightmare mode (Lv 10).
- 5.6 Better shard odds on harder runs.

**Done when**
- Each twist passes its own Kevin check.
- No element picked more than ~50% of the time in testing.

**Playtest check (Kevin)**
- Do the picks change how you play?
- Is Hard worth doing over Normal?

**Metrics to log**
- Buff pick rates. Mode chosen. Cash-out vs keep going.

**Risks**
- One best buff → watch pick rates, tune config.
- Twists slow the run → keep the run near 5 min.

**Out of scope**
- Endless mode, raids.

---

## Phase 6: Players and retention

**Goal:** people play together and come back tomorrow.

**Start:** pull parts from the salvage map: account level, onboarding + starter goals, dailies.

**Milestones**
- 6.1 Parties 1–4 from the gate pad (15s countdown).
- 6.2 +30% enemy HP per extra player. Personal loot.
- 6.3 Anti-AFK: must deal damage in 3 of 5 waves.
- 6.4 Account levels (cap 25).
- 6.5 First-time flow: under 5 min, start new players inside wave 1.
- 6.6 Onboarding funnel events checked (see Analytics).
- 6.7 Dailies (small, all feed rolling or dungeons).

**Done when**
- 4 players clear a run with no errors.
- A new player reaches their first roll in under 2 minutes.

**Playtest check (Kevin + friends)**
- Is a party more fun than solo?
- Can a brand-new friend start without help?

**Metrics to log**
- Party size. Funnel drop-off steps. Daily completion.

**Risks**
- Server load with 3–4 arenas → test full server.
- AFK farming → anti-AFK rule from config.

**Out of scope**
- Trading, guilds, raids, leaderboards.

---

## Phase 7: Launch

**Goal:** a small public launch that tells us if people stay.

**Start:** pull parts from the salvage map: receipts + paid-roll policy. Gold shop / pass stay off unless Kevin says so.

**Milestones**
- 7.1 UI polish + phone layout pass.
- 7.2 Robux shop (Kevin's call; fair, not pay-to-win).
- 7.3 Purchase receipts saved. Save right after every purchase.
- 7.4 Friend phone playtest (6 people). Fix top 3 issues.
- 7.5 Game page: icon, thumbnails, description.
- 7.6 Soft launch: public, small ad test (Kevin approves spend).
  - Approved Oct 21 at the Roblox minimum: 10 ad credits (5/day, 2 days).
  - Kevin still gives the final OK before any spend.
  - Run about a week. 7–8 thumbnails. Target new players.
  - Don't touch the campaign in the first hours.

**Done when**
- One full week of real player data.

**Retention bar (locked Oct 21, 2026)**
- D1 ≥ 10%. (Typical Roblox is ~8%. Great is 15%.)
- Sessions ≥ 10 min. (STS ~11–12 min. Great is 15.)
- D7 ≥ 2%. (Great is 4%.)
- Once we have 100+ DAU, compare against Roblox's peer scorecard instead.

**Decision after soft launch**
- Hit "pass" → grow (more ads, Phase 8).
- Miss D1 or session → fix onboarding and the loop first. Don't buy more players.
- Miss D7 only → fix progression (levels, harder modes, goals).

**Risks**
- Paying for players before the loop holds them → targets first, then spend.
- Looking like a copy → unique names and art (Roblox gives copies less ad reach).

**Out of scope**
- Big marketing spend before targets pass.

---

## Phase 8: Live updates (after launch)

**Goal:** keep players coming back with steady, small updates.

**Start:** pull parts from the salvage map: event banner (PARK) for limited-time events.

**Rhythm**
- Small content update every 2 weeks.
  - New weapons, pets, skills, enemies = config rows mostly.
  - Each under ~3 weeks of work.
- Bigger update about monthly (new dungeon, new mode).
- Weekly once the game proves itself (the Grow a Garden pattern).

**After every update, check**
- D1, D7, session time, new users, revenue.
- Write one line in CHANGELOG: what changed, what moved.

**Rules**
- New content builds on existing systems.
- Content must be earned over days, not eaten in one session.
- Bug fixes ship anytime.

---

## Analytics to add early

Server-side only. Cheap to add now, painful to add later.

**Onboarding funnel (in order)**
1. Joined
2. First roll
3. First equip
4. Entered gate
5. Cleared wave 1
6. Finished first run
7. Second roll with earned tokens
8. Second run

**Economy events**
- Every source: tokens and fragments from runs, free rolls, dailies.
- Every sink: rolls, x10 rolls.

**Custom events**
- Run start / wave reached / run end (cleared, left, died).
- Element equipped. Buff picked (Phase 5).
- Auto-equip undo.

---

## Definition of done (every milestone)

- [ ] Config test passes.
- [ ] Play screenshot or clip attached.
- [ ] Saves survive rejoin (if it touches saves).
- [ ] Server decides the outcome (if it touches rewards or rolls).
- [ ] Works on phone layout.
- [ ] CHANGELOG updated.
- [ ] Kevin answered the milestone's one question.

---

## Parking Lot (later, not now)

Review only at gates.

- Raids
- Classes
- Six-arch plaza
- Mireoak
- Codes
- Shard Dust / merging duplicates (needs Kevin's OK)
- Pets that cast skills
- Endless mode
- Gold upgrade tree
- Hub raid timer
- Trading, guilds, leaderboards
- A/B experiments (need ~1,000+ DAU)

---

---

## Salvage map (what we already built)

Checked Oct 21, 2026 against `cursor/live-build-9721` @ 88cf3ce.
205 source files, 179 tests. Nothing gets deleted.

**Counts:** REUSE 12 · REWORK 19 · PARK 15 (groups of files)

- **REUSE** = fits V1 as is.
- **REWORK** = close, needs reshaping (how is noted).
- **PARK** = off-plan. Switch off with a LaunchGate flag. Don't delete.

Paths: `S/` = src/ReplicatedStorage/Shared, `V/` = src/ServerScriptService/ShardfallServer, `C/` = src/StarterPlayer/StarterPlayerScripts/ShardfallClient. All `.luau`.

LaunchGate already has these flags off: raids, trading, market, pass, petEvolution, bossPets, relicSets, forgeReroll/Salvage/Craft, guilds, leaderboards, extraRealms, extraCurrencies, chests, paid.
NEW flags to add in 0.1: classes, travel, grove, codex, wildCapture, stars, goldShop, events, traits.

### REUSE

**Save system (custom, ProfileStore-style)** → 0.5
- Already session-locked, versioned, migrates. MemoryStore = mock. Keep it, don't swap to ProfileStore.
- Files: `V/DataService`, `V/StoreAdapter`, `S/SessionLock`, `S/ProfileLoad`, `S/Schema (v26)`, `S/MemoryStore`, `S/CallBudget`

**Remotes + checks** → 0.7
- Already one module with rate limits.
- Files: `V/Remotes`, `V/RateLimiter`, `S/RemoteCaller`, `S/RollRefuse`

**Server roll core** → 1.1, 1.3, 1.4
- Server-side odds, pity at 50, x10 at 10% off (#355).
- Files: `V/RollService`, `S/RollMath`, `S/RollConfig`, `S/RarityConfig`, `S/RollBatch`

**Combat core** → 3.3–3.6
- Server hits, melee reach (#357), hit feel.
- Files: `V/CombatService`, `S/CombatMath`, `S/MeleeConfig`, `S/CombatFeel`, `S/CombatAnims`, `C/CombatStage`, `C/CombatHud`, `S/CombatCluster`, `S/HeavyChip`

**Inventory + equip** → 2.1, 2.6
- Compare line → green arrows. Hide salvage prompt.
- Files: `V/InventoryService`, `S/InventoryView`, `S/InventoryStacks`, `S/BagBoard`, `C/InventoryHud`

**Hero stats panel** → 2.2
- Power score from loadout.
- Files: `S/HeroBoard`, `S/HeroView`

**Receipts + paid-roll policy** → 7.2–7.3
- Idempotent receipts. No Robux changes until Phase 7.
- Files: `V/ReceiptService`, `S/PaidRollPolicy`, `V/PolicyCache`

**UI shell + phone layout** → all phases, S.4
- Base for every screen.
- Files: `C/HudShell`, `S/HudLayout`, `S/ShellLayout`, `C/MobileShell`, `S/UiRouter`, `S/UiTheme`, `S/UiMotion`, `S/UiSfx`, `S/UiIcons`, `S/IconAssets`, `S/TextFit`, `S/NotifyBadges`, `S/ToastQueue`, `S/Keybinds`, `S/PadNav`, `C/PadFocus`, `S/PadLight`

**Settings, graphics, audio, loading** → S.3, S.5
- Phone graphics tiers already exist.
- Files: `S/Settings`, `S/Quality`, `C/VerdantLod`, `S/Audio`, `C/MusicController`, `C/LoadingHud`, `S/LoadingTips`

**Debug + safety plumbing** → 0.x
- Studio-only tools.
- Files: `S/DebugTools`, `V/DebugService`, `C/DebugHud`, `V/RunTick`, `S/Build`, `S/ForeignScripts`, `S/ClientChrome`, `S/LegacyChrome`

**Test suite (179 specs, lune)** → 0.4, every merge
- Base for the config validation test.
- Files: `tests/`

**Content docs** → 2.x, 3.x
- Source for config rows.
- Files: `docs/content/ (enemies, bosses, pets, armor)`

### REWORK

**Rarity ladder** → 1.3
- 7 tiers → 5 in config. Keep IDs stable, migrate saves.
- Files: `S/Rarities`

**Roll screen UI** → 1.2, 1.6
- Split into Weapons/Armor/Pets/Skills tabs, no scroll (#356 layout).
- Files: `S/RollScreen`, `S/RollSpot`, `S/RollBoard`, `S/ShardBoard`, `S/CrackCard`, `S/CrackReveal`, `C/RollReel`, `S/RollReveal`, `S/RollLoop`, `S/RollHype`, `S/RollNear`, `S/RollFocus`, `S/HubPress`

**Roll areas + pools** → 1.6
- One pool per tab instead of per area/ascension.
- Files: `S/Areas`, `S/Pools`

**Item catalog + stats** → 0.2, 2.2–2.3
- Add element tag (Ember/Frost/Void) and scaling stat.
- Files: `S/ItemBases`, `S/Stats`

**Gear on body** → 2.5
- Fits R15/Rthro already. Add armor shells + two big welded weapons.
- Files: `S/GearLook`, `V/GearService`

**Set bonuses** → 2.4
- Class 4-piece sets → element 2/3/4 sets in SetBonuses config.
- Files: `S/RelicSets`

**Action bar + skill tooltips** → 2.1, 3.x
- 8 slots → attack + 2 skill slots. Keep tooltips (#361) and cooldown chip (#363).
- Files: `S/ActionSlots`, `C/ActionBar`, `V/ActionBarService`, `S/SkillTip`, `S/CooldownNudge`, `S/ActionDrag`

**Skill casts (inside class code)** → 2.1
- Pull casting into a Skill/Combat path. Class select is parked.
- Files: `V/ClassService`

**Dungeon run** → 3.2–3.7
- Room crawl → one round arena ≥120 studs, waves 6/8/10/12. Keep spawn clearance (#364) + boss HP scaling idea (#362).
- Files: `S/Dungeons`, `V/DungeonService`, `S/Rootvault`

**Enemies** → 3.3–3.4
- Pick 3 types (chaser, mender, shielder). Drops → run rewards.
- Files: `S/ModelFactory`, `S/EnemyAbilities`, `S/Drops`

**Gnarl boss** → 3.6
- Wave 5 boss + 4 adds. Keep weak spot (#359).
- Files: `Gnarl in S/Dungeons / V/DungeonService`

**Currencies** → 4.1
- Six currencies + Forge → Roll Tokens + Fragments (+Gold if needed).
- Files: `S/Currencies`, `S/Economy`

**Results screen** → 4.2
- Add loot grid (#365) + Run Again.
- Files: `C/SessionRecap`, `victory card in C/CombatHud`

**Pets (basic)** → 2.1, 2.5
- One pet slot that follows you. Hatchery/care/fusion stay off.
- Files: `S/Pets`, `S/PetRoster`, `V/PetService`, `C/PetAura`, `C/PetHud`, `S/PetFlash`, `S/PetLine`

**Hub** → 3.1
- Small hub with the Shard Gate pad near spawn. Six-arch plaza parked.
- Files: `S/Haven`, `V/HavenBuilder`, `S/HavenLife`, `S/HavenProps`, `V/PropService`, `S/PropAssets`, `S/VerdantLook`, `S/VerdantScatter`, `S/SavedWorld`, `C/HavenClient`

**First session + starter goals** → 1.5, 6.5
- 3 free rolls now; later start new players in wave 1.
- Files: `S/Onboarding`, `V/OnboardingService`, `C/OnboardHud`, `S/FirstSession`, `S/FirstSessionKit`, `S/StarterGoals`, `S/StarterGoalPay`, `C/StarterGoalHud`

**Account level** → 6.4
- Cap at 25.
- Files: `S/Progression`

**Dailies** → 6.7
- Keep dailies. Shard Board / Pass stay off.
- Files: `S/Loops`, `V/LoopService`, `C/LoopHud`

**Menu** → 1.6, S.4
- 248 KB menu. Slim to Roll, Hero/Bag, Settings.
- Files: `C/MenuHub`, `C/MenuHud`, `C/Ui`

### PARK

**Raids + Story Echo** → Parking Lot
- Flag: raids (off).
- Files: `~25 files: S/Raid*.luau, S/Raids`, `V/RaidService`, `V/RaidReady`, `V/Echo*.luau`, `C/RaidHud`, `S/EchoChip`

**Trading + market** → Parking Lot
- Flags: trading, market (off).
- Files: `S/Trading`, `V/TradeService`, `V/TradeAudit`, `S/MarketBoard`, `V/MarketService`, `C/MarketHud`

**Chests** → maybe Phase 5
- Flag: chests (off). Could pay Hard/Nightmare chests later.
- Files: `S/ChestConfig`, `V/ChestService`

**Forge / crafting** → Parking Lot
- Flags: forgeCraft/Reroll/Salvage (off).
- Files: `S/Crafting`, `S/CraftingLevel`, `S/Recipes`, `S/Materials`, `V/CraftService`

**Pet evolution + boss pets + wild capture** → Parking Lot
- Flags: petEvolution, bossPets (off). NEW flag: wildCapture.
- Files: `S/PetEvolution`, `S/WildCapture`, `V/WildCaptureService`, `C/CaptureHud`

**Classes** → Parking Lot
- NEW flag: classes.
- Files: `S/Classes`, `C/ClassHud`, `class select in V/ClassService`

**Gate Plaza travel / extra realms** → Parking Lot
- Flag: extraRealms (off). NEW flag: travel.
- Files: `S/Travel`, `V/TravelService`, `C/TravelHud`

**Training Grove / practice** → Parking Lot
- NEW flag: grove.
- Files: `S/TrainingGrove`, `V/GroveService`, `S/PracticeLoot`

**Codex + titles** → Phase 5 (Nightmare title)
- NEW flag: codex.
- Files: `S/Codex`, `S/CodexCues`, `S/NameplateTitles`

**Duplicate merge (Stars)** → Parking Lot
- Close to Shard Dust. Needs Kevin's OK. NEW flag: stars.
- Files: `S/Stars`

**Gold shop, Shard Pass, paid** → Phase 7
- Flags: pass, paid (off). NEW flag: goldShop.
- Files: `S/GoldShop`, `Shard Pass in S/Loops`

**Event banner** → Phase 8
- NEW flag: events.
- Files: `C/EventBanner`, `S/EventBannerModel`, `S/BannerFit`

**Room doors** → none
- Room flow closed with #358.
- Files: `C/DoorHud`

**Weapon traits** → Parking Lot
- Extra roll layer. NEW flag: traits.
- Files: `S/Traits`

**Mireoak** → Parking Lot
- Not in V1.
- Files: `Mireoak in S/Dungeons`

