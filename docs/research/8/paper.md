# How Can A ComputerCraft Program Aim Create Simulated Swivel Bearings At A Radar Target And Fire With Going Ballistic Physics When Create Radar Cannot Steer Those Bearings?

Amazeballs can see targets on Create Radar and can spin a barrel on
Simulated swivel bearings. Radar yaw and pitch controllers do not
turn those bearings. Going Ballistic changes shot speed and has no
Lua API. This paper asks how one ComputerCraft program still aims
and fires that gun.

## Context

The product act is a spinning barrel on two Simulated swivel
bearings (yaw and pitch). Create Radar lists tracks. Create Radar
also ships yaw and pitch controllers whose advertised job is a
CBC cannon controller: "Direct your autocannons at intruders with
the help of your radars." That path already failed on this gun.

The pack already has the pieces a script can compose:

- Create Radar 0.4.9.4 exposes ComputerCraft peripherals on the
  dish and the monitor. Ticket #1 reads those tracks. The dish
  stays off the gun bearing.
- Simulated 1.3.0 (native wrap) and Create Avionics both expose
  `swivel_bearing`. `getTargetAngle` is a stored servo target.
  Neither API sets that angle. The target integrates from kinetic
  input.
- Create Crafts and Additions `electric_motor` `setSpeed` is the
  write primitive (ticket #3). Ticket #2 is the angle read.
- Going Ballistic replaces CBC muzzle-velocity math with Robins'
  1742 formula. It is a physics patch, not a ComputerCraft
  peripheral.

This ticket is the parent script. Fire, rotate, two-axis aim, and
ballistic math are child tickets #4 through #7. This paper names
the composition. It does not specify those children's internals.

## Known Approaches

### Drive The Gun With Create Radar Yaw And Pitch Controllers

Create Radar registers `yaw_controller` with `setAngle` /
`getAngle`. `YawControllerPeripheral.setAngle` calls
`AutoYawControllerBlockEntity.setTargetAngle`. The README names
the feature a CBC cannon controller. Issue #93 (auto pitch on a
big cannon) is about CBC mounts. The client's gun is not on a CBC
mount. It is on Simulated swivel bearings. This is the path that
already failed in world. Rejected.

A later Create Radar commit added `PhysBearingYaw`. Amazeballs
ships `create_radar-0.4.9.4-1.21.1.jar`. Even if a newer Radar
build grew a physics-bearing branch, this product is still a
ComputerCraft script on Simulated kinematics, not a Radar
controller block. Do not call `yaw_controller.setAngle` from this
function.

### Put The Radar Dish On The Simulated Gun Bearing

Ticket #1 rejected this for the read. The same placement still
fails aim: Radar controllers do not drive these bearings, and a
moving dish mixes sensor motion into the gun. The parent inherits
that placement rule. Radar stays off the gun.

### Aim With A CBC Cannon Mount Peripheral

CC:CBC and cbcperipheral wrap `cannon_mount` with `setTargetYaw` /
`setTargetPitch` / `fire`. Those methods talk to a Create Big
Cannons mount. This gun's axes are Simulated swivels. Wrapping a
mount that is not there does not turn the bearings. Rejected.

### Aim With Create Aero Radar Mechanical Controllers

Create Aero Radar is a separate addon. It places mechanical yaw
and pitch controllers next to Simulated swivels, reads a linked
radar lock, and sets generated RPM. It is player-powered: no
player input, no aim. It is not in the Amazeballs ComputerCraft
script, and it is not this topic's ainterface. Rejected for this
function.

### Compute Lead And Fire Inside This One Script

