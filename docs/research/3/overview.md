# How Should A ComputerCraft Program Set Create Addition Electric Motor Speed Without Tripping The Motor's Write Rate Limit?

## Who

ComputerCraft program wired to a Create Crafts and Additions electric
motor.

## What

Set that motor's speed.

## When

The motor peripheral is attached.

## Where

Amazeballs world. Kinetic network on the bearing.

## Why

Bearings turn from kinetic input. This is the write primitive. Native
swivel ComputerCraft cannot set angle.

Wrap type `electric_motor`. Lua takes one `opts` table: required
`rpm`, optional `motor_name`. If `getSpeed` already equals `rpm`, do
not call `setSpeed`. Otherwise `setSpeed`. Amazeballs is Create
Addition 1.21.1: `setRPM` always succeeds, so the documented
anti-spam throw is dead. If that throw still fires, fail loud. Do not
`sleep` and retry. Do not use `rotate` or `translate`. RPM 0 is a
stop. Missing or wrong-type wrap, a non-finite `rpm`, or any other
throw fails loud.

Paper: [paper](paper.md).
