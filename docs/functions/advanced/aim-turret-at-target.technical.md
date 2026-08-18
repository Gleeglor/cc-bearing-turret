# Aim Turret At Target

## What

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings to caller-supplied ballistic degrees.

## How

Lua call: `bearing_turret.aim_turret_at_target(opts)`. Arity is
exactly 1. Zero arguments, a second argument, or `opts` that is
not a table fail loud. A number as argument 1 is not positional
yaw. A wrap table is not `opts`.

`opts` a table: read only these keys. Any other key fails loud,
including array index `1`:

- `yaw_degrees`
- `pitch_degrees`
- `track_id`
- `radar_name`
- `monitor_name`
- `yaw_bearing_name`
- `pitch_bearing_name`
- `yaw_motor_name`
- `pitch_motor_name`

`yaw_degrees` and `pitch_degrees` are required finite Lua
numbers. Same finite check as Set Electric Motor Speed `rpm`:
`type ~= "number"` fails, `value ~= value` (NaN) fails, `math.huge`
and `-math.huge` fail. Do not `tostring`. Do not clamp. Do not
wrap to `[0, 360)`.

Optional strings: omit, nil, or `""` means absent. Present and
not a string fails loud. No `tostring`.

If both `yaw_bearing_name` and `pitch_bearing_name` are present
(non-empty strings) and those strings are equal, fail loud before
any child call. Same rule for `yaw_motor_name` and
`pitch_motor_name`. Absent names are not compared.

### Live target

Build a `read_radar_tracks` opts table with only present
`radar_name` and `monitor_name`. Call
`bearing_turret.read_radar_tracks` through that ainterface. Do
not wrap the dish. On throw, fail loud with the original message
in the diagnostic.

Resolve the required track id:

- If `track_id` is a non-empty string, that string is the
  required id.
- Otherwise the required id is `selectedTrackId` from the read
  result.

If the required id is nil or `""`, fail loud: no radar target.

Walk `tracks` (dense list from the child). A live target is a
row table whose `id` equals the required id. Miss fails loud.
Do not rotate. Ticket 1 allows a leftover selected id on the
read; this command does not. Aiming at a ghost is not success.

Do not read `position` or `velocity`. Do not use
`selectedTrack` map shape as the live check. Identity is the
list `id`.

### Two rotate calls

Call `bearing_turret.rotate_bearing_toward_angle` twice. Ticket
5 owns that command. Consume it through the ainterface when
published. Until then, `require` the sibling module
`rotate_bearing_toward_angle.lua` and call the same function
name. Do not copy its loop, `getTargetAngle`, or `setSpeed`.

This command maps onto rotate's inputs as:

- Yaw: target angle = `yaw_degrees`; bearing name =
  `yaw_bearing_name`; motor name = `yaw_motor_name`
- Pitch: target angle = `pitch_degrees`; bearing name =
  `pitch_bearing_name`; motor name = `pitch_motor_name`

Exact child key names are rotate's ainterface when ticket 5
publishes them. This command's own keys do not change. If rotate
uses different names, map onto those names here.

Yaw call first. On throw, do not call pitch. Fail loud with the
original message in the diagnostic. Pitch call second. On throw,
fail loud the same way.

Do not call `read_swivel_bearing_angle` or
`set_electric_motor_speed`. Those are rotate's callees.

Do not add a settle wait beyond what rotate already does. One
aim invocation is this pair of calls. Success is no Lua return
values. Bearings may still be moving.

Do not call `yaw_controller.setAngle`,
`pitch_controller.setAngle`, or any `cannon_mount` method. Do
not fire.

Child calls yield (`mainThread` on the children). The caller
must tolerate tick waits.

### Preconditions

- A Create Radar dish is attached so `read_radar_tracks` can
  succeed.
- `opts` is a table of the keys listed above.
- `yaw_degrees` and `pitch_degrees` are finite Lua numbers.
- Optional names and `track_id` are strings or absent.
- Present yaw and pitch bearing names, when both present, differ.
- Present yaw and pitch motor names, when both present, differ.

### Postconditions

- Success is no Lua return values.
- After success, `read_radar_tracks` returned a list that
  contained the required id, yaw rotate was invoked, then pitch
  rotate was invoked, and neither child threw.
- After success, this function does not claim either bearing's
  stored angle already equals the request.
- After a yaw rotate throw, pitch rotate was not invoked.

### Invariants

