local bearing_turret = dofile("rotate_bearing_toward_angle.lua")

local function rotate_bearing_toward_angle(...)
  return bearing_turret.rotate_bearing_toward_angle(...)
end

local failures = 0
local passes = 0

local original_dofile = dofile
local original_sleep = _G.sleep
local original_os_sleep = os.sleep

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

local last_read_opts = nil
local last_write_opts = nil
local read_calls = 0
local write_calls = 0

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

local function reset()
  bus.names = {}
  bus.types = {}
  bus.wraps = {}
  last_read_opts = nil
  last_write_opts = nil
  read_calls = 0
  write_calls = 0
  package.loaded.read_swivel_bearing_angle = nil
  package.loaded.set_electric_motor_speed = nil
  _G.dofile = original_dofile
  _G.sleep = original_sleep
  os.sleep = original_os_sleep
end

local function stub_children(read_fn, set_fn)
  package.loaded.read_swivel_bearing_angle = {
    read_swivel_bearing_angle = function(opts)
      read_calls = read_calls + 1
      last_read_opts = opts
      return read_fn(opts)
    end,
  }
  package.loaded.set_electric_motor_speed = {
    set_electric_motor_speed = function(opts)
      write_calls = write_calls + 1
      last_write_opts = opts
      if set_fn then
        return set_fn(opts)
      end
    end,
  }
end

local function attach(name, peripheral_type, wrapped)
  bus.names[#bus.names + 1] = name
  bus.types[name] = peripheral_type
  bus.wraps[name] = wrapped
end

local function bearing_wrap(angle)
  return {
    getTargetAngle = function()
      return angle
    end,
    getTargetAngleRad = function()
      error("getTargetAngleRad must not be called", 0)
    end,
    assemble = function()
      error("assemble must not be called", 0)
    end,
    disassemble = function()
      error("disassemble must not be called", 0)
    end,
    isAssembled = function()
      error("isAssembled must not be called", 0)
    end,
    setLockingMode = function()
      error("setLockingMode must not be called", 0)
    end,
  }
end

local function motor_wrap(speed)
  local set_count = 0
  local last_rpm = nil
  local wrap = {
    getSpeed = function()
      return speed
    end,
    setSpeed = function(rpm)
      set_count = set_count + 1
      last_rpm = rpm
    end,
    stop = function()
      error("stop must not be called", 0)
    end,
    rotate = function()
      error("rotate must not be called", 0)
    end,
    translate = function()
      error("translate must not be called", 0)
    end,
  }
  wrap._set_count = function()
    return set_count
  end
  wrap._last_rpm = function()
    return last_rpm
  end
  return wrap
end

local function expect_error(name, fn, needle)
  reset()
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
  reset()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

run("positive error writes rpm", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 10,
    rpm = 32,
  })
  expect_equal("error 10", err, 10)
  expect_equal("one read", read_calls, 1)
  expect_equal("one write", write_calls, 1)
  expect_equal("wrote 32", last_write_opts.rpm, 32)
  expect_equal("read empty table", next(last_read_opts), nil)
  expect_equal("write no motor name", last_write_opts.motor_name, nil)
end)

run("negative error writes negated rpm", function()
  stub_children(function()
    return 10
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 0,
    rpm = 32,
  })
  expect_equal("error -10", err, -10)
  expect_equal("wrote -32", last_write_opts.rpm, -32)
end)

run("in band leftover returned and writes 0", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 0.5,
    rpm = 32,
  })
  expect_equal("leftover 0.5", err, 0.5)
  expect_equal("wrote 0", last_write_opts.rpm, 0)
end)

run("default tolerance 1 stops at 1", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 32,
  })
  expect_equal("error 1", err, 1)
  expect_equal("wrote 0", last_write_opts.rpm, 0)
end)

run("default tolerance 1 drives 1.1", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 1.1,
    rpm = 32,
  })
  expect_equal("error 1.1", err, 1.1)
  expect_equal("wrote 32", last_write_opts.rpm, 32)
