# Read Radar Tracks

## What

Load the current Create Radar track list from a dish that is not on
the gun bearing.

## How

Lua call: `bearing_turret.read_radar_tracks(opts)`. Arity is 0 or
1. A second argument fails loud. `opts` omitted or `nil` means
both names discover (empty table). `opts` a table: read
`radar_name` and `monitor_name` only. Any other key fails loud,
including array index `1`. `opts` any other Lua type fails loud.
A string is not positional arg 1. A wrap table is not `opts`.

The only-monitor call is the `monitor_name` key with `radar_name`
omitted. Setting `radar_name` to `nil` is the same omit. Setting
it to `""` is discover.

Find one Create Radar dish peripheral. A dish is either the
rotating radar (`create_radar:radar`) or the stationary plane
radar (`create_radar:plane_radar`). If a name is given, wrap that
name and require it to be one of those types. If no name is given,
find every attached peripheral of either type; require exactly one.

Call `getTracks` on that dish. Each row is a map with `id`,
`position`, `velocity`, `category`, `scannedTime`, and `entityType`.
Each track row `id` is a non-empty string. `position` and
`velocity` are maps with numeric `x`, `y`, and `z`.

`position` is `{x, y, z}` in Minecraft world coordinates, units
blocks, Vec3 doubles. Same frame on selected track. Radar-local
and plotyard-local would need a transform this function does not
apply. Dish `getPosition` plotyard conversion is the dish pose
only.

Velocity components are Minecraft entity delta movement in blocks
per tick. The vector is the peripheral's, including gravity.

`getTracks` must be a Lua list of maps: empty (no keys) or a dense
sequence of integer keys `1..n`, each value a table.

If no monitor name is given, find attached peripherals of that
type. Name omitted (nil or empty string): zero monitors means
selected is absent; one is the selection source; two or more fail
loud. If a monitor name is given, wrap that name only. Wrap nil
fails loud. Require type `create_radar:monitor`. Wrap-nil and
wrap-non-nil wrong type are different failure classes.

One resolved monitor: `pcall` only `getSelectedTrackId`. On throw,
end the read. Type-check string. Non-string ends the read. Then
`pcall` only `getSelectedTrack`, even when the id is `""`. On
throw, end the read. Type-check table before any field access.
Non-table fails the whole read. Empty table: `selectedTrack` nil.
Id `""`: both selected fields nil. Non-empty id: keep the id.

A selected map is usable when it has required row shape (id,
position, velocity). A returned selected map then receives the
same optional-field sanitization as a list row. Map `id` a
non-empty string that does not equal `selectedTrackId`: omit
`selectedTrack`, keep `selectedTrackId`.

Do not `peripheral.find("monitor")`. That type is the CC screen.

After wrapping both peripherals, do not compare them for a shared
controller. Do not treat list inequality, or selected id missing
from the list, as a pairing failure.

Return exactly one value: a table with keys `tracks`,
`selectedTrack`, and `selectedTrackId`. `tracks` is the list from
`getTracks`. Do not return those three pieces as multiple Lua
values. Do not hang selected fields on the list table.

When selected is absent (no monitor, or monitor no-pick:
`getSelectedTrackId` is `""`), selected track and selected id are
both `nil`. An empty `getSelectedTrack` map is not returned as the
selected track.

If selected id is non-empty, look up that string in the dish list.
Miss: selected track absent, keep the id, return the list, do not
error. Hit: selected track is the monitor map when that map
passes row shape and its `id` equals selectedTrackId; otherwise
selected track is absent and the id is kept.

The call yields (main-thread peripheral). The caller must tolerate a
tick wait.

### Preconditions

- A Create Radar dish exists off the gun's Simulated bearing and is
  attached to the computer (wired modem clicked).
- The dish type string is `create_radar:radar` or
  `create_radar:plane_radar`.
- `opts` is nil or a table of `radar_name` / `monitor_name` keys.
- Names inside `opts` are strings or absent.

### Postconditions

- The success return is exactly one table. `tracks` is always
  present. `selectedTrack` and `selectedTrackId` are present when
  a value exists and omitted when absent (Lua `nil`).
- Every returned track has a non-empty string `id`, numeric
  world-block position x/y/z, and numeric velocity x/y/z.
- Every returned track map has string `category` and string
  `entityType`; empty string is allowed.
- The list still contains every track the dish returned. No
  category is removed.
- Velocity is the peripheral's vector, unaltered, in blocks per
  tick, including gravity.
- No pick means both selected fields `nil`, never `""` or `{}`.
- A present selected id is the monitor's reported id even when no
  returned row has that id.

### Invariants

- This function does not write to any peripheral.
- This function does not assemble, lock, or rotate a bearing.

### Failure modes

Fail loud on this page means `error(message)` with a required
distinguishing message.

- Extra arguments:
  `Read Radar Tracks: expected at most one argument, got <n>`
- Argument present and not a table:
  `Read Radar Tracks: inputs must be a table or nil, got <type>`
- Unknown `opts` key:
  `Read Radar Tracks: unknown input '<key>'`
- No radar peripheral, or named radar missing / wrong type: fail
  loud.
- Two or more dishes (either type) and no name: fail loud.
- Two or more Create Radar monitors and no monitor name: fail loud.
- Named monitor wrap-nil: fail loud.
  Diagnostic:
  `Read Radar Tracks: named monitor '<name>' is not attached`
- Named monitor wrap-non-nil and `getType` is not exactly
  `create_radar:monitor`: fail loud.
  Diagnostic:
  `Read Radar Tracks: named monitor '<name>' is type '<type>', expected create_radar:monitor`
