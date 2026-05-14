# fastfetch banner on first interactive shell; $FASTFETCH_SHOWN prevents nested
# shell re-renders. Colors track home/shared/assets/theme/theme.nix.
# host-status command modules intentionally fall back to "?" so shell startup
# survives optional service/API failures.
{
  lib,
  pkgs,
  ...
}: let
  theme = import ../../assets/theme/theme.nix;

  # Edit one accent here to recolor its section.
  systemAccent = theme."accent-yellow";
  terminalAccent = theme."ansi-cyan";
  hardwareAccent = theme."accent-blue";
  projectAccent = theme."ansi-bright-red";

  banner = ''
    if [ -t 1 ] && [ -z "$FASTFETCH_SHOWN" ]; then
      export FASTFETCH_SHOWN=1
      ${pkgs.fastfetch}/bin/fastfetch
    fi
  '';

  bannerNu = ''
    if (is-terminal --stdout) and ('FASTFETCH_SHOWN' not-in $env) {
      $env.FASTFETCH_SHOWN = "1"
      ^${pkgs.fastfetch}/bin/fastfetch
    }
  '';
in {
  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

      logo = {
        type = "auto";
        # Palette gradient inspired by jaimeadeur's #dc5f00→#ffffff pattern.
        color = {
          "1" = theme."text-secondary";
          "2" = theme."text-primary";
          "3" = theme."ansi-bright-yellow";
          "4" = theme."accent-yellow";
          "5" = theme."ansi-yellow";
          "6" = theme."ansi-bright-red";
          "7" = theme."ansi-red";
          "8" = theme."ansi-bright-black";
          "9" = theme."ansi-black";
        };
        padding = {top = 1;};
      };

      display.separator = " ";

      # All Nerd Font icons are nf-md-* (Material Design Icons). User's
      # font ships mdi but not FA — confirmed empirically: 󰏖 / 󰅐 render,
      # FA glyphs do not. Project section stays on plain Unicode dingbats.
      modules = [
        "break"

        {
          type = "os";
          key = "╭ 󰌽 ";
          keyColor = systemAccent;
        }
        {
          type = "kernel";
          key = "├ 󰒓 ";
          keyColor = systemAccent;
        }
        {
          type = "packages";
          key = "├ 󰏖 ";
          keyColor = systemAccent;
        }
        {
          type = "command";
          key = "├ 󰥔 ";
          keyColor = systemAccent;
          text = "host-status generation 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "╰ ❄ ";
          keyColor = systemAccent;
          text = "host-status flake 2>/dev/null || echo '?'";
        }

        "break"

        {
          type = "terminal";
          key = "╭ 󰆍 ";
          keyColor = terminalAccent;
        }
        {
          type = "shell";
          key = "├ 󰌌 ";
          keyColor = terminalAccent;
        }
        {
          type = "terminalfont";
          key = "╰ 󰛖 ";
          keyColor = terminalAccent;
        }

        "break"

        {
          type = "host";
          key = "╭ 󰌢 ";
          keyColor = hardwareAccent;
        }
        {
          type = "cpu";
          key = "├ 󰻟 ";
          keyColor = hardwareAccent;
        }
        {
          type = "gpu";
          key = "├ 󰢮 ";
          format = "{2}";
          keyColor = hardwareAccent;
        }
        {
          type = "memory";
          key = "├ 󰍛 ";
          keyColor = hardwareAccent;
          percent = {type = 3;};
        }
        {
          type = "disk";
          key = "├ 󰋊 ";
          keyColor = hardwareAccent;
          percent = {type = 3;};
        }
        {
          type = "uptime";
          key = "╰ 󰅐 ";
          keyColor = hardwareAccent;
        }

        "break"

        {
          type = "command";
          key = "╭ 󰒍 ";
          keyColor = projectAccent;
          text = "host-status tailscale 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "├ 󰡨 ";
          keyColor = projectAccent;
          text = "host-status containers 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "├ 󰚩 ";
          keyColor = projectAccent;
          text = "host-status agents 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "├ 󰧑 ";
          keyColor = projectAccent;
          text = "host-status render claude 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "├ 󰈸 ";
          keyColor = projectAccent;
          text = "host-status render openrouter 2>/dev/null || echo '?'";
        }
        {
          type = "command";
          key = "╰ 󰂺 ";
          keyColor = projectAccent;
          text = "host-status skills 2>/dev/null || echo '?'";
        }

        "break"
      ];
    };
  };

  # Shell hooks gate on FASTFETCH_SHOWN to avoid nested-shell rerenders.
  programs.bash.initExtra = lib.mkAfter banner;
  programs.zsh.initContent = lib.mkAfter banner;
  programs.fish.interactiveShellInit = lib.mkAfter ''
    if status is-interactive; and not set -q FASTFETCH_SHOWN
        set -gx FASTFETCH_SHOWN 1
        ${pkgs.fastfetch}/bin/fastfetch
    end
  '';
  programs.nushell.extraConfig = lib.mkAfter bannerNu;
}
