local prefix = "Aim Turret At Target: "

local known_keys = {
  yaw_degrees = true,
  pitch_degrees = true,
  yaw_rpm = true,
  pitch_rpm = true,
  track_id = true,
  radar_name = true,
  monitor_name = true,
  yaw_bearing_name = true,
  pitch_bearing_name = true,
  yaw_motor_name = true,
  pitch_motor_name = true,
  yaw_tolerance_degrees = true,
  pitch_tolerance_degrees = true,
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
    if known_keys[key] ~= true then
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

local function require_finite_number(value, field_name)
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

local function optional_tolerance(value, field_name)
  if value == nil then
    return nil
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
  if value < 0 then
    fail_loud(
      prefix .. field_name .. " must be >= 0, got " .. tostring(value)
    )
  end
  return value
end

local function load_child(filename, command_name)
  local cached = package.loaded[filename]
  if type(cached) == "table" and type(cached[command_name]) == "function" then
    return cached
  end
  local ok, result = pcall(dofile, filename)
  if not ok then
    fail_loud(
      prefix .. filename .. " failed: " .. tostring(result)
    )
  end
  if type(result) ~= "table" then
    fail_loud(
      prefix .. filename .. " returned " .. diagnostic_type(result) ..
        ", expected table"
    )
  end
  if type(result[command_name]) ~= "function" then
    fail_loud(
      prefix .. filename .. " missing function " .. command_name
    )
  end
  package.loaded[filename] = result
  return result
end

local function call_read_radar_tracks(read_fn, radar_opts)
  local ok, result = pcall(read_fn, radar_opts)
  if not ok then
    fail_loud(
      prefix .. "read_radar_tracks failed: " .. tostring(result)
    )
  end
  return result
end

local function track_id_in_list(tracks, required_id)
  if type(tracks) ~= "table" then
    return false
  end
  local index = 1
  while tracks[index] ~= nil do
    local row = tracks[index]
    if type(row) == "table" and row.id == required_id then
      return true
    end
    index = index + 1
  end
  return false
end

local function build_rotate_opts(target_degrees, rpm, bearing_name, motor_name, tolerance_degrees)
  local child_opts = {
    target_degrees = target_degrees,
    rpm = rpm,
  }
  if bearing_name ~= nil then
    child_opts.bearing_name = bearing_name
  end
  if motor_name ~= nil then
    child_opts.motor_name = motor_name
  end
  if tolerance_degrees ~= nil then
    child_opts.tolerance_degrees = tolerance_degrees
  end
  return child_opts
end

local function call_rotate(rotate_fn, child_opts, axis)
  local ok, result = pcall(rotate_fn, child_opts)
  if not ok then
    fail_loud(
      prefix .. axis .. " rotate failed: " .. tostring(result)
    )
  end
  if type(result) ~= "number" then
    fail_loud(
      prefix .. axis .. " rotate returned " .. diagnostic_type(result) ..
        ", expected number"
    )
  end
  return result
end

local function aim_turret_at_target(...)
  local opts = parse_opts(...)
  local yaw_degrees = require_finite_number(opts.yaw_degrees, "yaw_degrees")
  local pitch_degrees = require_finite_number(opts.pitch_degrees, "pitch_degrees")
  local yaw_rpm = require_finite_number(opts.yaw_rpm, "yaw_rpm")
  local pitch_rpm = require_finite_number(opts.pitch_rpm, "pitch_rpm")
  local track_id = optional_name(opts.track_id, "track_id")
  local radar_name = optional_name(opts.radar_name, "radar_name")
  local monitor_name = optional_name(opts.monitor_name, "monitor_name")
  local yaw_bearing_name = optional_name(opts.yaw_bearing_name, "yaw_bearing_name")
  local pitch_bearing_name = optional_name(
    opts.pitch_bearing_name,
    "pitch_bearing_name"
  )
  local yaw_motor_name = optional_name(opts.yaw_motor_name, "yaw_motor_name")
  local pitch_motor_name = optional_name(
    opts.pitch_motor_name,
    "pitch_motor_name"
  )
  local yaw_tolerance = optional_tolerance(
    opts.yaw_tolerance_degrees,
    "yaw_tolerance_degrees"
  )
  local pitch_tolerance = optional_tolerance(
    opts.pitch_tolerance_degrees,
    "pitch_tolerance_degrees"
  )

  if yaw_bearing_name ~= nil and pitch_bearing_name ~= nil and
      yaw_bearing_name == pitch_bearing_name then
    fail_loud(
      prefix .. "yaw_bearing_name and pitch_bearing_name must differ, both '" ..
        yaw_bearing_name .. "'"
    )
  end
  if yaw_motor_name ~= nil and pitch_motor_name ~= nil and
      yaw_motor_name == pitch_motor_name then
    fail_loud(
      prefix .. "yaw_motor_name and pitch_motor_name must differ, both '" ..
        yaw_motor_name .. "'"
    )
  end

  local radar_mod = load_child("read_radar_tracks.lua", "read_radar_tracks")
  local rotate_mod = load_child(
    "rotate_bearing_toward_angle.lua",
    "rotate_bearing_toward_angle"
  )

  local radar_opts = {}
  if radar_name ~= nil then
    radar_opts.radar_name = radar_name
  end
  if monitor_name ~= nil then
    radar_opts.monitor_name = monitor_name
  end
  local read_result = call_read_radar_tracks(
    radar_mod.read_radar_tracks,
    radar_opts
  )
  if type(read_result) ~= "table" then
    fail_loud(
      prefix .. "read_radar_tracks failed: expected table, got " ..
        diagnostic_type(read_result)
    )
  end

  local required_id = track_id
  if required_id == nil then
    required_id = read_result.selectedTrackId
  end
  if required_id == nil or required_id == "" then
    fail_loud(prefix .. "no radar target this tick")
  end
  if not track_id_in_list(read_result.tracks, required_id) then
    fail_loud(
      prefix .. "track '" .. required_id .. "' is not in this tick's tracks"
    )
  end

  local yaw_error = call_rotate(
    rotate_mod.rotate_bearing_toward_angle,
    build_rotate_opts(
      yaw_degrees,
      yaw_rpm,
      yaw_bearing_name,
      yaw_motor_name,
      yaw_tolerance
    ),
    "yaw"
  )
  local pitch_error = call_rotate(
    rotate_mod.rotate_bearing_toward_angle,
    build_rotate_opts(
      pitch_degrees,
      pitch_rpm,
      pitch_bearing_name,
      pitch_motor_name,
      pitch_tolerance
    ),
    "pitch"
  )

  local yaw_resolved = yaw_tolerance
  if yaw_resolved == nil then
    yaw_resolved = 1
  end
  local pitch_resolved = pitch_tolerance
  if pitch_resolved == nil then
    pitch_resolved = 1
  end

  local on_target = math.abs(yaw_error) <= yaw_resolved and
    math.abs(pitch_error) <= pitch_resolved
  return { on_target = on_target }
end

local bearing_turret = {
  aim_turret_at_target = aim_turret_at_target,
}

return bearing_turret
