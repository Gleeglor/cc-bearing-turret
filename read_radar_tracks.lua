local dish_type_radar = "create_radar:radar"
local dish_type_plane_radar = "create_radar:plane_radar"
local monitor_type = "create_radar:monitor"

local function fail_loud(message)
  error(message, 0)
end

local function diagnostic_type(value)
  return type(value)
end

local function is_empty_table(value)
  return next(value) == nil
end

local function is_dense_list(value)
  if type(value) ~= "table" then
    return false
  end
  local highest_index = 0
  for key in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    if key < 1 or key ~= math.floor(key) then
      return false
    end
    if key > highest_index then
      highest_index = key
    end
  end
  local index = 1
  while index <= highest_index do
    if value[index] == nil then
      return false
    end
    index = index + 1
  end
  return true
end

local function copy_map(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

local function parse_opts(...)
  local argument_count = select("#", ...)
  if argument_count > 1 then
    fail_loud(
      "Read Radar Tracks: expected at most one argument, got " ..
        tostring(argument_count)
    )
  end
  local opts = ...
  if opts == nil then
    return { radar_name = nil, monitor_name = nil }
  end
  if type(opts) ~= "table" then
    fail_loud(
      "Read Radar Tracks: inputs must be a table or nil, got " ..
        diagnostic_type(opts)
    )
  end
  for key in pairs(opts) do
    if key ~= "radar_name" and key ~= "monitor_name" then
      fail_loud("Read Radar Tracks: unknown input '" .. tostring(key) .. "'")
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
      "Read Radar Tracks: " .. field_name .. " is " ..
        diagnostic_type(value) .. ", expected string"
    )
  end
  if value == "" then
    return nil
  end
  return value
end

