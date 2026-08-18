# Read Swivel Bearing Angle

## What

Read the stored servo target angle in degrees.

## How

Lua call: `bearing_turret.read_swivel_bearing_angle(opts)`. Arity is
0 or 1. A second argument fails loud. `opts` omitted or `nil` means
discover (empty table). `opts` a table: read `bearing_name` only.
Any other key fails loud, including array index `1`. `opts` any
other Lua type fails loud. A string is not positional arg 1. A wrap
table is not `opts`.

Find one peripheral of type `swivel_bearing`. If a name is given,
wrap that name and require that type. If no name is given (omit,
nil, or `""`), find every attached peripheral of that type; require
exactly one.

Call `getTargetAngle` on that wrap. That method returns
`getTargetAngleDegrees()`: the block entity field
`targetAngleDegrees`. Do not call `getTargetAngleRad`. Do not
convert. Do not wrap to `[0, 360)`. Return that Lua number as the
only success value.

The field is rotation about the block FACING. Kinetic integration
and the rotary goal (`DEFAULT_AXIS`, radians of the same field)
share that axis. Do not convert the number into entity yaw/pitch
or a world heading. The peripheral has no such getter.

`targetAngleDegrees` starts at 0. `disassemble` sets it to 0.
Until another writer changes the field, the stored number after
that assign is 0. NBT key `TargetAngle` persists it. While
assembled, each tick: convert cog RPM to angular speed; if
FACING axis direction is NEGATIVE (`AxisDirection.NEGATIVE`:
DOWN, NORTH, WEST), multiply angular speed by `-1`; add to
`targetAngleDegrees`, then `%= 360`. That can stay at 0 or land
on 0. On lock start, `setTargetAngleFromCurrentOrientation`
overwrites from the current quaternion pose; 0 then means that
pose was 0 degrees. Assemble does not write pose into this
field. After disassemble then assemble with no lock start, 0 is
the leftover reset, not the orientation at assemble. This read
does not inspect FACING and does not negate. This read does not
perform the lock copy.

Success is that field, including when visual pose lags it. This
function still does not call assemble, disassemble, lock, or
`isAssembled`. Naming the writers does not add those calls.

`pcall` the getter. On throw, fail the read with the original
message in the diagnostic. Type-check number after a successful
call. `type(value) ~= "number"` fails loud. `value ~= value`
(NaN) fails loud. `value == math.huge` or `value == -math.huge`
fails loud.

Do not call `isAssembled`, `assemble`, `disassemble`,
`setLockingMode`, `getSpeed`, or any motor method. Unassembled is
not checked. Simulated only integrates the field while assembled;
the getter still returns the stored number.

The native getter is not marked `mainThread`. Tolerate a yield if a
pack overlay changes that.

### Preconditions

- A Simulated swivel bearing is attached to the computer (wired
  modem clicked).
- The peripheral type string is `swivel_bearing`.
- `opts` is nil or a table of the `bearing_name` key.
- `bearing_name` inside `opts` is a string or absent.

### Postconditions

- Success is exactly one Lua number, degrees.
- The success number is that FACING rotation in degrees,
  unaltered except the NaN/infinity rejection.
- After disassemble and before the next writer, success is the
  number 0.
- Success is the stored field when pose lags or diverges.
- That number is the peripheral's `getTargetAngle` value, unaltered
  except the NaN/infinity rejection.
- No second return value.
- No table wrapper.

### Invariants

- This function does not write to any peripheral.
- This function does not assemble, lock, or rotate a bearing.
- This function does not read tracks or fire.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra arguments:
  `Read Swivel Bearing Angle: expected at most one argument, got <n>`
- Argument present and not a table:
  `Read Swivel Bearing Angle: inputs must be a table or nil, got <type>`
- Unknown `opts` key:
  `Read Swivel Bearing Angle: unknown input '<key>'`
- Present `bearing_name` not a string:
  `Read Swivel Bearing Angle: bearing_name must be a string or nil, got <type>`
- No swivel peripheral when discovering:
  `Read Swivel Bearing Angle: no swivel_bearing attached`
- Two or more swivels and no name:
  `Read Swivel Bearing Angle: <n> swivel_bearing attached, pass bearing_name`
- Named wrap nil:
  `Read Swivel Bearing Angle: named bearing '<name>' is not attached`
- Named wrap type not `swivel_bearing`:
  `Read Swivel Bearing Angle: named bearing '<name>' is type '<type>', expected swivel_bearing`
- Getter throw:
  `Read Swivel Bearing Angle: getTargetAngle threw on bearing '<name>': <original>`
- Non-number:
  `Read Swivel Bearing Angle: getTargetAngle on bearing '<name>' returned <type>, expected number`
- NaN:
  `Read Swivel Bearing Angle: getTargetAngle on bearing '<name>' returned nan`
- Infinity:
  `Read Swivel Bearing Angle: getTargetAngle on bearing '<name>' returned inf`

Discovered wrap uses the attached peripheral name in diagnostics.

### Non-failures

- Unassembled is not a failure mode.
- Negative degree values are not a failure mode.
- Zero is not a failure mode.
- Zero is a stored degree value, not an unassembled flag.
- Lag or divergence from visual or physics pose is not a failure.
- A locked bearing is not a failure mode.

### Sanitization

- Names are strings or absent. Empty string is absent. Any other
  Lua type fails loud. No `tostring`. No wrap table as a name.
- `opts` omitted or nil is discover. Extra arguments, a non-table
  `opts`, or an unknown key fail loud as envelope failures.
- The returned number is not wrapped, rounded, or converted to
  radians. No `math.abs`. No add-360 for negatives. No
  FACING-based negate of the returned number.
- NaN and infinities are rejected. Finite numbers, including
  negative and zero, pass.

## Why

Native Simulated ComputerCraft on `swivel_bearing` is two getters.
`getTargetAngle` is the stored degree field. `getTargetAngleRad` is
the same field through `Math.toRadians`. Returning degrees avoids a
second unit and matches the block entity.

A name is optional because a bench computer may have one swivel. A
gun has two. Discover-when-exactly-one is the same rule as Read
Radar Tracks.

A table wrapper would invent a shape the peripheral does not have.
Ticket 1 used a table because it returned three facts.

Failing on unassembled would hide a stored angle. That stored
angle is often 0 after disassemble or on a fresh place. 0 is the
field at zero. Writers: default, disassemble reset, NBT
`TargetAngle`, assembled integration, lock-start pose. Assemble
does not capture pose. Integration and lock start are Simulated's
tick and lock path, not this read.

A yaw bearing and a pitch bearing differ by placement, not by
return type. This read does not compose them into a gun heading.

Returning the stored field avoids a second FACING flip in Lua.
Rotate Bearing Toward Angle consumes this number as already
facing-corrected.

The wrap can only see the field; closed-loop rotate compares
against the servo goal the motor tracks.

## SOLID

- Single responsibility: read one bearing angle. No aim, no fire,
  no motor.
- Compose later: Rotate Bearing Toward Angle calls this. This page
  does not call it.
- No caller-identity branching: yaw bearing and pitch bearing take
  the same read. The name picks which wrap.

## Compatibility

Basic. May be called by advanced and high-level functions. Must not
call other workspace functions.
