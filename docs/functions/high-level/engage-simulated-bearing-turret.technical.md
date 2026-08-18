# Engage Simulated Bearing Turret

## What

One engagement step: compute a ballistic solution from the
selected radar track, aim the Simulated yaw and pitch bearings at
that solution, and fire the rotating barrel only when aim reports
the gun is on target.

## How

Lua call: `bearing_turret.engage_simulated_bearing_turret(opts)`.
Check order is call-time, inside this command. Do not `dofile`
children at parent module load. Envelope tests must reach their
own messages even when child files are absent. First match wins.
Every fail is `error(message, 0)`. Prefix is
`Engage Simulated Bearing Turret: `.

Arity is exactly 1. Zero arguments, a second argument, or `opts`
that is not a table fail loud. A string as argument 1 is not a
positional name. A wrap table is still a table and continues; it
is not a valid `opts` and fails later envelope.

`opts` a table: legal keys are this command's six named keys on
`ainterface.json`, plus keys listed as inputs on
`compute_ballistic_aim`, `aim_turret_at_target`, and
`fire_rotating_barrel` once those rows exist, except a child
string that names yaw bearing, pitch bearing, yaw motor, or
pitch motor under a key other than `yaw_bearing_name`,
`pitch_bearing_name`, `yaw_motor_name`, or `pitch_motor_name`,
and except the input name `aim_turret_at_target` advertises for
the firing solution. Until that row names a key, that name is
`solution`. Those excepted strings are unknown. Any other key
fails loud, including array index `1`. Unknown-key scan runs
before required-field checks.

### Envelope

Optional `radar_name` / `monitor_name`: nil or `""` means omit
that key when forwarding (child discovers). Present and not a
string fails loud. No `tostring`. No wrap table as a name.
Check `radar_name`, then `monitor_name`.

Required axis names: `yaw_bearing_name`, `pitch_bearing_name`,
`yaw_motor_name`, `pitch_motor_name`. Those four names are the
only legal parent keys for those roles. Each must be a non-empty
Lua string. For each key, in that key order, then this
sub-order: missing or nil fails required; not a string fails
type; `""` fails non-empty. Empty string is not discover. Two
bearings and two motors cannot use exactly-one discovery.

`yaw_bearing_name` must not equal `pitch_bearing_name`.
`yaw_motor_name` must not equal `pitch_motor_name`. Equal names
fail loud. Do not assume wrap identity beyond the string.
Check equal bearings before equal motors.

Child-listed keys use that child's required/optional rule at
parent parse, including `fire_rotating_barrel` keys, except the
aim child's firing-solution input. A fire-required key missing
from `opts` fails loud on this call, whether or not aim will
report `on_target`. Do not wait until fire runs. Optional fire
keys stay optional. A child string that names one of the four
axis roles under a different key is not legal on parent `opts`;
if present, fail loud as an unknown input (before this
required/optional pass). The input name `aim_turret_at_target`
advertises for the firing solution is also not legal on parent
`opts`; if present, fail loud as an unknown input (before this
required/optional pass). Until that row names a key, that name
is `solution`. Parent parse does not require that key, even if
the aim child lists it required. Engage does not invent muzzle
velocity, barrel names, or RPM.

### Load

Load all three child modules after envelope, still before any
child call, in callee order: `compute_ballistic_aim`,
`aim_turret_at_target`, `fire_rotating_barrel`. For each name,
`pcall` `dofile` of that command's Lua module
(`compute_ballistic_aim.lua`, `aim_turret_at_target.lua`,
`fire_rotating_barrel.lua`). The module return must be a table
with that command as a function. `dofile` throw (missing file,
parse error, error during child module load), a successful
`dofile` that is not a table, or a command missing or not a
function are all load failure. All of those use
`Engage Simulated Bearing Turret: missing command '<name>'`,
not the raw Lua error. `<name>` is the ainterface command name,
not the filename. First missing name in callee order wins. Load
all three even when this step would skip fire. Do not inline
those functions. Do not use Lua `require`.

### Forward

Build three child `opts` tables after envelope and load, before
any child call. Do not pass the parent table through.

