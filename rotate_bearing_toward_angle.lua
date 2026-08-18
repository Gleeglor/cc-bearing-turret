local prefix = "Rotate Bearing Toward Angle: "

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
    if key ~= "target_degrees" and key ~= "rpm" and
        key ~= "bearing_name" and key ~= "motor_name" and
        key ~= "tolerance_degrees" then
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

local function require_finite(value, field_name)
  if value == nil then
    fail_loud(prefix .. field_name .. " is required")
  end
  if type(value) ~= "number" then
    fail_loud(
      prefix .. field_name .. " must be a number, got " ..
        diagnostic_type(value)
    )
  end
  if value ~= value then
    fail_loud(prefix .. field_name .. " must be a finite number, got nan")
  end
  if value == math.huge or value == -math.huge then
    fail_loud(prefix .. field_name .. " must be a finite number, got inf")
  end
  return value
end

local function require_tolerance(value)
  if value == nil then
    return 1
  end
  if type(value) ~= "number" then
    fail_loud(
      prefix .. "tolerance_degrees must be a number or nil, got " ..
        diagnostic_type(value)
    )
  end
  if value ~= value then
    fail_loud(prefix .. "tolerance_degrees must be a finite number, got nan")
  end
  if value == math.huge or value == -math.huge then
    fail_loud(prefix .. "tolerance_degrees must be a finite number, got inf")
  end
  if value < 0 then
    fail_loud(
      prefix .. "tolerance_degrees must be >= 0, got " .. tostring(value)
    )
  end
  return value
end

local function load_child(name, command)
  local loaded = package.loaded[name]
  if type(loaded) ~= "table" then
    local ok, result = pcall(dofile, name .. ".lua")
    if not ok then
      fail_loud(
        prefix .. "failed to load '" .. name .. "': " .. tostring(result)
      )
    end
    if type(result) ~= "table" then
      fail_loud(
        prefix .. "module '" .. name .. "' must be a table, got " ..
          diagnostic_type(result)
      )
    end
    package.loaded[name] = result
    loaded = result
  end
  if type(loaded[command]) ~= "function" then
    fail_loud(
      prefix .. "module '" .. name .. "' has no function " .. command
    )
  end
  return loaded
end

local function shortest_error(target_degrees, current)
  local delta = (target_degrees - current) % 360
  if delta > 180 then
    delta = delta - 360
  end
  return delta
end

local function write_rpm_for(error_degrees, rpm, tolerance)
  if math.abs(error_degrees) <= tolerance then
    return 0
  end
  if error_degrees > tolerance then
    return rpm
  end
  return -rpm
end

local function rotate_bearing_toward_angle(...)
  local opts = parse_opts(...)
  local target_degrees = require_finite(opts.target_degrees, "target_degrees")
  local rpm = require_finite(opts.rpm, "rpm")
  local bearing_name = optional_name(opts.bearing_name, "bearing_name")
  local motor_name = optional_name(opts.motor_name, "motor_name")
  local tolerance = require_tolerance(opts.tolerance_degrees)
  local read_mod = load_child(
    "read_swivel_bearing_angle",
    "read_swivel_bearing_angle"
  )
  local set_mod = load_child(
    "set_electric_motor_speed",
    "set_electric_motor_speed"
  )
  local read_opts = {}
  if bearing_name ~= nil then
    read_opts.bearing_name = bearing_name
  end
  local current = read_mod.read_swivel_bearing_angle(read_opts)
  local error_degrees = shortest_error(target_degrees, current)
  local write_rpm = write_rpm_for(error_degrees, rpm, tolerance)
  local write_opts = { rpm = write_rpm }
  if motor_name ~= nil then
    write_opts.motor_name = motor_name
  end
  set_mod.set_electric_motor_speed(write_opts)
  return error_degrees
end

local bearing_turret = {
  rotate_bearing_toward_angle = rotate_bearing_toward_angle,
}

return bearing_turret
