# UI copy

G-026. Button labels, empty states, errors, and confirms for Bag, Pets, Roll, Raids, Market, Pass, and Settings.

Read from `MenuHub.luau` on the current tip. Live strings stay until a code row picks these up. Proposed text is the pass. Hero is out of this pass.

Choice: a button that does nothing should not promise a screen. Where the click is empty, the proposed label matches the click, and a later label waits on the real panel.

## Bag

Filters and salvage live in `MenuHub.luau:2066-2118`. An empty card list uses one sentence even when a filter hid the gear.

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Bag | `ClientChrome.luau:53` | Bag |
| Title when sets are pushed | Bag  /  Sets | `MenuHub.luau:1161` | Bag |
| Filter | Rarity  … | `MenuHub.luau:2066` | Rarity |
| Filter | Type  … | `MenuHub.luau:2070` | Type |
| Filter | New, or New  On | `MenuHub.luau:2074` | New only |
| Filter | Sort  … | `MenuHub.luau:2078` | Sort |
| Row | Sets | `MenuHub.luau:2082` | Relic sets |
| Row | Open full bag | `MenuHub.luau:2085` | Open bag |
| Row | Salvage  {rarity} | `MenuHub.luau:2107` | Salvage {rarity} |
| Confirm | Confirm salvage | `MenuHub.luau:2090` | Salvage |
| Confirm body | Salvage every {rarity} weapon and armor piece that is not locked or equipped? | `BagBoard.luau:184-188` | Keep this sentence. |
| Cancel | Cancel | `MenuHub.luau:2098` | Cancel |
| Empty, no items | The bag is empty. | `MenuHub.luau:2113` | The bag is empty. |
| Empty, filters hid items | The bag is empty. | `MenuHub.luau:2112` | Nothing matches these filters. |
| Empty button | Open full bag | `MenuHub.luau:2113` | Open bag |
| Card | Lock, or Locked | `MenuHub.luau:1581` | Lock, or Locked |
| Compare, nothing worn | Nothing equipped to compare. | `MenuHub.luau:1370` | Nothing in this slot yet. |
| Sets line | Relic sets equip from the bag. Pieces stay raid drops. | `MenuHub.luau:2126` | Keep this sentence. |

## Pets

The hatch click does nothing (`MenuHub.luau:2184`). Eggs cost 50 gold (`Pets.luau:13`). The hub shows three slots and one equipped pet (`MenuHub.luau:2140-2166`).

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Pets | `ClientChrome.luau:54` | Pets |
| Count | Equipped  {n}/3 | `MenuHub.luau:2162` | Out  {n}/3 |
| Slot | Slot {n}  Empty | `MenuHub.luau:2165-2166` | Slot {n}  Empty |
| Empty | No companions yet. | `MenuHub.luau:2184` | No companion yet. |
| Empty button, click is empty | Open pets | `MenuHub.luau:2184` | Hide the button until it opens the hatch. |
| Later button | — | — | Hatch |
| Error, short gold | An egg costs 50 gold. | `PetService.luau:39` | An egg costs 50 gold. |
| Error, favorite fuse | A favorite cannot be fused. | `Pets.luau:166` | A favorite cannot be fused. |
| Error, mixed species | Fusion keeps the same species. | `Pets.luau:169` | Fusion keeps the same species. |
| Error, bond cap | Already at five Bond stars. | `Pets.luau:172` | Already at five Bond stars. |

## Roll

A failed invoke, a result with no item, and a short wallet all paint the reel as Miss (`MenuHub.luau:2759-2786`). The server already returns a reason (`RollService.luau:219-221`, `Currencies.luau:52-59`). Show that reason. A successful crack mints an item (`RollService.luau:239-244`). It does not return a landed miss. G-072 owns the test plan.

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Roll | `ClientChrome.luau:55` | Roll |
| Button | Roll | `MenuHub.luau:651` | Roll |
| Toggle | Auto, or Auto On | `MenuHub.luau:2232` | Auto-roll |
| Toggle | Stop  Off, or Stop at  {rarity} | `MenuHub.luau:2244-2245` | Stop at {rarity} |
| History empty | No rolls yet. | `MenuHub.luau:2511` | No rolls yet. |
| Odds empty | Odds are unavailable. | `MenuHub.luau:2481` | Odds are unavailable. |
| Pity, no meter | Legendary pity | `MenuHub.luau:2472` | Legendary pity |
| Streak, broke | Streak broke | `UiRouter.luau:467` | Streak broke |
| Near miss | Close call | `UiRouter.luau:308` | Close call |
| Reveal equip | ▲ Equip | `MenuHub.luau:798` | Equip |
| New item | NEW! | `MenuHub.luau:754` | New |
| Reel on failure | Miss | `MenuHub.luau:2786` | Use the server reason below. |
| Short Shard Token | You need a Shard Token to crack a shard. | `Currencies.luau:52` | You need a Shard Token. |
| Short Prism Token | You need a Prism Token. Prism Tokens are bought with Robux. | `Currencies.luau:59` | You need a Prism Token. |
| Unknown pool | Unknown shard. | `RollService.luau:162` | That shard is not open. |
| Locked pool | Reach Ascension {n} to roll {name}. | `RollService.luau:203` | Keep this sentence. |
| Full bag | Inventory is full. | `RollService.luau:225` | The bag is full. |
| Empty pool | That shard has nothing to roll. | `RollService.luau:236` | That shard is empty. |
| Profile | Profile is still loading. | `RollService.luau:180` | Still loading. |
| Cooldown | Roll cooling down. | `RollService.luau:197` | Wait a moment. |
| Throw, no reason | Miss | `MenuHub.luau:2786` | The roll did not land. Try again. |

