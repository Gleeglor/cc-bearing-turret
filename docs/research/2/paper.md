# How Should A ComputerCraft Program Read The Current Angle Of A Create Simulated Swivel Bearing?

A ComputerCraft program on the gun computer must learn each Simulated
swivel bearing's current angle: the stored servo target
`targetAngleDegrees`, exposed as `getTargetAngle`. Native Simulated
ComputerCraft on that block is read-only. This paper asks how that
read should work.

## Context

The gun sits on two Simulated swivel bearings (yaw and pitch). Create
Radar yaw and pitch controllers drive cannon mounts, not these
bearings. Ticket 1 already chose to read tracks from a dish off the
gun. Aim still needs the bearing angles themselves.

Simulated integrates kinetic shaft input into an internal target
angle. The player has no angle setter. Scripts have no angle setter
on the native peripheral. Closed-loop aim (ticket 5) writes motor
speed and reads this angle.

Amazeballs ships Simulated 1.3.0 nested in
`create-aeronautics-bundled-1.21.1-1.3.0.jar`. That jar registers a
ComputerCraft peripheral of type `swivel_bearing`.

This ticket is only the read. Motor speed, rotate-toward, aim, fire,
and ballistics are sibling tickets.

## Known Approaches

### Use Create Radar `getAngle` On A Yaw Or Pitch Controller

Create Radar controllers expose `setAngle` / `getAngle` for CBC
mounts. The client's gun is not on those mounts. Ticket 1 already
rejected that path for pose. It is also the wrong block for this
read: those angles are radar-weapon network state, not Simulated
bearing state.

### Wrap A Create Mechanical Bearing

Create's mechanical bearing is a different assembler. The gun uses
Simulated swivel bearings (side cog, center shaft pass-through).
Wrapping `Create_MechanicalBearing` would read the wrong machine.

### Drive Angle From Lua `setTargetAngle`

No such method exists on native Simulated `swivel_bearing`. Create
Avionics documents the same fact: the target is integrated from
kinetic input; neither the player nor scripts can set it. A Lua
setter would be a neighboring product, not this pack's native
surface.

### Read `getTargetAngle` / `getTargetAngleRad` On `swivel_bearing`

Native Simulated ComputerCraft (`SwivelBearingPeripheral`) exposes
exactly two Lua methods:

- `getTargetAngle()` - `blockEntity.getTargetAngleDegrees()`
- `getTargetAngleRad()` - `Math.toRadians` of that same field

Type string: `swivel_bearing`.

Create Avionics replaces Simulated's ComputerCraft init when that
addon is loaded. Its `swivel_bearing` type still exposes the same two
angle getters, calling the same `getTargetAngleDegrees()`. Extra
Avionics methods (`isAssembled`, `assemble`, locking) are not this
read. Amazeballs sources for ticket 1 listed the aeronautics bundle,
not Avionics. This function uses the native two-method surface. If
Avionics is later present, the same two calls still work.

`getTargetAngleDegrees` returns the field `targetAngleDegrees`. The
field starts at 0. `disassemble` assigns `targetAngleDegrees = 0`.
Until another writer changes the field, a successful
`getTargetAngle` after that assign is 0. That 0 is the specified
success value for the post-disassemble window. NBT key
`TargetAngle` persists the field, so a schematic or world load of 0
is that same stored 0; a non-zero load is a later writer, not a
second kind of zero.

Each assembled tick, Simulated converts cog speed to angular
speed. If FACING's axis direction is NEGATIVE (DOWN, NORTH, WEST),
it multiplies that angular speed by `-1`. It then adds the result
to `targetAngleDegrees` and applies `%= 360`. Java remainder keeps
the sign, so the stored value can be negative. Integration can
remain at 0 or land on 0.

On lock start, `setTargetAngleFromCurrentOrientation` overwrites
the field from the current quaternion pose; 0 then means that pose
was 0 degrees. Assemble does not copy pose into this field. After
disassemble then assemble with no lock start, 0 is the reset
leftover, not the orientation at assemble.

`getTargetAngle` returns `targetAngleDegrees` as stored. The
FACING-negative speed flip is already applied on the way into that
field. Callers of this read must not negate the returned number
because FACING is NEGATIVE. Positive sense: algebraic increase of
that stored field after the FACING correction. On POSITIVE-facing
bearings (UP, SOUTH, EAST), positive cog RPM increases the field.
On NEGATIVE-facing bearings, Simulated already negated, so
positive cog RPM decreases the field; the getter still returns the
post-flip stored value. Closed-loop code uses that number as
stored. Java `% 360` negatives are remainder wrap. They are
allowed. They are not a signal to apply the FACING flip a second
time.

When the bearing is not assembled, the field is not integrated
that tick; the getter still returns the stored number (0 after a
fresh disassemble reset or a never-written default). This read
does not require assembled. An unassembled bearing is still a
readable angle, including 0. 0 is a stored degree value. It is not
a failure and not an unassembled flag. Do not claim every
unassembled read is 0.

Neither getter is `mainThread = true` on the native peripheral. The
call does not need a world write. The caller should still tolerate a
yield if a pack overlay marks it main-thread later.

## Recommendation

Lua: `bearing_turret.read_swivel_bearing_angle(opts)`. Arity 0 or 1.
`opts` omitted, nil, or a table. The only key is `bearing_name`.
Unknown keys fail loud. A string is not a positional name.

Find one peripheral of type `swivel_bearing`. If `bearing_name` is
omitted, nil, or `""`, discover attached peripherals of that type and
require exactly one. Zero fails loud. Two or more fail loud. A turret
has two bearings; pass `bearing_name` when more than one is attached.

