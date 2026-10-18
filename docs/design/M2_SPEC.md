# M2 — Plaza and restyle

Status: **queued.** Kevin playtests M1 first. Do not write M2 code until Kevin approves this spec.

Sources: `docs/design/vision/VISION.md`, `docs/design/vision/refs/`, `docs/design/refs/`, `docs/design/UI_STYLE.md`, `docs/design/mockups/`, and `docs/design/LAUNCH_PLAN.md` (approved Oct 17, 2026).

M2's done-when in the launch plan is: compact plaza built, and Roll, Bag, Forge, and Pets match the vision. The work is T-195 through T-202. T-189 stays the milestone row and stays queued.

## Rules that stay

- Schema stays 26. `Loops.PREMIUM_ENABLED` stays false. Nothing costs Robux. Product ids stay 0.
- `LaunchGate` stays off. Raids, trading, the Market Board, the season pass, pet evolution, boss pets, relic sets, Forge reroll, salvage, and craft recipes stay hidden.
- `UiTheme.RARITY` Common through Legendary stays frozen. Contrast of text, muted, and gold on body, panel, and header stays at least 4.5. `STROKE_BOLD` stays at most 2.
- Keep the crack reveal and the text-size slider. Keep the runtime overlap check from M0.
- Currencies on the HUD are Gold and Shards. The Mastery pill stays hidden. Do not add a gem currency.
- The six-gate crescent in `docs/design/DUNGEON_GATE_PLAZA.md` is not the target.

## Plaza

One compact square, from `VISION.md` (world) and the launch KEEP list (3 dungeons).

- Spawn is the center.
- Roll, Forge, and Pets stands sit on one side.
- Exactly three dungeon gates sit in one row on the other side.
- Walk speed is 16. Every stand and every gate is at most 240 studs from spawn (15 seconds).
- Each gate and each of Roll, Forge, and Pets has a sign readable from spawn.
- The first unlocked gate is lit. The other two stay dim until they unlock.
- Raid is not a plaza destination while raids are parked.

## Restyle gaps

These are the gaps left after T-186 and T-187. Match the structure in the vision and the mockups. Do not copy reference art, names, or paid packs.

- Roll: the shard icon does not cover the "You need a Shard to crack" sentence. The in-panel Bag / Pets / Roll nav column is gone, because the HUD rail is the nav. Pity bars sit inset from the border (Epic and Legendary). The Odds label has the disclose lines beside it. Crack reveal and the text-size slider stay.
- Bag: pill tabs, rarity tiles, a detail pane with EQUIP and a gold UPGRADE, Equip Best, and Capacity stay aligned. Open full bag and Manage lives use the same rounded panel.
- Pets: the list stays pets and pet shards only. The detail pane has the perk, the stats, EQUIP, and CRACK PET SHARD. No forge item lines.
- Hotbar: a level uses a small corner badge. The slot face does not overflow "LV 4" or "LV 10". The key stays top-left. The selected slot stays a white stroke.
- Quest tracker: compact, top-left, diamond bullets, `N/M` counters. The data line stays `text N/M`.
- Forge: the launch panel is upgrade-only. Dark rounded panel, gold UPGRADE, no empty recipe list, no Robux. T-206 (M1 polish) opens the Forge on upgrade before this restyle starts.

## Three lanes

Lanes run in parallel. A file belongs to one lane. Tasks inside a lane run in order.

| Lane | Tasks | Files | Leave alone |
|---|---|---|---|
| A. Plaza | T-195, then T-196 | `src/ReplicatedStorage/Shared/Haven.luau`, `src/ServerScriptService/ShardfallServer/HavenBuilder.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HavenClient.luau`, `tests/Haven.spec.luau`, `tests/HavenBuild.spec.luau` | `MenuHub.luau`, `Ui.luau`, `HudShell.luau`, `ActionBar.luau` |
| B. HUD and Forge | T-197, then T-198, then T-199 | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/ActionBar.luau`, `src/ReplicatedStorage/Shared/HudLayout.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/StarterGoalHud.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/Ui.luau`, and the matching tests (`ActionSlots`, `HudLayout`, `ClientChrome`, `StarterGoalHud`, `LegacyFit`) | `Haven.luau`, `HavenBuilder.luau`, `HavenClient.luau`, `MenuHub.luau`. Do not edit `init.client.luau` (T-206 owns the upgrade callback). |
| C. Hub pages | T-200, then T-201, then T-202 | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau`, `src/ReplicatedStorage/Shared/HubStyle.luau`, `src/ReplicatedStorage/Shared/BagBoard.luau`, `tests/HubInput.spec.luau`. `src/ReplicatedStorage/Shared/RollBoard.luau` only if a pity bar needs a pure helper. | `Haven*`, `Ui.luau`, `HudShell.luau`, `ActionBar.luau` |

Lane B's T-199 starts after T-206 has merged, because both edit `Ui.luau`. Lane C's T-200 starts after T-203 and T-204 have merged, because both edit `MenuHub.luau` and `tests/HubInput.spec.luau`. Those four rows are M1 polish and can land during the playtest.

