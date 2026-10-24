# Two fastfetch configs that share one look:
#   - minimal: the banner on the first interactive shell. Its modules read
#     kernel data directly, so it starts no child processes and counts no
#     packages. $FASTFETCH_SHOWN prevents nested shell re-renders. Run it by
#     hand with `fastfetch -c minimal`.
#   - full: bare `fastfetch`. It adds packages, live load stats, and the
#     host-status rows.
# Colors track lib/theme-palette.nix (dotfilesLib.palette). host-status
# command modules intentionally fall back to "?" so a failed probe does not
# break the output.
{
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  theme = dotfilesLib.palette;
  jsonFormat = pkgs.formats.json { };

  # Pin host-status to its Nix store path. fastfetch executes command modules
  # via a minimal subshell whose PATH does not include
  # /etc/profiles/per-user/<user>/bin on Darwin, so an unqualified `host-status`
  # falls through to the `|| echo '?'` fallback.
  hs = "${(dotfilesLib.hostStatus { inherit pkgs; }).hostStatus}/bin/host-status";

  # Edit one accent here to recolor its section.
  systemAccent = theme."accent-yellow";
  terminalAccent = theme."ansi-cyan";
  hardwareAccent = theme."accent-blue";
  loadAccent = theme."ansi-green";
  projectAccent = theme."ansi-bright-red";

  common = {
    "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";

    logo = {
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
      padding = {
        top = 1;
      };
    };

    display.separator = " ";
  };

  # All Nerd Font icons are nf-md-* (Material Design Icons). User's
  # font ships mdi but not FA — confirmed empirically: 󰏖 / 󰅐 render,
  # FA glyphs do not. Project section stays on plain Unicode dingbats.
  minimalSettings = lib.recursiveUpdate common {
    # Small OS logo: nixos_small on NixOS, macOS_small on Darwin.
    logo.type = "small";
    # Version probes start `<shell> --version` and `<terminal> --version`.
    general.detectVersion = false;

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
        type = "shell";
        key = "├ 󰌌 ";
        keyColor = systemAccent;
      }
      {
        type = "memory";
        key = "├ 󰍛 ";
        keyColor = systemAccent;
        percent = {
          type = 3;
        };
      }
      {
        type = "uptime";
        key = "╰ 󰅐 ";
        keyColor = systemAccent;
      }

      "break"
    ];
  };

  minimalConfig = jsonFormat.generate "fastfetch-minimal.jsonc" minimalSettings;

  banner = ''
    if [ -t 1 ] && [ -z "$FASTFETCH_SHOWN" ]; then
      export FASTFETCH_SHOWN=1
      ${pkgs.fastfetch}/bin/fastfetch -c ${minimalConfig}
    fi
  '';

  bannerNu = ''
    if (is-terminal --stdout) and ('FASTFETCH_SHOWN' not-in $env) {
      $env.FASTFETCH_SHOWN = "1"
      ^${pkgs.fastfetch}/bin/fastfetch -c ${minimalConfig}
    }
  '';
in
{
  xdg.configFile."fastfetch/minimal.jsonc".source = minimalConfig;

  programs = {
    fastfetch = {
      enable = true;
      settings = lib.recursiveUpdate common {
        logo.type = "auto";
        # Cap each host-status probe at 1s instead of the 5s default, so a
        # hung tailscale or podman cannot stall the output.
        general.processingTimeout = 1000;

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
            text = "${hs} generation 2>/dev/null || echo '?'";
          }
          {
            type = "command";
            key = "╰ ❄ ";
            keyColor = systemAccent;
            text = "${hs} flake 2>/dev/null || echo '?'";
          }

          "break"

          {
            type = "wm";
            key = "╭ 󰖯 ";
            keyColor = terminalAccent;
          }
          {
            type = "terminal";
            key = "├ 󰆍 ";
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
            type = "display";
            key = "├ 󰍹 ";
            keyColor = hardwareAccent;
          }
          # Prints nothing on hosts without a battery, so it must not be
          # the last row of the section.
          {
            type = "battery";
            key = "├ 󰁹 ";
            keyColor = hardwareAccent;
          }
          {
            type = "uptime";
            key = "╰ 󰅐 ";
            keyColor = hardwareAccent;
          }

          "break"

          # cpuusage waits 200ms between two samples. That wait sets the
          # minimum run time of the full fetch.
          {
            type = "cpuusage";
            key = "╭ 󰓅 ";
            keyColor = loadAccent;
          }
          {
            type = "loadavg";
            key = "├ 󰊚 ";
            keyColor = loadAccent;
          }
          {
            type = "memory";
            key = "├ 󰍛 ";
            keyColor = loadAccent;
            percent = {
              type = 3;
            };
          }
          {
            type = "swap";
            key = "├ 󰓡 ";
            keyColor = loadAccent;
            percent = {
              type = 3;
            };
          }
          {
            type = "disk";
            key = "├ 󰋊 ";
            keyColor = loadAccent;
            percent = {
              type = 3;
            };
          }
          {
            type = "processes";
            key = "├ 󰉹 ";
            keyColor = loadAccent;
          }
          {
            type = "localip";
            key = "╰ 󰩟 ";
            keyColor = loadAccent;
          }

          "break"

          {
            type = "command";
            key = "╭ 󰒍 ";
            keyColor = projectAccent;
            text = "${hs} tailscale 2>/dev/null || echo '?'";
          }
          {
            type = "command";
            key = "├ 󰡨 ";
            keyColor = projectAccent;
            text = "${hs} containers 2>/dev/null || echo '?'";
          }
          {
            type = "command";
            key = "├ 󰚩 ";
            keyColor = projectAccent;
            text = "${hs} agents 2>/dev/null || echo '?'";
          }
          {
            type = "command";
            key = "├ 󰧑 ";
            keyColor = projectAccent;
            text = "${hs} render claude 2>/dev/null || echo '?'";
          }
        ]
        # OpenRouter refresher is Linux-only; on Darwin the cache is never
        # populated and the row would show "(no data)" forever.
        ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) {
          type = "command";
          key = "├ 󰈸 ";
          keyColor = projectAccent;
          text = "${hs} render openrouter 2>/dev/null || echo '?'";
        }
        ++ [
          {
            type = "command";
            key = "╰ 󰂺 ";
            keyColor = projectAccent;
            text = "${hs} skills 2>/dev/null || echo '?'";
          }

          "break"
        ];
      };
    };

    # Shell hooks gate on FASTFETCH_SHOWN to avoid nested-shell rerenders.
    bash.initExtra = lib.mkAfter banner;
    zsh.initContent = lib.mkAfter banner;
    nushell.extraConfig = lib.mkAfter bannerNu;
  };
}
