# Combat bug risks

G-062. Hit validation and cooldown desync in `CombatService.luau`, `CombatHud.luau`, and `CombatFeel.luau`. This file does not change code.

The server is the authority for damage. The client plays the slash and fires `Attack` without waiting (`Remotes.luau:569-570`). A dropped swing sends nothing back, so the local combo can run ahead of the server combo.

The heavy button and the R key already play the local slash. That path is `docs/qa/qa_heavy_swing.md`. This file does not restate it. Gamepad chords in `docs/qa/AUDIT_FOLLOWUPS.md` are not reopened.

## Risks

| id | risk | where | rating | what a tester sees |
|---|---|---|---|---|
| C1 | `charged` is whatever the client sends. There is no charge timer | `Remotes.luau:571-583`, `CombatService.luau:805`, `CombatFeel.luau:186-197`, `CombatFeel.luau:23` | high | Every `Attack` with the fifth argument true uses `CHARGE_MULT` (1.75), not the third-hit 1.4. A normal light click sends false. A modified client can send true on every swing and get the heavy multiplier inside range |
| C2 | Melee aim does not have to match the body facing | `CombatService.luau:595-607`, `CombatService.luau:748-770`, `CombatMath.luau:486-507` | high | Origin is the server root. A look vector whose length is between 0.05 and 3 becomes the arc. The body is not turned. An enemy behind the avatar and inside the weapon range can be the closest hit. A NaN look falls back to facing (`CombatService.luau:599-600`) |
| C3 | The client slash and combo advance when the server drops the swing | `CombatStage.luau:171-190`, `CombatHud.luau:136-142`, `CombatService.luau:707-712`, `CombatService.luau:805-806`, `Remotes.luau:579-580` | high | Spam light attack. The sword still slashes. `releaseSwing` returns on cooldown or during i-frames and sends no fx. `RateLimiter.take` for `Attack` returns with no fx. `OnboardingService.note(player, "swing")` still runs after the drop, so the tutorial step can count a swing that did not land |
| C4 | The weapon cooldown and the rate bucket are two clocks | `CombatMath.luau:156-160`, `RateLimiter.luau:50-51`, `CombatService.luau:717` | medium | Cooldown is `1 / attackSpeed`, or 1 second when speed is missing or not positive. The bucket is 8 burst and 6 per second. A fast weapon can be legal on cooldown and still be dropped by the bucket. A slow weapon can play six local slashes in a second and land one |
| C5 | A dodge with no charge still plays, and a failed dodge still sends fx | `init.client.luau:1305-1307`, `CombatService.luau:809-818`, `CombatFeel.luau:99-109` | medium | Empty charges. The local dodge clip plays, then the server sends `kind = "dodge"` with `charges` 0 and `perfect` false. The next real charge is unchanged |
| C6 | Shift can take two dodge paths if the sink does not mark it processed | `ActionBar.luau:899-912`, `CombatHud.luau:933-939` | medium | Hub closed. One LeftShift. Pass is one `Dodge` remote and one local clip. `ActionBar` sinks Shift and calls `onDodge` (clip plus remote). `CombatHud` also dodges on LeftShift when `processed` is false, and that branch does not call `CombatStage.dodge`. Two remotes fail the case |
| C7 | A swing in Haven plays locally and does nothing on the server | `CombatService.luau:786-789` | medium | Not in a run. The slash plays. No damage number, no cooldown write. The server returns before `releaseSwing` |
| C8 | Only the closest enemy in the arc is hit | `CombatService.luau:749-770` | low | Two enemies in the sword arc. The nearer one takes the hit. The farther one does not. This is the current rule, not a second swing |

C1 and C2 are the hit checks a modified client can bend. C3 is the desync a normal player can see by clicking fast.

## Cases

| case | setup | do this | pass |
|---|---|---|---|
| CB-1 | In a run, sword equipped, one enemy in front | Light click, then the Heavy chip or R | Light uses multiplier 1. Heavy uses 1.75. A light click that deals heavy damage fails C1 |
| CB-2 | In a run, enemy behind the avatar and inside range | Send `Attack` with a look vector aimed at that enemy, length about 1 | No hit. Today the closest enemy in that arc can be hit. The root does not move to the client |
| CB-3 | In a run, attack speed 1 | Click light attack five times inside the cooldown | One server hit. The local combo does not show a later step than the server. A slash with no number is allowed only when the server also says the swing was dropped. The swing tutorial does not advance on a drop |
| CB-4 | Attack speed high enough that cooldown is under 1/6 second | Swing as fast as the cooldown allows | Each cooldown swing lands, or the bucket drop is told to the client. A silent drop while cooldown has elapsed fails C4 |
| CB-5 | Dodge charges 0 | Press Shift | No local dodge clip, or the clip plays only when the server spends a charge. An fx with `charges` 0 and a played clip fails C5 |
| CB-6 | Hub closed, one charge | Press LeftShift once | One `Dodge` remote. One clip. RightShift uses the `ActionBar` bind only |
| CB-7 | Haven, not in a dungeon | Swing and dodge | No damage and no charge spent. The local slash is allowed only if the client already knows the swing will not land |
| CB-8 | Two enemies in the arc, different distances | One light swing | The nearer enemy takes the damage. The other does not |
| CB-9 | Look arguments are `0/0` | One `Attack` | The swing uses the server facing. It does not hit every enemy in range |

## Already locked

Do not re-file these.

| area | locked by |
|---|---|
| Perfect dodge uses the server clock. A client stamp is ignored | `CombatFeel.luau:136-138`, `CombatService.luau:820-821` |
| A hit during i-frames deals no damage and does not score a second perfect | `CombatService.luau:471-484` |
| Auto-attack shares `nextAttack` with the manual swing | `CombatService.luau:881-901` |
| Heavy chip and R play the local slash and fire `charged` true | `docs/qa/qa_heavy_swing.md` |

## Flags

None. The 1.75 multiplier is a combat number already in `CombatFeel`, not a shop item. No paid power is added by these cases.
