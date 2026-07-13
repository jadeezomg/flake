{
  isDarwin,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        ratio = [
          2
          3
          4
        ];
        show_hidden = true;
        show_symlink = true;
        linemode = "size_and_mtime";
      };
    }
    // lib.optionalAttrs (!isDarwin && (osConfig.dotfiles.profiles.apps.notes.enable or false)) {
      opener.typora = [
        {
          run = "${pkgs.typora}/bin/typora %s1";
          orphan = true;
          desc = "Open with Typora";
          "for" = "linux";
        }
      ];

      open.prepend_rules = [
        {
          mime = "text/markdown";
          use = [
            "typora"
            "edit"
            "open"
          ];
        }
        {
          mime = "text/x-markdown";
          use = [
            "typora"
            "edit"
            "open"
          ];
        }
        {
          url = "*.md";
          use = [
            "typora"
            "edit"
            "open"
          ];
        }
        {
          url = "*.markdown";
          use = [
            "typora"
            "edit"
            "open"
          ];
        }
      ];
      opener.open = [
        {
          run = "xdg-open %s1";
          orphan = true;
          desc = "Open";
          "for" = "linux";
        }
        {
          run = "${pkgs.nautilus}/bin/nautilus --select %s1";
          orphan = true;
          desc = "Show in Nautilus";
          "for" = "linux";
        }
      ];
    };

    initLua = ./init.lua;

    # Plugins/flavors go here as `name = ./path/to/foo.yazi;` once added.
    # See https://yazi-rs.github.io/docs/plugins/overview
    plugins = { };
    flavors = { };
  };
}
