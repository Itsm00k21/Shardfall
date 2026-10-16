# Verdant Relic Sets

Heartwood Hard drops one 4-piece Verdant Relic Set for each of the five classes. The pieces are bound and never tradeable. Each set has a 2-piece bonus and a 4-piece bonus. Those bonuses change how you play. They do not add flat damage, health, defense, crit, or attack speed.

The rules live in `src/ReplicatedStorage/Shared/RelicSets.luau`. This module does not grant loot, roll a drop, edit a profile, or spend Robux. T-010 wires the drops, the Vault, and the trade refusal. The numbers below are the ones in the module, for Kevin to review.

`grovewarden_*` in `ItemBases` is the existing Epic armor set. It is not a Verdant Relic Set. Relic ids are `verdant_<class>_<slot>`.

## Shared rules

| Rule | Value |
|---|---|
| Classes | `warden`, `tidecaller`, `forgeborn`, `frostblade`, `voidcaster` (same ids as `Classes`) |
| Pieces | 4 per set: `helm`, `chest`, `legs`, `boots` (same slots as `Schema.ARMOR_SLOTS`) |
| Source | `heartwood_hard` only. Story and Normal do not drop these. |
| Kind / rarity | `Armor` / `Epic` |
| Bind | `bound = true`, `tradeable = false`. Never tradeable, including the 2-hour same-run window other raid gear uses. |
| Count | Unique piece ids of that class. A duplicate Mask counts once. Another class's pieces count as zero. |
| Thresholds | 0 or 1 piece: no bonus. 2 or 3: the 2-piece bonus. 4: both, 2-piece first. |
| `setPct(owned)` | Integer percent of the fullest set you own: 0, 25, 50, 75, or 100. Counts outside 0–4 pieces clamp. |
| Stats on the piece | None in this module. If a catalog row is added later, it uses the normal Epic slot ranges. The set bonus is not a stat. |
| Cost | None. No Robux product, no paid skip, no power sold. |

`setPct` is ownership, not what you are wearing. `count` / `active` are the worn pieces. A second copy of a piece you already own does not raise the percent.

## Warden — Heartwood Bulwark (`verdant_warden`)

Tank. The bonuses make you plant for a taunt, then spend Barkskin on the people standing in you.

| Piece | Id | Slot |
|---|---|---|
| Bulwark Mask | `verdant_warden_helm` | helm |
| Bulwark Cuirass | `verdant_warden_chest` | chest |
| Bulwark Greaves | `verdant_warden_legs` | legs |
| Bulwark Treads | `verdant_warden_boots` | boots |

| Bonus | Id | Skill | Numbers |
|---|---|---|---|
| 2-piece Planted Taunt | `planted_taunt` | `deep_roots` | radius 10, interval 6 seconds. Taunts. No damage. |
| 4-piece Barkskin Share | `barkskin_share` | `barkskin` | radius 12, share 0.08 of the Warden's max HP (`shareOf = "casterMaxHp"`). The Warden's own shield is unchanged. |

## Tidecaller — Springwell (`verdant_tidecaller`)

Healer. The pool becomes the cleanse, and the overflow shield leaves you for the ally who needs it.

| Piece | Id | Slot |
|---|---|---|
| Springwell Circlet | `verdant_tidecaller_helm` | helm |
| Springwell Robe | `verdant_tidecaller_chest` | chest |
| Springwell Leggings | `verdant_tidecaller_legs` | legs |
| Springwell Sandals | `verdant_tidecaller_boots` | boots |

| Bonus | Id | Skill | Numbers |
|---|---|---|---|
| 2-piece Pool Cleanse | `pool_cleanse` | `healing_pool` | cleanses 1. The first ally who enters that cast. |
| 4-piece Ebb Jump | `ebb_jump` | `ebb_flow` | radius 16. The existing overflow shield moves to the lowest ally. You do not keep it. If nobody is in range, it is lost. No new heal coefficient. |

## Forgeborn — Kilnheart (`verdant_forgeborn`)

Bruiser. The dash becomes a slow you place, and a successful block turns the next slam into a cone you have to aim.

