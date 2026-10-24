# UI ownership

Ghost owns the surfaces below. Another agent does not edit them to make UI match this pack. If a change belongs in a Ghost-owned file, post the request on [#15](https://github.com/Itsm00k21/Shardfall/issues/15) and leave the file alone.

The one exception: other agents may **append rows** in MenuHub, Settings, and DevTools. Appending a row means adding an entry to an existing list or table in that file. It does not include rewriting layout, restyling, deleting a row, or changing behavior around the new row.

## Ghost-owned

| Surface | Files |
|---|---|
| MenuHub | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/MenuHub.luau` |
| Settings | `src/ReplicatedStorage/Shared/Settings.luau` |
| DevTools | `src/ReplicatedStorage/Shared/DevTools.luau` |
| Bag / Hero UI | Bag and Hero pages inside `MenuHub.luau`, plus `src/ReplicatedStorage/Shared/HeroBoard.luau`, `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/GearDetail.luau`, and the Bag rail in `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/HudShell.luau` |
| RollReveal | `src/ReplicatedStorage/Shared/RollReveal.luau` |
| InventoryHud | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/InventoryHud.luau` and `src/ReplicatedStorage/Shared/InventoryLayout.luau` |
| GearBar | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/GearBar.luau` |
| BagCompare | `src/ReplicatedStorage/Shared/BagCompare.luau` |
| GearHooks | `src/ReplicatedStorage/Shared/GearHooks.luau` |
| CombatHud / ResultsGrid | `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/CombatHud.luau` and `src/ReplicatedStorage/Shared/ResultsGrid.luau` |

GearBar, GearDetail, GearHooks, and InventoryLayout are on `ghost/gear-ui-hooks` and are not on `cursor/live-build-9721` yet. They are still Ghost's once they land.

The x10 summary painter `src/StarterPlayer/StarterPlayerScripts/ShardfallClient/RollSummaryHud.luau` and `src/ReplicatedStorage/Shared/RollSummary.luau` (on `ghost/roll-x10`) sit with RollReveal. Treat them as Ghost's. Do not edit them to restyle the summary.
