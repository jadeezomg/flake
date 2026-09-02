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

        Nix = {
          language_servers = [ "nil" ];
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
        nil = {
          binary.path = "nil";
          binary.arguments = [ ];
          # Fetch missing flake inputs automatically instead of asking
          # ("Some flake inputs are not available. Fetch them now?").
          initialization_options.nix.flake.autoArchive = true;
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