end)

run("custom tolerance", function()
  stub_children(function()
    return 0
  end)
  local inside = rotate_bearing_toward_angle({
    target_degrees = 5,
    rpm = 32,
    tolerance_degrees = 5,
  })
  expect_equal("inside leftover", inside, 5)
  expect_equal("inside wrote 0", last_write_opts.rpm, 0)
  expect_equal("inside write has no bearing_name", last_write_opts.bearing_name, nil)
  expect_equal("inside write has no tolerance", last_write_opts.tolerance_degrees, nil)
  local outside = rotate_bearing_toward_angle({
    target_degrees = 5.1,
    rpm = 32,
    tolerance_degrees = 5,
  })
  expect_equal("outside error", outside, 5.1)
  expect_equal("outside wrote 32", last_write_opts.rpm, 32)
  expect_equal("outside write has no bearing_name", last_write_opts.bearing_name, nil)
  expect_equal("outside write has no tolerance", last_write_opts.tolerance_degrees, nil)
end)

run("tolerance 0 only exact", function()
  stub_children(function()
    return 0
  end)
  local exact = rotate_bearing_toward_angle({
    target_degrees = 0,
    rpm = 32,
    tolerance_degrees = 0,
  })
  expect_equal("exact leftover", exact, 0)
  expect_equal("exact wrote 0", last_write_opts.rpm, 0)
  rotate_bearing_toward_angle({
    target_degrees = 0.01,
    rpm = 32,
    tolerance_degrees = 0,
  })
  expect_equal("tiny wrote 32", last_write_opts.rpm, 32)
end)

run("java negative remainder wrap", function()
  stub_children(function()
    return -10
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 10,
    rpm = 8,
  })
  expect_equal("short path 20", err, 20)
  expect_equal("wrote 8", last_write_opts.rpm, 8)
end)

run("180 chooses positive path", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 180,
    rpm = 4,
  })
  expect_equal("error 180", err, 180)
  expect_equal("wrote 4", last_write_opts.rpm, 4)
end)

run("181 takes negative short path", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 181,
    rpm = 4,
  })
  expect_equal("error -179", err, -179)
  expect_equal("wrote -4", last_write_opts.rpm, -4)
end)

run("does not negate child angle", function()
  stub_children(function()
    return -45
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = -45,
    rpm = 16,
  })
  expect_equal("zero error", err, 0)
  expect_equal("wrote 0", last_write_opts.rpm, 0)
end)

run("inverted polarity rpm", function()
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 10,
    rpm = -32,
  })
  expect_equal("increase write -32", last_write_opts.rpm, -32)
  rotate_bearing_toward_angle({
    target_degrees = -10,
    rpm = -32,
  })
  expect_equal("decrease write 32", last_write_opts.rpm, 32)
end)

run("rpm 0 stop only", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 40,
    rpm = 0,
  })
  expect_equal("error 40", err, 40)
  expect_equal("wrote 0", last_write_opts.rpm, 0)
end)

run("out of range rpm passed through unclamped", function()
  stub_children(function()
    return 0
  end)
  local err = rotate_bearing_toward_angle({
    target_degrees = 10,
    rpm = 999,
  })
  expect_equal("error outside band", err, 10)
  expect_equal("wrote 999", last_write_opts.rpm, 999)
end)

run("passes names to children", function()
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 3,
    rpm = 2,
    bearing_name = "yaw",
    motor_name = "yaw_motor",
    tolerance_degrees = 0,
  })
  expect_equal("bearing name", last_read_opts.bearing_name, "yaw")
  expect_equal("motor name", last_write_opts.motor_name, "yaw_motor")
  expect_equal("read has no rpm", last_read_opts.rpm, nil)
  expect_equal("read has no target_degrees", last_read_opts.target_degrees, nil)
  expect_equal("read has no tolerance_degrees", last_read_opts.tolerance_degrees, nil)
  expect_equal("write has no target", last_write_opts.target_degrees, nil)
  expect_equal("write has no bearing_name", last_write_opts.bearing_name, nil)
  expect_equal("write has no tolerance", last_write_opts.tolerance_degrees, nil)
