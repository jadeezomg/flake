{}: {
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

  # --- Diagnostics ---
  diagnostics = {
    button = true;
    inline = {
      enabled = true;
    };
  };
}