## Tasks

### T-195 — Compact plaza square

Lane A. Files: `Haven.luau`, `HavenBuilder.luau`, `tests/Haven.spec.luau`, `tests/HavenBuild.spec.luau`.

Done when: spawn is the center; Roll, Forge, and Pets stands are on one side; exactly three dungeon gates are in one row on the other; at walk speed 16 every stand and every gate is at most 240 studs from spawn. A Haven test locks the distances. The six-gate crescent is gone.

### T-196 — Signs and the first gate

Lane A, after T-195. Same files, plus `HavenClient.luau` if the forge arrow must point at the new Forge stand.

Done when: each gate and Roll, Forge, and Pets have a sign readable from spawn; the first unlocked gate is lit and the other two are dim until unlocked.

### T-197 — Hotbar level badge

Lane B. Files: `ActionBar.luau`, `tests/ActionSlots.spec.luau`, `tests/ClientChrome.spec.luau`.

Done when: a level uses a small corner badge and the slot face does not overflow "LV 4" or "LV 10". Keys stay top-left. The selected slot stays a white stroke. `HudLayout.RAIL_COUNT` stays 6. The rail still snaps to 44 when the preferred size does not fit.

### T-198 — Quest tracker and currency column

Lane B, after T-197. Files: `StarterGoalHud.luau`, `HudShell.luau`, `HudLayout.luau`, `tests/StarterGoalHud.spec.luau`, `tests/HudLayout.spec.luau`.

Done when: the tracker stays compact top-left with diamond bullets and `N/M` counters, and the HUD currency column shows Gold and Shards only. The goal line stays `text N/M`. The Mastery pill stays hidden.

### T-199 — Forge panel restyle

Lane B, after T-198 and after T-206. Files: `Ui.luau` and `tests/LegacyFit.spec.luau`.

Done when: the Forge panel matches the upgrade-only launch look (dark rounded panel, gold UPGRADE, no empty recipe list, no Robux). `fitLegacyText()` stays the last call of `renderCraft`. `ui.openPanel("craft")` stays the world prompt. Do not add `HubPress` or `HubStyle` to `Ui.luau`.

### T-200 — Roll page gaps

Lane C, after T-203 and T-204. Files: `MenuHub.luau`, `tests/HubInput.spec.luau`, and `RollBoard.luau` only if the pity inset needs a pure helper.

Done when: the shard icon does not cover the no-token sentence; the in-panel Bag / Pets / Roll nav column is gone; pity bars sit inset from the border; the Odds label has the disclose lines beside it; the crack reveal and the text-size slider stay.

### T-201 — Bag page gaps

Lane C, after T-200. Files: `MenuHub.luau`, `HubStyle.luau`, `BagBoard.luau`, `tests/HubInput.spec.luau`.

Done when: pill tabs, rarity tiles, the detail pane with EQUIP and UPGRADE, Equip Best, and Capacity stay aligned. Open full bag and Manage lives use the same rounded panel style.

### T-202 — Pets page gaps

Lane C, after T-201. Files: `MenuHub.luau`, `tests/HubInput.spec.luau`.

Done when: the list stays pets and pet shards only; the detail pane has the perk, stats, EQUIP, and CRACK PET SHARD; no forge item lines appear.

## M1 polish (not M2)

These four rows can run during Kevin's M1 playtest. They are not plaza or restyle work. Two polish lanes, so they do not edit the same files:

| Polish lane | Tasks | Files |
|---|---|---|
| Roll and shop | T-203, then T-204 | `MenuHub.luau`, `tests/HubInput.spec.luau` |
| Odds and Forge | T-205, then T-206 | `init.client.luau`, `Ui.luau`, `tests/PlaytestFollowup.spec.luau` |

### T-203 — A drag-off does not eat the next press

Done when: a pointer press that leaves the Roll button without `Activated` still cracks once, and the next keyboard or controller activation cracks again. An immediate `Activated` after a pointer press still cracks once. Do not clear `rollFromPointer` on `InputEnded`. A short time window (about 0.75s) or a non-pointer `InputBegan` drops the stale flag. ButtonA still presses on `InputBegan` and the following `Activated` does not crack a second time. The no-token sentence stays.

### T-204 — A shop failure toasts a fixed sentence

Done when: `buyOffer` toasts `Could not buy that.` when the invoke throws. A raw Lua error does not reach the toast. A server string such as `You need more Gold.` still toasts as itself.

### T-205 — A throttled odds fetch retries

Done when: `GetOdds` answering `Slow down a moment.` waits and retries, at most twice, about 1.1 seconds apart. Other errors still warn and set status. A throttled pool switch does not keep the previous pool's odds. The rate-limit sentence stays off the toast and the status line.

### T-206 — The Forge opens on upgrade

Done when: with `forgeCraft` and `forgeReroll` off, the Forge prompt still calls `ui.openPanel("craft")` and the panel shows upgrade rows for weapons and armor, not an empty recipe list. The Craft tab stays hidden while craft is off. An empty bag says `Upgrade gear from your bag.` `fitLegacyText()` stays the last call of `renderCraft`.
