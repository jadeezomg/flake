{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.code-cursor;
    profiles.default = {
      extensions = with pkgs.vscode-extensions;
        [
          dbaeumer.vscode-eslint # JavaScript/TypeScript linting
          charliermarsh.ruff # Python linting/formatting
          tamasfe.even-better-toml # TOML support
          jnoortheen.nix-ide # Nix language support
          redhat.vscode-yaml # YAML support
          thenuprojectcontributors.vscode-nushell-lang # Nushell support
          rebornix.ruby # Ruby support
          aaron-bond.better-comments # Better comments highlighting
          kamadorueda.alejandra # Nix formatter
          sumneko.lua # Lua Language Server with formatting support
        ]
        ++ (
          if false
          then []
          else []
        )
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "schemastore"; # JSON Schema support
            publisher = "remcohaszing";
            version = "1.0.264";
            sha256 = "0n0yxvi6abqlh0x498z3xzinf2qs01crgv62hgg7xk3akskav1ri";
          }
          {
            name = "birds-of-paradise"; # Cozy brown Theme
            publisher = "Programming-Engineer";
            version = "0.1.2";
            sha256 = "05b8ahbwkjgmw2cq46dddd64lwg5mhffzff4b1knbl4yrw9jlbp2";
          }
        ];
      userSettings = {
        "workbench.colorTheme" = "Birds of Paradise";
        "editor.formatOnSave" = true;
        "editor.formatOnSaveMode" = "file";
        "editor.cursorStyle" = "block";
        "editor.fontFamily" = "'IosevkaTerm Nerd Font', 'Iosevka Nerd Font', monospace";
        "telemetry.telemetryLevel" = "off";

        # Nix-specific settings for Alejandra formatter
        "[nix].editor.defaultFormatter" = "kamadorueda.alejandra";
        "[nix].editor.formatOnPaste" = true;
        "[nix].editor.formatOnSave" = true;
        "[nix].editor.formatOnType" = false;
        "alejandra.program" = "alejandra";

        # Enable color decorators for Nix files (shows color picker for hex codes)
        "[nix].editor.colorDecorators" = true;

        # Lua-specific settings for stylua formatter
        "[lua].editor.defaultFormatter" = "sumneko.lua";
        "[lua].editor.formatOnSave" = true;
        "[lua].editor.formatOnPaste" = false;
        "[lua].editor.formatOnType" = false;
        # Configure Lua Language Server formatting
        "Lua.format.enable" = true;
        # Use stylua configuration via .stylua.toml (stylua is installed and will be used)
        # The Lua Language Server will respect .stylua.toml if stylua is in PATH
        "Lua.format.defaultConfig" = {
          indent_style = "Tab";
          indent_size = "2";
          quote_style = "AutoPreferDouble";
          call_parentheses = "Always";
          column_width = "100";
        };
      };
    };
  };

  # Cursor can keep a stale `~/.cursor/extensions/extensions.json` and ignore newly linked
  # extensions. Remove it on activation so Cursor regenerates it from the on-disk extensions.
  home.activation.cursorRescanExtensions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    rm -f "$HOME/.cursor/extensions/extensions.json"
  '';
}
