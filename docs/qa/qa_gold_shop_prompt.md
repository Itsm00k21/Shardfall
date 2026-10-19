# Haven market prompt

G-082. The sentence the Haven market prompt shows, and the case that must not mention a pet slot. This file does not change code.

The sentence is `Gold shop. A Healing Tonic and a bag slot.`

It names the two live offers. `GoldShop.offers` is the Healing Tonic (`tonic`, 40 Gold) and the Bag slot (`bag`, 250 Gold) (`GoldShop.luau:24-27`). `GoldShop.apply` answers `"pet"` with "That is not for sale." (`GoldShop.luau:69-70`). Those prices are live. This note does not change them.

`init.client.luau` already sets that sentence when the Haven action is `market` (`init.client.luau:1366-1367`). The sweep line "Gold shop. Potions, a bag slot, and a pet slot." is absent. `tests/LaunchGate.spec.luau` locks the live sentence and the absence of `and a pet slot.` (`LaunchGate.spec.luau:238-241`).

Choice: keep the live sentence. The player reads it on `ShardfallBanner.Banner` (`Ui.luau:272-273`), because `setStatus` copies the text into the banner (`Ui.luau:1800-1806`). The same text also lands on the unnamed status label under the legacy crack button (`Ui.luau:855-867`). The shop page title is `Shop` (`MenuHub.luau:1816-1817`). The rows are painted from `GoldShop.offers()` (`MenuHub.luau:5176-5180`).

The floating RimShop prompt is a different string. Its ActionText is `Market Board` and its ObjectText is `Browse and trade` (`HavenBuilder.luau:1144`, `HavenBuilder.luau:306-312`). `tests/HavenBuild.spec.luau` locks ActionText `Market Board` on the RimShop host (`HavenBuild.spec.luau:1240-1254`). That label is not the offer sentence.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| GP1 | The status names a pet slot | `init.client.luau:1366-1367`, `LaunchGate.spec.luau:238-241`, `GoldShop.luau:69-70` | high | Press the RimShop prompt (`HavenClient.luau:52-53`, `HavenClient.luau:207-214`). The banner reads `and a pet slot.` or `Gold shop. Potions, a bag slot, and a pet slot.` The shop rows are still the tonic and the bag slot. That sentence fails |
| GP2 | The sentence drops a live offer or names a third good | `init.client.luau:1367`, `GoldShop.luau:24-27`, `MenuHub.luau:5176-5180` | high | Same prompt. The banner is the full live sentence, 42 characters. The shop lists `Healing Tonic  40 Gold` and `Bag slot  250 Gold`. A sentence that says only Potions, or only the tonic, or a third good, fails |
| GP3 | The banner clips the end of a correct sentence | `Ui.luau:283-284`, `Ui.luau:1806`, `ShellLayout.luau:29` | medium | 390×844 and 844×390. The banner does not wrap, and `TextTruncate` is AtEnd. It stays up for 3.5 seconds. Pass is the whole sentence, including `bag slot.` A visible prefix that stops before `bag slot` fails. The source string can still match GP1's pass |
| GP4 | The rail Shop button never writes this sentence | `init.client.luau:1292-1294`, `init.client.luau:1366-1367` | low | Tap Shop on the rail. The hub opens Shop. The banner keeps its previous text. That path is not the prompt. Score GP1 on RimShop only |
| GP5 | The floating label still says Market Board | `HavenBuilder.luau:1144`, `HavenBuild.spec.luau:1242` | low | Stand at RimShop before the key. The prompt reads Market Board and Browse and trade. It does not name the tonic, the bag slot, or a pet slot. After the key, GP1's sentence shows. Scoring the floating label as GP1 fails this case |
| GP6 | A market switch that is on would open the board under the gold-shop sentence | `UiRouter.luau:233-237`, `LaunchGate.luau:14`, `init.client.luau:1365-1367` | low | Today `market` is false, so the tab is `shop`. The live test leaves that switch false. The sentence still follows `kind == "market"`, which is the prompt action, after the tab is chosen |

GP1 is the case that must not mention a pet slot. GP2 is the sentence the prompt should show. GP3 is readability of that same sentence. GP5 keeps the floating label out of GP1.

The legacy status label wraps (`Ui.luau:860`). The banner does not. A pass on the label alone is not a pass on the banner.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| GS-1 | Live switch. Market off. Any viewport | Press the RimShop prompt, HavenAction `market` | The banner text is `Gold shop. A Healing Tonic and a bag slot.` The hub title is Shop. The rows are the Healing Tonic and the Bag slot |
| GS-2 | Same as GS-1 | Read the banner, the status label, and the shop rows | None of them contain `pet slot`. The client source does not contain `and a pet slot.` |
| GS-3 | Same as GS-1 | Search the client for the sweep sentence | `Gold shop. Potions, a bag slot, and a pet slot.` is absent. A return of that sentence fails GP1 |
| GS-4 | 390×844, then 844×390 | Press the RimShop prompt and read the banner before 3.5 seconds | All 42 characters are readable, including `bag slot.` A clipped end fails GP3 |
| GS-5 | Shop closed | Tap the rail Shop button | Shop opens. This tap is not required to write the gold-shop sentence. Use GS-1 for the sentence |
| GS-6 | Standing at RimShop, prompt showing, key not pressed | Read ActionText and ObjectText | ActionText is Market Board. ObjectText is Browse and trade. Neither line says pet slot. The offer sentence appears after the key, on the banner |
| GS-7 | Live `GoldShop.offers` | Invoke `BuyGoldShop` with `pet` | The shop answers "That is not for sale." The banner sentence from GS-1 stays the tonic and the bag slot. No third row appears |

## Flags

None. The sentence sells no power, no drop odds, and no Robux. A paid field does not change the sentence (`init.client.luau:1367` passes no extra). The two Gold prices stay the live offer prices.