If `bearing_name` is a non-empty string, wrap that name. Wrap nil
fails loud. Wrapped type must be `swivel_bearing`. A named motor or
radar fails loud with the actual type in the message.

Call `getTargetAngle` (degrees). Do not call `getTargetAngleRad`.
Do not call assemble, disassemble, lock, or any kinetic write. Do
not convert units. Return exactly one Lua number: that degree value,
including negatives and values whose magnitude is under 360 after
Java `%`.

A throw from `getTargetAngle` fails the read. A non-number return
fails the read. NaN and infinities fail the read. Missing peripheral
methods fail the read.

Do not `peripheral.find` some other type. Do not read `getSpeed` as
a stand-in for angle. Speed is kinetic RPM at the block, not pose.

### Why Degrees, Not Radians

The block entity stores degrees. `getTargetAngleRad` is a derived
view. Closed-loop rotate compares commanded degrees to this field.
Callers that want radians convert. Returning both would be two
outputs for one fact.

### Geometric Frame

`getTargetAngle` is the bearing's local rotation about its FACING
axis. Simulated adds signed kinetic cog speed about FACING into
`targetAngleDegrees` while assembled, after the FACING-negative
speed flip named above. The rotary constraint drives
`RotaryConstraintHandle.DEFAULT_AXIS` toward `AngleHelper.rad` of
that field.

0 is that field's rest origin: the stored servo target at the
bearing zero of the FACING scale, including 0 after a fresh
disassemble reset. That zero is the bearing's own rest, not
Minecraft north and not a level horizon. Visual pose may lag even
when the stored target is 0.

The Lua number is not Minecraft entity yaw or pitch. Native
ComputerCraft on `swivel_bearing` has no yaw or pitch getter. A
turret uses two bearings; each read is still this FACING scalar.
World heading of the gun is a later composition (rotate / aim),
not this command.

### Stored Target Versus Pose

An assembled swivel has two angles: the field `targetAngleDegrees`,
and the attached sub-level's orientation about the rotary
constraint (what the gun looks like).

Lua can read only the field. Both wrap methods call
`getTargetAngleDegrees()`.

When the bearing starts locking,
`setTargetAngleFromCurrentOrientation` writes the current relative
orientation into `targetAngleDegrees` and `lastTargetAngleDegrees`.
After that write, the field matches pose at that instant. This
read does not perform that copy.

Each physics update, `updateServoCoefficients` drives the
constraint motor. While locking, the motor goal is a lerp of those
two fields, with stiffness and damping from Simulated config
scaled by inertia. While unlocked, the motor is friction damping
at speed zero. Visual pose can trail the field.

This function returns the field on every success. Servo lag stays
on Simulated's motor. The read still has one output.

### Why One Number, Not A Table

Ticket 1 returned a table because tracks, selected map, and selected
id are three facts. This read has one fact. A wrapper table would
invent structure the peripheral does not have.

### Why Optional Name

Zero or one bearing on a test computer can discover. Two bearings on
the gun cannot. Same discovery rule as ticket 1's radar name: omit
means exactly one; a name means that wrap.

## What Would Falsify This

- Amazeballs `peripheral.getType` for the swivel is not
  `swivel_bearing`. Then discovery by that string is wrong.
- In-game `getTargetAngle` is radians, or a table, or nil at rest.
  Then returning a Lua number of degrees is wrong.
- In-game angle is wrapped to `[0, 360)` in Lua even when Java
  remainder is negative. Then preserving negatives is wrong if the
  pack already normalizes. Until that shows up, return the number
  the method gave.
- Unassembled `getTargetAngle` throws. Then fail-loud on throw is
  right, and "readable at 0" is wrong for that pack build.
- In-game `getTargetAngle` is Minecraft entity yaw or pitch, or a
  world heading. Then treating it as bearing-local rotation about
  FACING is wrong.
- A later Lua method that exposed constraint theta would not
  change this command. A pose read would be a different ticket.
- Amazeballs ships only Avionics and removes the native getters.
  Then this paper's two-method surface is wrong. Avionics source
  still has the same getters as of the cited commit tree.

## Sources

- [Native SwivelBearingPeripheral.java](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/compat/computercraft/peripherals/SwivelBearingPeripheral.java)
- [SwivelBearingBlockEntity.java (targetAngleDegrees, assemble gate, FACING negate, %= 360, lock copy, updateServoCoefficients)](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/content/blocks/swivel_bearing/SwivelBearingBlockEntity.java)
- [ComputerCraftPeripherals.java (registers SWIVEL_BEARING)](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/compat/computercraft/ComputerCraftPeripherals.java)
- [Create Avionics swivel_bearing docs](https://solastrius.github.io/CreateAvionics/peripheral/swivel_bearing.html)
- [Create Avionics SwivelBearingPeripheral.java](https://github.com/SolAstrius/CreateAvionics/blob/main/common/src/main/java/ink/astrius/create_avionics/compat/simulated/peripherals/SwivelBearingPeripheral.java)
- [Swivel bearing (Create Aeronautics Wiki)](https://createaeronautics.miraheze.org/wiki/Swivel_bearing)
- [CC: Tweaked peripheral API](https://tweaked.cc/module/peripheral.html)
- Amazeballs instance mods (ticket 1 paper):
  `create-aeronautics-bundled-1.21.1-1.3.0.jar` (Simulated 1.3.0
  nested), `cc-tweaked-1.21.1-forge-1.120.0.jar`
