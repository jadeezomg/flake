# fastfetch banner on first interactive shell of a session. Sectioned
# layout (╭ ├ ╰ box-drawing) inspired by jaimeadeur's config; colors pulled
# from the Birds of Paradise palette in home/shared/assets/theme/theme.nix
# so they auto-track theme changes.
#
# Custom modules call `host-status <module>` (built in lib/host-status.nix)
# so detached nono sessions, OpenRouter credits, Claude rate-limit
# utilization, and other per-host context surface alongside the standard
# system info. OS-agnostic — same config renders on Linux + Darwin.
#
# Gating: $FASTFETCH_SHOWN env var prevents re-firing on nested shells (an
# editor terminal, `bash -l` from zsh, etc.).
{
  lib,
  pkgs,
  ...
}: let
  theme = import ../../assets/theme/theme.nix;

  # Per-section accents — 4 distinct hues, all from the Birds of Paradise
  # palette. Edit a single key here to recolor the corresponding section.
  systemAccent = theme."accent-yellow"; # foundational / golden anchor
  terminalAccent = theme."ansi-cyan"; # prompt-cyan, CLI vibes
  hardwareAccent = theme."accent-blue"; # cool / metallic
  projectAccent = theme."ansi-bright-red"; # warm / active state changes

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
        # 9-stop gradient mapping our palette light→dark via the warm tones.
        # Inspired by jaimeadeur's #dc5f00→#ffffff gradient pattern.
        color = {
          "1" = theme."text-secondary"; # white-ish, lightest
          "2" = theme."text-primary"; # cream
          "3" = theme."ansi-bright-yellow"; # bright yellow
          "4" = theme."accent-yellow"; # canonical golden accent
          "5" = theme."ansi-yellow"; # warm amber
          "6" = theme."ansi-bright-red"; # bright orange-red
          "7" = theme."ansi-red"; # red
          "8" = theme."ansi-bright-black"; # warm brown
          "9" = theme."ansi-black"; # darkest brown
        };
        padding = {top = 1;};
      };

      display.separator = " ";

      # All Nerd Font icons are nf-md-* (Material Design Icons). User's
      # font ships mdi but not FA — confirmed empirically: 󰏖 / 󰅐 render,
      # FA glyphs do not. Project section stays on plain Unicode dingbats.
      modules = [
        "break"

        # ----- System -----
        {
          type = "os"; # 󰌽 nf-md-linux U+F033D
          key = "╭ 󰌽 ";
          keyColor = systemAccent;
        }
        {
          type = "kernel"; # 󰒓 nf-md-cog U+F0493
          key = "├ 󰒓 ";
          keyColor = systemAccent;
        }
        {
          type = "packages"; # 󰏖 nf-md-package_variant_closed U+F03D6
          key = "├ 󰏖 ";
          keyColor = systemAccent;
        }
        {
          # Generation — 󰥔 nf-md-update U+F0954
          type = "command";
          key = "├ 󰥔 ";
          keyColor = systemAccent;
          text = "host-status generation 2>/dev/null || echo '?'";
        }
        {
          # Flake — ❄ Unicode SNOWFLAKE U+2744 (Nix snowflake; no NF needed)
          type = "command";
          key = "╰ ❄ ";
          keyColor = systemAccent;
          text = "host-status flake 2>/dev/null || echo '?'";
        }

        "break"

        # ----- Terminal -----
        {
          type = "terminal"; # 󰆍 nf-md-console_line U+F018D
          key = "╭ 󰆍 ";
          keyColor = terminalAccent;
        }
        {
          type = "shell"; # 󰌌 nf-md-keyboard U+F030C
          key = "├ 󰌌 ";
          keyColor = terminalAccent;
        }
        {
          type = "terminalfont"; # 󰛖 nf-md-format_letter_case U+F06D6
          key = "╰ 󰛖 ";
          keyColor = terminalAccent;
        }

        "break"

        # ----- Hardware -----
        {
          type = "host"; # 󰌢 nf-md-laptop U+F0322
          key = "╭ 󰌢 ";
          keyColor = hardwareAccent;
        }
        {
          type = "cpu"; # 󰻟 nf-md-cpu_64_bit U+F0EDF
          key = "├ 󰻟 ";
          keyColor = hardwareAccent;
        }
        {
          type = "gpu"; # 󰢮 nf-md-expansion_card U+F08AE
          key = "├ 󰢮 ";
          format = "{2}";
          keyColor = hardwareAccent;
        }
        {
          type = "memory"; # 󰍛 nf-md-memory U+F035B
          key = "├ 󰍛 ";
          keyColor = hardwareAccent;
          percent = {type = 3;};
        }
        {
          type = "disk"; # 󰋊 nf-md-harddisk U+F02CA
          key = "├ 󰋊 ";
          keyColor = hardwareAccent;
          percent = {type = 3;};
        }
        {
          type = "uptime"; # 󰅐 nf-md-clock_outline U+F0150
          key = "╰ 󰅐 ";
          keyColor = hardwareAccent;
        }

        "break"

        # ----- Project / network / agents -----
        # All mdi-prefix Nerd Font icons (the family confirmed working in
        # the user's font; FA-prefix fails). If a specific codepoint below
        # renders as a box, swap it for an alternate mdi codepoint.
        {
          # Tailscale — 󰒍 nf-md-network U+F048D
          type = "command";
          key = "╭ 󰒍 ";
          keyColor = projectAccent;
          text = "host-status tailscale 2>/dev/null || echo '?'";
        }
        {
          # Containers — 󰡨 nf-md-docker U+F0868
          type = "command";
          key = "├ 󰡨 ";
          keyColor = projectAccent;
          text = "host-status containers 2>/dev/null || echo '?'";
        }
        {
          # Agents — 󰚩 nf-md-robot U+F06A9
          type = "command";
          key = "├ 󰚩 ";
          keyColor = projectAccent;
          text = "host-status agents 2>/dev/null || echo '?'";
        }
        {
          # Claude — 󰧑 nf-md-brain U+F09D1
          type = "command";
          key = "├ 󰧑 ";
          keyColor = projectAccent;
          text = "host-status render claude 2>/dev/null || echo '?'";
        }
        {
          # OpenRouter — 󰈸 nf-md-router-network U+F0238
          type = "command";
          key = "├ 󰈸 ";
          keyColor = projectAccent;
          text = "host-status render openrouter 2>/dev/null || echo '?'";
        }
        {
          # Skills — 󰂺 nf-md-book-open-page-variant U+F00BA
          type = "command";
          key = "╰ 󰂺 ";
          keyColor = projectAccent;
          text = "host-status skills 2>/dev/null || echo '?'";
        }

        "break"
      ];
    };
  };

  # Wire the banner into each interactive shell.
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