end)

run("read opts omit target_degrees and tolerance_degrees", function()
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 3,
    rpm = 2,
    bearing_name = "yaw",
    motor_name = "yaw_motor",
    tolerance_degrees = 5,
  })
  expect_equal("read has no target_degrees", last_read_opts.target_degrees, nil)
  expect_equal("read has no tolerance_degrees", last_read_opts.tolerance_degrees, nil)
  expect_equal("read has no rpm", last_read_opts.rpm, nil)
  expect_equal("read keeps bearing_name", last_read_opts.bearing_name, "yaw")
end)

run("empty string names omitted to children", function()
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 3,
    rpm = 2,
    bearing_name = "",
    motor_name = "",
  })
  expect_equal("bearing omitted", last_read_opts.bearing_name, nil)
  expect_equal("motor omitted", last_write_opts.motor_name, nil)
end)

run("exactly one return", function()
  stub_children(function()
    return 0
  end)
  local first, second = rotate_bearing_toward_angle({
    target_degrees = 2,
    rpm = 8,
  })
  expect_equal("first 2", first, 2)
  expect_equal("no second", second, nil)
end)

run("does not sleep", function()
  local sleep_count = 0
  local function record_sleep()
    sleep_count = sleep_count + 1
    error("sleep must not be called", 0)
  end
  _G.sleep = record_sleep
  os.sleep = record_sleep
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 10,
    rpm = 8,
  })
  expect_equal("no sleep", sleep_count, 0)
end)

run("does not wrap peripherals", function()
  local wrap_count = 0
  local previous_wrap = peripheral.wrap
  peripheral.wrap = function(name)
    wrap_count = wrap_count + 1
    return previous_wrap(name)
  end
  stub_children(function()
    return 0
  end)
  rotate_bearing_toward_angle({
    target_degrees = 4,
    rpm = 8,
  })
  peripheral.wrap = previous_wrap
  expect_equal("no wrap", wrap_count, 0)
end)

run("envelope does not load children", function()
  local dofile_count = 0
  _G.dofile = function()
    dofile_count = dofile_count + 1
    error("dofile must not run", 0)
  end
  local ok, err = pcall(function()
    rotate_bearing_toward_angle({ rpm = 1 })
  end)
  expect_equal("envelope failed", ok, false)
  if type(err) ~= "string" or
      string.find(err, "target_degrees is required", 1, true) == nil then
    error("expected target_degrees is required, got " .. tostring(err), 0)
  end
  expect_equal("no dofile", dofile_count, 0)
end)

run("child read error propagates", function()
  stub_children(function()
    error("Read Swivel Bearing Angle: boom", 0)
  end)
  local ok, err = pcall(function()
    rotate_bearing_toward_angle({
      target_degrees = 1,
      rpm = 1,
    })
  end)
  expect_equal("failed", ok, false)
  if type(err) ~= "string" or
      string.find(err, "Read Swivel Bearing Angle: boom", 1, true) == nil then
    error("expected child message, got " .. tostring(err), 0)
  end
  if string.find(err, "Rotate Bearing Toward Angle", 1, true) ~= nil then
    error("child message was wrapped: " .. tostring(err), 0)
  end
  expect_equal("no write", write_calls, 0)
end)

run("child write error propagates", function()
  stub_children(function()
    return 0
  end, function()
    error("Set Electric Motor Speed: boom", 0)
  end)
  local ok, err = pcall(function()
    rotate_bearing_toward_angle({
      target_degrees = 1,
      rpm = 1,
    })
  end)
  expect_equal("failed", ok, false)
  if type(err) ~= "string" or
      string.find(err, "Set Electric Motor Speed: boom", 1, true) == nil then
    error("expected child message, got " .. tostring(err), 0)
  end
  if string.find(err, "Rotate Bearing Toward Angle", 1, true) ~= nil then
    error("child message was wrapped: " .. tostring(err), 0)
  end
  expect_equal("one read", read_calls, 1)
  expect_equal("one write", write_calls, 1)
end)

