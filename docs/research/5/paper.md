# How Should A ComputerCraft Program Rotate A Simulated Swivel Bearing Toward A Commanded Angle Using Kinetic Motor Input?

A ComputerCraft program must drive one Simulated swivel bearing toward
a commanded angle. Native Simulated ComputerCraft cannot set that
angle. Kinetic cog input can. This paper asks how one closed-loop
step should compose the already-merged read and write.

## Context

The gun sits on two Simulated swivel bearings (yaw and pitch). Create
Radar yaw and pitch controllers do not drive those blocks. Ticket 2
reads the stored servo target `targetAngleDegrees` via
`getTargetAngle`. Ticket 3 writes Create Crafts and Additions
`electric_motor` RPM. This ticket is the loop that joins them on one
axis. Aim (ticket 6) will call it twice.

Amazeballs ships Simulated 1.3.0 nested in
`create-aeronautics-bundled-1.21.1-1.3.0.jar`, CC: Tweaked 1.120.0,
and Create Addition on the `1.21.1` line. Native `swivel_bearing` is
still two angle getters. Create Avionics documents the same fact: the
target is integrated from kinetic input; neither the player nor
scripts can set it.

This command consumes children only through their ainterface names:
`bearing_turret.read_swivel_bearing_angle` and
`bearing_turret.set_electric_motor_speed`. It does not wrap
`swivel_bearing` or `electric_motor` itself. It does not re-apply
Simulated's FACING-negative kinetic speed flip to the child read.
That flip is already in the stored field.

## Known Approaches

### Call Create Radar `setAngle` On A Yaw Or Pitch Controller

Those peripherals aim CBC mounts. The gun is not on those mounts.
Ticket 1 already rejected that path for pose. It is also the wrong
write for this rotate.

### Call Native `setTargetAngle` On `swivel_bearing`

No such method exists. Create Avionics states the target is
integrated from the shaft. A Lua setter would be a neighboring
product.

### Wrap A Create Mechanical Bearing Or Sequenced Gearshift

Create's mechanical bearing is a different assembler. A sequenced
gearshift `rotate` is a timed degree move on Create kinetics, not a
Simulated stored-field loop. Ticket 3 already rejected
`rotate` / `translate` on the motor for the same reason: closed-loop
aim wants a speed command. Wrong blocks.

### Sleep Until The Angle Matches, Inside This Command

A blocking wait would own `sleep`, freeze the computer until arrival,
and keep yaw and pitch from stepping together unless the caller used
`parallel`. Ticket 3's motor write already yields on `getSpeed` /
`setSpeed`. That Lua yield is in-contract here: every success
path of this command calls that child, including RPM-0 stop,
so every rotate that reaches the write pays `getSpeed`, and
pays `setSpeed` when that child writes. Adding a
wait-until-integrate loop would mix control with a neighboring
wait-for-apply (`cc_update_rpm`, or Simulated adding cog RPM
into `targetAngleDegrees`). Aim owns the outer loop. This
command is one step: read, decide RPM, write, return. No
`sleep`. Child `mainThread` yields are not `sleep`.

### Probe Motion To Learn Polarity, Then Drive

Motor FACING, gear inversions, and bearing FACING all affect whether
a positive `setSpeed` increases the stored field. Native
`swivel_bearing` has no facing getter. Ticket 2's read does not
inspect FACING and forbids a second flip of the returned number. A
probe step (nudge, wait, see which way the field moved) would sleep
and invent a calibration product. Rejected.

The caller who wired the gun knows which signed motor RPM increases
that bearing's stored field. That sign is an input, not a discovery.

### Bang-Bang One Step Through The Child Commands

Read the stored field through ticket 2. Compute the signed
shortest-path error to the commanded angle on the remainder circle.
If the absolute error is within tolerance, write RPM 0 through
ticket 3. Otherwise write the caller's `rpm` when the error is
positive (stored field must increase) and the negation of that `rpm`
when the error is negative. Return the signed error as one Lua
number.

