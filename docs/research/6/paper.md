# How Should A ComputerCraft Program Aim Yaw And Pitch Simulated Bearings At A Radar Target Using A Ballistic Solution?

A ComputerCraft program must point a Simulated yaw bearing and a
Simulated pitch bearing at a Create Radar track. The angles to
command come from a ballistic solution. This paper asks how that
aim should work on Amazeballs without inventing peripherals or
owning Going Ballistic physics.

## Context

The gun sits on two stacked Simulated swivel bearings: one yaw
axis (world bearing on the XZ plane) and one pitch axis (world
elevation). Ticket 1 already chose to read tracks from a Create
Radar dish that is not on the gun. Ticket 2 reads each swivel's
stored servo target. Ticket 3 writes Create Addition electric
motor RPM. Ticket 5 closes one axis. Ticket 7 turns a track pose
into yaw and pitch numbers. This ticket applies those numbers to
both axes while the named radar target is still live.

Native Simulated `swivel_bearing` has no angle setter. Create
Avionics documents the same fact: the target is integrated from
kinetic input. Aim is therefore two closed-loop rotates, not a
`setAngle` on the gun.

Amazeballs pack from ticket 1: Minecraft 1.21.1, Create Radar
0.4.9.4, CC: Tweaked 1.120.0, Simulated 1.3.0 nested in the
aeronautics bundle. Create Addition is the 1.21.1 motor write
from ticket 3.

## Known Approaches

### Call Create Radar `yaw_controller.setAngle` And
`pitch_controller.setAngle`

Create Radar registers generic peripherals
`create_radar:yaw_controller` and
`create_radar:pitch_controller`. Each exposes `setAngle` /
`getAngle` (`@LuaFunction(mainThread = true)`). `setAngle` writes
`AutoYawControllerBlockEntity.setTargetAngle` (or the pitch
twin). Those block entities resolve a mount through
`CannonMountContext` (Create Big Cannons) and Clockwork phys
bearings (`MountKind.PHYS`). Public Create Radar copy still names
this the CBC cannon controller path.

The same yaw block entity, when Simulated is loaded, also calls
`SimulatedSwivelMountAdapter.resolve(this, Direction.Axis.Y)`.
That adapter looks for exactly one adjacent swivel whose FACING
axis matches, assembled and locked, then drives kinetic RPM
toward a world aim direction. Ticket 1 already recorded that
radar-driven aim failed on this client's Simulated gun. This
function does not retry that path.

Even if the adapter later worked, using it here would skip ticket
5's rotate command and would let the radar weapon network choose
the aim direction. This ticket's ballistic numbers come from the
caller. Radar `setAngle` is the wrong mouth.

### Call CC:CBC `cannon_mount.setTargetAngles`

CC:CBC (and similar CBC peripherals) expose `setTargetAngles`,
`setTargetYaw`, and `setTargetPitch` on type `cannon_mount`. The
gun is not on a CBC mount. Wrapping that peripheral would aim a
different machine.

### Drop In Create Aero Radar Java Controllers

Create Aero Radar is a separate addon. Its README states a turret
uses two stacked swivel bearings (yaw and pitch, two sub-levels)
and that each mechanical controller reads a radar lock, computes
a desired bearing angle, reads `getTargetAngleDegrees()`, and
sets generated RPM. That is the right mechanical picture. The
addon is not on Amazeballs. It also owns target-angle math and
the one-axis loop. Those are tickets 7 and 5. Do not add its
blocks.

### Compute Lead And Muzzle Physics In This Command