## Raids

The empty button does not open a finder. It prints the mark count (`MenuHub.luau:3084-3086`).

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Raids | `ClientChrome.luau:56` | Raids |
| Empty | No raid is forming. | `MenuHub.luau:3084` | No wing is forming. |
| Button, current click | Open finder | `MenuHub.luau:3084` | Show marks |
| Marks line | Marks  {n} | `MenuHub.luau:3085` | Raid Marks  {n} |
| Later button | — | — | Open finder |
| Shop miss | The vendor does not sell that. | `Raids.luau:147` | The vendor does not sell that. |
| Short marks | Not enough Raid Marks. | `Raids.luau:150` | Not enough Raid Marks. |
| Bought | Bought. | `Raids.luau:159` | Bought. |

## Market

Open board does call the market hook (`MenuHub.luau:3087-3088`).

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Market | `ClientChrome.luau:57` | Market |
| Empty | Nothing is listed yet. | `MenuHub.luau:3087` | Nothing is listed. |
| Button | Open board | `MenuHub.luau:3087` | Open board |
| Confirm list | — | — | List this for {price}? The fee is not returned. |
| Confirm buy | — | — | Buy this for {price}? |
| Confirm cancel | — | — | Cancel the listing? The fee stays spent. |
| Short gold for the fee | — | — | Not enough gold for the fee. |

The fee line matches the live rule: 5% is sunk on post, and cancel does not return it (`MarketBoard.luau:6-7`, `MarketBoard.luau:22`).

## Pass

The tier is the snapshot of Pass XP (`Schema.luau:1184`). The button does nothing (`MenuHub.luau:3091-3096`). Premium sale is off (`Loops.luau:21`).

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Shard Pass | `ClientChrome.luau:58` | Shard Pass |
| Empty, tier 0 | The Shard Pass is quiet. Tier 0. | `MenuHub.luau:3094` | Tier 0. Finish a daily to start. |
| Empty, tier above 0 | The Shard Pass is quiet. Tier {n}. | `MenuHub.luau:3094` | Tier {n}. |
| Button, click is empty | Check daily | `MenuHub.luau:3095` | Hide the button until it opens the pass. |
| Later button | — | — | View pass |
| Claim, nothing ready | No free tier is ready. | `LoopService.luau:166` | No reward is ready. |
| Premium off | The premium track is not for sale yet. | `Loops.luau:350` | The premium track is not for sale yet. |
| Skip, short gems | Not enough Gems. | `Loops.luau:490` | Not enough Gems. |
| Overflow, nothing | No key cache is ready. | `LoopService.luau:361` | No key cache is ready. |

## Settings

Most rows already say what they cycle. Change the vague ones. Debug rows stay Studio-only (`MenuHub.luau:3324`).

| surface | live | cite | proposed |
|---|---|---|---|
| Tab | Settings | `ClientChrome.luau:59` | Settings |
| Junk rule | Junk  {ask, keep, salvage} | `MenuHub.luau:3157` | Low rolls  {Ask, Keep, Salvage} |
| Junk floor | Below  {rarity} | `MenuHub.luau:3167` | Salvage below  {rarity} |
| Hotkey | Hotkey {field}  {key} | `MenuHub.luau:3248` | {Tab name}  {key} |
| While capturing | press a key | `MenuHub.luau:3250` | Press a key |
| Trades | Trades  {everyone, friends, off} | `MenuHub.luau:3278` | Trades  {Everyone, Friends, Off} |
| Chat | Chat filter  {default, strict, off} | `MenuHub.luau:3291` | Chat  {Default, Strict, Off} |
| Hold | Hold instead of tap | `MenuHub.luau:3318` | Hold to press |

Keep, already clear: Graphics, Shadows, FPS cap, Roll animation, Camera shake, Screen flash, Master, Music, SFX, UI audio, Hide HUD, Damage numbers, Nameplates, Raid invites, Colorblind pips, Text size.

Flags: none of this copy sells power. Prism Token text stays "bought with Robux" only on the currency line that already says it. No other game's UI names.
