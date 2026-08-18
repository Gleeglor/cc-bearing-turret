local prefix = "Compute Ballistic Aim: "
local child_radar = dofile("read_radar_tracks.lua")

local allowed_keys = {
  muzzle_x = true,
  muzzle_y = true,
  muzzle_z = true,
  projectile_mass_kg = true,
  powder_mass_kg = true,
  charge_length_meters = true,
  barrel_length_meters = true,
  track = true,
  radar_name = true,
  monitor_name = true,
  trajectory = true,
  projectile_kind = true,
  max_ticks = true,
  gravity_multiplier = true,
  drag_multiplier = true,
  muzzle_velocity_blocks_per_tick = true,
}

local kind_radius = {
  cannon = 0.754441738242 / 2,
  autocannon = 0.150888347648 / 2,
  machine_gun = 0.004236548901,
}

local function fail_loud(message)
  error(message, 0)
end

local function diagnostic_type(value)
  return type(value)
end

local function is_nan(value)
  return value ~= value
end

local function is_inf(value)
  return value == math.huge or value == -math.huge
end

local function is_finite_number(value)
  return type(value) == "number" and not is_nan(value) and not is_inf(value)
end

local function number_got(value)
  if type(value) ~= "number" then
    return diagnostic_type(value)
  end
  if is_nan(value) then
    return "nan"
  end
  if is_inf(value) then
    return "inf"
  end
  return diagnostic_type(value)
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
    if not allowed_keys[key] then
      fail_loud(prefix .. "unknown input '" .. tostring(key) .. "'")
    end
  end
  return opts
end

local function optional_string(value, field_name)
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
  if is_nan(value) then
    fail_loud(prefix .. field_name .. " must be a finite number, got nan")
  end
  if is_inf(value) then
    fail_loud(prefix .. field_name .. " must be a finite number, got inf")
  end
  return value
end

local function optional_finite(value, field_name)
  if value == nil then
    return nil
  end
  if type(value) ~= "number" then
    fail_loud(
      prefix .. field_name .. " must be a number, got " ..
        diagnostic_type(value)
    )
  end
  if is_nan(value) then
    fail_loud(prefix .. field_name .. " must be a finite number, got nan")
  end
  if is_inf(value) then
    fail_loud(prefix .. field_name .. " must be a finite number, got inf")
  end
  return value
end

local function require_positive(value, field_name)
  if value <= 0 then
    fail_loud(prefix .. field_name .. " must be greater than 0")
  end
  return value
end

local function require_track_vector(vector, field_name)
  if vector == nil then
    fail_loud(prefix .. "track " .. field_name .. " is missing")
  end
  if type(vector) ~= "table" then
    fail_loud(
      prefix .. "track " .. field_name .. " is " ..
        diagnostic_type(vector) .. ", expected table"
    )
  end
  local axes = { "x", "y", "z" }
  local copy = {}
  local index = 1
  while index <= 3 do
    local axis = axes[index]
    local component = vector[axis]
    if not is_finite_number(component) then
      fail_loud(
        prefix .. "track " .. field_name .. "." .. axis ..
          " must be a finite number, got " .. number_got(component)
      )
    end
    copy[axis] = component
    index = index + 1
  end
  return copy
end

local function copy_track(track)
  if type(track) ~= "table" then
    fail_loud(
      prefix .. "track must be a table, got " .. diagnostic_type(track)
    )
  end
  if track.id == nil then
    fail_loud(prefix .. "track id is missing")
  end
  if type(track.id) ~= "string" then
    fail_loud(
      prefix .. "track id is " .. diagnostic_type(track.id) ..
        ", expected string"
    )
  end
  if track.id == "" then
    fail_loud(prefix .. "track id is empty")
  end
  return {
    id = track.id,
    position = require_track_vector(track.position, "position"),
    velocity = require_track_vector(track.velocity, "velocity"),
  }
end

local function robins_speed(mass, powder, charge_length, barrel_length)
  local ratio = barrel_length / charge_length
  if ratio < 1.000001 then
    ratio = 1.000001
  end
  local radicand = (powder / (mass + powder / 3)) * math.log(ratio)
  if not is_finite_number(radicand) or radicand <= 0 then
    fail_loud(prefix .. "Robins muzzle speed is not positive")
  end
  local v_mps = 606.8568 * math.sqrt(radicand)
  local v_bpt = v_mps / 20
  if not is_finite_number(v_bpt) or v_bpt <= 0 then
    fail_loud(prefix .. "Robins muzzle speed is not positive")
  end
  return v_bpt
end

