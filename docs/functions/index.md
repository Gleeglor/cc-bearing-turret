# Functions

Hierarchical ComputerCraft capabilities for the Amazeballs bearing
turret. Product features stay out of this catalog.

## Basic

- [Read Radar Tracks](/functions/basic/read-radar-tracks) - load the
  current Create Radar track list from a dish that is not on the gun
  bearing (`bearing_turret.read_radar_tracks`)
- [Read Swivel Bearing Angle](/functions/basic/read-swivel-bearing-angle)
  - read the stored servo target of one Simulated swivel bearing via
  `getTargetAngle`; visual or physics orientation is out of reach
  (`bearing_turret.read_swivel_bearing_angle`)
- [Set Electric Motor Speed](/functions/basic/set-electric-motor-speed)
  - set one Create Addition electric motor's commanded RPM, skipping
  `setSpeed` when `getSpeed` already equals the request; out-of-range
  requests always write
  (`bearing_turret.set_electric_motor_speed`)
- [Fire Rotating Barrel](/functions/basic/fire-rotating-barrel) -
  pulse analog strength 1 for two game ticks on a Create Big Cannons
  mount fire face, then 0
  (`bearing_turret.fire_rotating_barrel`)

## Advanced

(none)

## High-level

(none)