Create Big Cannons: Going Ballistic replaces CBC's projectile
velocity formula with Robins' cannon model. Its README lists
masses and powder. It does not register a ComputerCraft
peripheral. Lead, gravity on track velocity, and muzzle speed
belong to Compute Ballistic Aim (#7). This command receives the
resulting yaw and pitch. It does not re-derive them from a track
pose.

### Inline `getTargetAngle` And `setSpeed` In This Command

That is Rotate Bearing Toward Angle (#5). Aim composes that
command twice. Copying its internals would make the split a lie.

### Use Avionics `assemble` / Lock As Aim

Avionics can assemble, disassemble, and change locking mode. It
still has no angle setter. Assemble is not aim.

## Recommendation

Confirm a live Create Radar track this tick, then drive the yaw
swivel and the pitch swivel to caller-supplied bearing-local
degrees by calling `rotate_bearing_toward_angle` once per axis.

### Live Target

Call `bearing_turret.read_radar_tracks` through the ainterface
(already merged). Forward `radar_name` and `monitor_name`. Do not
wrap the dish inside this function.

The radar target is identity, not pose math:

- If `track_id` is a non-empty string, that id must appear in
  this tick's `tracks` list. Miss fails loud. Do not rotate.
- If `track_id` is omitted, nil, or `""`, use
  `selectedTrackId` from that read. Nil or empty selected id
  fails loud (no operator pick and no named id).
- A leftover selected id that is missing from this tick's list
  fails loud. Ticket 1 allows that miss on the read. Aim does
  not. Aiming at a ghost is not success.
- Do not use track `position` or `velocity` here. Do not convert
  world blocks into angles.

### Ballistic Numbers From The Caller

`yaw_degrees` and `pitch_degrees` are required finite Lua
numbers. They are bearing-local degrees for the yaw swivel and
the pitch swivel, the same scale ticket 2 returns from
`getTargetAngle`: rotation about that swivel's FACING, 0 at that
bearing's rest origin, not Minecraft yaw/pitch, not north. Ticket
7 produces those numbers. This command does not convert world
heading.

Do not clamp to a mount arc. Do not wrap to `[0, 360)` here.
Rotate owns one-axis motion. Pass the numbers through.

### Two Axes, Two Rotate Calls

The stacked-swivel layout is the live turret shape (Create Aero
Radar README; Simulated swivel wiki: side cog, center shaft
pass-through). Yaw is one `swivel_bearing`. Pitch is another.
Each has its own electric motor (ticket 3).

Call `bearing_turret.rotate_bearing_toward_angle` twice, through
the ainterface when ticket 5 has published it. Until then,
require the sibling module `rotate_bearing_toward_angle.lua`
without copying its loop, `getTargetAngle`, or `setSpeed`.

- First call: yaw. Forward `yaw_degrees` as that command's
  target angle, plus `yaw_bearing_name` and `yaw_motor_name`.
- Second call: pitch. Forward `pitch_degrees`,
  `pitch_bearing_name`, and `pitch_motor_name`.
- If the yaw call fails, do not call pitch. Fail loud with that
  error.
- If the two name pairs are omitted, rotate's own discovery
  applies. A gun with two swivels and two motors cannot discover
  "exactly one". Callers name the axes. This command does not
  invent a second discovery pass.

Do not call `read_swivel_bearing_angle` or
`set_electric_motor_speed` from this function. Those are rotate's
callees.

Do not wait for both axes to land inside a tolerance beyond what
rotate already does. One aim invocation is one pair of rotate
calls. Settle policy stays on rotate.

Do not fire. Fire Rotating Barrel is ticket 4.

### Call Shape

Lua: `bearing_turret.aim_turret_at_target(opts)`. Arity 1. `opts`
is a table. Success is no return values. Extra arguments, a
non-table `opts`, unknown keys, non-finite yaw or pitch, or a
present `track_id` that is not a string fail loud before any
child call.

`read_radar_tracks` and rotate both yield (`mainThread`
peripherals on the children). The caller must tolerate tick
waits.

### Why This Split

Who: the gun computer. What: apply a solution to both bearings
while a radar target is live. When: a solution exists. Where:
motors on the two Simulated swivels. Why: radar controllers and
CBC `setTargetAngles` aim other mounts; Going Ballistic has no
Lua API; rotate is one axis; this command is the two-axis apply.

## What Would Falsify This

- Amazeballs radar yaw/pitch controllers already aim this
  Simulated gun in world through `SimulatedSwivelMountAdapter`.
  Then this Lua apply is a duplicate product, and the ticket
  should close as a no-op on that pack.
- In-game a single `swivel_bearing` holds both yaw and pitch.
  Then two rotate calls are wrong.
- Ticket 5's rotate command takes both axes in one call. Then
  composing it twice is wrong.
- `compute_ballistic_aim` later returns Minecraft yaw/pitch
  instead of bearing-local degrees. Then passing those numbers
  through without a frame convert is wrong. That convert still
  would not live here.
- Going Ballistic grows a ComputerCraft method that aims
  Simulated bearings. Then this command would be the wrong
  mouth.
- A later Create Radar Lua method that names a live track and
  sets two Simulated angles in one call. Then composition here
  is redundant.

## Sources

- [YawControllerPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/YawControllerPeripheral.java)
- [PitchControllerPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/PitchControllerPeripheral.java)
- [AutoYawControllerBlockEntity.java (CBC mount, Simulated adapter resolve)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/block/controller/yaw/AutoYawControllerBlockEntity.java)
- [SimulatedSwivelMountAdapter.java](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/simulated/SimulatedSwivelMountAdapter.java)
- [Create Radar README (CBC cannon controller)](https://github.com/Arsenalists-of-Create/Create-Radar)
- [Create Aero Radar README (two stacked swivels)](https://github.com/kvrself/create-aero-radar)
- [Swivel bearing (Create Aeronautics Wiki)](https://createaeronautics.miraheze.org/wiki/Swivel_bearing)
- [Create Avionics swivel_bearing (no angle setter)](https://solastrius.github.io/CreateAvionics/peripheral/swivel_bearing.html)
- [Native SwivelBearingPeripheral.java](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/compat/computercraft/peripherals/SwivelBearingPeripheral.java)
- [Going Ballistic README (no ComputerCraft API)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic)
- [CC:CBC cannon_mount setTargetAngles](https://github.com/Drakon7009/CC-CBC)
- Ticket 1 paper: dish off the gun; Amazeballs jar list
- Ticket 2 paper: bearing-local `getTargetAngle` degrees
- Ticket 3 paper: `electric_motor` `setSpeed`
