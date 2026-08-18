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

- [Rotate Bearing Toward Angle](/functions/advanced/rotate-bearing-toward-angle)
  - one closed-loop step: read one stored swivel target, command one
  motor toward a commanded angle, return signed shortest-path error
  (`bearing_turret.rotate_bearing_toward_angle`)

## High-level

- [Aim Turret At Target](/functions/high-level/aim-turret-at-target) -
  high-level specialized task script; one dual-axis tick: confirm
  a live radar target and drive yaw and pitch Simulated swivels
  toward caller-supplied ballistic degrees; return `{ on_target }`
  (`bearing_turret.aim_turret_at_target`)
- [Engage Simulated Bearing Turret](/functions/high-level/engage-simulated-bearing-turret)
  - one engagement step: ballistic solution from the selected
  radar track, aim Simulated yaw and pitch bearings, fire only
  when on target (`bearing_turret.engage_simulated_bearing_turret`).
  Specialized task script.
