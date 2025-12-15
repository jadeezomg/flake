{ ... }:
{
  programs.zed-editor = {
    userSettings = {
      # --- Appearance ---
      buffer_font_fallbacks = [
        ".ZedMono"
        "Consolas"
        "Courier New"
      ];

      buffer_line_height = "comfortable";
      buffer_font_features = {
        calt = true;
      };

      # --- Agent Font ---
      agent_buffer_font_size = 14;

      current_line_highlight = "all";
      selection_highlight = true;
      ui_font_family = ".SystemUIFont";

      ui_font_features = {
        calt = true;
      };

      # --- UI ---
      active_pane_modifiers = {
        border_size = 1;
        inactive_opacity = 0.8;
      };
      rounded_selection = true;
      cursor_shape = "bar";

      # --- Terminal ---
      terminal = {
        font_family = "Iosevka Nerd Font";
        font_size = 14.0;
        font_features = {
          calt = true;
        };
        line_height = "standard";
        copy_on_select = true;
        cursor_shape = "bar";
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
      wrap_guides = [ ];

      # --- Keymap ---
      base_keymap = "VSCode";

      # --- Features And Telemetry ---
      features = {
        copilot = false;
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
      file_types = { };

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
        file_icons = false;
        git_status = true;
        activate_on_close = "history";
        show_close_button = "hover";
        show_diagnostics = "off";
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

      # --- Scrollbar ---
      # scrollbar = {
      #   axes = {
      #     horizontal = true;
      #     vertical = true;
      #   };
      #   cursors = true;
      #   diagnostics = "all";
      #   git_diff = true;
      #   search_results = true;
      #   selected_symbol = true;
      #   selected_text = true;
      #   show = "auto";
      # };

      # # --- Title Bar ---
      # title_bar = {
      #   show_branch_icon = false;
      #   show_onboarding_banner = true;
      #   show_user_picture = true;
      # };

      # # --- Toolbar ---
      # toolbar = {
      #   agent_review = false;
      #   breadcrumbs = true;
      #   quick_actions = true;
      #   selections_menu = true;
      # };

      # # --- Repl Configuration ---
      # jupyter = {
      #   kernel_selections = {
      #     python = "nixpython";
      #   };
      # };

    };
  };
}
