# Aim Turret At Target

## What

Confirm a live radar target this tick and drive yaw and pitch
Simulated swivel bearings one dual-axis control tick toward
caller-supplied ballistic degrees. Report whether both axes are
on target this step.

## How

Lua call: `bearing_turret.aim_turret_at_target(opts)`. Arity is
exactly 1. Zero arguments, a second argument, or `opts` that is
not a table fail loud. A number as argument 1 is not positional
yaw. A wrap table is not `opts`.

`opts` a table: read only these keys. Any other key fails loud,
including array index `1`:

- `yaw_degrees`
- `pitch_degrees`
- `yaw_rpm`
- `pitch_rpm`
- `track_id`
- `radar_name`
- `monitor_name`
- `yaw_bearing_name`
- `pitch_bearing_name`
- `yaw_motor_name`
- `pitch_motor_name`
- `yaw_tolerance_degrees`
- `pitch_tolerance_degrees`

`yaw_degrees`, `pitch_degrees`, `yaw_rpm`, and `pitch_rpm` are
required finite Lua numbers. Same finite check as Set Electric
Motor Speed `rpm`: `type ~= "number"` fails, `value ~= value`
(NaN) fails, `math.huge` and `-math.huge` fail. Do not
`tostring`. Do not clamp. Do not wrap degrees to `[0, 360)`. Do
not invent or default rpm.

Optional strings: omit, nil, or `""` means absent. Present and
not a string fails loud. No `tostring`.

Optional tolerances: omit, nil, or absent means that rotate call
omits `tolerance_degrees` (child default `1`). If present, must
be a finite Lua number greater than or equal to 0. Present
non-number, NaN, infinite, or negative fails loud before any
child call. Empty string is not default; it fails as a
non-number.

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

Call `bearing_turret.rotate_bearing_toward_angle` twice through
the ainterface. Child `opts` keys are `target_degrees`, `rpm`,
and optionally `bearing_name`, `motor_name`, and
`tolerance_degrees`. Do not copy rotate's loop,
`getTargetAngle`, or `setSpeed`. Do not pass this command's
keys through unchanged.

Yaw child table:

- `target_degrees` = `yaw_degrees`
- `rpm` = `yaw_rpm`
- `bearing_name` = `yaw_bearing_name` when that value is a
  non-empty string; otherwise omit the key
- `motor_name` = `yaw_motor_name` when that value is a
  non-empty string; otherwise omit the key
- `tolerance_degrees` = `yaw_tolerance_degrees` when present as
  a finite number; otherwise omit the key

Pitch child table: the same shape with `pitch_degrees`,
`pitch_rpm`, `pitch_bearing_name`, `pitch_motor_name`, and
`pitch_tolerance_degrees`.

Never send `yaw_bearing_name`, `yaw_rpm`, or the other parent
prefixed keys as child keys.

Yaw call first. Bind its only success value as yaw
`error_degrees` (one Lua number). On throw, do not call pitch.
Fail loud with the original message in the diagnostic. Pitch
call second. Bind its only success value as pitch
`error_degrees`. On throw, fail loud the same way.

Do not call `read_swivel_bearing_angle` or
`set_electric_motor_speed`. Those are rotate's callees.

This command is one dual-axis control tick. One invocation is
the live-track gate, one yaw rotate, one pitch rotate, then
return. Do not `while` until both axes are inside tolerance.
Do not `sleep`. After this tick the bearings may still be
moving.

Do not call `yaw_controller.setAngle`,
`pitch_controller.setAngle`, or any `cannon_mount` method. Do
not fire.

Child calls yield (`mainThread` on the children). The caller
must tolerate tick waits.

### On target

Resolved yaw tolerance is `yaw_tolerance_degrees` when that key
was forwarded, else `1`. Resolved pitch tolerance is
`pitch_tolerance_degrees` when forwarded, else `1`.

`on_target` is true iff `math.abs(yaw error_degrees)` is less
than or equal to the yaw resolved tolerance and
`math.abs(pitch error_degrees)` is less than or equal to the
pitch resolved tolerance.

Both axes must pass. One inside and one outside is false.
False is still success. Return exactly one table
`{ on_target = <boolean> }`. Do not return the leftover
numbers. Do not re-read bearings.

### Preconditions

- A Create Radar dish is attached so `read_radar_tracks` can
  succeed.
- `opts` is a table of the keys listed above.
- `yaw_degrees`, `pitch_degrees`, `yaw_rpm`, and `pitch_rpm`
  are finite Lua numbers.
- Optional names and `track_id` are strings or absent.
- Optional tolerances are absent or finite Lua numbers.
- Present yaw and pitch bearing names, when both present, differ.
- Present yaw and pitch motor names, when both present, differ.

### Postconditions