run("integration through real children", function()
  local motor = motor_wrap(0)
  attach("yaw", "swivel_bearing", bearing_wrap(0))
  attach("yaw_motor", "electric_motor", motor)
  local err = rotate_bearing_toward_angle({
    target_degrees = 12,
    rpm = 24,
    bearing_name = "yaw",
    motor_name = "yaw_motor",
  })
  expect_equal("integrated error", err, 12)
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("wrote 24", motor._last_rpm(), 24)
end)

run("integration in band writes 0 through child skip-same", function()
  local motor = motor_wrap(0)
  attach("yaw", "swivel_bearing", bearing_wrap(0.5))
  attach("yaw_motor", "electric_motor", motor)
  local err = rotate_bearing_toward_angle({
    target_degrees = 0,
    rpm = 24,
    bearing_name = "yaw",
    motor_name = "yaw_motor",
  })
  local delta = (0 - 0.5) % 360
  if delta > 180 then
    delta = delta - 360
  end
  expect_equal("leftover", err, delta)
  expect_equal("skip same 0", motor._set_count(), 0)
end)

expect_error("zero arguments", function()
  rotate_bearing_toward_angle()
end, "expected exactly one argument, got 0")

expect_error("extra arguments", function()
  rotate_bearing_toward_angle({ target_degrees = 1, rpm = 1 }, {})
end, "expected exactly one argument, got 2")

expect_error("nil opts", function()
  rotate_bearing_toward_angle(nil)
end, "inputs must be a table, got nil")

expect_error("positional target", function()
  rotate_bearing_toward_angle(90)
end, "inputs must be a table, got number")

expect_error("opts wrap table", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0))
  local wrapped = bus.wraps.yaw_motor
  rotate_bearing_toward_angle(wrapped)
end, "unknown input '")

expect_error("unknown key", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    name = "yaw",
  })
end, "unknown input 'name'")

expect_error("array index key", function()
  rotate_bearing_toward_angle({ 90 })
end, "unknown input '1'")

expect_error("bearing_name number", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    bearing_name = 1,
  })
end, "bearing_name must be a string or nil, got number")

expect_error("bearing_name wrap table", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    bearing_name = bearing_wrap(0),
  })
end, "bearing_name must be a string or nil, got table")

expect_error("motor_name number", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    motor_name = 1,
  })
end, "motor_name must be a string or nil, got number")

expect_error("motor_name wrap table", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0))
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    motor_name = bus.wraps.yaw_motor,
  })
end, "Rotate Bearing Toward Angle: motor_name must be a string or nil, got table")

expect_error("target_degrees missing", function()
  rotate_bearing_toward_angle({ rpm = 1 })
end, "target_degrees is required")

expect_error("target_degrees string", function()
  rotate_bearing_toward_angle({ target_degrees = "90", rpm = 1 })
end, "target_degrees must be a number, got string")

expect_error("target_degrees nan", function()
  rotate_bearing_toward_angle({ target_degrees = 0 / 0, rpm = 1 })
end, "target_degrees must be a finite number, got nan")

expect_error("target_degrees inf", function()
  rotate_bearing_toward_angle({ target_degrees = math.huge, rpm = 1 })
end, "target_degrees must be a finite number, got inf")

expect_error("target_degrees negative inf", function()
  rotate_bearing_toward_angle({ target_degrees = -math.huge, rpm = 1 })
end, "target_degrees must be a finite number, got inf")

expect_error("rpm missing", function()
  rotate_bearing_toward_angle({ target_degrees = 1 })
end, "rpm is required")

expect_error("rpm string", function()
  rotate_bearing_toward_angle({ target_degrees = 1, rpm = "8" })
end, "rpm must be a number, got string")

