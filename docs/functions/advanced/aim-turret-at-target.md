# Aim Turret At Target

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings one dual-axis control tick toward
caller-supplied ballistic degrees.

## Level

Advanced.

Ainterface command: `bearing_turret.aim_turret_at_target`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program on the gun computer.

## What

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings one dual-axis control tick toward
caller-supplied ballistic degrees. Report whether both axes are
on target this step.

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
- `yaw_rpm`: required finite Lua number (forwarded as rotate
  `rpm` on the yaw call; sign increases the yaw stored field)
- `pitch_rpm`: required finite Lua number (forwarded as rotate
  `rpm` on the pitch call; sign increases the pitch stored
  field)
- `track_id`: optional string on that table
- `radar_name`: optional string; forwarded to
  `read_radar_tracks`
- `monitor_name`: optional string; forwarded to
  `read_radar_tracks`
- `yaw_bearing_name`: optional string; forwarded as rotate
  `bearing_name` on the yaw call
- `pitch_bearing_name`: optional string; forwarded as rotate
  `bearing_name` on the pitch call
- `yaw_motor_name`: optional string; forwarded as rotate
  `motor_name` on the yaw call
- `pitch_motor_name`: optional string; forwarded as rotate
  `motor_name` on the pitch call
- `yaw_tolerance_degrees`: optional finite Lua number;
  forwarded as rotate `tolerance_degrees` on the yaw call
- `pitch_tolerance_degrees`: optional finite Lua number;
  forwarded as rotate `tolerance_degrees` on the pitch call

Omit key, nil, or empty string for optional names means the child
discovers. A missing `yaw_degrees`, `pitch_degrees`, `yaw_rpm`,
or `pitch_rpm` is not discover. Omit, nil, or empty `track_id`
means use `selectedTrackId` from this tick's
`read_radar_tracks`. Omit, nil, or absent
`yaw_tolerance_degrees` / `pitch_tolerance_degrees` means that
rotate call omits `tolerance_degrees` and uses default `1`.

`yaw_degrees` and `pitch_degrees` are the caller's ballistic
solution (Compute Ballistic Aim). They are bearing-local degrees
on the same scale as Read Swivel Bearing Angle: rotation about
that swivel's FACING, 0 at that bearing's rest origin. Not
Minecraft yaw or pitch. Not north. Not a world heading.

`yaw_rpm` and `pitch_rpm` use rotate's sign convention. The two
signs may differ. This command does not invent, default, probe,
or flip them.

## Outputs

One table. That table is the only return value.

- `on_target`: boolean. True iff both axes are on target this
  invocation (`abs` of each rotate `error_degrees` is less than
  or equal to that axis's resolved tolerance). False is still
  success of this command.

False does not mean failure. Engage fires only when the boolean
is true. After this tick the bearings may still be moving.

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
- Missing, non-number, NaN, or infinite `yaw_degrees`,
  `pitch_degrees`, `yaw_rpm`, or `pitch_rpm` fail loud
- Present non-number, NaN, infinite, or negative
  `yaw_tolerance_degrees` or `pitch_tolerance_degrees` fail
  loud
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
- Does not invent rpm or probe polarity
- Does not call `yaw_controller.setAngle` or
  `pitch_controller.setAngle`
- Does not wrap `cannon_mount`
- Does not fire
- One invocation is one dual-axis tick: live-track gate, yaw
  rotate, pitch rotate, return
- Does not `sleep` or loop until both axes are inside
  tolerance
- Yaw rotate runs before pitch rotate
- Yaw rotate failure skips pitch rotate and fails loud
- Pitch rotate failure fails loud
- Two swivels and two motors cannot discover "exactly one";
  callers name the axes
- Child discovery remains on the child; this command does not
  wrap dishes, bearings, or motors itself
- Zero degrees is a legal command
- Zero rpm is a legal command
- Negative degrees and negative rpm are legal
- Equal yaw and pitch numbers are legal
- `on_target` false is still success
- Rotate leftover inside tolerance still counts as that axis
  on target
