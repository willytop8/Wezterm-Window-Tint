local wezterm = require 'wezterm'
local config = wezterm.config_builder()

require('wezterm-window-tint').apply_to_config(config, {
  show_badge = true,
  set_retro_tab_bar = true,
})

return config
