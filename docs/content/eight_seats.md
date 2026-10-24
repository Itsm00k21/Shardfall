# Eight Seats

G-074. Party mix for achievement `eight_seats`. Any 8 players. This file does not edit `docs/content/achievements.md`.

Q-001, Kevin, 2026-10-17: any 8 players. Role mix does not matter. A party shorter than 8 does not count.

Choice: count bodies in the wing when it clears. A flex seat is one of those bodies. It is not a ninth player, and it does not have to be a Warden or a Tidecaller. The reward stays Seat Ribbon. Practice Grove still does not count.

## Rule

| check | counts |
|---|---|
| 8 players in the wing at the clear, any roles | Yes |
| 1 tank, 1 healer, 6 DPS | Yes. This mix is allowed. It is not required |
| 8 flex seats | Yes |
| 8 players and no tank | Yes |
| Listing size 8 with only 7 seated | No |
| A full listing of 7, 6, 5, or 4 | No |
| Someone left, and 7 remain at the clear | No |
| Practice Grove, even with 8 players | No |

`docs/content/achievements.md` still says 1 tank, 1 healer, and 6 DPS. That sentence is not the rule. This file does not change it.

## Seats

A premade listing is 4 to 8 seats (`RaidPremade.luau:29-30`). Each seat is tank, healer, DPS, or flex (`RaidPremade.luau:54-59`). A shorter listing can be full and still fail `eight_seats`.

| role | who can sit | where |
|---|---|---|
| flex | Any class, including no class. `roleOk` returns before it reads the class | `Raids.luau:61-63` |
| tank | `warden` only | `Raids.luau:67-69` |
| healer | `tidecaller` only | `Raids.luau:70-72` |
| dps | Any non-empty class id. The five beta classes are `warden`, `tidecaller`, `forgeborn`, `frostblade`, and `voidcaster` | `Raids.luau:73-75`, `Classes.luau:78`, `Classes.luau:143`, `Classes.luau:219`, `Classes.luau:273`, `Classes.luau:327` |

A tank or healer of the wrong class is refused with "That class does not fill that role. Pick Flex." (`Raids.luau:76`). An empty class on tank, healer, or DPS is "Pick a class at the Forge first." (`Raids.luau:64-66`). Flex never hits those lines.

## How flex counts inside the 8

Flex is a seat, not an extra player (`RaidPremade.luau:18-19`).

| player | seat they take | heads added |
|---|---|---|
| Tank, healer, or DPS | An open seat of that role, then an open flex seat | 1 |
| Flex | The first open seat, whatever its name | 1 |
| Eight flex players | Eight seats | 8 |
| A flex player on top of an already full 8 | No open seat | 0. The party is still 8 |

`pickSlot` is that order (`RaidPremade.luau:384-404`). After the sit, `eight_seats` does not read the seat name. Eight members count. Seven do not.

## Reward

| id | name | reward | visual note |
|---|---|---|---|
| `eight_seats` | Eight Seats | Seat Ribbon, once | A brown ribbon with eight dull stitches. No glow. |

The ribbon is bound. No stats, no luck, no drop chance, no Raid Marks.

## Flags

Eight Seats is not Four at the Door, which is a Rootvault party of 4. Seat Ribbon is not Heartwood Student. A flex seat is not a second character. No other game's raid composition is used.
