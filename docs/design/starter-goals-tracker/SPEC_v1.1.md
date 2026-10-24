# Starter Goals Tracker, Spec v1.1: Ghost's decisions folded, key value checked against live code (NOT APPROVED, docs only)

Owner: Prism (design, docs only: no code, no Config, no flag flips). Builders: Ghost (`StarterGoalHud.luau`, `init.client.luau`, `HudLayout`; Prism edits none of them), Echo (`StarterGoals`, `StarterGoalPay`). Base: `cursor/live-build-9721` @ **`a28a5e2`** (no starter-goal file changed since `bcef573`, so every v1 `file:line` still holds). Date: Oct 24, 2026 (PT).
Asked for in: Ghost's Agent Board row DP40P https://app.notion.com/p/403c31ca388381019967e14f73d4b5e4. ACK: https://app.notion.com/p/403c31ca3883819ea93ced18efc48254. Kevin pre-approved Ghost's tasks. Nothing here is official until Kevin approves it and it is copied into Vision & Design Rules.
Builds on `SPEC_v1.md` (same folder, PR #465). Every v1 section stands except the rows below. Mockups 01–04 are unchanged: they already draw the decided answers.

## What changed in v1.1
All 4 v1 open questions are decided (Ghost, DP40P, under Kevin's pre-approval; Kevin can veto Q4):
| v1 Q | Board Q | Decision | Where it lands in v1 |
|---|---|---|---|
| 1 | Q3 | **Counter T = reachable goals**: "GOALS 0/3" while `waveArena` is off, "GOALS 0/5" when it's on. No fixed /5. | §5 "Counter N/T" is now final. Echo still adds `done` + `total` to the show result (§9) so the client never counts. |
| 2 | Q4 | **Auto-fold** the tracker to its 108×44 tab while a toast or the Equip/Keep prompt is up on phones. It unfolds when the lane clears. | §3 step 6, §4 phone rows. Final. |
| 3 | Q5 | **Short labels on landscape phones**, including **"Beat the Warden"**. Full "Beat the Hollow Warden" stays on portrait, desktop and the boss bar. | §6 short-label table. Final. |
| 4 | Q7 | **Show "10 Shard Keys each"** under the counter on portrait and desktop, **only if it matches the live grant**. **It does** (below). | §5 header row, §6 copy. Final; Kevin can veto. |

## Q7 check: the key value in live code (`a28a5e2`)
| What | File:line | Value |
|---|---|---|
| Config | `src/ReplicatedStorage/Shared/StarterGoals.luau:45–49` (`StarterGoals.CONFIG`), **line 47** `shardKeys = 10` | **10** |
| Validator pin | `StarterGoals.luau:203` (`CONFIG.shardKeys ~= 10` → rules unusable) | 10 |
| Grant | `StarterGoals.luau:615` `local keys = if accept then CONFIG.shardKeys else 0` (returned at :629) | 10 per accepted goal |
| Pay check | `src/ReplicatedStorage/Shared/StarterGoalPay.luau:243` (`payout.amount ~= StarterGoals.CONFIG.shardKeys` is refused) | 10 |
| Currency | `StarterGoals.luau:48` `currency = "shardKeys"` | Shard Keys |
So "10 Shard Keys each" and the "+10 Shard Keys" grant chip both match the live grant. **Build note (Ghost):** build both strings from `StarterGoals.CONFIG.shardKeys`, not a literal 10 (`string.format("%d Shard Keys each", StarterGoals.CONFIG.shardKeys)`), so a future tuning change can't make the label lie. If the value ever changes, the label changes with it. If `CONFIG` can't be read on the client, hide the sub-line instead of guessing.

## 1–4. Goal, Where it lives, Flow, Layout
Unchanged from v1. Step 6 (auto-fold) and the counter rule are now decided, not proposed. One addition from the Wave HUD v2 pass (`prism/wave-hud` `SPEC_v2.md`, PR #428): **during a Shard Crater run the tracker shows as its folded tab only** (proposed there as Wave HUD Q6), so the wave chip and boss bar have the top band to themselves.

## 5. States (changed rows only)
| State | Look |
|---|---|
| Header | "GOALS N/T" gold BuilderSansBold 14 + muted "10 Shard Keys each" (portrait/desktop only; text from `CONFIG.shardKeys`) + 44 px fold chevron ‹ |
| Counter N/T | **Decided:** N = granted goals among the reachable ones; T = reachable goals (0/3 arena off, 0/5 arena on) |
| Auto-fold | **Decided:** folds to the tab while a toast or the Equip/Keep prompt is showing on phones; unfolds 0.2 s after the lane clears |

## 6. Copy (changed rows only)
"10 Shard Keys each" (decided, from `CONFIG.shardKeys`), "+10 Shard Keys" (grant chip, same source), "Beat the Warden" (landscape short label, decided).

## 7–10. Visual style, Motion, Roblox build notes, Mobile checks
Unchanged from v1, plus the build note under the Q7 check above (read `CONFIG.shardKeys`, no literal).

## 11. Open questions
None left from v1. One new, small:
1. **@Ghost:** during a Shard Crater run, show the tracker as its folded tab only (it would otherwise sit in the right column where the Wave HUD v2 chip goes on landscape)? Prism recommends **yes**. Tracked as Wave HUD v2 Q6 on PR #428 so it's answered once.

## Decision log
- 2026-10-24 (Prism, DP39P task 2): v1 tracker visual (`b980408`, `5794ec2`). NOT APPROVED.
- 2026-10-24 (Ghost under Kevin's pre-approval, DP40P https://app.notion.com/p/403c31ca388381019967e14f73d4b5e4): v1 Q1 reachable counter, Q2 auto-fold, Q3 short labels incl. "Beat the Warden", Q4 "10 Shard Keys each" only if it matches the live grant. Prism checked: it matches (StarterGoals.luau:47, grant :615, pay check StarterGoalPay.luau:243). Kevin can veto Q4. NOT APPROVED until copied into Vision & Design Rules.
