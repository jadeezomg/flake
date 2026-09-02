{ pkgs, ... }:
let
  # Biome owns the web languages here, as it does in ../zed/languages.nix.
  # `just fmt` runs the same formatter, so the editor and the repo agree.
  biome = {
    "editor.defaultFormatter" = "biomejs.biome";
    "editor.formatOnSave" = true;
  };
  # Zed adds the fix-all and organize-imports actions for JS/TS only.
  biomeWithFixAll = biome // {
    "editor.codeActionsOnSave" = {
      "source.fixAll.biome" = "explicit";
      "source.organizeImports.biome" = "explicit";
    };
  };
in
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;
    profiles.default = {
      extensions =
        with pkgs.vscode-extensions;
        [
          # --- General ---
          github.vscode-pull-request-github # GitHub Pull Requests
          # --- JavaScript/TypeScript ---
          dbaeumer.vscode-eslint # JavaScript/TypeScript linting          biomejs.biome # TypeScript linter and formatter
          # Nix
          jnoortheen.nix-ide # Nix language support + nixfmt formatting
          # Just
          nefrob.vscode-just-syntax # Justfile support + just-lsp client
          # Bash
          mads-hartmann.bash-ide-vscode # bash-language-server client
          # Python
          charliermarsh.ruff # Python linting/formatting
          ms-python.python # Python support
          # Nushell
          thenuprojectcontributors.vscode-nushell-lang # Nushell support
          # GraphQL
          apollographql.vscode-apollo # Apollo GraphQL support
          # Data Formats
          mechatroner.rainbow-csv # CSV support
          tamasfe.even-better-toml # TOML support
          redhat.vscode-yaml # YAML support
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "birds-of-paradise"; # Cozy brown Theme
            publisher = "Programming-Engineer";
            version = "0.1.2";
            sha256 = "05b8ahbwkjgmw2cq46dddd64lwg5mhffzff4b1knbl4yrw9jlbp2";
          }
          {
            name = "marksman"; # Markdown LSP client (not in nixpkgs)
            publisher = "arr";
            version = "0.3.4";
            sha256 = "1pvapvydbrlllhihy7bkgvz38851381fmcvwc3z2m3w6dpywaijm";
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

        # Ported from the Zed config in ../zed/settings, so both editors behave
        # the same. Zed's `cursor_shape = "hollow"` has no VS Code equivalent.
        "editor.lineNumbers" = "relative";
        "editor.renderWhitespace" = "selection";
        "editor.guides.indentation" = true;
        "editor.bracketPairColorization.enabled" = true;
        "editor.stickyScroll.enabled" = true;
        "editor.inlayHints.enabled" = "on";
        "editor.tabSize" = 4;
        "files.autoSave" = "onFocusChange";
        "search.smartCase" = true;

        # Zed pins `auto_update = false`. The flake owns the versions, so stop
        # VS Code from updating itself or the extensions it was given.
        "update.mode" = "none";
        "extensions.autoUpdate" = false;
        # `autoUpdate` alone still leaves the update check running, which logs
        # "Auto updating outdated extensions" on every launch. The nixpkgs
        # versions always look outdated against the marketplace.
        "extensions.autoCheckUpdates" = false;

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
            "args" = [ "-l" ];
            "icon" = "terminal";
          };
          "zsh" = {
            "path" = "/bin/zsh";
            "args" = [ "-l" ];
          };
          "bash" = {
            "path" = "/bin/bash";
            "args" = [ "-l" ];
          };
        };

        # The NixOS hosts install VS Code through the same module, and Zed uses
        # `shell.program = "nu"` on every platform.
        "terminal.integrated.defaultProfile.linux" = "nu";
        "terminal.integrated.profiles.linux" = {
          "nu" = {
            "path" = "/run/current-system/sw/bin/nu";
            "args" = [ "-l" ];
            "icon" = "terminal";
          };
          "bash" = {
            "path" = "/run/current-system/sw/bin/bash";
            "args" = [ "-l" ];
          };
        };
        "terminal.integrated.copyOnSelection" = true;

        # Git settings
        "git.confirmSync" = false;
        "git.autofetch" = true;
        "git.enableSmartCommit" = true;
        "git.blame.editorDecoration.enabled" = true;

        # Explorer settings
        "explorer.confirmDelete" = false;
        "explorer.confirmDragAndDrop" = false;

        # GitHub Pull Requests settings
        "githubPullRequests.pullBranch" = "never";
        "githubPullRequests.createOnPublishBranch" = "never";

        # TypeScript settings
        "typescript.format.enable" = false;

        # Python — Ruff formats and lints, as it does in Zed.
        "ruff.configurationPreference" = "filesystemFirst";
        "ruff.format.backend" = "uv";
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
          "editor.formatOnSave" = true;
        };

        # Web languages — Biome. `[jsonc]` covers VS Code's own settings files.
        "[css]" = biome;
        "[graphql]" = biome;
        "[html]" = biome;
        "[json]" = biome;
        "[jsonc]" = biome;
        "[javascript]" = biomeWithFixAll;
        "[javascriptreact]" = biomeWithFixAll;
        "[typescript]" = biomeWithFixAll;
        "[typescriptreact]" = biomeWithFixAll;

        # Nix — `nixd` language server, `nixfmt` formatting, both from
        # devenv.languages.nix. nix-ide formats through the server, so the formatter
        # command belongs in the server settings.
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "nix.serverSettings" = {
          "nixd" = {
            "formatting" = {
              "command" = [ "nixfmt" ];
            };
          };
        };
        # Bash — this extension bundles its own bash-language-server, so the
        # binary from devenv.languages.shell serves helix and Zed only. Both
        # helper tools still come from PATH.
        "bashIde.shellcheckPath" = "shellcheck";
        "bashIde.shfmt.path" = "shfmt";
        "[shellscript]" = {
          "editor.defaultFormatter" = "mads-hartmann.bash-ide-vscode";
          "editor.formatOnSave" = true;
        };

        # Markdown — the extension downloads its own server by default, which
        # will not run on NixOS. Point it at the binary from
        # devenv.languages.docs instead.
        "marksman.customCommand" = "marksman server";

        # Just — `just-lsp` from devenv.languages.general, `just` from
        # devenv.tools. The server formats through `just --fmt --unstable`.
        "vscode-just.lspPath" = "just-lsp";
        "vscode-just.justPath" = "just";

        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
          "editor.formatOnPaste" = true;
          "editor.formatOnType" = false;
          "editor.colorDecorators" = true;
        };

        # Lua — formatting through the Lua Language Server.
        "[lua]" = {
          "editor.defaultFormatter" = "sumneko.lua";
          "editor.formatOnSave" = true;
          "editor.formatOnPaste" = false;
          "editor.formatOnType" = false;
        };

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
}
