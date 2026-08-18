# How Should A ComputerCraft Program Set Create Addition Electric Motor Speed Without Tripping The Motor's Write Rate Limit?

A ComputerCraft program must set a Create Crafts and Additions electric
motor's RPM so a Simulated swivel bearing turns. Upstream docs still
warn that `setSpeed` throws if called too often. This paper asks how
that write should work on Amazeballs without that throw.

## Context

Native Simulated `swivel_bearing` is read-only for angle. Kinetic
input turns the bearing. On Amazeballs that write is a Create Crafts
and Additions electric motor (`electric_motor`). Ticket 1's pack list
is Minecraft 1.21.1 (Create Radar 0.4.9.4, CC: Tweaked 1.120.0,
Simulated 1.3.0). Create Addition on that line is the `1.21.1`
branch, not `main` (1.16 `ElectricMotorTileEntity`).

Ticket 5 will close the loop with ticket 2's angle read. This ticket
is only the speed write.

## Known Approaches

### Scroll The Motor In World

The block has a scroll speed. A script cannot turn that scroll from
Lua except through the peripheral. Rejected as the write path.

### Create Rotation Speed Controller Via Digital Adapter

Create Addition's digital adapter can `setTargetSpeed` on an RSC.
The gun's kinetic source in this product is the electric motor, not
an RSC behind an adapter. Wrong block.

### Call `rotate` / `translate` Instead Of `setSpeed`

Those methods optionally call `setSpeed` and then return a duration.
Closed-loop aim wants a speed command, not a timed rotate. Rejected
for this function.

### Trust `main` Anti-Spam (`cc_antiSpam` = 5 Per Second)

On Create Addition `main` (1.16), `setRPM` returns `cc_antiSpam > 0`.
`lazyTick` refills that counter to 5. Distinct-speed writes throw
`Speed is set too many times per second (Anti Spam).` Same-speed
`setSpeed` returns before `setRPM`.

Amazeballs is 1.21.1. `ElectricMotorBlockEntity.setRPM(float)` always
returns `true`. `lazyTick` does not refill a write budget.
`cc_antiSpam` is gone. `ElectricMotorPeripheral.setSpeed(double)`
still contains the throw if `setRPM` returns false. That branch is
dead on this pack. A Lua `sleep(1)` retry designed for the 1.16
budget would be a neighboring product's cope, not this write.

Upstream `COMPUTERCRAFT.md` on `1.21.1` still documents the throw.
The Java is the contract for "will it trip."

### Skip Same Speed, Then `setSpeed`

Create Addition `1.21.1` `ElectricMotorPeripheral` marks both
`getSpeed` and `setSpeed` `@LuaFunction(mainThread = true)`. CC:
Tweaked runs those methods through
`ILuaContext.executeMainThreadTask`: the computer waits for the
next server tick. `getType` is the motor method that is not
main-thread.

After wrap and a finite `rpm`, this command always calls `getSpeed`
from Lua. That yield is in-contract on every such call, including
the equal-speed skip. Envelope, unknown-key, `rpm`-type, and
discovery failures never reach `getSpeed` and take no `getSpeed`
yield.

`getSpeed` calls `getRPM()`, which returns the commanded field
`motorSpeed` as Java `float`. Kinetic output is
`getGeneratedSpeed()`: when `active` is false that value is 0
(then FACING conversion). `tick()` clears `active` when stored
energy cannot cover consumption, or when the block state `POWERED`
is true. `setRPM` does not consult energy or `POWERED` and still
returns true on this pack. An unpowered motor or a redstone-stopped
motor still takes skip / `setSpeed`. Skip compares the request to
`motorSpeed`, so a stopped shaft whose command already matches
still skips. This Lua function does not read energy, `POWERED`, or
generated speed. Success means the command was skipped or
`setSpeed` returned. The shaft may remain 0.

Lua: wrap `electric_motor`. Optional `motor_name`, required `rpm`.
Discover exactly one motor when the name is omitted (same rule as
tickets 1 and 2). The gun has two aim motors; pass names.

