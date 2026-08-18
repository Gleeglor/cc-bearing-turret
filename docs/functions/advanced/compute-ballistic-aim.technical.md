# Compute Ballistic Aim

## What

Compute yaw and pitch that intercept a radar track under Create
Big Cannons Going Ballistic physics.

## How

Lua call: `bearing_turret.compute_ballistic_aim(opts)`. Arity is
exactly 1. Zero arguments, a second argument, or `opts` that is
not a table fail loud. A string or a wrap table is not `opts`.

`opts` a table: read only the ainterface input keys. Any other key
fails loud, including array index `1`.

Load the child module with `dofile("read_radar_tracks.lua")`. Call
`bearing_turret.read_radar_tracks` on that table only when `track`
is omitted. Do not copy child internals. Do not wrap radar.

### Envelope

Optional strings: omit key, nil, or `""` means omit. A present
value that is not a string fails loud.

`track` omitted: key absent or nil. Do not treat `false` as omit.

`radar_name` or `monitor_name` non-omit while `track` is present
fails loud. Those names exist only to pass through to Read Radar
Tracks.

### Numbers

Required keys `muzzle_x`, `muzzle_y`, `muzzle_z`,
`projectile_mass_kg`, `powder_mass_kg`, `charge_length_meters`,
`barrel_length_meters` must be present Lua numbers and finite.
NaN and inf fail loud. Mass, powder, charge length, and barrel
length must be greater than 0.

`gravity_multiplier` omitted means 1. Present: finite Lua number
(negative is allowed; 0 is allowed).

`drag_multiplier` omitted means 1. Present: finite Lua number and
>= 0.

`muzzle_velocity_blocks_per_tick` omitted means compute Robins.
Present: finite Lua number greater than 0.

`max_ticks` omitted means 2000. Present: Lua number, finite,
equal to `math.floor` of itself, in 1 .. 100000 inclusive.

### Kind and trajectory

`projectile_kind` omit means `cannon`. Legal non-omit values:
`cannon`, `autocannon`, `machine_gun`.

`trajectory` omit means `low`. Legal non-omit values: `low`,
`high`.

### Track

When `track` is present it must be a table. Required row shape:

- `id`: non-empty string
- `position`: table with finite numeric `x`, `y`, `z`
- `velocity`: table with finite numeric `x`, `y`, `z`

Other keys on the track are ignored. Do not mutate the caller's
table. Copy the six numbers (`position.x/y/z` and `velocity.x/y/z`)
plus `id`.

Non-finite position or velocity components fail loud. Ticket 1
allows any Lua number on a read; this function cannot simulate
NaN.

When `track` is omitted, build a child opts table with only
`radar_name` and `monitor_name` when those are non-omit. Call
`read_radar_tracks(child_opts)` or `read_radar_tracks()` when both
names omit. `pcall` that call. On throw, fail loud with the
original message in the diagnostic. On success, the return must be
a table. Use `selectedTrack`. If `selectedTrack` is nil, fail
loud. Do not use `tracks[1]`. Then apply the same row-shape checks
as a supplied `track`.

Velocity is used as a constant blocks-per-tick vector, gravity
included. Do not subtract 0.08. Do not zero Y for PLAYER.

Lead at integer tick `t` (>= 1):

```
lead.x = position.x + velocity.x * t
lead.y = position.y + velocity.y * t
lead.z = position.z + velocity.z * t
```

### Muzzle speed

If override present, launch speed is that number (blocks/tick).

Else Robins, matching `BallisticsMath.getRobinsVelocityMps` with
local and global multipliers 1:

```
ratio = max(barrel_length_meters / charge_length_meters, 1.000001)
radicand = (powder_mass_kg / (projectile_mass_kg + powder_mass_kg / 3))
  * math.log(ratio)
v_mps = 606.8568 * sqrt(radicand)
v_bpt = v_mps / 20
```

`math.log` is natural log, same as Java `Math.log`. If `radicand`
is not finite or <= 0, or `v_bpt` is not finite or <= 0, fail
loud.

Do not use 1991 as an m/s constant. Do not use powder count as
speed.

Muzzle coordinates are the projectile spawn point. Do not add
`barrel_length_meters` onto the spawn pose.

### In-flight tick

Radius meters from `projectile_kind`:

- `cannon`: 0.754441738242 / 2
- `autocannon`: 0.150888347648 / 2
- `machine_gun`: 0.004236548901

```
area = pi * radius * radius
rho = 1.225 * drag_multiplier
k = 0.5 * rho * 0.47 * area / projectile_mass_kg
g = -9.80665 / 400 * gravity_multiplier
```

One block is one meter.

