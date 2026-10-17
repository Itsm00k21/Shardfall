# Shardfall roadmap

Oct 17, 2026. Short on purpose, so it reads on a phone. `Loops.PREMIUM_ENABLED` stays false. No Robux product is in this pass.

## Just landed today

- #130 The starter-goal list now hides with the rest of the HUD.
- #131 A party sent home from a raid saves first, so the lock does not kick them.
- #132 The starter-goal list paints the goals the server already decided.
- #133 A written plan so forge +10 takes about 200 clears. The live numbers are #134.
- #134 Rootvault pays 360 gold and Heartwood pays 480. Forge +1 is 150 and +2 is 300. Steps +8, +9, and +10 each spend one Gnarl's Seed.
- #135 The starter-goal list fits a phone and stays off the equip prompt.
- #136 Notes only: drop rates, the XP curve, and the launch checklist. No code.
- #137 The Gate Plaza design. Six dungeon arches in one crescent. The first build is #142.
- #138 Verdant playtest fixes. An empty gold banner hides. Hints and pickups fade. Gnarl is fairer at starter gear.
- #139 The playtest HUD. The goal tracker draws. Gold and Mastery sit in the corner. A new kit can include Shardjaw. The chrome is easier to read. The pull request text said T-138. The board row is T-139.
- #140 The gold banner stays inside the phone safe area and follows the text-size slider.
- #141 The Roll tab cracks the shard again. Odds, the pity bars, x10, and pet shards use the server result.
- #142 Gate Plaza, first build. Six arches stand in a crescent in front of spawn. Rootvault and Heartwood work. The other four say why they are closed.
- #143 Eight action slots on keys 1 through 8, saved per class. Schema is 24. On a phone they stack 2 by 4.
- #146 The gold banner has a lane clear of the portrait, the HP bar, and the top menu button. That is T-143.
- #147 Each Gate Plaza arch has its shape, its name, and its lock. That is T-144.

## Next up

The next week or two.

- T-145 adds the quiet lights on the Gate Plaza. T-141 in #142 is the blockout. T-144 in #147 dressed each arch.
- Pre-launch hardening. T-149 turns the paid switches off. T-150 grants a receipt before recording it. T-151 requires a verified granted receipt and a sane trade cap. T-152 takes paid luck off vip and caps Patron. Nothing is for sale.
- T-146 and T-147 polish the action bar. A controller d-pad and the bumpers still do nothing. Then a short playtest: drag a skill on, drag it off, and check the phone 2 by 4 grid.
- T-132 is one Raid Marks payout when a Heartwood clear pays. Raids stay paused, so this stays low on the list. A clear pays marks once.
- The bug sweeps. The last three passes filed their crashes, and those are done (T-094, T-128, T-129). Still open from those notes: a wing change that holds Echo stacks (T-099), a boss that dies while an add is still up (T-100), a queue click inside a raid server that can hop again (T-101), and a follow-in with no teleport data (T-102). Written test plans sit on G-069 through G-073, G-079, and G-080. The next sweep starts after `c576019`.

## Later

Kevin asked to hold the lighting pass. The older queue stays behind the plaza and the banner.

- T-148 is world lighting for Haven and the crawl. Backlog. It waits until the plaza lights exist.
- T-099 through T-102 are the open Echo and raid-hop bugs in Next up. T-103 and T-104 are done: a miss clears the old roll card, and the RollNear header names its caller.
- T-105 saves which Codex tips you have seen. T-106 paints the glows once the server says that moment is up.
- T-107 is done. Loading tips show, including during a hop.
- T-108 is decided. The Training Grove hands in one ribbon and 15 gold. The ribbon is a collectible and is not worn yet.
- T-109 saves the grove record after T-105. T-110 builds the grove dummy on the plaza after that.
- T-082 wires the raid contest once gear has a whole-number item level. The statue is one server-wide record.
- T-084 wires the weekly loot lock. A reclear pays marks, dust, and materials.
- T-036 wires the raid-leaver rules and four save fields: leaves today, the finder cooldown, and the rejoin window.
- T-038 stamps raid loot so a trade follows the raid rules. It waits on the real loot table.

## Launch path

The publish list is [docs/design/launch_checklist.md](design/launch_checklist.md), from #136.

Beta stays cosmetics and convenience. `Loops.PREMIUM_ENABLED` stays false. No Robux product ships in v0.1. Soft launch is a private clear, a two-account party, a solo Heartwood refusal, the paid-luck lock, honest odds, one friends evening, then public.
