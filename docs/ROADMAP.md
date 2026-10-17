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
- #148 The Gate Plaza mouths have quiet lights. That is T-145.
- #150 Heartwood is an open Gate Plaza arch. That is T-153.
- #151 A receipt lifts the trade cap only when it was verified and granted. That is T-151.
- #152 Paid luck and paid chests stay off until launch. That is T-149.
- #153 Vip does not change luck, and Patron has a finite cap. That is T-152.
- #154 A receipt id is stored only after the grant sticks. That is T-150.
- #155 The action bar answers the d-pad, and the left bumper shifts to slots 5-8. That is T-146.
- #158 The sweep of `a631a64` through `9662cb7`. It filed T-156 and G-081. Docs only.
- #159 Hub odds keep the real Legendary, Mythic, and Secret chances. Legendary pity is 1000. That is T-157.
- #160 The client startup waits are bounded at 15 seconds. That is T-154.
- #161 Holding LB and a D-pad direction fires action-bar slots 5-8. That is T-156.
- #162 A refused roll does not break the streak. That is T-155 (`1441f41`).
- #163 A Heartwood clear pays Raid Marks once. That is T-132.
- #164 The board pass after T-155. It filed T-158. Docs only.
- #165 A wing change no longer holds the shared Echo stacks. That is T-099 (`fcae0ad`).
- #166 Glass Kestrel flashes on a dodge. That is T-158 (`1afc833`).
- #167 A dead boss with a living add does not clear the Story Echo seat. That is T-100 (`eacd7ce`).
- #168 Glass Kestrel flash QA, discovery notes, and 3D prompts. Docs only.
- #169 A queue click inside a reserved raid server launches in place. That is T-101 (`e9daa41`).
- #170 A follow-in with no teleport data joins the pull. That is T-102 (`be93c70`).
- #171 The board marks T-102 done. Docs only.

Pre-launch money hardening is done except the T-015 wiring. `Loops.PREMIUM_ENABLED` stays false. Nothing is for sale.

## Next up

The next week or two.

- Echo's next row is T-159. A second Glass Kestrel flash inside 0.12s stays visible, on `helper/kestrel-flash-hold-9721`. Brief: `docs/hooks/T-159.md`. T-158 is done in #166 (`1afc833`).
- T-015 is the remaining premium wiring. `grantPremium` treats only `receipts[id] == true` as a duplicate, so a T-151 receipt table at that id would be overwritten with `true` once the switch is on. Fix that when wiring T-015. The switch stays false.
- T-147 is the action-bar drag and phone 2×4 checklist. Kevin checks it in Studio. The d-pad landed in #155. The LB chord landed in #161.
- The bug sweeps. The filed crashes are done (T-094, T-128, T-129, T-154, T-155, T-156). T-099, T-100, T-101, and T-102 landed in #165, #167, #169, and #170. The dodge flash landed in #166. The open note on that flash is T-159.
- Ghost's next row from the older queue is T-105, the Codex seen flags. T-106 stays until that save exists and the server names the moment. T-109 waits on T-105.

## Later

Kevin asked to hold the lighting pass. The older queue stays behind the plaza and the banner.

- T-148 is world lighting for Haven and the crawl. Backlog. The plaza lights landed in #148. This row still waits until Kevin asks.
- T-099, T-100, T-101, and T-102 landed in #165, #167, #169, and #170. T-158 landed in #166. T-132 landed in #163. T-103 and T-104 are done: a miss clears the old roll card, and the RollNear header names its caller.
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