Copy onto each child table only keys that child lists. Do not
copy a parent key the child does not list.

Source for `yaw_bearing_name`, `pitch_bearing_name`,
`yaw_motor_name`, and `pitch_motor_name` is always those parent
keys. If the child lists an input for that role, write the
parent value under the name the child lists. Same string is a
same-key copy. Different string is a rename; do not also copy
the parent key onto the child. Apply that rename for each child
that lists that role, not only `aim_turret_at_target`. A child
that lists no input for a role does not receive that parent
value. Envelope already rejected a child's different axis
string on parent `opts`. The parent name is the value that is
forwarded.

For every other child-listed key, copy from parent `opts` only
when the strings match. Do not copy unknown keys. Do not copy
the aim child's firing-solution input from parent `opts`.
Envelope already applied each child's required/optional rule,
including `fire_opts` on every call. Envelope does not require
the aim child's firing-solution input.

1. `compute_ballistic_aim(compute_opts)`. Take the first return
   value only. It must be a Lua table with at least one key.
   Nil, non-table, or empty table fails loud. Do not inspect
   solution field names. That table is the solution.
2. Write compute's success table onto `aim_opts` under the
   input name `aim_turret_at_target` advertises for the firing
   solution. Until that row names a key, that name is
   `solution`. That write is the only way that key appears on
   `aim_opts`. Do not read it from parent `opts`. Call
   `aim_turret_at_target(aim_opts)`. Take the first return
   value only. It must be a Lua table. Key `on_target` must be
   a boolean (`true` or `false`). Missing, nil, or any other
   type fails loud. That boolean is parent `on_target`.
3. If `on_target` is false, do not call fire. Return
   `{ on_target = false, fired = false }`. This skip is legal
   only if `fire_opts` already passed parent parse and the fire
   module already loaded.
4. If `on_target` is true, call
   `fire_rotating_barrel(fire_opts)`. On return without error,
   success is `{ on_target = true, fired = true }`. Ignore fire
   return values.

`pcall` each child call. On false, `error` the child's message
with level 0. Do not wrap it into a second prose sentence that
drops the original. Do not replace it with `missing command`.
Do not continue to the next child.

Do not `sleep`. Do not loop until `on_target`. One aim call is
one kinetic step.

Engage does not call `read_radar_tracks`. Compute (and aim, if
that child lists a read) owns the radar wrap. Engage requires
that compute fail loud when there is no usable selected pose.
Engage does not pick a track from a list.

Engage does not call `getTracks`, `getTargetAngle`, `setSpeed`,
`setAngle`, `assemble`, or `cannon_mount` methods.

### Preconditions

- Child modules for compute, aim, and fire exist as ainterface
  commands and Lua files before load. Envelope still runs if
  those files are absent, so envelope messages stay stable.
  Until those rows exist on `origin/master`, this how is the
  design; production code waits.
- `opts` is a table of this command's keys (and child-listed
  keys once present, except axis-role remaps and the aim child's
  firing-solution input).
- Axis names are distinct non-empty strings.
- A usable selected radar pose exists this step (compute's
  contract).

### Postconditions

- The success return is exactly one table with boolean
  `on_target` and boolean `fired`.
- `fired` is true only if fire ran without error this step.
- `fired` true implies `on_target` true.
- `on_target` false implies `fired` false and fire was not
  called.
- No Radar controller write. No CBC mount wrap.

### Invariants

- This function does not implement fire, rotate, two-axis close
  loops, or ballistic math.
- This function does not call basic leaves or
  `rotate_bearing_toward_angle`.
- This function does not run forever.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra or missing arguments:
  `Engage Simulated Bearing Turret: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Engage Simulated Bearing Turret: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Engage Simulated Bearing Turret: unknown input '<key>'`
