# Set Electric Motor Speed

## What

Set a Create Crafts and Additions electric motor's commanded speed.

## How

Lua call: `bearing_turret.set_electric_motor_speed(opts)`. Arity is
exactly 1. Zero arguments, a second argument, or `opts` that is
not a table fail loud. A number as argument 1 is not positional
RPM. A wrap table is not `opts`.

`opts` a table: read `rpm` and `motor_name` only. Any other key
fails loud, including array index `1`. `rpm` is required. Omit,
nil, or `""` for `motor_name` means discover.

`rpm` must be a Lua number and finite. `type(rpm) ~= "number"`
fails loud. `rpm ~= rpm` (NaN) fails loud. `rpm == math.huge` or
`rpm == -math.huge` fails loud. Do not `tostring`. Do not clamp
to the motor range. Java `setRPM` clamps on the block entity.

Find one peripheral of type `electric_motor`. If a name is given,
wrap that name and require that type. If no name is given, find
every attached peripheral of that type; require exactly one. Do
not accept type `servo_motor`.

Call `getSpeed` on that wrap (`pcall`). `getSpeed` is `mainThread`.
The Lua call yields. The caller must tolerate a tick wait. This
yield happens on every invocation that reaches this call, including
the equal-speed return that does not call `setSpeed`. On throw,
fail the write with the original message in the diagnostic.
Type-check number after a successful call. Non-number, NaN, or
infinity fail loud.

`getSpeed` returns commanded `motorSpeed`. Generated shaft speed is
a different field and can be 0 while this number is not. Skip uses
`getSpeed`. Unpowered and redstone-`POWERED` motors keep
`motorSpeed` and still take this path. Do not read energy,
`POWERED`, or generated speed. Do not wait for `active`.

Skip: after `getSpeed` type-checks as a finite Lua number, skip
`setSpeed` only when that number `== rpm`. No conversion, no
epsilon, no clamp, no `string.pack("f")`. `getSpeed` after clamp is
the clamped value. Lua `==` with the request is then false. Repeat
out-of-range calls `setSpeed`.

Otherwise `pcall` `setSpeed(rpm)`. `setSpeed` is `mainThread` and
yields. The skip check yields on every call that reaches it.
`setSpeed` is a second yield only when Lua `==` fails. On throw,
fail loud with the original message. Do not `sleep` and retry. The
documented anti-spam throw
(`Speed is set too many times per second (Anti Spam).`) is a
fail, not a retry. On success, discard any return values and
return with no Lua values.

`setRPM` stores `cc_new_rpm` and sets `cc_update_rpm`; `motorSpeed`
updates on the next `tick()`. `getSpeed` reads `motorSpeed`, so a
post-success read may still be the previous speed. Do not wait. Do
not re-read `getSpeed` after `setSpeed`. Do not `sleep`. Do not
treat the lag as a failure.

Do not call `stop`. RPM 0 is `setSpeed(0)` after the skip check.
Do not call `rotate` or `translate`.

### Preconditions

- A Create Crafts and Additions electric motor is attached to the
  computer (wired modem clicked).
- The peripheral type string is `electric_motor`.
- `opts` is a table of `rpm` and optional `motor_name`.
- `rpm` is a finite Lua number.
- `motor_name` inside `opts` is a string or absent.

### Postconditions

- Success is no Lua return values.
- After success, either `setSpeed` was not called because
  `getSpeed` already equaled `rpm` under raw Lua `==`, or
  `setSpeed(rpm)` returned without throw. Out-of-range success
  always called `setSpeed`.
- This function does not return the new speed.
- After success, this function does not claim `getSpeed` already
  equals `rpm`.
- After a `setSpeed` path success, `getSpeed` may still return the
  previous `motorSpeed` until the next
  `ElectricMotorBlockEntity.tick()` applies `cc_new_rpm`.
- After a skip path success, the pre-write `getSpeed` already
  `== rpm`. This function does not re-read after return.
- This function does not wait for a motor tick.
- After success, commanded speed was skipped or written. Generated
  shaft speed may still be 0.

### Invariants

- This function does not read bearings, tracks, or fire.
- This function does not call `rotate`, `translate`, or `stop`.
- This function does not wrap a servo motor.
- This function does not read energy, `POWERED`, or generated
  speed.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra or missing arguments:
  `Set Electric Motor Speed: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Set Electric Motor Speed: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Set Electric Motor Speed: unknown input '<key>'`