- `getSelectedTrackId` not a Lua string (nil, number, boolean,
  table, function, userdata, thread): fail loud. `""` stays
  no-pick, both selected fields nil.
  Diagnostic:
  `Read Radar Tracks: getSelectedTrackId on monitor '<name>'
  returned <type>, expected string`
- `getSelectedTrack` not a Lua table (nil, number, string,
  boolean, function, userdata, thread): fail loud.
  Diagnostic:
  `Read Radar Tracks: getSelectedTrack on monitor '<name>'
  returned <type>, expected table`
- Radar name or monitor name present and not a string: fail loud.
- `getTracks` throws: fail loud.
- `getTracks` not a list of maps (nil, scalar, named-key table,
  hole): fail loud.
- A list entry that is not a table: fail loud.
- A track row missing `id`: fail loud.
- A track row with `id` equal to `""`: fail loud.
- A track row whose `id` is present and not a Lua string: fail
  loud.
- A track row missing `position`: fail loud.
- A track row whose `position` is present and not a Lua table:
  fail loud.
- A track row whose `position` is a table but `x`, `y`, or `z` is
  missing or not numeric: fail loud.
- A track row missing `velocity`, whose `velocity` is not a table,
  or whose `velocity` table lacks numeric `x`/`y`/`z`: fail loud.
- Present `scannedTime` that is not a Lua number: fail loud.
  Diagnostic:
  `Read Radar Tracks: track '<id>' scannedTime is <type>, expected number`
- Present `category` that is not a Lua string: fail loud.
  Diagnostic:
  `Read Radar Tracks: track '<id>' category returned <type>, expected string`
- Present `entityType` that is not a Lua string: fail loud.
  Diagnostic:
  `Read Radar Tracks: track '<id>' entityType returned <type>, expected string`
- `getSelectedTrack` or `getSelectedTrackId` throws: fail loud.
  Diagnostic:
  `Read Radar Tracks: getSelectedTrackId threw on monitor '<name>': <original>`
  or
  `Read Radar Tracks: getSelectedTrack threw on monitor '<name>': <original>`.
  Do not encode that throw as selected absent.

### Non-failures

- Pairing mismatch is not a failure mode.
- Selected id not in this tick's list is not a failure mode.
- Non-empty selected id with empty selected map is not a failure
  mode.
- Selected map that fails row-shape checks is not a failure mode;
  omit selected track only.
- Selected map `id` a non-empty string that differs from
  selectedTrackId is not a failure mode; omit selected track
  only.

### Sanitization

- Names are strings or absent. Empty string is absent. Any other
  Lua type fails loud. No `tostring`. No wrap table as a name.
- `opts` omitted or nil is discover. Extra arguments, a non-table
  `opts`, or an unknown key fail loud as envelope failures.
- When selected is absent, translate Create Radar `""` and empty
  selected map to `nil`; do not pass them through.
- `id` must be a Lua string when present; any other Lua type fails
  loud. `position` must be a Lua table with numeric `x` / `y` /
  `z`. Missing key fails loud. Present and not a table fails loud.
- `getSelectedTrackId` must be a Lua string. Empty string is the
  only no-pick. Do not coerce. Do not treat a non-string as
  absent. Do not keep the dish list. Do not take an id from
  `getSelectedTrack`.
- `getSelectedTrack` must be a Lua table. Type-check before field
  access. Non-table fails the whole read. Empty table is miss,
  not nil.
- Optional-field pass runs after id, position, and velocity pass,
  on every returned track map: each `tracks` row and a present
  `selectedTrack`. Order: `scannedTime`, then `category`, then
  `entityType`.
- `scannedTime` missing or nil: omit. Present Lua number: keep.
  Present any other type: fail the whole read. No `tonumber`.
- `category` and `entityType` missing or nil: write `""`. Present
  Lua string: keep. Present any other type: fail the whole read.
  No `tostring`. No whitelist.
- Selected optional keys are not left as raw monitor values.
- Do not subtract gravity from velocity. Do not drop HOSTILE /
  PLAYER / SABLE / other categories. Do not zero-fill absent
  velocity.

## Why

Create Radar yaw and pitch controllers drive cannon mounts, not
Simulated swivel bearings. The dish can still list world-block
coordinates when it is not on the gun assembly.

Callers are other Lua functions, so the compose unit is one table.

The list is read from the dish because a monitor empty list cannot
tell unlinked from no contacts. Clicks live on the monitor. That
split accepts that selected may describe a different radar network
than the list. Dropping a selected id would collapse a stale or
out-of-list pick into no pick. Erroring would collapse a live radar
tick into a dead read. The id is the operator click; the list is
the dish this tick; the selected map is a pose only when that id
is in the list, the map has row shape, and map `id` equals
selectedTrackId.

Velocity is the peripheral's Minecraft entity delta movement in
blocks per tick, including gravity. A standing player reports
`y = -0.08`. A player in creative flight reports `y = 0` while
stationary. This function does not convert to blocks per second
and does not strip gravity. Zero-fill would make a missing
vector look like a parked entity, so the read fails instead. Lead
math is a different function and must name any gravity strip in
its own spec.

## SOLID

- Single responsibility: read tracks. No aim, no fire, no motor.
- Compose later: Aim Turret At Target and Compute Ballistic Aim call
  this. This page does not call them.
- No caller-identity branching: gun computer and a ground computer
  get the same read.

## Compatibility

Basic. May be called by advanced and high-level functions. Must not
call other workspace functions.
