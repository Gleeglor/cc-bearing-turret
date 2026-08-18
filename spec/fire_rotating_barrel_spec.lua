local bearing_turret = dofile("fire_rotating_barrel.lua")

local function fire_rotating_barrel(...)
  return bearing_turret.fire_rotating_barrel(...)
end

local failures = 0
local passes = 0

local bus = {
  names = {},
  types = {},
  wraps = {},
}

local computer_writes = {}
local relay_writes = {}
local sleep_calls = {}
local pull_event_calls = 0

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

local function install_computer_redstone(hooks)
  hooks = hooks or {}
  computer_writes = {}
  _G.redstone = {
    setAnalogOutput = function(side, value)
      computer_writes[#computer_writes + 1] = {
        side = side,
        value = value,
      }
      if hooks.setAnalogOutput then
        return hooks.setAnalogOutput(side, value)
      end
    end,
    setAnalogueOutput = function()
      error("setAnalogueOutput must not be called", 0)
    end,
    setOutput = function()
      error("setOutput must not be called", 0)
    end,
    setBundledOutput = function()
      error("setBundledOutput must not be called", 0)
    end,
    getAnalogOutput = function()
      error("getAnalogOutput must not be called", 0)
    end,
  }
end

local function install_sleep(hooks)
  hooks = hooks or {}
  sleep_calls = {}
  pull_event_calls = 0
  _G.sleep = function(duration)
    sleep_calls[#sleep_calls + 1] = duration
    if hooks.sleep then
      return hooks.sleep(duration)
    end
  end
  if os.sleep then
    os.sleep = function()
      error("os.sleep must not be called", 0)
    end
  end
  os.pullEvent = function()
    pull_event_calls = pull_event_calls + 1
    error("os.pullEvent must not be called", 0)
  end
end

local function reset_world(hooks)
  reset_bus()
  install_computer_redstone(hooks)
  install_sleep(hooks)
end

local function relay_wrap(name, hooks)
  hooks = hooks or {}
  local wrap = {
    setAnalogOutput = function(side, value)
      relay_writes[#relay_writes + 1] = {
        name = name,
        side = side,
        value = value,
      }
      if hooks.setAnalogOutput then
        return hooks.setAnalogOutput(side, value)
      end
    end,
    setAnalogueOutput = function()
      error("setAnalogueOutput must not be called", 0)
    end,
    setOutput = function()
      error("setOutput must not be called", 0)
    end,
    setBundledOutput = function()
      error("setBundledOutput must not be called", 0)
    end,
    setSpeed = function()
      error("setSpeed must not be called", 0)
    end,
  }
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
  reset_world()
  relay_writes = {}
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
  reset_world()
  relay_writes = {}
  local ok, err = pcall(fn)
  if not ok then
    fail(name .. ": " .. tostring(err))
    return
  end
  pass(name)
end

run("computer pulse 1 sleep 0", function()
  local first, second = fire_rotating_barrel({ side = "back" })
  expect_equal("no first return", first, nil)
  expect_equal("no second return", second, nil)
  expect_equal("two analog writes", #computer_writes, 2)
  expect_equal("on side", computer_writes[1].side, "back")
  expect_equal("on value", computer_writes[1].value, 1)
  expect_equal("off side", computer_writes[2].side, "back")
  expect_equal("off value", computer_writes[2].value, 0)
  expect_equal("one sleep", #sleep_calls, 1)
  expect_equal("sleep 0.1", sleep_calls[1], 0.1)
  expect_equal("no relay writes", #relay_writes, 0)
end)

run("setAnalogOutput true is discarded", function()
  install_computer_redstone({
    setAnalogOutput = function()
      return true
    end,
  })
  local return_count = select("#", fire_rotating_barrel({ side = "top" }))
  expect_equal("success return count", return_count, 0)
  expect_equal("two analog writes", #computer_writes, 2)
end)

run("already high still pulses", function()
  fire_rotating_barrel({ side = "left" })
  expect_equal("on is 1 not skip", computer_writes[1].value, 1)
  expect_equal("off is 0", computer_writes[2].value, 0)
end)

run("empty string relay uses computer", function()
  attach("fire_relay", "redstone_relay", relay_wrap("fire_relay"))
  fire_rotating_barrel({ side = "front", relay_name = "" })
  expect_equal("computer wrote", #computer_writes, 2)
  expect_equal("relay unused", #relay_writes, 0)
end)

run("named relay among two", function()
  local yaw = relay_wrap("yaw_relay")
  local fire = relay_wrap("fire_relay")
  attach("yaw_relay", "redstone_relay", yaw)
  attach("fire_relay", "redstone_relay", fire)
  fire_rotating_barrel({
    side = "right",
    relay_name = "fire_relay",
  })
  expect_equal("computer unused", #computer_writes, 0)
  expect_equal("two relay writes", #relay_writes, 2)
  expect_equal("relay name", relay_writes[1].name, "fire_relay")
  expect_equal("on value", relay_writes[1].value, 1)
  expect_equal("off value", relay_writes[2].value, 0)
  expect_equal("side", relay_writes[1].side, "right")
  expect_equal("one sleep", #sleep_calls, 1)
end)

run("two relays no name uses computer", function()
  attach("a", "redstone_relay", relay_wrap("a"))
  attach("b", "redstone_relay", relay_wrap("b"))
  fire_rotating_barrel({ side = "bottom" })
  expect_equal("computer wrote", #computer_writes, 2)
  expect_equal("relays unused", #relay_writes, 0)
end)

run("legal sides", function()
  local sides = { "top", "bottom", "left", "right", "front", "back" }
  local index = 1
  while index <= #sides do
    reset_world()
    relay_writes = {}
    fire_rotating_barrel({ side = sides[index] })
    expect_equal(sides[index] .. " on side", computer_writes[1].side, sides[index])
    expect_equal(sides[index] .. " writes", #computer_writes, 2)
    index = index + 1
  end
end)

run("does not call forbidden redstone verbs", function()
  fire_rotating_barrel({ side = "back" })
  expect_equal("no pullEvent", pull_event_calls, 0)
end)

run("sleep throw still writes off", function()
  install_sleep({
    sleep = function()
      error("sleepy", 0)
    end,
  })
  local ok, err = pcall(function()
    fire_rotating_barrel({ side = "back" })
  end)
  local needle = "Fire Rotating Barrel: sleep threw: sleepy"
  if ok then
    error("expected error containing " .. needle, 0)
  end
  if type(err) ~= "string" or
      string.find(err, needle, 1, true) == nil then
    error("expected " .. needle .. ", got " .. tostring(err), 0)
  end
  expect_equal("on then off", #computer_writes, 2)
  expect_equal("off is 0", computer_writes[2].value, 0)
  expect_equal("slept once", #sleep_calls, 1)
end)

run("off throw wins over sleep throw", function()
  local writes = 0
  install_computer_redstone({
    setAnalogOutput = function(side, value)
      writes = writes + 1
      if value == 0 then
        error("off boom", 0)
      end
    end,
  })
  install_sleep({
    sleep = function()
      error("sleepy", 0)
    end,
  })
  local ok, err = pcall(function()
    fire_rotating_barrel({ side = "back" })
  end)
  local needle =
    "Fire Rotating Barrel: setAnalogOutput 0 threw on side 'back': off boom"
  if ok then
    error("expected error containing " .. needle, 0)
  end
  if type(err) ~= "string" or
      string.find(err, needle, 1, true) == nil then
    error("expected " .. needle .. ", got " .. tostring(err), 0)
  end
  expect_equal("on and off attempted", writes, 2)
end)

run("on throw does not sleep or write 0", function()
  install_computer_redstone({
    setAnalogOutput = function()
      error("on boom", 0)
    end,
  })
  local ok, err = pcall(function()
    fire_rotating_barrel({ side = "back" })
  end)
  local needle =
    "Fire Rotating Barrel: setAnalogOutput 1 threw on side 'back': on boom"
  if ok then
    error("expected error containing " .. needle, 0)
  end
  if type(err) ~= "string" or
      string.find(err, needle, 1, true) == nil then
    error("expected " .. needle .. ", got " .. tostring(err), 0)
  end
  expect_equal("one write attempt", #computer_writes, 1)
  expect_equal("no sleep", #sleep_calls, 0)
end)

run("relay on throw message names relay", function()
  attach("fire_relay", "redstone_relay", relay_wrap("fire_relay", {
    setAnalogOutput = function()
      error("relay boom", 0)
    end,
  }))
  local ok, err = pcall(function()
    fire_rotating_barrel({
      side = "back",
      relay_name = "fire_relay",
    })
  end)
  local needle =
    "Fire Rotating Barrel: setAnalogOutput 1 threw on relay " ..
    "'fire_relay' side 'back': relay boom"
  if ok then
    error("expected error containing " .. needle, 0)
  end
  if type(err) ~= "string" or
      string.find(err, needle, 1, true) == nil then
    error("expected " .. needle .. ", got " .. tostring(err), 0)
  end
  expect_equal("no sleep", #sleep_calls, 0)
  expect_equal("computer unused", #computer_writes, 0)
  expect_equal("one relay write", #relay_writes, 1)
  expect_equal("relay on value", relay_writes[1].value, 1)
end)

expect_error("zero arguments", function()
  fire_rotating_barrel()
end, "expected exactly one argument, got 0")

expect_error("extra arguments", function()
  fire_rotating_barrel({ side = "back" }, {})
end, "expected exactly one argument, got 2")

expect_error("nil opts", function()
  fire_rotating_barrel(nil)
end, "inputs must be a table, got nil")

expect_error("positional side", function()
  fire_rotating_barrel("back")
end, "inputs must be a table, got string")

expect_error("unknown key", function()
  fire_rotating_barrel({ side = "back", name = "fire" })
end, "unknown input 'name'")

expect_error("array index key", function()
  fire_rotating_barrel({ "back" })
end, "unknown input '1'")

expect_error("opts wrap table", function()
  attach("fire_relay", "redstone_relay", relay_wrap("fire_relay"))
  local wrapped = bus.wraps.fire_relay
  fire_rotating_barrel(wrapped)
end, "unknown input '")

expect_error("relay_name number", function()
  fire_rotating_barrel({ side = "back", relay_name = 1 })
end, "relay_name must be a string or nil, got number")

expect_error("side missing", function()
  fire_rotating_barrel({})
end, "side is required")

expect_error("side number", function()
  fire_rotating_barrel({ side = 1 })
end, "side must be a string, got number")

expect_error("side Top", function()
  fire_rotating_barrel({ side = "Top" })
end, "side must be top, bottom, left, right, front, or back, got 'Top'")

expect_error("side north", function()
  fire_rotating_barrel({ side = "north" })
end, "side must be top, bottom, left, right, front, or back, got 'north'")

expect_error("named not attached", function()
  fire_rotating_barrel({
    side = "back",
    relay_name = "fire_relay",
  })
end, "named relay 'fire_relay' is not attached")

expect_error("named wrong type", function()
  attach("yaw_motor", "electric_motor", {})
  fire_rotating_barrel({
    side = "back",
    relay_name = "yaw_motor",
  })
end, "named relay 'yaw_motor' is type 'electric_motor', expected redstone_relay")

expect_error("named cannon_mount", function()
  attach("mount", "cannon_mount", {})
  fire_rotating_barrel({
    side = "back",
    relay_name = "mount",
  })
end, "named relay 'mount' is type 'cannon_mount', expected redstone_relay")

expect_error("named cbc_cannon_mount", function()
  attach("mount", "cbc_cannon_mount", {})
  fire_rotating_barrel({
    side = "back",
    relay_name = "mount",
  })
end, "named relay 'mount' is type 'cbc_cannon_mount', expected redstone_relay")

expect_error("named cbc_fixed_cannon_mount", function()
  attach("mount", "cbc_fixed_cannon_mount", {})
  fire_rotating_barrel({
    side = "back",
    relay_name = "mount",
  })
end, "named relay 'mount' is type 'cbc_fixed_cannon_mount', expected redstone_relay")

expect_error("relay_name wrap table", function()
  attach("fire_relay", "redstone_relay", relay_wrap("fire_relay"))
  fire_rotating_barrel({
    side = "back",
    relay_name = bus.wraps.fire_relay,
  })
end, "relay_name must be a string or nil, got table")

expect_error("side leading space", function()
  fire_rotating_barrel({ side = " back" })
end, "side must be top, bottom, left, right, front, or back, got ' back'")

expect_error("side trailing space", function()
  fire_rotating_barrel({ side = "back " })
end, "side must be top, bottom, left, right, front, or back, got 'back '")

expect_error("side 1 string", function()
  fire_rotating_barrel({ side = "1" })
end, "side must be top, bottom, left, right, front, or back, got '1'")

expect_error("side empty string", function()
  fire_rotating_barrel({ side = "" })
end, "side must be top, bottom, left, right, front, or back, got ''")

expect_error("fire_power key", function()
  fire_rotating_barrel({ side = "back", fire_power = 1 })
end, "unknown input 'fire_power'")

expect_error("duration key", function()
  fire_rotating_barrel({ side = "back", duration = 0.1 })
end, "unknown input 'duration'")

expect_error("redstone missing", function()
  redstone = nil
  fire_rotating_barrel({ side = "back" })
end, "redstone API is missing")

expect_error("redstone without setter", function()
  redstone = {}
  fire_rotating_barrel({ side = "back" })
end, "redstone API is missing")

expect_error("sleep missing", function()
  sleep = nil
  fire_rotating_barrel({ side = "back" })
end, "sleep is missing")

run("sleep missing does not write analog", function()
  sleep = nil
  local ok = pcall(function()
    fire_rotating_barrel({ side = "back" })
  end)
  expect_equal("failed", ok, false)
  expect_equal("no analog", #computer_writes, 0)
end)

expect_error("off throw", function()
  install_computer_redstone({
    setAnalogOutput = function(side, value)
      if value == 0 then
        error("off boom", 0)
      end
    end,
  })
  fire_rotating_barrel({ side = "back" })
end, "setAnalogOutput 0 threw on side 'back': off boom")

expect_error("relay off throw", function()
  attach("fire_relay", "redstone_relay", relay_wrap("fire_relay", {
    setAnalogOutput = function(side, value)
      if value == 0 then
        error("off boom", 0)
      end
    end,
  }))
  fire_rotating_barrel({
    side = "back",
    relay_name = "fire_relay",
  })
end, "setAnalogOutput 0 threw on relay 'fire_relay' side 'back': off boom")

io.stdout:write(
  "passes=" .. tostring(passes) .. " failures=" .. tostring(failures) .. "\n"
)
if failures > 0 then
  os.exit(1)
end