- This function does not compute lead, gravity strip, or muzzle
  speed.
- This function does not wrap peripherals.
- This function does not fire.
- This function does not write motor RPM except by calling
  rotate.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra or missing arguments:
  `Aim Turret At Target: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Aim Turret At Target: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Aim Turret At Target: unknown input '<key>'`
- Present optional string field not a string:
  `Aim Turret At Target: <field> must be a string or nil, got
  <type>`
- `yaw_degrees` missing:
  `Aim Turret At Target: yaw_degrees is required`
- `yaw_degrees` not a number:
  `Aim Turret At Target: yaw_degrees must be a number, got
  <type>`
- `yaw_degrees` NaN:
  `Aim Turret At Target: yaw_degrees must be a finite number,
  got nan`
- `yaw_degrees` infinity:
  `Aim Turret At Target: yaw_degrees must be a finite number,
  got inf`
- `pitch_degrees` missing, type, NaN, and infinity: same
  messages with `pitch_degrees`
- Equal present bearing names:
  `Aim Turret At Target: yaw_bearing_name and pitch_bearing_name
  must differ, both '<name>'`
- Equal present motor names:
  `Aim Turret At Target: yaw_motor_name and pitch_motor_name
  must differ, both '<name>'`
- `read_radar_tracks` throw:
  `Aim Turret At Target: read_radar_tracks failed: <original>`
- No usable id:
  `Aim Turret At Target: no radar target this tick`
- Required id missing from `tracks`:
  `Aim Turret At Target: track '<id>' is not in this tick's
  tracks`
- Yaw rotate throw:
  `Aim Turret At Target: yaw rotate failed: <original>`
- Pitch rotate throw:
  `Aim Turret At Target: pitch rotate failed: <original>`

### Non-failures

- `yaw_degrees` 0 or `pitch_degrees` 0 is not a failure.
- Negative degrees are not a failure.
- Equal yaw and pitch numbers are not a failure.
- Selected track map nil while the id is in `tracks` is not a
  failure.
- Child skip-same or in-progress motion is not a failure here.
- Unpowered motors are rotate's concern; this command does not
  treat them as a distinct case.

### Sanitization

- Envelope: arity 1, table `opts`, known keys only.
- Degrees: finite Lua numbers. No clamp. No wrap. No
  `tostring`.
- Names and `track_id`: strings or absent. Empty string is
  absent. No `tostring`.
- Track identity: string equality with list row `id`. No
  case-fold. No substring.
- Child errors: keep the original message inside this command's
  prefix. Do not swallow.

## Why

Radar `setAngle` writes Create Radar's CBC mount path (and an
optional Simulated adapter that already failed on this gun).
CC:CBC `setTargetAngles` is a CBC mount. Going Ballistic has no
ComputerCraft API. Native swivel has no angle setter.

The ballistic numbers belong to ticket 7. The one-axis loop
belongs to ticket 5. This command is the two-axis apply plus a
live-target gate. Inlining rotate would erase that split.
Computing lead here would steal ticket 7.

A leftover selected id is success on the read and failure here
because this command's What is aim at a radar target, not return
tracks.

Yaw before pitch is a defined order so a yaw fail does not move
pitch. Parallel `waitForAll` would still need a skip-pitch rule;
sequence is simpler.

Optional axis names match the child discovery rule. The gun has
two of each peripheral, so production callers pass names.

## SOLID

- Single responsibility: apply a caller solution to both axes
  when a live track id exists. No physics. No fire. No motor
  loop.
- Compose, do not extend: call `read_radar_tracks` and
  `rotate_bearing_toward_angle`. Do not subclass them. Do not
  copy their internals.
- No caller-identity branching: Engage and a bench script with a
  solution take the same path. Names pick wraps on the children,
  not a yaw-vs-pitch fork inside shared write code.

Atomic Design: molecule. It composes Read Radar Tracks (atom)
and Rotate Bearing Toward Angle (molecule on one axis). The
parent tree already split rotate so this command does not own
kinetic close-loop. Engage Simulated Bearing Turret is the
organism (specialized script) that also fires and computes
ballistics. This command is not that bundle.

## Compatibility

Advanced. May be called by high-level functions. Calls one basic
(`read_radar_tracks`) and one same-topic advanced sibling
(`rotate_bearing_toward_angle`) through ainterfaces. Must not
call high-level Engage. Must not reach into child internals.