- Success is one Lua table with boolean `on_target`.
- After success, `read_radar_tracks` returned a list that
  contained the required id, yaw rotate was invoked, then pitch
  rotate was invoked, neither child threw, and `on_target` is
  the both-axes leftover-vs-tolerance predicate.
- After success, this function does not claim either bearing has
  already stopped moving.
- After a yaw rotate throw, pitch rotate was not invoked.

### Invariants

- This function does not compute lead, gravity strip, or muzzle
  speed.
- This function does not wrap peripherals.
- This function does not fire.
- This function does not write motor RPM except by calling
  rotate.
- This function does not loop until landed.

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
- `pitch_degrees`, `yaw_rpm`, and `pitch_rpm` missing, type,
  NaN, and infinity: same messages with that field name
- Present `yaw_tolerance_degrees` not a number:
  `Aim Turret At Target: yaw_tolerance_degrees must be a
  number, got <type>`
- Present `yaw_tolerance_degrees` NaN or infinity: finite-number
  messages with that field name
- Present `pitch_tolerance_degrees` type / NaN / infinity: same
  family
- Present `yaw_tolerance_degrees` or `pitch_tolerance_degrees`
  less than 0:
  `Aim Turret At Target: <field> must be >= 0, got <value>`
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
- Yaw rotate success not a number:
  `Aim Turret At Target: yaw rotate returned <type>, expected
  number`
- Pitch rotate success not a number: same family with `pitch`

### Non-failures

- `yaw_degrees` 0 or `pitch_degrees` 0 is not a failure.
- `yaw_rpm` 0 or `pitch_rpm` 0 is not a failure.
- Negative degrees and negative rpm are not a failure.
- Equal yaw and pitch numbers are not a failure.
- Selected track map nil while the id is in `tracks` is not a
  failure.
- `on_target` false is not a failure.
- Child skip-same or in-progress motion is not a failure here.
- Unpowered motors are rotate's concern; this command does not
  treat them as a distinct case.

### Sanitization

- Envelope: arity 1, table `opts`, known keys only.
- Degrees and rpm: finite Lua numbers. No clamp. No wrap. No
  `tostring`. No default rpm.
- Names and `track_id`: strings or absent. Empty string is
  absent. No `tostring`.
- Tolerances: absent or finite Lua numbers. Empty string is not
  absent-default.
- Track identity: string equality with list row `id`. No
  case-fold. No substring.
- Rotate leftovers: Lua numbers. `on_target` is boolean from
  `abs(error) <= resolved tolerance` on both axes. No coerce of
  `1` / `"true"`.
- Child errors: keep the original message inside this command's
  prefix. Do not swallow.

## Why

Radar `setAngle` writes Create Radar's CBC mount path (and an
optional Simulated adapter that already failed on this gun).
CC:CBC `setTargetAngles` is a CBC mount. Going Ballistic has no
ComputerCraft API. Native swivel has no angle setter.

The ballistic numbers belong to ticket 7. The one-axis step
belongs to ticket 5. This command is the two-axis apply plus a
live-target gate plus the both-axes on-target report Engage
uses to fire. Inlining rotate would erase that split.
Computing lead here would steal ticket 7. Returning nothing
would make Engage fail loud on every tick.

A leftover selected id is success on the read and failure here
because this command's What is aim at a radar target, not return
tracks.

Yaw before pitch is a defined order so a yaw fail does not move
pitch. One tick, no sleep, matches rotate and Engage. Per-axis
rpm exists because polarity can differ; ticket 5 folds polarity
into the sign of `rpm`.

Optional axis names match the child discovery rule. The gun has
two of each peripheral, so production callers pass names.

## SOLID

- Single responsibility: apply a caller solution to both axes
  when a live track id exists, one tick, and report on-target.
  No physics. No fire. No wait-until-landed loop.
- Compose, do not extend: call `read_radar_tracks` and
  `rotate_bearing_toward_angle`. Do not subclass them. Do not
  copy their internals.
- No caller-identity branching: Engage and a bench script with a
  solution take the same path. Names pick wraps on the children,
  not a yaw-vs-pitch fork inside shared write code.

Atomic Design: organism (specialized task script), not molecule. A
molecule is atoms only. `rotate_bearing_toward_angle` is the
molecule (advanced; atoms `read_swivel_bearing_angle` and
`set_electric_motor_speed`). `read_radar_tracks` is an atom
(basic). This command includes that molecule, so it is an
organism. Split-off rotate is why rotate is the molecule and
this command is the organism that uses it. This command is not
a page (bytecode). Engage Simulated Bearing Turret may remain
an organism; nested organisms are allowed. Engage is the
product-act organism. This command is the dual-axis aim
organism.

## Compatibility

High-level specialized task script. Advanced only composes
basics. This command composes one basic (`read_radar_tracks`)
and one same-topic advanced sibling
(`rotate_bearing_toward_angle`) through ainterfaces, so the mix
is high-level. Must not call high-level Engage. Must not reach
into child internals.
