# How Should A ComputerCraft Program Compute Yaw And Pitch That Hit A Moving Target Under Create Big Cannons Going Ballistic Physics?

A ComputerCraft program must aim a Simulated bearing gun at a Create
Radar track. Create Big Cannons: Going Ballistic sets muzzle speed,
gravity, and drag. It has no ComputerCraft API. This paper asks how
Lua should compute yaw and pitch that intercept a moving target
under that physics.

## Context

The gun sits on Simulated swivel bearings. Create Radar yaw and
pitch controllers drive CBC mounts, not those bearings. Ticket 1
already reads tracks. Ticket 6 will drive bearings. This ticket
only computes a firing solution. It does not wrap motors, bearings,
or a barrel. It may call `bearing_turret.read_radar_tracks`.

Amazeballs is Minecraft 1.21.1. Ticket 1 listed Create Radar
0.4.9.4, CC: Tweaked 1.120.0, Simulated 1.3.0. Going Ballistic on
that line is the NeoForge mod
`Hectoris919/CreateBigCannons-Going-Ballistic`. CBC on that line is
the `create-v6-1.21.1` sources: `AbstractCannonProjectile` uses
`getForces`, `getDefaultGravity`, and `getDragForce`.

Going Ballistic issue 3 asked for an in-mod calculator block. The
author declined that as out of scope and wrote that Create Radar
still does not use Going Ballistic ballistics. Radar auto-aim is
the wrong physics for this gun and the wrong actuator.

## Known Approaches

### Trust Create Radar Yaw And Pitch Controllers

Rejected. Those blocks talk to CBC mounts. The product gun is on
Simulated bearings. The Going Ballistic author also states Radar
does not yet use this mod's ballistics.

### Use A Public CBC Calculator That Treats Powder Count As Speed

Malex21's Python calculator and SuperSpaceEye's Lua gist brute-force
pitch for a stationary target. Launch speed is the powder-charge
count. In-flight they use gravity 0.05 blocks/tick^2 and drag 0.99
per tick, with horizontal time from `ln(0.99)`. That is vanilla CBC
before Going Ballistic, and the old `vel' = vel * 0.99` drag, not
the 1.21.1 `getDragForce` path.

CBC 5.5.0 already rewrote drag to
`vel' = vel - vel * vel * drag * density` with default form drag
0.001. Going Ballistic then replaces `getDragForce` entirely.

Using those calculators on Amazeballs invents a miss. Rejected as
the live physics.

### Closed-Form Vacuum Ballistics

A vacuum parabola with constant gravity has two elevations. Going
Ballistic drag is quadratic in speed. CBC integrates with a
mid-tick position step. There is no public closed form for that
tick loop plus a moving target. Community write-ups say the same
for even the older CBC model. Rejected as the solver. Vacuum can
seed a search. It is not the answer.

### Copy The README Robins Formula With Constant 1991 And Stop

