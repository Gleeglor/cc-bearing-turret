# How Can A ComputerCraft Program Aim Create Simulated Swivel Bearings At A Radar Target And Fire With Going Ballistic Physics When Create Radar Cannot Steer Those Bearings?

## Who

ComputerCraft program on the gun computer.

## What

One engagement step: compute a ballistic solution from the selected
radar track, aim the Simulated yaw and pitch bearings at that
solution, and fire the rotating barrel only when aim reports the gun
is on target.

## When

Radar, yaw and pitch bearings, their motors, and the barrel fire path
are attached. The operator wants one engagement step.

## Where

Amazeballs world. ComputerCraft on the gun computer.

## Why

Create Radar yaw and pitch controllers drive CBC mounts, not Simulated
swivel bearings. Going Ballistic has no ComputerCraft API. This script
is the product act that composes those gaps.

Do not call Radar `setAngle`. Do not wrap a CBC `cannon_mount`. Do not
use Create Aero Radar mechanical controllers. Native `swivel_bearing`
cannot set angle; motors turn the axes. Going Ballistic only changes
muzzle velocity; lead stays in Lua.

This command is one specialized task script. One call is one step, not
a `while true` loop. Order: `compute_ballistic_aim`, then
`aim_turret_at_target` with that solution, then `fire_rotating_barrel`
only if aim reports on-target. Off-target skip is success
(`fired = false`). A child `error` fails the parent.

Engage a selected radar pose. No selected pose fails loud. Do not pick
the first track. Do not implement fire, rotate, aim math, or ballistics
here. Consume children by requiring their modules and calling names on
`ainterface.json`.

Lua takes one `opts` table. Optional `radar_name` and `monitor_name`.
Required `yaw_bearing_name`, `pitch_bearing_name`, `yaw_motor_name`,
`pitch_motor_name`. Child keys from #4, #6, and #7 join that table when
those rows exist. Parent fills solution fields; the caller does not.
Success is one table: `on_target`, `fired`.

Paper: [paper](paper.md).
