{lib}: {
  # --- Appearance ---
  # mkForce overrides Stylix's computed font values while keeping its theme.
  buffer_font_family = lib.mkForce "Iosevka Nerd Font";
  buffer_font_fallbacks = [
    ".ZedMono"
  ];
  buffer_font_size = lib.mkForce 13;
  buffer_line_height = {
    custom = 1.45;
  };
  buffer_font_features = {
    calt = true;
  };

  icon_theme = "Catppuccin Latte";

  # --- Font Sizes ---
  ui_font_size = lib.mkForce 15.2;
  agent_buffer_font_size = 13;
  agent_ui_font_size = 15.2;

  current_line_highlight = "all";
  selection_highlight = true;
  ui_font_family = lib.mkForce "Inter Display";
  ui_font_fallbacks = ["Helvetica Neue" ".SystemUIFont"];

  ui_font_features = {
    calt = true;
  };

  # --- Window ---
  window_decorations = "server";
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

  # --- UI ---
  active_pane_modifiers = {
    border_size = 2;
    inactive_opacity = 0.8;
  };
  rounded_selection = true;
  cursor_shape = "hollow";
}
