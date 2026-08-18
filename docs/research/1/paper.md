# How Should ComputerCraft Read A Target Pose From Create Radar Off The Gun Bearing?

Amazeballs can already see targets on a Create Radar monitor. The gun sits
on Simulated swivel bearings, so the radar dish and the radar yaw/pitch
controllers cannot ride that assembly. This paper asks how a ComputerCraft
program still gets a target pose from that radar.

## Context

The client wants a spinning barrel on Create Simulated bearings to aim and
fire. Create Radar's auto yaw/pitch controllers drive Create Big Cannons
mounts. They do not drive Simulated swivel bearings. Putting the radar
multiblock on the gun bearing does not give aim.

The pack already has the pieces needed to read tracks without putting the
dish on the gun:

- Create Radar 0.4.9.4 exposes ComputerCraft generic peripherals on the
  monitor and on the radar bearing.
- CC: Tweaked 1.120.0 can wrap those peripherals over a wired modem.
- The gun's Simulated swivel bearings stay a separate kinetic assembly.

This ticket is only the read. Aim, ballistics, motor drive, and fire are
sibling tickets.

## Known Approaches

### Drive The Gun With Radar Yaw And Pitch Controllers

Create Radar registers `yaw_controller` and `pitch_controller` peripherals
with `setAngle` / `getAngle`. Those block entities talk to the radar
weapon network and to CBC mounts. The client's gun is not on a CBC mount.
It is on Simulated swivel bearings. This path is the one that already
failed in world. It is not the read path either: even if it worked, it
would skip exposing a pose to a script.

### Put The Radar Dish On The Simulated Gun Bearing

Create Radar's radar-bearing peripheral (`create_radar:radar`,
`RadarBearingPeripheral.id()`) can list tracks (`getTracks`) and its own
pose (`getPosition`, `getRotation`). That `getPosition` is the dish
block, not a track. If Sable is loaded and the block is in a plotyard,
it uses `PhysicsHandler.getWorldPos`. Track `position` does not take
that branch. The client's report is that radar-driven *aim* does not
work on bearings. Using the dish as a sensor while it is assembled onto
the same Simulated gun is unproven and mixes sensor motion into the gun
assembly. Rejected for this function.

The stationary plane radar (`create_radar:plane_radar`,
`PlaneRadarPeripheral.id()`) has the same `getTracks` map shape. The
monitor is `create_radar:monitor` (`MonitorPeripheral.id()`).

### Read Tracks From A Monitor Or Radar That Is Not On The Gun

Create Radar's monitor peripheral yields:

- `getTracks()` - list of maps
- `getSelectedTrack()` - one map, or empty
- `getSelectedTrackId()` - selected id string, or `""`

`getSelectedTrackId` can be a non-empty string while `getSelectedTrack`
is an empty map. The id is `controller.getSelectedEntity()`. The map is
a lookup of that id in `controller.getTracks()`. A miss returns
`new HashMap<>()`, same as no controller and same as no pick. Cache
rebuild can null `activetrack` on a miss and still leave
`selectedEntity` set. The id is persisted as `SelectedEntity`. Stale
click, entity gone, or filtered-out this tick are that pair. That pair
is a missing selected pose.

Each track map has:

- `id` - non-empty entity UUID string. `""` is not a valid
  `getTracks` row; it is only `getSelectedTrackId`'s no-pick sentinel
- `position` - `{x, y, z}` Minecraft world coordinates in blocks
  (Vec3 doubles)
- `velocity` - `{x, y, z}` Minecraft entity delta movement, blocks
  per tick
- `category` - `TrackCategory` name (`PLAYER`, `HOSTILE`, `SABLE`, ...)
- `scannedTime` - game time
- `entityType` - registry string
- Vector maps come from `RadarBearingPeripheral.getMapFromVector`

