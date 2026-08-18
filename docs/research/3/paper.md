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

`setSpeed` is `mainThread`. It no-ops when `(float) rpm == getSpeed()`.
`getSpeed` returns `motorSpeed` (`float`). Requested RPM is a Lua
number passed as Java `double`, then compared as float.

Lua: wrap `electric_motor`. Optional `motor_name`, required `rpm`.
Discover exactly one motor when the name is omitted (same rule as
tickets 1 and 2). The gun has two aim motors; pass names.

Call `getSpeed`. If it equals the requested RPM as Lua numbers after
both are numbers, skip `setSpeed`. Then `pcall` `setSpeed`. Success:
no return values. If the dead anti-spam throw ever fires (overlay or
fork), fail loud with that message. Do not sleep-and-retry. Any
other throw fails loud.

Do not clamp in Lua. `setRPM` clamps to
`[-ELECTRIC_MOTOR_RPM_RANGE, ELECTRIC_MOTOR_RPM_RANGE]` (docs still
say 256). A non-number, NaN, or infinity fails loud before the
peripheral.

Do not call `stop` as a special case; `rpm` 0 is `setSpeed(0)`.
Do not call `rotate` or `translate`. Do not wrap `servo_motor`
(a different 1.21.1 peripheral).

Skipping an equal speed is how this command avoids the documented
rate-limit throw: that throw only existed for distinct writes, and
on this pack it cannot fire. Equal-speed skip still avoids a useless
main-thread write.

## Recommendation

Lua: `bearing_turret.set_electric_motor_speed(opts)`. Arity 1. `opts`
is a table. Keys: `motor_name` optional string, `rpm` required
finite number. Unknown keys fail loud. Omit, nil, or a second
argument fail loud. A positional RPM is not legal.

Find one `electric_motor`. Name omitted, nil, or `""`: exactly one
attached. Zero or two-plus fail loud. Named wrap nil or wrong type
fail loud.

Then the skip / `setSpeed` path above. Success is no Lua values.

## What Would Falsify This

- Amazeballs jar still runs 1.16 `setRPM` with `cc_antiSpam`. Then
  skip-same is not enough and a retry window is required.
- In-game `setSpeed` rejects non-integers. Then allowing any finite
  Lua number is wrong.
- In-game type string is not `electric_motor`.
- `(float) rpm == getSpeed()` disagrees with Lua `==` on the two
  numbers this function compared. Then skip-same can still call
  `setSpeed` every time, or skip a real change.

## Sources

- [Create Addition 1.21.1 COMPUTERCRAFT.md](https://github.com/mrh0/createaddition/blob/1.21.1/COMPUTERCRAFT.md)
- [ElectricMotorPeripheral.java (1.21.1)](https://github.com/mrh0/createaddition/blob/1.21.1/src/main/java/com/mrh0/createaddition/compat/computercraft/ElectricMotorPeripheral.java)
- [ElectricMotorBlockEntity.java (1.21.1 setRPM always true)](https://github.com/mrh0/createaddition/blob/1.21.1/src/main/java/com/mrh0/createaddition/blocks/electric_motor/ElectricMotorBlockEntity.java)
- Ticket 1 paper pack list: Minecraft 1.21.1 Amazeballs jars
