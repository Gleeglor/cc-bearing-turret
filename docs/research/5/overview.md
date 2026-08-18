# How Should A ComputerCraft Program Rotate A Simulated Swivel Bearing Toward A Commanded Angle Using Kinetic Motor Input?

## Who

ComputerCraft program on the gun computer.

## What

One closed-loop step on one axis: read the stored swivel target,
command the motor toward a commanded angle, return signed
shortest-path error.

## When

The bearing and motor peripherals are attached. A target angle is
known.

## Where

Amazeballs world. One electric motor on one Simulated swivel bearing.
That is the intended world, not a runtime kinetic-connectivity test.
`bearing_name` and `motor_name` identify which child wrap to read
and write; they do not assert that the named motor drives the named
bearing.

## Why

Native swivel wrap cannot set angle. Kinetic input is the write path.
Aim composes this once per yaw and once per pitch.

Lua takes one `opts` table: required finite `target_degrees` and
`rpm`, optional `bearing_name`, `motor_name`, and
`tolerance_degrees`. Omit or nil tolerance means 1 degree. Empty
string for `tolerance_degrees` is not default; it fails as a
non-number. Unknown keys fail loud.

`rpm` is the motor command that increases the stored field on this
build. Absolute error within tolerance writes 0. Positive error
outside tolerance writes that `rpm`. Negative error outside
tolerance writes `-rpm`. Do not flip the child angle a second time
for FACING. Fold polarity into `rpm`.

This command loads the child Lua modules
`read_swivel_bearing_angle` and `set_electric_motor_speed`. It does
not wrap peripherals. Child errors propagate. No `sleep` until
arrival. Aim owns the outer loop. Every success that reaches the
motor write inherits ticket 3's `getSpeed` main-thread yield, and
`setSpeed` when that child writes. That is not waiting for a
motor tick: waiting for a motor tick means waiting for
`cc_update_rpm` to apply. Do not wait for Simulated integration
either. The read child may also yield if its getter is
main-thread.

Unassembled and locked are not failures of this step; the speed
command is still issued and the stored angle may sit still. This
command does not verify kinetic connectivity. A crossed pair is
not a distinct failure of this command.

Success is one Lua number: signed shortest-path error in degrees
after wrapping Java remainder negatives. 180 takes the positive
path. Magnitude is at most 180. Leftover inside the tolerance
band is still that number; success is not 0 merely because the
motor was commanded 0. High RPM overshoots; callers pick `|rpm|`
and tolerance.

Paper: [paper](paper.md).
