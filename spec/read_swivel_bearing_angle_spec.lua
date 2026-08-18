local bearing_turret = dofile("read_swivel_bearing_angle.lua")

local function read_swivel_bearing_angle(...)
  return bearing_turret.read_swivel_bearing_angle(...)
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

local function bearing_wrap(angle_or_fn)
  if type(angle_or_fn) == "function" then
    return { getTargetAngle = angle_or_fn }
  end
  return {
    getTargetAngle = function()
      return angle_or_fn
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
    getSpeed = function()
      error("getSpeed must not be called", 0)
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

local function run(name, fn)
  reset_bus()
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

run("discover one bearing", function()
  attach("yaw", "swivel_bearing", bearing_wrap(37))
  local angle = read_swivel_bearing_angle()
  expect_equal("degrees 37", angle, 37)
end)

run("nil opts discovers", function()
  attach("yaw", "swivel_bearing", bearing_wrap(12.5))
  local angle = read_swivel_bearing_angle(nil)
  expect_equal("degrees 12.5", angle, 12.5)
end)

run("empty table discovers", function()
  attach("yaw", "swivel_bearing", bearing_wrap(0))
  local angle = read_swivel_bearing_angle({})
  expect_equal("zero", angle, 0)
end)

run("empty string name discovers", function()
  attach("yaw", "swivel_bearing", bearing_wrap(4))
  local angle = read_swivel_bearing_angle({ bearing_name = "" })
  expect_equal("empty name discover", angle, 4)
end)

run("named bearing", function()
  attach("yaw", "swivel_bearing", bearing_wrap(10))
  attach("pitch", "swivel_bearing", bearing_wrap(80))
  local angle = read_swivel_bearing_angle({ bearing_name = "pitch" })
  expect_equal("named pitch", angle, 80)
end)

run("negative remainder", function()
  attach("yaw", "swivel_bearing", bearing_wrap(-12))
  local angle = read_swivel_bearing_angle()
  expect_equal("negative kept", angle, -12)
end)

run("discover one among other types", function()
  attach("motor_1", "electric_motor", {})
  attach("yaw", "swivel_bearing", bearing_wrap(22))
  attach("radar_1", "create_radar:radar", {})
  local angle = read_swivel_bearing_angle()
  expect_equal("discover among others", angle, 22)
end)

run("exactly one return", function()
  attach("yaw", "swivel_bearing", bearing_wrap(9))
  local first, second = read_swivel_bearing_angle()
  expect_equal("first is 9", first, 9)
  expect_equal("no second return", second, nil)
end)

run("does not call rad assemble lock or speed", function()
  attach("yaw", "swivel_bearing", bearing_wrap(1))
  read_swivel_bearing_angle()
end)

run("does not call peripheral.find", function()
  local find_called = false
  peripheral.find = function()
    find_called = true
  end
  attach("yaw", "swivel_bearing", bearing_wrap(1))
  read_swivel_bearing_angle()
  expect_equal("find not called", find_called, false)
end)

run("does not negate stored value", function()
  attach("down", "swivel_bearing", bearing_wrap(-45))
  local angle = read_swivel_bearing_angle()
  expect_equal("no second FACING flip", angle, -45)
end)

expect_error("extra arguments", function()
  attach("yaw", "swivel_bearing", bearing_wrap(1))
  read_swivel_bearing_angle({}, {})
end, "expected at most one argument, got 2")

expect_error("opts wrap table", function()
  attach("yaw", "swivel_bearing", bearing_wrap(1))
  local wrapped = bus.wraps.yaw
  read_swivel_bearing_angle(wrapped)
end, "unknown input '")

expect_error("opts string", function()
  read_swivel_bearing_angle("yaw")
end, "inputs must be a table or nil, got string")

expect_error("unknown key", function()
  read_swivel_bearing_angle({ name = "yaw" })
end, "unknown input 'name'")

expect_error("array index key", function()
  read_swivel_bearing_angle({ "yaw" })
end, "unknown input '1'")

expect_error("bearing_name number", function()
  read_swivel_bearing_angle({ bearing_name = 1 })
end, "bearing_name must be a string or nil, got number")

expect_error("no swivel", function()
  attach("motor_1", "electric_motor", {})
  read_swivel_bearing_angle()
end, "no swivel_bearing attached")

expect_error("two swivels no name", function()
  attach("yaw", "swivel_bearing", bearing_wrap(1))
  attach("pitch", "swivel_bearing", bearing_wrap(2))
  read_swivel_bearing_angle()
end, "2 swivel_bearing attached, pass bearing_name")

expect_error("named not attached", function()
  read_swivel_bearing_angle({ bearing_name = "yaw" })
end, "named bearing 'yaw' is not attached")

expect_error("named wrong type", function()
  attach("motor_1", "electric_motor", {})
  read_swivel_bearing_angle({ bearing_name = "motor_1" })
end, "named bearing 'motor_1' is type 'electric_motor', expected swivel_bearing")

expect_error("getter throw", function()
  attach("yaw", "swivel_bearing", bearing_wrap(function()
    error("boom", 0)
  end))
  read_swivel_bearing_angle()
end, "getTargetAngle threw on bearing 'yaw': boom")

expect_error("non-number", function()
  attach("yaw", "swivel_bearing", bearing_wrap("37"))
  read_swivel_bearing_angle()
end, "getTargetAngle on bearing 'yaw' returned string, expected number")

expect_error("nil return", function()
  attach("yaw", "swivel_bearing", bearing_wrap(function()
    return nil
  end))
  read_swivel_bearing_angle()
end, "getTargetAngle on bearing 'yaw' returned nil, expected number")

expect_error("nan", function()
  attach("yaw", "swivel_bearing", bearing_wrap(0 / 0))
  read_swivel_bearing_angle()
end, "getTargetAngle on bearing 'yaw' returned nan")

expect_error("inf", function()
  attach("yaw", "swivel_bearing", bearing_wrap(math.huge))
  read_swivel_bearing_angle()
end, "getTargetAngle on bearing 'yaw' returned inf")

expect_error("negative inf", function()
  attach("yaw", "swivel_bearing", bearing_wrap(-math.huge))
  read_swivel_bearing_angle()
end, "getTargetAngle on bearing 'yaw' returned inf")

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