- Present aim-child firing-solution key on parent `opts`
  (placeholder `solution` until #6 names it):
  `Engage Simulated Bearing Turret: unknown input '<key>'`
  (same unknown-input message; that key is not a parent key)
- Present `radar_name` or `monitor_name` not a string:
  `Engage Simulated Bearing Turret: radar_name must be a string
  or nil, got <type>`
  (same shape for `monitor_name`)
- Missing required axis name:
  `Engage Simulated Bearing Turret: yaw_bearing_name is required`
  (same shape for the other three axis keys)
- Present axis name not a string:
  `Engage Simulated Bearing Turret: yaw_bearing_name must be a
  string, got <type>`
- Empty axis name:
  `Engage Simulated Bearing Turret: yaw_bearing_name must be a
  non-empty string`
- Equal bearing names:
  `Engage Simulated Bearing Turret: yaw_bearing_name and
  pitch_bearing_name must differ`
- Equal motor names:
  `Engage Simulated Bearing Turret: yaw_motor_name and
  pitch_motor_name must differ`
- Missing fire-child required key:
  `Engage Simulated Bearing Turret: <key> is required`
  (same shape as missing axis names; use the child's key name)
- Child module load or command missing, including a thrown
  `dofile`:
  `Engage Simulated Bearing Turret: missing command '<name>'`
  (`<name>` is the ainterface command name. This is not the
  raw Lua error and not a child-throw re-raise.)
- Compute return not a table:
  `Engage Simulated Bearing Turret: compute_ballistic_aim
  returned <type>, expected table`
- Compute return empty table:
  `Engage Simulated Bearing Turret: compute_ballistic_aim
  returned an empty solution`
- Aim return not a table:
  `Engage Simulated Bearing Turret: aim_turret_at_target
  returned <type>, expected table`
- Aim `on_target` not a boolean:
  `Engage Simulated Bearing Turret: aim_turret_at_target
  on_target returned <type>, expected boolean`
- Child throw: re-raise the child's message. Do not replace it.

### Non-failures

- `on_target` false is not a failure.
- Fire not called because off-target is not a failure.
- Those two hold only after parent parse passed, including
  fire-required keys, and after all three child modules loaded.
- Optional radar or monitor name omitted is not a failure;
  children discover.

### Sanitization

- Axis names are non-empty strings. No `tostring`. No wrap table.
- Optional dish and monitor names: empty string is omit. Any
  other non-string fails loud.
- `opts` must be a table. Extra arguments, omitted `opts`, nil
  `opts`, a non-table `opts`, or an unknown key fail loud as
  envelope failures.
- Child returns: first value only. Extra Lua returns discarded.
- Solution table is passed through unaltered. Do not add parent
  keys onto that table. Write it onto `aim_opts` under the aim
  child's firing-solution input name only. That name is not a
  parent `opts` key.
- `on_target` is not coerced (`1` / `"true"` fail).
- `fired` is not read from fire. It is whether fire ran.

## Why

Radar controllers aim CBC mounts. Simulated swivels integrate
kinetic input. Going Ballistic has no Lua peripheral (issue 3 on
that mod: a calculator block is out of scope). The only legal
parent is a specialized script that calls named children.

One call is one step so a bytecode loop can `sleep` between
ticks. An inner `while true` would steal that loop. Fire every
step would spray while the motors catch up. Fire only on the
aim child's on-target bit keeps the gate on #6, where tolerance
lives.

Selected pose is the operator click already exposed by Read
Radar Tracks. Picking the first `HOSTILE` would drop that click
without a spec.

Axis names are required because discover-exactly-one cannot tell
yaw from pitch. Equal names would drive one wrap twice and look
like two-axis aim.

Children own sanitization of their peripherals. Engage owns the
envelope, the order, the solution wire, and the fire gate.
The fire gate does not filter the envelope. Incomplete fire
`opts` must not look like a successful off-target step.

## SOLID

- Single responsibility: one engagement step. No ballistic
  formula, no motor RPM law, no barrel fire path.
- Compose don't extend: `dofile` child modules and call
  ainterface names. Do not copy their bodies.
- No caller-identity branching: a gun computer and a test harness
  that supplies the same `opts` get the same order and gate.

## Compatibility

High-level specialized task script. May call advanced and basic
commands through this topic's ainterface. Must not reimplement
those commands. Bytecode may call this command in a loop.
