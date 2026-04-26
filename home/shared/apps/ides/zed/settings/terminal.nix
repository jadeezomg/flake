{lib}: {
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
}