- Present `motor_name` not a string:
  `Set Electric Motor Speed: motor_name must be a string or nil, got <type>`
- `rpm` missing:
  `Set Electric Motor Speed: rpm is required`
- `rpm` not a number:
  `Set Electric Motor Speed: rpm must be a number, got <type>`
- `rpm` NaN:
  `Set Electric Motor Speed: rpm must be a finite number, got nan`
- `rpm` infinity:
  `Set Electric Motor Speed: rpm must be a finite number, got inf`
- No motor when discovering:
  `Set Electric Motor Speed: no electric_motor attached`
- Two or more motors and no name:
  `Set Electric Motor Speed: <n> electric_motor attached, pass motor_name`
- Named wrap nil:
  `Set Electric Motor Speed: named motor '<name>' is not attached`
- Named wrap type not `electric_motor`:
  `Set Electric Motor Speed: named motor '<name>' is type
  '<type>', expected electric_motor`
- `getSpeed` throw:
  `Set Electric Motor Speed: getSpeed threw on motor '<name>': <original>`
- `getSpeed` non-number:
  `Set Electric Motor Speed: getSpeed on motor '<name>' returned
  <type>, expected number`
- `getSpeed` NaN:
  `Set Electric Motor Speed: getSpeed on motor '<name>' returned nan`
- `getSpeed` infinity:
  `Set Electric Motor Speed: getSpeed on motor '<name>' returned inf`
- `setSpeed` throw:
  `Set Electric Motor Speed: setSpeed threw on motor '<name>': <original>`

Discovered wrap uses the attached peripheral name in diagnostics.

### Non-failures

- Current speed already equal under raw Lua `==` is not a failure;
  skip the write.
- RPM 0 is not a failure.
- Negative RPM is not a failure.
- A value outside the motor's configured RPM range is not a Lua
  failure; the block entity clamps; skip-same does not apply;
  every call writes.
- Unpowered / inactive motor is not a failure.
- Redstone-`POWERED` motor is not a failure.
- Shaft speed 0 while commanded RPM is non-zero is not a failure.

### Sanitization

- Names are strings or absent. Empty string is absent. Any other
  Lua type fails loud. No `tostring`. No wrap table as a name.
- `opts` must be a table. Extra arguments, omitted `opts`, nil
  `opts`, a non-table `opts`, or an unknown key fail loud as
  envelope failures.
- `rpm` is not clamped, rounded, or converted. Non-finite numbers
  fail loud. No last-request cache. No binary32 narrow of `rpm`.
- `getSpeed` is not converted. Equality is Lua `==` on the two
  numbers. No clamp before compare.

## Why

Amazeballs is Create Addition `1.21.1`. `setRPM` always returns
true. The `main` (1.16) `cc_antiSpam` budget is gone. A sleep-and-
retry loop would be a neighboring product's cope. Skip-same covers
equal `getSpeed` and request under raw Lua `==` only. It does not
cover out-of-range repeats, pending-tick repeats, or float
mismatch. Equal current speed skips `setSpeed`; that skip still
paid `getSpeed`. Skip does not avoid the `getSpeed` yield. On this
pack the documented throw cannot fire. If a fork still throws that
message, fail loud so the caller sees it.

`rotate` and `translate` optionally call `setSpeed` and then wait.
Closed-loop aim wants a speed command, not a timed move.

A name is optional because a bench computer may have one motor. A
gun has two aim motors. Discover-when-exactly-one is the same rule
as Read Swivel Bearing Angle.

Clamping in Lua would hide the block entity's range and invent a
second limit. Rejected skip rules: last-request cache; clamp then
compare; `string.pack("f")` to match Java `(float)`. Non-finite
values never reach the peripheral.

Failing loud, sleeping, or extra-skipping on empty energy or
`POWERED` would invent a power gate this primitive does not own.
The write is the command. Kinetic apply stays on the block entity.

RPM 0 is a legal speed. Mapping it to `stop` would add a second
verb the ainterface does not list.

## SOLID

- Single responsibility: write one motor speed. No angle, no fire,
  no radar.
- Compose later: Rotate Bearing Toward Angle calls this. This page
  does not call it.
- No caller-identity branching: yaw motor and pitch motor take the
  same write. The name picks which wrap.

## Compatibility

Basic. May be called by advanced and high-level functions. Must not
call other workspace functions.
