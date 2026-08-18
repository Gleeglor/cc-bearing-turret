# How Should A ComputerCraft Program Read The Current Angle Of A Create Simulated Swivel Bearing?

## Who

ComputerCraft program wired to a Simulated swivel bearing.

## What

Read the stored servo target in degrees.

## When

The bearing peripheral is attached.

## Where

Amazeballs world. Native swivel ComputerCraft wrap.

## Why

Closed-loop rotate needs the angle. Native wrap is read-only.

Wrap type `swivel_bearing`. Call `getTargetAngle` (degrees). That
number is bearing-local rotation about the swivel FACING axis. 0 is
that scale's rest origin, not Minecraft north, yaw, pitch, or world
heading. After disassemble, a successful read returns 0 until another
writer changes the field. The assembled gun can look off that number
while the physics motor catches up; this command still returns the
stored number.

Lua takes one optional `opts` table (`bearing_name`). Omit the name
only when exactly one swivel is attached; the gun has two, so name
them. Return one Lua number, including Java `% 360` negatives. That
number already includes Simulated's FACING-negative kinetic speed
flip; callers do not flip again. Do not call `getTargetAngleRad`. Do
not assemble, lock, or set speed. Missing or wrong-type wrap, a
non-number, NaN, infinity, or a throw fails loud.

Unassembled still returns the stored angle. Integration only runs
while assembled; that is Simulated's tick, not a read failure.

Paper: [paper](paper.md).
