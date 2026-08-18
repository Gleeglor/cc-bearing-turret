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

## Advanced

(none)

## High-level

- [Engage Simulated Bearing Turret](/functions/high-level/engage-simulated-bearing-turret)
  - one engagement step: ballistic solution from the selected
  radar track, aim Simulated yaw and pitch bearings, fire only
  when on target (`bearing_turret.engage_simulated_bearing_turret`).
  Specialized task script.