local function attached_names_of_types(allowed_types)
  local names = {}
  local attached = peripheral.getNames()
  local index = 1
  while index <= #attached do
    local peripheral_name = attached[index]
    local peripheral_type = peripheral.getType(peripheral_name)
    if allowed_types[peripheral_type] then
      names[#names + 1] = peripheral_name
    end
    index = index + 1
  end
  return names
end

local function is_dish_type(peripheral_type)
  return peripheral_type == dish_type_radar or
    peripheral_type == dish_type_plane_radar
end

local function wrap_named(peripheral_name)
  return peripheral.wrap(peripheral_name)
end

local function resolve_dish(radar_name)
  if radar_name ~= nil then
    local wrapped = wrap_named(radar_name)
    if wrapped == nil then
      fail_loud(
        "Read Radar Tracks: named radar '" .. radar_name ..
          "' is not attached"
      )
    end
    local peripheral_type = peripheral.getType(radar_name)
    if not is_dish_type(peripheral_type) then
      local type_text = peripheral_type
      if type_text == nil then
        type_text = "nil"
      end
      fail_loud(
        "Read Radar Tracks: named radar '" .. radar_name ..
          "' is type '" .. tostring(type_text) ..
          "', expected create_radar:radar or create_radar:plane_radar"
      )
    end
    return wrapped
  end
  local names = attached_names_of_types({
    [dish_type_radar] = true,
    [dish_type_plane_radar] = true,
  })
  if #names == 0 then
    fail_loud("Read Radar Tracks: no radar peripheral attached")
  end
  if #names > 1 then
    fail_loud(
      "Read Radar Tracks: expected exactly one radar, found " ..
        tostring(#names)
    )
  end
  return wrap_named(names[1])
end

local function resolve_monitor(monitor_name)
  if monitor_name ~= nil then
    local wrapped = wrap_named(monitor_name)
    if wrapped == nil then
      fail_loud(
        "Read Radar Tracks: named monitor '" .. monitor_name ..
          "' is not attached"
      )
    end
    local peripheral_type = peripheral.getType(monitor_name)
    if peripheral_type ~= monitor_type then
      local type_text = peripheral_type
      if type_text == nil then
        type_text = "nil"
      end
      fail_loud(
        "Read Radar Tracks: named monitor '" .. monitor_name ..
          "' is type '" .. tostring(type_text) ..
          "', expected create_radar:monitor"
      )
    end
    return wrapped, monitor_name
  end
  local names = attached_names_of_types({
    [monitor_type] = true,
  })
  if #names == 0 then
    return nil, nil
  end
  if #names > 1 then
    fail_loud(
      "Read Radar Tracks: expected exactly one Create Radar monitor, found " ..
        tostring(#names)
    )
  end
  return wrap_named(names[1]), names[1]
end

local function vector_has_numeric_xyz(vector)
  if type(vector) ~= "table" then
    return false
  end
  if type(vector.x) ~= "number" then
    return false
  end
  if type(vector.y) ~= "number" then
    return false
  end
  if type(vector.z) ~= "number" then
    return false
  end
  return true
end

local function required_row_failure(row)
  if type(row) ~= "table" then
    return "Read Radar Tracks: track row is not a table"
  end
  if row.id == nil then
    return "Read Radar Tracks: track id is missing"
  end
  if type(row.id) ~= "string" then
    return "Read Radar Tracks: track id is " ..
      diagnostic_type(row.id) .. ", expected string"
  end
  if row.id == "" then
    return "Read Radar Tracks: track id is empty"
  end
  if row.position == nil then
    return "Read Radar Tracks: track '" .. row.id .. "' position is missing"
  end
  if type(row.position) ~= "table" then
    return "Read Radar Tracks: track '" .. row.id ..
      "' position is " .. diagnostic_type(row.position) .. ", expected table"
  end
  if not vector_has_numeric_xyz(row.position) then
    return "Read Radar Tracks: track '" .. row.id ..
      "' position lacks numeric x/y/z"
  end
  if row.velocity == nil then
    return "Read Radar Tracks: track '" .. row.id .. "' velocity is missing"
  end
  if type(row.velocity) ~= "table" then
    return "Read Radar Tracks: track '" .. row.id ..
      "' velocity is " .. diagnostic_type(row.velocity) .. ", expected table"
  end
  if not vector_has_numeric_xyz(row.velocity) then
    return "Read Radar Tracks: track '" .. row.id ..
      "' velocity lacks numeric x/y/z"
  end
  return nil
end

local function apply_optional_fields(track_map)
  local scanned_time = track_map.scannedTime
  if scanned_time == nil then
    track_map.scannedTime = nil
  elseif type(scanned_time) ~= "number" then
    fail_loud(
      "Read Radar Tracks: track '" .. track_map.id ..
        "' scannedTime is " .. diagnostic_type(scanned_time) ..
        ", expected number"
    )
  end
  local category = track_map.category
  if category == nil then
    track_map.category = ""
  elseif type(category) ~= "string" then
    fail_loud(
      "Read Radar Tracks: track '" .. track_map.id ..
        "' category returned " .. diagnostic_type(category) ..
        ", expected string"
    )
  end
  local entity_type = track_map.entityType
  if entity_type == nil then
    track_map.entityType = ""
  elseif type(entity_type) ~= "string" then
    fail_loud(
      "Read Radar Tracks: track '" .. track_map.id ..
        "' entityType returned " .. diagnostic_type(entity_type) ..
        ", expected string"
    )
  end
end

local function read_track_list(dish)
  local ok, tracks_or_error = pcall(dish.getTracks)
  if not ok then
    fail_loud(
      "Read Radar Tracks: getTracks threw: " ..
        tostring(tracks_or_error)
    )
  end
  local tracks = tracks_or_error
  if type(tracks) ~= "table" then
    fail_loud(
      "Read Radar Tracks: getTracks returned " ..
        diagnostic_type(tracks) .. ", expected list"
    )
  end
  if not is_dense_list(tracks) then
    fail_loud(
      "Read Radar Tracks: getTracks returned a table that is not a list of maps"
    )
  end
  local sanitized = {}
  local index = 1
  while index <= #tracks do
    local row = tracks[index]
    local shape_failure = required_row_failure(row)
    if shape_failure ~= nil then
      fail_loud(shape_failure)
    end
    local copy = copy_map(row)
    apply_optional_fields(copy)
    sanitized[index] = copy
    index = index + 1
  end
  return sanitized
end

local function id_in_list(tracks, track_id)
  local index = 1
  while index <= #tracks do
    if tracks[index].id == track_id then
      return true
    end
    index = index + 1
  end
  return false
end

local function read_selection(monitor, monitor_name, tracks)
  local id_ok, selected_id_or_error = pcall(monitor.getSelectedTrackId)
  if not id_ok then
    fail_loud(
      "Read Radar Tracks: getSelectedTrackId threw on monitor '" ..
        monitor_name .. "': " .. tostring(selected_id_or_error)
    )
  end
  local selected_id = selected_id_or_error
  if type(selected_id) ~= "string" then
    fail_loud(
      "Read Radar Tracks: getSelectedTrackId on monitor '" ..
        monitor_name .. "' returned " .. diagnostic_type(selected_id) ..
        ", expected string"
    )
  end
  local track_ok, selected_map_or_error = pcall(monitor.getSelectedTrack)
  if not track_ok then
    fail_loud(
      "Read Radar Tracks: getSelectedTrack threw on monitor '" ..
        monitor_name .. "': " .. tostring(selected_map_or_error)
    )
  end
  local selected_map = selected_map_or_error
  if type(selected_map) ~= "table" then
    fail_loud(
      "Read Radar Tracks: getSelectedTrack on monitor '" ..
        monitor_name .. "' returned " .. diagnostic_type(selected_map) ..
        ", expected table"
    )
  end
  if selected_id == "" then
    return nil, nil
  end
  if is_empty_table(selected_map) then
    return nil, selected_id
  end
  if required_row_failure(selected_map) ~= nil then
    return nil, selected_id
  end
  if selected_map.id ~= selected_id then
    return nil, selected_id
  end
  if not id_in_list(tracks, selected_id) then
    return nil, selected_id
  end
  local copy = copy_map(selected_map)
  apply_optional_fields(copy)
  return copy, selected_id
end

local function read_radar_tracks(...)
  local opts = parse_opts(...)
  local radar_name = optional_name(opts.radar_name, "radar_name")
  local monitor_name = optional_name(opts.monitor_name, "monitor_name")
  local dish = resolve_dish(radar_name)
  local tracks = read_track_list(dish)
  local monitor, resolved_monitor_name = resolve_monitor(monitor_name)
  local result = {
    tracks = tracks,
  }
  if monitor == nil then
    return result
  end
  local selected_track, selected_track_id = read_selection(
    monitor,
    resolved_monitor_name,
    tracks
  )
  result.selectedTrack = selected_track
  result.selectedTrackId = selected_track_id
  return result
end

local bearing_turret = {
  read_radar_tracks = read_radar_tracks,
}

return bearing_turret
