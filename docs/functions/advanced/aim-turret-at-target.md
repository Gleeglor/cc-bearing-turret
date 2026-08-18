# Aim Turret At Target

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings to caller-supplied ballistic degrees.

## Level

Advanced.

Ainterface command: `bearing_turret.aim_turret_at_target`.

Module level: high-level specialized task script (`bearing_turret`).

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

## Inputs

Exactly one table `opts`. Arity 1.

- `yaw_degrees`: required finite Lua number (bearing-local
  degrees for the yaw swivel)
- `pitch_degrees`: required finite Lua number (bearing-local
  degrees for the pitch swivel)
- `track_id`: optional string on that table
- `radar_name`: optional string; forwarded to
  `read_radar_tracks`
- `monitor_name`: optional string; forwarded to
  `read_radar_tracks`
- `yaw_bearing_name`: optional string; forwarded to
  `rotate_bearing_toward_angle` for yaw
- `pitch_bearing_name`: optional string; forwarded to
  `rotate_bearing_toward_angle` for pitch
- `yaw_motor_name`: optional string; forwarded to
  `rotate_bearing_toward_angle` for yaw
- `pitch_motor_name`: optional string; forwarded to
  `rotate_bearing_toward_angle` for pitch

Omit key, nil, or empty string for optional names means the child
discovers. A missing `yaw_degrees` or `pitch_degrees` is not
discover. Omit, nil, or empty `track_id` means use
`selectedTrackId` from this tick's `read_radar_tracks`.

`yaw_degrees` and `pitch_degrees` are the caller's ballistic
solution (Compute Ballistic Aim). They are bearing-local degrees
on the same scale as Read Swivel Bearing Angle: rotation about
that swivel's FACING, 0 at that bearing's rest origin. Not
Minecraft yaw or pitch. Not north. Not a world heading.

## Outputs

None. Success is no Lua return values.

Success does not mean either bearing has already reached the
commanded degrees. Settle stays on Rotate Bearing Toward Angle.

## Callers

- Engage Simulated Bearing Turret

## Callees

- Read Radar Tracks (`bearing_turret.read_radar_tracks`)
- Rotate Bearing Toward Angle
  (`bearing_turret.rotate_bearing_toward_angle`)

Does not call Read Swivel Bearing Angle, Set Electric Motor
Speed, Compute Ballistic Aim, or Fire Rotating Barrel.

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table
  `opts`, or an unknown `opts` key fail loud
- A positional yaw or pitch is not legal
- Missing, non-number, NaN, or infinite `yaw_degrees` or
  `pitch_degrees` fail loud
- A present `track_id` that is not a string fails loud
- A present name field that is not a string fails loud
- Present equal `yaw_bearing_name` and `pitch_bearing_name`
  fail loud
- Present equal `yaw_motor_name` and `pitch_motor_name` fail
  loud
- `read_radar_tracks` failure fails this command loud
- Empty `tracks` with no usable id fails loud
- Omitted `track_id` and nil `selectedTrackId` fail loud (no
  radar target)
- Named or selected id missing from this tick's `tracks` list
  fails loud
- Live identity is a matching `id` in `tracks`; selected map
  shape is not required
- Does not read track `position` or `velocity`
- Does not convert world pose into angles
- Does not clamp or wrap degrees
- Does not call `yaw_controller.setAngle` or
  `pitch_controller.setAngle`
- Does not wrap `cannon_mount`
- Does not fire
- Yaw rotate runs before pitch rotate
- Yaw rotate failure skips pitch rotate and fails loud
- Pitch rotate failure fails loud
- Two swivels and two motors cannot discover "exactly one";
  callers name the axes
- Child discovery remains on the child; this command does not
  wrap dishes, bearings, or motors itself
- Zero degrees is a legal command
- Negative degrees are legal
- Equal yaw and pitch numbers are legal
- Success is no return values; bearings may still be moving
