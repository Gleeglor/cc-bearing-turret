# Read Radar Tracks

Load the current Create Radar track list from a dish that is not on
the gun bearing.

## Level

Basic.

Ainterface command: `bearing_turret.read_radar_tracks`.

## Who

ComputerCraft program on a computer wired to the dish.

## When

A dish is attached. Each time a caller needs this tick's tracks.

## Where

Amazeballs world. ComputerCraft peripheral wrap on that computer.

## Why

Create Radar yaw and pitch controllers drive cannon mounts. They
cannot aim Simulated swivel bearings. Callers read tracks here.

## Inputs

One optional table `opts`. Arity 0 or 1.

- `radar_name`: optional string on that table (rotating dish or
  stationary plane radar)
- `monitor_name`: optional string on that table

Monitor-only: `{ monitor_name = "<name>" }` with `radar_name`
omitted.

## Outputs

One table. That table is the only return value.

- Track list (id, world-block position {x,y,z}, velocity in
  blocks per tick, category, scanned time, entity type)
- Selected track: a track map or nil. A returned map has required
  row shape and the same optional-field sanitization as a list
  row.
- Selected track id: a non-empty string or nil

## Callers

- Aim Turret At Target
- Compute Ballistic Aim

## Callees

None.

## Edges

- Missing radar peripheral fails loud
- More than one radar (rotating dish and/or plane radar) and no
  name fails loud
- Rotating dish and plane radar are both valid sources; same
  track shape
- Empty track list is a live empty result, not a failure
- Monitor name omitted and zero Create Radar monitors
  discovered: selected is absent
- Named monitor not attached fails loud
- More than one Create Radar monitor and no name fails loud
- Named monitor that is a CC screen, not a Create Radar monitor,
  fails loud
- Radar name and monitor name are independent
- Monitor linked to a different dish than the tracks source is not
  a failure
- Selected id is the monitor's report, not a row copied from the
  dish list
- Selected track is the monitor map only when that id is in this
  tick's list, the map has row shape, and map `id` equals
  selectedTrackId; otherwise selected track is nil
- Monitor selected map whose `id` is a non-empty string and
  differs from selectedTrackId: selected track nil, selected id
  kept, list unchanged, not a failure
- No monitor, empty selected id from the peripheral, or unlinked
  monitor: both selected values are nil
- Monitor present with empty selected id means no operator pick;
  both selected values are then nil
- Selected id missing from this tick's track list: selected track
  nil, selected id still returned, list unchanged, not a failure
- Do not drop a selected id to make a miss look like no pick
- Non-empty selected id with empty selected map: selected track
  nil, not a failure
- Selected map that fails the same id/position/velocity checks as
  a track row: selected track nil, list still returned, not a
  failure
- Resolved monitor whose selected-track or selected-id read
  throws fails the whole read loud
- Extra arguments, a non-table `opts`, or an unknown `opts` key
  fail loud
- A radar name or monitor name that is present and not a string
  fails loud
- Present `scannedTime` that is not a Lua number: fail the whole
  read. Missing or nil: omit that key. Present number: keep.
- Missing or nil `category` / `entityType`: write `""`. Present
  string: keep. Present not a string: fail the whole read.
- A returned selected track map takes the same optional-field
  output sanitization as a list row
- Track list not a list of maps fails loud
- A track row that is not a table fails loud
- Empty-string track id fails loud (same as missing id)
- Track id present but not a string fails loud
- Missing position fails loud, same as missing id
- Track position present but not a table fails loud
- Missing velocity fails loud, same as missing position
- Selected-id read that is not a string fails loud; empty string
  is absent (both selected fields nil)
- Velocity is the peripheral's vector in blocks per tick,
  including gravity
- Categories are not dropped
- Does not rotate bearings, compute lead, or fire
