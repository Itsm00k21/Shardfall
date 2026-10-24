# Premade ghost seat test plan

G-079. A disconnect during a failed premade hop leaves that userId on the listing. Ready counts them. This file does not change code.

`departUser` returns immediately while `hopHold[userId]` is true (`RaidService.luau:410-412`). `PlayerRemoving` calls `departUser` first and clears the hold after (`RaidService.luau:493-498`). The seat is already kept. `hopPremade`'s `stop` then sets `hopHold` nil for the seated list and does not call `departUser` (`RaidService.luau:890-899`). A userId that already left stays on `listing.members`.

The hold is set before `reservedCode` and `TeleportAsync` (`RaidService.luau:946-948`). The failures after that point call `stop(true)` (`RaidService.luau:950-955`, `RaidService.luau:964-978`). `stop(true)` also clears `row.ready`. The next Ready check starts over, and the ghost has to vote again. They are gone, so they cannot.

A listing expires at `createdAt + listingSeconds` (`RaidPremade.luau:525`). `listingSeconds` is 1800 (`RaidPremade.luau:31`). `isExpired` is `now >= expiresAt` (`RaidPremade.luau:551-552`). `sweep` drops a listing that is not active (`RaidService.luau:366-374`). Until that instant, `RaidPremade.status` still counts the ghost in `memberCount`, and `full` stays true while `members` fill `partySize` (`RaidPremade.luau:575-589`).

`RaidReady.vote` sizes the check from those member ids (`RaidReady.luau:112-121`, called at `RaidService.luau:1293-1298`). `partySize` on the vote is the id count. Complete needs every id, including the ghost.

Host leave would close the listing (`RaidPremade.luau:20`, `RaidPremade.luau:801-810`). Member leave would drop that one id (`RaidPremade.luau:813-828`). Neither call runs for the id that disconnected during the hold.

This plan does not restate T-117. The success path after `TeleportAsync` keeps every seat on purpose and does not depart (`RaidService.luau:980-996`). A pass here does not drop those seats. It does not restate T-118. The seated failure line is not a step.

Choice: the clock is `createdAt + 1800`, not 1800 seconds after the disconnect. A check at `createdAt + 1799` still counts the ghost.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| GS1 | A member disconnects while `hopHold` is set, the hop fails, and the seat remains | `RaidService.luau:410-412`, `RaidService.luau:493-498`, `RaidService.luau:890-899`, `RaidService.luau:946-978` | high | Four seated, member userId 42 drops during the hold, then `reservedCode` fails or `TeleportAsync` does not return `"teleported"`. 42 is still in `members`. `closed` is false. The next Ready from a live member shows a party size of 4. 42 cannot press Ready, so the check never completes |
| GS2 | The host disconnects in that same window, and the listing does not close | `RaidService.luau:410-412`, `RaidPremade.luau:801-810`, `RaidPremade.luau:20` | high | Host userId is the one that leaves during the hold. After `stop`, `hostUserId` is unchanged, `closed` is false, and `hostLeft` was never returned. The other members can leave themselves once the hold is nil. The host id stays until `createdAt + 1800`. Ready still counts the host |
| GS3 | Ready counts a userId that is not in `Players` | `RaidReady.luau:112-121`, `RaidService.luau:1293-1307`, `RaidPremade.luau:575-580` | high | After GS1, three live players vote. The note is `Ready 3/4.` Complete stays false. `status.full` stays true, so a new player cannot take the ghost's seat. Forcing `complete` with the ghost still listed hits `partyNow`: `GetPlayerByUserId` is nil, `partyNow` returns nil, and launch refuses "The host left the ready check." even when the host is still here (`RaidService.luau:1082-1111`). That refusal still does not depart the ghost |
| GS4 | The seat lasts until `listingSeconds`, measured from `createdAt` | `RaidPremade.luau:31`, `RaidPremade.luau:525`, `RaidPremade.luau:551-552`, `RaidService.luau:366-374` | medium | `createdAt + 1799`: the ghost is still seated and Ready still counts them. `createdAt + 1800`: `sweep` removes the listing. A tester who waits 1800 seconds from the disconnect, on an older listing, can see the seat vanish early or late. Score the clock from `createdAt` |
| GS5 | A disconnect before the hold still departs. That is the regression lock | `RaidService.luau:946-948`, `RaidService.luau:410-412` | low | The same member leaves before line 946 sets `hopHold`. `departUser` removes them, or closes the listing if they are the host. Scoring that as GS1 fails the case |
| GS6 | A hop that returns success keeps the seats. That is not this bug | `RaidService.luau:980-996` | low | `TeleportAsync` returns `"teleported"`. Seats stay, `hopping` is true, and `launched` stays unset. Departing those seats fails this plan. Leave that path to the success rule |

GS1 and GS2 are the open holes. GS3 is how Ready keeps counting them. GS5 and GS6 are the locks that must stay.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| GH-1 | Story listing, party 4, all four in `Players`, `hopHold` set, userId 42 is not the host | Remove 42 from `Players` before `stop`, then fail the hop with a nil reserve code | 42 is not in `members`. Today 42 remains. That fails GS1. The other three stay seated. `closed` is false |
| GH-2 | Same party. The host's userId leaves during the hold, then the teleport result is not `"teleported"` | Read `closed`, `hostUserId`, and `members` | The listing is closed, or the host id is gone. Today `closed` is false and the host id remains. That fails GS2 |
| GH-3 | The listing left by GH-1 | A live member calls `RaidService.ready` three times | The note reaches `Ready 3/4.` and `complete` stays false. A fourth live player cannot sit in 42's seat while `full` is true. A `Ready 4/4` that launches fails GS3 |
| GH-4 | GH-1's listing, `now` at `createdAt + 1799`, then `createdAt + 1800` | Call a path that `sweep`s, then Ready | At 1799 the ghost still counts. At 1800 the listing is gone. Ready says you are not seated |
| GH-5 | Same party, hold not set yet | Remove 42, then run `departUser` | 42 is absent. A host in that spot closes the listing. The seat must not survive |
| GH-6 | Hold set, all four still in `Players` | `TeleportAsync` returns `"teleported"` | All four members remain. `launched` is not set. A depart on this path fails GS6 |
| GH-7 | After GH-1, hold already cleared | A live member calls `RaidService.leave`. 42 does not | The live member is gone. 42 remains until GH-4's expiry, because nothing calls `depart` for 42. A leave that also drops 42 is a pass only if it targeted 42 |

## Flags

None. The hop does not spend Robux. A paid field is not a seat. No live number in `listingSeconds` changes.
