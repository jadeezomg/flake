local wezterm = require("wezterm")

local M = {}
local SOLID_LEFT_ARROW = wezterm.nerdfonts.pl_right_hard_divider
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.pl_left_hard_divider


function M.tab_title(tab_info)
    local title = tab_info.tab_title
    -- if the tab title is explicitly set, take that
    if title and #title > 0 then
        return title
    end
    -- Otherwise, use the title from the active pane
    -- in that tab
    return tab_info.active_pane.title
end

-- Extract shell name from pane process or title
function M.get_shell_name(pane)
    -- Try to get shell from user vars first (if set by shell integration)
    local user_vars = pane:get_user_vars()
    if user_vars and user_vars.SHELL then
        local shell_path = user_vars.SHELL
        -- Extract just the shell name (e.g., "nu" from "/nix/store/.../bin/nu")
        local shell_name = shell_path:match("([^/]+)$")
        return shell_name or "shell"
    end

    -- Try to get from process name
    local process_name = pane:get_foreground_process_name()
    if process_name then
        -- Extract shell name from process path
        local shell_name = process_name:match("([^/]+)$")
        -- Remove common suffixes and extensions
        shell_name = shell_name:gsub("%.exe$", ""):gsub("%-l$", "")
        -- Map common shell names
        if shell_name == "nu" or shell_name:match("nu") then
            return "nu"
        elseif shell_name == "fish" or shell_name:match("fish") then
            return "fish"
        elseif shell_name == "bash" or shell_name:match("bash") then
            return "bash"
        elseif shell_name == "zsh" or shell_name:match("zsh") then
            return "zsh"
        elseif shell_name == "powershell" or shell_name:match("pwsh") or shell_name:match("powershell") then
            return "pwsh"
        elseif shell_name == "cmd" or shell_name:match("cmd") then
            return "cmd"
        end
        return shell_name
    end

    -- Fallback: try to extract from pane title
    local pane_title = pane.title
    if pane_title then
        -- Look for common shell patterns in title
        if pane_title:match("nu") then
            return "nu"
        elseif pane_title:match("fish") then
            return "fish"
        elseif pane_title:match("bash") then
            return "bash"
        elseif pane_title:match("zsh") then
            return "zsh"
        end
    end

    return nil
end

