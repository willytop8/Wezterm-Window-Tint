local wezterm = require 'wezterm'

local M = {}

local palette = {
  { name = 'rose', hex = '#fb7185' },
  { name = 'orange', hex = '#fb923c' },
  { name = 'amber', hex = '#fbbf24' },
  { name = 'lime', hex = '#a3e635' },
  { name = 'emerald', hex = '#34d399' },
  { name = 'teal', hex = '#2dd4bf' },
  { name = 'cyan', hex = '#22d3ee' },
  { name = 'sky', hex = '#38bdf8' },
  { name = 'indigo', hex = '#818cf8' },
  { name = 'violet', hex = '#a78bfa' },
  { name = 'fuchsia', hex = '#e879f9' },
  { name = 'pink', hex = '#f472b6' },
}

local config_opts = {
  palette = palette,
  show_badge = true,
  retint_interval_seconds = 1,
  set_retro_tab_bar = true,
}

local project_colors = {}
local project_roots = {}
local used_indices = {}
local used_index_count = 0
local window_state = {}

math.randomseed(os.time())

local function fnv1a(str)
  local hash = 2166136261
  for i = 1, #str do
    hash = hash ~ string.byte(str, i)
    hash = (hash * 16777619) & 0xffffffff
  end
  return hash
end

local function hash_to_index(seed, count)
  return (fnv1a(tostring(seed or 'default')) % count) + 1
end

local function exists(path)
  if not path or path == '' then
    return false
  end
  local ok = os.rename(path, path)
  return ok == true
end

local function dirname(path)
  if not path or path == '' or path == '/' then
    return nil
  end
  local trimmed = path:gsub('/+$', '')
  local parent = trimmed:match('^(.*)/[^/]+$')
  if parent == '' then
    return '/'
  end
  return parent
end

local function cwd_from_uri(uri)
  if not uri then
    return nil
  end

  if type(uri) == 'userdata' or type(uri) == 'table' then
    local ok, path = pcall(function()
      return uri.file_path
    end)
    if ok and type(path) == 'string' and path ~= '' then
      return path
    end
  end

  local value = tostring(uri)
  local path = value:match('^file://[^/]*(/.*)$')
  if path then
    local ok, parsed = pcall(wezterm.url.parse, value)
    if ok and parsed and parsed.file_path then
      return parsed.file_path
    end
  end
  return value ~= '' and value or nil
end

local function project_root_for_cwd(cwd)
  if not cwd or cwd == '' then
    return nil
  end
  if project_roots[cwd] then
    return project_roots[cwd]
  end

  local dir = cwd:gsub('/+$', '')
  local root = dir
  while dir do
    if exists(dir .. '/.git') then
      root = dir
      break
    end
    dir = dirname(dir)
  end

  project_roots[cwd] = root
  return root
end

local function random_seed(root, attempt)
  return table.concat({
    'windowtint',
    tostring(os.time()),
    tostring(math.random()),
    tostring(attempt or 0),
    tostring(root or ''),
  }, ':')
end

