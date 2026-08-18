# Fire Rotating Barrel

Pulse analog strength 1 for two game ticks on a Create Big Cannons
mount fire face, then 0, so the rotating autocannon fires once.

## Level

Basic.

Ainterface command: `bearing_turret.fire_rotating_barrel`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program on the gun computer.

## What

Pulse analog strength 1 for two game ticks on the Create Big
Cannons mount fire face, then 0. That is one autocannon shot at
the 10 RPM rate table, not a spray.

## When

The barrel loop is spinning and a shot is wanted.

## Where

Amazeballs world. Mount fire face, separate from the aim motors.
ComputerCraft redstone API or a `redstone_relay` on that face.

## Why

Create Big Cannons has no ComputerCraft fire method. The native
trigger is analog redstone on the mount fire face. Aim does not
pull the trigger.

## Inputs

Exactly one table `opts`. Arity 1.

- `side`: required string on that table. One of `top`, `bottom`,
  `left`, `right`, `front`, `back`
- `relay_name`: optional string on that table (`redstone_relay`
  peripheral name)

Omit key, nil, or empty string for `relay_name` means the computer
`redstone` API. A missing `side` is not a default face.

## Outputs

None. Success is no Lua return values.

## Callers

- Engage Simulated Bearing Turret

## Callees

None.

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table `opts`,
  or an unknown `opts` key fail loud
- A positional side is not legal
- A present `relay_name` that is not a string fails loud
- Missing, non-string, or unknown `side` fails loud
- Side names are the six lowercase ComputerCraft names. Other
  strings fail loud. No `tostring`. No case fold
- Named wrap nil fails loud
- Named wrap whose type is not `redstone_relay` fails loud
- Omitted `relay_name` does not discover a relay
- Two attached relays and no name still use the computer
  `redstone` API
- Missing computer `redstone` when no relay is named fails loud
- Missing `sleep` fails loud
- `setAnalogOutput` throw on the on write (strength 1) fails loud
  and does not sleep and does not write 0
- After a successful on write, analog 0 is always attempted,
  including when `sleep` throws
- `sleep` throw after a successful off write fails loud
- Off write throw fails loud; the fire face may still be at 1.
  That message wins if sleep also threw
- Does not call `setOutput` (strength 15)
- Does not call `setAnalogueOutput`
- Does not call `setBundledOutput`
- Does not wrap `cannon_mount`, `cbc_cannon_mount`, or
  `cbc_fixed_cannon_mount`
- Does not call `setSpeed`
- Does not read analog input
- Does not restore a previous analog value
- Does not take a fire-power or duration input
- Strength is 1 then 0. Not 15. Not 0 only
- Hold is `sleep(0.1)` (two game ticks at 20 tps). Not `sleep(0)`.
  Not `os.pullEvent`
- Already-high analog on that side is not a skip. Still write 1,
  sleep, write 0
- Empty ammo is not a Lua failure
- Disassembled mount is not a Lua failure
- Barrel loop not spinning is not a Lua failure
- Success does not mean a projectile left the barrel
- Success does not mean the mount fire face is the wired face
- This function does not write the assembly face. Wiring the
  chosen side to the fire face is the operator's
- Create redstone links are wiring, not a second API
