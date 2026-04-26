{}: {
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
}
