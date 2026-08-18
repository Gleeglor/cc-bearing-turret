local bearing_turret = dofile("compute_ballistic_aim.lua")

local function compute_ballistic_aim(...)
  return bearing_turret.compute_ballistic_aim(...)
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
    fail(
      name .. ": expected " .. tostring(expected) ..
        ", got " .. tostring(actual)
    )
    return
  end
  pass(name)
end

local function expect_near(name, actual, expected, epsilon)
  if type(actual) ~= "number" then
    fail(name .. ": expected number, got " .. tostring(actual))
    return
  end
  if math.abs(actual - expected) > epsilon then
    fail(
      name .. ": expected near " .. tostring(expected) ..
        ", got " .. tostring(actual)
    )
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

local function track_at(x, y, z, vx, vy, vz)
  return {
    id = "uuid-1",
    position = { x = x, y = y, z = z },
    velocity = { x = vx or 0, y = vy or 0, z = vz or 0 },
  }
end

local function base_opts(track, extra)
  local opts = {
    muzzle_x = 0,
    muzzle_y = 0,
    muzzle_z = 0,
    projectile_mass_kg = 1,
    powder_mass_kg = 1,
    charge_length_meters = 1,
    barrel_length_meters = 8,
    track = track,
    max_ticks = 80,
    muzzle_velocity_blocks_per_tick = 4,
    drag_multiplier = 0,
  }
  if extra ~= nil then
    for key, value in pairs(extra) do
      opts[key] = value
    end
  end
  return opts
end

local function output_keys(result)
  local count = 0
  for _ in pairs(result) do
    count = count + 1
  end
  return count
end

run("stationary south intercept", function()
  local result = compute_ballistic_aim(base_opts(track_at(0, 0, 20)))
  expect_equal("yaw 0", result.yaw_degrees == 0 or result.yaw_degrees == -0, true)
  expect_near("pitch", result.pitch_degrees, 0.9, 0.2)
  expect_equal("tof", result.time_of_flight_ticks, 5)
  expect_equal("v", result.muzzle_velocity_blocks_per_tick, 4)
  expect_near("impact z", result.impact_z, 20, 0.05)
  expect_equal("trajectory low", result.trajectory, "low")
  expect_equal("eight keys", output_keys(result), 8)
end)

run("west yaw is 90", function()
  local result = compute_ballistic_aim(base_opts(track_at(-20, 0, 0)))
  expect_equal("yaw", result.yaw_degrees, 90)
  expect_near("impact x", result.impact_x, -20, 0.05)
end)

run("east yaw is -90", function()
  local result = compute_ballistic_aim(base_opts(track_at(20, 0, 0)))
  expect_equal("yaw", result.yaw_degrees, -90)
end)

run("north yaw is 180 or -180", function()
  local result = compute_ballistic_aim(base_opts(track_at(0, 0, -20)))
  local yaw = result.yaw_degrees
  expect_equal("yaw 180", yaw == 180 or yaw == -180, true)
end)

run("high request with one family still names high", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { trajectory = "high" })
  )
  expect_equal("trajectory", result.trajectory, "high")
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("two families low is lower root not graze", function()
  local low = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { gravity_multiplier = 10 })
  )
  local named_low = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), {
      gravity_multiplier = 10,
      trajectory = "low",
    })
  )
  local high = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), {
      gravity_multiplier = 10,
      trajectory = "high",
    })
  )
  expect_equal("omit names low", low.trajectory, "low")
  expect_equal("explicit low name", named_low.trajectory, "low")
  expect_equal("high name", high.trajectory, "high")
  expect_equal("omit yaw 0", low.yaw_degrees == 0 or low.yaw_degrees == -0, true)
  expect_equal("high yaw 0", high.yaw_degrees == 0 or high.yaw_degrees == -0, true)
  expect_near("low pitch", low.pitch_degrees, 8.7, 0.15)
  expect_near("named low pitch", named_low.pitch_degrees, 8.7, 0.15)
  expect_near("high pitch", high.pitch_degrees, 80.95, 0.15)
  expect_equal("pitches differ", low.pitch_degrees ~= high.pitch_degrees, true)
  expect_equal("low below high", low.pitch_degrees < high.pitch_degrees, true)
  expect_equal("low tof", low.time_of_flight_ticks, 5)
  expect_equal("high tof", high.time_of_flight_ticks, 32)
  expect_near("low impact z", low.impact_z, 20, 0.3)
  expect_near("high impact z", high.impact_z, 20, 0.3)
  expect_equal("low eight keys", output_keys(low), 8)
  expect_equal("high eight keys", output_keys(high), 8)
