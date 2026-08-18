# Fire Rotating Barrel

## What

Pulse analog strength 1 for two game ticks on a Create Big Cannons
mount fire face, then 0, so the rotating autocannon fires once.

## How

Lua call: `bearing_turret.fire_rotating_barrel(opts)`. Arity is
exactly 1. Zero arguments, a second argument, or `opts` that is
not a table fail loud. A string as argument 1 is not positional
side. A wrap table is not `opts`.

`opts` a table: read `side` and `relay_name` only. Any other key
fails loud, including array index `1`. `side` is required. Omit,
nil, or `""` for `relay_name` means the computer `redstone` API.

`side` must be a Lua string and one of `top`, `bottom`, `left`,
`right`, `front`, `back`. `type(side) ~= "string"` fails loud.
Any other string fails loud. Do not `tostring`. Do not lower-case.
Do not accept `Top` or `"1"`.

`relay_name` when present and not `""` must be a string. Find
peripheral type `redstone_relay`. If a name is given, wrap that
name and require that type. If no name is given, do not scan for
relays. Do not require exactly one relay. The computer `redstone`
module is the no-name path.

When a relay is named: `pcall` `wrapped.setAnalogOutput(side, value)`.
That method may be `mainThread` and yield. When no relay is named:
call `redstone.setAnalogOutput(side, value)`. The computer module
is not a peripheral yield. Use `setAnalogOutput`, not
`setAnalogueOutput`, `setOutput`, or `setBundledOutput`.

`sleep` is `_G.sleep`. If it is nil, fail loud. Do not call
`os.sleep`. Do not `os.pullEvent`. Hold is `sleep(0.1)`: two
game ticks at 20 tps.

Pulse, after wrap and `side` type-check:

1. `pcall` analog 1. On throw, fail loud with the original
   message. Do not sleep. Do not write 0.
2. `pcall` `sleep(0.1)`. Remember a throw. Do not fail yet.
3. `pcall` analog 0. On throw, fail loud with the original
   message. If sleep also threw, the off message is the one.
4. If sleep threw and analog 0 returned, fail loud with the
   sleep original message.

On success, discard analog return values and return with no Lua
values. Do not read `getAnalogOutput`. Do not restore a previous
strength. Strength 1 is the on value even if the side already
reads 1.

CBC `CannonMountBlock` / `FixedCannonMountBlock` read
`level.getSignal` on the fire face and pass that integer as
`firePower`. Autocannon `setFireRate` uses 1-15. `FIRE_RATES[0]`
is 120 ticks (10 RPM). `canFire` needs rate at least 1 and
cooldown 0. A two-tick hold at 1 can produce at most one shot.
Strength 0 stops further shots. This function does not observe
the mount, ammo, or cooldown.

### Preconditions

- `opts` is a table of `side` and optional `relay_name`.
- `side` is one of the six lowercase ComputerCraft side names.
- Either the computer `redstone` API is present, or a named
  `redstone_relay` is attached.
- `_G.sleep` is present.
- The chosen side is wired to a CBC mount **fire** face (operator
  wiring, not checked here).

### Postconditions

- Success is no Lua return values.
- After success, analog 1 was written, `sleep(0.1)` returned, and
  analog 0 was written.
- This function does not return a shot count.
- After success, this function does not claim a projectile left
  the barrel.
- After success, the chosen side's analog output is 0.
- After an off-write failure, analog output may still be 1.

### Invariants

- This function does not read bearings, tracks, or motors.
- This function does not wrap a CBC mount peripheral.
- This function does not call `setOutput`, `setAnalogueOutput`,
  or `setBundledOutput`.
- This function does not write analog values other than 1 then 0.
- This function does not call `setSpeed`.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra or missing arguments:
  `Fire Rotating Barrel: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Fire Rotating Barrel: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Fire Rotating Barrel: unknown input '<key>'`
- Present `relay_name` not a string:
  `Fire Rotating Barrel: relay_name must be a string or nil, got <type>`