local function yaw_to_lead(muzzle_x, muzzle_z, lead_x, lead_z)
  local dx = lead_x - muzzle_x
  local dz = lead_z - muzzle_z
  local horiz = math.sqrt(dx * dx + dz * dz)
  if horiz < 1e-9 then
    return 0
  end
  return math.atan2(-dx, dz) * 180 / math.pi
end

local function launch_direction(yaw_degrees, pitch_degrees)
  if pitch_degrees == 90 then
    return 0, 1, 0
  end
  if pitch_degrees == -90 then
    return 0, -1, 0
  end
  local yaw_rad = yaw_degrees * math.pi / 180
  local pitch_rad = pitch_degrees * math.pi / 180
  local cos_pitch = math.cos(pitch_rad)
  local ux = -math.sin(yaw_rad) * cos_pitch
  local uy = math.sin(pitch_rad)
  local uz = math.cos(yaw_rad) * cos_pitch
  return ux, uy, uz
end

local function distance(ax, ay, az, bx, by, bz)
  local dx = ax - bx
  local dy = ay - by
  local dz = az - bz
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function simulate_against_lead(
  muzzle_x,
  muzzle_y,
  muzzle_z,
  v_bpt,
  yaw_degrees,
  pitch_degrees,
  max_ticks,
  k,
  g,
  lead_at_tick
)
  local ux, uy, uz = launch_direction(yaw_degrees, pitch_degrees)
  local x = muzzle_x
  local y = muzzle_y
  local z = muzzle_z
  local vx = v_bpt * ux
  local vy = v_bpt * uy
  local vz = v_bpt * uz
  local best_n = nil
  local best_miss = nil
  local best_x = nil
  local best_y = nil
  local best_z = nil
  local n = 1
  while n <= max_ticks do
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed == 0 then
      break
    end
    local unit_x = vx / speed
    local unit_y = vy / speed
    local unit_z = vz / speed
    local drag_force = k * speed * speed
    if drag_force > speed then
      drag_force = speed
    end
    local ax = -unit_x * drag_force
    local ay = -unit_y * drag_force + g
    local az = -unit_z * drag_force
    x = x + vx + 0.5 * ax
    y = y + vy + 0.5 * ay
    z = z + vz + 0.5 * az
    vx = vx + ax
    vy = vy + ay
    vz = vz + az
    local lead_x, lead_y, lead_z = lead_at_tick(n)
    local miss = distance(x, y, z, lead_x, lead_y, lead_z)
    local better = best_n == nil or miss < best_miss
    if not better and miss == best_miss and n < best_n then
      better = true
    end
    if better then
      best_n = n
      best_miss = miss
      best_x = x
      best_y = y
      best_z = z
    end
    n = n + 1
  end
  return best_n, best_miss, best_x, best_y, best_z
end

local function frozen_lead_fn(lead_x, lead_y, lead_z)
  return function()
    return lead_x, lead_y, lead_z
  end
end

local function moving_lead_fn(position, velocity)
  return function(n)
    return position.x + velocity.x * n,
      position.y + velocity.y * n,
      position.z + velocity.z * n
  end
end

local function pick_best_sample(samples)
  local best = nil
  local index = 1
  while index <= #samples do
    local sample = samples[index]
    if sample.n ~= nil then
      if best == nil then
        best = sample
      elseif sample.miss < best.miss then
        best = sample
      elseif sample.miss == best.miss and sample.pitch < best.pitch then
        best = sample
      end
    end
    index = index + 1
  end
  return best
end

