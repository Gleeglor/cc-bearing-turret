local bearing_turret = dofile("set_electric_motor_speed.lua")

local function set_electric_motor_speed(...)
  return bearing_turret.set_electric_motor_speed(...)
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

local function motor_wrap(speed, hooks)
  hooks = hooks or {}
  local generated_speed = speed
  if hooks.generated_speed ~= nil then
    generated_speed = hooks.generated_speed
  end
  local set_count = 0
  local last_rpm = nil
  local wrap = {
    getSpeed = function()
      if hooks.getSpeed then
        return hooks.getSpeed()
      end
      return speed
    end,
    setSpeed = function(rpm)
      set_count = set_count + 1
      last_rpm = rpm
      if hooks.setSpeed then
        return hooks.setSpeed(rpm)
      end
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
  wrap._generated_speed = function()
    return generated_speed
  end
  return wrap
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

local function run(name, fn)
  reset_bus()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

run("discover one motor writes", function()
  local motor = motor_wrap(0)
  attach("yaw_motor", "electric_motor", motor)
  local first, second = set_electric_motor_speed({ rpm = 32 })
  expect_equal("no first return", first, nil)
  expect_equal("no second return", second, nil)
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("wrote 32", motor._last_rpm(), 32)
end)

run("setSpeed true is discarded", function()
  local motor = motor_wrap(0, {
    setSpeed = function()
      return true
    end,
  })
  attach("yaw_motor", "electric_motor", motor)
  local return_count = select("#", set_electric_motor_speed({ rpm = 32 }))
  expect_equal("write success return count", return_count, 0)
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("wrote 32", motor._last_rpm(), 32)
end)

run("skip when getSpeed equals rpm", function()
  local motor = motor_wrap(32)
  attach("yaw_motor", "electric_motor", motor)
  local return_count = select("#", set_electric_motor_speed({ rpm = 32 }))
  expect_equal("skip success return count", return_count, 0)
  expect_equal("setSpeed skipped", motor._set_count(), 0)
end)

run("float mismatch still writes", function()
  local current = 1
  local rpm = 1 + 2^-24
  local motor = motor_wrap(current)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = rpm })
  expect_equal("not lua equal", current == rpm, false)
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("wrote original rpm", motor._last_rpm(), rpm)
end)

run("empty string name discovers", function()
  local motor = motor_wrap(0)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 8, motor_name = "" })
  expect_equal("discovered write", motor._set_count(), 1)
end)

run("named motor among two", function()
  local yaw = motor_wrap(0)
  local pitch = motor_wrap(0)
  attach("yaw_motor", "electric_motor", yaw)
  attach("pitch_motor", "electric_motor", pitch)
  set_electric_motor_speed({ rpm = 16, motor_name = "pitch_motor" })
  expect_equal("yaw untouched", yaw._set_count(), 0)
  expect_equal("pitch wrote", pitch._set_count(), 1)
  expect_equal("pitch rpm", pitch._last_rpm(), 16)
end)

run("rpm zero writes", function()
  local motor = motor_wrap(12)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 0 })
  expect_equal("wrote zero", motor._last_rpm(), 0)
  expect_equal("setSpeed once", motor._set_count(), 1)
end)

run("negative rpm writes", function()
  local motor = motor_wrap(0)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = -40 })
  expect_equal("wrote negative", motor._last_rpm(), -40)
end)

run("out of range always writes", function()
  local motor = motor_wrap(256)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 999 })
  expect_equal("out of range wrote", motor._set_count(), 1)
  expect_equal("original rpm", motor._last_rpm(), 999)
end)

run("pending tick same request writes again", function()
  local motor = motor_wrap(0)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 32 })
  set_electric_motor_speed({ rpm = 32 })
  expect_equal("two writes before apply", motor._set_count(), 2)
end)

run("stopped shaft still skips equal command", function()
  local motor = motor_wrap(32, { generated_speed = 0 })
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 32 })
  expect_equal("generated stays 0", motor._generated_speed(), 0)
  expect_equal("setSpeed skipped", motor._set_count(), 0)
end)

run("redstone POWERED motor still skips equal command", function()
  local motor = motor_wrap(32)
  motor.POWERED = true
  attach("yaw_motor", "electric_motor", motor)
  local return_count = select("#", set_electric_motor_speed({ rpm = 32 }))
  expect_equal("POWERED skip return count", return_count, 0)
  expect_equal("setSpeed skipped", motor._set_count(), 0)
end)

run("redstone POWERED motor still writes unequal command", function()
  local motor = motor_wrap(32)
  motor.POWERED = true
  attach("yaw_motor", "electric_motor", motor)
  local return_count = select("#", set_electric_motor_speed({ rpm = 40 }))
  expect_equal("POWERED write return count", return_count, 0)
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("wrote 40", motor._last_rpm(), 40)
end)

run("unpowered motor still skips equal command", function()
  local motor = motor_wrap(32)
  motor.energy = 0
  motor.active = false
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 32 })
  expect_equal("skip while unpowered", motor._set_count(), 0)
end)

run("unpowered motor still writes", function()
  local motor = motor_wrap(0)
  motor.energy = 0
  motor.active = false
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 32 })
  expect_equal("wrote while unpowered", motor._set_count(), 1)
  expect_equal("wrote rpm", motor._last_rpm(), 32)
end)

run("does not call stop rotate translate", function()
  local motor = motor_wrap(1)
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 2 })
end)

run("does not re-read getSpeed after setSpeed", function()
  local reads = 0
  local motor = motor_wrap(0, {
    getSpeed = function()
      reads = reads + 1
      return 0
    end,
  })
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 5 })
  expect_equal("one getSpeed", reads, 1)
  expect_equal("one setSpeed", motor._set_count(), 1)
