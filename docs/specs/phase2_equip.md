# Phase 2 Equip (server)

Server-only. The Bag and Hero UI stay with Ghost. Nothing here spends Robux.

`LaunchGate.equip` defaults **off**. While it is off, `EquipSlot`, `UnequipSlot`, and `GetEquip` return `{ ok = false, error = "Equip is off." }` and do not read or write a profile.

## Save

`equipLoadout` is a new profile table, one string per slot (`""` when empty). It is additive. `schemaVersion` stays **26**. A missing field becomes five empty slots in `Schema.reconcile`. `Schema.migrate` on this branch still mutates its argument; `EquipService/Save.migrate` copies first and is what a future #381 step should call:

```lua
-- after #381, do not bump before that PR is the server
-- Schema.MIGRATIONS append { to = 27, apply = migrateTo27 }
-- inside migrateTo27: Save.apply(raw, versionless, ctx)
```

A v27 document would look newer to a live v26 server, so this PR does not bump the version.

The legacy `equipped` weapon, armor, pet, and accessories are not written by these remotes. Combat still reads that map until Ghost hooks the totals.

## Slots

`Config/EquipSlots`, in order: weapon, armor, pet, skill1, skill2.

- weapon: inventory item, kind Weapon
- armor: inventory item, kind Armor (any armor piece, one slot)
- pet: pets bag, kind Pet
- skill1 / skill2: a skill id on the player's class. The ultimate is not a slot id.

The same id cannot sit in two slots. A locked skill may still be equipped (`slots[].locked`). Using it is out of scope. Skill unlock levels are `EquipSlots.SKILL_LEVELS` (1, 2, 4, 6).

## Stats

`Config/EquipStats`. Totals are computed, not saved.

Empty loadout: damage 5, attack speed 1, crit chance 0.02, crit damage 1.5, HP 100. Replace-stats come from the weapon. Add-stats sum onto the base (HP 100).

When `LaunchGate.gearLevels` is on, a rolled stat is multiplied by `1 + item.upgrade * 0.08` before the element multiplier. `+0` is ×1. The scale is not written back onto `stat.value`. While `gearLevels` is off, totals use the saved stat as it is. See `docs/specs/gear_levels_stage_a.md`.

## Client API

All three calls are RemoteFunctions. The player is the caller. Extra arguments are ignored. Ids are strings of at most 64 characters, `[A-Za-z0-9_%-]`.

Rate limit: 6 burst, then 3 per second, per action, per player. Over the limit: `{ ok = false, error = "Slow down a moment." }`.

### EquipSlot(slotId, itemId)

Success:

```lua
{
  ok = true,
  loadout = { weapon = "uid", armor = "", pet = "", skill1 = "", skill2 = "" },
  stats = { lines = { { id, name, value, unit, text, fromGear } }, byId = { damage = 12 } },
  slots = { { id, name, accepts, source, itemId, locked, level } },
  elements = { ember = 0, frost = 0, void = 0 },
  replaced = "previousUid", -- only when the slot already held an item
}
```

`slots[].level` is the forge upgrade (`item.upgrade`). `+0` is `0`. An empty slot omits `level`.

Errors (string `error`, `ok = false`):

- `Equip is off.`
- `Slow down a moment.`
- `Unknown slot.`
- `You do not have that item.`
- `That item does not fit this slot.`
- `That item is already equipped.`
- `That skill is not on your class.`
- `Profile is not loaded.`
- `Could not update your profile.`

### UnequipSlot(slotId)

Same success body. `removed` is the uid or skill id that left the slot. Empty slot: `That slot is empty.`

### GetEquip()

No arguments. Same success body without `replaced` or `removed`. Does not write. A stored id the player does not own is shown as `""` and left on the save until an equip or unequip heals it.

### EquipChanged (RemoteEvent)

Server to client only. Fired after a successful EquipSlot or UnequipSlot with that same success body. No client event.

## Studio checklist

1. Set `LaunchGate.SHOW.equip` to true (it ships false).
2. Dev Tools → Seat owned gear. Output is `Seated N. Damage X, HP Y.` The legacy equipped weapon is unchanged.
3. From the client, `EquipSlot:InvokeServer("weapon", uid)` then `GetEquip:InvokeServer()`. Damage matches the weapon stat. A second slot with the same uid returns `That item is already equipped.`
4. `UnequipSlot:InvokeServer("weapon")`. Damage returns to 5. `EquipChanged` arrives with `removed`.
5. Set `equip` back to false. The next call returns `Equip is off.` and the save is unchanged.
