# Read Swivel Bearing Angle

Read the stored servo target angle in degrees.

## Level

Basic.

Ainterface command: `bearing_turret.read_swivel_bearing_angle`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program wired to a Simulated swivel bearing.

## When

The bearing peripheral is attached.

## Where

Amazeballs world. Native swivel ComputerCraft wrap.

## Why

Closed-loop rotate needs the angle. Native wrap is read-only.

## Inputs

One optional table `opts`. Arity 0 or 1.

- `bearing_name`: optional string on that table (`swivel_bearing`
  peripheral name)

Omit key, nil, or empty string means discover.

## Outputs

Exactly one Lua number: degrees from `getTargetAngle`.

- Lua number from `getTargetAngle`: the stored servo target,
  including when visual pose lags it
- Degrees of rotation about the swivel's FACING axis
- 0 is the origin of that scale (bearing rest pose). Not north.
  Not the horizon
- Zero is a valid stored degree value
- Zero is the stored target when that target is 0 degrees
- After disassemble and before the next writer, that number is 0
- Disassemble resets the stored angle to 0
- Assemble does not capture pose into this angle
- A schematic or world load can store 0 as the same field
- Zero does not mean unassembled
- Not Minecraft yaw or pitch
- Not world heading
- The returned degrees already include Simulated's
  FACING-negative kinetic speed flip (DOWN, NORTH, WEST)
- Callers must not re-apply that flip
- Positive is increase of the stored field after that correction
- Negative values are allowed (Java remainder after `%= 360`)
- Magnitude under 360 after that remainder
- Not a table
- Not radians

## Callers

- Rotate Bearing Toward Angle

## Callees

None.

## Edges

- Missing swivel peripheral fails loud
- More than one `swivel_bearing` and no name fails loud
- Named wrap nil fails loud
- Named wrap whose type is not `swivel_bearing` fails loud
- Extra arguments, a non-table `opts`, or an unknown `opts` key
  fail loud
- A present `bearing_name` that is not a string fails loud
- `getTargetAngle` throw fails loud
- Non-number return fails loud
- NaN or infinity fails loud
- Unassembled is not a failure; return the stored angle
- Zero is not a failure; return 0 when the stored angle is 0
- Zero does not mean unassembled
- Lag or divergence from the stored target is not a failure;
  return the stored number
- Does not read constraint theta or visual pose
- Does not call `getTargetAngleRad`
- Does not assemble, disassemble, lock, or set motor speed
- Does not wrap Create mechanical bearings or radar controllers
