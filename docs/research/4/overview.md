# How Should A ComputerCraft Program Fire The Rotating Barrel Once It Is Aimed?

## Who

ComputerCraft program on the gun computer.

## What

Pulse analog strength 1 for two game ticks on the Create Big
Cannons mount fire face, then 0, so the rotating autocannon
fires once.

## When

The barrel loop is spinning and a shot is wanted.

## Where

Amazeballs world. Mount fire face, separate from the aim motors.
ComputerCraft redstone API or a `redstone_relay` on that face.

## Why

Create Big Cannons has no ComputerCraft fire method. The native
trigger is analog redstone on the mount fire face. Aim does not
pull the trigger.

CBC `create-v6-1.21.1` ships no Lua peripheral. Third-party
`cannon_mount.fire` addons are not on the Amazeballs jar list
and they take over CBC mount aim.

Autocannon fire rate is analog 1-15 on the fire face. Strength
15 is 300 RPM and can spray. Strength 1 is 10 RPM (120-tick
cooldown), so a two-tick pulse is one shot. `setOutput(true)` is
15; do not use it. Two analog writes in the same computer tick
leave the world at 0, so `sleep(0.1)` sits between 1 and 0.

`side` is required. Optional `relay_name` wraps a
`redstone_relay` when the computer is not on the fire face.
Success is the pulse, not a projectile. Empty ammo and a
disassembled mount are silent in CBC.

Paper: [paper](paper.md).
