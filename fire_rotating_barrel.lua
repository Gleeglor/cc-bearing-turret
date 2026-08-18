local relay_type = "redstone_relay"
local prefix = "Fire Rotating Barrel: "
local legal_sides = {
  top = true,
  bottom = true,
  left = true,
  right = true,
  front = true,
  back = true,
}

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
    if key ~= "side" and key ~= "relay_name" then
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

local function require_side(side)
  if side == nil then
    fail_loud(prefix .. "side is required")
  end
  if type(side) ~= "string" then
    fail_loud(
      prefix .. "side must be a string, got " .. diagnostic_type(side)
    )
  end
  if legal_sides[side] ~= true then
    fail_loud(
      prefix ..
        "side must be top, bottom, left, right, front, or back, got '" ..
        side .. "'"
    )
  end
  return side
end

local function resolve_writer(relay_name)
  if relay_name ~= nil then
    local wrapped = peripheral.wrap(relay_name)
    if wrapped == nil then
      fail_loud(
        prefix .. "named relay '" .. relay_name .. "' is not attached"
      )
    end
    local peripheral_type = peripheral.getType(relay_name)
    if peripheral_type ~= relay_type then
      local type_text = peripheral_type
      if type_text == nil then
        type_text = "nil"
      end
      fail_loud(
        prefix .. "named relay '" .. relay_name .. "' is type '" ..
          tostring(type_text) .. "', expected redstone_relay"
      )
    end
    return wrapped.setAnalogOutput, relay_name
  end
  if type(redstone) ~= "table" or
      type(redstone.setAnalogOutput) ~= "function" then
    fail_loud(prefix .. "redstone API is missing")
  end
  return redstone.setAnalogOutput, nil
end

local function analog_throw_message(strength, side, relay_name, original)
  if relay_name ~= nil then
    return prefix .. "setAnalogOutput " .. tostring(strength) ..
      " threw on relay '" .. relay_name .. "' side '" .. side ..
      "': " .. tostring(original)
  end
  return prefix .. "setAnalogOutput " .. tostring(strength) ..
    " threw on side '" .. side .. "': " .. tostring(original)
end

local function write_analog(writer, side, strength, relay_name)
  local ok, value_or_error = pcall(writer, side, strength)
  if not ok then
    fail_loud(
      analog_throw_message(strength, side, relay_name, value_or_error)
    )
  end
end

local function fire_rotating_barrel(...)
  local opts = parse_opts(...)
  local side = require_side(opts.side)
  local relay_name = optional_name(opts.relay_name, "relay_name")
  local writer, resolved_name = resolve_writer(relay_name)
  if type(sleep) ~= "function" then
    fail_loud(prefix .. "sleep is missing")
  end
  write_analog(writer, side, 1, resolved_name)
  local sleep_ok, sleep_error = pcall(sleep, 0.1)
  local off_ok, off_error = pcall(writer, side, 0)
  if not off_ok then
    fail_loud(
      analog_throw_message(0, side, resolved_name, off_error)
    )
  end
  if not sleep_ok then
    fail_loud(prefix .. "sleep threw: " .. tostring(sleep_error))
  end
end

local bearing_turret = {
  fire_rotating_barrel = fire_rotating_barrel,
}

return bearing_turret
