# Playtest script

G-035. One 30-minute session, a watch list, and a feedback form. This file does not change code.

Choice: one fresh account, one device, Normal Rootvault. The clock follows the live rooms in `Dungeons.luau`, not the unused Heartwood-at-20 text. Suggested XP from G-030 is a pace note. A pass or fail uses the live column. Skip and a finished cold open both count. The first pet stays unminted.

Do not spend Robux. `Loops.PREMIUM_ENABLED` stays false. If a buy button appears, stop and write the label.

## Setup

| check | live | cite |
|---|---|---|
| Kit on skip or finish | 250 gold, 40 Shard Keys, 1 Rare chest, 1 Uncommon chest, 3 Healing Tonics | `Onboarding.luau:52-63` |
| Shard Tokens | 25 | `Schema.luau:37` |
| Classes | Warden, Tidecaller, Forgeborn, Frostblade, Voidcaster | `Classes.luau:79`, `Classes.luau:144`, `Classes.luau:220`, `Classes.luau:274`, `Classes.luau:328` |
| Rootvault Normal | account level 1 | `Rootvault.luau:14` |
| Rooms, in order | Choked Thicket, Spore Canopy, Brute Den, Gnarl's Heart | `Dungeons.luau:297-315` |
| First forge from +0 | 150 gold | `Economy.luau:28-29` |
| Manual clear, before Gold Find | 360 gold, 3 tokens, 40 account XP | `Dungeons.luau:318-322` |
| First Rootvault clear today | that 40 XP becomes 120, plus 1 Rare chest | `DungeonService.luau:1323-1329` |
| Guild Hall | "The Guild Hall is coming soon." | `Haven.luau:134-141` |
| Market district | "The daily shop is not open yet." | `Haven.luau:125-131` |

Write the build you joined, the device, and the viewport. On a phone, also note 390 wide and 844 wide if you can rotate.

## Steps

| min | do this | pass | write it down if |
|---|---|---|---|
| 0 | Join. Read the cold open, or skip. | Haven, with the kit row above | The kit differs |
| 1 | Pick any of the five pedestals. | One class is set. The other four were visible | A pedestal is missing or blank |
| 2–3 | Swing saplings until the lesson advances. | The third hit is the lesson | You are stuck with no hint |
| 4–5 | Step out of a red mark. | The dodge lesson advances | The mark gives no time to move |
| 6 | Look at both doors, then take one. | Both doors are safe choices | One door is a trap with no tell |
| 7–8 | Open the Uncommon chest, then the Rare chest. | Both open into the bag | A chest spends keys or Robux |
| 9 | Claim the login chest once. Claim it again. | First claim pays. Second says "Daily login is already claimed." Streak shows 1 | The second claim pays again |
| 10–12 | At the Forge, upgrade one piece from +0. | Gold falls by 150 and stays at 0 or more | The price is not 150, or gold goes negative |
| 13 | Open Pets. | An empty slot is fine | A pet was minted for you |
| 14–16 | On the Roll tab, crack 3 Shard Tokens. Read the Odds list, then open the odds info. | Tokens go from 25 to 22. Each crack gives an item. Epic on both lines is about 0.4, not 4.0 | A refusal paints a Miss streak. Epic prints as 4.0. Legendary, Mythic, or Secret prints as 0.0 |
| 17 | Open Pass, Market, Raids, and Settings. | Premium says the track is not for sale. No price button takes Robux | A product id prompts a purchase |
| 18 | Read the Rootvault gate and enter Normal. | Normal starts at level 1 | Hard or Nightmare starts instead |
| 19–27 | Clear the four rooms. Take any door you understand. | You can name the room you are in | A door is blank, or you cannot leave a room |
| 28 | Beat Grandmother Gnarl. | The clear pays. First boss today can add an Epic chest. First boss this week can also add a Legendary chest | The clear pays nothing, and this was not Practice |
| 29 | Read the reward line. | 360 gold and 3 tokens, or you wrote the line you saw. Account XP 120 if this was the day's first clear | Gold and tokens are both missing |
| 30 | Open the loop list. Walk to the Guild Hall and the Market district. | Daily boss reads resting, because Gnarl already fell. Both districts show the soon lines | The daily button starts a second paid Gnarl, or a district is an empty error |

Practice Grove is a separate door. If you enter it, loot should be "Practice Grove. No loot." That is a pass for Practice, and it does not replace the Normal clear.

Heartwood is out of this half hour. Level 15 and a party of 4 are the later bar.

## What to watch

| watch | fail looks like | cite |
|---|---|---|
| Red marks | Damage lands with no time to step out | `Rootvault.luau:21` |
| Gnarl's rest | A new red square opens on top of the last slam | `Dungeons.luau:263-266` |
| Refused roll | Tokens stay, and the streak still breaks or the card says Miss | `MenuHub.luau:3205-3206` |
| Odds honesty | The Odds list or the info line prints Legendary, Mythic, or Secret as 0.0, or Epic as 4.0 | `RollBoard.luau:112-120`, `MenuHub.luau:2811-2823`, `MenuHub.luau:2656-2662` |
| Login once | A second claim on the same day pays another chest | `ChestConfig.luau:435-436` |
| Daily Gnarl | After this clear, Start Daily Boss still starts a fight | `DungeonService.luau:2498-2499` |
| Phone top | The gold banner covers the portrait or the HP bar | banner lane, viewports 390×844 and 844×390 |
| Robux | Any prompt. Stop the session | `Loops.luau:21` |
| Pet | A cute starter pet appears on its own | Shardjaw hold is still on |

The Echo chip and the raid Leave button have their own QA rows. If either is off the screen, write the viewport and keep going.

## Feedback form

Scores are 1 (stuck or unhappy) to 5 (clear and fun). One session, one form.

| id | prompt | answer |
|---|---|---|
| F1 | Device and viewport | |
| F2 | Skip or full cold open | |
| F3 | Class picked | |
| F4 | Fun, 1–5 | |
| F5 | You knew the next step, 1–5 | |
| F6 | Red marks felt fair, 1–5 | |
| F7 | Where you got stuck, one sentence | |
| F8 | The odds line for Epic, copied from the screen | |
| F9 | A refused action, and the exact sentence | |
| F10 | Did anything ask for Robux | |
| F11 | One thing to keep | |
| F12 | One thing to change | |

## Flags

None. Room names and class names are the live ones.