Track `position` is world, in blocks. Monitor, rotating dish, and plane
radar all copy `track.position()` through `getMapFromVector`. Entity
tracks store `entity.position()`. Sable ships store
`RadarTrackUtil.getPosition` (bounding-box center as a world Vec3).
Lua does not convert into radar-local or plotyard space. The plotyard
branch on dish `getPosition` is the dish pose only.

The radar-bearing peripheral has the same `getTracks` map shape, plus
`getPosition`, `getRange`, `getRotation`, `getRotationSpeed`,
`getDishCount`.

All of those Lua methods are `@LuaFunction(mainThread = true)`. They
yield. A caller must not assume they are free of a tick wait.

`getTracks` on a monitor walks `controller.getTracks()`. If the monitor
has no controller, it returns an empty list. That is a missing-link
failure, not "no targets". The dish peripheral does not have that
controller short-circuit.

Open issue
[Create-Radar#128](https://github.com/Arsenalists-of-Create/Create-Radar/issues/128)
states `getTracks` velocity includes gravity and differs by entity
type. A standing player reports `y = -0.08` blocks per tick. The
same player in creative flight reports `y = 0` while still
stationary. Those numbers are Minecraft entity delta movement: the
peripheral's vector, in blocks per tick, with gravity left in.
This function still returns that vector unaltered. Subtracting
gravity belongs to Compute Ballistic Aim (#7), with a spec. Silent
filtering of tracks or of velocity axes is out of bounds here.
Issue 128 is about a present Y component that includes gravity.
Missing velocity is a malformed row, not a default of standing
still.

The Amazeballs jar `create_radar-0.4.9.4-1.21.1.jar` decompiles to the
same method names and map keys as the
`Neoforge-1.21.1-DEV` sources cited below.

### Scan Entities Some Other Way

CC:Sable ships `sublevel` / `aero` Lua APIs. Those describe the local
physics body, not a battlefield track list. Optical sensors in Simulated
report a single laser hit out to a short range. Neither replaces Create
Radar for the client's existing radar setup.

## Recommendation

Read tracks from a Create Radar **dish** (rotating or plane) that is
**not** assembled onto the gun's Simulated swivel bearings. Use the
monitor only for operator selection.

### Placement

- Radar dish and monitor stay in the world, or on a structure that is
  not the gun bearing.
- ComputerCraft reaches them with a wired modem. Right-click the modem
  on the dish (and monitor, if used) so the peripheral attaches.
- The gun computer may sit on the gun. The radar hardware must not.

### Call

The workspace read returns one table. Keys are `tracks`,
`selectedTrack`, and `selectedTrackId`. Track maps inside that
table stay raw. Do not drop categories. Do not rewrite velocity.
Velocity stays in blocks per tick. Do not convert to per-second.
Do not strip gravity. Do not return those three pieces as multiple
Lua values. Do not hang selected fields on the list table.

Find by the locked type strings `create_radar:radar`,
`create_radar:plane_radar`, and `create_radar:monitor`. Do not
treat a different `getType` as an alternate contract.

Optional radar name and optional monitor name are Lua strings when
present, on one optional `opts` table. Arity is 0 or 1. Omit the
key, or pass nil / `""` on that key, to discover. Empty string is
already omitted. A name whose Lua type is not string (number,
boolean, table, function, userdata, thread) is a caller error:
fail loud. Do not coerce with `tostring`. Do not treat it as
omitted and discover instead. A wrapped peripheral table fails
this check. Callers with a wrap pass `peripheral.getName`.

Legal calls:

```lua
bearing_turret.read_radar_tracks()
bearing_turret.read_radar_tracks(nil)
bearing_turret.read_radar_tracks({})
bearing_turret.read_radar_tracks({ radar_name = "radar_2" })
bearing_turret.read_radar_tracks({
  monitor_name = "left_monitor",
})
bearing_turret.read_radar_tracks({
  radar_name = "radar_2",
  monitor_name = "left_monitor",
})
bearing_turret.read_radar_tracks({
  radar_name = "",
  monitor_name = "left_monitor",
})
```

These calls fail loud:

```lua
bearing_turret.read_radar_tracks("radar_2")
bearing_turret.read_radar_tracks(nil, "left_monitor")
bearing_turret.read_radar_tracks(peripheral.wrap("radar_2"))
```

Tracks are read from the dish peripheral. Operator selection is
read from the monitor peripheral. The two names are independent.
The monitor Lua API does not expose which dish it is linked to.
This function cannot test that they share a Create Radar network.
A monitor linked to a different dish than the `getTracks` source
is not a distinct failure. Do not invent a pairing check. Do not
use selected-id membership as a stand-in for pairing.

Call `getTracks()`. It must be a list of maps. An empty list is a
live empty result. A non-list value is a broken peripheral
contract: fail loud. That includes nil, a scalar, and a single
track map (named fields, not a sequence of rows). Do not wrap a
map as a one-element list. Do not treat a named-key table as
empty. If any list entry is not a table, fail loud. Do not skip
that row. Do not coerce it into a map.

A track row that lacks `position`, or whose `position` is not a
table, or whose `position` table lacks numeric `x` / `y` / `z`,
is a broken row. Fail loud, the same as a missing `id`. Do not
skip the row. Do not invent `{x,y,z}`. Do not pass nil in place
of the vector.

A track row that lacks `velocity`, or lacks numeric `velocity.x` /
`velocity.y` / `velocity.z`, is a broken row. Fail loud, the same
as a missing `id` or position. Do not substitute `{x=0,y=0,z=0}`.
Do not pass nil in place of the vector.

Read Radar Tracks returns `nil` for absent selected track and
`nil` for absent selected id. It translates peripheral `""` and
empty map to `nil`. It does not return `""` or `{}` for those
fields. Omitted result-table key equals `nil`.

`getSelectedTrackId` must be a Lua string. Empty string is
no-pick: both selected fields nil. Any other Lua type (nil,
number, boolean, table, function, userdata, thread) fails the
whole read loud. Do not coerce with `tostring`. Do not treat that
return as absent. Do not keep the dish track list. Do not take an
id from `getSelectedTrack` instead. The Java method returns
`String` and maps a null selected entity to `""`. CC converts that
to a Lua string. A number, boolean, or table is not that contract
and is not the no-pick sentinel.

Monitor presence is optional only when the monitor name is
omitted. Omit the key, or pass nil / `""` on that key: discover
attached peripherals of type `create_radar:monitor`. Count
decides the outcome:

- Zero: selected is absent. Do not call `getSelectedTrack` or
  `getSelectedTrackId`. That is a tracks-only read.
- One: that peripheral is the selection source.
- Two or more: fail loud. Do not pick the first attached. Do not
  treat the ambiguity as selected absent.

Zero unnamed monitors is absence. Two unnamed monitors is an
unresolved selection source. A caller with two monitors passes a
name.

A non-empty monitor name is a contract. Wrap that name.
`peripheral.wrap` returns nil when nothing is attached at that
name. Fail loud. Do not treat wrap-nil as selected absent. Do
not discover another monitor. Do not encode a missing named
peripheral as no operator pick.

Diagnostic:

- `Read Radar Tracks: named monitor '<name>' is not attached`

`<name>` is the caller-supplied monitor name. Fire wrap-nil only
when `peripheral.wrap` of that name returns nil.

Fire a second string when wrap is non-nil and
`peripheral.getType` of that name is not exactly
`create_radar:monitor`:

- `Read Radar Tracks: named monitor '<name>' is type '<type>', expected create_radar:monitor`

`<type>` is the getType string; write `nil` if getType is nil. CC
screen type `monitor` is this class. Dish types on the monitor
name are this class. Do not call `getSelectedTrackId` or
`getSelectedTrack`. Do not discover another monitor. Do not
encode selected absent.

An attached Create Radar monitor with no controller or no pick is
still resolved; empty-pick returns stay selected absent.

The Java methods do not throw for no controller or no pick.
`getSelectedTrackId` returns `""`. `getSelectedTrack` returns an
empty map. If either Lua call throws after a monitor was resolved,
fail the whole read loud with:

- `Read Radar Tracks: getSelectedTrackId threw on monitor '<name>': <original>`
- `Read Radar Tracks: getSelectedTrack threw on monitor '<name>': <original>`
- `Read Radar Tracks: getSelectedTrackId on monitor '<name>'
  returned <type>, expected string`
- `Read Radar Tracks: getSelectedTrack on monitor '<name>'
  returned <type>, expected table`

`<name>` is the wrapped peripheral name. `<original>` is the CC /
`pcall` throw text. Do not keep the dish track list. Do not encode
the throw as selected absent.

`pcall` wraps only the peripheral invocation. Type-check
`getSelectedTrack` as a table before any field access. Non-table
(nil, number, string, boolean, function, userdata, thread) fails
the whole read. Do not omit selected. Do not rewrite a Lua index
error as `getSelectedTrack threw`. Call `getSelectedTrack` even
when the id is `""`. Nil is not the empty-map sentinel. Only an
empty table is miss.

If the operator has clicked a target on the monitor, prefer
`getSelectedTrack` only when that map itself has a non-empty `id`
and passes the same row-shape checks as a list row, and when that
selected id is in this tick's returned dish `getTracks` list
(exact string `id`), and when map `id` equals `selectedTrackId`.
Membership is against the list this function returns. Empty list
is a miss for any non-empty id. Map `id` a non-empty string that
differs from `selectedTrackId`: omit selected track, keep the id,
return the list. Not a failure.

Non-empty `getSelectedTrackId` with empty `getSelectedTrack` means
selected track is absent. The function still returns. Do not fail
the read. Do not invent position or velocity from the id.

When the selected id is non-empty and no dish row matches: return
the list, return the id, treat selected track as absent. The read
succeeds. Do not drop the id. Do not fail. Do not splice a
selected map into the list. A click can outlive the entity on this
dish. The monitor peripheral already returns an empty selected map
while keeping the id string. This function does the same for the
dish list it actually returns.

After `getSelectedTrack` / `getSelectedTrackId`, run the same id,
position, and velocity checks used for a track row. If the
selected map fails those checks, treat selected track as absent.
Keep the selected id when it is a non-empty string. Keep the
track list. Do not fail the read. Do not return the failed map.

Treat an empty list from a linked dish as "no tracks this tick".
Missing dish is a failure.

### Fail Loud

Fail loud means `error(message)`. The message is a required
non-empty string that names the failure class. `return nil,
message` is the rejected alternative: a caller that takes only the
first return gets `nil` and continues. An empty track list is a
live success; a soft-fail `nil` lets a caller treat a missing dish
as no tracks. CC: Tweaked uses `error("...")` as the usual loud
path. Coentrify fail loud surfaces the failure. `error()` with no
argument, an empty string, `assert` with no message, or one
generic `"failed"` is not fail loud.

### Track Id And Position Types

Create Radar's `getTracks` puts `id` from `track.id()` (a Java
String, the entity UUID) and `position` from `getMapFromVector`
(always a `HashMap<String, Double>` with `x`, `y`, `z`). CC
converts those to a Lua string and a Lua table.

A row whose `id` is present and not a string (number, boolean,
table, or other Lua type) is not that map. Fail loud. Do not
coerce with `tostring`.

A row that lacks `position` is not that map. Fail loud. Do not
skip the row. Do not rewrite a missing `position` into a table.

A row whose `position` is present and not a table is not that
map. Fail loud. Do not index it for `x` / `y` / `z`. Do not skip
the row. Do not rewrite `position` into a table.

`getSelectedTrackId` uses the same non-string fail as a track-row
`id`, with one exception: that method's `""` is no-pick (both
selected fields nil). A track-row `id` of `""` still fails loud.
Do not collapse a wrong `getSelectedTrackId` type into no-pick.

