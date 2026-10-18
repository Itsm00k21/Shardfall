# Trade exploit review

G-058. Dupes, races, and scams in `Trading.luau`, `TradeService.luau`, and `TradeAudit.luau`. This file does not change code.

A normal commit is locked. `withPlayers` takes `Trading.tryLock` for both ids and holds it across `savePair` (`TradeService.luau:131-149`, `TradeService.luau:393-406`). `finish` moves items only after both sides have confirmed, the seen revision matches, and the 3 second lock is over (`Trading.luau:1954-1961`). `applyOffers` restores both profiles when a move fails (`Trading.luau:1898-1923`). Gold keeps a 10% tax (`Trading.luau:27`, `Trading.luau:1517-1521`). Robux items stay bound while `ROBUX_ITEM_TRADING_ENABLED` is false (`Trading.luau:49-50`, `Trading.luau:477-478`).

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| T1 | `savePair` cannot put a closing profile back. That profile stays on the swapped bag. The other is restored from the backup, so the restored side's items sit in both bags | `DataService.luau:230-232`, `DataService.luau:245-252`, `DataService.luau:255-275`, `TradeService.luau:393-406` | high | Both confirmed, bags already swapped in memory. `closing` is true before that player's `save` or `replace`. `save` returns false at the closing check, before `UpdateAsync`. `replace` returns false. Memory for that player stays swapped. The other player is written back to the backup. A flag flip inside the `UpdateAsync` callback does not make that same `save` return false |
| T2 | A failed audit load returns an empty log. The next save replaces the store key with that short log | `TradeAudit.luau:107-131`, `TradeAudit.luau:135-141`, `TradeService.luau:81-84`, `TradeService.luau:273-282` | high | Boot while `load` throws. The warn is `trade audit load failed`. One new trade then `persistAudit`. The stored entries from before the boot are gone. Rollback of an old id returns "No trade with that id." The other warn, `using an empty log`, is the store failing to open. That path keeps a memory adapter and does not write the DataStore key |
| T3 | Invite does not take the trade lock. `forget` clears `byUser` by user id, so it drops a session that was opened while `savePair` was yielding | `TradeService.luau:294-326`, `TradeService.luau:97-99`, `Trading.luau:259-268` | high | `finish` has already set status to `committed`. `savePair` is yielding inside `withPlayers`, so the lock is held, and invite does not check it. Status is not `open`, so the "already in a trade" check lets the invite through. `forget` then nils `byUser` for both of the original ids. The new session is left in `sessions` with no `byUser` row. A follow-up offer on that invite never finds it |
| T4 | An offer during that same window can hold uids on the orphan. `dropTradeOffer` only clears a uid whose session id still matches | `Trading.luau:443-456`, `Trading.luau:430-439` | medium | After T3, put a uid on the orphan before `forget`, then let the live session end. `consumeBlock` still says the item is in a trade. Salvage and feed refuse it (`Crafting.luau:362-364`). Nothing in the live session can drop that hold |
| T5 | Rollback needs both players in this server. A leaver cannot be reversed. A failed pair-save clears the reversed flag but the audit save is a separate call | `TradeService.luau:212-257`, `Trading.luau:1606-1682` | medium | Commit, one player leaves, `rollback` returns "Both players have to be online". Both stay, `savePair` fails: `entry.reversed` is set back to false (`TradeService.luau:252-254`) and the profiles should match the backups. The audit row can still say reversed if a later `persistAudit` never ran |
| T6 | Friend trades are never treated as connected. Every lopsided pair can flag | `TradeService.luau:55-73`, `Trading.luau:1193-1200`, `Trading.luau:1253-1258` | medium | `actorOf` sets `connected` to nil. Two accounts on each other's friend list, one side giving 10× the value: the flag list still contains `"lopsided"`. The warning text still depends on `WARNING_SHARE` (0.95), not on this flag (`Trading.luau:1181-1189`) |
| T7 | The giver can accept a 95% warning alone. The receiver is not asked. Flags do not block the move | `Trading.luau:1971-1996`, `Trading.luau:1242-1350` | medium | Left offers almost all the value. Left commits without `acceptWarning` and gets `needsWarning`. Left commits again with `acceptWarning` true. Right commits with no warning flag. The trade completes. `"lopsided"` is on the audit row and did not stop it |
| T8 | `persistAudit` failure is a warn. The profiles can be saved with no log row | `TradeService.luau:81-84`, `TradeService.luau:407` | low | `TradeAudit.save` returns false after a good `savePair`. Both bags are swapped. `search` does not find the id until a later save succeeds |

