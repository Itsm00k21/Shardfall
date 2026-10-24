# Studio retest for #388 and #393

One sitting, one test account. Do not use Kevin's save. Do not commit the Studio edit below. Do not merge either PR from this pass. No Robux prompt should appear. `schemaVersion` stays 26.

`#388` (`echo/gear-b-salvage`) and `#393` (`echo/0.5-save-lock-release`) are separate branches. This sitting plays `#393` first, then `#388`. Same test account the whole way.

If Output says the profile could not be read, or this server is out of date, stop. That save was not overwritten.

## Lock (`echo/0.5-save-lock-release`)

In Studio only, set `StoreAdapter.STUDIO_LIVE = true` in `src/ServerScriptService/ShardfallServer/StoreAdapter.luau`. Leave the committed default `false`. Turn API Services on. `LaunchGate.saveTools` stays off.

1. Play. Note the gold. Output shows `schema v26` and `via DataStore`. Dev Tools does not show Force autosave or Print save version. Stop.
2. Play again right away. The same gold loads. The kick "Your data is still open on another server." does not appear. A lock left by an older Stop is taken only after about a minute, and the gold stays. A lock under 60 seconds stays busy. Do not try that takeover on a published server.

Set `STUDIO_LIVE` back to `false` and turn API Services off before the salvage half. The stored gold from step 2 is what this account should still have after salvage.

## Salvage (`echo/gear-b-salvage`)

API Services stay off, so this half keeps the profile in memory. `gearSalvage` and `chests` start off.

3. Play. In the command bar, set `LaunchGate.SHOW.gearSalvage = true`. Reopen Dev Tools. The Gear salvage section shows **+500 Essence** and **Fill the Bag**. Both were hidden while the flag was off. Fill the Bag, then +500 Essence. The toast shows the new total. Gear that was already in the bag is still there.
4. Favorite one sword and lock another. Leave the equipped weapon worn. Preview salvage all at or below Common, then press Confirm. The bag does not change until Confirm. The favorite, the lock, and the equipped piece stay. Essence rises by 1 for each salvaged Common.
5. Select two pieces and press Salvage selected. The bag stays until Confirm. Confirm deletes those two and adds their Essence. A bad `salvageNow` token leaves the bag and Essence unchanged.
6. Turn auto-salvage on at Uncommon and accept the ask. Crack one Common: it does not enter the bag, Essence rises by 1, and the row has `autoSalvaged = true` and `essenceGained = 1`. A Rare enters the bag, and that row omits both fields. Rare, Epic, or Mythic as the cap returns "Auto-salvage stops at Uncommon." and the bag does not change. A saved cap that was already above Uncommon reads Uncommon after load. Gold, gear, and Essence stay, the toggle stays on if it was on, and `schemaVersion` stays 26.
7. With auto-salvage still on at Uncommon, crack x10. Each Common row has `autoSalvaged = true` and `essenceGained = 1`, the number the server granted. Those Commons are not in the bag. A drop above Uncommon stays in the bag without those fields. Leave `chests` off.
8. Stop. The memory bag from this half is discarded. Play is over. The test account's stored gold is still the gold from step 2.
