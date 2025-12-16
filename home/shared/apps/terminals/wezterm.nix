{pkgs, ...}: let
  # Import theme colors
  themeColors = import ../../assets/theme/theme.nix;
in {
  programs.wezterm = {
    enable = true;
  };

  # Place the main wezterm.lua config file
  home.file.".config/wezterm/wezterm.lua".source = ./wezterm/wezterm.lua;

  # Place the Lua module files in the wezterm config directory
  home.file.".config/wezterm/decoration.lua".source = ./wezterm/decoration.lua;
  home.file.".config/wezterm/fonts.lua".source = ./wezterm/fonts.lua;
  home.file.".config/wezterm/keys.lua".source = ./wezterm/keys.lua;

  # Generate colors.lua from theme.nix
  home.file.".config/wezterm/colors.lua".text = ''
    local wezterm = require("wezterm")

    local M = {}

    -- Birds of Paradise Color Scheme
    -- Generated from theme.nix - DO NOT EDIT MANUALLY
    -- Colors are sourced from: ../../assets/theme/theme.nix
    function M.get_scheme()
    	return {
    		-- Foreground and background
    		foreground = "${themeColors.text-primary}",
    		background = "${themeColors.bg-primary}",

    		-- Cursor colors
    		cursor_bg = "${themeColors.text-primary}",
    		cursor_border = "${themeColors.text-primary}",
    		cursor_fg = "${themeColors.bg-primary}",

    		-- Selection colors
    		selection_bg = "${themeColors.bg-tertiary}",
    		selection_fg = "${themeColors.text-primary}",

    		-- ANSI colors (standard terminal colors)
    		ansi = {
    			"${themeColors.ansi-black}",
    			"${themeColors.ansi-red}",
    			"${themeColors.ansi-green}",
    			"${themeColors.ansi-yellow}",
    			"${themeColors.ansi-blue}",
    			"${themeColors.ansi-magenta}",
    			"${themeColors.ansi-cyan}",
    			"${themeColors.ansi-white}",
    		},

    		-- Bright ANSI colors
    		brights = {
    			"${themeColors.ansi-bright-black}",
    			"${themeColors.ansi-bright-red}",
    			"${themeColors.ansi-bright-green}",
    			"${themeColors.ansi-bright-yellow}",
    			"${themeColors.ansi-bright-blue}",
    			"${themeColors.ansi-bright-magenta}",
    			"${themeColors.ansi-bright-cyan}",
    			"${themeColors.ansi-bright-white}",
    		},

    		-- Tab bar colors
    		tab_bar = {
    			-- Background of the tab bar
    			background = "${themeColors.bg-secondary}",

    			-- Active tab
    			active_tab = {
    				bg_color = "${themeColors.bg-tertiary}",
    				fg_color = "${themeColors.text-primary}",
    				intensity = "Normal",
    				underline = "None",
    				italic = false,
    				strikethrough = false,
    			},

    			-- Inactive tab
    			inactive_tab = {
    				bg_color = "${themeColors.bg-secondary}",
    				fg_color = "${themeColors.text-tertiary}",
    				intensity = "Normal",
    				underline = "None",
    				italic = false,
    				strikethrough = false,
    			},

    			-- Inactive tab hover
    			inactive_tab_hover = {
    				bg_color = "${themeColors.bg-tertiary}",
    				fg_color = "${themeColors.text-primary}",
    				intensity = "Normal",
    				underline = "None",
    				italic = false,
    				strikethrough = false,
    			},

    			-- New tab button
    			new_tab = {
    				bg_color = "${themeColors.bg-secondary}",
    				fg_color = "${themeColors.text-tertiary}",
    				intensity = "Normal",
    				underline = "None",
    				italic = false,
    				strikethrough = false,
    			},

    			-- New tab hover
    			new_tab_hover = {
    				bg_color = "${themeColors.bg-tertiary}",
    				fg_color = "${themeColors.accent-yellow}",
    				intensity = "Normal",
    				underline = "None",
    				italic = false,
    				strikethrough = false,
    			},
    		},

    		-- Split pane divider
    		split = "${themeColors.sidebar-border}",

    		-- Visual bell (flash) color
    		visual_bell = "${themeColors.accent-red}",

    		-- Indexed colors (256-color mode)
    		indexed = {
    			[16] = "${themeColors.ansi-bright-black}",
    			[17] = "${themeColors.ansi-bright-red}",
    			[18] = "${themeColors.ansi-bright-green}",
    			[19] = "${themeColors.ansi-bright-yellow}",
    			[20] = "${themeColors.ansi-bright-blue}",
    			[21] = "${themeColors.ansi-bright-magenta}",
    			[22] = "${themeColors.ansi-bright-cyan}",
    			[23] = "${themeColors.ansi-bright-white}",
    		},
    	}
    end

    -- Register the color scheme with wezterm
    function M.setup(config)
    	-- Register the color scheme
    	config.color_schemes = config.color_schemes or {}
    	config.color_schemes["Birds of Paradise"] = M.get_scheme()
    end

    return M
  '';
}
