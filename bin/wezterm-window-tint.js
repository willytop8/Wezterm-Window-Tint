#!/usr/bin/env node

'use strict'

const fs = require('fs')
const os = require('os')
const path = require('path')

const packageRoot = path.resolve(__dirname, '..')
const sourceFile = path.join(packageRoot, 'wezterm-window-tint.lua')
const defaultConfigDir = path.join(os.homedir(), '.config', 'wezterm')

function printHelp() {
  console.log(`WezTerm Window Tint

Usage:
  wezterm-window-tint install [--force] [--dry-run] [--config-dir <path>]
  wezterm-window-tint help

Options:
  --force              Overwrite an existing wezterm-window-tint.lua file.
  --dry-run            Show what would happen without writing files.
  --config-dir <path>  Install into a custom WezTerm config directory.

Recommended native WezTerm install:
  local window_tint = wezterm.plugin.require('https://github.com/willytop8/Wezterm-Window-Tint')
`)
}

function parseArgs(argv) {
  const options = {
    command: argv[0] || 'help',
    configDir: process.env.WEZTERM_CONFIG_DIR || defaultConfigDir,
    dryRun: false,
    force: false,
  }

  for (let index = 1; index < argv.length; index += 1) {
    const arg = argv[index]

    if (arg === '--force') {
      options.force = true
    } else if (arg === '--dry-run') {
      options.dryRun = true
    } else if (arg === '--config-dir') {
      index += 1
      if (!argv[index]) {
        throw new Error('--config-dir requires a path')
      }
      options.configDir = path.resolve(argv[index])
    } else if (arg.startsWith('--config-dir=')) {
      options.configDir = path.resolve(arg.slice('--config-dir='.length))
    } else {
      throw new Error(`Unknown option: ${arg}`)
    }
  }

  return options
}

function printConfigSnippet() {
  console.log(`
Add this to ~/.config/wezterm/wezterm.lua before returning config:

  require('wezterm-window-tint').apply_to_config(config, {
    show_badge = true,
    set_retro_tab_bar = true,
  })

Then reload WezTerm with Cmd+Shift+R on macOS, or restart WezTerm.
`)
}

function install(options) {
  const targetDir = path.resolve(options.configDir)
  const targetFile = path.join(targetDir, 'wezterm-window-tint.lua')

  if (!fs.existsSync(sourceFile)) {
    throw new Error(`Package file is missing: ${sourceFile}`)
  }

  if (fs.existsSync(targetFile) && !options.force) {
    throw new Error(
      `${targetFile} already exists. Re-run with --force to overwrite it.`
    )
  }

  if (options.dryRun) {
    console.log(`Would create directory: ${targetDir}`)
    console.log(`Would copy: ${sourceFile}`)
    console.log(`To: ${targetFile}`)
    printConfigSnippet()
    return
  }

  fs.mkdirSync(targetDir, { recursive: true })
  fs.copyFileSync(sourceFile, targetFile)

  console.log(`Installed ${targetFile}`)
  printConfigSnippet()
}

function main() {
  const options = parseArgs(process.argv.slice(2))

  if (options.command === 'help' || options.command === '--help' || options.command === '-h') {
    printHelp()
    return
  }

  if (options.command !== 'install') {
    throw new Error(`Unknown command: ${options.command}`)
  }

  install(options)
}

try {
  main()
} catch (error) {
  console.error(`Error: ${error.message}`)
  console.error('Run `wezterm-window-tint help` for usage.')
  process.exitCode = 1
}
