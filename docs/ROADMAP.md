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
- #172 The board marks T-158 done and files T-159. Docs only.
- #173 Codex seen flags save on schema 25. That is T-105 (`776db3c`).
- #174 The Training Grove record saves on schema 26. That is T-109 (`05a4870`).
- #175 A second Glass Kestrel flash inside 0.12s stays visible. That is T-159 (`13d317b`).
- #176 The Training Grove dummy stands on the plaza. That is T-110 (`24e46fb`).
- #177 The board marks T-159 done and files T-160. Docs only.
- #178 A late hero avatar is destroyed, and an R6 rig still builds. That is T-160 (`e510db4`).
- #179 Codex cues and the dodge pulse paint from the server-named moment. The hint stays Dodge!. That is T-106 (`cc789b8`).
- #180 World prompts, icons, rarity, VFX, and audio notes. Docs only (`6e2d9e5`). G-043 through G-047 are done.
- #181 The action-bar drag and phone 2×4 checklist is on the soft-launch list. That is T-147 (`441a1b6`). The same pass files the MenuHub hotfix row and the deferred door-nameplate restyle.
- #182 The menu loads again. `MenuHub.start` stays under the 200-local cap (`f95c210`).
- #183 The board records that hotfix on T-161. Docs only (`9069ddc`).
- #184 The board marks T-160 done and files Echo's T-163. Docs only (`72808fc`).
- #185 The board files the hub rarity color row. Docs only (`8eab46d`).
- #186 The board locks the rarity palette row and marks G-043 through G-047 done in #180 (`6e2d9e5`). Docs only (`c6a0602`).
- #187 Mythic is red `#E6404E` and Secret stays white. Only Secret inventory strokes keep the rainbow. That is T-164 (`90a4818`).
- #189 The Story Echo chip stays off the HP bar on a phone. That is T-163 (`7dd700e`).
- #190 The on-screen Dodge button flashes Glass Kestrel. That is T-165 (`52a5717`).
- #191 A controller dodges on ButtonY. ButtonX stays heavy. That is T-166 (`961bf5e`).

Pre-launch money hardening is done except the T-015 wiring. `Loops.PREMIUM_ENABLED` stays false. Nothing is for sale. Schema is 26.

## Next up

The next week or two.

- Echo's next row is T-167. The bag follows the text-size slider, on `helper/bag-text-scale-9721`. Brief: `docs/hooks/T-167.md`. T-163 is done in #189 (`7dd700e`).
- T-165 landed in #190 (`52a5717`). The on-screen Dodge button flashes Glass Kestrel. T-166 landed in #191 (`961bf5e`). ButtonY dodges and ButtonX stays heavy.
- T-164 landed in #187 (`90a4818`). Mythic is red `#E6404E` and Secret is white. Only Secret inventory strokes keep the rainbow.
- T-015 is the remaining premium wiring. `grantPremium` treats only `receipts[id] == true` as a duplicate, so a T-151 receipt table at that id would be overwritten with `true` once the switch is on. Fix that when wiring T-015. The switch stays false.
- T-148 is world lighting, and T-162 is the dungeon door nameplate restyle. Both wait. UI fixes and gameplay come first.
- The bug sweeps. The filed crashes are done (T-094, T-128, T-129, T-154, T-155, T-156). T-099, T-100, T-101, and T-102 landed in #165, #167, #169, and #170. The dodge flash landed in #166 and #175. The hero viewport landed in #178. The menu load landed in #182.

## Later

Kevin asked to hold the lighting pass. The older queue stays behind the plaza and the banner.

- T-148 is world lighting for Haven and the crawl. Backlog. The plaza lights landed in #148. This row still waits until Kevin asks.
- T-099, T-100, T-101, and T-102 landed in #165, #167, #169, and #170. T-158 landed in #166. T-159 landed in #175. T-132 landed in #163. T-103 and T-104 are done: a miss clears the old roll card, and the RollNear header names its caller.
- T-105 landed in #173. Codex seen flags save on schema 25. T-106 landed in #179. The server names the moment, and the hint stays Dodge!.
- T-107 is done. Loading tips show, including during a hop.
- T-108 is decided. The Training Grove hands in one ribbon and 15 gold. The ribbon is a collectible and is not worn yet.
- T-109 landed in #174. The grove record saves on schema 26. T-110 landed in #176. The dummy stands on the plaza.
- T-160 landed in #178. T-147 landed in #181. T-161 landed in #182. T-163 landed in #189 (`7dd700e`). T-164 landed in #187 (`90a4818`). T-165 landed in #190 (`52a5717`). T-166 landed in #191 (`961bf5e`). T-162, the door nameplates, stays with the lighting pass.
- T-082 wires the raid contest once gear has a whole-number item level. The statue is one server-wide record.
- T-084 wires the weekly loot lock. A reclear pays marks, dust, and materials.
- T-036 wires the raid-leaver rules and four save fields: leaves today, the finder cooldown, and the rejoin window.
- T-038 stamps raid loot so a trade follows the raid rules. It waits on the real loot table.

## Launch path

The publish list is [docs/design/launch_checklist.md](design/launch_checklist.md), from #136.

Beta stays cosmetics and convenience. `Loops.PREMIUM_ENABLED` stays false. No Robux product ships in v0.1. Soft launch is a private clear, a two-account party, a solo Heartwood refusal, the paid-luck lock, honest odds, one friends evening, then public.
