# How Should A ComputerCraft Program Fire The Rotating Barrel Once It Is Aimed?

A ComputerCraft program must fire a Create Big Cannons rotating
autocannon after Simulated bearings have already aimed it. This
paper asks how that one shot is triggered on Amazeballs without
inventing a CBC ComputerCraft peripheral.

## Context

The gun sits on Simulated swivel bearings. Ticket 1 established
that Create Radar yaw and pitch controllers drive CBC mounts, not
those bearings. Tickets 2 and 3 are the angle read and the motor
write. Ticket 5 will close the aim loop. This ticket is only the
trigger.

The rotating barrel is a CBC autocannon assembled on a CBC cannon
mount or fixed cannon mount. The mount still exists so the
autocannon can assemble and receive a fire signal. Simulated
bearings own aim. CBC mount yaw and pitch shafts are not this
product's write path.

Ticket 1's pack list is Minecraft 1.21.1 (Create Radar 0.4.9.4,
CC: Tweaked 1.120.0, Simulated 1.3.0). CBC on that line is the
`create-v6-1.21.1` tree. CC: Tweaked 1.120.0 includes the
`redstone` module and, since 1.114.0, `redstone_relay`.

## Known Approaches

### Wrap A Native CBC Fire Peripheral

The CBC `create-v6-1.21.1` tree has no `LuaFunction`, no
ComputerCraft package, and no cannon-mount peripheral. There is
nothing to wrap on Amazeballs from CBC itself. Inventing a
`cannon_mount.fire` method here would be a fake API.

### Call CC:CBC Or Create Big Cannons: Peripherals

Third-party addons (CC:CBC type `cannon_mount`, cbcperipheral
types `cbc_cannon_mount` / `cbc_fixed_cannon_mount`) add `fire`.
Ticket 1's Amazeballs jar list does not include those mods. Those
APIs also expose `setTargetAngles` / `setComputerControl`, which
take over CBC mount aim. This product rejected CBC mount aim.
Using those addons for fire would bind this leaf to a peripheral
the pack has not listed and to an aim path this tree does not
use. Rejected.

### Pulse ComputerCraft `redstone.setOutput`

`setOutput(side, true)` emits analog strength 15. CBC
`CannonMountBlock.tick` reads `level.getSignal` on the fire face
(`HORIZONTAL_FACING`) and passes that integer as `firePower`.
`MountedAutocannonContraption.onRedstoneUpdate` calls
`breech.setFireRate(firePower)`. Strength 15 is 300 RPM (4-tick
cooldown). A pulse that lasts two entity ticks can fire twice.
Binary on is a spray, not one shot. Rejected as the pulse
strength.

### Hold Analog 15 Until The Caller Stops

That is a fire-rate write, not fire-once. A later hold-to-spray
command would own it. This leaf drops the signal itself.

### Player Seat Click / Handle Autocannon

Handle-mode autocannons fire from
`ServerboundFiringActionPacket` when a player is seated.
`canBeFiredOnController` is false for handle mode. A ComputerCraft
program is not that player. Rejected.

### Drive The Barrel Motor Instead Of The Mount Fire Face

Autocannon `fireShot` gates on `breech.canFire()`: `fireRate > 0`
and `firingCooldown <= 0`. It does not read kinetic RPM. Spinning
the barrel loop is a precondition the operator or a sibling motor
write already meets. Setting aim-motor RPM, or a barrel-motor
RPM, does not pull the trigger. Rejected as the fire path.

### Pulse Analog Strength 1 For Two Game Ticks, Then 0

CBC's native trigger is analog redstone on the **fire face**,
not the assembly face.

`CannonMountBlock`: fire face is `HORIZONTAL_FACING`. Assembly
face is the opposite. `FixedCannonMountBlock.getFiringFace` is
the opposite of `getAssemblyFace`. Powering assembly assembles
or disassembles. This function must not write the assembly face.

While the mount is running, `onRedstoneUpdate` forwards
`firePower` into the mounted contraption on every mount tick,
not only on a rising edge. Autocannon `setFireRate` clamps 0-15.
`FIRE_RATES[0]` is 120 ticks (10 RPM). `canFire` is true when
that rate is at least 1 and cooldown is 0. Each server tick the
mounted autocannon calls `fireShot`. After a real shot,
`handleFiring` sets cooldown to 120 ticks at rate 1. A two-tick
hold at strength 1 can produce at most one shot. Strength 0
stops further shots.

Big-cannon `MountedBigCannonContraption.onRedstoneUpdate` fires
on a rising edge (`togglePower && firePower > 0`). That is a
different product. This leaf is the rotating autocannon.

