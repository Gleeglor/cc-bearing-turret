# How Should ComputerCraft Read A Target Pose From Create Radar Off The Gun Bearing?

## Who

ComputerCraft program on a computer wired to the dish.

## What

Load the current Create Radar track list from a dish that is not
on the gun bearing.

## When

A dish is attached. Each time a caller needs this tick's tracks.

## Where

Amazeballs world. ComputerCraft peripheral wrap on that computer.

## Why

Create Radar yaw and pitch controllers drive cannon mounts. They
cannot aim Simulated swivel bearings. Callers read tracks here.

Keep the radar and its monitor off the Simulated gun bearing. Wrap the
Create Radar dish (rotating or plane) and the monitor by their type
ids. Lua takes one optional `opts` table. Monitor-only is
`{ monitor_name = "<name>" }` with `radar_name` omitted. The read
returns one table of raw maps. Each track has world-block
`position` (`{x, y, z}` doubles), `velocity` in blocks per tick
(peripheral vector, gravity included), `id`, and `category`.

Absent selected track and selected id are `nil`, not the peripheral's
empty string or empty map. A missing or unusable dish errors with a
message; it does not return nil.

Radar name and monitor name are independent. Selected id is the
monitor's report even when that monitor is not the dish that supplied
the track list. That split is not a failure. A selected id missing
from this tick's list still comes back with the list; the selected
track is absent; the read does not fail. A leftover selected id with
an empty selected map is a missing pose. The read still returns. A
selected map that fails id/position/velocity checks is omitted; the
track list still returns. A selected map whose `id` is a non-empty
string and differs from the monitor selected id is omitted; the id
and the list still return.

A throw from `getSelectedTrack` or `getSelectedTrackId` fails the
read; that is a broken monitor call. Empty-pick returns are `""` /
empty map. A non-list `getTracks` result, or a row that is not a map,
is a failure. Do not skip that row. Missing velocity is a broken row
and fails loud; do not zero-fill. Missing position is a broken row
and fails loud, same as missing id; do not zero-fill.

Zero Create Radar monitors when the name is omitted leaves selected
absent. Two or more Create Radar monitors with no name fails loud.
Pass a monitor name when more than one is attached. A supplied
monitor name that wraps to nil fails loud.

A throw from `getSelectedTrack` or `getSelectedTrackId` fails the
read; that is a broken monitor call. Empty-pick returns are `""` /
empty map. `getSelectedTrackId` that is not a Lua string fails the
read. Empty string is the only no-pick. Do not treat a number,
boolean, or table as absent.

Do not use radar yaw/pitch controllers to move this gun. They drive
CBC mounts, which is why aim already fails on Simulated bearings.

Paper: [paper](paper.md).
