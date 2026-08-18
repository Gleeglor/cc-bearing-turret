# Rotate Bearing Toward Angle

One closed-loop step: read one stored swivel target, command one
motor toward a commanded angle, return signed shortest-path error.

## Level

Advanced.

Ainterface command: `bearing_turret.rotate_bearing_toward_angle`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program on the gun computer.

## What

One closed-loop step on one axis. Read the stored servo target.
Command the motor toward a commanded angle. Return the signed
shortest-path error. Does not wait for the bearing to arrive.
Success that reaches the motor write inherits that child's
main-thread yields. It does not wait for Simulated to move the
stored field, and it does not wait for the motor block entity
to apply `cc_new_rpm`.

## When

The bearing and motor peripherals are attached. A target angle is
known.

## Where

Amazeballs world. One electric motor on one Simulated swivel bearing.
That is the intended world, not a runtime kinetic-connectivity test.

## Why

Native swivel wrap cannot set angle. Kinetic input is the write
path. Aim composes this once per yaw and once per pitch.

## Inputs

Exactly one table `opts`. Arity 1.

- `target_degrees`: required finite Lua number (commanded stored
  servo target, degrees)
- `rpm`: required finite Lua number (motor command whose sign
  increases the stored field)
- `bearing_name`: optional string on that table (`swivel_bearing`
  peripheral name, passed through to Read Swivel Bearing Angle)
- `motor_name`: optional string on that table (`electric_motor`
  peripheral name, passed through to Set Electric Motor Speed)
- `tolerance_degrees`: optional finite Lua number `>= 0`

Omit key, nil, or empty string for `bearing_name` or `motor_name`
means discover on that child. Omit key or nil for
`tolerance_degrees` means 1. A missing `target_degrees` or `rpm`
is not discover. Empty string for `tolerance_degrees` is not
default; it fails as a non-number.

`bearing_name` and `motor_name` identify which child wrap to read
and which child wrap to write. They do not assert that the named
motor drives the named bearing.

## Outputs

Exactly one Lua number: signed shortest-path error in degrees from
the stored servo target to `target_degrees`.

- Positive means the stored field must increase to take the short
  path
- Negative means the stored field must decrease
- Java remainder negatives from the child read are allowed and
  wrapped here
- `180` chooses the positive path
- Magnitude is at most 180
- Leftover inside the tolerance band is still returned, including
  when the motor is commanded 0
- Not a table
- Not a boolean arrived flag
- Not radians

The motor is commanded 0 if and only if `abs(error)` is less than
or equal to the resolved tolerance.

## Callers

- Aim Turret At Target

## Callees

- Read Swivel Bearing Angle
- Set Electric Motor Speed

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table `opts`,
  or an unknown `opts` key fail loud
- A positional target or RPM is not legal
- A present `bearing_name` or `motor_name` that is not a string
  fails loud
- Missing, non-number, NaN, or infinite `target_degrees` fails loud
- Missing, non-number, NaN, or infinite `rpm` fails loud
- Present `tolerance_degrees` that is not a number, NaN, infinite,
  or negative fails loud
- Child envelope, discovery, wrap, and peripheral failures
  propagate unchanged
- A child module missing its command function fails loud
- Does not wrap `swivel_bearing` or `electric_motor` itself
- Does not call `getTargetAngle` or `setSpeed` except through the
  callees
- Does not re-apply Simulated's FACING-negative kinetic speed flip
  to the child angle
- Polarity lives in the sign of `rpm`
- `rpm` 0 is a legal stop-only step; the returned error still
  reports the short path
- Does not `sleep`
- Does not wait until the stored field equals `target_degrees`
- Does not wait for Simulated to integrate cog RPM into
  `targetAngleDegrees`
- Does not wait for `ElectricMotorBlockEntity.tick()` to apply
  `cc_new_rpm` (`motorSpeed` may still lag after a write)
- Every success path calls Set Electric Motor Speed, including
  an RPM-0 stop; that child's `getSpeed` main-thread yield is
  in-contract on every such call
- When that child writes, its `setSpeed` main-thread yield is a
  second in-contract wait; skip-same still paid `getSpeed`
- Read Swivel Bearing Angle: tolerate a yield if that getter is
  main-thread
- Envelope and input failures never load children and take no
  child yield
- "Do not wait for a motor tick" means do not wait for
  `cc_update_rpm` apply; it does not mean this step is
  yield-free
- Does not assemble, disassemble, or lock
- Unassembled is not a failure; the speed command is still issued
  and the stored angle may sit still
- Locked is not a failure; the speed command is still issued and
  the stored angle may sit still
- This command does not verify kinetic connectivity;
  `bearing_name` and `motor_name` identify which child wrap to
  read and write, not that the named motor drives the named
  bearing; omit / nil / empty-string discovery still does not
  prove shaft membership; a crossed pair is not a distinct
  failure of this command
- Do not invent a pairing check; do not use motion, `sleep`,
  `getSpeed` vs `getTargetAngle`, assemble/lock, or FACING as a
  stand-in for connectivity
- Visual or physics pose lag is not a failure; the error uses the
  stored field
- Ticket 3 skip-same, clamp, float mismatch, unpowered, and
  POWERED behavior stay on that callee
- High RPM overshoot is not a failure; callers pick `|rpm|` and
  tolerance
- Success does not mean the stored field already equals
  `target_degrees`