Create's `KineticBlockEntity.convertToAngular` maps cog RPM to
degrees per tick as `speed * 360 / 60 / 20` (0.3 deg/tick per RPM).
Simulated adds that angular speed to `targetAngleDegrees` while
assembled, after the FACING-negative negate, then `%= 360`. This
command does not hard-code 0.3 into the write. Gearing between motor
and cog changes the ratio. The caller's `rpm` already folds ratio
and polarity. High RPM still overshoots: at 256 RPM a 1:1 cog steps
76.8 degrees in one tick. Callers pick a smaller `|rpm|` or a larger
tolerance. This function does not schedule a one-tick close.

## Recommendation

Lua: `bearing_turret.rotate_bearing_toward_angle(opts)`. Arity 1.
`opts` is a table. Keys:

- `target_degrees` - required finite Lua number
- `rpm` - required finite Lua number (signed; see polarity)
- `bearing_name` - optional string, passed through to
  `read_swivel_bearing_angle`
- `motor_name` - optional string, passed through to
  `set_electric_motor_speed`
- `tolerance_degrees` - optional finite Lua number `>= 0`; omit or
  nil means `1`; empty string is not default and fails as a
  non-number

Unknown keys fail loud. Omit, nil, or a second argument fail loud.
A positional target is not legal.

Load the two child Lua modules. Call
`read_swivel_bearing_angle` with at most `bearing_name`. Call
`set_electric_motor_speed` with `rpm` (the decided write) and at
most `motor_name`. Do not call `peripheral.wrap`. Do not call
`getTargetAngle` or `setSpeed` on a wrap this file created. Child
failures propagate unchanged.

### Error On The Remainder Circle

Ticket 2 returns Java remainder after `%= 360`. Java keeps the sign,
so the stored number can be negative. Lua 5.2 `%` on a finite number
is always in `[0, 360)` for modulus 360
(`a % b == a - math.floor(a / b) * b`).

Signed shortest-path error:

1. `delta = (target_degrees - current) % 360` in Lua
2. if `delta > 180` then `delta = delta - 360`
3. that `delta` is the error

Positive error means the stored field must increase to take the
short path. `delta == 180` stays `+180` (the positive path). Do not
add 360 to the child read before this wrap. Do not negate the child
read because FACING is NEGATIVE.

### Polarity

`rpm` is the motor command that increases the stored field on this
build. When error is positive and outside tolerance, write that
`rpm`. When error is negative and outside tolerance, write `-rpm`.
When `abs(error) <= tolerance_degrees`, write `0`.

On a POSITIVE-facing bearing (UP, SOUTH, EAST) with 1:1 cog sense,
positive cog RPM increases the field, so a typical `rpm` is
positive. On a NEGATIVE-facing bearing (DOWN, NORTH, WEST),
Simulated already negated cog speed on the way into the field;
positive cog RPM decreases the field. The caller then passes a
negative `rpm` so that this command's "increase" write still
increases the stored number. Gear inversions fold into the same
sign. This command does not read FACING.

`rpm` 0 is legal. Both the increase write and its negation are 0, so
every step writes 0 (ticket 3 may skip). The returned error still
reports the short path.

### Tolerance

Default `1` degree. One RPM at 1:1 is 0.3 degrees per tick, so a
1 degree band is wider than one slow tick and still tight for a gun.
`tolerance_degrees` 0 is legal and chatters unless the field lands
exactly. Negative tolerance fails loud.

The motor is commanded 0 if and only if `abs(error) <=` the resolved
tolerance. Success still returns the raw signed error, including a
leftover inside the band. Magnitude of that error is at most 180.
Stopping the motor does not replace the success number with 0.

### One Step, No Sleep, Child Yields In-Contract

Success is exactly one Lua number: that signed leftover error,
not 0 because the motor stopped. The stored
field will not move until Simulated's next assembled tick.
Ticket 3 may leave `getSpeed` lagging one motor tick (`cc_new_rpm`
not yet copied into `motorSpeed`). Neither lag is a failure.
This command does not wait for either tick: it does not `sleep`
until the stored field matches, and it does not re-read until
`getSpeed` equals `write_rpm`.