expect_error("rpm nan", function()
  rotate_bearing_toward_angle({ target_degrees = 1, rpm = 0 / 0 })
end, "rpm must be a finite number, got nan")

expect_error("rpm inf", function()
  rotate_bearing_toward_angle({ target_degrees = 1, rpm = math.huge })
end, "rpm must be a finite number, got inf")

expect_error("rpm negative inf", function()
  rotate_bearing_toward_angle({ target_degrees = 1, rpm = -math.huge })
end, "rpm must be a finite number, got inf")

expect_error("tolerance empty string", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    tolerance_degrees = "",
  })
end, "tolerance_degrees must be a number or nil, got string")

expect_error("tolerance nan", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    tolerance_degrees = 0 / 0,
  })
end, "tolerance_degrees must be a finite number, got nan")

expect_error("tolerance inf", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    tolerance_degrees = math.huge,
  })
end, "tolerance_degrees must be a finite number, got inf")

expect_error("tolerance negative inf", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    tolerance_degrees = -math.huge,
  })
end, "tolerance_degrees must be a finite number, got inf")

expect_error("tolerance negative", function()
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
    tolerance_degrees = -1,
  })
end, "tolerance_degrees must be >= 0, got -1")

expect_error("dofile throw", function()
  _G.dofile = function()
    error("missing file", 0)
  end
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "failed to load 'read_swivel_bearing_angle': missing file")

expect_error("dofile throw set_electric_motor_speed", function()
  package.loaded.read_swivel_bearing_angle = {
    read_swivel_bearing_angle = function()
      return 0
    end,
  }
  _G.dofile = function(path)
    if path ~= "set_electric_motor_speed.lua" then
      error(
        "dofile must load set_electric_motor_speed.lua, got " ..
          tostring(path),
        0
      )
    end
    error("missing file", 0)
  end
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "failed to load 'set_electric_motor_speed': missing file")

expect_error("dofile non-table", function()
  _G.dofile = function()
    return true
  end
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "module 'read_swivel_bearing_angle' must be a table, got boolean")

run("dofile non-table does not store package.loaded", function()
  _G.dofile = function()
    return true
  end
  local ok, err = pcall(function()
    rotate_bearing_toward_angle({
      target_degrees = 1,
      rpm = 1,
    })
  end)
  expect_equal("non-table failed", ok, false)
  if type(err) ~= "string" or
      string.find(
        err,
        "module 'read_swivel_bearing_angle' must be a table, got boolean",
        1,
        true
      ) == nil then
    error("expected non-table message, got " .. tostring(err), 0)
  end
  if package.loaded.read_swivel_bearing_angle == true then
    error("package.loaded.read_swivel_bearing_angle is true", 0)
  end
  if type(package.loaded.read_swivel_bearing_angle) == "boolean" then
    error("package.loaded.read_swivel_bearing_angle is boolean", 0)
  end
end)

expect_error("set dofile non-table", function()
  package.loaded.read_swivel_bearing_angle = {
    read_swivel_bearing_angle = function()
      return 0
    end,
  }
  _G.dofile = function(path)
    if path ~= "set_electric_motor_speed.lua" then
      error(
        "dofile must load only set_electric_motor_speed.lua, got " ..
          tostring(path),
        0
      )
    end
    return true
  end
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "module 'set_electric_motor_speed' must be a table, got boolean")

expect_error("child missing function", function()
  package.loaded.read_swivel_bearing_angle = {}
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "module 'read_swivel_bearing_angle' has no function read_swivel_bearing_angle")

expect_error("set_electric_motor_speed missing function", function()
  package.loaded.read_swivel_bearing_angle = {
    read_swivel_bearing_angle = function()
      return 0
    end,
  }
  package.loaded.set_electric_motor_speed = {}
  rotate_bearing_toward_angle({
    target_degrees = 1,
    rpm = 1,
  })
end, "module 'set_electric_motor_speed' has no function set_electric_motor_speed")

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
