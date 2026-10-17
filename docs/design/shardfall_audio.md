# Shardfall Sound & Music v1 (draft, Oct 16 2026)

## Pillars
1. Sound = feedback: every action, hit, roll, and drop has a sound that tells you what happened without looking.
2. Each realm and class has a sonic identity (instruments, textures).
3. Rarity has a sound ladder players learn to crave.
4. Mobile-friendly: works on phone speakers, nothing painful; full volume sliders.

## Music direction
- Style: orchestral-fantasy blended with light electronic shimmer (the "shard" sound = glassy bells/synth pads).
- **Main theme** motif (4-6 notes) reused everywhere: menu, Haven, boss victories, the Lumen Heart.
| Area | Instruments / mood |
|---|---|
| Haven (hub) | warm strings, plucked lute, soft bells; day/night versions; busy market ambience |
| Verdant Wilds | flutes, hand drums, birdsong layers |
| Sunken Reach | harp, choir pads, underwater filters |
| Emberforge | taiko/anvil percussion, brass, low choir |
| Frostveil | celesta, glass chimes, sparse piano, wind |
| Void Rift | reversed textures, deep synth drones, detuned choir |
| Rootvault / dungeons | tense ostinato, intensity rises per room |
| Bosses | unique theme per boss; music shifts each phase (adds layers, tempo up) |
| Raids | epic choir + main theme variation; final boss phase uses the full main theme |
- **Adaptive music**: layers fade in for combat, out when calm; boss phases add stems; low HP adds a heartbeat filter.
- Victory stingers (3-5 s) after clears; level-up jingle.

## Rarity sound ladder (rolls, chests, drops)
| Rarity | Sound |
|---|---|
| Common | soft click/pop |
| Uncommon | light chime |
| Rare | bright 2-note chime + shimmer |
| Epic | rising arpeggio + bass hit |
| Legendary | choir swell + big impact + main theme snippet |
| Mythic | silence 0.3 s (the fake stall), then full orchestral hit + server-wide horn |
Reel tick sounds speed up and slow down with the reel; the pitch rises as it slows (tension).

## Combat sound
- Layered impacts: swish + body + tail; heavier hits add bass. Crits get a sharp "ting".
- Class palettes: Warden wood/thud, Tidecaller water/chimes, Forgeborn anvil/fire, Frostblade ice/slice, Voidcaster hum/reverse.
- **Audio telegraphs** match the color language: red (dodge) = rising whoosh, yellow (stack) = bell, purple (spread) = warble, blue (interrupt) = charging hum. Helps readability and accessibility.
- Enemy voice barks for big attacks; boss phase roars.

## UI & world
- Satisfying UI clicks, inventory sorting sounds, coin pickups that combine when many drop.
- Pets: each species has cute vocalizations; happy sounds when petted.
- Ambience per district in Haven (forge clangs near the Forge, crowd murmur at the Roll Shrine, water near waterfalls).

## Settings & accessibility
Master/Music/SFX/Ambience/UI/Voice sliders; "reduce loud sounds" toggle; captions for important audio cues.

## Sourcing (efficient)
- Roblox Creator Store audio (free licensed library) for SFX and ambience to start.
- Music: commission or license a small set (main theme + Haven + Verdant + Rootvault + 1 boss) for the beta; expand per realm. Optionally AI-assisted drafts for temp tracks, replaced by final music later.
- Audio upload limits & licensing: only use audio we own or that Roblox licenses for use.

## Tech
SoundService with SoundGroups (Music/SFX/UI/Ambience), pooled Sound instances, 3D positional sounds for combat, client-side playback triggered by server events; cap simultaneous sounds on mobile (~24).

## Beta scope
Main theme, Haven, Verdant, Rootvault, Gnarl boss theme with phase layers, full rarity ladder, class combat palettes, audio telegraphs, sliders.
