local read_radar_tracks = dofile("read_radar_tracks.lua")

local failures = 0
local passes = 0

local bus = {
  names = {},
  types = {},
  wraps = {},
}

_G.peripheral = {
  getNames = function()
    local names = {}
    local index = 1
    while index <= #bus.names do
      names[index] = bus.names[index]
      index = index + 1
    end
    return names
  end,
  getType = function(name)
    return bus.types[name]
  end,
  wrap = function(name)
    return bus.wraps[name]
  end,
}

local function reset_bus()
  bus.names = {}
  bus.types = {}
  bus.wraps = {}
end

local function attach(name, peripheral_type, wrapped)
  bus.names[#bus.names + 1] = name
  bus.types[name] = peripheral_type
  bus.wraps[name] = wrapped
end

local function valid_row(track_id)
  return {
    id = track_id,
    position = { x = 1.5, y = 64, z = -8 },
    velocity = { x = 0, y = -0.08, z = 0 },
    category = "PLAYER",
    entityType = "minecraft:player",
    scannedTime = 1200,
  }
end

local function dish_wrap(tracks_or_fn)
  if type(tracks_or_fn) == "function" then
    return { getTracks = tracks_or_fn }
  end
  return {
    getTracks = function()
      return tracks_or_fn
    end,
  }
end

local function monitor_wrap(selected_id, selected_map)
  return {
    getSelectedTrackId = function()
      return selected_id
    end,
    getSelectedTrack = function()
      return selected_map
    end,
  }
end

local function copy_row(row)
  local copy = {}
  for key, value in pairs(row) do
    copy[key] = value
  end
  return copy
end

local function fail(message)
  failures = failures + 1
  io.stderr:write("FAIL " .. message .. "\n")
end

local function pass(name)
  passes = passes + 1
end

local function expect_error(name, fn, needle)
  reset_bus()
  local ok, err = pcall(fn)
  if ok then
    fail(name .. ": expected error containing " .. needle)
    return
  end
  if type(err) ~= "string" or string.find(err, needle, 1, true) == nil then
    fail(name .. ": expected " .. needle .. ", got " .. tostring(err))
    return
  end
  pass(name)
end

local function expect_equal(name, actual, expected)
  if actual ~= expected then
    fail(name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    return
  end
  pass(name)
end

local function run(name, fn)
  reset_bus()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

-- Happy path

run("empty tracks no monitor", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  local result = read_radar_tracks()
  expect_equal("empty tracks list length", #result.tracks, 0)
  expect_equal("empty tracks selectedTrack", result.selectedTrack, nil)
  expect_equal("empty tracks selectedTrackId", result.selectedTrackId, nil)
end)

run("one player track keeps gravity and category", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  local result = read_radar_tracks(nil)
  expect_equal("one track length", #result.tracks, 1)
  expect_equal("one track id", result.tracks[1].id, "uuid-1")
  expect_equal("one track vy", result.tracks[1].velocity.y, -0.08)
  expect_equal("one track category", result.tracks[1].category, "PLAYER")
  expect_equal("one track scannedTime", result.tracks[1].scannedTime, 1200)
end)

run("plane radar is a valid dish", function()
  attach("plane_1", "create_radar:plane_radar", dish_wrap({}))
  local result = read_radar_tracks({})
  expect_equal("plane tracks length", #result.tracks, 0)
end)

run("named radar", function()
  attach("radar_2", "create_radar:radar", dish_wrap({}))
  attach("radar_extra", "create_radar:radar", dish_wrap({ valid_row("other") }))
  local result = read_radar_tracks({ radar_name = "radar_2" })
  expect_equal("named radar empty list", #result.tracks, 0)
end)

run("selected hit uses monitor map not dish row", function()
  local dish_row = valid_row("uuid-1")
  dish_row.position = { x = 1, y = 64, z = 1 }
  local monitor_row = valid_row("uuid-1")
  monitor_row.position = { x = 99, y = 70, z = 99 }
  attach("radar_1", "create_radar:radar", dish_wrap({ dish_row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", monitor_row))
  local first, second = read_radar_tracks()
  expect_equal("hit monitor x", first.selectedTrack.position.x, 99)
  expect_equal("hit dish x unchanged", first.tracks[1].position.x, 1)
  expect_equal("no second return", second, nil)
end)

run("multi-row list keeps every row and hits non-first id", function()
  local first = valid_row("uuid-1")
  local second = valid_row("uuid-2")
  second.category = "HOSTILE"
  attach("radar_1", "create_radar:radar", dish_wrap({ first, second }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-2", copy_row(second)))
  local result = read_radar_tracks()
  expect_equal("multi length", #result.tracks, 2)
  expect_equal("multi first kept", result.tracks[1].id, "uuid-1")
  expect_equal("multi second kept", result.tracks[2].id, "uuid-2")
  expect_equal("multi hit id", result.selectedTrackId, "uuid-2")
  expect_equal("multi hit map id", result.selectedTrack.id, "uuid-2")
end)

run("unnamed discover ignores motors and CC screens", function()
  attach("motor_1", "electric_motor", {})
  attach("screen", "monitor", {})
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  local result = read_radar_tracks()
  expect_equal("discover ignores extras", #result.tracks, 0)
  expect_equal("screen is not radar monitor", result.selectedTrackId, nil)
end)

run("empty selected id with populated map is no pick", function()
  local row = valid_row("uuid-1")
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("mon", "create_radar:monitor", monitor_wrap("", copy_row(row)))
  local result = read_radar_tracks()
  expect_equal("populated no-pick selectedTrack", result.selectedTrack, nil)
  expect_equal("populated no-pick selectedTrackId", result.selectedTrackId, nil)
  expect_equal("populated no-pick list kept", result.tracks[1].id, "uuid-1")
end)

run("monitor only opts selected hit", function()
  local row = valid_row("uuid-1")
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("left_monitor", "create_radar:monitor", monitor_wrap("uuid-1", copy_row(row)))
  local result = read_radar_tracks({ monitor_name = "left_monitor" })
  expect_equal("monitor-only selected id", result.selectedTrackId, "uuid-1")
  expect_equal("monitor-only selected map id", result.selectedTrack.id, "uuid-1")
end)

run("both names", function()
  local row = valid_row("uuid-1")
  attach("radar_2", "create_radar:radar", dish_wrap({ row }))
  attach("left_monitor", "create_radar:monitor", monitor_wrap("uuid-1", copy_row(row)))
  local result = read_radar_tracks({
    radar_name = "radar_2",
    monitor_name = "left_monitor",
  })
  expect_equal("both names selected", result.selectedTrackId, "uuid-1")
end)

run("radar_name empty string discovers", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  local result = read_radar_tracks({ radar_name = "", monitor_name = "" })
  expect_equal("empty string discover length", #result.tracks, 0)
end)

-- Envelope failures

expect_error("too many args", function()
  read_radar_tracks(nil, "left_monitor")
end, "expected at most one argument, got 2")

expect_error("string opts", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks("radar_1")
end, "inputs must be a table or nil, got string")

expect_error("unknown key", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks({ "radar_1" })
end, "unknown input '1'")

expect_error("non-string radar_name", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks({ radar_name = 2 })
end, "radar_name is number, expected string")

expect_error("non-string monitor_name", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks({ monitor_name = true })
end, "monitor_name is boolean, expected string")

-- Dish failures

expect_error("no radar", function()
  read_radar_tracks()
end, "no radar peripheral attached")

expect_error("two radars unnamed", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("plane_1", "create_radar:plane_radar", dish_wrap({}))
  read_radar_tracks()
end, "expected exactly one radar, found 2")

expect_error("named radar missing", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks({ radar_name = "missing" })
end, "named radar 'missing' is not attached")

expect_error("named radar wrong type", function()
  attach("motor_1", "electric_motor", {})
  read_radar_tracks({ radar_name = "motor_1" })
end, "named radar 'motor_1' is type 'electric_motor'")

-- Monitor failures

expect_error("two unnamed monitors", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("mon_a", "create_radar:monitor", monitor_wrap("", {}))
  attach("mon_b", "create_radar:monitor", monitor_wrap("", {}))
  read_radar_tracks()
end, "expected exactly one Create Radar monitor, found 2")

expect_error("named monitor missing", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks({ monitor_name = "ghost" })
end, "named monitor 'ghost' is not attached")

expect_error("named monitor is CC screen", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("screen", "monitor", {})
  read_radar_tracks({ monitor_name = "screen" })
end, "named monitor 'screen' is type 'monitor', expected create_radar:monitor")

-- getTracks shape

expect_error("getTracks throws", function()
  attach("radar_1", "create_radar:radar", dish_wrap(function()
    error("boom", 0)
  end))
  read_radar_tracks()
end, "getTracks threw: boom")

expect_error("getTracks nil", function()
  attach("radar_1", "create_radar:radar", dish_wrap(function()
    return nil
  end))
  read_radar_tracks()
end, "getTracks returned nil, expected list")

expect_error("getTracks named table", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ id = "x" }))
  read_radar_tracks()
end, "not a list of maps")

expect_error("getTracks hole", function()
  attach("radar_1", "create_radar:radar", dish_wrap({
    [1] = valid_row("a"),
    [3] = valid_row("c"),
  }))
  read_radar_tracks()
end, "not a list of maps")

expect_error("row not table", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ "nope" }))
  read_radar_tracks()
end, "track row is not a table")

expect_error("missing id", function()
  local row = valid_row("x")
  row.id = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "track id is missing")

expect_error("empty id", function()
  local row = valid_row("x")
  row.id = ""
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "track id is empty")

expect_error("non-string id", function()
  local row = valid_row("x")
  row.id = 12
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "track id is number, expected string")

expect_error("missing position", function()
  local row = valid_row("x")
  row.position = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "position is missing")

expect_error("non-table position", function()
  local row = valid_row("x")
  row.position = "nope"
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "position is string, expected table")

expect_error("missing velocity", function()
  local row = valid_row("x")
  row.velocity = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "velocity is missing")

expect_error("missing position xyz", function()
  local row = valid_row("x")
  row.position = { x = 1, y = 2 }
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "position lacks numeric x/y/z")

expect_error("velocity not table", function()
  local row = valid_row("x")
  row.velocity = 0
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "velocity is number, expected table")

expect_error("missing velocity xyz", function()
  local row = valid_row("x")
  row.velocity = { x = 0, y = -0.08 }
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "velocity lacks numeric x/y/z")

expect_error("scannedTime string", function()
  local row = valid_row("x")
  row.scannedTime = "100"
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "scannedTime is string, expected number")

expect_error("category number", function()
  local row = valid_row("x")
  row.category = 1
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "category returned number, expected string")

expect_error("entityType table", function()
  local row = valid_row("x")
  row.entityType = {}
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  read_radar_tracks()
end, "entityType returned table, expected string")

-- Optional sanitization

run("nil category and entityType become empty string", function()
  local row = valid_row("uuid-1")
  row.category = nil
  row.entityType = nil
  row.scannedTime = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  local result = read_radar_tracks()
  expect_equal("nil category", result.tracks[1].category, "")
  expect_equal("nil entityType", result.tracks[1].entityType, "")
  expect_equal("nil scannedTime omitted", result.tracks[1].scannedTime, nil)
end)

run("HOSTILE is kept", function()
  local row = valid_row("uuid-1")
  row.category = "HOSTILE"
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  local result = read_radar_tracks()
  expect_equal("HOSTILE kept", result.tracks[1].category, "HOSTILE")
end)

-- Selection edges

run("zero unnamed monitors omits selected", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  local result = read_radar_tracks()
  expect_equal("zero monitors selectedTrack", result.selectedTrack, nil)
  expect_equal("zero monitors selectedTrackId", result.selectedTrackId, nil)
end)

run("empty selected id is no pick", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("mon", "create_radar:monitor", monitor_wrap("", {}))
  local result = read_radar_tracks()
  expect_equal("empty id selectedTrack", result.selectedTrack, nil)
  expect_equal("empty id selectedTrackId", result.selectedTrackId, nil)
end)

run("empty selected map keeps id and list", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", {}))
  local result = read_radar_tracks()
  expect_equal("empty map selectedTrack", result.selectedTrack, nil)
  expect_equal("empty map selectedTrackId", result.selectedTrackId, "uuid-1")
  expect_equal("empty map list kept", result.tracks[1].id, "uuid-1")
end)

run("selected id missing from list keeps id and list", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("mon", "create_radar:monitor", monitor_wrap("stale", valid_row("stale")))
  local result = read_radar_tracks()
  expect_equal("stale selectedTrack", result.selectedTrack, nil)
  expect_equal("stale selectedTrackId", result.selectedTrackId, "stale")
  expect_equal("stale list kept", result.tracks[1].id, "uuid-1")
end)

run("selected map id mismatch omits track keeps list", function()
  local list_row = valid_row("uuid-1")
  local monitor_row = valid_row("uuid-2")
  attach("radar_1", "create_radar:radar", dish_wrap({ list_row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", monitor_row))
  local result = read_radar_tracks()
  expect_equal("mismatch selectedTrack", result.selectedTrack, nil)
  expect_equal("mismatch selectedTrackId", result.selectedTrackId, "uuid-1")
  expect_equal("mismatch list kept", result.tracks[1].id, "uuid-1")
end)

run("selected map bad shape omits track keeps list", function()
  local bad = valid_row("uuid-1")
  bad.velocity = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", bad))
  local result = read_radar_tracks()
  expect_equal("bad shape selectedTrack", result.selectedTrack, nil)
  expect_equal("bad shape selectedTrackId", result.selectedTrackId, "uuid-1")
  expect_equal("bad shape list kept", result.tracks[1].id, "uuid-1")
end)

run("selected map gets optional sanitization", function()
  local row = valid_row("uuid-1")
  local selected = copy_row(row)
  selected.category = nil
  selected.entityType = nil
  selected.scannedTime = nil
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", selected))
  local result = read_radar_tracks()
  expect_equal("selected category empty", result.selectedTrack.category, "")
  expect_equal("selected entityType empty", result.selectedTrack.entityType, "")
  expect_equal("selected scannedTime omitted", result.selectedTrack.scannedTime, nil)
end)

expect_error("selected scannedTime not number", function()
  local row = valid_row("uuid-1")
  local selected = copy_row(row)
  selected.scannedTime = "100"
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", selected))
  read_radar_tracks()
end, "scannedTime is string, expected number")

expect_error("selected category not string", function()
  local row = valid_row("uuid-1")
  local selected = copy_row(row)
  selected.category = 1
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", selected))
  read_radar_tracks()
end, "category returned number, expected string")

expect_error("selected entityType not string", function()
  local row = valid_row("uuid-1")
  local selected = copy_row(row)
  selected.entityType = {}
  attach("radar_1", "create_radar:radar", dish_wrap({ row }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", selected))
  read_radar_tracks()
end, "entityType returned table, expected string")

expect_error("getSelectedTrackId throws", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("mon", "create_radar:monitor", {
    getSelectedTrackId = function()
      error("id-boom", 0)
    end,
    getSelectedTrack = function()
      return {}
    end,
  })
  read_radar_tracks()
end, "getSelectedTrackId threw on monitor 'mon': id-boom")

expect_error("getSelectedTrack throws", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("mon", "create_radar:monitor", {
    getSelectedTrackId = function()
      return ""
    end,
    getSelectedTrack = function()
      error("map-boom", 0)
    end,
  })
  read_radar_tracks()
end, "getSelectedTrack threw on monitor 'mon': map-boom")

expect_error("getSelectedTrackId not string", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("mon", "create_radar:monitor", monitor_wrap(3, {}))
  read_radar_tracks()
end, "getSelectedTrackId on monitor 'mon' returned number, expected string")

expect_error("getSelectedTrack not table", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  attach("mon", "create_radar:monitor", monitor_wrap("", nil))
  read_radar_tracks()
end, "getSelectedTrack on monitor 'mon' returned nil, expected table")

run("does not call peripheral.find", function()
  local find_called = false
  peripheral.find = function()
    find_called = true
  end
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  read_radar_tracks()
  expect_equal("find not called", find_called, false)
end)

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
