# Engage Simulated Bearing Turret

One engagement step: compute a ballistic solution from the
selected radar track, aim the Simulated yaw and pitch bearings at
that solution, and fire the rotating barrel only when aim reports
the gun is on target.

## Level

High-level. Specialized task script.

Ainterface command: `bearing_turret.engage_simulated_bearing_turret`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program on the gun computer.

## What

One engagement step: compute a ballistic solution from the
selected radar track, aim the Simulated yaw and pitch bearings at
that solution, and fire the rotating barrel only when aim reports
the gun is on target.

## When

Radar, yaw and pitch bearings, their motors, and the barrel fire
path are attached. The operator wants one engagement step.

## Where

Amazeballs world. ComputerCraft on the gun computer.

## Why

Create Radar yaw and pitch controllers drive CBC mounts. They
cannot aim Simulated swivel bearings. Going Ballistic has no
ComputerCraft API. This script is the product act that composes
those gaps.

## Inputs

Exactly one table `opts`. Arity 1.

- `radar_name`: optional string (Create Radar dish)
- `monitor_name`: optional string (Create Radar monitor)
- `yaw_bearing_name`: required string (Simulated swivel, yaw)
- `pitch_bearing_name`: required string (Simulated swivel, pitch)
- `yaw_motor_name`: required string (`electric_motor` on yaw)
- `pitch_motor_name`: required string (`electric_motor` on pitch)

Omit key, nil, or empty string for `radar_name` or `monitor_name`
means discover, forwarded to children that list those keys.

Empty string is not legal for the four axis names. Those names
are required. The gun has two swivels and two motors.

When `compute_ballistic_aim`, `aim_turret_at_target`, or
`fire_rotating_barrel` lists further input keys on
`ainterface.json`, those keys are also legal on this same `opts`
table and are required or optional exactly as that child lists
them, except two classes of child key.

The first exception is a child key that names yaw bearing, pitch
bearing, yaw motor, or pitch motor under a string other than
`yaw_bearing_name`, `pitch_bearing_name`, `yaw_motor_name`, or
`pitch_motor_name`. That different string is not a parent key.
The parent keeps those four names as the only legal names for
those roles. Engage copies each of those four values onto a
child `opts` table under the name that child lists for that
role. If the child lists the same string, the copy is by name.
If both a parent axis name and a child's different string for
that role are present, the child's string is unknown and fails
loud.

The second exception is the input name `aim_turret_at_target`
advertises for the firing solution. Until that row names a key,
that name is `solution`. That key is not a parent `opts` key.
If it is present on parent `opts`, it is unknown and fails loud.
Parent parse does not require it, even if the aim child lists it
required. The caller does not pass a firing solution. Engage
does not copy that key from parent `opts`. After compute returns
a success table, engage writes that table onto `aim_opts` under
that name only.

Engage does not invent ballistic or fire internals.

Fire-child required keys are required on every call of this
command. Parent parse fails loud if a fire-required key is
missing, even when this step will skip fire. The on-target gate
chooses whether fire runs. It does not defer envelope checks.
A missing fire-required key is not an off-target success.

## Outputs

One table. That table is the only return value.

- `on_target`: boolean from `aim_turret_at_target` this step
- `fired`: boolean; true only when `fire_rotating_barrel` ran
  this step

## Callers

- Operator program or bytecode loop that re-calls this command

## Callees

- Compute Ballistic Aim
- Aim Turret At Target
- Fire Rotating Barrel

Does not call Read Radar Tracks, Read Swivel Bearing Angle, Set
Electric Motor Speed, or Rotate Bearing Toward Angle. Those sit
under the callees.

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table
  `opts`, or an unknown `opts` key fail loud
- A positional string is not legal
- A wrap table is not `opts`
- Present `radar_name` or `monitor_name` that is not a string
  fails loud
- Missing, empty, or non-string axis bearing or motor name fails
  loud
- `yaw_bearing_name` equal to `pitch_bearing_name` fails loud
- `yaw_motor_name` equal to `pitch_motor_name` fails loud
- Missing fire-child required key fails loud at parent parse,
  same as other required `opts` keys; do not wait for
  `on_target` true
- No selected radar pose this step fails loud (callee contract:
  compute fails; engage does not pick another track)
- Compute success that is not a table fails loud
- Compute success that is an empty table fails loud
- Aim success that is not a table fails loud
- Aim success missing boolean `on_target` fails loud
- A child `error` fails the parent with that child's message
- Missing child module or missing child command on the module
  table fails loud
- `on_target` false is not a failure; skip fire; return
  `fired = false`
- `on_target` true runs fire; fire success sets `fired = true`
- Fire is not called when compute or aim failed
- Does not `sleep`
- Does not contain `while true`
- Does not call Radar `setAngle`
- Does not wrap `cannon_mount`
- Does not implement fire, rotate, aim math, or ballistics
- Does not read `getTracks`, `getTargetAngle`, or `setSpeed`
