# Rotate Bearing Toward Angle

## What

One closed-loop step: read one stored swivel target, command one
motor toward a commanded angle, return signed shortest-path error.

## How

Lua call: `bearing_turret.rotate_bearing_toward_angle(opts)`.
Arity is exactly 1. Zero arguments, a second argument, or `opts`
that is not a table fail loud. A number as argument 1 is not
positional target or RPM. A wrap table is not `opts`.

`opts` a table: read `target_degrees`, `rpm`, `bearing_name`,
`motor_name`, and `tolerance_degrees` only. Any other key fails
loud, including array index `1`. `target_degrees` and `rpm` are
required. Omit, nil, or `""` for `bearing_name` or `motor_name`
means discover on that child. Omit or nil for `tolerance_degrees`
means `1`. A present empty string for `tolerance_degrees` is not
the default; it fails as a non-number.

`target_degrees` and `rpm` must be Lua numbers and finite.
`type(value) ~= "number"` fails loud. `value ~= value` (NaN) fails
loud. `value == math.huge` or `value == -math.huge` fails loud. Do
not `tostring`. Do not wrap `target_degrees` to `[0, 360)` before
the error math; Lua `%` in the error step does that. Do not clamp
`rpm`.

If `tolerance_degrees` is present and not nil: it must be a Lua
number, finite, and `>= 0`. Negative fails loud. `0` is legal.

### Child modules

After envelope and input sanitization succeed, resolve two sibling
modules by name:

- `read_swivel_bearing_angle`
- `set_electric_motor_speed`

Envelope failures never load children.

If `type(package.loaded[name]) == "table"`, use that table. Else
`dofile(name .. ".lua")`. `dofile` failure fails loud with the
original message in the diagnostic. After `dofile` returns
without throwing, if `type(loaded) ~= "table"`, fail loud before
command lookup and before storing into `package.loaded`. Do not
reuse the throw wrapper (load succeeded). Do not reuse the
missing-function message (there is no table to index). If it is
a table, store it in `package.loaded[name]`. A later call reuses
`package.loaded` when it is still a table.

Each loaded table must expose the matching function
(`read_swivel_bearing_angle` / `set_electric_motor_speed`). A
missing or non-function value fails loud. Do not wrap peripherals
in this function. Do not copy child discovery, `getTargetAngle`,
`getSpeed`, or `setSpeed` logic.

### Read, error, write

Call `read_swivel_bearing_angle` with one table. If a resolved
bearing name exists, that table has `bearing_name`. Otherwise the
table is empty. Do not pass `rpm`, `target_degrees`, or
`tolerance_degrees` to the read.

Let `current` be that child's one Lua number. Compute signed
shortest-path error in Lua 5.2:

1. `delta = (target_degrees - current) % 360`
2. if `delta > 180` then `delta = delta - 360`
3. `error_degrees = delta`

Lua `%` is floor modulus, so a finite left-hand side with `360`
lands in `[0, 360)`. Java remainder negatives from the child are
legal inputs to this step. Do not add 360 to `current` first. Do
not negate `current` because FACING is NEGATIVE. `delta == 180`
stays `+180`.

Let `tolerance` be the resolved non-negative number. Let
`write_rpm` be:

- `0` when `math.abs(error_degrees) <= tolerance`
- `rpm` when `error_degrees > tolerance`
- `-rpm` when `error_degrees < -tolerance`

`rpm` 0 yields `write_rpm` 0 on every branch.

Call `set_electric_motor_speed` with one table: `rpm` is
`write_rpm`. If a resolved motor name exists, that table also has
`motor_name`. Do not pass `target_degrees`, `bearing_name`, or
`tolerance_degrees` to the write.

Child `error(...)` propagates unchanged. Do not catch and rewrite
child messages. Do not `pcall` the children unless catching only
to re-raise the same message at level 0; prefer a direct call.

Return `error_degrees` as the only success value. Do not return
`write_rpm`. Do not `sleep`. Do not assemble, disassemble, lock,
or call `isAssembled`.
Do not inspect lock. Locked is not checked. The child read still
returns the stored number; this step still writes `write_rpm`.

Do not wait for Simulated to add cog RPM into
`targetAngleDegrees`. Do not wait for
`ElectricMotorBlockEntity.tick()` to copy `cc_new_rpm` into
`motorSpeed`. Do not re-read the children after the write to
confirm either lag is gone. Those waits are not this step.