ComputerCraft: `redstone.setAnalogOutput(side, value)` with
value 1, then `sleep(0.1)` (two game ticks at 20 tps), then
`setAnalogOutput(side, 0)`. Two writes in the same computer tick
leave the world seeing only 0. The sleep is the pulse, not a
retry. `setAnalogOutput` on the computer module is not a
main-thread peripheral yield. The sleep is the wait.

`setOutput(true)` is strength 15. Do not call it. Do not call
`setBundledOutput`.

A computer whose own faces do not touch the fire face uses a
CC: Tweaked `redstone_relay` (type `redstone_relay`, since
1.114.0) clicked with a wired modem. Same analog pulse on that
wrap. Omit `relay_name` to use the computer `redstone` API. Do
not discover a relay when the name is omitted.

`side` is required. A computer always has six faces. There is
no discover-exactly-one-side rule. Legal strings: `top`,
`bottom`, `left`, `right`, `front`, `back`.

Success is no Lua return values. Success means the pulse ran.
It does not mean a projectile left the barrel. Empty ammo,
cooldown, a disassembled mount (`running` false skips the
contraption update), or a wire on the wrong face are silent in
CBC. This function does not wrap the mount, so it cannot observe
those. It does not fail loud on them.

## Recommendation

Lua: `bearing_turret.fire_rotating_barrel(opts)`. Arity 1.
`opts` is a table. Keys: `side` required string, `relay_name`
optional string. Unknown keys fail loud. Omit, nil, or a second
argument fail loud. A positional side is not legal.

`side` must be one of the six ComputerCraft side names. Any
other string, or a non-string, fails loud. No `tostring`.

Omit, nil, or `""` for `relay_name`: call
`redstone.setAnalogOutput`. Named wrap nil or type not
`redstone_relay` fails loud. Named wrap: `pcall`
`setAnalogOutput` on that wrap. Throw fails loud with the
original message.

Pulse: analog 1, `sleep(0.1)`, analog 0. Use `sleep`, not
`os.pullEvent`. Do not skip the off write if the on write
succeeded. If the off write throws, fail loud; the fire face
may still be at 1. Do not restore a previous analog value; this
command owns the side for the pulse.

Wire that side (computer or relay) to the CBC mount **fire**
face only. Prefer a fixed cannon mount when Simulated bearings
own aim. Do not call `setSpeed`. Do not wrap `cannon_mount`.

## What Would Falsify This

- Amazeballs jars include CC:CBC or cbcperipheral as the pack's
  fire path, and CBC redstone on the fire face is dead on that
  pack. Then this pulse is the wrong API.
- In-game `peripheral.getMethods` on a CBC mount lists `fire`
  from CBC itself. Then the "no native peripheral" claim is
  wrong.
- Autocannon `canFire` requires kinetic RPM. Then pulsing
  redstone without a spinning barrel motor is never a shot, and
  this function would need a motor sibling.
- A one-tick pulse at analog 1 never reaches `setFireRate`
  before analog 0. Then two ticks is still too short.
- Analog 1 held two ticks fires more than once on this pack.
  Then the rate table changed.
- `sleep(0.1)` is not two game ticks on CC: Tweaked 1.120.0.
  Then the hold length is wrong.
- In-game type string for the relay is not `redstone_relay`.

## Sources

- [CannonMountBlock.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannon_control/cannon_mount/CannonMountBlock.java)
- [CannonMountBlockEntity.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannon_control/cannon_mount/CannonMountBlockEntity.java)
- [FixedCannonMountBlock.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannon_control/fixed_cannon_mount/FixedCannonMountBlock.java)
- [MountedAutocannonContraption.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannon_control/contraption/MountedAutocannonContraption.java)
- [MountedBigCannonContraption.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannon_control/contraption/MountedBigCannonContraption.java)
- [AbstractAutocannonBreechBlockEntity.java (create-v6-1.21.1)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/cannons/autocannon/breech/AbstractAutocannonBreechBlockEntity.java)
- [CC: Tweaked 1.21.y redstone module](https://tweaked.cc/mc-1.21.y/module/redstone.html)
- [CC: Tweaked 1.21.y redstone_relay](https://tweaked.cc/mc-1.21.y/peripheral/redstone_relay.html)
- [CC:CBC README](https://github.com/Drakon7009/CC-CBC/blob/master/README.md)
- [cbcperipheral Peripherals wiki](https://github.com/nosqd/cbcperipheral/wiki/Peripherals)
- [Ticket 1 paper pack list](/research/1/paper)
