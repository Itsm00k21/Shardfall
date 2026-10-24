# Premade ghost seat test plan

G-079. A disconnect during a failed premade hop leaves the seat in the listing. This file does not change code.

`departUser` returns while `hopHold` is set (`RaidService.luau:410-412`). `PlayerRemoving` calls `departUser` and only then clears the hold (`RaidService.luau:493-498`). The seat is never passed to `RaidPremade.depart`.

`hopPremade` sets the hold before `TeleportAsync` (`RaidService.luau:946-948`). The failure return calls `stop`, which nils the hold and does not call `departUser` (`RaidService.luau:890-892`, `RaidService.luau:964-978`). A userId that already left stays in `listing.members`.

The listing stays active until `now >= expiresAt`. That stamp is `createdAt + listingSeconds`, and `listingSeconds` is 1800 (`RaidPremade.luau:31`, `RaidPremade.luau:525`, `RaidPremade.luau:551-552`). `sweep` removes it only after that (`RaidService.luau:366-374`).

Ready scores `listing.members` (`RaidService.luau:1293-1298`). `partySize` is the length of that list (`RaidReady.luau:111-121`). A ghost id counts.

Choice: the window is the failed hop only. Disconnect after `stop` has nilled the hold, so `departUser` can run. A hop that returns success is not this plan. The seated failure sentence is not this plan.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| GS1 | Host disconnects while the hold is set. The listing does not close | `RaidService.luau:410-412`, `RaidService.luau:946-948`, `RaidService.luau:964-978`, `RaidPremade.luau:801-810` | high | Full Story listing. Ready completes and the teleport fails. The host drops during `TeleportAsync`, before `stop` returns. `depart` on a host would set `hostLeft` and `closed`. That call never runs. `closed` stays false. The host id is still in `members`. A member who clicks Ready is told "The host has not started the ready check." (`RaidReady.luau:151-152`). The row stays on the board until 1800 seconds after `createdAt` |
| GS2 | A member disconnects while the hold is set. Ready still counts them | `RaidService.luau:493-498`, `RaidPremade.luau:813-828`, `RaidReady.luau:111-121`, `RaidService.luau:1304-1307` | high | Same failed hop. A non-host member drops during the hold. `depart` would have removed that id. It does not. The host can start a new check. `Ready n/n` uses the old size, including the missing id. `complete` stays false because that id cannot vote. The note never reaches a launch |
| GS3 | The ghost keeps the listing full | `RaidPremade.luau:665-667`, `RaidPremade.luau:575-580` | high | The listing was 8 of 8. After GS1 or GS2, `partySize - #members` is still 0. A new player gets "That listing is full." The free seat the disconnect should have made does not exist |
| GS4 | The seat lasts until the listing expires | `RaidPremade.luau:31`, `RaidPremade.luau:525`, `RaidPremade.luau:551-552`, `RaidService.luau:366-374` | medium | One second before `createdAt + 1800`, the ghost is still seated and Ready still counts them. At `createdAt + 1800`, `sweep` drops the row. A Ready click then says "You are not seated on a premade listing." (`RaidService.luau:1272-1274`) |
| GS5 | A disconnect after the failure returns does leave | `RaidService.luau:890-892`, `RaidService.luau:410-412` | low | The teleport has already failed and `stop` has nilled the hold. The host then leaves, or a member then leaves. `departUser` calls `RaidPremade.depart`. The host closes the listing. The member is removed. Ready's size drops. This is the pass next to GS1 and GS2 |
| GS6 | A reconnect is still the same seat | `RaidService.luau:385-397` | medium | The player from GS2 rejoins before expiry. `seatedRow` finds their old id. They are not a new join. A different player is still refused as full |

GS1 is the host-left case. GS2 is the member-left case. GS3 is both of them blocking a new player. A hop that returns success, and the sentence "The raid teleport failed. The party is still seated.", are not GS1 or GS2.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| HG-1 | 8 seated, Story, raids flag on in the harness. Teleport fails | Host disconnects during the hold | The listing stays open. The host id is still a member. It does not close. A member cannot start Ready. The row is gone at `createdAt + 1800` and not before |
| HG-2 | Same party | One non-host member disconnects during the hold | The host starts Ready. The note counts 8, not 7. It never completes. A ninth player is refused "That listing is full." |
| HG-3 | Same party, after the failure has returned and the hold is nil | Host leaves with the Leave button, or by a later disconnect | The listing closes. Ready says you are not seated |
| HG-4 | Same as HG-3 | A member leaves after the hold is nil | That id is gone. Ready's size is 7. A new player can sit if a slot is open |
| HG-5 | GS2, before expiry | The missing member rejoins | They are still seated. They do not take a second seat. A stranger is still refused |
| HG-6 | Full party, teleport never starts, hold never set | Host disconnects during the early checks, before `hopHold` is set | `depart` runs. The listing closes. Scoring this as HG-1 fails the case |

## Flags

None. The hold does not sell a seat. A `productId` or `robux` field is not a member. No live listing duration changes.