Requested RPM is a Lua number (double). Skip predicate: after
`getSpeed` type-checks as a finite Lua number, skip `setSpeed`
only when that number `== rpm`. That is the whole predicate. No
conversion, no epsilon, no clamp of either side, no wait for the
motor tick, no `string.pack` / `string.unpack` narrowing to IEEE
754 binary32.

Always write (call `setSpeed`) when Lua `==` misses, including:

- Delay. `ElectricMotorPeripheral.setSpeed` returns early when
  `(float) rpm == getSpeed()`. Otherwise it calls
  `setRPM((float) rpm)`. `ElectricMotorBlockEntity.setRPM` clamps
  to `[-ELECTRIC_MOTOR_RPM_RANGE, ELECTRIC_MOTOR_RPM_RANGE]`,
  stores that float in `cc_new_rpm`, sets `cc_update_rpm = true`,
  and returns `true`. It does not assign `motorSpeed`. `getSpeed`
  reads applied RPM (`motorSpeed`) only. The next `tick()` (every
  game tick; not `lazyTick`) copies `cc_new_rpm` into `motorSpeed`
  and `generatedSpeed`, then `updateGeneratedRotation()`. Until
  that `tick()`, `getSpeed` is the previous speed. A later call
  with the same `rpm` before that `tick()` may call `setSpeed`
  again. That extra write is in-contract. This function does not
  store last requested RPM. Java `(float) rpm == getSpeed()` then
  return has the same hole. Lua cannot lean on that no-op to
  coalesce pending requests.
- Clamp. Lua does not clamp. After an out-of-range write,
  `getSpeed` is the clamped `motorSpeed`, not the request. A
  repeated out-of-range `rpm` is not Lua-equal to that value, so
  every such call reaches `setSpeed`. Java's early return
  `(float) rpm == getSpeed()` has the same hole. Do not remember
  the last request and skip from that. A scroll, another computer,
  or a later `setSpeed` from `rotate` / `translate` can change
  `motorSpeed` while the remembered request stays out-of-range;
  skipping would leave the motor where it is. Do not clamp in Lua
  and then compare. The wrap has no max-RPM method. Hard-coding
  256 from `COMPUTERCRAFT.md` invents a second limit the block
  entity already owns. Config can differ. Those always-write
  out-of-range calls are not a Lua failure.
- Float mismatch. `getSpeed` is a Java `float` in Lua. `rpm` is a
  Lua number (double). Java's no-op is
  `(float) rpm == getSpeed()`. Those can disagree. Lua miss still
  calls `setSpeed`. Java may then no-op. That is in-contract. This
  command does not narrow `rpm` through `string.pack("f")` to
  match the JVM `(float)` cast.

Then `pcall` `setSpeed` with the original `rpm` on a miss: fail
loud on throw, no sleep-and-retry, no Lua clamp. A non-number,
NaN, or infinity fails loud before the peripheral.

This command does not wait for the applying `tick()`. It does not
re-read `getSpeed` after `setSpeed`. It does not `sleep` until
they match. A caller that `getSpeed`s immediately after success
may see the previous value. That is allowed. Waiting until
`getSpeed` matches is a neighboring wait-for-apply, not this
write. Success means the request was accepted on this call
(skipped because applied speed already matched under Lua `==`, or
`setSpeed` returned). It does not mean `getSpeed` already equals
`rpm`.

Calling `getSpeed` yields. Skip-same still does that on every call
that reaches the check, including when it then skips `setSpeed`.
When Lua `==` fails, `setSpeed` yields a second time. Java
`setSpeed` calling `getSpeed()` internally is already on the main
thread; that is not a second Lua yield.

Skip-same is the Lua rule: do not call `setSpeed` when `getSpeed`
already equals `rpm`. On the Lua-equal path the computer still
waits on one main-thread peripheral call (`getSpeed` in place of
`setSpeed`). On the change path it waits on two. Equal-speed
success is no setter. The skip check is still a main-thread wait.
Always calling `setSpeed` on the equal path is also one wait.
Skip-same is not fewer main-thread waits as a justification, not a
coalescer for in-flight requests, and not a rate-limit defense
that covers out-of-range repeats.

