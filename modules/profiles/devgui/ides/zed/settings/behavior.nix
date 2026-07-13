{ }: {
  # --- Behavior ---
  auto_indent_on_paste = true;
  auto_indent = "syntax_aware";
  auto_signature_help = true;
  middle_click_paste = true;
  show_completion_documentation = true;
  show_completions_on_input = true;
  show_edit_predictions = true;
  show_wrap_guides = true;
  use_autoclose = true;
  use_auto_surround = true;
  wrap_guides = [ ];
  sticky_scroll = {
    enabled = true;
  };

  # --- Cursor / Selection ---
  colorize_brackets = true;
  show_whitespaces = "selection";
  relative_line_numbers = "enabled";
  multi_cursor_modifier = "cmd_or_ctrl";

  # --- Editing ---
  hard_tabs = false;
  soft_wrap = "none";
  tab_size = 4;
  line_ending = "detect";
  code_lens = "on";
  completions = {
    words = "enabled";
  };

  # --- File ---
  close_on_file_delete = true;
  use_smartcase_search = true;
  file_finder = {
    modal_max_width = "large";
  };

  # --- Panes / Windows ---
  pane_split_direction_horizontal = "down";
  pane_split_direction_vertical = "right";
  zoomed_padding = true;
  restore_on_startup = "launchpad";
  cli_default_open_behavior = "new_window";
  on_last_window_closed = "quit_app";
  when_closing_with_no_tabs = "close_window";

  # --- Context Server ---
  context_server_timeout = 120;

  inlay_hints = {
    enabled = true;
    show_type_hints = true;
    show_parameter_hints = true;
    show_other_hints = true;
    show_background = false;
  };

  # --- Keymap ---
  base_keymap = "VSCode";

  # --- Edit Predictions ---
  edit_predictions = {
    provider = "zed";
    allow_data_collection = "no";
  };
}