| Piece | Id | Slot |
|---|---|---|
| Kilnheart Helm | `verdant_forgeborn_helm` | helm |
| Kilnheart Plate | `verdant_forgeborn_chest` | chest |
| Kilnheart Legguards | `verdant_forgeborn_legs` | legs |
| Kilnheart Sabatons | `verdant_forgeborn_boots` | boots |

| Bonus | Id | Skill | Numbers |
|---|---|---|---|
| 2-piece Cinder Trail | `charge_slow` | `molten_charge` | slow 0.2 (20% move speed) for 2 seconds. The trail deals no extra damage. |
| 4-piece Quenched Slam | `guard_cone` | `hammerfall` | within 4 seconds of a block, the next Hammerfall is a 120° cone of radius 8. The skill's damage coefficient stays as it is. |

## Frostblade — Rimewake (`verdant_frostblade`)

Melee. This is the set called out in the raids doc: the 4-piece makes Shatter spread Chill.

| Piece | Id | Slot |
|---|---|---|
| Rimewake Hood | `verdant_frostblade_helm` | helm |
| Rimewake Coat | `verdant_frostblade_chest` | chest |
| Rimewake Leggings | `verdant_frostblade_legs` | legs |
| Rimewake Boots | `verdant_frostblade_boots` | boots |

| Bonus | Id | Skill | Numbers |
|---|---|---|---|
| 2-piece Rime Path | `dash_patch` | `glacial_dash` | a patch of radius 4 for 3 seconds. Crossing it applies 1 Chill. The dash hit is unchanged. |
| 4-piece Shatter Spread | `shatter_spread` | `shatter` | 1 Chill to other foes within 8 studs. No extra crit damage, and the spread does not Shatter again. |

## Voidcaster — Riftweave (`verdant_voidcaster`)

Ranged. Blink becomes a grouping tool, and emptying Void on purpose lets Hex jump once.

| Piece | Id | Slot |
|---|---|---|
| Riftweave Cowl | `verdant_voidcaster_helm` | helm |
| Riftweave Mantle | `verdant_voidcaster_chest` | chest |
| Riftweave Trousers | `verdant_voidcaster_legs` | legs |
| Riftweave Steps | `verdant_voidcaster_boots` | boots |

| Bonus | Id | Skill | Numbers |
|---|---|---|---|
| 2-piece Blink Pull | `blink_pull` | `blink` | foes within 8 studs are pulled 4 studs toward the spot you left. The pull deals no damage. |
| 4-piece Unstable Hex | `unstable_jump` | `hex` | while Unstable (empty Void), Hex jumps to 1 foe within 12 studs when the hexed foe dies. The jump spends no Void. |

## Why these are not raw power

A set bonus here is a behavior on a skill you already have: who gets the shield, what shape the slam is, where Chill goes, when the taunt happens. The new numbers are radii, durations, one cleanse, one Chill, a 20% slow, and one 8% ally shield.

Left out on purpose:

- No flat damage, health, defense, crit, or attack speed on the bonus.
- No second copy of a piece counting toward 2-piece or 4-piece.
- No credit for wearing another class's pieces.
- The Tidecaller 4-piece does not add a heal percent. It moves the shield the passive already made, and you lose it if you are alone.
- The Forgeborn cone uses Hammerfall's existing damage. Radius 8 matches that skill. The change is that you have to aim a 120° cone.
- Frostblade's spread does not add crit damage. It only moves 1 Chill.
- Pieces are not sold. There is no Robux product id.

## For review

1. Relic pieces are never tradeable. The raids doc also lets raid gear be traded inside the same run for 2 hours. That window does not apply to these pieces. Confirm.
2. `setPct` only returns 0, 25, 50, 75, or 100, because a set is 4 pieces. The session-recap sample sentence uses 41%. Confirm the 25-point steps are what the card should show.
3. Applying the behavior (the taunt, the cleanse, the cone, the Chill spread) is combat. This module only returns the rows. Confirm that stays out of T-010.
4. Should the Heartwood Vendor sell a missing piece for Raid Marks, or are Hard drops the only source? No Mark price is set here.
