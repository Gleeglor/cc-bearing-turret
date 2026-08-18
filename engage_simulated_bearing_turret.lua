local prefix = "Engage Simulated Bearing Turret: "

local known_keys = {
  radar_name = true,
  monitor_name = true,
  yaw_bearing_name = true,
  pitch_bearing_name = true,
  yaw_motor_name = true,
  pitch_motor_name = true,
  yaw_rpm = true,
  pitch_rpm = true,
  side = true,
  relay_name = true,
  muzzle_x = true,
  muzzle_y = true,
  muzzle_z = true,
  projectile_mass_kg = true,
  powder_mass_kg = true,
  charge_length_meters = true,
  barrel_length_meters = true,
  track = true,
  trajectory = true,
  projectile_kind = true,
  max_ticks = true,
  gravity_multiplier = true,
  drag_multiplier = true,
  muzzle_velocity_blocks_per_tick = true,
  track_id = true,
  yaw_tolerance_degrees = true,
  pitch_tolerance_degrees = true,
}

local omit_empty = {
  radar_name = true,
  monitor_name = true,
  relay_name = true,
  track_id = true,
  trajectory = true,
  projectile_kind = true,
}

local compute_keys = {
  "muzzle_x",
  "muzzle_y",
  "muzzle_z",
  "projectile_mass_kg",
  "powder_mass_kg",
  "charge_length_meters",
  "barrel_length_meters",
  "track",
  "radar_name",
  "monitor_name",
  "trajectory",
  "projectile_kind",
  "max_ticks",
  "gravity_multiplier",
  "drag_multiplier",
  "muzzle_velocity_blocks_per_tick",
}

local aim_parent_keys = {
  "yaw_rpm",
  "pitch_rpm",
  "track_id",
  "radar_name",
  "monitor_name",
  "yaw_bearing_name",
  "pitch_bearing_name",
  "yaw_motor_name",
  "pitch_motor_name",
  "yaw_tolerance_degrees",
  "pitch_tolerance_degrees",
}

local fire_keys = {
  "side",
  "relay_name",
}

local compute_required = {
  "muzzle_x",
  "muzzle_y",
  "muzzle_z",
  "projectile_mass_kg",
  "powder_mass_kg",
  "charge_length_meters",
  "barrel_length_meters",
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
    return
  end
  if type(value) ~= "string" then
    fail_loud(
      prefix .. field_name .. " must be a string or nil, got " ..
        diagnostic_type(value)
    )
  end
end

local function require_axis(opts, field_name)
  local value = opts[field_name]
  if value == nil then
    fail_loud(prefix .. field_name .. " is required")
  end
  if type(value) ~= "string" then
    fail_loud(
      prefix .. field_name .. " must be a string, got " ..
        diagnostic_type(value)
    )
  end
  if value == "" then
    fail_loud(prefix .. field_name .. " must be a non-empty string")
  end
  return value
end

local function require_present(opts, field_name)
  if opts[field_name] == nil then
    fail_loud(prefix .. field_name .. " is required")
  end
end

local function load_child(filename, command_name)
  local ok, result = pcall(dofile, filename)
  if not ok then
    fail_loud(prefix .. "missing command '" .. command_name .. "'")
  end
  if type(result) ~= "table" then
    fail_loud(prefix .. "missing command '" .. command_name .. "'")
  end
  if type(result[command_name]) ~= "function" then
    fail_loud(prefix .. "missing command '" .. command_name .. "'")
  end
  return result
end

local function copy_listed(src, keys)
  local dest = {}
  local index = 1
  while keys[index] ~= nil do
    local key = keys[index]
    local value = src[key]
    if value ~= nil then
      if omit_empty[key] == true and value == "" then
        -- omit
      else
        dest[key] = value
      end
    end
    index = index + 1
  end
  return dest
end

local function call_child(fn, child_opts)
  local ok, result = pcall(fn, child_opts)
  if not ok then
    error(result, 0)
  end
  return result
end

local function table_has_a_key(value)
  return next(value) ~= nil
end

local function engage_simulated_bearing_turret(...)
  local opts = parse_opts(...)
  optional_name(opts.radar_name, "radar_name")
  optional_name(opts.monitor_name, "monitor_name")
  local yaw_bearing_name = require_axis(opts, "yaw_bearing_name")
  local pitch_bearing_name = require_axis(opts, "pitch_bearing_name")
  local yaw_motor_name = require_axis(opts, "yaw_motor_name")
  local pitch_motor_name = require_axis(opts, "pitch_motor_name")
  if yaw_bearing_name == pitch_bearing_name then
    fail_loud(
      prefix .. "yaw_bearing_name and pitch_bearing_name must differ"
    )
  end
  if yaw_motor_name == pitch_motor_name then
    fail_loud(prefix .. "yaw_motor_name and pitch_motor_name must differ")
  end
  local required_index = 1
  while compute_required[required_index] ~= nil do
    require_present(opts, compute_required[required_index])
    required_index = required_index + 1
  end
  require_present(opts, "yaw_rpm")
  require_present(opts, "pitch_rpm")
  require_present(opts, "side")

  local compute_mod = load_child(
    "compute_ballistic_aim.lua",
    "compute_ballistic_aim"
  )
  local aim_mod = load_child("aim_turret_at_target.lua", "aim_turret_at_target")
  local fire_mod = load_child(
    "fire_rotating_barrel.lua",
    "fire_rotating_barrel"
  )

  local compute_opts = copy_listed(opts, compute_keys)
  local aim_opts = copy_listed(opts, aim_parent_keys)
  local fire_opts = copy_listed(opts, fire_keys)

  local solution = call_child(compute_mod.compute_ballistic_aim, compute_opts)
  if type(solution) ~= "table" then
    fail_loud(
      prefix .. "compute_ballistic_aim returned " ..
        diagnostic_type(solution) .. ", expected table"
    )
  end
  if not table_has_a_key(solution) then
    fail_loud(
      prefix .. "compute_ballistic_aim returned an empty solution"
    )
  end
  if solution.yaw_degrees ~= nil then
    aim_opts.yaw_degrees = solution.yaw_degrees
  end
  if solution.pitch_degrees ~= nil then
    aim_opts.pitch_degrees = solution.pitch_degrees
  end

  local aim_result = call_child(aim_mod.aim_turret_at_target, aim_opts)
  if type(aim_result) ~= "table" then
    fail_loud(
      prefix .. "aim_turret_at_target returned " ..
        diagnostic_type(aim_result) .. ", expected table"
    )
  end
  local on_target = aim_result.on_target
  if type(on_target) ~= "boolean" then
    fail_loud(
      prefix .. "aim_turret_at_target on_target returned " ..
        diagnostic_type(on_target) .. ", expected boolean"
    )
  end
  if on_target == false then
    return { on_target = false, fired = false }
  end
  call_child(fire_mod.fire_rotating_barrel, fire_opts)
  return { on_target = true, fired = true }
end

local bearing_turret = {
  engage_simulated_bearing_turret = engage_simulated_bearing_turret,
}

return bearing_turret
