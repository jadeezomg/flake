{
  lib,
  pkgs,
  ...
}:
let
  vls = pkgs.vscode-langservers-extracted;
  vscodeLangServer = name: {
    binary.path = lib.getExe' vls name;
    binary.arguments = [ "--stdio" ];
  };
in
{
  programs.zed-editor = {
    userSettings = {
      languages = {
        Python = {
          language_servers = [
            "ty"
            "!basedpyright"
          ];
          formatter = {
            language_server = {
              name = "ruff";
            };
          };
        };

        Lua = {
          tab_size = 2;
          formatter = "language_server";
          format_on_save = "on";
        };

        # Zed resolves `bash-language-server` from PATH before it npm-installs
        # its own copy. shfmt formats directly, as Zed's docs recommend; the
        # server still calls shellcheck for diagnostics.
        # https://zed.dev/docs/languages/sh
        "Shell Script" = {
          language_servers = [ "bash-language-server" ];
          formatter.external = {
            command = "shfmt";
            arguments = [
              "--filename"
              "{buffer_path}"
              "--indent"
              "2"
            ];
          };
          format_on_save = "on";
        };

        # Zed has built-in LSP support for marksman; no extension needed.
        # https://github.com/artempyanykh/marksman#existing-editor-integrations
        Markdown = {
          language_servers = [ "marksman" ];
        };

        Nix = {
          # `!nil` switches off the other server that the `nix` extension
          # registers. https://github.com/zed-extensions/nix#only-use-nixd
          language_servers = [
            "nixd"
            "!nil"
          ];
          formatter.external = {
            command = "nixfmt";
            arguments = [ "-" ];
          };
          format_on_save = "on";
        };

        # --- Biome (per-language; avoid global so unsupported languages aren't affected) ---
        CSS = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
        };
        GraphQL = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
        };
        HTML = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
        };
        JSON = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
        };
        JSONC = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
        };
        JavaScript = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        TSX = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
        TypeScript = {
          formatter = {
            language_server = {
              name = "biome";
            };
          };
          code_actions_on_format = {
            "source.fixAll.biome" = true;
            "source.organizeImports.biome" = true;
          };
        };
      };

      lsp = {
        "bash-language-server" = {
          binary.path = "bash-language-server";
          binary.arguments = [ "start" ];
        };

        marksman = {
          binary.path = "marksman";
          binary.arguments = [ "server" ];
        };

        nixd = {
          binary.path = "nixd";
          binary.arguments = [ ];
          # Zed nests `settings` under nixd's own config section.
          # https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
          settings.formatting.command = [ "nixfmt" ];
        };

        # Only enable Biome when project has biome.json (avoids affecting non-Biome projects)
        # Use system biome binary — the extension-downloaded binary is dynamically linked
        # and won't run on NixOS (stub-ld error).
        biome = {
          binary.path = "biome";
          binary.arguments = [ "lsp-proxy" ];
          settings = { };
        };

        # Pin VSCodium-extracted servers from pkgs (avoid stale 4.x on PATH / in Zed).
        "json-language-server" = vscodeLangServer "vscode-json-language-server";
        "html-language-server" = vscodeLangServer "vscode-html-language-server";
        "css-language-server" = vscodeLangServer "vscode-css-language-server";
      };
    };
  };
}
