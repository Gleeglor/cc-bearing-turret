package.loaded["rotate_bearing_toward_angle.lua"] = nil

local rotate_log = {
  calls = {},
  errors = {},
  results = {},
}

local function reset_rotate()
  rotate_log.calls = {}
  rotate_log.errors = {}
  rotate_log.results = {}
end

package.loaded["rotate_bearing_toward_angle.lua"] = {
  rotate_bearing_toward_angle = function(opts)
    rotate_log.calls[#rotate_log.calls + 1] = opts
    local n = #rotate_log.calls
    if rotate_log.errors[n] then
      error(rotate_log.errors[n], 0)
    end
    local result = rotate_log.results[n]
    if result == nil then
      result = 0
    end
    return result
  end,
}

local bearing_turret = dofile("aim_turret_at_target.lua")

local function aim_turret_at_target(...)
  return bearing_turret.aim_turret_at_target(...)
end

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

local function dish_wrap(tracks)
  return {
    getTracks = function()
      return tracks
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

local function fail(message)
  failures = failures + 1
  io.stderr:write("FAIL " .. message .. "\n")
end

local function pass(name)
  passes = passes + 1
end

local function expect_error(name, fn, needle)
  reset_bus()
  reset_rotate()
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
    fail(
      name .. ": expected " .. tostring(expected) ..
        ", got " .. tostring(actual)
    )
    return
  end
  pass(name)
end

local function run(name, fn)
  reset_bus()
  reset_rotate()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

local function live_dish(track_id)
  attach(
    "radar_1",
    "create_radar:radar",
    dish_wrap({ valid_row(track_id) })
  )
end

local function base_opts()
  return {
    yaw_degrees = 10,
    pitch_degrees = 5,
    yaw_rpm = 32,
    pitch_rpm = -16,
    track_id = "uuid-1",
    yaw_bearing_name = "yaw_swivel",
    pitch_bearing_name = "pitch_swivel",
    yaw_motor_name = "yaw_motor",
    pitch_motor_name = "pitch_motor",
  }
end

run("happy path on_target true default tolerance", function()
  live_dish("uuid-1")
  rotate_log.results[1] = 0.25
  rotate_log.results[2] = -1
  local result = aim_turret_at_target(base_opts())
  expect_equal("happy on_target", result.on_target, true)
  expect_equal("happy extra key", result.error_degrees, nil)
  expect_equal("happy rotate count", #rotate_log.calls, 2)
  expect_equal("yaw target", rotate_log.calls[1].target_degrees, 10)
  expect_equal("yaw rpm", rotate_log.calls[1].rpm, 32)
  expect_equal("yaw bearing", rotate_log.calls[1].bearing_name, "yaw_swivel")
  expect_equal("yaw motor", rotate_log.calls[1].motor_name, "yaw_motor")
  expect_equal("yaw no parent key", rotate_log.calls[1].yaw_degrees, nil)
  expect_equal("yaw omit tolerance", rotate_log.calls[1].tolerance_degrees, nil)
  expect_equal("pitch omit tolerance", rotate_log.calls[2].tolerance_degrees, nil)
  expect_equal("pitch target", rotate_log.calls[2].target_degrees, 5)
  expect_equal("pitch rpm", rotate_log.calls[2].rpm, -16)
  expect_equal("pitch bearing", rotate_log.calls[2].bearing_name, "pitch_swivel")
  expect_equal("pitch motor", rotate_log.calls[2].motor_name, "pitch_motor")
end)

run("on_target false when one axis leftover exceeds default 1", function()
  live_dish("uuid-1")
  rotate_log.results[1] = 0
  rotate_log.results[2] = 1.25
  local result = aim_turret_at_target(base_opts())
  expect_equal("one axis off", result.on_target, false)
end)

run("custom tolerances forwarded and used", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_tolerance_degrees = 2
  opts.pitch_tolerance_degrees = 0.5
  rotate_log.results[1] = 1.5
  rotate_log.results[2] = 0.5
  local result = aim_turret_at_target(opts)
  expect_equal("custom yaw tolerance child", rotate_log.calls[1].tolerance_degrees, 2)
  expect_equal("custom pitch tolerance child", rotate_log.calls[2].tolerance_degrees, 0.5)
  expect_equal("custom on_target", result.on_target, true)
end)

run("selectedTrackId when track_id omitted", function()
  attach(
    "radar_1",
    "create_radar:radar",
    dish_wrap({ valid_row("uuid-sel") })
  )
  attach(
    "mon_1",
    "create_radar:monitor",
    monitor_wrap("uuid-sel", valid_row("uuid-sel"))
  )
  local opts = base_opts()
  opts.track_id = nil
  local result = aim_turret_at_target(opts)
  expect_equal("selected id on_target", result.on_target, true)
end)

run("empty track_id uses selectedTrackId", function()
  attach(
    "radar_1",
    "create_radar:radar",
    dish_wrap({ valid_row("uuid-sel") })
  )
  attach(
    "mon_1",
    "create_radar:monitor",
    monitor_wrap("uuid-sel", valid_row("uuid-sel"))
  )
  local opts = base_opts()
  opts.track_id = ""
  local result = aim_turret_at_target(opts)
  expect_equal("empty track_id on_target", result.on_target, true)
end)

run("selected map nil still live when id is in list", function()
  attach(
    "radar_1",
    "create_radar:radar",
    dish_wrap({ valid_row("uuid-1") })
  )
  attach(
    "mon_1",
    "create_radar:monitor",
    monitor_wrap("uuid-1", {})
  )
  local opts = base_opts()
  opts.track_id = nil
  local result = aim_turret_at_target(opts)
  expect_equal("nil selected map still aims", result.on_target, true)
end)

run("zero degrees and zero rpm are legal", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_degrees = 0
  opts.pitch_degrees = 0
  opts.yaw_rpm = 0
  opts.pitch_rpm = 0
  local result = aim_turret_at_target(opts)
  expect_equal("zero rpm child yaw", rotate_log.calls[1].rpm, 0)
  expect_equal("zero on_target", result.on_target, true)
end)

run("named radar and monitor forwarded", function()
  attach("radar_a", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("radar_b", "create_radar:radar", dish_wrap({}))
  attach(
    "mon_a",
    "create_radar:monitor",
    monitor_wrap("", {})
  )
  attach(
    "mon_b",
    "create_radar:monitor",
    monitor_wrap("uuid-1", valid_row("uuid-1"))
  )
  local opts = base_opts()
  opts.radar_name = "radar_a"
  opts.monitor_name = "mon_b"
  local result = aim_turret_at_target(opts)
  expect_equal("named peripherals on_target", result.on_target, true)
end)

expect_error("arity 0", function()
  aim_turret_at_target()
end, "expected exactly one argument, got 0")

expect_error("arity 2", function()
  aim_turret_at_target(base_opts(), 1)
end, "expected exactly one argument, got 2")

expect_error("non table opts", function()
  aim_turret_at_target(10)
end, "inputs must be a table, got number")

expect_error("unknown key", function()
  local opts = base_opts()
  opts.solution = {}
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "unknown input 'solution'")

expect_error("pitch_degrees missing", function()
  local opts = base_opts()
  opts.pitch_degrees = nil
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_degrees is required")

expect_error("pitch_rpm missing", function()
  local opts = base_opts()
  opts.pitch_rpm = nil
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_rpm is required")

expect_error("yaw_bearing_name number", function()
  local opts = base_opts()
  opts.yaw_bearing_name = 1
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_bearing_name must be a string or nil, got number")

expect_error("yaw_tolerance nan", function()
  local opts = base_opts()
  opts.yaw_tolerance_degrees = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_tolerance_degrees must be a finite number, got nan")

expect_error("unknown array index", function()
  local opts = base_opts()
  opts[1] = 10
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "unknown input '1'")

run("leftover exactly 1 is on target at default", function()
  live_dish("uuid-1")
  rotate_log.results[1] = 1
  rotate_log.results[2] = -1
  local result = aim_turret_at_target(base_opts())
  expect_equal("boundary on_target", result.on_target, true)
end)

run("empty equal names are absent not equal-present", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_bearing_name = ""
  opts.pitch_bearing_name = ""
  local result = aim_turret_at_target(opts)
  expect_equal("empty names on_target", result.on_target, true)
  expect_equal("empty names omitted on child", rotate_log.calls[1].bearing_name, nil)
end)

expect_error("missing yaw_degrees", function()
  local opts = base_opts()
  opts.yaw_degrees = nil
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_degrees is required")

expect_error("yaw_degrees string", function()
  local opts = base_opts()
  opts.yaw_degrees = "10"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_degrees must be a number, got string")

expect_error("yaw_degrees nan", function()
  local opts = base_opts()
  opts.yaw_degrees = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_degrees must be a finite number, got nan")

expect_error("pitch_rpm inf", function()
  local opts = base_opts()
  opts.pitch_rpm = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_rpm must be a finite number, got inf")

expect_error("missing yaw_rpm", function()
  local opts = base_opts()
  opts.yaw_rpm = nil
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_rpm is required")

expect_error("track_id number", function()
  local opts = base_opts()
  opts.track_id = 1
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "track_id must be a string or nil, got number")

expect_error("negative yaw tolerance", function()
  local opts = base_opts()
  opts.yaw_tolerance_degrees = -1
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_tolerance_degrees must be >= 0")

expect_error("tolerance empty string", function()
  local opts = base_opts()
  opts.pitch_tolerance_degrees = ""
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_tolerance_degrees must be a number, got string")

expect_error("equal bearing names", function()
  local opts = base_opts()
  opts.yaw_bearing_name = "same"
  opts.pitch_bearing_name = "same"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_bearing_name and pitch_bearing_name must differ, both 'same'")

expect_error("equal motor names", function()
  local opts = base_opts()
  opts.yaw_motor_name = "m"
  opts.pitch_motor_name = "m"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_motor_name and pitch_motor_name must differ, both 'm'")

expect_error("no radar target", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  local opts = base_opts()
  opts.track_id = nil
  aim_turret_at_target(opts)
end, "no radar target this tick")

expect_error("track missing from list", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.track_id = "gone"
  aim_turret_at_target(opts)
end, "track 'gone' is not in this tick's tracks")

expect_error("leftover selected id not in list", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach(
    "mon_1",
    "create_radar:monitor",
    monitor_wrap("stale", {})
  )
  local opts = base_opts()
  opts.track_id = nil
  aim_turret_at_target(opts)
end, "track 'stale' is not in this tick's tracks")

expect_error("empty tracks named id", function()
  attach("radar_1", "create_radar:radar", dish_wrap({}))
  aim_turret_at_target(base_opts())
end, "track 'uuid-1' is not in this tick's tracks")

run("yaw rotate failure skips pitch", function()
  live_dish("uuid-1")
  rotate_log.errors[1] = "no kinetic"
  local ok, err = pcall(aim_turret_at_target, base_opts())
  expect_equal("yaw fail pcall", ok, false)
  local found = type(err) == "string" and
    string.find(err, "yaw rotate failed: no kinetic", 1, true) ~= nil
  expect_equal("yaw fail message", found, true)
  expect_equal("pitch not called", #rotate_log.calls, 1)
end)

run("pitch rotate failure after yaw", function()
  live_dish("uuid-1")
  rotate_log.errors[2] = "pitch jammed"
  local ok, err = pcall(aim_turret_at_target, base_opts())
  expect_equal("pitch fail pcall", ok, false)
  local found = type(err) == "string" and
    string.find(err, "pitch rotate failed: pitch jammed", 1, true) ~= nil
  expect_equal("pitch fail message", found, true)
  expect_equal("both rotate attempts", #rotate_log.calls, 2)
end)

run("yaw rotate non-number", function()
  live_dish("uuid-1")
  rotate_log.results[1] = true
  local ok, err = pcall(aim_turret_at_target, base_opts())
  expect_equal("non-number pcall", ok, false)
  local found = type(err) == "string" and
    string.find(err, "yaw rotate returned boolean, expected number", 1, true) ~=
      nil
  expect_equal("non-number message", found, true)
  expect_equal("pitch skipped after bad yaw return", #rotate_log.calls, 1)
end)

expect_error("read_radar_tracks missing dish", function()
  aim_turret_at_target(base_opts())
end, "read_radar_tracks failed: Read Radar Tracks: no radar peripheral attached")

run("omit axis names does not send child name keys", function()
  live_dish("uuid-1")
  local opts = {
    yaw_degrees = 1,
    pitch_degrees = 2,
    yaw_rpm = 8,
    pitch_rpm = 8,
    track_id = "uuid-1",
  }
  aim_turret_at_target(opts)
  expect_equal("omit yaw bearing", rotate_log.calls[1].bearing_name, nil)
  expect_equal("omit yaw motor", rotate_log.calls[1].motor_name, nil)
  expect_equal("omit pitch bearing", rotate_log.calls[2].bearing_name, nil)
  expect_equal("omit pitch motor", rotate_log.calls[2].motor_name, nil)
end)

expect_error("nil opts", function()
  aim_turret_at_target(nil)
end, "inputs must be a table, got nil")

expect_error("opts wrap table", function()
  live_dish("uuid-1")
  local wrapped = bus.wraps.radar_1
  aim_turret_at_target(wrapped)
end, "unknown input '")

expect_error("yaw_degrees inf", function()
  local opts = base_opts()
  opts.yaw_degrees = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_degrees must be a finite number, got inf")

expect_error("yaw_degrees negative inf", function()
  local opts = base_opts()
  opts.yaw_degrees = -math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_degrees must be a finite number, got inf")

expect_error("pitch_degrees string", function()
  local opts = base_opts()
  opts.pitch_degrees = "5"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_degrees must be a number, got string")

expect_error("pitch_degrees nan", function()
  local opts = base_opts()
  opts.pitch_degrees = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_degrees must be a finite number, got nan")

expect_error("pitch_degrees inf", function()
  local opts = base_opts()
  opts.pitch_degrees = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_degrees must be a finite number, got inf")

expect_error("yaw_rpm string", function()
  local opts = base_opts()
  opts.yaw_rpm = "32"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_rpm must be a number, got string")

expect_error("yaw_rpm nan", function()
  local opts = base_opts()
  opts.yaw_rpm = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_rpm must be a finite number, got nan")

expect_error("yaw_rpm inf", function()
  local opts = base_opts()
  opts.yaw_rpm = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_rpm must be a finite number, got inf")

expect_error("pitch_rpm string", function()
  local opts = base_opts()
  opts.pitch_rpm = "16"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_rpm must be a number, got string")

expect_error("pitch_rpm nan", function()
  local opts = base_opts()
  opts.pitch_rpm = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_rpm must be a finite number, got nan")

run("negative degrees forwarded unchanged", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_degrees = -90
  opts.pitch_degrees = 370
  local result = aim_turret_at_target(opts)
  expect_equal("negative yaw target", rotate_log.calls[1].target_degrees, -90)
  expect_equal("unwrapped pitch target", rotate_log.calls[2].target_degrees, 370)
  expect_equal("unwrapped on_target", result.on_target, true)
end)

run("equal yaw and pitch numbers are legal", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_degrees = 45
  opts.pitch_degrees = 45
  local result = aim_turret_at_target(opts)
  expect_equal("equal yaw", rotate_log.calls[1].target_degrees, 45)
  expect_equal("equal pitch", rotate_log.calls[2].target_degrees, 45)
  expect_equal("equal on_target", result.on_target, true)
end)

expect_error("radar_name number", function()
  local opts = base_opts()
  opts.radar_name = 1
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "radar_name must be a string or nil, got number")

expect_error("monitor_name boolean", function()
  local opts = base_opts()
  opts.monitor_name = true
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "monitor_name must be a string or nil, got boolean")

expect_error("pitch_bearing_name number", function()
  local opts = base_opts()
  opts.pitch_bearing_name = 2
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_bearing_name must be a string or nil, got number")

expect_error("yaw_motor_name number", function()
  local opts = base_opts()
  opts.yaw_motor_name = 3
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_motor_name must be a string or nil, got number")

expect_error("pitch_motor_name table", function()
  local opts = base_opts()
  opts.pitch_motor_name = {}
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_motor_name must be a string or nil, got table")

run("empty radar and monitor names are absent", function()
  local previous_radar = package.loaded["read_radar_tracks.lua"]
  local radar_calls = {}
  package.loaded["read_radar_tracks.lua"] = {
    read_radar_tracks = function(child_opts)
      radar_calls[#radar_calls + 1] = child_opts
      return {
        tracks = { valid_row("uuid-1") },
      }
    end,
  }
  local opts = base_opts()
  opts.radar_name = ""
  opts.monitor_name = ""
  local ok, result = pcall(aim_turret_at_target, opts)
  package.loaded["read_radar_tracks.lua"] = previous_radar
  if not ok then
    error(result)
  end
  expect_equal("empty radar names on_target", result.on_target, true)
  expect_equal("empty radar child call count", #radar_calls, 1)
  expect_equal("empty radar_name omitted", radar_calls[1].radar_name, nil)
  expect_equal("empty monitor_name omitted", radar_calls[1].monitor_name, nil)
end)

run("empty motor names omitted on children", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_motor_name = ""
  opts.pitch_motor_name = ""
  aim_turret_at_target(opts)
  expect_equal("empty yaw motor omitted", rotate_log.calls[1].motor_name, nil)
  expect_equal("empty pitch motor omitted", rotate_log.calls[2].motor_name, nil)
end)

expect_error("yaw_tolerance string", function()
  local opts = base_opts()
  opts.yaw_tolerance_degrees = "1"
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_tolerance_degrees must be a number, got string")

expect_error("yaw_tolerance empty string", function()
  local opts = base_opts()
  opts.yaw_tolerance_degrees = ""
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_tolerance_degrees must be a number, got string")

expect_error("yaw_tolerance inf", function()
  local opts = base_opts()
  opts.yaw_tolerance_degrees = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "yaw_tolerance_degrees must be a finite number, got inf")

expect_error("pitch_tolerance nan", function()
  local opts = base_opts()
  opts.pitch_tolerance_degrees = 0 / 0
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_tolerance_degrees must be a finite number, got nan")

expect_error("pitch_tolerance inf", function()
  local opts = base_opts()
  opts.pitch_tolerance_degrees = math.huge
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_tolerance_degrees must be a finite number, got inf")

expect_error("pitch_tolerance negative", function()
  local opts = base_opts()
  opts.pitch_tolerance_degrees = -0.1
  live_dish("uuid-1")
  aim_turret_at_target(opts)
end, "pitch_tolerance_degrees must be >= 0")

run("tolerance 0 is legal", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.yaw_tolerance_degrees = 0
  opts.pitch_tolerance_degrees = 0
  rotate_log.results[1] = 0
  rotate_log.results[2] = 0
  local result = aim_turret_at_target(opts)
  expect_equal("zero tolerance child yaw", rotate_log.calls[1].tolerance_degrees, 0)
  expect_equal("zero tolerance on_target", result.on_target, true)
end)

expect_error("empty selectedTrackId is no target", function()
  attach("radar_1", "create_radar:radar", dish_wrap({ valid_row("uuid-1") }))
  attach("mon_1", "create_radar:monitor", monitor_wrap("", {}))
  local opts = base_opts()
  opts.track_id = nil
  aim_turret_at_target(opts)
end, "no radar target this tick")

expect_error("track id is not case-folded", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.track_id = "UUID-1"
  aim_turret_at_target(opts)
end, "track 'UUID-1' is not in this tick's tracks")

expect_error("track id is not a substring match", function()
  live_dish("uuid-1")
  local opts = base_opts()
  opts.track_id = "uuid"
  aim_turret_at_target(opts)
end, "track 'uuid' is not in this tick's tracks")

run("pitch rotate non-number", function()
  live_dish("uuid-1")
  rotate_log.results[2] = "ok"
  local ok, err = pcall(aim_turret_at_target, base_opts())
  expect_equal("pitch non-number pcall", ok, false)
  local found = type(err) == "string" and
    string.find(err, "pitch rotate returned string, expected number", 1, true) ~=
      nil
  expect_equal("pitch non-number message", found, true)
  expect_equal("yaw already ran", #rotate_log.calls, 2)
end)

if failures > 0 then
  io.stderr:write(tostring(failures) .. " failed, " .. tostring(passes) ..
    " passed\n")
  os.exit(1)
end

io.write(tostring(passes) .. " passed\n")