wezterm.on(
    'format-tab-title',
    function(tab, tabs, panes, config, hover, max_width)
        -- Get the current color scheme to use theme colors
        -- Colors are sourced from theme.nix via colors.lua
        local color_scheme = config.color_schemes[config.color_scheme] or {}
        local tab_bar_colors = color_scheme.tab_bar or {}

        -- Use theme colors from color scheme (registered in colors.lua)
        local edge_background = tab_bar_colors.background or tab_bar_colors.inactive_tab.bg_color
        local inactive_tab = tab_bar_colors.inactive_tab or {}
        local active_tab = tab_bar_colors.active_tab or {}
        local hover_tab = tab_bar_colors.inactive_tab_hover or active_tab

        local background = inactive_tab.bg_color or edge_background
        local foreground = inactive_tab.fg_color

        if tab.is_active then
            background = active_tab.bg_color or background
            foreground = active_tab.fg_color or foreground
        elseif hover then
            background = hover_tab.bg_color or background
            foreground = hover_tab.fg_color or foreground
        end

        local edge_foreground = background

        -- Get the tab title
        local title = M.tab_title(tab)

        -- Get shell name from active pane
        local shell_name = M.get_shell_name(tab.active_pane)

        -- Get ANSI cyan color for shell name (matches terminal colors)
        -- ANSI colors: [1]=black, [2]=red, [3]=green, [4]=yellow, [5]=blue, [6]=magenta, [7]=cyan, [8]=white
        local shell_color = (color_scheme.ansi and color_scheme.ansi[7]) or
            (color_scheme.brights and color_scheme.brights[7]) or
            "#85b4bb"

        -- Calculate space needed for shell name display
        local shell_display_width = 0
        if shell_name then
            shell_display_width = #shell_name + 3 -- "[shell]"
        end

        -- Calculate available width for title (account for edges and shell name)
        local available_width = max_width - 2 - shell_display_width -- 2 for edges
        local min_title_width = 10                                  -- Minimum characters for title
        if available_width < min_title_width then
            available_width = min_title_width
        end

        -- Truncate title to fit available space
        local truncated_title = wezterm.truncate_right(title, available_width)

        -- Build the formatted tab title with colored shell name
        local result = {
            { Background = { Color = edge_background } },
            { Foreground = { Color = edge_foreground } },
            { Text = SOLID_LEFT_ARROW },
            { Background = { Color = background } },
            { Foreground = { Color = foreground } },
        }

        -- Add title text
        result[#result + 1] = { Text = truncated_title }

        -- Add shell name if available
        if shell_name then
            -- Add separator
            result[#result + 1] = { Text = " [" }
            -- Add shell name with cyan color (terminal color)
            result[#result + 1] = { Foreground = { Color = shell_color }, Text = shell_name }
            -- Add closing bracket with normal foreground
            result[#result + 1] = { Foreground = { Color = foreground }, Text = "]" }
        end

        -- Add closing edge
        result[#result + 1] = { Background = { Color = edge_background } }
        result[#result + 1] = { Foreground = { Color = edge_foreground } }
        result[#result + 1] = { Text = SOLID_RIGHT_ARROW }

        return result
    end
)

function M.setup(config, platform)
    if platform == "windows" then
        config.window_background_opacity = 0.5
        config.win32_system_backdrop = "Acrylic"
        config.win32_acrylic_accent_color = "rgb(40, 56, 54)"
        config.webgpu_power_preference = "HighPerformance"
        config.front_end = "OpenGL"
        config.prefer_egl = true
        config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
    elseif platform == "macos" then
        config.window_background_opacity = 0.85
        config.macos_window_background_blur = 40
        config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
        config.native_macos_fullscreen_mode = true
    elseif platform == "linux" then
        -- config.window_background_opacity = 0.9
        config.window_decorations = "INTEGRATED_BUTTONS | RESIZE"
        config.integrated_title_button_style = "Gnome"
        -- config.window_decorations = "RESIZE"
    end

    -- Common settings for all platforms
    -- Tab Bar Configuration
    config.enable_tab_bar = true
    -- config.hide_tab_bar_if_only_one_tab = true
    -- config.show_tab_index_in_tab_bar = false
    -- config.use_fancy_tab_bar = false
    --config.tab_bar_at_bottom = false
    -- config.tab_max_width = 50

    -- config.default_cursor_style = "BlinkingBar"
    -- config.window_padding = {
    --     left = 15,
    --     right = 15,
    --     top = 0,
    --     bottom = 15,
    -- }
    --  config.cell_width = 0.9

    -- Get theme colors from the registered color scheme
    -- Colors are sourced from theme.nix via colors.lua
    -- Note: colors.setup() must be called before decoration.setup()
    local color_schemes = config.color_schemes or {}
    local color_scheme_name = config.color_scheme or "Birds of Paradise"
    local color_scheme = color_schemes[color_scheme_name] or {}
    local tab_bar_colors = color_scheme.tab_bar or {}
    local bg_secondary = tab_bar_colors.background or "#2e201f"
    local inactive_tab = tab_bar_colors.inactive_tab or {}
    local active_tab = tab_bar_colors.active_tab or {}
    local new_tab = tab_bar_colors.new_tab or {}
    local new_tab_hover = tab_bar_colors.new_tab_hover or {}

    -- Initialize config.colors for retro tab bar styling
    -- This is used when use_fancy_tab_bar = false
    -- Reference: https://wezterm.org/config/appearance.html#dynamic-color-escape-sequences
    config.colors = config.colors or {}
    config.colors.tab_bar = {
        -- The color of the strip that goes along the top of the window
        background = config.window_background_image and "rgba(0, 0, 0, 0)" or bg_secondary,
        -- The color of the inactive tab bar edge/divider
        inactive_tab_edge = inactive_tab.bg_color or bg_secondary,
        -- Active tab colors
        active_tab = {
            bg_color = active_tab.bg_color or bg_secondary,
            fg_color = active_tab.fg_color or color_scheme.foreground,
            intensity = active_tab.intensity or "Normal",
            underline = active_tab.underline or "None",
            italic = active_tab.italic or false,
            strikethrough = active_tab.strikethrough or false,
        },
        -- Inactive tab colors
        inactive_tab = {
            bg_color = inactive_tab.bg_color or bg_secondary,
            fg_color = inactive_tab.fg_color or color_scheme.foreground,
            intensity = inactive_tab.intensity or "Normal",
            underline = inactive_tab.underline or "None",
            italic = inactive_tab.italic or false,
            strikethrough = inactive_tab.strikethrough or false,
        },
        -- Inactive tab hover colors
        inactive_tab_hover = {
            bg_color = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.bg_color or
                active_tab.bg_color,
            fg_color = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.fg_color or
                active_tab.fg_color,
            intensity = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.intensity or "Normal",
            underline = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.underline or "None",
            italic = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.italic or false,
            strikethrough = tab_bar_colors.inactive_tab_hover and tab_bar_colors.inactive_tab_hover.strikethrough or
                false,
        },
        -- New tab button colors
        new_tab = {
            bg_color = new_tab.bg_color or bg_secondary,
            fg_color = new_tab.fg_color or inactive_tab.fg_color,
            intensity = new_tab.intensity or "Normal",
            underline = new_tab.underline or "None",
            italic = new_tab.italic or false,
            strikethrough = new_tab.strikethrough or false,
        },
        -- New tab hover colors
        new_tab_hover = {
            bg_color = new_tab_hover.bg_color or active_tab.bg_color,
            fg_color = new_tab_hover.fg_color or active_tab.fg_color,
            intensity = new_tab_hover.intensity or "Normal",
            underline = new_tab_hover.underline or "None",
            italic = new_tab_hover.italic or false,
            strikethrough = new_tab_hover.strikethrough or false,
        },
    }

    config.window_frame = {
        -- The overall background color of the tab bar when
        -- the window is focused (use theme bg-secondary from color scheme)
        active_titlebar_bg = color_scheme.foreground,

        -- The overall background color of the tab bar when
        -- the window is not focused (use theme bg-secondary from color scheme)
        inactive_titlebar_bg = color_scheme.background,

        -- Button colors to match theme (from color scheme)
        button_fg = inactive_tab.fg_color or "#DDDDDD",     -- text-tertiary
        button_bg = bg_secondary,                           -- bg-secondary
        button_hover_fg = active_tab.fg_color or "#E6E1C4", -- text-primary
        button_hover_bg = active_tab.bg_color or "#5B413D", -- bg-tertiary
    }
end

return M