end)

run("middle hit run is ignored", function()
  local low = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { gravity_multiplier = 32 })
  )
  local high = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), {
      gravity_multiplier = 32,
      trajectory = "high",
    })
  )
  expect_equal("low name", low.trajectory, "low")
  expect_equal("high name", high.trajectory, "high")
  expect_near("low root", low.pitch_degrees, 35.25, 0.15)
  expect_near("high root", high.pitch_degrees, 51.45, 0.15)
  expect_equal("not middle", math.abs(low.pitch_degrees - 44) > 2, true)
  expect_equal("high not middle", math.abs(high.pitch_degrees - 44) > 2, true)
  expect_equal("low below high", low.pitch_degrees < high.pitch_degrees, true)
  expect_equal("low tof", low.time_of_flight_ticks, 6)
  expect_equal("high tof", high.time_of_flight_ticks, 8)
  expect_near("low impact z", low.impact_z, 20, 0.5)
  expect_near("high impact z", high.impact_z, 20, 0.5)
end)

run("empty trajectory string means low", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { trajectory = "" })
  )
  expect_equal("trajectory", result.trajectory, "low")
end)

run("moving lead along +Z", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 16, 0, 0, 0.8))
  )
  expect_equal("tof", result.time_of_flight_ticks, 5)
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("overhead pitch 90 and yaw 0", function()
  local result = compute_ballistic_aim(base_opts(track_at(0, 20, 0)))
  expect_equal("yaw", result.yaw_degrees, 0)
  expect_equal("pitch", result.pitch_degrees, 90)
  expect_near("impact y", result.impact_y, 20, 0.5)
end)

run("underfoot pitch -90", function()
  local result = compute_ballistic_aim(base_opts(track_at(0, -20, 0)))
  expect_equal("yaw", result.yaw_degrees, 0)
  expect_equal("pitch", result.pitch_degrees, -90)
end)

run("empty projectile_kind means cannon", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_kind = "" })
  )
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("negative gravity_multiplier is not a failure", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { gravity_multiplier = -1 })
  )
  expect_equal("eight keys", output_keys(result), 8)
end)

run("does not rewrite PLAYER velocity.y", function()
  local falling = track_at(0, 20, 20, 0, -0.08, 0)
  local result = compute_ballistic_aim(base_opts(falling))
  expect_equal("caller vy", falling.velocity.y, -0.08)
  expect_equal("eight keys", output_keys(result), 8)
end)

run("falling lead uses velocity.y", function()
  local pos_y = 20
  local vy = -1
  local control = compute_ballistic_aim(
    base_opts(track_at(0, pos_y, 20, 0, 0, 0))
  )
  local falling = track_at(0, pos_y, 20, 0, vy, 0)
  local result = compute_ballistic_aim(base_opts(falling))
  local lead_y = pos_y + vy * result.time_of_flight_ticks
  expect_near("impact y follows falling lead", result.impact_y, lead_y, 1.0)
  expect_equal(
    "below vy=0 control",
    result.impact_y < control.impact_y - 1.0,
    true
  )
end)

run("does not mutate caller track extra keys", function()
  local row = track_at(0, 0, 20)
  row.category = "PLAYER"
  row.entityType = "minecraft:player"
  row.scannedTime = 12
  local result = compute_ballistic_aim(base_opts(row))
  expect_equal("category kept", row.category, "PLAYER")
  expect_equal("no category on output", result.category, nil)
end)

run("Robins speed when override omitted", function()
  local opts = base_opts(track_at(0, 0, 38))
  opts.muzzle_velocity_blocks_per_tick = nil
  local result = compute_ballistic_aim(opts)
  local ratio = 8 / 1
  local radicand = (1 / (1 + 1 / 3)) * math.log(ratio)
  local expected = 606.8568 * math.sqrt(radicand) / 20
  expect_near("robins v", result.muzzle_velocity_blocks_per_tick, expected, 1e-9)
  expect_near("impact z", result.impact_z, 38, 1.0)
end)

run("L/c below 1 still yields positive Robins speed", function()
  local opts = base_opts(track_at(0, 0.03, 0), {
    barrel_length_meters = 1,
    charge_length_meters = 8,
    max_ticks = 20,
  })
  opts.muzzle_velocity_blocks_per_tick = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("v positive", result.muzzle_velocity_blocks_per_tick > 0, true)
end)

