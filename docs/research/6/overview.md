# How Should A ComputerCraft Program Aim Yaw And Pitch Simulated Bearings At A Radar Target Using A Ballistic Solution?

## Who

ComputerCraft program on the gun computer.

## What

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings to caller-supplied ballistic degrees.

## When

A firing solution exists and a Create Radar dish is attached.

## Where

Amazeballs world. Kinetic motors on Simulated yaw and pitch
swivel bearings.

## Why

Create Radar yaw and pitch controllers drive cannon mounts, not
this Lua path. This command aims bearings at a solution. It does
not compute Going Ballistic physics.

The gun is two stacked Simulated swivels (yaw on the XZ plane,
pitch elevation). Native `swivel_bearing` has no angle setter.
Radar `yaw_controller.setAngle` / `pitch_controller.setAngle`
write Create Radar's CBC (and optional Simulated adapter) mount
path. That path already failed on this gun. CC:CBC
`setTargetAngles` is a CBC mount. Going Ballistic changes CBC
muzzle speed and has no ComputerCraft API.

Lua takes one `opts` table. Required: `yaw_degrees` and
`pitch_degrees` (bearing-local, from Compute Ballistic Aim).
Optional: `track_id`, radar/monitor names, and per-axis bearing
and motor names. Call `read_radar_tracks`. Require a live track
id this tick (named, or the monitor selection). Then call
`rotate_bearing_toward_angle` for yaw, then for pitch. Do not
inline rotate. Do not fire. Do not convert world pose into
angles. Success is no return values. A missing target fails
loud. If yaw rotate fails, skip pitch.

The gun has two swivels and two motors, so callers name the axes.
Discovery stays on the child commands.

Paper: [paper](paper.md).