local function assign_color(root)
  if not root or root == '' then
    return nil
  end
  if project_colors[root] then
    return project_colors[root]
  end

  local colors = config_opts.palette
  local seed = nil
  if used_index_count < #colors then
    for attempt = 1, 200 do
      local candidate = random_seed(root, attempt)
      local index = hash_to_index(candidate, #colors)
      if not used_indices[index] then
        seed = candidate
        break
      end
    end
  end
  if not seed then
    seed = random_seed(root)
  end

  local index = hash_to_index(seed, #colors)
  if not used_indices[index] then
    used_indices[index] = true
    used_index_count = used_index_count + 1
  end
  local color = {
    name = colors[index].name,
    hex = colors[index].hex,
    root = root,
    seed = seed,
    index = index,
  }
  project_colors[root] = color
  return color
end

local function color_for_pane(pane)
  if not pane then
    return nil
  end

  local cwd = cwd_from_uri(pane:get_current_working_dir())
  local root = project_root_for_cwd(cwd)
  if not root then
    root = 'pane:' .. tostring(pane:pane_id())
  end
  return assign_color(root)
end

local function merge_table(base, patch)
  local result = {}
  for key, value in pairs(base or {}) do
    result[key] = value
  end
  for key, value in pairs(patch or {}) do
    result[key] = value
  end
  return result
end

local function compact_root(root)
  local home = os.getenv('HOME')
  if home and home ~= '' and root:sub(1, #home) == home then
    return '~' .. root:sub(#home + 1)
  end
  return root
end

local function apply_window_tint(window, pane, color)
  if not window or not color then
    return
  end

  local id = tostring(window:window_id())
  local signature = color.root .. ':' .. color.hex
  if window_state[id] == signature then
    return
  end
  window_state[id] = signature

  local overrides = window:get_config_overrides() or {}
  local frame = merge_table(overrides.window_frame, {
    active_titlebar_bg = color.hex,
    inactive_titlebar_bg = '#161616',
    active_titlebar_fg = '#111111',
    inactive_titlebar_fg = '#9a9a9a',
    border_left_color = color.hex,
    border_right_color = color.hex,
    border_bottom_color = color.hex,
    border_top_color = color.hex,
    border_left_width = '0.12cell',
    border_right_width = '0.12cell',
    border_bottom_height = '0.12cell',
    border_top_height = '0.12cell',
  })

  local colors = merge_table(overrides.colors, {
    tab_bar = merge_table(overrides.colors and overrides.colors.tab_bar, {
      background = '#111111',
      active_tab = {
        bg_color = color.hex,
        fg_color = '#111111',
        intensity = 'Bold',
      },
      inactive_tab = {
        bg_color = '#1c1c1c',
        fg_color = '#c6c6c6',
      },
      inactive_tab_hover = {
        bg_color = '#262626',
        fg_color = color.hex,
      },
      new_tab = {
        bg_color = '#111111',
        fg_color = color.hex,
      },
    }),
  })

  overrides.window_frame = frame
  overrides.colors = colors
  window:set_config_overrides(overrides)

  if config_opts.show_badge then
    window:set_left_status(wezterm.format({
      { Background = { Color = color.hex } },
      { Foreground = { Color = '#111111' } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = '  ' .. string.upper(color.name) .. '  ' },
      { Background = { Color = '#111111' } },
      { Foreground = { Color = color.hex } },
      { Text = ' ' .. compact_root(color.root) .. ' ' },
    }))
  end
end

local function tab_title(tab)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  end
  return (tab.active_pane and tab.active_pane.title) or 'wezterm'
end

function M.apply_to_config(config, opts)
  config_opts = merge_table(config_opts, opts or {})
  if type(config_opts.palette) ~= 'table' or #config_opts.palette == 0 then
    config_opts.palette = palette
  end

  if config_opts.set_retro_tab_bar then
    config.use_fancy_tab_bar = false
  end
  config.status_update_interval = config_opts.retint_interval_seconds * 1000

  wezterm.on('update-status', function(window, pane)
    apply_window_tint(window, pane, color_for_pane(pane))
  end)

  wezterm.on('format-tab-title', function(tab, tabs, panes, config_, hover, max_width)
    local pane_info = tab.active_pane
    local color = nil
    if pane_info and pane_info.current_working_dir then
      local root = project_root_for_cwd(cwd_from_uri(pane_info.current_working_dir))
      color = assign_color(root)
    end
    local title = wezterm.truncate_right(tab_title(tab), math.max(1, max_width - 3))

    if tab.is_active and color then
      return {
        { Background = { Color = color.hex } },
        { Foreground = { Color = '#111111' } },
        { Attribute = { Intensity = 'Bold' } },
        { Text = ' ' .. title .. ' ' },
      }
    end

    if color then
      return {
        { Background = { Color = '#1c1c1c' } },
        { Foreground = { Color = color.hex } },
        { Text = ' ' .. title .. ' ' },
      }
    end

    return {
      { Text = ' ' .. title .. ' ' },
    }
  end)
end

return M