run("gravity_multiplier 0 is not a failure", function()
  local result = compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { gravity_multiplier = 0 })
  )
  expect_near("flat pitch", result.pitch_degrees, 0, 0.05)
end)

run("omitted drag_multiplier means 1", function()
  local track = track_at(0, 0, 8)
  local omitted = base_opts(track)
  omitted.drag_multiplier = nil
  local vacuum = base_opts(track)
  local explicit = base_opts(track)
  explicit.drag_multiplier = 1
  local a = compute_ballistic_aim(omitted)
  local b = compute_ballistic_aim(vacuum)
  local c = compute_ballistic_aim(explicit)
  expect_equal("omit eight keys", output_keys(a), 8)
  expect_equal("vacuum eight keys", output_keys(b), 8)
  expect_equal("explicit eight keys", output_keys(c), 8)
  expect_equal("omit matches 1 pitch", a.pitch_degrees, c.pitch_degrees)
  expect_equal("omit matches 1 tof", a.time_of_flight_ticks, c.time_of_flight_ticks)
  expect_equal("omit matches 1 impact z", a.impact_z, c.impact_z)
  expect_equal("omit differs vacuum pitch", a.pitch_degrees ~= b.pitch_degrees, true)
  expect_equal("omit differs vacuum tof", a.time_of_flight_ticks ~= b.time_of_flight_ticks, true)
  expect_equal("omit differs vacuum impact z", a.impact_z ~= b.impact_z, true)
end)

run("cannon vs autocannon area with drag", function()
  local track = track_at(0, 0, 8)
  local cannon_opts = base_opts(track)
  cannon_opts.drag_multiplier = 1
  cannon_opts.projectile_kind = "cannon"
  local auto_opts = base_opts(track)
  auto_opts.drag_multiplier = 1
  auto_opts.projectile_kind = "autocannon"
  local d = compute_ballistic_aim(cannon_opts)
  local e = compute_ballistic_aim(auto_opts)
  expect_equal("cannon eight keys", output_keys(d), 8)
  expect_equal("autocannon eight keys", output_keys(e), 8)
  expect_equal(
    "kind radii differ",
    d.pitch_degrees ~= e.pitch_degrees
      or d.time_of_flight_ticks ~= e.time_of_flight_ticks
      or d.impact_z ~= e.impact_z,
    true
  )
  expect_equal(
    "cannon loftier or slower",
    d.pitch_degrees > e.pitch_degrees
      or d.time_of_flight_ticks > e.time_of_flight_ticks,
    true
  )
end)

run("machine_gun vs autocannon impact with drag", function()
  local track = track_at(0, 0, 20)
  local auto_opts = base_opts(track)
  auto_opts.drag_multiplier = 1
  auto_opts.projectile_kind = "autocannon"
  local mg_opts = base_opts(track)
  mg_opts.drag_multiplier = 1
  mg_opts.projectile_kind = "machine_gun"
  local f = compute_ballistic_aim(auto_opts)
  local g = compute_ballistic_aim(mg_opts)
  expect_equal("autocannon eight keys", output_keys(f), 8)
  expect_equal("machine_gun eight keys", output_keys(g), 8)
  expect_equal("impact z differs", f.impact_z ~= g.impact_z, true)
end)

run("tiny mass drag clamp hits z=2", function()
  local opts = base_opts(track_at(0, 0, 2))
  opts.drag_multiplier = 1
  opts.projectile_mass_kg = 1e-6
  opts.gravity_multiplier = 0
  local h = compute_ballistic_aim(opts)
  expect_equal("eight keys", output_keys(h), 8)
  expect_near("impact z", h.impact_z, 2, 1.0)
end)

run("max_ticks omit uses 2000 and still intercepts", function()
  local opts = base_opts(track_at(0, 0, 20))
  opts.max_ticks = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("tof", result.time_of_flight_ticks, 5)
end)

run("search does not yield", function()
  local sleep_calls = 0
  local previous_sleep = _G.sleep
  local previous_pull = os.pullEvent
  _G.sleep = function()
    sleep_calls = sleep_calls + 1
    error("sleep must not be called", 0)
  end
  os.pullEvent = function()
    sleep_calls = sleep_calls + 1
    error("os.pullEvent must not be called", 0)
  end
  local ok, err = pcall(function()
    compute_ballistic_aim(base_opts(track_at(0, 0, 20)))
  end)
  _G.sleep = previous_sleep
  os.pullEvent = previous_pull
  if not ok then
    error(err, 0)
  end
  expect_equal("no yield", sleep_calls, 0)
end)