"Return the raw maps" means do not alter a valid track map. It
does not mean accept a wrong Lua type as a track. A present
non-number `scannedTime` on a dish `getTracks` row is that same
class. The same optional-field pass runs on a returned selected
map.

`category` and `entityType` missing or nil become `""`. Present
and not a string fails the whole read, next to the track-id type
rule. Present strings pass through, including `HOSTILE`,
`PLAYER`, `SABLE`, and `""`.

### What This Function Is Not

- It does not rotate bearings.
- It does not compute lead.
- It does not fire.
- It does not call `yaw_controller.setAngle`.

Those are the sibling tickets under Engage Simulated Bearing Turret
(#8).

## What Would Falsify This

- In-game `peripheral.getMethods` on the Amazeballs dish lacks
  `getTracks`, or the track map lacks `position` / `id`.
- If in-game `peripheral.getType` is not `create_radar:radar`,
  `create_radar:plane_radar`, or `create_radar:monitor`, the paper
  is wrong and the wrap path changes. The map shape can still
  stand. Do not patch the function with runtime discovery.
- Tracks from a world-fixed radar never include the entities the
  client wants to shoot (range, filters, or dimension). Then the
  placement rule is wrong, not the Lua shape.
- A later Create Radar Lua method that names the linked dish.
  Then pairing could become an explicit check. Until that exists,
  do not invent one.
- If in-game a non-empty selected id with no matching dish row
  this tick is treated by Create Radar as a hard peripheral error,
  then success-plus-absent-map is wrong and the rule becomes fail
  loud. Until that shows up, live miss stands.
- Amazeballs `getSelectedTrack` throws, or returns nil rather than
  an empty table, when the stored id is missing from controller
  tracks. Then the Lua encoding of this miss changes. Until that
  shows up, only an empty table is miss; nil fails the whole read
  as non-table. The read still must not fail unless the method
  throws, if in-game miss is Lua nil.
- In-game `getTracks` is not a list of maps (nil, a scalar, or a
  single track map). Then the CC conversion or the mod version
  broke; this function fails rather than adapting.
- In-game `getTracks` rows use a non-string `id` or a non-table
  `position` as the normal Create Radar shape. Then fail-loud on
  those types is wrong.
- If a caller-supplied monitor name with wrap-nil is meant as
  "no monitor this tick", fail-loud on wrap-nil is wrong. Omit
  the argument to mean no monitor. A name means that peripheral
  must be attached.
- In-game `getSelectedTrackId` returns nil or another non-string
  as the normal no-pick or pick encoding. Then fail-loud on those
  types is wrong. Until that shows up, only `""` is no-pick.

## Sources

- [MonitorPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/MonitorPeripheral.java)
- [RadarBearingPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/RadarBearingPeripheral.java)
- [PlaneRadarPeripheral.java (Neoforge-1.21.1-DEV)](https://github.com/Arsenalists-of-Create/Create-Radar/blob/Neoforge-1.21.1-DEV/src/main/java/com/happysg/radar/compat/computercraft/PlaneRadarPeripheral.java)
- [Create-Radar issue 128, gravity in track velocity](https://github.com/Arsenalists-of-Create/Create-Radar/issues/128)
- [CC: Tweaked peripheral API (1.21)](https://tweaked.cc/mc-1.21.y/module/peripheral.html)
- Amazeballs instance mods: `create_radar-0.4.9.4-1.21.1.jar`,
  `cc-tweaked-1.21.1-forge-1.120.0.jar`,
  `create-aeronautics-bundled-1.21.1-1.3.0.jar` (Simulated 1.3.0 nested)