This function does not call `getSpeed` or `setSpeed` itself.
Every success path that reaches the write calls
`set_electric_motor_speed`, including `write_rpm` 0. That
child's `getSpeed` is `mainThread`; the Lua call yields. That
yield is in-contract on every rotate that reaches the write,
including the RPM-0 stop and the skip-same return that never
calls `setSpeed`. When that child writes, `setSpeed` is a
second main-thread yield. Envelope and input failures never
load children and take no child yield. A read-child failure
never reaches the write; it may already have yielded if that
getter is main-thread.

Read Swivel Bearing Angle's native getter is not marked
`mainThread`. Tolerate a yield if a pack overlay changes that.

Aim cannot treat one axis step as a non-yielding return. One
success that reaches the write costs at least the motor child's
`getSpeed` wait. A change write costs that wait plus `setSpeed`.

Do not verify kinetic connectivity. `bearing_name` and
`motor_name` identify which child wrap to read and write; they
do not assert shaft membership. Do not use motion, `sleep`,
`getSpeed` vs `getTargetAngle`, assemble/lock, or FACING as a
stand-in for connectivity. A crossed pair is not a distinct
failure of this command.

### Preconditions

- A Simulated swivel bearing and a Create Addition electric motor
  are attached (wired modem clicked), or the callee discovery
  rules are satisfied by names.
- `opts` is a table of the keys above.
- `target_degrees` and `rpm` are finite Lua numbers.
- `bearing_name` and `motor_name` inside `opts` are strings or
  absent.
- `tolerance_degrees` inside `opts` is a non-negative finite Lua
  number or absent.
- The two child modules load and expose their commands.

### Postconditions

- Success is exactly one Lua number, degrees, the signed
  shortest-path error computed from the child read and
  `target_degrees`.
- After success, Set Electric Motor Speed was called with
  `write_rpm` as specified above.
- After success, this function does not claim the stored field
  already equals `target_degrees`.
- After success, this function does not claim `getSpeed` already
  equals `write_rpm`.
- After success that reached the write, Set Electric Motor
  Speed already performed its `getSpeed` main-thread wait, and
  `setSpeed` when that child wrote. This function does not add
  a wait for Simulated integration or `cc_update_rpm`.
- After success, this function does not claim it returned
  without yielding.
- No second return value.
- No table wrapper.

### Invariants

- This function does not wrap peripherals.
- This function does not assemble, lock, or fire.
- This function does not read radar tracks.
- This function does not `sleep`.
- This function does not wait for Simulated integration or
  `cc_update_rpm` apply.
- This function does not suppress the motor child's
  `getSpeed` / `setSpeed` main-thread yields.
- This function does not verify kinetic connectivity between
  the named motor and the named bearing.
- This function does not negate the child angle for FACING.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message. Child failures keep the child prefix.

- Extra or missing arguments:
  `Rotate Bearing Toward Angle: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Rotate Bearing Toward Angle: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Rotate Bearing Toward Angle: unknown input '<key>'`
- Present `bearing_name` not a string:
  `Rotate Bearing Toward Angle: bearing_name must be a string or
  nil, got <type>`
- Present `motor_name` not a string:
  `Rotate Bearing Toward Angle: motor_name must be a string or nil,
  got <type>`
- `target_degrees` missing:
  `Rotate Bearing Toward Angle: target_degrees is required`
- `target_degrees` not a number:
  `Rotate Bearing Toward Angle: target_degrees must be a number, got <type>`
- `target_degrees` NaN:
  `Rotate Bearing Toward Angle: target_degrees must be a finite number, got nan`
- `target_degrees` infinity:
  `Rotate Bearing Toward Angle: target_degrees must be a finite number, got inf`
- `rpm` missing:
  `Rotate Bearing Toward Angle: rpm is required`
- `rpm` not a number:
  `Rotate Bearing Toward Angle: rpm must be a number, got <type>`
- `rpm` NaN:
  `Rotate Bearing Toward Angle: rpm must be a finite number, got nan`
- `rpm` infinity:
  `Rotate Bearing Toward Angle: rpm must be a finite number, got inf`
- Present `tolerance_degrees` not a number:
  `Rotate Bearing Toward Angle: tolerance_degrees must be a number
  or nil, got <type>`
- `tolerance_degrees` NaN:
  `Rotate Bearing Toward Angle: tolerance_degrees must be a finite
  number, got nan`
- `tolerance_degrees` infinity:
  `Rotate Bearing Toward Angle: tolerance_degrees must be a finite
  number, got inf`
- `tolerance_degrees` negative:
  `Rotate Bearing Toward Angle: tolerance_degrees must be >= 0, got <value>`