T1 is the dupe. T2 is the scam log disappearing. T3 and T4 are the race. T7 is the scam the rules allow through once the giver taps through.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| TR-1 | Two profiles, one sword each, both confirmed, lock expired | Finish while both saves succeed | Each sword has one owner. Gold received is 90 for a 100 offer. The audit id exists once |
| TR-2 | Same, but the second `save` returns false and both `replace` calls succeed | Finish | Both profiles match the backups. Session is reopened (`Trading.reopen` via `TradeService.luau:401`). Client error is "Could not save that trade. Nothing was kept." A second confirm pair can commit |
| TR-3 | Same, but one profile has `closing` true before `save` and `replace` | Finish | The closing profile must not keep the swapped bag while the other profile is back on the backup. That split is T1. Pass is both bags on the backups, or both bags on the swap, never one of each |
| TR-4 | Store log has two old rows. `TradeAudit.load` throws | Boot, then one small trade, then save | The two old rows are still in the store. The new row is added. An empty in-memory log must not be the document that gets written. The warn is `trade audit load failed` |
| TR-5 | `savePair` yielding after `finish` marked the session `committed` | Second client sends `invite` for one of the two ids | Invite is refused while the lock is held, or `forget` does not clear a `byUser` row whose session id is newer |
| TR-6 | TR-5 was allowed to open a session | Offer a uid, let the first commit finish | That uid is not stuck in `tradeItems`. Salvage works |
| TR-7 | Normal commit, then one player leaves | `TradeService.rollback` | Error names the offline player. Bags do not change. When both are back, one rollback returns the items and a second rollback returns "already reversed" (`Trading.luau:1607-1608`) |
| TR-8 | New account, Mythic obtained just now | Offer the Mythic | Rejected for the 7 day bind (`Trading.luau:30`, `Trading.luau:494-498`). An older Mythic is allowed. A `starter_` item and a `paid` item are rejected (`Trading.luau:400-411`, `Trading.luau:477-482`) |
| TR-9 | Same uid twice in one offer. A uid the player does not own. An equipped uid | `normalize`, then finish | "listed twice" (`Trading.luau:608-609`). "do not have that item." "That item is equipped." (`Trading.luau:1133-1141`) |
| TR-10 | Left value is 95% or more of the pair | Commit without `acceptWarning`, then with it | First call sets `needsWarning` and moves nothing. Second call, after the other side commits, moves the items |
| TR-11 | `GEM_TRADING_ENABLED` false, or the actor is New | Offer gems | "Gem trades are turned off." or the Standard-tier line (`Trading.luau:378-388`). No gems move |
| TR-12 | Both sides offer only empty tables | Commit | "Add something to the trade." (`Trading.luau:1968-1969`). Bags unchanged |
| TR-13 | Offer set, then the other side changes their offer | The first side commits without confirming again | "The trade changed. Confirm again." (`Trading.luau:1957-1958`). `setOffer` cleared `confirmed` (`Trading.luau:799-804`) |
| TR-14 | Item is in an offer | Salvage, feed, and bulk salvage that uid | Each one returns the trade hold string. After cancel, salvage works (`Trading.luau:837-849`) |

## Flags

None. The warning copy is the live `warningText` line. No paid trade fee is added here. Gem trading stays on the kill switch already in `Trading.luau`.