Launch direction from yaw and pitch, pitch positive up, yaw
Minecraft facing (0 = +Z):

```
ux = -sin(yaw) * cos(pitch)
uy = sin(pitch)
uz = cos(yaw) * cos(pitch)
```

Angles in radians inside the trig calls. Initial velocity is
`v_bpt` times that unit vector. Initial position is the muzzle.

Each tick, while speed > 0:

```
speed = |vel|
unit = vel / speed
drag_force = min(k * speed * speed, speed)
accel_x = -unit.x * drag_force
accel_y = -unit.y * drag_force + g
accel_z = -unit.z * drag_force
pos = pos + vel + 0.5 * accel
vel = vel + accel
```

This is CBC 1.21.1 `getForces` plus the half-accel position step.
If speed is 0 before `max_ticks`, that sample stops.

Do not use drag 0.99. Do not use gravity -0.05. Do not apply
fluid drag. Do not clip blocks.

### Minecraft yaw

```
dx = lead.x - muzzle_x
dz = lead.z - muzzle_z
horiz = sqrt(dx * dx + dz * dz)
```

If `horiz < 1e-9`, `yaw_degrees` is 0 (Minecraft south, +Z): a
zero-length XZ vector has no facing. Lua `math.atan2(0, 0)` is 0;
the contract still names 0 so the output is not a 0/0 accident.
At pitch ±90 this yaw does not change launch direction. Else:

```
yaw_degrees = atan2(-dx, dz) * 180 / pi
```

Lua `math.atan2`. Output is not wrapped to 0..360; any finite
degree value is legal. Aim Turret maps this onto bearings. This
function does not apply Simulated FACING-negative.

### Intercept search

Miss limit: 1.0 blocks (Euclidean).

Pitch domain: -90 through 90 degrees inclusive.

Launch direction at ±90 is `(0, ±1, 0)` because `cos(pitch)` is 0,
so yaw drops out. CBC `getForces` normalizes velocity; speed is
`v_bpt` > 0, so zero horizontal is a legal tick start. A domain
that stops at ±89 never samples that vector, so an overhead or
underfoot lead can fail the 1-block miss limit by construction.

Coarse step: 1 degree. Refine half-width: 1 degree. Refine step:
0.05 degree.

Lead iteration cap: 8.

Integer `t` starts at `max(1, floor(horiz0 / v_bpt))` where
`horiz0` is muzzle-to-track position horizontal distance. If
`v_bpt` is 0 this path already failed.

Each lead iteration:

1. `lead = position + velocity * t` (t integer).
2. `yaw_degrees` from muzzle to that lead.
3. Coarse-scan pitch -90..90 step 1. For each pitch, simulate
   from the muzzle with that yaw/pitch up to `max_ticks`. At
   each tick `n`, miss is distance from projectile pose to this
   **frozen** lead. Keep the `n` with smallest miss (lowest `n`
   on a tie).
4. A coarse pitch is a hit if that smallest miss <= 1.0.
5. Group consecutive hit pitches on the 1-degree grid into runs
   (a run ends at any non-hit). Each run is one elevation family.
   A family's coarse pitch is the sample in that run with
   smallest miss (lowest pitch on a tie). That is the root, not
   a graze at the run edge. Do not use the smallest and largest
   pitch among all hits as the two families.
6. If no coarse hit: pick the coarse pitch with smallest miss
   (lowest pitch on a tie). It may still fail the miss limit
   after refine and moving check.
7. If exactly one run: both `low` and `high` choose that family's
   coarse pitch.
8. If two or more runs: `low` is the run at smallest pitch;
   `high` is the run at largest pitch (the steep air solution).
   Ignore any runs between those two.
9. Choose family from requested `trajectory` (`low` default).
10. Refine: scan `chosen-1` .. `chosen+1` step 0.05, clamped to
   [-90, 90], same frozen-lead simulation. Keep the pitch with
   smallest miss (lowest pitch on a tie) and its `n`.
11. Set `t` to that `n`. If `t` equals the previous `t`, stop
   iterating. If `n` is nil because every sample had speed 0
   immediately, fail as no intercept after the outer loop.

After at most 8 iterations (or early stop), freeze yaw and pitch
to the last refined values. Simulate again against the **moving**
lead (`position + velocity * n` at each tick `n`). Pick the tick
`n` in 1..`max_ticks` with smallest miss (lowest `n` on a tie).
If that miss > 1.0, fail loud with
`Compute Ballistic Aim: no intercept`.

This eight-iteration-then-moving-check procedure is the complete
intercept search. `no intercept` means that procedure did not
produce a moving-lead miss <= 1.0 under these physics, this pitch
grid, the lead iteration cap 8, and `max_ticks`. Do not run a
further exhaustive loop over t. Do not emit a second string such
as "lead search did not converge." A miss that such an exhaustive
t sweep would have found is still `no intercept`.

