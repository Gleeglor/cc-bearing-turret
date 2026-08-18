# Compute Ballistic Aim

Compute yaw and pitch that intercept a radar track under Create
Big Cannons Going Ballistic physics.

## Level

Advanced.

Ainterface command: `bearing_turret.compute_ballistic_aim`.

Module level: high-level specialized task script (`bearing_turret`).

## Who

ComputerCraft program on the gun computer.

## What

Turn a track pose into a firing solution: Minecraft facing yaw and
elevation pitch that hit the moving target under Going Ballistic
muzzle speed, gravity, and quadratic drag.

## When

A track is supplied or a dish can supply `selectedTrack`. Muzzle
pose and Robins inputs are known.

## Where

Same computer. Lua only. No peripheral write.

## Why

Going Ballistic has no ComputerCraft API. Create Radar controllers
use vanilla CBC ballistics and drive CBC mounts, not Simulated
bearings.

## Inputs

Exactly one table `opts`. Arity 1.

Required finite Lua numbers:

- `muzzle_x`, `muzzle_y`, `muzzle_z`: world-block spawn point
  (barrel tip)
- `projectile_mass_kg`: greater than 0
- `powder_mass_kg`: greater than 0
- `charge_length_meters`: greater than 0
- `barrel_length_meters`: greater than 0

Optional:

- `track`: table, Create Radar row shape (`id`, `position`,
  `velocity`)
- `radar_name`: string; only when `track` is omitted; omit key,
  nil, or `""` means discover
- `monitor_name`: string; only when `track` is omitted; omit key,
  nil, or `""` means discover
- `trajectory`: string `low` or `high`; omit, nil, or `""` means
  `low`
- `projectile_kind`: string `cannon`, `autocannon`, or
  `machine_gun`; omit, nil, or `""` means `cannon`
- `max_ticks`: integer 1 through 100000; omit means 2000
- `gravity_multiplier`: finite Lua number; omit means 1
- `drag_multiplier`: finite Lua number >= 0; omit means 1
- `muzzle_velocity_blocks_per_tick`: finite Lua number greater
  than 0; skips Robins

## Outputs

One table. That table is the only return value.

- `yaw_degrees`: Minecraft facing, 0 = +Z south, positive toward
  -X west
- `pitch_degrees`: elevation from horizontal, positive muzzle up;
  inclusive -90 through 90
- `time_of_flight_ticks`: integer intercept tick
- `muzzle_velocity_blocks_per_tick`: launch speed used
- `impact_x`, `impact_y`, `impact_z`: simulated projectile pose at
  that tick
- `trajectory`: `low` or `high` (the requested family name;
  `low` if omitted), even when only one elevation family exists

## Callers

- Engage Simulated Bearing Turret

## Callees

- Read Radar Tracks, only when `track` is omitted

## Edges

- Extra arguments, omitted `opts`, nil `opts`, a non-table `opts`,
  or an unknown `opts` key fail loud
- A present optional string that is not a string fails loud
- Empty string on `radar_name` / `monitor_name` / `trajectory` /
  `projectile_kind` is omit
- `radar_name` or `monitor_name` present (non-omit) together with
  `track` fails loud
- Missing, non-number, NaN, or infinite required numbers fail loud
- Mass, powder, charge length, barrel length, or override muzzle
  speed <= 0 fail loud
- `drag_multiplier` < 0 fails loud
- `max_ticks` not an integer in 1..100000 fails loud
- `trajectory` other than omit / `low` / `high` fails loud
- `projectile_kind` other than omit / `cannon` / `autocannon` /
  `machine_gun` fails loud
- `track` present but not a table fails loud
- `track` missing required row shape (non-empty string `id`,
  position and velocity tables with finite numeric x/y/z) fails
  loud
- `track` omitted: call Read Radar Tracks; a throw from that call
  fails loud; `selectedTrack` nil fails loud
- Do not pick `tracks[1]` when selection is absent
- Do not strip gravity from track velocity
- Do not rewrite PLAYER `velocity.y`
- A grounded caller passes `velocity.y` already 0 on the track
- Lead is `position + velocity * t` in blocks and ticks
- Muzzle is the spawn point; do not add barrel length as a second
  origin offset
- Robins uses Java constant 606.8568 m/s, then /20 for
  blocks/tick; README 1991 is ft/s and is not the Lua constant
- `L/c` below 1 uses ratio 1.000001, same as Java
- Robins result non-positive fails loud
- Gravity is -9.80665/400 times `gravity_multiplier`
- Drag is Going Ballistic quadratic (Cd 0.47, air 1.225, area from
  kind); not CBC 0.99 and not gravity -0.05
- One block is one meter in the drag area
- In-flight step copies CBC 1.21.1 `getForces` (drag along
  velocity plus gravity on Y; pos += vel + 0.5*accel; vel +=
  accel)
- Zero speed during a sample ends that sample
- Horizontal distance to lead below 1e-9: `yaw_degrees` is 0
  (Minecraft south, +Z); a zero-length XZ vector has no facing
- Pitch search is -90 through 90 degrees inclusive; ±90 is a
  vertical launch (yaw unused for direction). Excluding ±90 would
  make overhead intercepts fail by construction
- A coarse hit is miss <= 1 block. Consecutive 1-degree hits are
  one elevation family (one ballistic root). The family's pitch
  is the sample in that band with smallest miss, not the band's
  min or max graze
- Two elevation families exist when two disjoint hit bands
  exist. Low is the lower-elevation band's root. High is the
  higher-elevation (steep) band's root
- One hit family: that solution is returned for either requested
  `trajectory`; output `trajectory` equals the request (`low` if
  omitted)
- The intercept search is eight frozen-lead iterations then one
  moving-lead check; miss > 1 block on that check fails loud as
  `no intercept`. That is the whole search. An exhaustive t sweep
  is not a second try and is not a second command
- Does not wrap peripherals
- Nested pitch/tick search does not yield (`sleep` /
  `os.pullEvent` / dummy queued event)
- ComputerCraft `Too long without yielding` during that search is
  a fail; the host message is not wrapped; it is not
  `no intercept`; does not sleep-retry; caller lowers `max_ticks`
  or accepts the throw
- Completing the published grid inside a given computer's timeout
  is out of contract
- Does not rotate bearings or fire
- Does not convert yaw/pitch into Simulated bearing-local degrees
- Fluid drag, bounce, and block clip are out of scope