run("supplied track does not wrap peripherals", function()
  _G.peripheral.getNames = function()
    error("getNames must not be called", 0)
  end
  local ok, err = pcall(function()
    compute_ballistic_aim(base_opts(track_at(0, 0, 20)))
  end)
  _G.peripheral.getNames = function()
    local names = {}
    local index = 1
    while index <= #bus.names do
      names[index] = bus.names[index]
      index = index + 1
    end
    return names
  end
  if not ok then
    error(err, 0)
  end
end)

run("omitted track uses selectedTrack not tracks[1]", function()
  local first = track_at(400, 0, 0)
  first.id = "uuid-first"
  local selected = track_at(0, 0, 20)
  selected.id = "uuid-selected"
  attach("radar_1", "create_radar:radar", dish_wrap({ first, selected }))
  attach(
    "mon",
    "create_radar:monitor",
    monitor_wrap("uuid-selected", selected)
  )
  local opts = base_opts(nil)
  opts.track = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("yaw 0", result.yaw_degrees == 0 or result.yaw_degrees == -0, true)
  expect_near("impact x", result.impact_x, 0, 0.05)
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("empty radar_name with omitted track discovers", function()
  local selected = track_at(0, 0, 20)
  attach("radar_1", "create_radar:radar", dish_wrap({ selected }))
  attach("mon", "create_radar:monitor", monitor_wrap("uuid-1", selected))
  local opts = base_opts(nil, { radar_name = "", monitor_name = "" })
  opts.track = nil
  local result = compute_ballistic_aim(opts)
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("omitted track names the second radar", function()
  local chosen = track_at(0, 0, 20)
  chosen.id = "uuid-south"
  local decoy = track_at(-20, 0, 0)
  decoy.id = "uuid-west"
  attach("radar_extra", "create_radar:radar", dish_wrap({ decoy }))
  attach("radar_2", "create_radar:radar", dish_wrap({ chosen }))
  attach(
    "mon",
    "create_radar:monitor",
    monitor_wrap("uuid-south", chosen)
  )
  local opts = base_opts(nil, { radar_name = "radar_2" })
  opts.track = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("yaw 0", result.yaw_degrees == 0 or result.yaw_degrees == -0, true)
  expect_near("impact z", result.impact_z, 20, 0.05)
end)

run("omitted track names the second monitor", function()
  local south = track_at(0, 0, 20)
  south.id = "uuid-south"
  local west = track_at(-20, 0, 0)
  west.id = "uuid-west"
  attach(
    "radar_1",
    "create_radar:radar",
    dish_wrap({ south, west })
  )
  attach(
    "mon_a",
    "create_radar:monitor",
    monitor_wrap("uuid-south", south)
  )
  attach(
    "left_monitor",
    "create_radar:monitor",
    monitor_wrap("uuid-west", west)
  )
  local opts = base_opts(nil, { monitor_name = "left_monitor" })
  opts.track = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("yaw", result.yaw_degrees, 90)
  expect_near("impact x", result.impact_x, -20, 0.05)
end)

run("omitted track names radar and monitor among two of each", function()
  local south = track_at(0, 0, 20)
  south.id = "uuid-south"
  local west = track_at(-20, 0, 0)
  west.id = "uuid-west"
  attach("radar_extra", "create_radar:radar", dish_wrap({ south }))
  attach("radar_2", "create_radar:radar", dish_wrap({ west }))
  attach(
    "mon_a",
    "create_radar:monitor",
    monitor_wrap("uuid-south", south)
  )
  attach(
    "left_monitor",
    "create_radar:monitor",
    monitor_wrap("uuid-west", west)
  )
  local opts = base_opts(nil, {
    radar_name = "radar_2",
    monitor_name = "left_monitor",
  })
  opts.track = nil
  local result = compute_ballistic_aim(opts)
  expect_equal("yaw", result.yaw_degrees, 90)
  expect_near("impact x", result.impact_x, -20, 0.05)
end)

expect_error("no selected track", function()
  local first = track_at(0, 0, 20)
  attach("radar_1", "create_radar:radar", dish_wrap({ first }))
  attach("mon", "create_radar:monitor", monitor_wrap("", {}))
  local opts = base_opts(nil)
  opts.track = nil
  compute_ballistic_aim(opts)
end, "no selected track")

expect_error("child throw", function()
  attach("radar_1", "create_radar:radar", dish_wrap(function()
    error("dish down", 0)
  end))
  local opts = base_opts(nil)
  opts.track = nil
  compute_ballistic_aim(opts)
end, "read_radar_tracks threw:")

expect_error("arity zero", function()
  compute_ballistic_aim()
end, "expected exactly one argument, got 0")

expect_error("arity two", function()
  compute_ballistic_aim(base_opts(track_at(0, 0, 20)), 1)
end, "expected exactly one argument, got 2")

expect_error("opts string", function()
  compute_ballistic_aim("wrap")
end, "inputs must be a table, got string")

expect_error("unknown key", function()
  local opts = base_opts(track_at(0, 0, 20))
  opts.foo = 1
  compute_ballistic_aim(opts)
end, "unknown input 'foo'")

expect_error("array index key", function()
  local opts = base_opts(track_at(0, 0, 20))
  opts[1] = true
  compute_ballistic_aim(opts)
end, "unknown input '1'")

expect_error("radar_name with track", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { radar_name = "radar_1" })
  )
end, "radar_name is not used when track is supplied")

