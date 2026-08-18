# Set Electric Motor Speed

Set a Create Crafts and Additions electric motor's commanded speed.

## Level

Basic.

Ainterface command: `bearing_turret.set_electric_motor_speed`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program wired to a Create Crafts and Additions
electric motor.

## What

Set that motor's commanded speed. Skip the peripheral write when
`getSpeed` already equals that command (raw Lua `==` of the two
numbers). Java clamp means the motor never reports an out-of-range
request, so those calls always write.

## When

The motor peripheral is attached.

## Where

Amazeballs world. Kinetic network on the bearing.

## Why

Bearings turn from kinetic input. This is the write primitive.
Native swivel ComputerCraft cannot set angle.

## Inputs

Exactly one table `opts`. Arity 1.

- `rpm`: required finite Lua number
- `motor_name`: optional string on that table (`electric_motor`
  peripheral name)

Omit key, nil, or empty string for `motor_name` means discover.
A missing `rpm` is not discover.

## Outputs

None. Success is no Lua return values.

## Callers

- Rotate Bearing Toward Angle

## Callees

None.

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table `opts`,
  or an unknown `opts` key fail loud
- A positional RPM is not legal
- A present `motor_name` that is not a string fails loud
- Missing, non-number, NaN, or infinite `rpm` fails loud
- Missing electric motor peripheral fails loud
- More than one `electric_motor` and no name fails loud
- Named wrap nil fails loud
- Named wrap whose type is not `electric_motor` fails loud
- `getSpeed` throw, non-number, NaN, or infinity fails loud
- `setSpeed` throw fails loud, including the documented anti-spam
  message if a fork still throws it
- Does not sleep and retry after a throw
- Does not clamp `rpm` in Lua
- Does not call `stop`, `rotate`, or `translate`
- Does not wrap `servo_motor`
- Equal current speed is not a failure; skip `setSpeed`
- RPM 0 is a speed write, not a distinct stop command
- A value outside the motor's configured RPM range always calls
  `setSpeed`; skip-same does not cover that path
- `getSpeed` is commanded `motorSpeed`; generated shaft speed can
  be 0
- Unpowered (inactive) motor is not a failure; skip or write as
  usual
- Redstone-`POWERED` motor is not a failure; skip or write as usual
- Equal commanded speed still skips when the shaft is stopped
- Success does not mean the shaft is turning at `rpm`
- After a `setSpeed` success, `getSpeed` may still be the previous
  value until the next motor tick; that is allowed
- Success does not mean `getSpeed` already equals `rpm`
- A later call with the same `rpm` before that tick may call
  `setSpeed` again
- Does not read energy, `POWERED`, generated speed, or stress
- Does not wait for the motor to become active
- Does not wait for a motor tick
- Does not remember last requested RPM
