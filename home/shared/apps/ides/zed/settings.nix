{
  lib,
  claude-agent-acp-fork,
  ...
}: {
  programs.zed-editor = {
    userSettings = {
      # --- Appearance ---
      buffer_font_fallbacks = [
        ".ZedMono"
      ];

      buffer_line_height = {
        custom = 1.45;
      };
      buffer_font_features = {
        calt = true;
      };

      icon_theme = "Catppuccin Latte";

      # --- Agent Font ---
      agent_buffer_font_size = 14;

      current_line_highlight = "all";
      selection_highlight = true;
      ui_font_family = lib.mkDefault "Inter Display";
      ui_font_fallbacks = ["Helvetica Neue" ".SystemUIFont"];

      ui_font_features = {
        calt = true;
      };

      # --- Window ---
      window_decorations = "client";
      use_system_window_tabs = false;
      focus_follows_mouse = {
        enabled = true;
      };
      centered_layout = {
        left_padding = 0.2;
      };
      bottom_dock_layout = "contained";
      diff_view_style = "split";
      text_rendering_mode = "platform_default";
      ui_font_weight = 400;
      buffer_font_weight = 400;
      auto_update = false;
      autosave = "on_focus_change";
      session = {
        trust_all_worktrees = true;
      };
      features = {
        copilot = false;
      };

      # --- UI ---
      active_pane_modifiers = {
        border_size = 1;
        inactive_opacity = 0.8;
      };
      rounded_selection = true;
      cursor_shape = "bar";

      # --- Git ---
      git = {
        inline_blame = {
          show_commit_summary = true;
        };
      };
      git_panel = {
        show_count_badge = false;
        diff_stats = true;
        tree_view = true;
        file_icons = false;
        folder_icons = true;
        collapse_untracked_diff = false;
        sort_by_path = true;
      };

      # --- Panels ---
      outline_panel = {
        button = true;
      };
      project_panel = {
        hide_hidden = false;
        hide_root = true;
        indent_guides = {
          show = "always";
        };
        sticky_scroll = true;
        git_status_indicator = false;
        diagnostic_badges = false;
        scrollbar = {
          horizontal_scroll = false;
        };
        bold_folder_labels = false;
        starts_open = true;
        auto_reveal_entries = true;
        indent_size = 12;
        git_status = true;
        folder_icons = true;
        file_icons = true;
        entry_spacing = "standard";
        default_width = 230;
        button = true;
      };

      # --- Terminal ---
      terminal = {
        minimum_contrast = 45;
        blinking = "on";
        font_weight = 350;
        show_count_badge = false;
        button = true;
        font_family = lib.mkDefault "Iosevka Nerd Font";
        font_size = 13;
        font_features = {
          calt = true;
        };
        line_height = "standard";
        copy_on_select = true;
        cursor_shape = "underline";
        shell = {
          program = "nu";
        };
      };

      # --- Behavior ---
      auto_indent_on_paste = true;
      auto_signature_help = true;
      middle_click_paste = true;
      show_completion_documentation = true;
      show_completions_on_input = true;
      show_edit_predictions = true;
      show_wrap_guides = true;
      use_autoclose = true;
      use_auto_surround = true;
      wrap_guides = [];
      sticky_scroll = {
        enabled = true;
      };

      inlay_hints = {
        enabled = true;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        # Let the theme color them more softly than normal code.
        show_background = false;
      };

      # --- Keymap ---
      base_keymap = "VSCode";

      # --- Edit Predictions ---
      edit_predictions = {
        provider = "zed";
      };

      # --- External Agents ---
      agent_servers = {
        # --- Registry ---
        pi-acp = {
          type = "registry";
        };
        claude-acp = {
          type = "registry";
        };

        # --- Pi ---
        pi = {
          type = "custom";
          command = "npx";
          args = ["-y" "pi-acp"];
          env = {
            "PI_ACP_ENABLE_EMBEDDED_CONTEXT" = "true";
          };
        };

        # --- Claude Agent ACP Fork with inline accept/reject---
        claude-agent-acp-fork = {
          type = "custom";
          command = "${claude-agent-acp-fork}/bin/claude-agent-acp";
          args = [];
        };
      };

      context_servers = {
        mcp-server-context7 = {
          enabled = true;
          remote = false;
        };
        mcp-server-github = {
          enabled = true;
          remote = false;
        };
        code-review-graph = {
          command = "uvx";
          args = [
            "code-review-graph"
            "serve"
          ];
        };
      };

      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      # --- Code ---
      format_on_save = "on";
      formatter = "language_server";
      minimap = {
        show = "auto";
      };
      file_types = {};

      # --- Gutter ---
      gutter = {
        line_numbers = true;
        runnables = true;
        breakpoints = true;
        folds = true;
        min_line_number_digits = 4;
      };

      # --- Tabs ---
      tabs = {
        close_position = "right";
        file_icons = true;
        git_status = true;
        activate_on_close = "history";
        show_close_button = "hover";
        show_diagnostics = "all";
      };
      tab_bar = {
        show_tab_bar_buttons = true;
        show_pinned_tabs_in_separate_row = false;
        show = true;
      };
      preview_tabs = {
        enable_keep_preview_on_code_navigation = false;
        enable_preview_multibuffer_from_code_navigation = true;
        enable_preview_from_file_finder = true;
      };

      # --- Indent Guides ---
      indent_guides = {
        enabled = true;
        line_width = 3;
        active_line_width = 6;
        coloring = "indent_aware";
      };

      # --- Image Viewer ---
      image_viewer = {
        unit = "decimal";
      };

      # --- Journal ---
      journal = {
        hour_format = "hour24";
      };

      # --- Diagnostics ---
      diagnostics = {
        button = true;
        inline = {
          enabled = true;
        };
      };

      # --- Title / Status Bar ---
      title_bar = {
        show_project_items = true;
        show_onboarding_banner = true;
        show_menus = false;
        show_branch_icon = true;
      };
      status_bar = {
        show_active_file = false;
        cursor_position_button = true;
        active_encoding_button = "non_utf8";
        active_language_button = true;
      };

      # --- Agent ---
      agent = {
        thinking_display = "always_collapsed";
        play_sound_when_agent_done = "when_hidden";
        expand_edit_card = true;
        notify_when_agent_waiting = "never";
        single_file_review = true;
        model_parameters = [];
        tool_permissions = import ./tool-permissions.nix;
        show_turn_stats = true;
      };
    };
  };
}