end)

run("discover among other types", function()
  local motor = motor_wrap(0)
  attach("yaw", "swivel_bearing", {})
  attach("yaw_motor", "electric_motor", motor)
  set_electric_motor_speed({ rpm = 4 })
  expect_equal("found motor", motor._set_count(), 1)
end)

expect_error("zero arguments", function()
  set_electric_motor_speed()
end, "expected exactly one argument, got 0")

expect_error("extra arguments", function()
  set_electric_motor_speed({ rpm = 1 }, {})
end, "expected exactly one argument, got 2")

expect_error("nil opts", function()
  set_electric_motor_speed(nil)
end, "inputs must be a table, got nil")

expect_error("positional rpm", function()
  set_electric_motor_speed(32)
end, "inputs must be a table, got number")

expect_error("opts wrap table", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0))
  local wrapped = bus.wraps.yaw_motor
  set_electric_motor_speed(wrapped)
end, "unknown input '")

expect_error("unknown key", function()
  set_electric_motor_speed({ rpm = 1, name = "yaw" })
end, "unknown input 'name'")

expect_error("array index key", function()
  set_electric_motor_speed({ 32 })
end, "unknown input '1'")

expect_error("motor_name number", function()
  set_electric_motor_speed({ rpm = 1, motor_name = 1 })
end, "motor_name must be a string or nil, got number")

expect_error("rpm missing", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0))
  set_electric_motor_speed({})
end, "rpm is required")

expect_error("rpm string", function()
  set_electric_motor_speed({ rpm = "32" })
end, "rpm must be a number, got string")

expect_error("rpm nan", function()
  set_electric_motor_speed({ rpm = 0 / 0 })
end, "rpm must be a finite number, got nan")

expect_error("rpm inf", function()
  set_electric_motor_speed({ rpm = math.huge })
end, "rpm must be a finite number, got inf")

expect_error("rpm negative inf", function()
  set_electric_motor_speed({ rpm = -math.huge })
end, "rpm must be a finite number, got inf")

expect_error("no motor", function()
  attach("yaw", "swivel_bearing", {})
  set_electric_motor_speed({ rpm = 1 })
end, "no electric_motor attached")

expect_error("two motors no name", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0))
  attach("pitch_motor", "electric_motor", motor_wrap(0))
  set_electric_motor_speed({ rpm = 1 })
end, "2 electric_motor attached, pass motor_name")

expect_error("named not attached", function()
  set_electric_motor_speed({ rpm = 1, motor_name = "yaw_motor" })
end, "named motor 'yaw_motor' is not attached")

expect_error("named wrong type", function()
  attach("yaw", "swivel_bearing", {})
  set_electric_motor_speed({ rpm = 1, motor_name = "yaw" })
end, "named motor 'yaw' is type 'swivel_bearing', expected electric_motor")

expect_error("named servo_motor", function()
  attach("servo", "servo_motor", {})
  set_electric_motor_speed({ rpm = 1, motor_name = "servo" })
end, "named motor 'servo' is type 'servo_motor', expected electric_motor")

expect_error("discover only servo_motor", function()
  attach("servo", "servo_motor", {})
  set_electric_motor_speed({ rpm = 1 })
end, "no electric_motor attached")

expect_error("getSpeed throw", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0, {
    getSpeed = function()
      error("boom", 0)
    end,
  }))
  set_electric_motor_speed({ rpm = 1 })
end, "getSpeed threw on motor 'yaw_motor': boom")

expect_error("getSpeed non-number", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0, {
    getSpeed = function()
      return "fast"
    end,
  }))
  set_electric_motor_speed({ rpm = 1 })
end, "getSpeed on motor 'yaw_motor' returned string, expected number")

expect_error("getSpeed nan", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0, {
    getSpeed = function()
      return 0 / 0
    end,
  }))
  set_electric_motor_speed({ rpm = 1 })
end, "getSpeed on motor 'yaw_motor' returned nan")

expect_error("getSpeed inf", function()
  attach("yaw_motor", "electric_motor", motor_wrap(0, {
    getSpeed = function()
      return math.huge
    end,
  }))
  set_electric_motor_speed({ rpm = 1 })
end, "getSpeed on motor 'yaw_motor' returned inf")

run("setSpeed throw does not sleep and retry", function()
  local sleep_count = 0
  local previous_sleep = _G.sleep
  local previous_os_sleep = os.sleep
  local function record_sleep()
    sleep_count = sleep_count + 1
    error("sleep must not be called", 0)
  end
  _G.sleep = record_sleep
  os.sleep = record_sleep
  local motor = motor_wrap(0, {
    setSpeed = function()
      error(
        "Speed is set too many times per second (Anti Spam).",
        0
      )
    end,
  })
  attach("yaw_motor", "electric_motor", motor)
  local ok, err = pcall(function()
    set_electric_motor_speed({ rpm = 1 })
  end)
  _G.sleep = previous_sleep
  os.sleep = previous_os_sleep
  local needle = "setSpeed threw on motor 'yaw_motor': " ..
    "Speed is set too many times per second (Anti Spam)."
  if ok then
    error("expected error containing " .. needle, 0)
  end
  if type(err) ~= "string" or
      string.find(err, needle, 1, true) == nil then
    error(
      "expected " .. needle .. ", got " .. tostring(err),
      0
    )
  end
  expect_equal("setSpeed once", motor._set_count(), 1)
  expect_equal("no sleep", sleep_count, 0)
end)

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