It does yield as its children yield. Every success that reaches
the write inherits ticket 3's `getSpeed` main-thread wait. A
write that is not skip-same inherits `setSpeed` as a second
wait. Ticket 2's getter is not marked `mainThread`; tolerate a
yield if a pack overlay changes that. Envelope failures take
no child yield.

"Do not wait for a motor tick" means do not wait for
`ElectricMotorBlockEntity.tick()` / `cc_update_rpm`. It does
not mean this function is yield-free. Aim cannot treat one
axis step as a non-yielding return.

Unassembled is not a failure. Ticket 2 still returns the stored
number. Ticket 3 still skips or writes. Simulated does not
integrate the field that tick. The speed command is accepted;
the angle may sit still.

Locked is not a failure. Ticket 2 still returns the stored number;
a locked bearing is already a named non-failure of that child.
Ticket 3 still skips or writes. This command does not inspect
lock, unlock, or call `setLockingMode`. The speed command is
accepted; the stored angle may sit still. This command does not
assemble, disassemble, or lock.

### Why Degrees, Why One Number, Why Optional Names

The child read is degrees. The commanded angle is degrees. Returning
radians would add a unit this tree does not use.

Ticket 2 returned one number because it had one fact. This command
has one fact after the write decision: remaining short-path error.
Arrived is `abs(error) <= tolerance`. A wrapper table would invent
a second shape.

A bench computer may have one swivel and one motor. The gun has two
of each. Discover-when-exactly-one stays on the children. Pass names
when more than one of a type is attached.

`bearing_name` and `motor_name` identify which child wrap to read
and which child wrap to write. They do not assert that the named
motor drives the named bearing. This command does not verify
kinetic connectivity. Omit / nil / empty-string discovery still
does not prove shaft membership. A crossed pair (yaw motor with
pitch bearing, or any attached motor that is not on that swivel's
cog) is not a distinct failure of this command. Child type,
envelope, and peripheral failures still propagate. Do not invent
a pairing check. Do not use motion, `sleep`, `getSpeed` vs
`getTargetAngle`, assemble/lock, or FACING as a stand-in for
connectivity. Aim (or the bench caller) owns the wiring: one
named motor per named bearing, with `rpm` signed so that value
increases that bearing's stored field.

## What Would Falsify This

- Amazeballs grows a native `setTargetAngle`. Then kinetic closed
  loop is no longer the write path for this pack.
- In-game `getTargetAngle` is already wrapped to `[0, 360)` in Lua
  and never negative. Then preserving Java negatives in the child
  is still correct; this wrap still works.
- A 1:1 cog does not step `rpm * 0.3` degrees per tick. Then the
  overshoot warning's 0.3 factor is wrong; bang-bang and polarity
  still hold.
- `package.loaded` child injection is unavailable on the computer.
  Then the load path must still reach the two sibling Lua files
  without inlining their wraps.
- In-game shortest path across 180 always prefers the negative
  sign. Then choosing `+180` on the tie is a documented convention
  that still arrives in one half-turn.

## Sources

- [Native SwivelBearingPeripheral.java](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/compat/computercraft/peripherals/SwivelBearingPeripheral.java)
- [SwivelBearingBlockEntity.java (cog speed, FACING negate, convertToAngular, %= 360)](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/content/blocks/swivel_bearing/SwivelBearingBlockEntity.java)
- [Create KineticBlockEntity.convertToAngular (RPM to deg/tick)](https://github.com/Creators-of-Create/Create/blob/mc1.21.1/dev/src/main/java/com/simibubi/create/content/kinetics/base/KineticBlockEntity.java)
- [Create Avionics swivel_bearing docs](https://solastrius.github.io/CreateAvionics/peripheral/swivel_bearing.html)
- [Swivel bearing (Create Aeronautics Wiki)](https://createaeronautics.miraheze.org/wiki/Swivel_bearing)
- [Lua 5.2 arithmetic (`%` as floor modulus)](https://www.lua.org/manual/5.2/manual.html#3.4.1)
- Ticket 2 paper: stored field, FACING flip already applied, one
  Lua number
- Ticket 3 paper: `electric_motor` skip-same, no sleep-and-retry
- Ticket 1 paper pack list: Minecraft 1.21.1 Amazeballs jars