- `side` missing:
  `Fire Rotating Barrel: side is required`
- `side` not a string:
  `Fire Rotating Barrel: side must be a string, got <type>`
- `side` not one of the six names:
  `Fire Rotating Barrel: side must be top, bottom, left, right,
  front, or back, got '<side>'`
- Named wrap nil:
  `Fire Rotating Barrel: named relay '<name>' is not attached`
- Named wrap type not `redstone_relay`:
  `Fire Rotating Barrel: named relay '<name>' is type '<type>',
  expected redstone_relay`
- Computer `redstone` missing:
  `Fire Rotating Barrel: redstone API is missing`
- `sleep` missing:
  `Fire Rotating Barrel: sleep is missing`
- Analog 1 throw (computer):
  `Fire Rotating Barrel: setAnalogOutput 1 threw on side
  '<side>': <original>`
- Analog 1 throw (relay):
  `Fire Rotating Barrel: setAnalogOutput 1 threw on relay
  '<name>' side '<side>': <original>`
- Analog 0 throw (computer):
  `Fire Rotating Barrel: setAnalogOutput 0 threw on side
  '<side>': <original>`
- Analog 0 throw (relay):
  `Fire Rotating Barrel: setAnalogOutput 0 threw on relay
  '<name>' side '<side>': <original>`
- Sleep throw:
  `Fire Rotating Barrel: sleep threw: <original>`

Computer-path diagnostics use `side` only. Relay-path diagnostics
use the attached peripheral name and `side`.

### Non-failures

- Empty ammo is not a Lua failure.
- A disassembled mount is not a Lua failure.
- Barrel loop not spinning is not a Lua failure.
- Analog already 1 on that side is not a skip.
- Two attached relays and no `relay_name` is not a failure.
- `setAnalogOutput` returning a value is not a failure; discard it.

### Sanitization

- Names are strings or absent. Empty string is absent. Any other
  Lua type fails loud. No `tostring`. No wrap table as a name.
- `opts` must be a table. Extra arguments, omitted `opts`, nil
  `opts`, a non-table `opts`, or an unknown key fail loud as
  envelope failures.
- `side` is not folded, trimmed, or mapped from a number. Only
  the six lowercase names pass.
- Analog values are the integers 1 and 0. They are not inputs.
  No clamp of a caller strength.

## Why

CBC `create-v6-1.21.1` has no Lua fire method. Analog redstone on
the fire face is the native trigger. Third-party
`cannon_mount.fire` addons are not on the Amazeballs jar list and
they take over CBC mount aim.

`setOutput(true)` is strength 15 (300 RPM, 4-tick cooldown). A
short hold can spray. Strength 1 is 10 RPM (120-tick cooldown),
so two ticks is one shot.

Two analog writes in the same computer tick leave the world at
the last value. `sleep(0.1)` is the pulse. `sleep(0)` is one
tick and can miss the autocannon entity tick. After analog 1
succeeds, analog 0 still runs if sleep throws, so a sleep
failure does not leave a spray latched when the off write
works.

A name is optional because a computer sitting on the fire face
needs no relay. A gun computer elsewhere uses `redstone_relay`
over a wired modem (CC: Tweaked 1.114.0+, pack is 1.120.0).
Discover-when-exactly-one-relay would fire a random relay when
the computer itself is the intended output.

Restoring a previous analog value would re-arm a spray the
caller had left on that side. This command owns the side for
the pulse and leaves 0.

Failing loud on empty ammo or a disassembled mount would need a
CBC peripheral this pack does not ship. Success is the pulse.

## SOLID

- Single responsibility: pulse one fire-face analog once. No
  angle, no motor, no radar.
- Compose later: Engage Simulated Bearing Turret calls this.
  This page does not call it.
- No caller-identity branching: computer `redstone` and a named
  relay take the same 1 / sleep / 0 sequence. The name picks
  which writer.

## Compatibility

Basic. May be called by advanced and high-level functions. Must not
call other workspace functions.