Success fields:

- `yaw_degrees` / `pitch_degrees`: last refined pair
- `time_of_flight_ticks`: that moving-lead `n`
- `muzzle_velocity_blocks_per_tick`: launch speed
- `impact_x/y/z`: projectile pose at `n`
- `trajectory`: requested name (`low` if omitted)

One hit family still succeeds for a `high` request. Output
`trajectory` is still `high` when that was requested.

The nested pitch/tick search does not yield. Do not call `sleep`,
`os.pullEvent`, or a synthetic queued event inside that loop. The
only yield this function may take is the child radar read when
`track` is omitted.

If ComputerCraft trips the instruction budget during that search,
the host throws `Too long without yielding` (or the pack's
equivalent). That throw is a fail. Do not `pcall` the search. Do
not wrap the host message with `Compute Ballistic Aim:`. Do not
treat it as `no intercept`. Do not sleep-retry. Completing the
published grid inside a given computer's timeout is out of
contract. A caller who cannot accept the host throw must lower
`max_ticks`.

### Preconditions

- `opts` is a table of ainterface keys.
- Muzzle pose, mass, powder, charge length, and barrel length are
  finite numbers with the positivity rules above.
- A track row exists (supplied or selected).
- Going Ballistic realistic ballistics are the modeled pack
  (config flags off). Dimension multipliers default to 1.

### Postconditions

- Success is exactly one table with the eight output keys.
- `time_of_flight_ticks` is an integer in 1 .. `max_ticks`.
- Moving-lead miss at that tick is <= 1.0 blocks.
- No peripheral method was called by this function. The child may
  yield on radar reads when `track` is omitted. The nested
  pitch/tick search does not yield.
- Yaw is world Minecraft facing. Pitch is elevation, positive up.

### Invariants

- This function does not write peripherals.
- This function does not call rotate, motor speed, or fire.
- This function does not strip track velocity axes.
- This function does not pick an unselected track from the list.

### Failure modes

Fail loud on this page means `error(message, 0)` with a required
distinguishing message.

- Extra or missing arguments:
  `Compute Ballistic Aim: expected exactly one argument, got <n>`
- Argument present and not a table:
  `Compute Ballistic Aim: inputs must be a table, got <type>`
- Unknown `opts` key:
  `Compute Ballistic Aim: unknown input '<key>'`
- Present optional name not a string:
  `Compute Ballistic Aim: <field> must be a string or nil, got
  <type>`
- `radar_name` or `monitor_name` with `track`:
  `Compute Ballistic Aim: <field> is not used when track is
  supplied`
- Required number missing:
  `Compute Ballistic Aim: <field> is required`
- Required or optional number not a number:
  `Compute Ballistic Aim: <field> must be a number, got <type>`
- NaN:
  `Compute Ballistic Aim: <field> must be a finite number, got
  nan`
- Infinity:
  `Compute Ballistic Aim: <field> must be a finite number, got
  inf`
- Mass, powder, charge length, barrel length, or override speed
  <= 0:
  `Compute Ballistic Aim: <field> must be greater than 0`
- `drag_multiplier` < 0:
  `Compute Ballistic Aim: drag_multiplier must be >= 0`
- `max_ticks` not an integer in range:
  `Compute Ballistic Aim: max_ticks must be an integer 1 through
  100000, got <value>`
- Bad `trajectory`:
  `Compute Ballistic Aim: trajectory must be 'low' or 'high', got
  '<value>'`
- Bad `projectile_kind`:
  `Compute Ballistic Aim: projectile_kind must be 'cannon',
  'autocannon', or 'machine_gun', got '<value>'`
- `track` present not a table:
  `Compute Ballistic Aim: track must be a table, got <type>`
- Track id missing / empty / not a string:
  `Compute Ballistic Aim: track id is missing` /
  `Compute Ballistic Aim: track id is empty` /
  `Compute Ballistic Aim: track id is <type>, expected string`
- Track position or velocity missing or not a table:
  `Compute Ballistic Aim: track <field> is missing` /
  `Compute Ballistic Aim: track <field> is <type>, expected
  table`
- Track vector component not a finite number:
  `Compute Ballistic Aim: track <field>.<axis> must be a finite
  number, got <type-or-nan-or-inf>`
- Child throw:
  `Compute Ballistic Aim: read_radar_tracks threw: <original>`
- Child success not a table:
  `Compute Ballistic Aim: read_radar_tracks returned <type>,
  expected table`
- No selected track:
  `Compute Ballistic Aim: no selected track`
