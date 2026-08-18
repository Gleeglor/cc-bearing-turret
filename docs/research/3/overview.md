# How Should A ComputerCraft Program Set Create Addition Electric Motor Speed Without Tripping The Motor's Write Rate Limit?

## Who

ComputerCraft program wired to a Create Crafts and Additions electric
motor.

## What

Set that motor's commanded speed.

## When

The motor peripheral is attached.

## Where

Amazeballs world. Kinetic network on the bearing.

## Why

Bearings turn from kinetic input. This is the write primitive. Native
swivel ComputerCraft cannot set angle.

Wrap type `electric_motor`. Lua takes one `opts` table: required
`rpm`, optional `motor_name`. `getSpeed` is commanded `motorSpeed`.
Generated shaft speed can be 0 while that command is non-zero.
`getSpeed` and `setSpeed` are both `mainThread`. After wrap and a
finite `rpm`, the command always calls `getSpeed`; that wait is
in-contract, including when it then skips `setSpeed`.

Skip is raw Lua `==` of `getSpeed` and `rpm`. If `getSpeed` already
equals `rpm`, do not call `setSpeed`. Skipping `setSpeed` skips the
second call when the motor already reports `rpm`. Delay (`setRPM`
applies on the next motor tick; a later same-`rpm` call before that
tick may `setSpeed` again), clamp (an out-of-range `rpm` never
equals `getSpeed` after Java clamp), and float mismatch (Lua double
vs Java float) still call `setSpeed`. Lua does not remember last
requested RPM. Those extra writes are allowed. On this pack they
cannot throw.

An unpowered or redstone-stopped motor still succeeds and still
skips. Success does not mean `getSpeed` already equals `rpm`;
`getSpeed` may lag until the next motor `tick()`. Success does not
mean the shaft is turning at `rpm`. Amazeballs is Create Addition
1.21.1: `setRPM` always succeeds, so the documented anti-spam throw
is dead. If that throw still fires, fail loud. Do not `sleep` and
retry. Do not use `rotate` or `translate`. RPM 0 is a stop. Missing
or wrong-type wrap, a non-finite `rpm`, or any other throw fails
loud.

Paper: [paper](paper.md).
