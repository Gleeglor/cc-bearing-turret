# How Should A ComputerCraft Program Compute Yaw And Pitch That Hit A Moving Target Under Create Big Cannons Going Ballistic Physics?

## Who

ComputerCraft program on the gun computer.

## What

Compute yaw and pitch that intercept a radar track under Going
Ballistic physics.

## When

A track is selected or supplied. Muzzle pose and shot parameters
are known.

## Where

Same computer. Lua only. No peripheral write.

## Why

Going Ballistic has no ComputerCraft API. Create Radar controllers
still use vanilla CBC ballistics and drive CBC mounts, not
Simulated bearings.

Lua takes one `opts` table. Required: muzzle world `x/y/z` (barrel
tip spawn), projectile mass, powder mass, charge length, barrel
length (Robins m, p, c, L). Optional `track` is a ticket 1 row.
Omit track to call `read_radar_tracks` and use `selectedTrack`.
Missing selection fails loud. Do not pick the first list row.

Muzzle speed is Robins with Java constant 606.8568 m/s, then /20
for blocks/tick. That 606.8568 is the README 1991 ft/s constant in
meters. Do not launch at 1991 m/s. Do not treat powder count as
speed. Optional `muzzle_velocity_blocks_per_tick` skips Robins.

In flight, copy CBC 1.21.1: acceleration is minus drag along
velocity plus Going Ballistic Earth gravity
(-9.80665/400 blocks/tick^2). Drag is quadratic (Cd 0.47, air
1.225, area from `projectile_kind`). Do not use the public CBC
calculators' 0.99 drag and -0.05 gravity.

Lead uses the track velocity as constant blocks/tick, gravity
included. Do not strip Y. A grounded caller passes velocity Y = 0
on the track. Search time of flight with eight frozen-lead
iterations then one moving-lead check. That procedure is the
whole search. `no intercept` means it missed (miss > 1 block)
under these physics and that cap, not that every t was tried.
Prefer the low elevation root. When two disjoint elevation roots
hit the same lead, `trajectory` `"high"` selects the steep root.
One root is returned for either request. Yaw is Minecraft facing
(0 = +Z). When the lead is straight above or below the muzzle
(horizontal length below 1e-9), yaw is 0: there is no horizontal
facing. Pitch is elevation, positive up, including straight up
and straight down (±90). A vertical launch is a well-defined unit
vector; CBC `getForces` may normalize it because speed is still
the muzzle speed. Stopping the search at ±89 would miss overhead
intercepts by construction. Aim Turret maps those onto bearings.
This command does not rotate or fire.

The nested pitch/tick search does not yield. A ComputerCraft
`Too long without yielding` abort during that search is a fail.
The host message is not wrapped. It is not `no intercept`. Do
not sleep-retry. Completing the published grid inside a given
computer's timeout is out of contract; lower `max_ticks` or
accept the throw. The only in-contract yield is the child radar
read when `track` is omitted.

Paper: [paper](paper.md).
