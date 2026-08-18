local motor_type = "electric_motor"
local prefix = "Set Electric Motor Speed: "

local function fail_loud(message)
  error(message, 0)
end

local function diagnostic_type(value)
  return type(value)
end

local function parse_opts(...)
  local argument_count = select("#", ...)
  if argument_count ~= 1 then
    fail_loud(
      prefix .. "expected exactly one argument, got " ..
        tostring(argument_count)
    )
  end
  local opts = ...
  if type(opts) ~= "table" then
    fail_loud(
      prefix .. "inputs must be a table, got " .. diagnostic_type(opts)
    )
  end
  for key in pairs(opts) do
    if key ~= "rpm" and key ~= "motor_name" then
      fail_loud(prefix .. "unknown input '" .. tostring(key) .. "'")
    end
  end
  return opts
end

local function optional_name(value, field_name)
  if value == nil then
    return nil
  end
  if type(value) ~= "string" then
    fail_loud(
      prefix .. field_name .. " must be a string or nil, got " ..
        diagnostic_type(value)
    )
  end
  if value == "" then
    return nil
  end
  return value
end

local function require_finite_rpm(rpm)
  if rpm == nil then
    fail_loud(prefix .. "rpm is required")
  end
  if type(rpm) ~= "number" then
    fail_loud(
      prefix .. "rpm must be a number, got " .. diagnostic_type(rpm)
    )
  end
  if rpm ~= rpm then
    fail_loud(prefix .. "rpm must be a finite number, got nan")
  end
  if rpm == math.huge or rpm == -math.huge then
    fail_loud(prefix .. "rpm must be a finite number, got inf")
  end
  return rpm
end

local function attached_names_of_type(peripheral_type)
  local names = {}
  local attached = peripheral.getNames()
  local index = 1
  while index <= #attached do
    local peripheral_name = attached[index]
    if peripheral.getType(peripheral_name) == peripheral_type then
      names[#names + 1] = peripheral_name
    end
    index = index + 1
  end
  return names
end

local function resolve_motor(motor_name)
  if motor_name ~= nil then
    local wrapped = peripheral.wrap(motor_name)
    if wrapped == nil then
      fail_loud(
        prefix .. "named motor '" .. motor_name .. "' is not attached"
      )
    end
    local peripheral_type = peripheral.getType(motor_name)
    if peripheral_type ~= motor_type then
      local type_text = peripheral_type
      if type_text == nil then
        type_text = "nil"
      end
      fail_loud(
        prefix .. "named motor '" .. motor_name .. "' is type '" ..
          tostring(type_text) .. "', expected electric_motor"
      )
    end
    return wrapped, motor_name
  end
  local names = attached_names_of_type(motor_type)
  if #names == 0 then
    fail_loud(prefix .. "no electric_motor attached")
  end
  if #names > 1 then
    fail_loud(
      prefix .. tostring(#names) ..
        " electric_motor attached, pass motor_name"
    )
  end
  return peripheral.wrap(names[1]), names[1]
end

local function require_finite_speed(value, motor_name)
  if type(value) ~= "number" then
    fail_loud(
      prefix .. "getSpeed on motor '" .. motor_name .. "' returned " ..
        diagnostic_type(value) .. ", expected number"
    )
  end
  if value ~= value then
    fail_loud(
      prefix .. "getSpeed on motor '" .. motor_name .. "' returned nan"
    )
  end
  if value == math.huge or value == -math.huge then
    fail_loud(
      prefix .. "getSpeed on motor '" .. motor_name .. "' returned inf"
    )
  end
  return value
end

local function set_electric_motor_speed(...)
  local opts = parse_opts(...)
  local rpm = require_finite_rpm(opts.rpm)
  local motor_name = optional_name(opts.motor_name, "motor_name")
  local wrapped, resolved_name = resolve_motor(motor_name)
  local ok, value_or_error = pcall(wrapped.getSpeed)
  if not ok then
    fail_loud(
      prefix .. "getSpeed threw on motor '" .. resolved_name .. "': " ..
        tostring(value_or_error)
    )
  end
  local current = require_finite_speed(value_or_error, resolved_name)
  if current == rpm then
    return
  end
  ok, value_or_error = pcall(wrapped.setSpeed, rpm)
  if not ok then
    fail_loud(
      prefix .. "setSpeed threw on motor '" .. resolved_name .. "': " ..
        tostring(value_or_error)
    )
  end
end

local bearing_turret = {
  set_electric_motor_speed = set_electric_motor_speed,
}

return bearing_turret
