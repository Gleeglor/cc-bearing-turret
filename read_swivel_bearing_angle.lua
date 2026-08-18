local bearing_type = "swivel_bearing"

local function fail_loud(message)
  error(message, 0)
end

local function diagnostic_type(value)
  return type(value)
end

local function parse_opts(...)
  local argument_count = select("#", ...)
  if argument_count > 1 then
    fail_loud(
      "Read Swivel Bearing Angle: expected at most one argument, got " ..
        tostring(argument_count)
    )
  end
  local opts = ...
  if opts == nil then
    return { bearing_name = nil }
  end
  if type(opts) ~= "table" then
    fail_loud(
      "Read Swivel Bearing Angle: inputs must be a table or nil, got " ..
        diagnostic_type(opts)
    )
  end
  for key in pairs(opts) do
    if key ~= "bearing_name" then
      fail_loud(
        "Read Swivel Bearing Angle: unknown input '" .. tostring(key) .. "'"
      )
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
      "Read Swivel Bearing Angle: " .. field_name ..
        " must be a string or nil, got " .. diagnostic_type(value)
    )
  end
  if value == "" then
    return nil
  end
  return value
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

local function resolve_bearing(bearing_name)
  if bearing_name ~= nil then
    local wrapped = peripheral.wrap(bearing_name)
    if wrapped == nil then
      fail_loud(
        "Read Swivel Bearing Angle: named bearing '" ..
          bearing_name .. "' is not attached"
      )
    end
    local peripheral_type = peripheral.getType(bearing_name)
    if peripheral_type ~= bearing_type then
      local type_text = peripheral_type
      if type_text == nil then
        type_text = "nil"
      end
      fail_loud(
        "Read Swivel Bearing Angle: named bearing '" ..
          bearing_name .. "' is type '" .. tostring(type_text) ..
          "', expected swivel_bearing"
      )
    end
    return wrapped, bearing_name
  end
  local names = attached_names_of_type(bearing_type)
  if #names == 0 then
    fail_loud("Read Swivel Bearing Angle: no swivel_bearing attached")
  end
  if #names > 1 then
    fail_loud(
      "Read Swivel Bearing Angle: " .. tostring(#names) ..
        " swivel_bearing attached, pass bearing_name"
    )
  end
  return peripheral.wrap(names[1]), names[1]
end

local function read_angle(wrapped, bearing_name)
  local ok, value_or_error = pcall(wrapped.getTargetAngle)
  if not ok then
    fail_loud(
      "Read Swivel Bearing Angle: getTargetAngle threw on bearing '" ..
        bearing_name .. "': " .. tostring(value_or_error)
    )
  end
  local value = value_or_error
  if type(value) ~= "number" then
    fail_loud(
      "Read Swivel Bearing Angle: getTargetAngle on bearing '" ..
        bearing_name .. "' returned " .. diagnostic_type(value) ..
        ", expected number"
    )
  end
  if value ~= value then
    fail_loud(
      "Read Swivel Bearing Angle: getTargetAngle on bearing '" ..
        bearing_name .. "' returned nan"
    )
  end
  if value == math.huge or value == -math.huge then
    fail_loud(
      "Read Swivel Bearing Angle: getTargetAngle on bearing '" ..
        bearing_name .. "' returned inf"
    )
  end
  return value
end

local function read_swivel_bearing_angle(...)
  local opts = parse_opts(...)
  local bearing_name = optional_name(opts.bearing_name, "bearing_name")
  local wrapped, resolved_name = resolve_bearing(bearing_name)
  return read_angle(wrapped, resolved_name)
end

local bearing_turret = {
  read_swivel_bearing_angle = read_swivel_bearing_angle,
}

return bearing_turret