On this pack the extra write cannot trip a rate limit: `setRPM`
always returns true. The documented anti-spam throw cannot fire.
The throw did not only exist for distinct writes. On `main`
(1.16), same requested RPM before `tick()` still reaches `setRPM`
and would burn a `cc_antiSpam` token. Distinct-versus-same is
applied-speed, not requested-speed. If a fork still throws that
message on distinct writes, including out-of-range repeats, fail
loud; do not sleep-and-retry.

Do not call `stop` as a special case; `rpm` 0 is `setSpeed(0)`
after the skip check. Do not call `rotate` or `translate`. Do not
wrap `servo_motor` (a different 1.21.1 peripheral).

## Recommendation

Lua: `bearing_turret.set_electric_motor_speed(opts)`. Arity 1.
`opts` is a table. Keys: `motor_name` optional string, `rpm`
required finite number. Unknown keys fail loud. Omit, nil, or a
second argument fail loud. A positional RPM is not legal.

Find one `electric_motor`. Name omitted, nil, or `""`: exactly one
attached. Zero or two-plus fail loud. Named wrap nil or wrong type
fail loud.

Then skip when applied `getSpeed` equals `rpm` under raw Lua `==`.
Do not remember last requested RPM. A same-`rpm` call before the
motor tick may write again. Do not justify skip-same as fewer
main-thread waits. Success is no Lua values. The caller of
`bearing_turret.set_electric_motor_speed` must tolerate a tick
wait whenever the command reaches `getSpeed`.

## What Would Falsify This

- Amazeballs jar still runs 1.16 `setRPM` with `cc_antiSpam`. Then
  allowing same-`rpm` re-entry before `tick()` can trip the throw,
  and this contract is wrong for the ticket question. A retry
  window or last-request memory would then be required.
- In-game `setSpeed` rejects non-integers. Then allowing any finite
  Lua number is wrong.
- In-game type string is not `electric_motor`.
- If `getSpeed` were not `mainThread`, skip-same would avoid a
  main-thread call on the equal path. On this Amazeballs jar it is
  `mainThread`.
- In-game, two same-`rpm` calls before the motor tick throw. Then
  the extra write is not in-contract on this pack.
- Repeated out-of-range `setSpeed` throws the documented anti-spam
  message on this pack. Then `getSpeed == rpm` skip is not enough
  to keep that throw from firing. Fail loud still applies. A
  last-request cache or Lua clamp-then-compare would be a
  different write product.
- `getSpeed` returns generated shaft speed, 0 when inactive. Then
  skip-same would keep writing a non-zero `rpm` on an unpowered or
  redstone-stopped motor, and treating those motors as
  success-and-skip would be wrong.
- The Amazeballs jar assigns `motorSpeed` inside `setRPM`. Then
  the post-success lag claim is wrong.

## Sources

- [Create Addition 1.21.1 COMPUTERCRAFT.md](https://github.com/mrh0/createaddition/blob/1.21.1/COMPUTERCRAFT.md)
- [ElectricMotorPeripheral.java (1.21.1)](https://github.com/mrh0/createaddition/blob/1.21.1/src/main/java/com/mrh0/createaddition/compat/computercraft/ElectricMotorPeripheral.java)
- [ElectricMotorBlockEntity.java (1.21.1 setRPM always true)](https://github.com/mrh0/createaddition/blob/1.21.1/src/main/java/com/mrh0/createaddition/blocks/electric_motor/ElectricMotorBlockEntity.java)
- [LuaFunction.mainThread (CC: Tweaked 1.21.x)](https://tweaked.cc/mc-1.21.x/javadoc/dan200/computercraft/api/lua/LuaFunction.html)
- [ILuaContext.executeMainThreadTask](https://tweaked.cc/mc-1.21.x/javadoc/dan200/computercraft/api/lua/ILuaContext.html)
- Ticket 1 paper pack list: Minecraft 1.21.1 Amazeballs jars
