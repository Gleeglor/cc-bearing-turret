local original_dofile = dofile
local bearing_turret = dofile("engage_simulated_bearing_turret.lua")

local function engage_simulated_bearing_turret(...)
  return bearing_turret.engage_simulated_bearing_turret(...)
end

local failures = 0
local passes = 0

local dofile_log = {}
local compute_calls = {}
local aim_calls = {}
local fire_calls = {}
local sleep_count = 0
local child_files = {}

_G.sleep = function()
  sleep_count = sleep_count + 1
end

local function fail(message)
  failures = failures + 1
  io.stderr:write("FAIL " .. message .. "\n")
end

local function pass(name)
  passes = passes + 1
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

local function reset_children()
  dofile_log = {}
  compute_calls = {}
  aim_calls = {}
  fire_calls = {}
  sleep_count = 0
  child_files = {
    ["compute_ballistic_aim.lua"] = {
      compute_ballistic_aim = function(opts)
        compute_calls[#compute_calls + 1] = opts
        return {
          yaw_degrees = 12.5,
          pitch_degrees = -4,
          time_of_flight_ticks = 40,
          extra = "drop-me",
        }
      end,
    },
    ["aim_turret_at_target.lua"] = {
      aim_turret_at_target = function(opts)
        aim_calls[#aim_calls + 1] = opts
        return { on_target = true }
      end,
    },
    ["fire_rotating_barrel.lua"] = {
      fire_rotating_barrel = function(opts)
        fire_calls[#fire_calls + 1] = opts
      end,
    },
  }
  _G.dofile = function(path)
    dofile_log[#dofile_log + 1] = path
    local mod = child_files[path]
    if mod == nil then
      error("no stub for " .. tostring(path), 0)
    end
    return mod
  end
end

local function base_opts()
  return {
    yaw_bearing_name = "yaw_swivel",
    pitch_bearing_name = "pitch_swivel",
    yaw_motor_name = "yaw_motor",
    pitch_motor_name = "pitch_motor",
    yaw_rpm = 16,
    pitch_rpm = -8,
    side = "back",
    muzzle_x = 10,
    muzzle_y = 64,
    muzzle_z = -3,
    projectile_mass_kg = 1.2,
    powder_mass_kg = 0.5,
    charge_length_meters = 0.8,
    barrel_length_meters = 3.4,
  }
end

local function expect_error(name, fn, needle)
  reset_children()
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

local function run(name, fn)
  reset_children()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

expect_error("zero arguments", function()
  engage_simulated_bearing_turret()
end, "expected exactly one argument, got 0")

expect_error("two arguments", function()
  engage_simulated_bearing_turret(base_opts(), {})
end, "expected exactly one argument, got 2")

expect_error("nil opts", function()
  engage_simulated_bearing_turret(nil)
end, "inputs must be a table, got nil")

expect_error("string opts", function()
  engage_simulated_bearing_turret("yaw_swivel")
end, "inputs must be a table, got string")

expect_error("unknown key", function()
  local opts = base_opts()
  opts.target_degrees = 1
  engage_simulated_bearing_turret(opts)
end, "unknown input 'target_degrees'")

expect_error("unknown index 1", function()
  local opts = base_opts()
  opts[1] = "x"
  engage_simulated_bearing_turret(opts)
end, "unknown input '1'")

expect_error("bearing_name unknown", function()
  local opts = base_opts()
  opts.bearing_name = "yaw_swivel"
  engage_simulated_bearing_turret(opts)
end, "unknown input 'bearing_name'")

expect_error("motor_name unknown", function()
  local opts = base_opts()
  opts.motor_name = "yaw_motor"
  engage_simulated_bearing_turret(opts)
end, "unknown input 'motor_name'")

expect_error("yaw_degrees unknown", function()
  local opts = base_opts()
  opts.yaw_degrees = 9
  engage_simulated_bearing_turret(opts)
end, "unknown input 'yaw_degrees'")

expect_error("pitch_degrees unknown", function()
  local opts = base_opts()
  opts.pitch_degrees = 2
  engage_simulated_bearing_turret(opts)
end, "unknown input 'pitch_degrees'")

run("unknown key does not dofile", function()
  local opts = base_opts()
  opts.yaw_degrees = 1
  local ok = pcall(engage_simulated_bearing_turret, opts)
  expect_equal("unknown failed", ok, false)
  expect_equal("no dofile", #dofile_log, 0)
end)

expect_error("radar_name not string", function()
  local opts = base_opts()
  opts.radar_name = 1
  engage_simulated_bearing_turret(opts)
end, "radar_name must be a string or nil, got number")

expect_error("monitor_name not string", function()
  local opts = base_opts()
  opts.monitor_name = true
  engage_simulated_bearing_turret(opts)
end, "monitor_name must be a string or nil, got boolean")

expect_error("missing yaw_bearing_name", function()
  local opts = base_opts()
  opts.yaw_bearing_name = nil
  engage_simulated_bearing_turret(opts)
end, "yaw_bearing_name is required")

expect_error("yaw_bearing_name not string", function()
  local opts = base_opts()
  opts.yaw_bearing_name = 3
  engage_simulated_bearing_turret(opts)
end, "yaw_bearing_name must be a string, got number")

expect_error("empty yaw_bearing_name", function()
  local opts = base_opts()
  opts.yaw_bearing_name = ""
  engage_simulated_bearing_turret(opts)
end, "yaw_bearing_name must be a non-empty string")

expect_error("missing pitch_bearing_name", function()
  local opts = base_opts()
  opts.pitch_bearing_name = nil
  engage_simulated_bearing_turret(opts)
end, "pitch_bearing_name is required")

expect_error("empty pitch_motor_name", function()
  local opts = base_opts()
  opts.pitch_motor_name = ""
  engage_simulated_bearing_turret(opts)
end, "pitch_motor_name must be a non-empty string")

expect_error("missing yaw_motor_name", function()
  local opts = base_opts()
  opts.yaw_motor_name = nil
  engage_simulated_bearing_turret(opts)
end, "yaw_motor_name is required")

expect_error("yaw_motor_name not string", function()
  local opts = base_opts()
  opts.yaw_motor_name = 8
  engage_simulated_bearing_turret(opts)
end, "yaw_motor_name must be a string, got number")

expect_error("empty yaw_motor_name", function()
  local opts = base_opts()
  opts.yaw_motor_name = ""
  engage_simulated_bearing_turret(opts)
end, "yaw_motor_name must be a non-empty string")

expect_error("wrap table is not opts", function()
  engage_simulated_bearing_turret({
    getTargetAngle = function()
      return 0
    end,
  })
end, "unknown input 'getTargetAngle'")

expect_error("equal bearing names", function()
  local opts = base_opts()
  opts.pitch_bearing_name = "yaw_swivel"
  engage_simulated_bearing_turret(opts)
end, "yaw_bearing_name and pitch_bearing_name must differ")

expect_error("equal motor names", function()
  local opts = base_opts()
  opts.pitch_motor_name = "yaw_motor"
  engage_simulated_bearing_turret(opts)
end, "yaw_motor_name and pitch_motor_name must differ")

run("equal bearings checked before equal motors", function()
  local opts = base_opts()
  opts.pitch_bearing_name = "yaw_swivel"
  opts.pitch_motor_name = "yaw_motor"
  local ok, err = pcall(engage_simulated_bearing_turret, opts)
  expect_equal("failed", ok, false)
  local found = type(err) == "string" and
    string.find(err, "yaw_bearing_name and pitch_bearing_name must differ", 1, true) ~=
      nil
  expect_equal("bearing message first", found, true)
end)

expect_error("missing muzzle_x", function()
  local opts = base_opts()
  opts.muzzle_x = nil
  engage_simulated_bearing_turret(opts)
end, "muzzle_x is required")

expect_error("missing muzzle_y", function()
  local opts = base_opts()
  opts.muzzle_y = nil
  engage_simulated_bearing_turret(opts)
end, "muzzle_y is required")

expect_error("missing muzzle_z", function()
  local opts = base_opts()
  opts.muzzle_z = nil
  engage_simulated_bearing_turret(opts)
end, "muzzle_z is required")

expect_error("missing projectile_mass_kg", function()
  local opts = base_opts()
  opts.projectile_mass_kg = nil
  engage_simulated_bearing_turret(opts)
end, "projectile_mass_kg is required")

expect_error("missing powder_mass_kg", function()
  local opts = base_opts()
  opts.powder_mass_kg = nil
  engage_simulated_bearing_turret(opts)
end, "powder_mass_kg is required")

expect_error("missing charge_length_meters", function()
  local opts = base_opts()
  opts.charge_length_meters = nil
  engage_simulated_bearing_turret(opts)
end, "charge_length_meters is required")

expect_error("missing barrel_length_meters", function()
  local opts = base_opts()
  opts.barrel_length_meters = nil
  engage_simulated_bearing_turret(opts)
end, "barrel_length_meters is required")

expect_error("missing yaw_rpm", function()
  local opts = base_opts()
  opts.yaw_rpm = nil
  engage_simulated_bearing_turret(opts)
end, "yaw_rpm is required")

expect_error("missing pitch_rpm", function()
  local opts = base_opts()
  opts.pitch_rpm = nil
  engage_simulated_bearing_turret(opts)
end, "pitch_rpm is required")

expect_error("missing side", function()
  local opts = base_opts()
  opts.side = nil
  engage_simulated_bearing_turret(opts)
end, "side is required")

run("envelope missing side does not dofile", function()
  local opts = base_opts()
  opts.side = nil
  local ok = pcall(engage_simulated_bearing_turret, opts)
  expect_equal("failed", ok, false)
  expect_equal("no dofile", #dofile_log, 0)
end)

run("compute required before yaw_rpm", function()
  local opts = base_opts()
  opts.muzzle_x = nil
  opts.yaw_rpm = nil
  local ok, err = pcall(engage_simulated_bearing_turret, opts)
  expect_equal("failed", ok, false)
  local found = type(err) == "string" and
    string.find(err, "muzzle_x is required", 1, true) ~= nil
  expect_equal("muzzle first", found, true)
end)

expect_error("dofile throw compute", function()
  child_files["compute_ballistic_aim.lua"] = nil
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'compute_ballistic_aim'")

run("dofile throw compute uses missing command not raw", function()
  child_files["compute_ballistic_aim.lua"] = nil
  local ok, err = pcall(engage_simulated_bearing_turret, base_opts())
  expect_equal("failed", ok, false)
  local raw = type(err) == "string" and
    string.find(err, "no stub for", 1, true) ~= nil
  expect_equal("no raw dofile", raw, false)
end)

expect_error("dofile throw aim", function()
  child_files["aim_turret_at_target.lua"] = nil
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'aim_turret_at_target'")

expect_error("dofile throw fire", function()
  child_files["fire_rotating_barrel.lua"] = nil
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'fire_rotating_barrel'")

expect_error("dofile non-table compute", function()
  child_files["compute_ballistic_aim.lua"] = 1
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'compute_ballistic_aim'")

expect_error("missing function compute", function()
  child_files["compute_ballistic_aim.lua"] = {}
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'compute_ballistic_aim'")

expect_error("dofile non-table aim", function()
  child_files["aim_turret_at_target.lua"] = "nope"
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'aim_turret_at_target'")

expect_error("missing function aim", function()
  child_files["aim_turret_at_target.lua"] = {}
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'aim_turret_at_target'")

expect_error("dofile non-table fire", function()
  child_files["fire_rotating_barrel.lua"] = false
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'fire_rotating_barrel'")

expect_error("missing function fire", function()
  child_files["fire_rotating_barrel.lua"] = {}
  engage_simulated_bearing_turret(base_opts())
end, "missing command 'fire_rotating_barrel'")

run("loads all three before any call", function()
  engage_simulated_bearing_turret(base_opts())
  expect_equal("three loads", #dofile_log, 3)
  expect_equal("compute file", dofile_log[1], "compute_ballistic_aim.lua")
  expect_equal("aim file", dofile_log[2], "aim_turret_at_target.lua")
  expect_equal("fire file", dofile_log[3], "fire_rotating_barrel.lua")
end)

run("off-target still loads fire", function()
  child_files["aim_turret_at_target.lua"].aim_turret_at_target = function(opts)
    aim_calls[#aim_calls + 1] = opts
    return { on_target = false }
  end
  local result = engage_simulated_bearing_turret(base_opts())
  expect_equal("on_target", result.on_target, false)
  expect_equal("fired", result.fired, false)
  expect_equal("three loads", #dofile_log, 3)
  expect_equal("no fire call", #fire_calls, 0)
end)

run("happy on-target fires", function()
  local result = engage_simulated_bearing_turret(base_opts())
  expect_equal("on_target", result.on_target, true)
  expect_equal("fired", result.fired, true)
  expect_equal("compute once", #compute_calls, 1)
  expect_equal("aim once", #aim_calls, 1)
  expect_equal("fire once", #fire_calls, 1)
end)

run("compute does not receive axis names", function()
  engage_simulated_bearing_turret(base_opts())
  expect_equal("no yaw bearing", compute_calls[1].yaw_bearing_name, nil)
  expect_equal("has muzzle_x", compute_calls[1].muzzle_x, 10)
  expect_equal("has powder", compute_calls[1].powder_mass_kg, 0.5)
end)

run("aim receives parent rpm and compute degrees", function()
  engage_simulated_bearing_turret(base_opts())
  local aim_opts = aim_calls[1]
  expect_equal("yaw_degrees", aim_opts.yaw_degrees, 12.5)
  expect_equal("pitch_degrees", aim_opts.pitch_degrees, -4)
  expect_equal("yaw_rpm", aim_opts.yaw_rpm, 16)
  expect_equal("pitch_rpm", aim_opts.pitch_rpm, -8)
  expect_equal("yaw bearing", aim_opts.yaw_bearing_name, "yaw_swivel")
  expect_equal("pitch bearing", aim_opts.pitch_bearing_name, "pitch_swivel")
  expect_equal("yaw motor", aim_opts.yaw_motor_name, "yaw_motor")
  expect_equal("pitch motor", aim_opts.pitch_motor_name, "pitch_motor")
  expect_equal("no extra", aim_opts.extra, nil)
  expect_equal("no tof", aim_opts.time_of_flight_ticks, nil)
  expect_equal("fire side", fire_calls[1].side, "back")
  expect_equal("fire no axis", fire_calls[1].yaw_bearing_name, nil)
end)

run("empty optional strings omitted", function()
  local opts = base_opts()
  opts.radar_name = ""
  opts.monitor_name = ""
  opts.relay_name = ""
  opts.track_id = ""
  opts.trajectory = ""
  opts.projectile_kind = ""
  engage_simulated_bearing_turret(opts)
  expect_equal("compute radar omitted", compute_calls[1].radar_name, nil)
  expect_equal("compute monitor omitted", compute_calls[1].monitor_name, nil)
  expect_equal("compute traj omitted", compute_calls[1].trajectory, nil)
  expect_equal("compute kind omitted", compute_calls[1].projectile_kind, nil)
  expect_equal("aim radar omitted", aim_calls[1].radar_name, nil)
  expect_equal("aim monitor omitted", aim_calls[1].monitor_name, nil)
  expect_equal("aim track_id omitted", aim_calls[1].track_id, nil)
  expect_equal("fire relay omitted", fire_calls[1].relay_name, nil)
end)

run("optional keys forwarded when present", function()
  local opts = base_opts()
  opts.radar_name = "dish_1"
  opts.monitor_name = "mon_1"
  opts.relay_name = "relay_1"
  opts.track_id = "UUID-1"
  opts.trajectory = "high"
  opts.max_ticks = 100
  opts.yaw_tolerance_degrees = 2
  opts.track = { id = "UUID-1" }
  engage_simulated_bearing_turret(opts)
  expect_equal("compute radar", compute_calls[1].radar_name, "dish_1")
  expect_equal("compute monitor", compute_calls[1].monitor_name, "mon_1")
  expect_equal("aim radar", aim_calls[1].radar_name, "dish_1")
  expect_equal("aim monitor", aim_calls[1].monitor_name, "mon_1")
  expect_equal("compute trajectory", compute_calls[1].trajectory, "high")
  expect_equal("compute max_ticks", compute_calls[1].max_ticks, 100)
  expect_equal("compute track id", compute_calls[1].track.id, "UUID-1")
  expect_equal("aim track_id", aim_calls[1].track_id, "UUID-1")
  expect_equal("aim tolerance", aim_calls[1].yaw_tolerance_degrees, 2)
  expect_equal("fire relay", fire_calls[1].relay_name, "relay_1")
end)

run("parent table is not passed through", function()
  local opts = base_opts()
  opts.marker = nil
  engage_simulated_bearing_turret(opts)
  expect_equal("compute is not parent", compute_calls[1] == opts, false)
  expect_equal("aim is not parent", aim_calls[1] == opts, false)
  expect_equal("fire is not parent", fire_calls[1] == opts, false)
end)

expect_error("compute non-table", function()
  child_files["compute_ballistic_aim.lua"].compute_ballistic_aim = function()
    return 3
  end
  engage_simulated_bearing_turret(base_opts())
end, "compute_ballistic_aim returned number, expected table")

expect_error("compute empty table", function()
  child_files["compute_ballistic_aim.lua"].compute_ballistic_aim = function()
    return {}
  end
  engage_simulated_bearing_turret(base_opts())
end, "compute_ballistic_aim returned an empty solution")

expect_error("aim non-table", function()
  child_files["aim_turret_at_target.lua"].aim_turret_at_target = function()
    return true
  end
  engage_simulated_bearing_turret(base_opts())
end, "aim_turret_at_target returned boolean, expected table")

expect_error("aim on_target missing", function()
  child_files["aim_turret_at_target.lua"].aim_turret_at_target = function()
    return {}
  end
  engage_simulated_bearing_turret(base_opts())
end, "aim_turret_at_target on_target returned nil, expected boolean")

expect_error("aim on_target coerced", function()
  child_files["aim_turret_at_target.lua"].aim_turret_at_target = function()
    return { on_target = 1 }
  end
  engage_simulated_bearing_turret(base_opts())
end, "aim_turret_at_target on_target returned number, expected boolean")

run("compute throw is re-raised", function()
  child_files["compute_ballistic_aim.lua"].compute_ballistic_aim = function()
    error("Compute Ballistic Aim: no selected pose", 0)
  end
  local ok, err = pcall(engage_simulated_bearing_turret, base_opts())
  expect_equal("failed", ok, false)
  expect_equal("child message", err, "Compute Ballistic Aim: no selected pose")
  local wrapped = type(err) == "string" and
    string.find(err, "Engage Simulated Bearing Turret", 1, true) ~= nil
  expect_equal("not wrapped", wrapped, false)
  expect_equal("no aim", #aim_calls, 0)
  expect_equal("no fire", #fire_calls, 0)
end)

run("aim throw is re-raised", function()
  child_files["aim_turret_at_target.lua"].aim_turret_at_target = function()
    error("Aim Turret At Target: no radar target this tick", 0)
  end
  local ok, err = pcall(engage_simulated_bearing_turret, base_opts())
  expect_equal("failed", ok, false)
  expect_equal(
    "child message",
    err,
    "Aim Turret At Target: no radar target this tick"
  )
  expect_equal("no fire", #fire_calls, 0)
end)

run("fire throw is re-raised", function()
  child_files["fire_rotating_barrel.lua"].fire_rotating_barrel = function()
    error("Fire Rotating Barrel: side is required", 0)
  end
  local ok, err = pcall(engage_simulated_bearing_turret, base_opts())
  expect_equal("failed", ok, false)
  expect_equal("child message", err, "Fire Rotating Barrel: side is required")
end)

run("compute extra returns discarded", function()
  child_files["compute_ballistic_aim.lua"].compute_ballistic_aim = function()
    return { yaw_degrees = 1, pitch_degrees = 2 }, { leaked = true }
  end
  local result = engage_simulated_bearing_turret(base_opts())
  expect_equal("fired", result.fired, true)
  expect_equal("aim yaw", aim_calls[1].yaw_degrees, 1)
end)

run("fire extra returns discarded", function()
  child_files["fire_rotating_barrel.lua"].fire_rotating_barrel = function()
    return "pulse"
  end
  local result = engage_simulated_bearing_turret(base_opts())
  expect_equal("fired true anyway", result.fired, true)
end)

run("does not sleep", function()
  engage_simulated_bearing_turret(base_opts())
  expect_equal("sleep_count", sleep_count, 0)
end)

run("missing degrees still call aim", function()
  child_files["compute_ballistic_aim.lua"].compute_ballistic_aim = function()
    return { impact_x = 1 }
  end
  engage_simulated_bearing_turret(base_opts())
  expect_equal("aim called", #aim_calls, 1)
  expect_equal("no yaw_degrees", aim_calls[1].yaw_degrees, nil)
  expect_equal("rpm still copied", aim_calls[1].yaw_rpm, 16)
end)

_G.dofile = original_dofile

if failures > 0 then
  io.stderr:write(tostring(failures) .. " failed, " .. tostring(passes) ..
    " passed\n")
  os.exit(1)
end

io.write(tostring(passes) .. " passed\n")