expect_error("monitor_name with track", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { monitor_name = "mon" })
  )
end, "monitor_name is not used when track is supplied")

expect_error("radar_name not string", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { radar_name = 1 })
  )
end, "radar_name must be a string or nil, got number")

expect_error("monitor_name not string", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { monitor_name = false })
  )
end, "monitor_name must be a string or nil, got boolean")

expect_error("gravity_multiplier nan", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { gravity_multiplier = 0 / 0 })
  )
end, "gravity_multiplier must be a finite number, got nan")

expect_error("muzzle_x missing", function()
  local opts = base_opts(track_at(0, 0, 20))
  opts.muzzle_x = nil
  compute_ballistic_aim(opts)
end, "muzzle_x is required")

expect_error("muzzle_x nan", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_x = 0 / 0 })
  )
end, "muzzle_x must be a finite number, got nan")

expect_error("muzzle_x inf", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_x = math.huge })
  )
end, "muzzle_x must be a finite number, got inf")

expect_error("mass not number", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_mass_kg = "1" })
  )
end, "projectile_mass_kg must be a number, got string")

expect_error("mass zero", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_mass_kg = 0 })
  )
end, "projectile_mass_kg must be greater than 0")

expect_error("powder negative", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { powder_mass_kg = -1 })
  )
end, "powder_mass_kg must be greater than 0")

expect_error("override speed zero", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_velocity_blocks_per_tick = 0 })
  )
end, "muzzle_velocity_blocks_per_tick must be greater than 0")

expect_error("drag_multiplier not number", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { drag_multiplier = "0" })
  )
end, "drag_multiplier must be a number, got string")

expect_error("drag_multiplier nan", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { drag_multiplier = 0 / 0 })
  )
end, "drag_multiplier must be a finite number, got nan")

expect_error("drag_multiplier inf", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { drag_multiplier = math.huge })
  )
end, "drag_multiplier must be a finite number, got inf")

expect_error("override speed not number", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_velocity_blocks_per_tick = "4" })
  )
end, "muzzle_velocity_blocks_per_tick must be a number, got string")

expect_error("override speed nan", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_velocity_blocks_per_tick = 0 / 0 })
  )
end, "muzzle_velocity_blocks_per_tick must be a finite number, got nan")

expect_error("override speed inf", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { muzzle_velocity_blocks_per_tick = math.huge })
  )
end, "muzzle_velocity_blocks_per_tick must be a finite number, got inf")

expect_error("drag_multiplier negative", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { drag_multiplier = -0.1 })
  )
end, "drag_multiplier must be >= 0")

expect_error("max_ticks zero", function()
  compute_ballistic_aim(base_opts(track_at(0, 0, 20), { max_ticks = 0 }))
end, "max_ticks must be an integer 1 through 100000, got 0")

expect_error("max_ticks fraction", function()
  compute_ballistic_aim(base_opts(track_at(0, 0, 20), { max_ticks = 1.5 }))
end, "max_ticks must be an integer 1 through 100000, got 1.5")

expect_error("max_ticks too large", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { max_ticks = 100001 })
  )
end, "max_ticks must be an integer 1 through 100000, got 100001")

expect_error("max_ticks not number", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { max_ticks = "80" })
  )
end, "max_ticks must be a number, got string")

expect_error("max_ticks nan", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { max_ticks = 0 / 0 })
  )
end, "max_ticks must be a finite number, got nan")