The Going Ballistic README prints Benjamin Robins' cannon formula
with leading constant 1991, citing
[arc.id.au Cannon Ballistics](https://www.arc.id.au/CannonBallistics.html).
That 1991 is feet per second in the historical write-up. The Java
does not launch at 1991 m/s times the square root.

`BallisticsMath.getRobinsVelocityMps` is:

```
v = K * sqrt( (p / (m + p/3)) * ln(L/c) ) * localMul * globalMul
```

`K` is `BallisticsParameterRegistry.robinsConstantMps()`, default
**606.8568** (datapack
`ballistics_parameters/defaults.json`). 1991 / 3.28084 is 606.86.
The README constant is ft/s. Lua must use the Java m/s constant,
then divide by 20 for blocks/tick (`BallisticsMath.mpsToBPT`).

If `L/c < 1`, Java clamps the ratio to `1.000001` before `ln`.
Non-finite or non-positive m, p, c, or L return 0. A 0 result is
not a legal muzzle speed for this function.

Powder mass and charge length are physical kilograms and meters,
not "number of powder charges" as a velocity. When the live shot
capture is empty, Going Ballistic's fallback is
`(cbcChargePower / 2) * cannon_powder_mass` and
`(cbcChargePower / 2) * cannon_charge_length`. Datapack defaults:
powder mass 121.59345516815 kg per charge-equivalent, charge
length 1 m. The README table listing a powder charge as 63.0151 kg
is not what `BallisticsParameterRegistry` returns. This function
takes kg and meters. It does not guess charge-power from a block
inventory.

### Simulate The Live Tick Loop (Recommended)

Going Ballistic changes three things that a solver must copy.

#### Muzzle velocity

`MountedCannonContraptionMixin` redirects
`AbstractBigCannonProjectile.shoot` and replaces the CBC charge
power with
`BallisticProjectileHelper.calculateCannonLaunchVelocityBlocksPerTick`.
That calls Robins, then `mpsToBPT`. Config
`disableRealisticBallistics` falls back to raw CBC charge power.
This paper assumes the pack leaves that flag false. If it is true,
the Robins path is wrong.

Barrel length L is summed from mounted cannon blocks
(`estimateMountedBarrelProfile`), 1 m per normal barrel, minimum
0.25 m. This function does not scan a contraption. The caller
passes `barrel_length_meters`. The muzzle coordinates are the
**spawn point** (barrel tip). Do not add barrel length again as a
position offset. The gist that starts at the mount and then walks
the barrel is a different origin convention.

#### Gravity

`AbstractCannonProjectilePhysicsMixin` injects
`getDefaultGravity`. When realistic gravity is on, it returns

```
-9.80665 / (20 * 20) * dimensionGravityMultiplier
```

(`ProjectilePhysicsMath.earthGravityBlocksPerTickSquared`). That
is about **-0.024516625** blocks/tick^2 in the overworld, not CBC
datapack gravity and not -0.05.

CBC 1.21.1 `getForces` adds `this.getGravity()` on Y. Entity
`getGravity()` uses `getDefaultGravity` when gravity is enabled.
Overworld `gravityMultiplier` is 1 unless a dimension datapack
says otherwise. This function multiplies by caller
`gravity_multiplier` (default 1). It does not read a world.

#### Drag

The same mixin injects `getDragForce`. When realistic drag is on,
it returns quadratic drag acceleration in blocks/tick^2, capped at
current speed:

```
k = 0.5 * rho * Cd * A / m
a_drag = min(k * v * v, v)
```

Defaults from `BallisticsParameterRegistry`: air density 1.225,
Cd 0.47. Area is `pi * r^2` with r from projectile kind:

- cannon: `cannon_charge_diameter / 2` (default 0.754441738242 / 2)
- autocannon: `autocannon_cartridge_diameter / 2`
- machine_gun: `machine_gun_bullet_radius`

`rho` is `air_density * drag_multiplier`. One block is one meter
in that helper, the same as Robins' L and c.

CBC 1.21.1 then builds acceleration and steps:

```
accel = -unit(velocity) * getDragForce() + (0, getGravity(), 0)
pos = pos + velocity + 0.5 * accel
vel = vel + accel
```

(`AbstractCannonProjectile.tick` / `getForces`, branch
`create-v6-1.21.1`). If speed is 0, `normalize` is undefined. A
solver must not start a tick at zero speed.

This is **not** `vel = 0.99 * vel + gravity`. Copying the gist
tick here would miss.

Fluid drag (`FluidDragHandler`) and in-ground / bounce / penetrate
are out of scope. The solution is a free-air intercept. A hit that
would have clipped a block is Aim / fire's problem, not this
function.

### Moving Target Lead

Ticket 1 returns Create Radar `velocity` as Minecraft entity
delta movement, **blocks per tick, gravity included** (Create-Radar
issue 128; link in Sources).
A standing player reports `y = -0.08`. Creative flight reports
`y = 0`. Subtracting 0.08 from every Y would invent a filter and
would be wrong for flying targets.

This function uses the track velocity **as a constant**
blocks-per-tick vector for lead:

```
lead(t) = position + velocity * t
```

It does not strip gravity. It does not zero Y for PLAYER. A
caller who wants a grounded lead passes a `track` whose velocity
already has the Y they want (often 0). Silent rewrite of ticket 1
output is out of bounds.

A moving intercept uses this hit test: integer flight time t in
1 .. `max_ticks` (default 2000), aim at `lead(t)`, simulate the
projectile, accept when the simulated arrival tick matches t
(nearest tick, miss distance inside one block of the lead point
at that tick).

That hit test is not a loop over every t. The complete search is
at most eight frozen-lead iterations, then one moving-lead check.
Each frozen-lead iteration aims at `lead(t)` with t held fixed,
samples pitch on the design grid, and takes the simulated
closest-tick as the next t. After at most eight iterations, freeze
yaw and pitch and simulate against the moving lead
(`position + velocity * n` at each tick n). Prefer the **low**
elevation when two air solutions exist on that frozen-lead pitch
scan. `trajectory = "high"` selects the steep solution. Two air
solutions are two disjoint elevation roots that both pass the
lead point. They are not the minimum and maximum pitches inside
the one-block miss window of a single arc. That window is a
graze band around one root. When only one root exists, that
elevation is returned for either `trajectory` request.

If the moving-lead miss is greater than one block, fail loud with
exactly `Compute Ballistic Aim: no intercept`. That string means
this search did not hit under these physics, this pitch grid,
eight frozen-lead iterations, and `max_ticks`. It is not a claim
that every t in 1 .. `max_ticks` was tried. A miss that an
exhaustive t sweep would have found is still `no intercept`.
There is no second failure string for "did not converge" and no
second command.

Yaw is not searched. Once a lead point is chosen, yaw is the
Minecraft facing of the horizontal vector from muzzle to lead:

- 0 degrees = +Z (south)
- positive toward -X (west)
- `atan2(-dx, dz)` in degrees

If that horizontal length is below 1e-9, the facing is undefined.
Emit `yaw_degrees` 0 (south, +Z). Lua `math.atan2(0, 0)` returns 0;
the contract still names 0 so the output is not a 0/0 accident
from a different math library. At pitch ±90 that yaw does not
change launch direction. It is still a finite number because Aim
Turret maps yaw onto a bearing.

That is player-facing yaw, not Simulated bearing-local degrees.
Ticket 2's FACING-negative wrap belongs to Aim Turret At Target.
This function does not convert into bearing space and does not
call rotate or fire.

Pitch is elevation from horizontal, **positive muzzle up**.
Minecraft entity `xRot` is positive down. Do not emit that sign.
CBC mount goggles show pitch as elevation; Aim Turret maps this
number onto bearings.

Launch direction is `ux = -sin(yaw)*cos(pitch)`, `uy = sin(pitch)`,
`uz = cos(yaw)*cos(pitch)`. At pitch ±90 degrees, `cos(pitch)` is
0, so the unit vector is `(0, ±1, 0)`. Yaw does not affect it. A
vertical launch is well-defined. CBC 1.21.1 `getForces` uses
`velocity.normalize()`. That call is defined whenever speed > 0.
Launch speed is already required positive, so zero horizontal at
±90 is a legal tick start, not a zero-speed case.

The pitch search domain is **-90 through 90 degrees, inclusive**.
Excluding ±90 would make an overhead or underfoot intercept fail
by construction: the solver would never sample the vertical shot
even when the lead sits on the muzzle vertical. Coarse step is 1
degree. Refine half-width is 1 degree, clamped to that same
inclusive domain, so a coarse 90 does not invent pitch 91.

### Track Source

When `opts.track` is present, use that row. Do not call the child.
When `track` is omitted, call
`bearing_turret.read_radar_tracks` with `radar_name` and
`monitor_name` only. Use `selectedTrack`. If that is nil, fail
loud. Do not pick `tracks[1]`. Empty list plus no selection is
not a stationary origin at 0,0,0.

The track row shape is ticket 1's: non-empty string `id`,
`position` and `velocity` tables with numeric x/y/z. Optional
radar fields are ignored. This function does not wrap radar
itself.

### Yield Or Cap The Nested Pitch Search

Rejected. ComputerCraft aborts a program that runs too long without
`os.pullEvent`, `sleep`, or another yield. The host message is
`Too long without yielding`. On CC: Tweaked the soft abort is on
the order of seven seconds of Lua without a yield; a later hard
abort kills the machine. The nested pitch/tick search (coarse
-90..90 step 1, refine plus or minus 1 at 0.05, eight lead
iterations, each sample up to `max_ticks`) can exceed that budget,
especially at `max_ticks` 100000.

Yielding every N samples (`sleep(0)` or a queued dummy event)
would reset the budget. `sleep` waits at least one world tick and
discards other events. Ticket 3 already rejected sleep-and-retry
as neighboring cope. A same-tick dummy yield still stretches
wall-clock, stales the lead while Engage waits, and hides the
cost. This command does not sleep.

Capping work so it "fits one tick" is the wrong budget. The host
limit is wall-clock Lua without yield, not one game tick, and it
is configurable. Shrinking the published grid would miss
intercepts. Lua cannot read remaining instructions, so a guessed
pre-abort `error("Compute Ballistic Aim: ...")` fails fast hosts
that would have finished and still loses to the host abort on slow
ones. Catching the abort with `pcall` and wrapping it races the
hard-abort window.

Named behavior: the nested search does not yield. If the host
trips the budget, that is a fail. The message is the host's
(`Too long without yielding` or the pack's equivalent). This
function does not `pcall` the search, does not prefix
`Compute Ballistic Aim:`, does not treat it as `no intercept`,
and does not sleep-retry. Completing the published grid inside a
given computer's timeout is out of contract. The caller lowers
`max_ticks` or accepts the throw. The only in-contract yield is
the child radar read when `track` is omitted.

## Recommendation

Compute the solution in Lua on the gun computer.

1. Resolve the track (opts table, or selected track from
   `read_radar_tracks`).
2. Compute muzzle speed from Robins (Java constant 606.8568 m/s,
   /20 for blocks/tick) unless the caller passed
   `muzzle_velocity_blocks_per_tick`.
3. Search time of flight with the complete procedure: at most
   eight frozen-lead iterations (aim at `lead(t)`, sample pitch,
   set t to the closest-tick), then one moving-lead check. Launch
   from the muzzle at candidate yaw (horizontal to lead, or 0
   when that horizontal length is below 1e-9) and candidate pitch
   in -90..90 inclusive (low or high family). Step with CBC
   `getForces` kinematics, Going Ballistic gravity, and Going
   Ballistic quadratic drag for `projectile_kind`. If that
   moving-lead miss is greater than one block, fail `no
   intercept`. Do not run a second exhaustive t search. Do not
   emit a second failure string for "did not converge."
4. Return one table: yaw, pitch, time of flight, muzzle speed,
   intercept point, trajectory name.

The nested pitch/tick search does not yield. A ComputerCraft
budget abort is the host throw, unwrapped. It is not `no
intercept`. Completing the published grid inside a given
computer's timeout is out of contract; lower `max_ticks` or
accept the throw.

Do not write peripherals. Do not sleep. Do not use powder count
as speed. Do not use drag 0.99. Do not use gravity -0.05. Do not
use README 1991 as an m/s constant.

## Five Ws

### Who

ComputerCraft program on the gun computer.

### What

Turn a track pose into yaw and pitch under Going Ballistic.

### When

A track is selected or supplied. Muzzle pose and shot parameters
are known.

### Where

Same computer. No peripheral write.

### Why

Going Ballistic has no Lua API. Radar controllers are the wrong
physics and the wrong mount. Lead must live in this command.

## What Would Falsify This

- Amazeballs sets `disableRealisticBallistics`,
  `disableRealisticGravity`, or `disableRealisticDrag`. Then
  CBC charge power, datapack gravity, and form-drag 0.001 apply
  instead.
- `DimensionMunitionProperties` multipliers are not 1 in the
  fight dimension. Then caller multipliers must match.
- Live CBC `getForces` on the Amazeballs jar differs from
  `create-v6-1.21.1` (order of drag vs gravity, or no half-accel
  position step). Then the Lua tick is wrong.
- Projectile spawn is the mount, not the barrel tip. Then muzzle
  coordinates in this contract are the wrong origin.
- Create Radar velocity is not blocks per tick, or is stripped
  before Lua. Then lead using the ticket 1 vector is wrong.
- Going Ballistic datapack overrides `robins_constant_mps`,
  masses, or Cd. Then the baked defaults miss. This function
  still uses those published defaults unless the caller passes
  muzzle speed and masses that already include the override.
- Eight frozen-lead iterations plus one moving-lead check miss
  fights this gun actually sees (a hit exists on the pitch grid
  at some t this procedure never visits). Then the contract is
  wrong: change the paper to exhaustive t. Do not keep
  `no intercept` as a silent "maybe."
- Live CBC `getForces` rejects a spawn whose XZ velocity is 0 even
  when speed is the muzzle speed. Then ±90 is not a legal launch
  and the pitch domain must stop short of vertical.

## Sources

- [Going Ballistic README (Robins formula, masses)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic)
- [BallisticsMath.java (K = robinsConstantMps, mpsToBPT)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/java/org/hectoris919/CBCGoingBallistic/ballistics/BallisticsMath.java)
- [ProjectilePhysicsMath.java (g = -9.80665/400, quadratic k)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/java/org/hectoris919/CBCGoingBallistic/ballistics/ProjectilePhysicsMath.java)
- [AbstractCannonProjectilePhysicsMixin.java](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/java/org/hectoris919/CBCGoingBallistic/mixin/AbstractCannonProjectilePhysicsMixin.java)
- [MountedCannonContraptionMixin.java (replace shoot velocity)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/java/org/hectoris919/CBCGoingBallistic/mixin/MountedCannonContraptionMixin.java)
- [BallisticProjectileHelper.java (Robins launch, charge fallback)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/java/org/hectoris919/CBCGoingBallistic/ballistics/BallisticProjectileHelper.java)
- [ballistics_parameters/defaults.json](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/blob/main/src/main/resources/data/cbc_going_ballistic/cbc_going_ballistic/ballistics_parameters/defaults.json)
- [Going Ballistic issue 3 (no calculator block; Radar not updated)](https://github.com/Hectoris919/CreateBigCannons-Going-Ballistic/issues/3)
- [CBC AbstractCannonProjectile.java create-v6-1.21.1 (getForces tick)](https://github.com/Cannoneers-of-Create/CreateBigCannons/blob/create-v6-1.21.1/src/main/java/rbasamoyai/createbigcannons/munitions/AbstractCannonProjectile.java)
- [CBC 5.5.0 drag rework notes](https://modrinth.com/mod/create-big-cannons/version/y3RxrHjU)
- [Robins / 1991 ft/s write-up](https://www.arc.id.au/CannonBallistics.html)
- [SuperSpaceEye gist (vanilla CBC 0.99 / 0.05; rejected here)](https://gist.github.com/SuperSpaceEye/c33443213605d1bf35f81737c9058dc2)
- [Malex21 CBC calculator (powder count as speed; rejected here)](https://github.com/Malex21/CreateBigCannons-BallisticCalculator)
- [Create-Radar issue 128 (velocity includes gravity)](https://github.com/Arsenalists-of-Create/Create-Radar/issues/128)
- [_G.sleep (yield vs Too long without yielding)](https://tweaked.cc/module/_G.html)
- [CC: Tweaked discussion 605 (timeout catchable; yield required)](https://github.com/cc-tweaked/CC-Tweaked/discussions/605)
- Ticket 1 paper: track pose, blocks/tick, gravity left in
