# Roll miss test plan

G-072. A failed `RollShard` on the Roll tab must not paint Miss or break the session streak unless the roll is a real miss. This file does not change code.

`beginRoll` no longer calls `RollHype.note` for every failure. It asks `RollRefuse.classify` first (`MenuHub.luau:4325-4363`). A refusal leaves the streak. A miss is the only branch that notes `landed = false`.

Choice: the real miss is the shape the classifier already names. The live crack returns an item on success (`RollService.luau:280-300`) and `{ ok = false, error = message }` on failure (`RollService.luau:43`). The server does not send the miss shape. The client branch stays (`RollRefuse.luau:12-13`).

`landed = false` sets the streak to 0 and does not add a roll (`RollHype.luau:295-310`).

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| RM1 | A thrown invoke, including a timed-out remote, is a refusal. The streak must stay | `RollRefuse.luau:39-41`, `RollRefuse.luau:9-10`, `MenuHub.luau:4326-4362` | high | `RollShard` throws. Caption becomes the error text when that text is a single line (`MenuHub.luau:4332-4336`). The reel does not say Miss. Streak and roll count stay. `lastMissed` stays false |
| RM2 | "not enough tokens" is a refusal, even when `ok` is true and an error string is set | `RollRefuse.luau:46-54`, `RollReveal.luau:125-140` | high | Result `{ ok = false, error = "not enough tokens" }`, or the same error with `ok` true and no item. Streak stays. The reel shows `not enough tokens`, not Miss |
| RM3 | The miss shape still zeros the streak and paints Miss | `RollRefuse.luau:51-52`, `MenuHub.luau:4338-4355`, `RollHype.luau:295-310`, `RollReveal.luau:125-131` | high | `pcall` ok, result `{ ok = true }` with no item and no error (or a blank error). Streak becomes 0. Reel says Miss. Roll count does not go up. This is the only real miss |
| RM4 | An ok `RollShards` body with no item field takes the miss branch | `MenuHub.luau:4267-4294`, `RollRefuse.luau:46-54` | medium | Batch payload `{ ok = true, items = {} }` fails the `#items > 0` check, so `result` is that table. It has no `item` and no error, so it is a miss and the streak drops. `rollMany` does not send an empty `items` list today (`RollService.luau:324-353`). A payload that matches it still fails the streak |
| RM5 | A land the reel cannot read does not note a miss, but it also does not show the item | `RollReveal.luau:68-79`, `MenuHub.luau:4327-4348` | medium | `{ ok = true, item = { name = "Thorn Dagger" } }` with no uid. `classify` says land. `capture` returns nil. The code takes the "unusable land" path and does not call `note`. Streak stays. The reel goes back to Roll |
| RM6 | A bad hype state still paints Miss | `MenuHub.luau:4338-4355`, `RollHype.luau:281-285` | low | Miss shape, but `note` returns `ok` false. The stored streak stays. `lastMissed` is still set true and the reel can say Miss |

RM1 and RM2 are the cases that used to look like a miss. RM3 is the real miss. RM4 is the batch hole that still matches RM3.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| RL-1 | Roll tab, streak 4, tokens enough | Force `RollShard` to throw, then repeat with the timeout string as the pcall error | Streak 4. Rolls unchanged. Reel is not Miss. No `RollHype.note` |
| RL-2 | Streak 4, zero tokens | Invoke returns `{ ok = false, error = "not enough tokens" }` | Streak 4. Reel text is `not enough tokens` |
| RL-3 | Streak 4 | Result `{ ok = true, error = "not enough tokens" }` and no item | Streak 4. Same caption as RL-2. A paid flag on the table does not change it (`RollRefuse.luau:19-20`) |
| RL-4 | Streak 4 | Result `{ ok = true }` with item nil and error nil, then again with `error = "   "` | Both are the real miss. Streak 0. Roll count unchanged. Reel says Miss. `lastMissed` true |
| RL-5 | Streak 4 | `RollShards` returns `{ ok = true, items = {} }` | Streak 4. An empty batch is not a miss. Today RM4 zeros the streak, and that fails this case |
| RL-6 | Streak 4 | A normal land, item uid set | Streak 5. Reel shows the item. `lastMissed` false |
| RL-7 | Streak 4 | `{ ok = true, item = { name = "Thorn Dagger", rarity = "Common" } }` and no uid | Streak 4. Reel returns to Roll. The item is not shown as a land and not shown as Miss |
| RL-8 | Streak 4, reveal generation changed before the invoke returns | Let the result arrive late | The function returns at `MenuHub.luau:4300-4302`. Streak 4. No note |
| RL-9 | Miss shape, hype state not a table | Run `note` | Stored streak unchanged. The reel does not say Miss unless the state was accepted |

## Flags

None. No paid random item is added. A `paid` or `prism` field does not move a result between refuse, miss, and land.