expect_error("max_ticks inf", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { max_ticks = math.huge })
  )
end, "max_ticks must be a finite number, got inf")

expect_error("trajectory not string", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { trajectory = 1 })
  )
end, "trajectory must be a string or nil, got number")

expect_error("projectile_kind not string", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_kind = false })
  )
end, "projectile_kind must be a string or nil, got boolean")

expect_error("trajectory table", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { trajectory = {} })
  )
end, "trajectory must be a string or nil, got table")

expect_error("projectile_kind table", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_kind = {} })
  )
end, "projectile_kind must be a string or nil, got table")

expect_error("bad trajectory", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { trajectory = "mid" })
  )
end, "trajectory must be 'low' or 'high', got 'mid'")

expect_error("bad projectile_kind", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { projectile_kind = "shell" })
  )
end, "projectile_kind must be 'cannon', 'autocannon', or 'machine_gun', got 'shell'")

expect_error("track false is not omit", function()
  compute_ballistic_aim(base_opts(false))
end, "track must be a table, got boolean")

expect_error("track id missing", function()
  local row = track_at(0, 0, 20)
  row.id = nil
  compute_ballistic_aim(base_opts(row))
end, "track id is missing")

expect_error("track id empty", function()
  local row = track_at(0, 0, 20)
  row.id = ""
  compute_ballistic_aim(base_opts(row))
end, "track id is empty")

expect_error("track id number", function()
  local row = track_at(0, 0, 20)
  row.id = 1
  compute_ballistic_aim(base_opts(row))
end, "track id is number, expected string")

expect_error("track position missing", function()
  local row = track_at(0, 0, 20)
  row.position = nil
  compute_ballistic_aim(base_opts(row))
end, "track position is missing")

expect_error("track velocity not table", function()
  local row = track_at(0, 0, 20)
  row.velocity = 1
  compute_ballistic_aim(base_opts(row))
end, "track velocity is number, expected table")

expect_error("track velocity y nan", function()
  local row = track_at(0, 0, 20)
  row.velocity.y = 0 / 0
  compute_ballistic_aim(base_opts(row))
end, "track velocity.y must be a finite number, got nan")

expect_error("track position not table", function()
  local row = track_at(0, 0, 20)
  row.position = "nope"
  compute_ballistic_aim(base_opts(row))
end, "track position is string, expected table")

expect_error("track velocity missing", function()
  local row = track_at(0, 0, 20)
  row.velocity = nil
  compute_ballistic_aim(base_opts(row))
end, "track velocity is missing")

expect_error("track position x missing", function()
  local row = track_at(0, 0, 20)
  row.position.x = nil
  compute_ballistic_aim(base_opts(row))
end, "track position.x must be a finite number, got nil")

expect_error("track position y string", function()
  local row = track_at(0, 0, 20)
  row.position.y = "1"
  compute_ballistic_aim(base_opts(row))
end, "track position.y must be a finite number, got string")

expect_error("track position z nan", function()
  local row = track_at(0, 0, 20)
  row.position.z = 0 / 0
  compute_ballistic_aim(base_opts(row))
end, "track position.z must be a finite number, got nan")

expect_error("track position x inf", function()
  local row = track_at(0, 0, 20)
  row.position.x = math.huge
  compute_ballistic_aim(base_opts(row))
end, "track position.x must be a finite number, got inf")

expect_error("no intercept", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 400), { max_ticks = 5 })
  )
end, "no intercept")

expect_error("charge_length not number", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { charge_length_meters = true })
  )
end, "charge_length_meters must be a number, got boolean")

expect_error("charge_length zero", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { charge_length_meters = 0 })
  )
end, "charge_length_meters must be greater than 0")

expect_error("charge_length negative", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { charge_length_meters = -1 })
  )
end, "charge_length_meters must be greater than 0")

expect_error("vacuum overshoots z=2", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 2), { gravity_multiplier = 0 })
  )
end, "no intercept")

expect_error("zero speed ends sample no intercept", function()
  local opts = base_opts(track_at(0, 0, 8))
  opts.drag_multiplier = 1
  opts.projectile_mass_kg = 1e-6
  opts.gravity_multiplier = 0
  compute_ballistic_aim(opts)
end, "no intercept")

expect_error("barrel_length zero", function()
  compute_ballistic_aim(
    base_opts(track_at(0, 0, 20), { barrel_length_meters = 0 })
  )
end, "barrel_length_meters must be greater than 0")

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