- Robins radicand or speed unusable:
  `Compute Ballistic Aim: Robins muzzle speed is not positive`
- No intercept:
  `Compute Ballistic Aim: no intercept`
  This is the only intercept-miss string. It covers both "the
  moving-lead miss is > 1.0 after the defined search" and "eight
  frozen-lead iterations did not land on a t that later hits."
  Callers must not distinguish those cases.
- Host instruction-budget abort during the nested search (not a
  wrapped loud fail): the host message `Too long without yielding`
  (or the pack's equivalent) propagates as thrown. This function
  does not prefix `Compute Ballistic Aim:`, does not map it to
  `no intercept`, and does not sleep-retry.

`<field>` is the ainterface key. `<n>` is the arity. `<type>` is
`type(value)`. `<original>` is the `pcall` throw text.

### Non-failures

- A standing track with `velocity.y = -0.08` is not rewritten.
- `gravity_multiplier` 0 is not a failure.
- Negative `gravity_multiplier` is not a failure.
- `trajectory` `high` with only one hit family is not a failure.
- `max_ticks` 2000 by omit is not a failure.
- Child yield when `track` is omitted is not a failure.
- Completing the published pitch/tick grid before the host timeout
  is not a promise of this function.

### Sanitization

- No `tostring` on names, kinds, or numbers.
- Empty string optional strings are omit.
- Track copy does not keep `category` / `entityType` /
  `scannedTime` for the solver; they are not outputs.
- Pitch samples clamp to [-90, 90]. Output pitch is the refined
  sample, not rounded to 1 degree. ±90 is a legal output.
- Yaw is not normalized to 0..360.

## Why

Going Ballistic replaces CBC charge-power speed, datapack gravity,
and form-drag `getDragForce`. Public CBC calculators still model
powder count, 0.99 drag, and -0.05 gravity. Copying them would
aim at the wrong intercept.

Robins in Java uses 606.8568 m/s (1991 ft/s converted). Using 1991
as m/s would overspeed by about 3.28.

Muzzle as spawn point avoids double-counting barrel length (Robins
L is interior; CBC spawns at the tip).

Track velocity stays raw because ticket 1 forbids silent gravity
strips. A grounded lead is a caller-supplied Y of 0.

The search is discrete pitch samples plus eight frozen-lead
iterations and one moving-lead check, not a closed form and not
an exhaustive t sweep. Quadratic drag plus a moving target has no
public closed form. Eight iterations is the defined search, not a
heuristic leftover. `no intercept` after that search is the
product contract, not "physics proved no t works" and not "try
again with a longer search."

Failing when miss > 1 block is louder than returning a wild aim.
Aim Turret must not inherit a neighbor's guess.

Low vs high are disjoint hit runs on the coarse pitch grid, not
the min and max of every pitch whose miss is <= 1. A 1-block
window around one root is a band of grazes of the same arc.
Calling the top of that band `high` would not be the steep air
solution. The family's coarse pitch is the smallest-miss sample
in the run so refine (±1 degree, step 0.05) sits on the root,
not on a graze several degrees away. One run is one family:
`high` still succeeds and still names itself on the output.

Child-only-when-omitted lets tests pass a track without a dish.
Picking `tracks[1]` would invent a target.

The nested search is CPU-bound Lua. Sleep or dummy-event yield
would stall Engage and stale the lead. Ticket 3 already forbade
sleep-retry. Lua cannot read remaining instructions, so a
homemade budget is a guess. Naming the host abort as an unwrapped
fail, with `max_ticks` as the caller's lever, is the contract.
Wrapping it would invent a second message for the same kill.

World yaw/pitch stay out of bearing-local space so this command
does not own Simulated FACING flip (ticket 2).

Pitch includes ±90 because the launch unit vector there is
`(0, ±1, 0)`: `cos(pitch)` is 0, so yaw drops out. CBC `getForces`
normalizes velocity; speed is still `v_bpt` > 0. A domain of
-89..89 never samples that vector, so an overhead lead can fail
the 1-block miss limit by construction.

Yaw is 0 when `horiz < 1e-9` because a zero-length XZ vector has
no facing. The named south/+Z value is the contract, not a leftover
from `atan2(0, 0)`. At ±90 that yaw does not change direction.

## SOLID

- Single responsibility: firing solution only. No motor, no fire,
  no radar wrap.
- Compose: Read Radar Tracks supplies the row when the caller
  omitted it. This page does not reimplement `getTracks`.
- No caller-identity branching: Engage and any later caller pass
  the same `opts`. Low vs high is an input, not a caller name.

## Compatibility

Advanced. May call basic `read_radar_tracks`. Must not call other
advanced or high-level workspace functions. Must not be called
from a basic.
