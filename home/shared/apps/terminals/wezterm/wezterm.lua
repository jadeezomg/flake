local wezterm = require("wezterm")

-- Load modules
local decoration = require("decoration")
local fonts = require("fonts")
local keys = require("keys")
local colors = require("colors")

-- Detect platform using target_triple
local platform = "linux"
local target_triple = wezterm.target_triple
if target_triple:match("windows") or target_triple:match("msvc") then
	platform = "windows"
elseif target_triple:match("darwin") or target_triple:match("apple") then
	platform = "macos"
elseif target_triple:match("linux") then
	platform = "linux"
end
-- Setup modules
local config = wezterm.config_builder()

-- Setup colors first so color schemes are available for decoration
colors.setup(config)
decoration.setup(config, platform)
fonts.setup(config, platform)
keys.setup(config, platform)

-- Default shell: nushell
if platform == "windows" then
	config.default_prog = { "nu", "-l" }
	config.launch_menu = {
		{
			label = "Pwsh",
			args = { "pwsh.exe" },
		},
		{
			label = "PowerShell",
			args = { "powershell.exe" },
		},
		{
			label = "CMD",
			args = { "cmd.exe" },
		},
	}
elseif platform == "macos" then
	config.default_prog = { "nu", "-l" }
	config.launch_menu = {
		{
			label = "Nushell",
			args = { "nu", "-l" },
		},
		{
			label = "Fish",
			args = { "fish", "-l" },
		},
		{
			label = "Bash",
			args = { "/bin/bash", "-l" },
		},
		{
			label = "Zsh",
			args = { "/bin/zsh", "-l" },
		},
	}
elseif platform == "linux" then
	config.default_prog = { "nu", "-l" }
	config.launch_menu = {
		{
			label = "Nushell",
			args = { "nu", "-l" },
		},
		{
			label = "Fish",
			args = { "fish", "-l" },
		},
		{
			label = "Bash",
			args = { "bash", "-l" },
		},
	}
end

-- Default color scheme (with fallback)
config.color_scheme = config.color_scheme or "Birds of Paradise"

-- Enable scrollback
config.scrollback_lines = 10000

-- Window Configuration
config.initial_rows = 40
config.initial_cols = 130

-- Performance Settings
config.max_fps = 144
config.animation_fps = 60
config.cursor_blink_rate = 250

-- Hyperlinks are enabled by default in wezterm
config.hyperlink_rules = wezterm.default_hyperlink_rules()

return config
