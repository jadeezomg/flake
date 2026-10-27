{
  isDarwin,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # The desktop id that owns markdown, from the same option as the XDG default
  # (modules/profiles/desktop/mime.nix). Null on darwin and on headless hosts.
  markdownId = osConfig.dotfiles.desktop.mimeHandlers.markdown or null;
  notesEnabled = osConfig.dotfiles.profiles.apps.notes.enable or false;
  hasMarkdownOpener = !isDarwin && notesEnabled && markdownId != null;

  # Map a desktop id to the command yazi runs. Known apps get a direct binary.
  # Anything else is launched through its .desktop entry.
  markdownOpeners = {
    typora = {
      run = "${pkgs.typora}/bin/typora %s1";
      desc = "Open with Typora";
    };
  };
  markdownOpener =
    markdownOpeners.${markdownId} or {
      run = "${pkgs.gtk3}/bin/gtk-launch ${markdownId} %s1";
      desc = "Open with ${markdownId}";
    };
  # Opener key: the last segment of the id, lowercased ("dev.zed.Zed" -> "zed").
  markdownOpenerName = lib.toLower (lib.last (lib.splitString "." markdownId));
  # Enter on a Markdown file reads it in glow, on every host. The open-with
  # menu keeps the desktop markdown app (Linux with notes), the editor, and
  # the system opener. The opener calls glow and less by their store paths,
  # so it works on hosts without the devenv profile that installs glow.
  markdownUse = [
    "glow"
  ]
  ++ lib.optional hasMarkdownOpener markdownOpenerName
  ++ [
    "edit"
    "open"
  ];
  markdownRules = map (rule: rule // { use = markdownUse; }) [
    { mime = "text/markdown"; }
    { mime = "text/x-markdown"; }
    { url = "*.md"; }
    { url = "*.markdown"; }
  ];
in
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

      opener = {
        # glow shows its output in less: glow 3.0.0's own reader (--tui)
        # loses the text when the window changes size (charmbracelet/glow#983).
        glow = [
          {
            run = "PAGER='${pkgs.less}/bin/less -R' ${pkgs.glow}/bin/glow --pager -- %s1";
            block = true;
            desc = "Read in glow";
          }
        ];
      }
      // lib.optionalAttrs hasMarkdownOpener {
        ${markdownOpenerName} = [
          {
            inherit (markdownOpener) run desc;
            orphan = true;
            "for" = "linux";
          }
        ];
        open = [
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

      open.prepend_rules = markdownRules;
    };

    initLua = ./init.lua;

    # Plugins/flavors go here as `name = ./path/to/foo.yazi;` once added.
    # See https://yazi-rs.github.io/docs/plugins/overview
    plugins = { };
    flavors = { };
  };
}
