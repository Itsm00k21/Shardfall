# Audio cue list

G-047. Music moods and sound cues for the audio pass. Live ids stay in `Audio.luau` and `UiSfx.luau`. An empty id stays silent (`Audio.luau:87`, `Audio.luau:105-113`). Moods are suggested. Do not paste a new asset id into this file.

Style from `docs/design/shardfall_audio.md`: orchestral fantasy plus a glassy shard shimmer. Phone speakers must stay comfortable. Nothing here sells power.

## Live music

The bed plays at `HAVEN_VOLUME` 0.35. The Music slider multiplies it. Zone changes fade over 2 seconds (`Audio.luau:16-23`). SFX, UI, and Ambience share the SFX slider. Groups are Music, SFX, UI, and Ambience. There is no Voice group and no Master group. Master exists only as a `UiSfx` multiplier.

| zone | field | live id | when it plays |
|---|---|---|---|
| `haven` | `TRACKS.haven` | `rbxassetid://126726964341960` | `Audio.zoneFor` when the player is not in a crawl |
| `rootvault` | `Audio.Rootvault` | `rbxassetid://122681644942798` | an active `rootvault`, `rootvault_waves`, or `heartwood` run with no living boss |
| `gnarlBoss` | `Audio.GnarlBoss` | the same id as Rootvault | that run while `boss` is true |
| `verdant` | `TRACKS.verdant` | empty | never. The field is reserved and stays quiet |

`zoneFor` only returns `haven` or `rootvault` (`Audio.luau:61-66`). Far Glade, Saltglass, the trench, the marches, the ice, and the rift have no track field. Heartwood does not have its own bed. It uses Rootvault, and the Gnarl bed when a boss is up.

## Live UI clips

`UiSfx` is what the hub plays. Reduced motion does not mute these. A UI volume of 0 does (`UiSfx.luau:3-6`). Two built-in clips cover eight actions.

| action | live id | used for | suggested replacement |
|---|---|---|---|
| `open` | `rbxasset://sounds/switch.wav` | the hub opens | a soft latch |
| `close` | same switch | the hub closes | the latch, lower |
| `tab` | same switch | a tab change | a short wood tick |
| `click` | same switch | a list click | a soft click |
| `press` | `rbxasset://sounds/electronicpingshort.wav` | a button press | a muted tick |
| `confirm` | same ping | a Rare crack | a two-note chime |
| `toast` | same ping | a toast | a light bell |
| `stinger` | same ping | an Epic-or-better crack | the rising arpeggio |

`playUi` plays the action it is given (`MenuHub.luau:504-518`). Call sites ask for `press`, `toast`, `tab`, `stinger`, `confirm`, `click`, `open`, and `close`.

## Live combat and rarity cues

Every row in `Audio.CUES` is `""` (`Audio.luau:88-103`). `CombatHud.playCue` returns without a sound. `RollReel` asks `Audio.cue` for the landed rarity, then falls back to `electronicpingshort.wav` only for Rare, Epic, and Legendary (`RollReel.luau:809-820`).

| cue | who asks | suggested sound | live |
|---|---|---|---|
| `hit` | a damage or heal payload | a layered swish, a body, and a short tail. A crit adds a sharp ting | silent |
| `dodge` | a dodge that is not perfect | a dry sidestep | silent |
| `perfect` | a perfect dodge | the dodge, plus a bright tick | silent |
| `kill` | a kill | a low shard chime | silent |
| `red` | a red telegraph | a rising whoosh | silent |
| `yellow` | a yellow telegraph | one bell | silent |
| `purple` | a purple telegraph | a soft warble | silent |
| `blue` | a blue telegraph | a charging hum | silent |
| `common` | a landed Common | a soft click | silent |
| `uncommon` | a landed Uncommon | a light chime | silent |
| `rare` | a landed Rare | a bright two-note chime, then a shimmer | fallback ping |
| `epic` | a landed Epic | a rising arpeggio, then a bass hit | fallback ping |
| `legendary` | a landed Legendary | a choir swell, an impact, a short theme snippet | fallback ping |
| `mythic` | a landed Mythic | 0.3s of silence, then a full hit and a horn | silent. The fallback does not cover it |

Reel ticks should speed up and then slow with the spin, and the pitch should rise as the reel slows. That tick is not a `CUES` key yet. Suggested name, if a later row adds one: `reel_tick`. Do not add it to `Audio.luau` from this doc.

## Realm moods

No new music ids. These narrow the rows in `docs/design/shardfall_audio.md` to the six zones in `docs/content/zones.md`.

| place | suggested mood | live bed |
|---|---|---|
| Haven | warm strings, a plucked lute, soft bells. Market murmur at the armory stand. Forge clangs at the forge. Water at the falls | the Haven id |
| Far Glade | Verdant flutes and hand drums, slower, plus a soft wood creak | none. `verdant` is empty |
| Saltglass Strand | harp, tide bells, distant gulls, a light choir pad | none |
| Pearl Trench | low harp, choir pads, a slow pressure drone. No gulls | none |
| Slag Marches | distant anvils, low brass, a slow heat shimmer | none |
| Hoarfrost Expanse | celesta and sparse piano, far apart, plus wind | none |
| Rift Margin | reversed pads, a detuned choir, one bell that never finishes | none |
| Rootvault | a tense ostinato that rises per room | the shared id |
| Grandmother Gnarl | the same id today. Suggested: its own theme, one added layer per phase | shared with Rootvault |
| A raid clear | a 3–5s victory stinger. Suggested, not a bed | none |

Beta scope in the design doc is the main theme, Haven, Verdant, Rootvault, a Gnarl theme with phase layers, the rarity ladder, class palettes, the four telegraphs, and the sliders. Haven is the only one of those with its own id. Rootvault and Gnarl still share one.

## Class palettes

Suggested, from the design doc. One identity each. They are not tracks.

| class | palette |
|---|---|
| Warden | wood and a soft thud |
| Tidecaller | water and small chimes |
| Forgeborn | an anvil hit and a low fire |
| Frostblade | ice and a thin slice |
| Voidcaster | a hum and a short reverse |

## Pet calls

The design doc asks for cute species vocals. Kevin rejected cute pets on 2026-10-17. Suggested: one short creature call per species, and a quieter repeat when the pet is addressed. No squeak, no baby voice. No call is wired in `Audio.CUES`.

## Fill order

Suggested, so the blanks match the beta list:

| step | fill | leave alone |
|---|---|---|
| 1 | a Gnarl id that is not the Rootvault id | the Haven id |
| 2 | `TRACKS.verdant` | the five later realms |
| 3 | the six rarity cues and `red`, `yellow`, `purple`, `blue` | a new cue name |
| 4 | eight distinct UI clips | the slider math |

The design also names a "reduce loud sounds" toggle and captions for important cues. Neither lives on `Audio`. Captions for the four telegraph colors would help the first three lessons, which already hide the word and keep the color.

Flags: no other game's theme, stinger, or creature call. Creator Store audio has to be licensed for Roblox. A temp track is not a final id.
