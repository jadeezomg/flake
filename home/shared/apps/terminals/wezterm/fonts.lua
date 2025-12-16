local wezterm = require("wezterm")

local M = {}

function M.setup(config, platform)
	-- Font configuration with platform-specific fallbacks
	-- Font names may vary across platforms, so we provide multiple options
	local font_families = {
		{
			family = "Iosevka Nerd Font",
		},
		{
			family = "Iosevka",
		},
		{
			family = "FiraMono Nerd Font",
		},
		{
			family = "Fira Code",
		},
		{
			family = "Hack Nerd Font",
		},
		{
			family = "Hack",
		},
	}

	-- Add platform-specific fallback fonts
	if platform == "windows" then
		-- Windows often has Consolas and Cascadia Code
		table.insert(font_families, { family = "Cascadia Code" })
		table.insert(font_families, { family = "Consolas" })
	elseif platform == "macos" then
		-- macOS has Menlo and SF Mono
		table.insert(font_families, { family = "SF Mono" })
		table.insert(font_families, { family = "Menlo" })
	elseif platform == "linux" then
		-- Linux common fonts
		table.insert(font_families, { family = "DejaVu Sans Mono" })
		table.insert(font_families, { family = "Liberation Mono" })
	end

	config.font = wezterm.font_with_fallback(font_families)
	config.font_size = 12
	-- config.underline_thickness = "200%"
	-- config.underline_position = "-3pt"
	-- config.adjust_window_size_when_changing_font_size = false

	-- Window frame font with fallbacks
	local frame_font_families = {
		"IosevkaTerm NFM",
		"Iosevka Term",
		"FiraMono Nerd Font",
		"Fira Code",
	}

	if platform == "windows" then
		table.insert(frame_font_families, "Segoe UI")
	elseif platform == "macos" then
		table.insert(frame_font_families, "SF Pro Display")
		table.insert(frame_font_families, "Helvetica Neue")
	elseif platform == "linux" then
		table.insert(frame_font_families, "DejaVu Sans")
		table.insert(frame_font_families, "Liberation Sans")
	end

	config.window_frame = {
		font = wezterm.font_with_fallback(frame_font_families),
		font_size = 11,
	}
end

return M
