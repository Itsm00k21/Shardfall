# Haven market prompt sentence

G-082. The status line the RimShop prompt should show. This file does not change code.

The backlog sentence is already gone on this tip. `kind == "market"` sets `Gold shop. A Healing Tonic and a bag slot.` (`init.client.luau:1490-1491`). That is the sentence to keep. It names the two live offer labels and nothing else.

`GoldShop.offers` is the Healing Tonic at 40 Gold and the Bag slot at 250 Gold (`GoldShop.luau:24-27`). `GoldShop.apply` returns "That is not for sale." for offer id `pet` (`GoldShop.luau:69-70`). The shop page draws those offers and no third card (`MenuHub.luau:6931-6947`).

The case that must not mention a pet slot is this market open. `HavenClient` sends action `market` to `onPanel("market")` (`HavenClient.luau:53-54`). The RimShop pad is that action (`HavenBuilder.luau:1146-1148`, `Haven.luau:91-98`). `HavenBuild.spec` locks the prompt on `RimShop` (`HavenBuild.spec.luau:1240-1254`). A status on that open that contains `pet slot` fails. The Pet Garden line is a different action and is not this case (`init.client.luau:1492-1493`, `HavenClient.luau:49-50`).

Choice: keep the live sentence. Do not invent a second wording. While `LaunchGate.SHOW.market` is false, `UiRouter.havenTab("market")` returns `shop` (`UiRouter.luau:233-237`, `LaunchGate.luau:14`). The hub title is Shop (`StudioSmoke.spec.luau:109-119`).

## Sentence

| open | status | must not contain |
|---|---|---|
| Haven action `market` (RimShop) | `Gold shop. A Healing Tonic and a bag slot.` | `pet slot`, `Potions` |

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| GP1 | The market status names a pet slot the offers do not sell | `init.client.luau:1490-1491`, `GoldShop.luau:24-27`, `GoldShop.luau:69-70`, `MenuHub.luau:6931` | high | Trigger the RimShop prompt. The status contains `pet slot`. The cards are Healing Tonic and Bag slot. There is no pet-slot card |
| GP2 | The old Potions sentence comes back | `init.client.luau:1491`, `LaunchGate.spec.luau:263-266`, `GoldShop.luau:25` | high | The status is `Gold shop. Potions, a bag slot, and a pet slot.` The live offer label is Healing Tonic, not Potions. `LaunchGate.spec` requires the live sentence and forbids `and a pet slot.` |
| GP3 | The garden line is used for the market open | `init.client.luau:1492-1495`, `HavenClient.luau:49-54` | low | Action `market` shows `Pet Garden. Companions.` or `Armory. Weapons and armor.` Action `pets` shows the garden line and does not say a pet slot is for sale |
| GP4 | The hardcoded sentence drifts off the offer labels | `init.client.luau:1491`, `GoldShop.luau:34-35`, `MenuHub.luau:6931-6974` | medium | The status names a label that is not on `GoldShop.offers`. The cards still read Healing Tonic and Bag slot. Pass is both labels in the status, in that order |

GP2 is the regression lock. GP1 is the same hole if only the pet-slot words return. The prices stay 40 and 250. This note does not change them.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| GP-1 | Plaza, market flag off | Trigger the RimShop prompt (`HavenAction` `market`) | Status is exactly `Gold shop. A Healing Tonic and a bag slot.` It does not contain `pet slot` or `Potions`. The hub tab is Shop |
| GP-2 | Shop page open from that prompt | Read the offer cards | Two cards: Healing Tonic and Bag slot. No pet-slot card |
| GP-3 | Plaza | Trigger the Pet Garden prompt (`HavenAction` `pets`) | Status is `Pet Garden. Companions.` It is not the gold shop sentence, and it does not say a pet slot is for sale |
| GP-4 | Source | Read `init.client.luau` | The `kind == "market"` branch contains the live sentence. The file does not contain `and a pet slot.` |

## Flags

None. The sentence sells no power, no drop odds, and no Robux. A third argument on `GoldShop.apply` does not add an offer (`GoldShop.luau:64-65`).
