# Material flavor

G-025. Flavor lines for every material in `Materials.luau`, plus 10 suggested new ones. The live names stay. This file does not rename ids.

Grade tints match `Materials.luau:231-236`: common reads Common, rare reads Rare, boss reads Legendary, scroll reads Epic. Stack caps are live (`Materials.luau:50-210`). Colors are the live RGB.

Healing Tonic is a consumable, not a row in `Materials.DEFS`. It is listed so the file covers the module.

## Live materials

| id | live name | realm | grade | stack | rgb | flavor | visual note |
|---|---|---|---|---|---|---|---|
| `wood` | Verdant Wood | Verdant Wilds | common | 999 | 120, 150, 70 | A cut log, still green at the core. | Short log, olive cut face, moss flecks. No glow. |
| `vine` | Living Vine | Verdant Wilds | common | 999 | 72, 160, 90 | A cut vine that keeps a slow curl. | Coiled green vine, one pale tip. No glow. |
| `spore` | Spore Cap | Verdant Wilds | common | 999 | 156, 96, 210 | A violet cap that dusts the hands. | Small round cap, violet top, gray stem. No glow. |
| `bark` | Ironbark | Verdant Wilds | common | 999 | 110, 84, 58 | A dark strip of bark, heavy for its size. | Flat brown strip, iron-dark ridges. No glow. |
| `heartwood` | Heartwood | Verdant Wilds | rare | 999 | 196, 120, 64 | The warm core of an old root. | Short amber core, darker rim. Soft warm glow. |
| `verdant_bark` | Verdant Bark | Verdant Wilds | common | 999 | 86, 140, 72 | Fresh bark, greener than Ironbark. | Curved green bark, pale inner face. No glow. |
| `gnarl_seed` | Gnarl's Seed | Verdant Wilds | boss | 99 | 48, 110, 56 | A hard seed from the raid's heart. | Fist-sized seed, deep green, one gold seam. Steady seam glow. |
| `scroll_thornbound` | Thornbound Scroll | Verdant Wilds | scroll | 1 | 220, 186, 96 | A gold scroll bound in thorn cord. | Rolled gold page, brown thorn cord. Soft gold edge. |
| `coral_shard` | Coral Shard | Sunken Reach | common | 999 | 80, 170, 186 | A teal chip broken off a reef. | Small jagged chip, teal and cream. No glow. |
| `black_pearl` | Black Pearl | Sunken Reach | rare | 999 | 48, 90, 120 | A dark pearl with a blue sheen. | Round pearl, near-black, a blue highlight. Soft sheen. |
| `leviathan_scale` | Leviathan Crown-Scale | Sunken Reach | boss | 99 | 36, 70, 130 | One wide scale from a tide crown. | Wide scale, deep blue, a pale gold rim. Steady rim glow. |
| `cinder_ore` | Cinder Ore | Emberforge | common | 999 | 196, 96, 48 | Orange rock that stays warm. | Chunk of orange-gray ore, dull coal crust. No glow. |
| `molten_core` | Molten Core | Emberforge | rare | 999 | 230, 120, 40 | A cooled orb with an orange heart. | Round orb, dark crust, orange center. Soft center glow. |
| `tyrant_heart` | Tyrant's Ember Heart | Emberforge | boss | 99 | 180, 40, 30 | A dark red stone that still ticks with heat. | Cut stone, dark red, not an organ. Bright heat cracks. |
| `frost_pelt` | Frost Pelt | Frostveil | common | 999 | 186, 220, 236 | A pale hide stiff with frost. | Folded white-blue hide, short nap. No glow. |
| `everfrost_gem` | Everfrost Gem | Frostveil | rare | 999 | 120, 180, 230 | A blue gem that does not melt. | Faceted blue gem, a white core. Soft core glow. |
| `matriarch_fang` | Matriarch's Frozen Fang | Frostveil | boss | 99 | 90, 140, 210 | A clear fang of ice, not bone. | Long ice fang, blue-white, a cold edge. Steady edge glow. |
| `void_dust` | Void Dust | Void Rift | common | 999 | 140, 90, 200 | Violet dust that hides the palm. | A pinch of violet dust in a gray scrap. No glow. |
| `rift_eye` | Rift Eye | Void Rift | rare | 999 | 170, 80, 220 | A violet stone with a slit of light. | Oval stone, not an eyeball. One violet slit. Soft slit glow. |
| `hollow_core` | Sovereign's Hollow Core | Void Rift | boss | 99 | 80, 40, 140 | A dark core, empty, with a prism crack. | Hollow black sphere, one prism crack. Bright crack. |