- Child module `dofile` throw:
  `Rotate Bearing Toward Angle: failed to load '<name>': <original>`
- Child module `dofile` returned a non-table:
  `Rotate Bearing Toward Angle: module '<name>' must be a table, got <type>`
- Child command missing:
  `Rotate Bearing Toward Angle: module '<name>' has no function <command>`

Read Swivel Bearing Angle and Set Electric Motor Speed failures
keep those pages' messages.

### Non-failures

- Absolute error inside the resolved tolerance is not a failure;
  write RPM 0 and return the leftover error.
- `rpm` 0 is not a failure.
- Negative `rpm` is not a failure (inverted build polarity).
- Negative `target_degrees` and negative child angles are not
  failures.
- Unassembled bearing is not a failure.
- A locked bearing is not a failure.
- Visual or physics pose lag is not a failure.
- Ticket 3 skip-same, out-of-range clamp, unpowered, POWERED, and
  post-write `getSpeed` lag are not failures of this function.
- The motor child's `getSpeed` yield, and `setSpeed` when it
  writes, are not failures of this function.
- A yield from Read Swivel Bearing Angle if that getter is
  main-thread is not a failure of this function.
- Wrong motor/bearing pairing (no kinetic connectivity, including
  a crossed yaw/pitch pair) is not a failure of this function.
- High RPM overshoot on a later Simulated tick is not a failure of
  this step.

### Sanitization

- Names are strings or absent. Empty string is absent. Any other
  Lua type fails loud. No `tostring`. No wrap table as a name.
  That empty-string-is-absent rule is name-only. A present empty
  string for `tolerance_degrees` is not absent and is not 1; it
  fails as a non-number.
- `opts` must be a table. Extra arguments, omitted `opts`, nil
  `opts`, a non-table `opts`, or an unknown key fail loud as
  envelope failures.
- `target_degrees`, `rpm`, and present `tolerance_degrees` are not
  rounded. Non-finite numbers fail loud. Negative tolerance fails
  loud.
- The child angle is not FACING-negated, not converted to radians,
  and not forced into `[0, 360)` before the `%` step.
- `write_rpm` is not clamped to the motor range. That clamp stays
  on Set Electric Motor Speed.

## Why

Native Simulated ComputerCraft cannot set the stored field. Ticket
3 is the kinetic write. Ticket 2 is the stored-field read. This
function is the one-axis composition. A blocking `sleep` until
arrival would freeze yaw while pitch waited, and would mix control
with a wait-for-integrate that neither child owns. Aim loops.

"Do not wait for a motor tick" is ticket 3's wait-for-apply
ban: do not sit until `cc_update_rpm` becomes `motorSpeed`.
It is not a claim that Lua returns in the same computer tick.
Ticket 3 already yields on `getSpeed` on every write this
function issues. A second `sleep` until the stored field
moves would still freeze yaw while pitch waited. Child
`mainThread` yields are the CC: Tweaked peripheral contract.
`sleep` until arrival is a different product. Aim must budget
at least one motor `getSpeed` wait per axis step that reaches
the write, plus `setSpeed` when the speed command changes,
plus a possible read yield.

Polarity cannot be read from the native wrap. FACING-negative
negate is already in the child number. A second flip here would
break POSITIVE-facing bearings. Signed `rpm` as "increase the
stored field" is the build's wiring, including gear inversions.

Default tolerance `1` is wider than one tick at 1 RPM on a 1:1 cog
(Create `convertToAngular` is 0.3 deg/tick per RPM) and still small
for a gun. This function does not hard-code 0.3 into `write_rpm`.
Gearing belongs in the caller's `rpm`. High RPM overshoots; that
is a caller choice of `|rpm|` and tolerance, not a second scheduler
inside this step.

One returned number matches one fact. Arrived is
`abs(error) <= tolerance` using the same tolerance this step used
to stop.

A name is optional because a bench computer may have one swivel
and one motor. A gun has two of each. Discovery stays on the
children.

Names pick which children to call. They do not prove that motor
is on that bearing's kinetic network. Aim owns that wiring.

## SOLID

- Single responsibility: one closed-loop step on one axis. No
  aim of two bearings, no fire, no radar.
- Compose, don't extend: calls Read Swivel Bearing Angle and Set
  Electric Motor Speed. Does not copy their wraps.
- No caller-identity branching: yaw and pitch take the same step.
  Names pick which children to call. Sign of `rpm` picks polarity.

## Compatibility

Advanced. May call basic workspace functions. Must not call other
advanced or high-level workspace functions. Aim Turret At Target
may call this.
