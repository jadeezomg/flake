{lib}: {
  # --- Terminal ---
  terminal = {
    toolbar = {
      breadcrumbs = false;
    };
    bell = "system";
    minimum_contrast = 45;
    blinking = "on";
    font_weight = 400;
    show_count_badge = true;
    button = true;
    font_family = lib.mkDefault "Iosevka Nerd Font";
    font_size = 11.5;
    font_features = {
      calt = true;
    };
    line_height = "standard";
    copy_on_select = true;
    cursor_shape = "hollow";
    shell = {
      program = "nu";
    };
  };
}
