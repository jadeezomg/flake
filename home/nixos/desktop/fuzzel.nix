{pkgs, ...}: {
  programs.fuzzel = {
    enable = true;
    settings = {
      border = {
        radius = 0;
        width = 1;
      };
      dmenu = {
        exit-immediately-if-empty = false;
        mode = "text";
      };
      main = {
        exit-on-keyboard-focus-loss = false;
        hide-before-typing = false;
        horizontal-pad = 40;
        icons-enabled = true;
        image-size-ratio = 0.5;
        inner-pad = 20;
        keyboard-focus = "exclusive"; # Other option: on-demand
        layer = "overlay";
        letter-spacing = 0;
        lines = 15;
        match-counter = true;
        match-mode = "fuzzy";
        prompt = "'λ '"; # NOTE: Default prompt if none provided
        show-actions = false;
        sort-result = true;
        tabs = 8;
        terminal = "kitty -e";
        use-bold = false;
        vertical-pad = 20;
        width = 60;
      };
    };
  };
}
