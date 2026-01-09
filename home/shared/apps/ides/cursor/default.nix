{
  pkgs,
  lib,
  ...
}: {
  programs.vscode = {
    enable = true;
    package = pkgs.code-cursor;
    mutableExtensionsDir = false;
    profiles.default = {
      extensions = with pkgs.vscode-extensions;
        [
          # --- Languages ---
          # Ruby
          wingrunr21.vscode-ruby # Ruby support
          rebornix.ruby # Ruby support
          shopify.ruby-lsp # Ruby Language Server
          # --- JavaScript/TypeScript ---
          dbaeumer.vscode-eslint # JavaScript/TypeScript linting
          # Nix
          kamadorueda.alejandra # Nix formatter
          jnoortheen.nix-ide # Nix language support
          # Lua
          sumneko.lua # Lua Language Server with formatting support
          # Python
          charliermarsh.ruff # Python linting/formatting
          ms-python.python # Python support
          # Nushell
          thenuprojectcontributors.vscode-nushell-lang # Nushell support
          # Data Formats
          mechatroner.rainbow-csv # CSV support
          tamasfe.even-better-toml # TOML support
          redhat.vscode-yaml # YAML support
        ]
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
          {
            name = "vscode-rubocop"; # Ruby formatter
            publisher = "rubocop";
            version = "0.10.0";
            sha256 = "0p25dzrxlvpv0a7qsn5lw65xnrjks43dzqq4g7j3r6dq6fn8ci1s";
          }
          {
            name = "prettier-vscode"; # Prettier formatter
            publisher = "prettier";
            version = "12.0.7";
            sha256 = "sha256-YWPqx5+q6ll/jrxjE1cfXTPOJTdphroELdEcKb4vtps=";
          }
          {
            name = "kdl"; # Prettier formatter
            publisher = "kdl-org";
            version = "2.1.3";
            sha256 = "sha256-Jssmb5owrgNWlmLFSKCgqMJKp3sPpOrlEUBwzZSSpbM=";
          }
        ];
      userSettings = {
        "workbench.colorTheme" = "Birds of Paradise";
        "editor.formatOnSave" = true;
        "editor.formatOnSaveMode" = "file";
        "editor.cursorStyle" = "block";
        "editor.accessibilitySupport" = "off";
        "telemetry.telemetryLevel" = "off";
        "window.commandCenter" = true;

        # Font settings
        "editor.fontFamily" = "'Iosevka Nerd Font', 'Iosevka', Menlo, Monaco, 'Courier New', monospace";
        "editor.fontSize" = 13;
        "editor.fontLigatures" = true;
        "terminal.integrated.fontFamily" = "'Iosevka Nerd Font', 'Iosevka', monospace";
        "terminal.integrated.fontSize" = 13;
        "debug.console.fontFamily" = "'Iosevka Nerd Font', 'Iosevka', monospace";

        # Terminal settings - use nushell as default
        "terminal.integrated.defaultProfile.osx" = "nu";
        "terminal.integrated.profiles.osx" = {
          "nu" = {
            "path" = "/run/current-system/sw/bin/nu";
            "args" = ["-l"];
            "icon" = "terminal";
          };
          "zsh" = {
            "path" = "/bin/zsh";
            "args" = ["-l"];
          };
          "bash" = {
            "path" = "/bin/bash";
            "args" = ["-l"];
          };
          "fish" = {
            "path" = "/run/current-system/sw/bin/fish";
            "args" = ["-l"];
          };
        };

        # Git settings
        "git.confirmSync" = false;
        "git.autofetch" = true;
        "git.enableSmartCommit" = true;

        # Explorer settings
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;

        # GitHub Pull Requests settings
        "githubPullRequests.pullBranch" = "never";
        "githubPullRequests.createOnPublishBranch" = "never";

        # Ruby settings
        "ruby.lint" = {
          "rubocop" = {
            "useBundler" = true;
          };
        };
        "rubyLsp.addonSettings" = {};
        "rubyLsp.formatter" = "rubocop_internal";

        # TypeScript settings
        "typescript.format.enable" = false;

        # Ruff settings
        "ruff.configurationPreference" = "filesystemFirst";
        "ruff.format.backend" = "uv";

        # CursorPyright settings
        "cursorpyright.disableLanguageServices" = true;

        # JSON-specific settings
        "[json]" = {
          "editor.defaultFormatter" = "prettier.prettier-vscode";
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        # JSONC-specific settings
        "[jsonc]" = {
          "editor.defaultFormatter" = "prettier.prettier-vscode";
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
          "editor.insertSpaces" = true;
        };

        # Nix-specific settings for Alejandra formatter
        "[nix].editor.defaultFormatter" = "kamadorueda.alejandra";
        "[nix].editor.formatOnPaste" = true;
        "[nix].editor.formatOnSave" = true;
        "[nix].editor.formatOnType" = false;
        "alejandra.program" = "alejandra";
        "[nix].editor.colorDecorators" = true;

        # Lua-specific settings for stylua formatter
        "[lua].editor.defaultFormatter" = "sumneko.lua";
        "[lua].editor.formatOnSave" = true;
        "[lua].editor.formatOnPaste" = false;
        "[lua].editor.formatOnType" = false;

        # Configure Lua Language Server formatting
        "Lua.format.enable" = true;
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
  # Only delete if Cursor is not running and the file/directory is writable.
  # home.activation.cursorRescanExtensions = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   # Check if Cursor is running - if so, skip deletion to avoid breaking extensions
  #   if pgrep -f "cursor|code-cursor" > /dev/null 2>&1; then
  #     echo "Cursor is running - skipping extensions.json deletion. Restart Cursor to rescan extensions."
  #   elif [ -f "$HOME/.cursor/extensions/extensions.json" ]; then
  #     # Check if the directory is writable before attempting deletion
  #     if [ -w "$HOME/.cursor/extensions" ] || [ -w "$HOME/.cursor/extensions/extensions.json" ]; then
  #       rm -f "$HOME/.cursor/extensions/extensions.json" || true
  #     else
  #       echo "Warning: Cannot delete extensions.json (read-only filesystem). Restart Cursor to rescan extensions."
  #     fi
  #   fi
  # '';
}