## Healing Tonic

Not in `Materials.ORDER`. Live heal is 40% of max HP. Cap is 20 (`Materials.luau:213-217`).

| id | live name | flavor | visual note |
|---|---|---|---|
| `healing_tonic` | Healing Tonic | A small drink that closes a scrape. | Short green vial, cork stopper, pale sap inside. No glow. |

## Suggested new materials

Not in `Materials.ORDER`. None of these is `primary`, so kill drops and salvage stay on the live rows. The four scrolls fill realms that have no scroll today (`Drops.luau:61-65` passes nil outside Verdant). Haven is not in `Materials.REALMS` (`Materials.luau:25`). Haven Ash waits for a realm row before it can drop.

| id | name | realm | grade | stack | suggested rgb | flavor | visual note |
|---|---|---|---|---|---|---|---|
| `tidebound_scroll` | Tidebound Scroll | Sunken Reach | scroll | 1 | 80, 170, 186 | A teal scroll tied with wet cord. | Rolled teal page, dark cord. Soft teal edge. |
| `kilnbound_scroll` | Kilnbound Scroll | Emberforge | scroll | 1 | 196, 96, 48 | An orange scroll sealed with soot wax. | Rolled orange page, black wax. Soft wax glow. |
| `veilbound_scroll` | Veilbound Scroll | Frostveil | scroll | 1 | 186, 220, 236 | A pale scroll that stays cold. | Rolled white-blue page, ice thread. Soft cold edge. |
| `riftbound_scroll` | Riftbound Scroll | Void Rift | scroll | 1 | 170, 80, 220 | A violet scroll with a dark slit. | Rolled violet page, one dark slit. Soft slit glow. |
| `sap_resin` | Sap Resin | Verdant Wilds | common | 999 | 196, 150, 48 | A sticky amber lump from a cut root. | Small amber lump, dull crust. No glow. |
| `brine_salt` | Brine Salt | Sunken Reach | common | 999 | 200, 210, 200 | Coarse salt from a dried tide pool. | A pinch of pale crystals. No glow. |
| `slag_glass` | Slag Glass | Emberforge | rare | 999 | 80, 70, 70 | A black glass shard with an orange fleck. | Jagged black shard, one orange fleck. Soft fleck. Not the rare primary. |
| `rime_thread` | Rime Thread | Frostveil | common | 999 | 220, 230, 240 | A white thread that snaps when it warms. | A coil of white thread. No glow. |
| `prism_grit` | Prism Grit | Void Rift | common | 999 | 180, 160, 220 | Fine grit that flashes one color, then stops. | A pinch of pale violet grit. One dull glint. |
| `haven_ash` | Haven Ash | Haven | common | 999 | 90, 90, 96 | Cool ash from the plaza braziers. | Fine gray ash in a square of cloth. No glow. |

Flags: Verdant Bark is not Ironbark. Heartwood the material is not the raid. Gnarl's Seed is not Grandmother Gnarl. Leviathan Crown-Scale is not Leviathan Mallet. Tyrant's Ember Heart is a stone, not Kiln Tyrant and not an organ. Matriarch's Frozen Fang is ice, not Galecrown the owl. Rift Eye is a stone, not a creature. Sovereign's Hollow Core is not Geode Sovereign and not Void Palanquin. Tidebound Scroll is not Thornbound Scroll. Sap Resin is not Sap Wisp. Brine Salt is not Brine Skiff. Slag Glass is not Slagplate. Rime Thread is not Rime Ram. Prism Grit is not Prism Bow. No live number changes.