local function family_from_runs(runs, trajectory)
  if #runs == 0 then
    return nil
  end
  if #runs == 1 then
    return pick_best_sample(runs[1])
  end
  local low_run = runs[1]
  local high_run = runs[#runs]
  local low_index = 2
  while low_index <= #runs do
    local run = runs[low_index]
    if run[1].pitch < low_run[1].pitch then
      low_run = run
    end
    if run[1].pitch > high_run[1].pitch then
      high_run = run
    end
    low_index = low_index + 1
  end
  if trajectory == "high" then
    return pick_best_sample(high_run)
  end
  return pick_best_sample(low_run)
end

local function coarse_scan(
  muzzle_x,
  muzzle_y,
  muzzle_z,
  v_bpt,
  yaw_degrees,
  max_ticks,
  k,
  g,
  lead_x,
  lead_y,
  lead_z,
  trajectory
)
  local lead_fn = frozen_lead_fn(lead_x, lead_y, lead_z)
  local samples = {}
  local runs = {}
  local current_run = nil
  local pitch = -90
  while pitch <= 90 do
    local n, miss, px, py, pz = simulate_against_lead(
      muzzle_x,
      muzzle_y,
      muzzle_z,
      v_bpt,
      yaw_degrees,
      pitch,
      max_ticks,
      k,
      g,
      lead_fn
    )
    local sample = {
      pitch = pitch,
      n = n,
      miss = miss,
      x = px,
      y = py,
      z = pz,
    }
    samples[#samples + 1] = sample
    local is_hit = n ~= nil and miss <= 1.0
    if is_hit then
      if current_run == nil then
        current_run = {}
      end
      current_run[#current_run + 1] = sample
    else
      if current_run ~= nil then
        runs[#runs + 1] = current_run
        current_run = nil
      end
    end
    pitch = pitch + 1
  end
  if current_run ~= nil then
    runs[#runs + 1] = current_run
  end
  local chosen = family_from_runs(runs, trajectory)
  if chosen == nil then
    chosen = pick_best_sample(samples)
  end
  return chosen
end

local function refine_scan(
  muzzle_x,
  muzzle_y,
  muzzle_z,
  v_bpt,
  yaw_degrees,
  chosen_pitch,
  max_ticks,
  k,
  g,
  lead_x,
  lead_y,
  lead_z
)
  local lead_fn = frozen_lead_fn(lead_x, lead_y, lead_z)
  local start_pitch = chosen_pitch - 1
  if start_pitch < -90 then
    start_pitch = -90
  end
  local finish_pitch = chosen_pitch + 1
  if finish_pitch > 90 then
    finish_pitch = 90
  end
  local samples = {}
  local i = 0
  while true do
    local pitch = start_pitch + i * 0.05
    if pitch > finish_pitch + 1e-12 then
      break
    end
    if pitch > 90 then
      pitch = 90
    end
    if pitch < -90 then
      pitch = -90
    end
    local n, miss, px, py, pz = simulate_against_lead(
      muzzle_x,
      muzzle_y,
      muzzle_z,
      v_bpt,
      yaw_degrees,
      pitch,
      max_ticks,
      k,
      g,
      lead_fn
    )
    samples[#samples + 1] = {
      pitch = pitch,
      n = n,
      miss = miss,
      x = px,
      y = py,
      z = pz,
    }
    i = i + 1
  end
  return pick_best_sample(samples)
end

local function load_track(opts, radar_name, monitor_name)
  if opts.track ~= nil then
    if radar_name ~= nil then
      fail_loud(prefix .. "radar_name is not used when track is supplied")
    end
    if monitor_name ~= nil then
      fail_loud(prefix .. "monitor_name is not used when track is supplied")
    end
    return copy_track(opts.track)
  end
  local ok, result_or_error
  if radar_name == nil and monitor_name == nil then
    ok, result_or_error = pcall(child_radar.read_radar_tracks)
  else
    local child_opts = {}
    if radar_name ~= nil then
      child_opts.radar_name = radar_name
    end
    if monitor_name ~= nil then
      child_opts.monitor_name = monitor_name
    end
    ok, result_or_error = pcall(child_radar.read_radar_tracks, child_opts)
  end
  if not ok then
    fail_loud(
      prefix .. "read_radar_tracks threw: " .. tostring(result_or_error)
    )
  end
  if type(result_or_error) ~= "table" then
    fail_loud(
      prefix .. "read_radar_tracks returned " ..
        diagnostic_type(result_or_error) .. ", expected table"
    )
  end
  if result_or_error.selectedTrack == nil then
    fail_loud(prefix .. "no selected track")
  end
  return copy_track(result_or_error.selectedTrack)
end

local function compute_ballistic_aim(...)
  local opts = parse_opts(...)
  local radar_name = optional_string(opts.radar_name, "radar_name")
  local monitor_name = optional_string(opts.monitor_name, "monitor_name")
  local trajectory = optional_string(opts.trajectory, "trajectory")
  local projectile_kind = optional_string(opts.projectile_kind, "projectile_kind")
  if trajectory == nil then
    trajectory = "low"
  elseif trajectory ~= "low" and trajectory ~= "high" then
    fail_loud(
      prefix .. "trajectory must be 'low' or 'high', got '" ..
        trajectory .. "'"
    )
  end
  if projectile_kind == nil then
    projectile_kind = "cannon"
  elseif kind_radius[projectile_kind] == nil then
    fail_loud(
      prefix .. "projectile_kind must be 'cannon', 'autocannon', or " ..
        "'machine_gun', got '" .. projectile_kind .. "'"
    )
  end
  local muzzle_x = require_finite(opts.muzzle_x, "muzzle_x")
  local muzzle_y = require_finite(opts.muzzle_y, "muzzle_y")
  local muzzle_z = require_finite(opts.muzzle_z, "muzzle_z")
  local mass = require_positive(
    require_finite(opts.projectile_mass_kg, "projectile_mass_kg"),
    "projectile_mass_kg"
  )
  local powder = require_positive(
    require_finite(opts.powder_mass_kg, "powder_mass_kg"),
    "powder_mass_kg"
  )
  local charge_length = require_positive(
    require_finite(opts.charge_length_meters, "charge_length_meters"),
    "charge_length_meters"
  )
  local barrel_length = require_positive(
    require_finite(opts.barrel_length_meters, "barrel_length_meters"),
    "barrel_length_meters"
  )
  local gravity_multiplier = optional_finite(
    opts.gravity_multiplier,
    "gravity_multiplier"
  )
  if gravity_multiplier == nil then
    gravity_multiplier = 1
  end
  local drag_multiplier = optional_finite(
    opts.drag_multiplier,
    "drag_multiplier"
  )
  if drag_multiplier == nil then
    drag_multiplier = 1
  elseif drag_multiplier < 0 then
    fail_loud(prefix .. "drag_multiplier must be >= 0")
  end
  local override_speed = optional_finite(
    opts.muzzle_velocity_blocks_per_tick,
    "muzzle_velocity_blocks_per_tick"
  )
  if override_speed ~= nil then
    require_positive(override_speed, "muzzle_velocity_blocks_per_tick")
  end
  local max_ticks = optional_finite(opts.max_ticks, "max_ticks")
  if max_ticks == nil then
    max_ticks = 2000
  elseif max_ticks ~= math.floor(max_ticks) or max_ticks < 1 or
      max_ticks > 100000 then
    fail_loud(
      prefix .. "max_ticks must be an integer 1 through 100000, got " ..
        tostring(max_ticks)
    )
  end
  local track = load_track(opts, radar_name, monitor_name)
  local v_bpt = override_speed
  if v_bpt == nil then
    v_bpt = robins_speed(mass, powder, charge_length, barrel_length)
  end
  local radius = kind_radius[projectile_kind]
  local area = math.pi * radius * radius
  local rho = 1.225 * drag_multiplier
  local k = 0.5 * rho * 0.47 * area / mass
  local g = -9.80665 / 400 * gravity_multiplier
  local dx0 = track.position.x - muzzle_x
  local dz0 = track.position.z - muzzle_z
  local horiz0 = math.sqrt(dx0 * dx0 + dz0 * dz0)
  local t = math.floor(horiz0 / v_bpt)
  if t < 1 then
    t = 1
  end
  local last_yaw = nil
  local last_pitch = nil
  local last_n = nil
  local iter = 1
  while iter <= 8 do
    local lead_x = track.position.x + track.velocity.x * t
    local lead_y = track.position.y + track.velocity.y * t
    local lead_z = track.position.z + track.velocity.z * t
    local yaw_degrees = yaw_to_lead(muzzle_x, muzzle_z, lead_x, lead_z)
    local coarse = coarse_scan(
      muzzle_x,
      muzzle_y,
      muzzle_z,
      v_bpt,
      yaw_degrees,
      max_ticks,
      k,
      g,
      lead_x,
      lead_y,
      lead_z,
      trajectory
    )
    if coarse == nil or coarse.n == nil then
      last_n = nil
      break
    end
    local refined = refine_scan(
      muzzle_x,
      muzzle_y,
      muzzle_z,
      v_bpt,
      yaw_degrees,
      coarse.pitch,
      max_ticks,
      k,
      g,
      lead_x,
      lead_y,
      lead_z
    )
    if refined == nil or refined.n == nil then
      last_n = nil
      break
    end
    last_yaw = yaw_degrees
    last_pitch = refined.pitch
    last_n = refined.n
    if refined.n == t then
      break
    end
    t = refined.n
    iter = iter + 1
  end
  if last_n == nil or last_yaw == nil or last_pitch == nil then
    fail_loud(prefix .. "no intercept")
  end
  local moving_n, moving_miss, impact_x, impact_y, impact_z =
    simulate_against_lead(
      muzzle_x,
      muzzle_y,
      muzzle_z,
      v_bpt,
      last_yaw,
      last_pitch,
      max_ticks,
      k,
      g,
      moving_lead_fn(track.position, track.velocity)
    )
  if moving_n == nil or moving_miss == nil or moving_miss > 1.0 then
    fail_loud(prefix .. "no intercept")
  end
  return {
    yaw_degrees = last_yaw,
    pitch_degrees = last_pitch,
    time_of_flight_ticks = moving_n,
    muzzle_velocity_blocks_per_tick = v_bpt,
    impact_x = impact_x,
    impact_y = impact_y,
    impact_z = impact_z,
    trajectory = trajectory,
  }
end

local bearing_turret = {
  compute_ballistic_aim = compute_ballistic_aim,
}

return bearing_turret