A single Lua file that reads radar, integrates gravity, solves
Robins muzzle velocity, closes two motor loops, and pulls the
trigger is the slogan the tree already split. Going Ballistic
issue #3 asks for a calculator block; the author said that may be
outside the mod's scope and that Radar compat is future work.
There is still no Lua surface. Lead math belongs in
`compute_ballistic_aim` (#7). Closed-loop rotate belongs in
`rotate_bearing_toward_angle` (#5). Two-axis aim belongs in
`aim_turret_at_target` (#6). The shot belongs in
`fire_rotating_barrel` (#4). Stuffing those into the parent would
fail Seventh Circle as a blob.

### Compose One Engagement Step From Named Children

The pseudocode tree already names the parent and its three
direct callees:

```
bearing_turret.engage_simulated_bearing_turret
  bearing_turret.compute_ballistic_aim
  bearing_turret.aim_turret_at_target
  bearing_turret.fire_rotating_barrel
```

`read_radar_tracks` sits under compute and aim, not under engage.
`rotate_bearing_toward_angle`, `read_swivel_bearing_angle`, and
`set_electric_motor_speed` sit under aim, not under engage.
Engage consumes children by `dofile` of their Lua modules and
calling the names on `ainterface.json`. It does not copy their
bodies.

## Recommendation

One specialized task script,
`bearing_turret.engage_simulated_bearing_turret`. One Lua call is
one engagement step. The operator or a bytecode loop re-calls it.
The parent does not contain `while true`.

### Order

1. Call `compute_ballistic_aim` with the child's advertised
   inputs taken from the parent `opts` table. That child reads
   tracks (including operator selection) and returns a firing
   solution under Going Ballistic physics.
2. Call `aim_turret_at_target` with that child's advertised
   inputs. Engage writes compute's success table onto `aim_opts`
   under the input name that child advertises for the firing
   solution. Until that row names a key, that name is
   `solution`. The caller does not supply that key. Aim is one
   kinetic step, not a wait until aligned.
3. If aim reports the gun is on the solution this step, call
   `fire_rotating_barrel` with that child's advertised inputs.
   If aim reports off-target, skip fire. That skip is success,
   not a failure.

A child `error` fails the parent. Do not catch and continue. Do
not fire after a failed compute or a failed aim.

### Target

Engage a selected radar pose. `read_radar_tracks` already returns
`selectedTrack` / `selectedTrackId` as `nil` when there is no
pick, and it can return a selected id with a missing pose. The
parent does not pick the first `HOSTILE` row. No selected pose
this step is `error`. An empty track list with no pose is the
same failure. Silent substitution of another track is out of
bounds.

Compute owns how it reads tracks. Engage still requires a usable
selected pose before it aims or fires. If compute fails loud on
that miss, engage does not add a second check. If compute would
accept a missing pose, engage fails before aim.

### Fire Gate

Fire is not "every step" and not "after aim returns." Fire runs
only when `aim_turret_at_target` reports on-target for this step.
That report is the child's advertised output. Engage maps it to
parent output `on_target`. Parent output `fired` is true only
when the fire child actually ran.

The gate is the call, not the envelope. A missing fire-required
key fails this call even when fire would have been skipped.

Aim's on-target test (tolerance, both axes, stored servo vs
visual) lives in #6. Engage does not re-read bearings to second
guess it.

### Inputs

Lua arity 1. `opts` is a table. Extra arguments, omitted `opts`,
nil `opts`, or a non-table fail loud. Unknown keys fail loud.

Known keys on this ticket's ainterface row:

- `radar_name`, `monitor_name` (optional; discover as #1 does)
- `yaw_bearing_name`, `pitch_bearing_name` (required strings)
- `yaw_motor_name`, `pitch_motor_name` (required strings)

The gun has two swivels and two motors. Discover-exactly-one
cannot name the axes. Those four names are required.

`fire_rotating_barrel` is on the ainterface. Its `side` is
required on every engage call. Its `relay_name` is optional.

When tickets #6 and #7 add rows, engage's legal `opts` keys
become the union of those two input maps with the keys above, except a child key
that names yaw bearing, pitch bearing, yaw motor, or pitch motor
under a string other than `yaw_bearing_name`,
`pitch_bearing_name`, `yaw_motor_name`, or `pitch_motor_name`,
and except the input name `aim_turret_at_target` advertises for
the firing solution. Until that row names a key, that name is
`solution`. Those four parent axis names stay required. They
are not dropped, and the child's different strings are not
added as second parent keys. Engage copies each parent axis
value onto a child `opts` under the name that child lists for
that role: a rename when the strings differ, a same-key copy
when they match. If a caller puts both `yaw_bearing_name` and a
child's different yaw key on `opts`, the child's key is unknown
and fails loud; the parent name is the only legal key for that
role. The aim child's firing-solution input is not a parent
`opts` key. Presence on parent `opts` is unknown and fails
loud. Parent parse does not require it, even if the aim child
lists it required. Engage writes compute's success table onto
`aim_opts` under that name only. It does not copy that key from
parent `opts`. `side` and `relay_name` are the fire-child keys
now listed. `side` is required on every engage call and fails at
parent parse, not after aim reports on-target. Engage forwards
those keys unchanged when fire runs. Engage forwards non-axis,
non-solution child keys unchanged. This ticket does not invent
barrel internals.

Forwarding is by ainterface names. Engage `dofile`s each
child's module and calls
`bearing_turret.<command>(child_opts)`. It does not call
`getTracks`, `getTargetAngle`, `setSpeed`, or Radar
`setAngle`.

### Outputs

Success is one table:

- `on_target`: boolean from aim this step
- `fired`: boolean; true only if fire ran

Do not return child solution maps as extra Lua values. Do not
return no values. A skipped fire is `fired = false` with
`on_target = false`.

### What This Function Is Not

- It does not implement fire, rotate, aim loops, or ballistic
  math.
- It does not call `yaw_controller.setAngle` or
  `pitch_controller.setAngle`.
- It does not wrap `cannon_mount`.
- It does not run forever.
- It does not choose a track when the operator has not.

Those belong to children, to rejected approaches, or to the
caller.

## What Would Falsify This

- In-game Radar yaw/pitch controllers rotate Amazeballs Simulated
  swivels without a motor. Then the product act is a Radar
  controller, and this script is the wrong parent.
- Going Ballistic grows a ComputerCraft peripheral that returns
  yaw/pitch. Then #7 becomes a wrap, and engage still composes,
  but compute's how changes.
- Aim's ainterface has no on-target output. Then the fire gate
  cannot be "aim reported on-target" and must be redesigned with
  #6, not guessed inside engage.
- A selected pose is not how the operator designates a target
  (for example only category filters). Then fail-loud on missing
  selection is wrong.
- One engagement step cannot include fire because the barrel
  needs a multi-tick spin-up that #4 will not hide. Then engage
  still calls fire; #4's contract says whether that call is a
  no-op or a fail.

## Sources

- [Create Radar README (CBC Cannon Controller)](https://github.com/Arsenalists-of-Create/Create-Radar)
- [YawControllerPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/YawControllerPeripheral.java)
- [Create-Radar issue 93, auto pitch on a big cannon](https://github.com/Arsenalists-of-Create/Create-Radar/issues/93)
- [Create Avionics swivel_bearing (target angle not settable)](https://solastrius.github.io/CreateAvionics/peripheral/swivel_bearing.html)
- [Native SwivelBearingPeripheral.java](https://github.com/Creators-of-Aeronautics/Simulated-Project/blob/main/simulated/common/src/main/java/dev/simulated_team/simulated/compat/computercraft/peripherals/SwivelBearingPeripheral.java)
- [Going Ballistic README (Robins formula, no Lua API)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic)
- [Going Ballistic issue 3, calculator block out of scope](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/issues/3)
- [Create Aero Radar (mechanical Simulated aim, separate addon)](https://github.com/kvrself/create-aero-radar)
- [CC:CBC cannon_mount peripheral](https://github.com/Drakon7009/CC-CBC)
- Ticket 1 paper: dish off the gun, raw tracks, selected pose
- Ticket 2 paper: `getTargetAngle` read-only stored servo target
- Ticket 3 paper: `electric_motor` `setSpeed` write primitive
- Amazeballs instance mods (ticket 1 paper):
  `create_radar-0.4.9.4-1.21.1.jar`,
  `create-aeronautics-bundled-1.21.1-1.3.0.jar` (Simulated 1.3.0
  nested), `cc-tweaked-1.21.1-forge-1.120.0.jar`
