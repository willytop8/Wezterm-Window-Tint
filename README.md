# WezTerm Window Tint

Project-aware window tinting for [WezTerm](https://wezterm.org/).

WezTerm Window Tint colors your terminal window based on the project in the
active tab or pane. Open several terminals across several repositories and the
active project gets an immediate, subtle visual identity.

It is a WezTerm Lua module, not a binary plugin. Drop one file into your
WezTerm config directory, require it from `wezterm.lua`, and reload.

![WezTerm Window Tint showing project-colored terminal tabs and window chrome](docs/screenshot.png)

## What It Does

- Finds the active pane's current working directory through WezTerm.
- Walks upward to the nearest parent containing `.git`.
- Uses that git root as the project key; if no `.git` exists, uses cwd.
- Falls back to a pane-scoped key if cwd is unavailable.
- Assigns runtime-scoped colors from a curated 12-color palette.
- Prefers unused palette slots for the first 12 distinct projects.
- Retints the window when the active tab/pane changes.
- Retints after live `cd` changes when WezTerm receives cwd updates through
  shell integration or OSC 7.
- Tints the window frame, tab bar, active tab, inactive tab text, and optional
  status badge.

Colors intentionally reshuffle after restarting WezTerm. The goal is quick
session identity, not permanent project branding.

## Install

Copy the module into your WezTerm config directory:

```sh
mkdir -p ~/.config/wezterm
cp wezterm-window-tint.lua ~/.config/wezterm/wezterm-window-tint.lua
```

Then add this to `~/.config/wezterm/wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

require('wezterm-window-tint').apply_to_config(config, {
  show_badge = true,
  set_retro_tab_bar = true,
})

return config
```

If you already have a `wezterm.lua`, keep your existing config and add only the
`require(...).apply_to_config(config, ...)` call before `return config`.

Reload WezTerm with `Cmd+Shift+R` on macOS, or quit and reopen it.

## Options

```lua
require('wezterm-window-tint').apply_to_config(config, {
  show_badge = true,
  set_retro_tab_bar = true,
  retint_interval_seconds = 1,
  palette = {
    { name = 'rose', hex = '#fb7185' },
    { name = 'orange', hex = '#fb923c' },
    { name = 'amber', hex = '#fbbf24' },
  },
})
```

- `show_badge`: show a left status badge with the color name and project path.
- `set_retro_tab_bar`: set `use_fancy_tab_bar = false` for reliable tab tinting.
- `retint_interval_seconds`: status update interval used to refresh the active
  pane's cwd.
- `palette`: optional list of `{ name, hex }` entries.

## Live `cd` Retinting

WezTerm can track cwd through shell integration and OSC 7. If changing
directories does not retint the window, add this to `~/.zshrc`:

```zsh
_osc7_cwd() {
  printf '\e]7;file://%s%s\e\\' "${HOST:-localhost}" "$PWD"
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _osc7_cwd
add-zsh-hook precmd _osc7_cwd
```

Then restart your shell.

## Test Checklist

1. Open one tab in repo A and another in repo B.
2. Switch tabs and confirm the window tint follows the active project.
3. Open two tabs inside the same repo and confirm they share a color.
4. `cd` from repo A into repo B and confirm the tint updates.
5. `cd` into a non-git directory and confirm it gets its own cwd color.
6. Restart WezTerm and confirm colors reshuffle.

## Limitations

- WezTerm does not expose Hyper-style CSS hooks, so this uses native WezTerm
  frame, tab bar, and status APIs.
- `format-tab-title` is a single global event. If your config already defines
  one, you will need to merge the handlers manually.
- Runtime `window:set_config_overrides()` may conflict with other config code
  that also rewrites `window_frame` or `colors.tab_bar`.
- Fancy/native tab bars offer less tint control. Retro tab bar mode is enabled
  by default through `set_retro_tab_bar = true`.

## Credits

This was built as a WezTerm replacement for
[Hyper-WindowTint](https://github.com/willytop8/Hyper-WindowTint).

## License

MIT
