# Pseudocode

One topic: `bearing_turret`. Module level: high-level.
Specialized task script. Function level is per node. Do not
split this tree into sibling repos.

- bearing_turret.engage_simulated_bearing_turret
  - bearing_turret.compute_ballistic_aim
    - bearing_turret.read_radar_tracks
  - bearing_turret.aim_turret_at_target
    - bearing_turret.read_radar_tracks
    - bearing_turret.rotate_bearing_toward_angle
      - bearing_turret.read_swivel_bearing_angle
      - bearing_turret.set_electric_motor_speed
  - bearing_turret.fire_rotating_barrel

Leaves are ainterface commands. On `ainterface.json` now:
`bearing_turret.read_radar_tracks`,
`bearing_turret.read_swivel_bearing_angle`, and
`bearing_turret.set_electric_motor_speed`. Other basic leaves
join the contract when their tickets enter the Vestibule.
Non-leaf names are this topic's functions. They are not other
topics. They join the ainterface when their own tickets enter the
Vestibule.

Lua call this ticket:
`bearing_turret.engage_simulated_bearing_turret(opts)`. `opts` is
a table of ainterface input keys. Axis bearing and motor names
are required. Success is one table (`on_target`, `fired`).

## bearing_turret.engage_simulated_bearing_turret

Parent [#8](https://github.com/Gleeglor/cc-bearing-turret/issues/8).
High-level specialized script.

- [Overview](/research/8/overview)
- [Paper](/research/8/paper)

### Who

ComputerCraft program on the gun computer.

### What

Track, aim, and fire the Simulated bearing gun.

### When

The operator wants engagement. Radar, motors, and barrel are
attached.

### Where

Amazeballs world. Gun on Simulated swivel bearings.

### Why

This is the product act. Radar mount controllers cannot aim these
bearings.

## bearing_turret.compute_ballistic_aim

[#7](https://github.com/Gleeglor/cc-bearing-turret/issues/7).
Advanced. No research page yet.

### Who

ComputerCraft program on the gun computer.

### What

Turn a track pose into a firing solution.

### When

A track is selected or chosen.

### Where

Same computer. No peripheral write.

### Why

Going Ballistic has no ComputerCraft API. Lead is computed in Lua.

## bearing_turret.aim_turret_at_target

[#6](https://github.com/Gleeglor/cc-bearing-turret/issues/6).
Advanced. No research page yet.

### Who

ComputerCraft program on the gun computer.

### What

Drive yaw and pitch bearings to a commanded angle.

### When

A firing solution or angle command exists.

### Where

Kinetic motors on Simulated swivel bearings.

### Why

Native swivel ComputerCraft is read-only. Motors are the write
path.

## bearing_turret.rotate_bearing_toward_angle

[#5](https://github.com/Gleeglor/cc-bearing-turret/issues/5).
Advanced. No research page yet.

### Who

ComputerCraft program on the gun computer.

### What

Run one bearing toward a target angle.

### When

Current angle and target angle are known.

### Where

One electric motor and one swivel bearing.

### Why

Closed loop on one axis. Aim composes this twice.

## bearing_turret.read_radar_tracks

[#1](https://github.com/Gleeglor/cc-bearing-turret/issues/1).
Basic. On the ainterface this ticket.

- [Functional](/functions/basic/read-radar-tracks)
- [Technical](/functions/basic/read-radar-tracks.technical)
- [Overview](/research/1/overview)
- [Paper](/research/1/paper)

### Who

ComputerCraft program on a computer wired to the dish.

### What

Load the current Create Radar track list from a dish that is not
on the gun bearing.

### When

A dish is attached. Each time a caller needs this tick's tracks.

### Where

Amazeballs world. ComputerCraft peripheral wrap on that computer.

### Why

Create Radar yaw and pitch controllers drive cannon mounts. They
cannot aim Simulated swivel bearings. Callers read tracks here.

## bearing_turret.read_swivel_bearing_angle

[#2](https://github.com/Gleeglor/cc-bearing-turret/issues/2).
Basic. On the ainterface this ticket.

- [Functional](/functions/basic/read-swivel-bearing-angle)
- [Technical](/functions/basic/read-swivel-bearing-angle.technical)
- [Overview](/research/2/overview)
- [Paper](/research/2/paper)

### Who

ComputerCraft program wired to a Simulated swivel bearing.

### What

Read the bearing's current target angle.

### When

The bearing peripheral is attached.

### Where

Amazeballs world. Native swivel ComputerCraft wrap.

### Why

Closed-loop rotate needs the angle. Native wrap is read-only.

## bearing_turret.set_electric_motor_speed

[#3](https://github.com/Gleeglor/cc-bearing-turret/issues/3).
Basic. On the ainterface this ticket.

- [Functional](/functions/basic/set-electric-motor-speed)
- [Technical](/functions/basic/set-electric-motor-speed.technical)
- [Overview](/research/3/overview)
- [Paper](/research/3/paper)

### Who

ComputerCraft program wired to a Create Crafts & Additions
electric motor.

### What

Set that motor's speed.

### When

The motor peripheral is attached.

### Where

Amazeballs world. Kinetic network on the bearing.

### Why

Bearings turn from kinetic input. This is the write primitive.

## bearing_turret.fire_rotating_barrel

[#4](https://github.com/Gleeglor/cc-bearing-turret/issues/4).
Basic. Not yet on the ainterface.

### Who

ComputerCraft program on the gun computer.

### What

Fire the rotating barrel once.

### When

The barrel loop is spinning and a shot is wanted.

### Where

Amazeballs world. Barrel fire path, separate from the aim motors.

### Why

Firing is its own kinetic loop. Aim does not pull the trigger.
