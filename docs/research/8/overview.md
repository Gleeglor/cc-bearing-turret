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
here. Consume children by `dofile` of their modules and calling names on
`ainterface.json`.

Lua takes one `opts` table. Optional `radar_name` and `monitor_name`.
Required `yaw_bearing_name`, `pitch_bearing_name`, `yaw_motor_name`,
`pitch_motor_name`. Those four names are the only legal parent keys
for those roles. `side` is required (`fire_rotating_barrel`).
`relay_name` is optional. Child keys from #6 and #7 join that table
when those rows exist, except a child string that names one of those
four roles under a different key, and except the aim child's
firing-solution keys `yaw_degrees`, `pitch_degrees`, `yaw_rpm`, and
`pitch_rpm`.
Those excepted strings are not parent keys; if present they are
unknown and fail loud. Engage forwards each parent axis value under
the name the child lists. If both the parent name and the child's
different string are present, the child's string is unknown and
fails loud. Fire-required keys from #4 (`side`) fail at parent parse on every
call; off-target skip is not a pass on a missing fire key. Parent
parse does not require those four firing-solution keys, even if
aim lists them required. Engage copies those keys from compute's
success table onto `aim_opts`. Success is one table: `on_target`,
`fired`.

Paper: [paper](paper.md).
